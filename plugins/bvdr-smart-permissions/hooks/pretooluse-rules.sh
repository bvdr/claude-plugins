#!/usr/bin/env bash
# Layer 1: Fast deterministic auto-allow rules (~5ms)
# Returns allow for known-safe operations.
# No output (passthrough) for everything else — Layer 2 AI or normal dialog handles it.
# Layer 1 never denies — the user always gets the final say via dialog.

set -euo pipefail

# Read stdin JSON once
INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // "{}"')

# --- Helper functions ---

allow() {
  local reason="$1"
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"allow\",\"permissionDecisionReason\":\"$reason\"}}"
  exit 0
}

passthrough() {
  # No output = normal permission flow continues
  exit 0
}

# Derive config dir from plugin install path (e.g. ~/.claude/plugins/cache/... → ~/.claude)
# Falls back to ~/.claude if CLAUDE_PLUGIN_ROOT is not set
if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
  CLAUDE_CONFIG_DIR="${CLAUDE_PLUGIN_ROOT%%/plugins/*}"
else
  CLAUDE_CONFIG_DIR="$HOME/.claude"
fi

debug_log() {
  if [[ "${SMART_PERMISSIONS_DEBUG:-0}" == "1" ]]; then
    local LOG_DIR="$CLAUDE_CONFIG_DIR/hooks"
    mkdir -p "$LOG_DIR"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [L1] $1" >> "$LOG_DIR/smart-permissions.log"
  fi
}

# --- Layer 1: Tool-level rules (no bash inspection needed) ---

# Tools that are always safe — read-only or informational
# AskUserQuestion is intentionally excluded — it must always reach the user so they can respond
ALWAYS_ALLOW_TOOLS="Read Glob Grep WebSearch WebFetch LS ListDirectory TodoRead TaskList TaskGet TaskCreate TaskUpdate ToolSearch ListMcpResourcesTool ReadMcpResourceTool EnterPlanMode"

for safe_tool in $ALWAYS_ALLOW_TOOLS; do
  if [[ "$TOOL_NAME" == "$safe_tool" ]]; then
    debug_log "ALLOW tool=$TOOL_NAME (always-allow list)"
    allow "Safe tool: $TOOL_NAME"
  fi
done

# If not a Bash tool, pass through — we only have detailed rules for Bash
if [[ "$TOOL_NAME" != "Bash" ]]; then
  debug_log "PASSTHROUGH tool=$TOOL_NAME (no rules for this tool)"
  passthrough
fi

# --- Layer 1: Bash command inspection ---

COMMAND=$(echo "$TOOL_INPUT" | jq -r '.command // ""')

if [[ -z "$COMMAND" ]]; then
  debug_log "PASSTHROUGH tool=Bash (empty command)"
  passthrough
fi

# Strip leading whitespace for pattern matching
COMMAND_TRIMMED=$(echo "$COMMAND" | sed 's/^[[:space:]]*//')

# --- Auto-ALLOW patterns ---

# Read-only / informational commands
if echo "$COMMAND_TRIMMED" | grep -qE '^(ls|cat|head|tail|wc|file|which|pwd|date|echo|stat|tree|du|df|env|printenv|uname|id|whoami|hostname|uptime|free|top\s+-bn1|lsof|ps|sort|uniq|cut|tr|diff|comm|basename|dirname|realpath|readlink)\b'; then
  debug_log "ALLOW tool=Bash cmd='$COMMAND' (read-only command)"
  allow "Read-only command"
fi

# Search commands
if echo "$COMMAND_TRIMMED" | grep -qE '^(grep|rg|find|fd|ag|ack|locate)\b'; then
  debug_log "ALLOW tool=Bash cmd='$COMMAND' (search command)"
  allow "Search command"
fi

# Git — all git operations are allowed
# (git is version-controlled, destructive actions are recoverable)
if echo "$COMMAND_TRIMMED" | grep -qE '^git\b'; then
  debug_log "ALLOW tool=Bash cmd='$COMMAND' (git)"
  allow "Git command"
fi

# gh CLI — GitHub operations
if echo "$COMMAND_TRIMMED" | grep -qE '^gh\b'; then
  debug_log "ALLOW tool=Bash cmd='$COMMAND' (gh cli)"
  allow "GitHub CLI command"
fi

