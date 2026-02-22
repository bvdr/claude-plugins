# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A collection of Claude Code plugins and skills for macOS productivity. Contains native macOS integrations (dialogs, voice alerts, statusline) that enhance Claude Code workflows.

**Platform:** macOS only (uses `osascript`, `say` command)
**Dependencies:** `jq` (required), `git` (optional for statusline)

## Repository Structure

```
plugins/
├── bvdr-smart-permissions/        # AI-powered auto-allow/deny permission hook
│   └── hooks/                     # PreToolUse + PermissionRequest scripts
├── bvdr-interactive-notifications/ # Native macOS dialogs for permissions/questions
│   └── hooks/                     # Bash scripts invoked by Claude Code hooks
└── bvdr/                          # Skills collection (voice alerts, statusline, Slack)
    └── commands/                  # Skill markdown files
```

## Development Commands

```bash
# Test hook scripts directly (pipe JSON input)
echo '{"tool_name":"Bash","cwd":"/path","tool_input":{"command":"ls"}}' | bash plugins/bvdr-interactive-notifications/hooks/interactive-permission.sh

# View debug logs
tail -f ~/.claude/hooks/debug.log
tail -f ~/.claude/hooks/permission.log

# Test text-to-speech voices
say -v "?"                    # List all available voices
say -v Zarvox "Hello"         # Test specific voice

# Install plugin locally for testing
claude --plugin-dir ./
```

## Hook System Architecture

Hooks intercept Claude Code events and return JSON decisions:

```
Claude Code Event → Hook Script (stdin: JSON) → AppleScript Dialog → JSON Response (stdout)
```

**PermissionRequest Response Format:**
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": {
      "behavior": "allow|deny",
      "updatedInput": {},
      "message": "optional context (for deny)"
    }
  }
}
```

**Behavior values:**
- `allow` - Approve the action
- `deny` - Block with optional message
- To fall back to terminal prompt: exit with no stdout output (`exit 0`)

**PreToolUse Response Format:**
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow|deny|ask",
    "permissionDecisionReason": "reason text"
  }
}
```

**Stop Response Format (to block stopping):**
```json
{"decision": "block", "reason": "User wants to continue: ..."}
```

## Key Implementation Patterns

### AppleScript Integration
- Use `osascript -e` for dialogs
- `display alert` for longer text, `display dialog` for text input
- `choose from list` for 3+ options with multi-select support
- Always include `giving up after 300` for 5-minute timeout

### JSON Handling
- Parse with `jq`, always check if command exists first
- Escape special characters for AppleScript: `sed 's/\\/\\\\/g; s/"/\\"/g'`
- Truncate long content with `head -c N` before displaying

### Context Extraction
- Folder path: Last 3 directories via awk for compact display
- Last assistant message: Use `last_assistant_message` field from Stop/SubagentStop hook input (v2.1.47+), fall back to transcript parsing
- Last user message: Parse transcript JSON, extract from `message.content`

## Adding New Hooks

1. Create bash script in `plugins/<plugin-name>/hooks/`
2. Register in `hooks.json`:
```json
{
  "hooks": {
    "PermissionRequest": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/your-script.sh",
            "timeout": 310
          }
        ]
      }
    ]
  }
}
```
Available events: `PreToolUse`, `PermissionRequest`, `PostToolUse`, `Notification`, `Stop`, `SubagentStart`, `SubagentStop`, `SessionStart`, `SessionEnd`, `UserPromptSubmit`, `TaskCompleted`, `TeammateIdle`, `ConfigChange`, `PreCompact`
3. Update `manifest.json` with new hook file

## Adding New Skills

1. Create markdown file in `plugins/<plugin-name>/commands/`
2. Define procedural instructions for Claude to follow
3. Register in plugin's `.claude-plugin/plugin.json`
4. Skills can use `AskUserQuestion` tool for interactive configuration

## Important: Keep README.md in Sync

When adding, removing, or renaming plugins/skills, always update the root `README.md` to reflect the changes. This includes the plugin listings, install commands, skills table, and repository structure section.

## Testing

No automated tests - manual testing workflow:
1. Install plugin: `/plugin install <name>@bvdr`
2. Trigger relevant events (permission requests, questions, idle, completion)
3. Check debug logs at `~/.claude/hooks/`
4. Verify dialog behavior and JSON responses
