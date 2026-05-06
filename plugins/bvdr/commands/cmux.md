---
description: Manipulate the cmux terminal app via its CLI — save/restore workspace sessions to JSON, rename or close workspaces, and auto-assign workspace colors via a user-defined name→color rule file. Trigger phrases include "cmux", "save cmux", "restore cmux", "cmux workspaces", "color my cmux".
---

# cmux

Drives the cmux macOS terminal (`cmux.app`) over its Unix-socket CLI to save / restore / clean / recolor workspaces.

## Usage

Subcommands (parse from user's message):

| Subcommand | What it does |
|---|---|
| `save [path]` | Dump every workspace in the current cmux window to a portable JSON. Default path: `~/cmux-sessions/<UTC timestamp>.json`. |
| `restore <path>` | Recreate workspaces from a JSON saved by `save`. Skips ones already present (matched by name). |
| `apply-colors` | Color every workspace based on the user's local rule file (`~/.config/cmux-skill/colors.json`). Idempotent. No-op (with hint) if the file is missing. |
| `rename <ws> <new-name>` | Rename a single workspace (workspace ref like `workspace:5` or current name). |
| `cleanup` | Walk every workspace and ask the user (one prompt per workspace) whether to keep / rename / close. |
| `list` | Pretty-print current workspaces with their colors and CWD. |

If the user just says "cmux" with no subcommand, ask which one. Don't guess.

## Pre-flight (run once per session, not per subcommand)

1. **Locate the binary.** Try `command -v cmux`; if missing, fall back to `/Applications/cmux.app/Contents/Resources/bin/cmux`. Cache this in a shell var `CMUX=`. If neither exists, tell the user cmux isn't installed and stop.
2. **Verify daemon.** Run `"$CMUX" ping`. If it returns "Broken pipe (errno 32)", the cmux app's `socketControlMode` is `cmuxOnly` — external CLI control is blocked. Tell the user:
   > Add `"automation": { "socketControlMode": "automation" }` to `~/.config/cmux/cmux.json` (back the file up first), then restart cmux. (Reload via `cmux reload-config` doesn't help here because reload itself goes through the same socket.)
   Then stop. Don't auto-edit the config without explicit consent — it relaxes a security boundary.

## Color mapping

Color rules live **outside this repo** in `~/.config/cmux-skill/colors.json`. The file is intentionally not shipped — project names are personal context. Format:

```json
{
  "rules": [
    { "pattern": "<case-insensitive regex matched against workspace name>", "color": "<named color or #RRGGBB>" }
  ]
}
```

Rules are applied in order; first match wins. Patterns are Python regex (`re.IGNORECASE`).

If the file is missing when `apply-colors` runs, do not invent rules — print a one-liner showing the expected path and an example file, and stop.

cmux's named-color set (verified May 2026): `Amber, Aqua, Blue, Brown, Charcoal, Crimson, Green, Indigo, Magenta, Navy, Olive, Orange, Purple, Red, Rose, Teal`. Anything else needs `#RRGGBB` — notably there is no named "white".

## Subcommand: `save`

```bash
mkdir -p ~/cmux-sessions
OUT="${1:-$HOME/cmux-sessions/$(date -u +%Y%m%dT%H%M%SZ).json}"
SRC="$HOME/Library/Application Support/cmux/session-com.cmuxterm.app.json"
test -f "$SRC" || { echo "cmux session file not found: $SRC"; exit 1; }
python3 - "$SRC" "$OUT" <<'PY'
import json, sys, datetime
src, out = sys.argv[1], sys.argv[2]
d = json.load(open(src))
saved = {
  "version": 1,
  "savedAt": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
  "workspaces": []
}
for w in d.get("windows", []):
  for ws in w.get("tabManager", {}).get("workspaces", []):
    panels = []
    for p in ws.get("panels", []):
      term = p.get("terminal") or {}
      agent = term.get("agent") or {}
      lc = agent.get("launchCommand") or {}
      panels.append({
        "type": p.get("type"),
        "title": p.get("title"),
        "cwd": term.get("workingDirectory") or p.get("directory"),
        "command": {
          "executable": lc.get("executablePath"),
          "args": lc.get("arguments") or [],
          "env": {k: v for k, v in (lc.get("environment") or {}).items() if k.startswith("CLAUDE_")},
        } if lc else None,
        "agentKind": agent.get("kind"),
        "sessionId": agent.get("sessionId"),
      })
    saved["workspaces"].append({
      "name": ws.get("customTitle") or ws.get("processTitle"),
      "color": ws.get("customColor"),
      "cwd": ws.get("currentDirectory"),
      "panels": panels,
    })
json.dump(saved, open(out, "w"), indent=2)
print(f"Saved {len(saved['workspaces'])} workspaces -> {out}")
PY
```

Notes for the agent:
- The cmux app rewrites its session JSON on focus loss / quit, so `save` reads the latest *persisted* state. If the user just made changes and didn't switch away, advise: "Cmd+Tab away from cmux first so it flushes its session file, then run save again."
- Only `CLAUDE_*` env vars are kept — that's enough to preserve `cw`'s `CLAUDE_CONFIG_DIR`. Don't dump the full env; it leaks tokens.

## Subcommand: `restore`

```bash
SRC="$1"
test -f "$SRC" || { echo "no such file: $SRC"; exit 1; }
existing=$("$CMUX" list-workspaces 2>/dev/null | sed -E 's/^[* ] *workspace:[0-9]+  //; s/  \[selected\]$//')
python3 - "$SRC" "$CMUX" "$existing" <<'PY'
import json, sys, subprocess, shlex
src, cmux, existing = sys.argv[1], sys.argv[2], set(sys.argv[3].splitlines())
d = json.load(open(src))
for ws in d.get("workspaces", []):
    name = ws.get("name") or "(unnamed)"
    if name in existing:
        print(f"skip (exists): {name}")
        continue
    cwd = ws.get("cwd") or ""
    args = ["new-workspace", "--name", name, "--focus", "false"]
    if cwd: args += ["--cwd", cwd]
    out = subprocess.run([cmux] + args, capture_output=True, text=True)
    print(out.stdout.strip() or out.stderr.strip())
    ws_ref = (out.stdout or "").split()[-1] if out.stdout.startswith("OK ") else None
    if not ws_ref: continue
    color = ws.get("color")
    if color:
        subprocess.run([cmux, "workspace-action", "--action", "set-color", "--workspace", ws_ref, "--color", color])
    panels = ws.get("panels") or []
    if panels and panels[0].get("command"):
        p0 = panels[0]
        cmd = p0["command"]
        env_prefix = " ".join(f"{k}={shlex.quote(str(v))}" for k, v in (cmd.get("env") or {}).items())
        # cmux records args[0] as the executable already; don't double it.
        argv = list(cmd.get("args") or [])
        if not argv and cmd.get("executable"):
            argv = [cmd["executable"]]
        # Re-attach --resume <sessionId> if cmux captured it separately
        sid = p0.get("sessionId")
        if sid and "--resume" not in argv:
            argv += ["--resume", sid]
        full = " ".join([env_prefix, *(shlex.quote(a) for a in argv)]).strip()
        if full:
            subprocess.run([cmux, "send", "--workspace", ws_ref, full])
            subprocess.run([cmux, "send-key", "--workspace", ws_ref, "Return"])
PY
```

After restoring, advise the user that any first-run prompts (e.g. `claude`'s "trust external imports?" prompt) need to be answered manually in the cmux UI, or via `cmux send-key --workspace <ws> 1` then `Return`.

## Subcommand: `apply-colors`

```bash
RULES="$HOME/.config/cmux-skill/colors.json"
if [ ! -f "$RULES" ]; then
  cat <<EOF
No color rules found.

Create $RULES with your name→color mappings:

{
  "rules": [
    { "pattern": "<regex-on-workspace-name>", "color": "<NamedColor|#RRGGBB>" }
  ]
}
EOF
  exit 0
fi
python3 - "$CMUX" "$RULES" <<'PY'
import json, re, subprocess, sys
cmux, rules_path = sys.argv[1], sys.argv[2]
rules = json.load(open(rules_path)).get("rules", [])
compiled = [(re.compile(r["pattern"], re.IGNORECASE), r["color"]) for r in rules]
out = subprocess.run([cmux, "list-workspaces"], capture_output=True, text=True).stdout
for line in out.splitlines():
    m = re.match(r"^[* ] *(workspace:\d+)\s+(.+?)(?:\s+\[selected\])?$", line)
    if not m: continue
    ref, name = m.group(1), m.group(2)
    color = next((c for rx, c in compiled if rx.search(name)), None)
    if not color:
        print(f"no rule: {ref} ({name})")
        continue
    r = subprocess.run(
        [cmux, "workspace-action", "--action", "set-color", "--workspace", ref, "--color", color],
        capture_output=True, text=True,
    )
    print(f"{ref} ({name}) -> {color}" if r.returncode == 0 else f"FAIL {ref}: {r.stderr.strip()}")
PY
```

If a workspace name is ambiguous (e.g. matches two rules), the user's rule order decides. Tell them this when relevant — don't silently re-order.

## Subcommand: `rename`

```bash
"$CMUX" rename-workspace --workspace "$1" "$2"
```

Accept either a workspace ref (`workspace:5`), a current full name, or a substring (look up via `list-workspaces`).

## Subcommand: `cleanup`

Iterate workspaces, one at a time. For each:
1. Show the user: `<ref> | <name> | <cwd> | <color>` and ask: keep / rename / close.
2. If `rename`, prompt for the new name and run `rename-workspace`.
3. If `close`, run `cmux close-workspace --workspace <ref>` (warn if a Claude/agent process is running in it — they'll be killed).

Do not batch this. One workspace per prompt; the user wants to think about each.

## Subcommand: `list`

```bash
"$CMUX" tree --all
```

Already pretty. Pass through.

## Background context for the agent

- All `cmux` invocations need the binary path. Don't assume `cmux` is on PATH.
- `set-color`'s argument is positional after `--color`, no quoting needed for hex; named colors are case-sensitive (the `Color` enum: capitalized first letter).
- Workspaces created via `new-workspace --command "<cmd>"` may run the command in a non-interactive shell that doesn't load `~/.zshrc` (so aliases like `cw` won't expand). To preserve aliases, create the workspace without `--command`, then send the command via `send` + `send-key Return` — that goes to the interactive shell cmux already spawned.
- The cmux app must be running before any subcommand. If `ping` fails with "Broken pipe", check `socketControlMode` (see Pre-flight); if it fails with no response, run `open -a cmux` and wait ~3s.
