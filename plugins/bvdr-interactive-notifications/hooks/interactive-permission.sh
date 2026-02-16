#!/bin/bash
#
# Interactive Permission Hook for Claude Code
#
# Shows macOS dialog with clickable buttons when Claude asks for permission.
# Includes folder path, session context, and option to type a reply.
#
# Part of: claude-plugins/plugins/interactive-notifications
#

LOG_FILE="$HOME/.claude/hooks/permission.log"
DEBUG_LOG="$HOME/.claude/hooks/debug.log"

# Generate unique ID for this hook call
HOOK_ID="$$-$(date +%s%N)"

# Read JSON input from stdin
INPUT=$(cat)

# Detailed debug logging
echo "========================================" >> "$DEBUG_LOG"
echo "$(date): HOOK CALL START - ID: $HOOK_ID" >> "$DEBUG_LOG"
echo "Script: $0" >> "$DEBUG_LOG"
echo "CLAUDE_PLUGIN_ROOT: ${CLAUDE_PLUGIN_ROOT:-not set}" >> "$DEBUG_LOG"
echo "PWD: $(pwd)" >> "$DEBUG_LOG"
echo "INPUT JSON:" >> "$DEBUG_LOG"
echo "$INPUT" | head -c 500 >> "$DEBUG_LOG"
echo "" >> "$DEBUG_LOG"

# Log for debugging
echo "$(date): Received permission request" >> "$LOG_FILE"

# Parse JSON input using jq
if command -v jq &> /dev/null; then
    TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "Unknown"')
    CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
    TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // ""')

    echo "$(date): HOOK $HOOK_ID - Tool: $TOOL_NAME" >> "$DEBUG_LOG"

    # Handle AskUserQuestion - collect answers via dialog and inject via updatedInput
    if [ "$TOOL_NAME" = "AskUserQuestion" ]; then
        echo "$(date): HOOK $HOOK_ID - Handling AskUserQuestion" >> "$DEBUG_LOG"
        FOLDER_PATH=$(echo "$CWD" | awk -F'/' '{
            n = NF
            if (n >= 3) print "../" $(n-2) "/" $(n-1) "/" $n
            else if (n == 2) print "../" $(n-1) "/" $n
            else print $n
        }')

        QUESTIONS=$(echo "$INPUT" | jq -r '.tool_input.questions // []')
        NUM_QUESTIONS=$(echo "$QUESTIONS" | jq 'length')

        if [ "$NUM_QUESTIONS" -eq 0 ]; then
            echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}'
            exit 0
        fi

        # Build answers object for updatedInput
        ANSWERS="{"

        for ((i=0; i<NUM_QUESTIONS; i++)); do
            QUESTION=$(echo "$QUESTIONS" | jq -r ".[$i]")
            HEADER=$(echo "$QUESTION" | jq -r '.header // "Question"')
            QUESTION_TEXT=$(echo "$QUESTION" | jq -r '.question // ""')
            OPTIONS=$(echo "$QUESTION" | jq -r '.options // []')
            NUM_OPTIONS=$(echo "$OPTIONS" | jq 'length')

            if [ "$NUM_OPTIONS" -eq 0 ]; then
                continue
            fi

            # Build options for dialog (max 2 buttons + Other, use list for more)
            if [ "$NUM_OPTIONS" -le 2 ]; then
                # Use buttons: options + Other
                BUTTON_LIST="\"Other\""
                for ((j=NUM_OPTIONS-1; j>=0; j--)); do
                    LABEL=$(echo "$OPTIONS" | jq -r ".[$j].label // \"Option $((j+1))\"" | head -c 20)
                    BUTTON_LIST="$BUTTON_LIST, \"$LABEL\""
                done

                DEFAULT_LABEL=$(echo "$OPTIONS" | jq -r '.[0].label // "Option 1"' | head -c 20)

                RESULT=$(osascript -e "
set theResult to display alert \"Claude [$FOLDER_PATH]: $HEADER\" message \"$QUESTION_TEXT\" buttons {$BUTTON_LIST} default button \"$DEFAULT_LABEL\" giving up after 300
if gave up of theResult then
    return \"TIMEOUT\"
else
    return button returned of theResult
end if
" 2>&1)
            else
                # Use list for 3+ options, add Other at the end
                LIST_ITEMS=""
                for ((j=0; j<NUM_OPTIONS; j++)); do
                    LABEL=$(echo "$OPTIONS" | jq -r ".[$j].label // \"Option $((j+1))\"")
                    if [ -n "$LIST_ITEMS" ]; then
                        LIST_ITEMS="$LIST_ITEMS, "
                    fi
                    LIST_ITEMS="$LIST_ITEMS\"$LABEL\""
                done
                LIST_ITEMS="$LIST_ITEMS, \"Other (custom answer)\""

                RESULT=$(osascript -e "
tell application \"System Events\"
    activate
    set chosenItem to choose from list {$LIST_ITEMS} with title \"Claude [$FOLDER_PATH]: $HEADER\" with prompt \"$QUESTION_TEXT\"
    if chosenItem is false then
        return \"CANCELLED\"
    else
        return item 1 of chosenItem
    end if
end tell
" 2>&1)
            fi

            # Handle "Other" - show text input for custom answer
            if [[ "$RESULT" == "Other" ]] || [[ "$RESULT" == "Other (custom answer)" ]]; then
                RESULT=$(osascript -e "
tell application \"System Events\"
    activate
    set userReply to display dialog \"Enter your custom answer:\" with title \"Claude [$FOLDER_PATH]: $HEADER\" default answer \"\" buttons {\"Cancel\", \"OK\"} default button \"OK\" giving up after 300
    if gave up of userReply then
        return \"TIMEOUT\"
    else if button returned of userReply is \"Cancel\" then
        return \"CANCELLED\"
    else
        return text returned of userReply
    end if
end tell
" 2>&1)
            fi

            echo "$(date): AskUserQuestion Q$i [$HEADER]: $RESULT" >> "$LOG_FILE"

            # Timeout/cancel - fall back to terminal
            if [[ "$RESULT" == "TIMEOUT" ]] || [[ "$RESULT" == "CANCELLED" ]] || [[ -z "$RESULT" ]]; then
                echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}'
                exit 0
            fi

            # Add to answers object (key is the question index as string)
            if [ $i -gt 0 ]; then
                ANSWERS="$ANSWERS,"
            fi
            RESULT_ESCAPED=$(echo "$RESULT" | sed 's/\\/\\\\/g; s/"/\\"/g')
            ANSWERS="$ANSWERS\"$i\":\"$RESULT_ESCAPED\""
        done

        ANSWERS="$ANSWERS}"
        echo "$(date): AskUserQuestion answers: $ANSWERS" >> "$LOG_FILE"

        # Allow the tool with pre-filled answers via updatedInput
        cat << EOF
{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow","updatedInput":{"answers":$ANSWERS}}}}
EOF
        exit 0
    fi

    # Extract relevant info based on tool type
    case "$TOOL_NAME" in
        "Bash")
            DETAIL=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
            ;;
        "Write"|"Edit"|"Read")
            DETAIL=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
            ;;
        *)
            DETAIL=$(echo "$INPUT" | jq -r '.tool_input | tostring' 2>/dev/null)
            ;;
    esac
