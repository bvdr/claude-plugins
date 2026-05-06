---
description: Initialize a cross-session cmux control center. Discovers active workspaces, lets the user pick which to monitor, captures the day's focus, and starts a background watcher that surfaces decisions / idle / done events to the calling session.
---

# /control

Stand up the cmux control-center pattern: this conversation becomes the orchestrator that watches every claude/codex/opencode session running inside cmux and surfaces only the events that need a human (questions, plan-mode, idle, done). Routine work is handled silently in each sub-session.

## When to use

User invokes `/control` to start (or re-start) supervising sub-agents. The command:
1. Discovers what's running across cmux right now
2. Asks the user which sessions to focus on today
3. Asks what they're working on (one sentence — used as a "north star" while routing decisions back)
4. Spawns / restarts the background watcher
5. Switches the rest of the conversation into orchestrator mode

## Pre-flight

1. **Locate cmux** — try `command -v cmux`; fall back to `/Applications/cmux.app/Contents/Resources/bin/cmux`. Cache as `CMUX=`. If neither exists, tell the user cmux isn't installed and stop.
2. **Verify daemon** — `"$CMUX" ping`. If it returns `Broken pipe (errno 32)`, see the `cmux` command's pre-flight notes (socketControlMode). Stop until resolved.
3. **Ensure config dir** — `mkdir -p ~/.config/cmux-control`.
4. **Ensure watcher script** — if `~/.config/cmux-control/filter.py` is missing, write it from the source in this repo (`plugins/bvdr/scripts/cmux-control-filter.py`), or fail loudly and tell the user where to install it from.

## Step 1 — Discover sessions

Read three sources and join them:

| Source | What you get |
|---|---|
| `cmux list-workspaces` | Workspace refs and names |
| `~/Library/Application Support/cmux/session-com.cmuxterm.app.json` | Per-workspace cwd, customColor, panel sessionIds (`panels[].terminal.agent.sessionId`) |
| `~/.cmuxterm/claude-hook-sessions.json` | Per-session `lastSubtitle` (Waiting/Working), `lastBody`, `cwd` |
| `~/.cmuxterm/workstream.jsonl` | Per-session activity history; tail to derive last user prompt + recent tool descriptions |

For each workspace with a claude/codex/opencode panel, build a one-line summary:

```
[N] <workspace-name>  ·  cwd=<short cwd>  ·  state=<Waiting|Active|Idle-stale>
    last user: "<truncated to ~80 chars>"
    last activity: <tool name + description, latest 1–2 entries>
```

Print the full list, numbered. Ignore workspaces without an agent panel.

## Step 2 — Ask which sessions to monitor

Use a multiple-choice question. Offer:
- Each session by number
- "All" — monitor everything
- "None" — start in pure-relay mode (the user will name sessions to add later)

