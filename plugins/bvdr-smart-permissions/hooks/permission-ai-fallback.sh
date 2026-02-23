#!/usr/bin/env bash
# Layer 2: AI-powered permission evaluation (~8-10s)
# Only fires when Layer 1 didn't decide (passthrough) and a permission dialog would appear.
# Uses Claude Haiku to evaluate against permission-policy.md.
# Fail-open: any error → no output → normal permission dialog shown.

set -euo pipefail

# Internal timeout (seconds) — must be shorter than the hook timeout (180s)
# so we can log + clean up before the hook system kills us.
INTERNAL_TIMEOUT=170

# Derive config dir from plugin install path (e.g. ~/.claude/plugins/cache/... → ~/.claude)
# Falls back to ~/.claude if CLAUDE_PLUGIN_ROOT is not set
if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
  CLAUDE_CONFIG_DIR="${CLAUDE_PLUGIN_ROOT%%/plugins/*}"
else
  CLAUDE_CONFIG_DIR="$HOME/.claude"
fi

LOG_DIR="$CLAUDE_CONFIG_DIR/hooks"
LOG_FILE="$LOG_DIR/smart-permissions.log"

log() {
  mkdir -p "$LOG_DIR"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [L2] $1" >> "$LOG_FILE"
}

fail_open() {
  log "FAIL-OPEN: $1"
  # No output = normal permission dialog
  exit 0
}

# Trap signals so we log when the hook system kills us instead of vanishing silently
trap 'fail_open "Killed by signal (SIGTERM)"' TERM
trap 'fail_open "Killed by signal (SIGINT)"' INT
trap 'fail_open "Killed by signal (SIGHUP)"' HUP

# --- Recursion guard ---
# CLAUDE_CODE is set when running inside Claude Code's hook context.
# If claude CLI spawns another claude, this prevents infinite loops.
if [[ "${CLAUDECODE:-}" == "1" ]]; then
  fail_open "Recursion detected (CLAUDECODE=1)"
fi

# --- Check dependencies ---
if ! command -v jq &>/dev/null; then
  fail_open "jq not found"
fi

if [[ -z "${ANTHROPIC_API_KEY:-}" ]] && ! command -v claude &>/dev/null; then
  fail_open "Neither ANTHROPIC_API_KEY nor claude CLI available"
fi

# --- Parse input ---
INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "Unknown"')
TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}')
CWD=$(echo "$INPUT" | jq -r '.cwd // "unknown"')

# Show the command being evaluated for easier debugging
if [[ "$TOOL_NAME" == "Bash" ]]; then
  COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
  log "Evaluating: tool=$TOOL_NAME cwd=$CWD command=$COMMAND"
elif [[ "$TOOL_NAME" == "Write" || "$TOOL_NAME" == "Edit" ]]; then
  # Log just the file path — the full old_string/new_string content is too verbose
  FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // ""')
  log "Evaluating: tool=$TOOL_NAME cwd=$CWD file=$FILE_PATH"
else
  log "Evaluating: tool=$TOOL_NAME cwd=$CWD input=$TOOL_INPUT"
fi

# AskUserQuestion must always reach the user — never auto-decide
if [[ "$TOOL_NAME" == "AskUserQuestion" ]]; then
  log "PASSTHROUGH: AskUserQuestion always needs user interaction"
  exit 0
fi

# --- Load permission policy ---
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POLICY_FILE="$PLUGIN_DIR/permission-policy.md"

if [[ ! -f "$POLICY_FILE" ]]; then
  fail_open "permission-policy.md not found at $POLICY_FILE"
fi

POLICY=$(cat "$POLICY_FILE")

# --- Build prompt for AI evaluation ---
PROMPT="You are a security evaluator for Claude Code tool calls.

<policy>
$POLICY
</policy>

<tool_call>
Tool: $TOOL_NAME
Working Directory: $CWD
Input: $TOOL_INPUT
</tool_call>

Based on the policy above, should this tool call be allowed?
Respond with EXACTLY one word on the first line: ALLOW or DENY
Then on the second line, a brief reason (one sentence)."

# --- Call Claude Haiku ---
# Fast path: direct API call via curl (~1-2s) when ANTHROPIC_API_KEY is set.
# Slow path: claude CLI (~8-10s) as fallback — spawns full Node.js runtime.
RESPONSE=""