else
    TOOL_NAME="Unknown"
    CWD=""
    TRANSCRIPT_PATH=""
    DETAIL=""
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

# Try to get the last user message from transcript for context
LAST_MESSAGE=""
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    LAST_MESSAGE=$(tail -50 "$TRANSCRIPT_PATH" 2>/dev/null | \
        grep '"type":"human"' | \
        tail -1 | \
        jq -r '.message.content // "" | if type == "array" then .[0].text // "" else . end' 2>/dev/null | \
        tr '\n' ' ')
fi

# Build the dialog title with folder context
DIALOG_TITLE="Claude: $FOLDER_PATH"

# Build the message
MSG="Tool: $TOOL_NAME"

if [ -n "$DETAIL" ] && [ "$DETAIL" != "null" ]; then
    DETAIL_ESCAPED=$(echo "$DETAIL" | sed 's/\\/\\\\/g; s/"/\\"/g')
    MSG="$MSG

$DETAIL_ESCAPED"
fi

# Add last message context if available
if [ -n "$LAST_MESSAGE" ] && [ "$LAST_MESSAGE" != "null" ]; then
    LAST_MSG_ESCAPED=$(echo "$LAST_MESSAGE" | sed 's/\\/\\\\/g; s/"/\\"/g')
    MSG="$MSG

---
Task: $LAST_MSG_ESCAPED"
fi

# Show alert with Yes/No/Reply buttons (5 minute timeout = 300 seconds)
# Using display alert instead of display dialog for longer text support
RESULT=$(osascript -e "
set theResult to display alert \"$DIALOG_TITLE\" message \"$MSG\" buttons {\"Reply\", \"No\", \"Yes\"} default button \"Yes\" giving up after 300
if gave up of theResult then
    return \"TIMEOUT\"
else
    return button returned of theResult
end if
" 2>&1)

echo "$(date): User selected: $RESULT" >> "$LOG_FILE"

# Handle Reply - show text input dialog
if [[ "$RESULT" == "Reply" ]]; then
    REPLY_TEXT=$(osascript -e "
tell application \"System Events\"
    activate
    set userReply to display dialog \"Type your message to Claude:\" with title \"Reply to Claude\" default answer \"\" buttons {\"Cancel\", \"Send\"} default button \"Send\" giving up after 300
    if gave up of userReply then
        return \"TIMEOUT\"
    else if button returned of userReply is \"Cancel\" then
        return \"CANCELLED\"
    else
        return text returned of userReply
    end if
end tell
" 2>&1)

    echo "$(date): User reply: $REPLY_TEXT" >> "$LOG_FILE"

    if [[ "$REPLY_TEXT" == "TIMEOUT" ]] || [[ "$REPLY_TEXT" == "CANCELLED" ]] || [[ -z "$REPLY_TEXT" ]]; then
        # Fall back to terminal
        echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"ask"}}}'
    else
        # Escape the reply for JSON
        REPLY_ESCAPED=$(echo "$REPLY_TEXT" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g')
        # Deny with user's message as context
        cat << EOF
{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny","message":"User replied: $REPLY_ESCAPED"}}}
EOF
    fi
    exit 0
fi

# Map user choice to Claude Code decision
if [[ "$RESULT" == *"Yes"* ]]; then
    echo "$(date): HOOK $HOOK_ID - Returning allow" >> "$DEBUG_LOG"
    echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}'
elif [[ "$RESULT" == *"No"* ]]; then
    echo "$(date): HOOK $HOOK_ID - Returning deny" >> "$DEBUG_LOG"
    echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny","message":"User denied via dialog"}}}'
else
    # Timeout or error - fall back to terminal prompt
    echo "$(date): HOOK $HOOK_ID - Returning ask (fallback)" >> "$DEBUG_LOG"
    echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"ask"}}}'
fi

echo "$(date): HOOK $HOOK_ID - COMPLETE" >> "$DEBUG_LOG"
exit 0