Save the chosen UUIDs. Sessions not chosen are still recorded by the watcher (so we don't miss anything later) but the orchestrator filters them out by default.

## Step 3 — Ask what we're working on today

Single short open question: **"What are we working on today?"** One sentence is enough. This becomes the orchestrator's north star — it informs which sub-session events you proactively surface vs. log silently, and which to deprioritize if multiple decisions come in.

## Step 4 — Save state

Write to `~/.config/cmux-control/state.json`:

```json
{
  "today": "<the user's one-liner>",
  "started_at": "<ISO timestamp>",
  "monitored_sessions": [
    { "session_id": "<uuid>", "workspace_name": "<name>", "cwd": "<path>" }
  ]
}
```

## Step 5 — Start the watcher

The watcher is a single Python process at `~/.config/cmux-control/filter.py`. It tails `~/.cmuxterm/workstream.jsonl` and polls `claude-hook-sessions.json` every few seconds. It writes one labelled line per actionable event to `~/.config/cmux-control/events.log`:

```
[<ISO ts>] [<workspace name>] DECISION_NEEDED kind=AskUserQuestion input={…}
[<ISO ts>] [<workspace name>] PERM_PENDING tool=Bash desc=…
[<ISO ts>] [<workspace name>] IDLE body='Claude is waiting for your input'
[<ISO ts>] [<workspace name>] BUSY (resumed via activity)
[<ISO ts>] [<workspace name>] DONE (sessionEnd)
[<ISO ts>] [<workspace name>] SESSION_START
```

Restart logic (run every time `/control` is invoked, idempotent):

```bash
pkill -f ~/.config/cmux-control/filter.py 2>/dev/null
sleep 1
nohup python3 ~/.config/cmux-control/filter.py \
  > ~/.config/cmux-control/stdout.log \
  2> ~/.config/cmux-control/stderr.log &
echo $! > ~/.config/cmux-control/pid
```

Reset the cursor file so the orchestrator doesn't re-replay events from earlier today:

```bash
wc -c < ~/.config/cmux-control/events.log > ~/.config/cmux-control/cursor
```

## Step 5b — Arm the Monitor on events.log (so the orchestrator actually listens)

The watcher writes events to `events.log`, but without a Monitor watching that file the orchestrator only sees them when the user types something. To actually listen in real-time, arm a Monitor on the file with a filter that covers actionable events:

```python
# pseudo-Skill-tool call
Monitor({
  description: "cmux-control: actionable events from monitored sub-agents",
  command: "tail -F /Users/<USER>/.config/cmux-control/events.log | grep --line-buffered -E 'IDLE|DECISION_NEEDED|DONE'",
  persistent: true,
  timeout_ms: 3600000
})
```

Use `os.path.expanduser('~')` or shell `$HOME` — never hardcode the user path. Each new line in events.log that matches the filter becomes a `<task-notification>` that wakes the orchestrator turn — this is what makes "actively listening" real.

Before arming, call `TaskList` and skip if a Monitor with the same description is already running (re-running `/control` shouldn't double-arm).

Then call `ScheduleWakeup` with:
- `delaySeconds`: 1500 (25min — heartbeat past the 5-min cache window since Monitor is the primary wake signal)
- `reason`: "Monitor primary wake; this is fallback heartbeat"
- `prompt`: a `/loop ...` invocation that re-enters the same checking logic — this lets the orchestrator self-pace via `ScheduleWakeup` if anything ever slips past the Monitor.

The recommended `/loop` prompt:

```
/loop Check ~/.config/cmux-control/events.log past cursor. If new DECISION_NEEDED or IDLE events for monitored sessions exist, surface them with the agent's last-message summary per the operating contract. If a queue file exists at ~/.config/cmux-control/queue/<slug>.txt for an idle workspace, dispatch it via cmux send + Return and delete it. If no actionable events, reply silently with a single dot. Update the cursor file regardless.
```

If the user explicitly says "stop listening" / "stop the monitor": `TaskStop` the monitor, do not re-`ScheduleWakeup`. The watcher process keeps running (it's cheap and lossless — events.log keeps recording so resuming via `/control` again replays nothing missed).

## Step 6 — Confirm and explain operating mode

Print a single confirmation block:

```
✅ Control center active.
   Monitoring: <list of workspace names>
   Today's focus: <user's one-liner>
   Watcher PID: <pid>   Events log: ~/.config/cmux-control/events.log
   Monitor task: <task-id> (persistent — wakes me on each actionable event)
   Heartbeat: 25min fallback ScheduleWakeup armed
```

Then state the operating contract for the rest of the conversation:

- **Each user turn**: peek at events.log past the cursor.
- **Surface proactively**: `DECISION_NEEDED` from monitored sessions (always); `IDLE` and `DONE` from monitored sessions.
- **Always include the sub-agent's last message** when surfacing any event from a monitored session — pull `context.assistantPreamble` (and/or recent text) from the latest workstream.jsonl entries for that session and quote 1–4 sentences. Without it the user has no context on what the agent just did. This is non-negotiable, not a "if there's space" thing.
- **Silent**: routine `PERM_PENDING`, `BUSY`, `SESSION_START`, plus everything from unmonitored sessions (just record).
- **On user request**: `status` / `what's running?` → dump unread events for all sessions.
- **User-driven sub-agent control**: When the user wants to talk to a specific sub-agent, send via `cmux send --workspace <ref> "<msg>"` then `cmux send-key --workspace <ref> Return`. Always provide context to the sub-agent (it can't see this orchestrator's history).

## Cursor protocol (per-turn check)

```bash
CUR=$(cat ~/.config/cmux-control/cursor 2>/dev/null || echo 0)
SIZE=$(wc -c < ~/.config/cmux-control/events.log)
if [ "$SIZE" -gt "$CUR" ]; then
  tail -c +$((CUR+1)) ~/.config/cmux-control/events.log
  echo "$SIZE" > ~/.config/cmux-control/cursor
fi
```

Then filter the dumped lines: keep only those whose `[workspace name]` is in `state.json`'s `monitored_sessions`, unless the kind is `DECISION_NEEDED` (always surface).

## Pulling the last assistant message

For every surfaced event from a monitored session, fetch the most recent assistant text from `~/.cmuxterm/workstream.jsonl` for that session and quote it.

```python
import json
def last_assistant_text(session_id):
    """Return the most recent context.assistantPreamble for a session, or None."""
    last = None
    workstream = "~/.cmuxterm/workstream.jsonl"  # expanduser at call site
    with open(workstream) as f:
        for line in f:
            if not line.strip(): continue
            try: d = json.loads(line)
            except: continue
            if d.get("workstreamId","").endswith(session_id):
                p = (d.get("context") or {}).get("assistantPreamble")
                if p: last = (d.get("createdAt"), p)
    return last
```

`assistantPreamble` is the assistant's prose immediately before its next tool call or stop. The most recent non-empty value is the last thing the agent said. Quote 1–4 sentences in the user-facing relay.

## Queueing feedback for a busy sub-agent

When the user gives feedback for a sub-agent that's currently mid-work, **queue it**, don't interrupt. Stage any referenced screenshots into the target repo (e.g. `<repo>/.claude-feedback/<name>.png`) and write the prepared prompt to:

```
~/.config/cmux-control/queue/<workspace-slug>.txt
```

`<workspace-slug>` = lowercase workspace name with non-alphanumerics → `-`, emojis stripped. Confirm to the user that it's queued and will fire on next IDLE.

**Per-turn dispatch:** when peeking the events log, if you see a fresh `IDLE` for a workspace AND a queue file exists for it, send the queue file's content via `cmux send --workspace <ref>` + `Return`, then delete the queue file. Always include the cmux browser CLI snippet (see Sub-agent browser preference) inside the dispatched message — sub-agents may not remember it.

## Sub-agent browser preference

When relaying tasks to sub-agents that need browser-based verification (UI changes, screenshots, click-through tests), instruct them to use **cmux's built-in browser** rather than chrome MCP / playwright / puppeteer. Sub-agents running inside a cmux workspace already have access via their shell:

```
cmux browser open <url>             # opens a browser split alongside the terminal
cmux browser navigate <url>
cmux browser snapshot --compact     # accessibility tree
cmux browser screenshot --out <path>
cmux browser click <selector>
cmux browser type <selector> <text>
cmux browser eval <js>
cmux browser get text|title|html|url
```

Why: faster (no MCP roundtrip), the browser is visible to the user in the same workspace, screenshots land on disk where the sub-agent can immediately reference them. Mention this in the prompt you send via `cmux send`.

## Background context for the agent

- The watcher is **persistent across conversations** — it keeps running once started. Re-invoking `/control` cleanly restarts it.
- `claude-hook-sessions.json`'s `lastSubtitle` is a lagging indicator (it only updates when Claude's notification hook fires). The watcher cross-checks against fresh workstream activity to flip BUSY when a "Waiting" session actually resumed.
- The watcher does NOT differentiate sub-agent sources by workspace — a workspace can host any agent (`claude`, `codex`, `opencode`). The mapping is keyed on the panel's `agent.sessionId`.
- Workspace names should be treated as opaque strings — the user customizes them and they may contain emojis. Never normalize or strip them.
- The orchestrator mode persists for the rest of the conversation. It does not re-confirm on every turn — only acts on it.