# claude CLI — plugin management, config, etc.
if echo "$COMMAND_TRIMMED" | grep -qE '^claude\b'; then
  debug_log "ALLOW tool=Bash cmd='$COMMAND' (claude cli)"
  allow "Claude CLI command"
fi

# Testing frameworks
if echo "$COMMAND_TRIMMED" | grep -qE '^(npm\s+test|npx\s+(jest|vitest|mocha)|yarn\s+test|pnpm\s+test|pytest|python\s+-m\s+pytest|cargo\s+test|go\s+test|make\s+test|bundle\s+exec\s+rspec|phpunit|php\s+artisan\s+test)\b'; then
  debug_log "ALLOW tool=Bash cmd='$COMMAND' (testing)"
  allow "Test command"
fi

# Build commands
if echo "$COMMAND_TRIMMED" | grep -qE '^(npm\s+run\s+build|yarn\s+build|pnpm\s+build|cargo\s+build|go\s+build|make($|\s)|cmake\b|gradle\s+build|mvn\s+(compile|package)|dotnet\s+build)\b'; then
  debug_log "ALLOW tool=Bash cmd='$COMMAND' (build)"
  allow "Build command"
fi

# Linting / formatting
if echo "$COMMAND_TRIMMED" | grep -qE '^(eslint|prettier|black|isort|rustfmt|gofmt|goimports|rubocop|php-cs-fixer|phpcs|stylelint|tslint|biome|oxlint|deno\s+fmt|deno\s+lint)\b'; then
  debug_log "ALLOW tool=Bash cmd='$COMMAND' (lint/format)"
  allow "Linting/formatting command"
fi

# Dev servers
if echo "$COMMAND_TRIMMED" | grep -qE '^(npm\s+(start|run\s+dev|run\s+serve)|yarn\s+(start|dev)|pnpm\s+(start|dev)|cargo\s+run|go\s+run|python\s+(manage\.py\s+runserver|app\.py|-m\s+flask\s+run|-m\s+uvicorn|-m\s+gunicorn)|node\s|deno\s+run|bun\s+run)\b'; then
  debug_log "ALLOW tool=Bash cmd='$COMMAND' (dev server)"
  allow "Dev server command"
fi

# Docker read-only commands
if echo "$COMMAND_TRIMMED" | grep -qE '^docker\s+(ps|images|logs|inspect|stats|top|port|version|info|network\s+ls|volume\s+ls|container\s+ls)\b'; then
  debug_log "ALLOW tool=Bash cmd='$COMMAND' (docker read-only)"
  allow "Docker read-only command"
fi

# Version checks
if echo "$COMMAND" | grep -qE '(--version|-[vV]$|\bversion$)'; then
  debug_log "ALLOW tool=Bash cmd='$COMMAND' (version check)"
  allow "Version check"
fi

# Compilers / type-checkers
if echo "$COMMAND_TRIMMED" | grep -qE '^(gcc|g\+\+|clang|clang\+\+|tsc|rustc|javac|scalac|kotlinc|swiftc|go\s+vet|mypy|pyright)\b'; then
  debug_log "ALLOW tool=Bash cmd='$COMMAND' (compiler)"
  allow "Compiler/type-checker"
fi

# JSON processing
if echo "$COMMAND_TRIMMED" | grep -qE '^jq\b'; then
  debug_log "ALLOW tool=Bash cmd='$COMMAND' (jq)"
  allow "JSON processing with jq"
fi

# Package manager installs (read-only queries, not installs)
if echo "$COMMAND_TRIMMED" | grep -qE '^(npm\s+(ls|list|outdated|audit|info|view|show|explain)|pip\s+(list|show|freeze|check)|cargo\s+(tree|metadata)|gem\s+(list|info)|composer\s+(show|info))\b'; then
  debug_log "ALLOW tool=Bash cmd='$COMMAND' (package info)"
  allow "Package manager info command"
fi

# mkdir — creating directories is generally safe
if echo "$COMMAND_TRIMMED" | grep -qE '^mkdir\b'; then
  debug_log "ALLOW tool=Bash cmd='$COMMAND' (mkdir)"
  allow "Creating directories"
fi

# --- Passthrough: anything not matched above ---

debug_log "PASSTHROUGH tool=Bash cmd='$COMMAND' (no matching rule)"
passthrough
