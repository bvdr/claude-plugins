# Smart Permissions

AI-powered permission hook for Claude Code that auto-approves safe operations and auto-denies dangerous ones, reducing manual permission prompts.

## Installation

```bash
/plugin install smart-permissions@bvdr
```

> Requires the `bvdr` marketplace. Add it first if you haven't:
> ```bash
> /plugin marketplace add bvdr/claude-plugins
> ```

## Architecture

Two-layer system designed for speed and safety:

### Layer 1 — PreToolUse (fast, ~5ms)

Deterministic bash regex rules that run on every tool call. No LLM involved.

- **Always-allow**: Read-only tools (Read, Glob, Grep, etc.), safe bash commands (ls, git, npm test, etc.)
- **Always-deny**: Dangerous operations (rm -rf /, sudo, curl|bash, etc.)
- **Passthrough**: Anything ambiguous produces no output, falling through to Layer 2

### Layer 2 — PermissionRequest (~1-2s with API key, ~8-10s with CLI)

AI fallback using Claude Haiku. Only fires when Layer 1 didn't decide and a permission dialog would appear anyway.

- **Fast path**: Direct Anthropic API call via `curl` when `ANTHROPIC_API_KEY` is set (~1-2s)
- **Slow path**: Falls back to `claude` CLI when no API key is available (~8-10s)
- Loads `permission-policy.md` as the evaluation ruleset
- Fail-open: if anything breaks (missing deps, timeout, parse error), shows normal dialog
- Recursion-safe: guards against infinite loops via env checks

## What Gets Auto-Allowed (Layer 1)

**Tools**: Read, Glob, Grep, WebSearch, WebFetch, LS, ListDirectory, TodoRead, TaskList, TaskGet, TaskCreate, TaskUpdate, ToolSearch, EnterPlanMode

**Bash commands**:
- Read-only: `ls`, `cat`, `head`, `tail`, `wc`, `file`, `which`, `pwd`, `date`, `echo`, `stat`, `tree`, `du`, `df`
- Search: `grep`, `rg`, `find`, `fd`, `ag`
- Git: all `git` commands
- GitHub: all `gh` commands
- Testing: `npm test`, `pytest`, `jest`, `cargo test`, `go test`, `make test`
- Building: `npm run build`, `cargo build`, `go build`, `make`
- Linting: `eslint`, `prettier`, `black`, `rustfmt`
- Dev servers: `npm start`, `npm run dev`
- Docker read-only: `docker ps`, `docker images`, `docker logs`, `docker inspect`
- Version checks: `--version`, `-v`
- Compilers: `gcc`, `clang`, `tsc`, `rustc`, `javac`
- JSON: `jq`

## What Gets Auto-Denied (Layer 1)

- `rm -rf /`, `rm -rf ~`, or system paths
- `sudo` / `su`
- `curl | bash`, `wget | sh`
- `chmod 777`, recursive chmod on system paths
- `dd if=... of=/dev/`
- `mkfs`
- Fork bombs
- `networksetup`, `iptables`, `ufw`
- Modifying `~/.ssh/`, `~/.gnupg/`

## Speed Up Layer 2 with API Key

By default, Layer 2 uses the `claude` CLI which spawns a full Node.js runtime (~8-10s per evaluation). Set your Anthropic API key to use the direct API path instead (~1-2s):

```bash
# Add to your ~/.zshrc or ~/.bashrc
export ANTHROPIC_API_KEY="sk-ant-..."
```

Then restart your shell (or `source ~/.zshrc`) so the variable is available to hooks. The plugin detects the key automatically — no other configuration needed. If the key is missing or invalid, it falls back to the `claude` CLI.

## Customization

Edit `permission-policy.md` to adjust the AI evaluation rules for Layer 2. This file defines what the LLM considers GREEN (allow) and RED (deny) when evaluating ambiguous commands.

## Debug Logging

Layer 1 logging (high frequency — gated behind env var):
```bash
export SMART_PERMISSIONS_DEBUG=1
```

Layer 2 logging (low frequency — always on):
```bash
tail -f ~/.claude/hooks/smart-permissions.log
```

## Compatibility

Composes with `interactive-notifications`: smart-permissions runs first. If it decides (allow/deny), the event is resolved. If it passes through, interactive-notifications shows the macOS dialog as fallback.

## Requirements

- `jq` for JSON parsing (required for both layers)
- Layer 2 needs one of:
  - `ANTHROPIC_API_KEY` env var (fast path — direct API, ~1-2s)
  - `claude` CLI (slow path — full Node.js runtime, ~8-10s)

## Changelog

### v1.5.0
- Direct Anthropic API call via `curl` when `ANTHROPIC_API_KEY` is set — ~5x faster than CLI path (~1-2s vs ~8-10s)
- Falls back to `claude` CLI when no API key is available
- Increase PermissionRequest hook timeout from 60s to 180s (3 minutes)
- Add internal `timeout` wrapper (170s) so the script can log and clean up before the hook system's hard kill
- Add signal trap handlers (SIGTERM/SIGINT/SIGHUP) — previously the script vanished silently when killed, now it logs FAIL-OPEN entries

### v1.4.0
- Increase PermissionRequest hook timeout from 30s to 60s

### v1.3.0
- Compact Layer 2 logs for Write/Edit — log only file path instead of full content

### v1.2.0
- Removed `ExitPlanMode` from auto-allow list — plan execution now requires explicit user approval via Layer 2

### v1.1.0
- Added debug logging for evaluated commands
- Fixed `AskUserQuestion` being auto-approved (must always reach the user)

### v1.0.0
- Initial release: two-layer permission system (deterministic rules + AI fallback)

## License

MIT
