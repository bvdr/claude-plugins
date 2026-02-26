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

### Layer 2 — PermissionRequest (AI evaluation)

AI fallback that evaluates ambiguous tool calls against `permission-policy.md`. Only fires when Layer 1 didn't decide and a permission dialog would appear anyway.

**Supported providers:**

| Provider | How | Speed | Requirements |
|----------|-----|-------|-------------|
| `claude` (default) | Anthropic API via `curl`, falls back to `claude` CLI | ~1-2s (API) / ~8-10s (CLI) | `ANTHROPIC_API_KEY` or `claude` CLI |
| `ollama` | Local inference via `ollama run` | Varies by model | `ollama` CLI running locally |
| `gemini` | Google Gemini REST API via `curl` | ~1-3s | `GEMINI_API_KEY` |
| `auto` | Tries claude API → gemini → ollama → claude CLI | Best available | Any one of the above |

Fail-open: if anything breaks (missing deps, timeout, parse error), shows normal dialog.

## Provider Configuration

Set the provider via environment variable:

```bash
# Add to your ~/.zshrc or ~/.bashrc
export SMART_PERMISSIONS_PROVIDER="claude"   # default
export SMART_PERMISSIONS_PROVIDER="ollama"   # use local Ollama
export SMART_PERMISSIONS_PROVIDER="gemini"   # use Gemini API
export SMART_PERMISSIONS_PROVIDER="auto"     # try all, first success wins
```

### Claude (default)

No extra config needed if `ANTHROPIC_API_KEY` is set (fast path) or `claude` CLI is installed (slow path).

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
# Optional: override the model (default: claude-haiku-4-5-20251001)
export SMART_PERMISSIONS_CLAUDE_MODEL="claude-haiku-4-5-20251001"
```

### Ollama

Requires [Ollama](https://ollama.ai) running locally with a model pulled:

```bash
ollama pull qwen2.5-coder:1.5b   # small, fast model — good for yes/no decisions
export SMART_PERMISSIONS_PROVIDER="ollama"
# Optional: override the model (default: qwen2.5-coder:1.5b)
export SMART_PERMISSIONS_OLLAMA_MODEL="qwen2.5-coder:1.5b"
```

### Gemini

Requires a [Google AI Studio](https://aistudio.google.com/apikey) API key:

```bash
export GEMINI_API_KEY="your_key_here"
export SMART_PERMISSIONS_PROVIDER="gemini"
# Optional: override the model (default: gemini-2.5-flash)
export SMART_PERMISSIONS_GEMINI_MODEL="gemini-2.5-flash"
```

### Auto mode

Tries providers in order until one succeeds: Claude API → Gemini → Ollama → Claude CLI. Useful if you have multiple providers available and want automatic failover.

```bash
export SMART_PERMISSIONS_PROVIDER="auto"
```

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
- Layer 2 needs at least one provider:
  - `ANTHROPIC_API_KEY` env var (Claude API — fast, ~1-2s)
  - `claude` CLI installed (Claude CLI — slower, ~8-10s)
  - `ollama` CLI with a model pulled (local inference)
  - `GEMINI_API_KEY` env var (Gemini API — fast, ~1-3s)

## Changelog

### v2.0.0
- Multi-provider support for Layer 2: Claude (API + CLI), Ollama, Gemini, or auto-failover
- New env vars: `SMART_PERMISSIONS_PROVIDER`, `SMART_PERMISSIONS_CLAUDE_MODEL`, `SMART_PERMISSIONS_OLLAMA_MODEL`, `SMART_PERMISSIONS_GEMINI_MODEL`
- Default behavior unchanged (Claude provider, same as before)

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
