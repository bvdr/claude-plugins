#!/bin/bash
#
# Interactive Stop Hook for Claude Code
#
# Shows macOS dialog when Claude finishes responding.
# Allows user to reply with follow-up or acknowledge completion.
#
# Part of: claude-plugins/plugins/interactive-notifications
#

LOG_FILE="$HOME/.claude/hooks/notification.log"

# Read JSON input from stdin
INPUT=$(cat)

# Log for debugging
echo "$(date): Received stop notification" >> "$LOG_FILE"

# Parse JSON input using jq
if command -v jq &> /dev/null; then
    CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
    STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
    TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // ""')
else
    CWD=""
    STOP_HOOK_ACTIVE="false"
    TRANSCRIPT_PATH=""
fi

# Don't show dialog if we're already in a stop hook loop
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
    exit 0
fi

# Get last 3 folders from path
if [ -n "$CWD" ]; then
    FOLDER_PATH=$(echo "$CWD" | awk -F'/' '{
        n = NF
        if (n >= 3) print "../" $(n-2) "/" $(n-1) "/" $n
        else if (n == 2) print "../" $(n-1) "/" $n
        else print $n
    }')
else
    FOLDER_PATH="Unknown"
fi

# Try to get Claude's last message
# Prefer the last_assistant_message field (available since v2.1.47), fall back to transcript parsing
LAST_CLAUDE_MSG=""

# First try: use last_assistant_message from hook input (fast, reliable)
LAST_CLAUDE_MSG=$(echo "$INPUT" | jq -r '.last_assistant_message // ""' 2>/dev/null)
echo "$(date): DEBUG last_assistant_message field length=${#LAST_CLAUDE_MSG}" >> "$LOG_FILE"

# Fallback: parse transcript file if last_assistant_message was empty
if [ -z "$LAST_CLAUDE_MSG" ] || [ "$LAST_CLAUDE_MSG" = "null" ]; then
    LAST_CLAUDE_MSG=""
    echo "$(date): DEBUG falling back to transcript parsing, path=$TRANSCRIPT_PATH" >> "$LOG_FILE"

    if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
        LAST_ASSISTANT_LINE=$(tac "$TRANSCRIPT_PATH" 2>/dev/null | grep -m 1 '"type":"assistant"')

        if [ -n "$LAST_ASSISTANT_LINE" ]; then
            LAST_CLAUDE_MSG=$(echo "$LAST_ASSISTANT_LINE" | jq -r '
                .message.content // [] |
                if type == "array" then
                    [.[] | select(.type=="text") | .text] | join("\n\n")
                elif type == "string" then
                    .
                else
                    ""
                end
            ' 2>/dev/null)
            echo "$(date): DEBUG transcript extracted_msg length=${#LAST_CLAUDE_MSG}" >> "$LOG_FILE"
        fi
    else
        echo "$(date): DEBUG transcript file NOT found or path empty" >> "$LOG_FILE"
    fi
fi

# Build dialog
DIALOG_TITLE="Claude Done: $FOLDER_PATH"

if [ -n "$LAST_CLAUDE_MSG" ] && [ "$LAST_CLAUDE_MSG" != "null" ] && [ "$LAST_CLAUDE_MSG" != "" ]; then
    # Escape for AppleScript: backslashes, quotes, and preserve newlines
    MSG=$(printf '%s' "$LAST_CLAUDE_MSG" | sed 's/\\/\\\\/g; s/"/\\"/g')
else
    MSG="Claude has finished responding."
fi

# Show alert with Continue/OK buttons (5 minute timeout)
# Using display alert instead of display dialog for longer text support
RESULT=$(osascript -e "
set theResult to display alert \"$DIALOG_TITLE\" message \"$MSG\" buttons {\"Continue\", \"OK\"} default button \"OK\" giving up after 300
if gave up of theResult then
    return \"TIMEOUT\"
else
    return button returned of theResult
end if
" 2>&1)

echo "$(date): User selected: $RESULT" >> "$LOG_FILE"

# Handle Continue - show text input for follow-up
if [[ "$RESULT" == "Continue" ]]; then
    REPLY_TEXT=$(osascript -e "
tell application \"System Events\"
    activate
    set userReply to display dialog \"What should Claude do next?\" with title \"Continue with Claude\" default answer \"\" buttons {\"Cancel\", \"Send\"} default button \"Send\" giving up after 300
    if gave up of userReply then
        return \"TIMEOUT\"
    else if button returned of userReply is \"Cancel\" then
        return \"CANCELLED\"
    else
        return text returned of userReply
    end if
end tell
" 2>&1)

    echo "$(date): User continue request: $REPLY_TEXT" >> "$LOG_FILE"

    if [[ "$REPLY_TEXT" != "TIMEOUT" ]] && [[ "$REPLY_TEXT" != "CANCELLED" ]] && [[ -n "$REPLY_TEXT" ]]; then
        # Block stopping and provide follow-up instruction
        REPLY_ESCAPED=$(echo "$REPLY_TEXT" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g')
        cat << EOF
{"decision":"block","reason":"User wants to continue: $REPLY_ESCAPED"}
EOF
        exit 0
    fi
fi

# OK or timeout - allow stop
exit 0
