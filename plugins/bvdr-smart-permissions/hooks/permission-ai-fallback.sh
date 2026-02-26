#!/usr/bin/env bash
# Layer 2: AI-powered permission evaluation
# Only fires when Layer 1 didn't decide (passthrough) and a permission dialog would appear.
# Evaluates tool calls against permission-policy.md using a configurable AI provider.
# Fail-open: any error → no output → normal permission dialog shown.
#
# Provider selection via SMART_PERMISSIONS_PROVIDER env var:
#   claude  — Anthropic API (needs ANTHROPIC_API_KEY) or claude CLI fallback (default)
#   ollama  — Local Ollama (needs ollama running)
#   gemini  — Google Gemini API (needs GEMINI_API_KEY)
#   auto    — tries claude API → gemini → ollama → claude CLI

set -euo pipefail

# Internal timeout (seconds) — must be shorter than the hook timeout (180s)
# so we can log + clean up before the hook system kills us.
INTERNAL_TIMEOUT=170

# --- Provider configuration ---
PROVIDER="${SMART_PERMISSIONS_PROVIDER:-claude}"
CLAUDE_API_MODEL="${SMART_PERMISSIONS_CLAUDE_MODEL:-claude-haiku-4-5-20251001}"
OLLAMA_MODEL="${SMART_PERMISSIONS_OLLAMA_MODEL:-qwen2.5-coder:7b}"
GEMINI_MODEL="${SMART_PERMISSIONS_GEMINI_MODEL:-gemini-2.5-flash}"
GEMINI_API_URL="https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent"

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

# Validate provider early
case "$PROVIDER" in
  claude|ollama|gemini|auto) ;;
  *)
    fail_open "Unknown provider '$PROVIDER' — must be claude, ollama, gemini, or auto"
    ;;
esac

# Check that at least one provider is available
has_anthropic_key() { [[ -n "${ANTHROPIC_API_KEY:-}" ]]; }
has_gemini_key() { [[ -n "${GEMINI_API_KEY:-}" ]]; }
has_gemini_cli() { command -v gemini &>/dev/null; }
has_ollama() { command -v ollama &>/dev/null; }
has_claude_cli() { command -v claude &>/dev/null; }

if [[ "$PROVIDER" == "claude" ]] && ! has_anthropic_key && ! has_claude_cli; then
  fail_open "Provider 'claude': neither ANTHROPIC_API_KEY nor claude CLI available"
elif [[ "$PROVIDER" == "ollama" ]] && ! has_ollama; then
  fail_open "Provider 'ollama': ollama CLI not found"
elif [[ "$PROVIDER" == "gemini" ]] && ! has_gemini_cli && ! has_gemini_key; then
  fail_open "Provider 'gemini': neither gemini CLI nor GEMINI_API_KEY available"
elif [[ "$PROVIDER" == "auto" ]] && ! has_anthropic_key && ! has_gemini_cli && ! has_gemini_key && ! has_ollama && ! has_claude_cli; then
  fail_open "Provider 'auto': no providers available (need ANTHROPIC_API_KEY, GEMINI_API_KEY, gemini CLI, ollama, or claude CLI)"
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
POLICY_FILE="$PLUGIN_DIR/hooks/permission-policy.md"

# Fallback to old location if not found in hooks/
if [[ ! -f "$POLICY_FILE" ]]; then
  POLICY_FILE="$PLUGIN_DIR/permission-policy.md"
fi

if [[ ! -f "$POLICY_FILE" ]]; then
  fail_open "permission-policy.md not found"
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

# ============================================================
# Provider functions — each sets RESPONSE or calls fail_open
# ============================================================

