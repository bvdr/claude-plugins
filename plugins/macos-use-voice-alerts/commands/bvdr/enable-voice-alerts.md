---
description: Enable verbal notifications using macOS text-to-speech for Claude Code events
---

# Enable Voice Alerts

This command configures macOS text-to-speech notifications for Claude Code events.

## What It Does

Sets up voice alerts for:
- **Permission requests** - "Claude needs your permission"
- **Questions** - "Claude has a question for you"
- **Idle prompts** - "Claude is waiting for your input"
- **Session completion** - "Claude has finished"

## Setup Process

1. Determine the Claude config directory:
   - If `~/.claude-work/` exists → use `~/.claude-work/settings.json`
   - Otherwise → use `~/.claude/settings.json`

2. Read the existing settings.json file

3. Add or update the hooks configuration:

```json
{
  "hooks": {
    "PermissionRequest": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "say 'Claude needs your permission'"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "AskUserQuestion",
        "hooks": [
          {
            "type": "command",
            "command": "say 'Claude has a question for you'"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "idle_prompt",
        "hooks": [
          {
            "type": "command",
            "command": "say 'Claude is waiting for your input'"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "say 'Claude has finished'"
          }
        ]
      }
    ]
  }
}
```

4. Preserve all existing settings - only add/update the `hooks` key

5. Write the updated settings.json

## Completion Message

After setup, tell the user:

```
Voice alerts enabled!

You'll now hear spoken notifications when Claude:
- Needs permission for an action
- Has a question for you
- Is waiting for your input
- Finishes a task

Settings saved to: <settings_path>

To disable, remove the "hooks" section from your settings.json
```

## Notes

- **Platform**: macOS only (uses `say` command)
- **No restart needed**: Hooks take effect immediately
- **Customization**: Users can edit settings.json to change the spoken phrases