if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
  # Build JSON payload — jq handles escaping the prompt safely
  API_PAYLOAD=$(jq -n \
    --arg prompt "$PROMPT" \
    '{
      model: "claude-haiku-4-5-20251001",
      max_tokens: 100,
      messages: [{ role: "user", content: $prompt }]
    }')

  API_RESPONSE=$(curl -s \
    --max-time "$INTERNAL_TIMEOUT" \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
    -d "$API_PAYLOAD" \
    "https://api.anthropic.com/v1/messages" 2>/dev/null) || {
    EXIT_CODE=$?
    # curl exit 28 = timeout
    if [[ $EXIT_CODE -eq 28 ]]; then
      fail_open "API call timed out after ${INTERNAL_TIMEOUT}s"
    else
      fail_open "API call failed (exit code $EXIT_CODE)"
    fi
  }

  # Extract text from API response — handle both success and error shapes
  # Use printf instead of echo: the JSON contains \n sequences that zsh's echo
  # would interpret as literal newlines, breaking jq parsing.
  RESPONSE=$(printf '%s\n' "$API_RESPONSE" | jq -r '.content[0].text // empty' 2>/dev/null)

  if [[ -z "$RESPONSE" ]]; then
    # Check for API error message
    API_ERROR=$(printf '%s\n' "$API_RESPONSE" | jq -r '.error.message // empty' 2>/dev/null)
    if [[ -n "$API_ERROR" ]]; then
      fail_open "API error: $API_ERROR"
    fi
    fail_open "Empty response from API"
  fi
else
  # Fallback: claude CLI (slower — full Node.js runtime boot)
  # --no-session-persistence: don't pollute session history
  # --max-turns 1: single response, no back-and-forth
  # Background watchdog kills the CLI if it exceeds INTERNAL_TIMEOUT (macOS has no `timeout` command).
  echo "$PROMPT" | claude --print --model haiku --no-session-persistence --max-turns 1 2>/dev/null > /tmp/smart-permissions-response.$$ &
  CLAUDE_PID=$!
  ( sleep "$INTERNAL_TIMEOUT" && kill "$CLAUDE_PID" 2>/dev/null ) &
  WATCHDOG_PID=$!
  wait "$CLAUDE_PID" 2>/dev/null
  EXIT_CODE=$?
  kill "$WATCHDOG_PID" 2>/dev/null
  wait "$WATCHDOG_PID" 2>/dev/null

  if [[ $EXIT_CODE -ne 0 ]]; then
    rm -f "/tmp/smart-permissions-response.$$"
    if [[ $EXIT_CODE -eq 137 || $EXIT_CODE -eq 143 ]]; then
      fail_open "claude CLI timed out after ${INTERNAL_TIMEOUT}s"
    else
      fail_open "claude CLI failed (exit code $EXIT_CODE)"
    fi
  fi

  RESPONSE=$(cat "/tmp/smart-permissions-response.$$" 2>/dev/null)
  rm -f "/tmp/smart-permissions-response.$$"
fi

if [[ -z "$RESPONSE" ]]; then
  fail_open "Empty response from claude CLI"
fi

log "AI response: $(echo "$RESPONSE" | head -2 | tr '\n' ' ')"

# --- Parse AI decision ---
FIRST_LINE=$(echo "$RESPONSE" | head -1 | tr -d '[:space:]')
REASON=$(echo "$RESPONSE" | sed -n '2p' | head -c 200)

# Default reason if none provided
if [[ -z "$REASON" ]]; then
  REASON="AI evaluation"
fi

# Escape quotes in reason for JSON
REASON_ESCAPED=$(echo "$REASON" | sed 's/\\/\\\\/g; s/"/\\"/g')

if [[ "$FIRST_LINE" == "ALLOW" ]]; then
  log "DECISION: ALLOW — $REASON"
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PermissionRequest\",\"decision\":{\"behavior\":\"allow\",\"message\":\"AI: $REASON_ESCAPED\"}}}"
  exit 0
elif [[ "$FIRST_LINE" == "DENY" ]]; then
  # AI recommends denying, but let the user make the final call via the normal permission dialog.
  log "DECISION: DENY (asking user) — $REASON"
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PermissionRequest\",\"decision\":{\"behavior\":\"ask\",\"message\":\"AI recommends deny: $REASON_ESCAPED\"}}}"
  exit 0
else
  # AI response wasn't clear — fail open to normal dialog
  fail_open "Unclear AI response: '$FIRST_LINE'"
fi