call_claude_api() {
  # Direct Anthropic API call via curl (~1-2s)
  local api_payload api_response api_error
  api_payload=$(jq -n \
    --arg prompt "$PROMPT" \
    --arg model "$CLAUDE_API_MODEL" \
    '{
      model: $model,
      max_tokens: 100,
      messages: [{ role: "user", content: $prompt }]
    }')

  api_response=$(curl -s \
    --max-time "$INTERNAL_TIMEOUT" \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
    -d "$api_payload" \
    "https://api.anthropic.com/v1/messages" 2>/dev/null) || {
    local exit_code=$?
    if [[ $exit_code -eq 28 ]]; then
      log "claude API: timed out after ${INTERNAL_TIMEOUT}s"
    else
      log "claude API: curl failed (exit code $exit_code)"
    fi
    return 1
  }

  # Extract text — use printf instead of echo: the JSON contains \n sequences
  # that zsh's echo would interpret as literal newlines, breaking jq parsing.
  RESPONSE=$(printf '%s\n' "$api_response" | jq -r '.content[0].text // empty' 2>/dev/null)

  if [[ -z "$RESPONSE" ]]; then
    api_error=$(printf '%s\n' "$api_response" | jq -r '.error.message // empty' 2>/dev/null)
    if [[ -n "$api_error" ]]; then
      log "claude API error: $api_error"
    else
      log "claude API: empty response"
    fi
    return 1
  fi
  return 0
}

call_claude_cli() {
  # Fallback: claude CLI (slower — full Node.js runtime boot ~8-10s)
  local tmp_file="/tmp/smart-permissions-response.$$"
  local claude_pid watchdog_pid exit_code

  echo "$PROMPT" | claude --print --model haiku --no-session-persistence --max-turns 1 2>/dev/null > "$tmp_file" &
  claude_pid=$!
  ( sleep "$INTERNAL_TIMEOUT" && kill "$claude_pid" 2>/dev/null ) &
  watchdog_pid=$!
  wait "$claude_pid" 2>/dev/null
  exit_code=$?
  kill "$watchdog_pid" 2>/dev/null
  wait "$watchdog_pid" 2>/dev/null

  if [[ $exit_code -ne 0 ]]; then
    rm -f "$tmp_file"
    if [[ $exit_code -eq 137 || $exit_code -eq 143 ]]; then
      log "claude CLI: timed out after ${INTERNAL_TIMEOUT}s"
    else
      log "claude CLI: failed (exit code $exit_code)"
    fi
    return 1
  fi

  RESPONSE=$(cat "$tmp_file" 2>/dev/null)
  rm -f "$tmp_file"
  [[ -n "$RESPONSE" ]] && return 0
  log "claude CLI: empty response"
  return 1
}

call_ollama() {
  # Local Ollama inference
  local tmp_file="/tmp/smart-permissions-response.$$"
  local ollama_pid watchdog_pid exit_code

  echo "$PROMPT" | ollama run "$OLLAMA_MODEL" 2>/dev/null > "$tmp_file" &
  ollama_pid=$!
  ( sleep "$INTERNAL_TIMEOUT" && kill "$ollama_pid" 2>/dev/null ) &
  watchdog_pid=$!
  wait "$ollama_pid" 2>/dev/null
  exit_code=$?
  kill "$watchdog_pid" 2>/dev/null
  wait "$watchdog_pid" 2>/dev/null

  if [[ $exit_code -ne 0 ]]; then
    rm -f "$tmp_file"
    if [[ $exit_code -eq 137 || $exit_code -eq 143 ]]; then
      log "ollama: timed out after ${INTERNAL_TIMEOUT}s"
    else
      log "ollama: failed (exit code $exit_code)"
    fi
    return 1
  fi

  RESPONSE=$(cat "$tmp_file" 2>/dev/null)
  rm -f "$tmp_file"
  [[ -n "$RESPONSE" ]] && return 0
  log "ollama: empty response"
  return 1
}

call_gemini_cli() {
  # Gemini CLI (uses `gemini -p` for non-interactive mode)
  local tmp_file="/tmp/smart-permissions-response.$$"
  local gemini_pid watchdog_pid exit_code

  gemini -p "$PROMPT" 2>/dev/null > "$tmp_file" &
  gemini_pid=$!
  ( sleep "$INTERNAL_TIMEOUT" && kill "$gemini_pid" 2>/dev/null ) &
  watchdog_pid=$!
  wait "$gemini_pid" 2>/dev/null
  exit_code=$?
  kill "$watchdog_pid" 2>/dev/null
  wait "$watchdog_pid" 2>/dev/null

  if [[ $exit_code -ne 0 ]]; then
    rm -f "$tmp_file"
    if [[ $exit_code -eq 137 || $exit_code -eq 143 ]]; then
      log "gemini CLI: timed out after ${INTERNAL_TIMEOUT}s"
    else
      log "gemini CLI: failed (exit code $exit_code)"
    fi
    return 1
  fi

  RESPONSE=$(cat "$tmp_file" 2>/dev/null)
  rm -f "$tmp_file"
  [[ -n "$RESPONSE" ]] && return 0
  log "gemini CLI: empty response"
  return 1
}

call_gemini_api() {
  # Google Gemini REST API
  local api_payload api_response text parts_len

  api_payload=$(jq -n \
    --arg prompt "$PROMPT" \
    '{
      contents: [{ parts: [{ text: $prompt }] }],
      generationConfig: { maxOutputTokens: 256, temperature: 0.1 }
    }')

  api_response=$(curl -s \
    --max-time "$INTERNAL_TIMEOUT" \
    -H "Content-Type: application/json" \
    -d "$api_payload" \
    "${GEMINI_API_URL}?key=${GEMINI_API_KEY}" 2>/dev/null) || {
    local exit_code=$?
    if [[ $exit_code -eq 28 ]]; then
      log "gemini: timed out after ${INTERNAL_TIMEOUT}s"
    else
      log "gemini: curl failed (exit code $exit_code)"
    fi
    return 1
  }

  # Extract text — for thinking models, skip thought parts and grab the last non-thought text
  # Try the last part first (most models), then walk backwards for thinking models
  text=$(printf '%s\n' "$api_response" | jq -r '
    .candidates[0].content.parts
    | to_entries
    | map(select(.value.thought != true and .value.text != null))
    | last
    | .value.text // empty
  ' 2>/dev/null)

  if [[ -z "$text" ]]; then
    local api_error
    api_error=$(printf '%s\n' "$api_response" | jq -r '.error.message // empty' 2>/dev/null)
    if [[ -n "$api_error" ]]; then
      log "gemini API error: $api_error"
    else
      log "gemini: empty/unparseable response"
    fi
    return 1
  fi

  RESPONSE="$text"
  return 0
}

# ============================================================
# Execute provider(s)
# ============================================================
RESPONSE=""

case "$PROVIDER" in
  claude)
    if has_anthropic_key; then
      call_claude_api || call_claude_cli || fail_open "All claude providers failed"
    else
      call_claude_cli || fail_open "claude CLI failed"
    fi
    ;;
  ollama)
    call_ollama || fail_open "ollama failed"
    ;;
  gemini)
    if has_gemini_cli; then
      call_gemini_cli || { has_gemini_key && call_gemini_api; } || fail_open "All gemini providers failed"
    else
      call_gemini_api || fail_open "gemini API failed"
    fi
    ;;
  auto)
    # Try providers in order: claude API → gemini CLI → gemini API → ollama → claude CLI
    got_response=false
    if has_anthropic_key && call_claude_api; then
      got_response=true
    elif has_gemini_cli && call_gemini_cli; then
      got_response=true
    elif has_gemini_key && call_gemini_api; then
      got_response=true
    elif has_ollama && call_ollama; then
      got_response=true
    elif has_claude_cli && call_claude_cli; then
      got_response=true
    fi
    if [[ "$got_response" == "false" ]]; then
      fail_open "All providers failed (auto mode)"
    fi
    ;;
esac

if [[ -z "$RESPONSE" ]]; then
  fail_open "Empty response from $PROVIDER"
fi

log "AI response ($PROVIDER): $(echo "$RESPONSE" | head -2 | tr '\n' ' ')"

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
