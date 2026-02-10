# Claude Code Plugins by Bogdan Dragomir

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-compatible-blueviolet)](https://claude.com/claude-code)

A curated collection of Claude Code plugins for macOS productivity, development workflows, and automation.

---

## Quick Start

Add the marketplace and install any plugin:

```bash
/plugin marketplace add bvdr/claude-plugins
/plugin install <plugin-name>@bvdr
```

---

## Plugins

### [Smart Permissions](plugins/smart-permissions)

AI-powered permission hook that auto-approves safe operations and auto-denies dangerous ones.

- **Layer 1**: Fast deterministic regex rules (~5ms) — no LLM involved
- **Layer 2**: Claude Haiku fallback for ambiguous cases (~8-10s)
- Composes with interactive-notifications as a fallback

```bash
/plugin install smart-permissions@bvdr
```

**Platform:** macOS, Linux | **Requires:** `jq`, `claude` CLI (optional for Layer 2)

---

### [Interactive Notifications](plugins/interactive-notifications)

Respond to Claude Code from anywhere on your Mac via native macOS dialogs — no need to switch to the terminal.

- Permission dialogs with Yes / No / Reply buttons
- Question dialogs with buttons or selectable lists
- Idle alerts and task completion notifications
- Shows folder path, tool details, and your last request

```bash
/plugin install interactive-notifications@bvdr
```

**Platform:** macOS | **Requires:** `jq`

---

### [Voice Alerts](plugins/macos-use-voice-alerts)

Verbal notifications using macOS text-to-speech when Claude needs attention or completes tasks.

- Announces permission requests, questions, idle prompts, and completion
- Customizable voice (Zarvox, Whisper, Samantha, etc.)
- No restart needed — hooks take effect immediately

```bash
/plugin install macos-use-voice-alerts@bvdr
```

After installing, invoke: `/enable-voice-alerts`

**Platform:** macOS

---

### [Setup Statusline](plugins/setup-statusline)

Interactive wizard to configure a custom Claude Code statusline.

- Folder display, git branch info, token usage bar
- Customizable accent colors
- Second line showing your last message

```bash
/plugin install setup-statusline@bvdr
```

After installing, invoke: `/setup-statusline`

**Platform:** macOS, Linux | **Requires:** `jq`, `git` (optional)

---

## Development

### Clone the Repository

```bash
git clone https://github.com/bvdr/claude-plugins.git
cd claude-plugins
```

### Install the Marketplace Locally

Add the local directory as a marketplace in your `~/.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "bvdr": {
      "source": {
        "source": "local",
        "path": "/path/to/claude-plugins"
      }
    }
  }
}
```

### Install a Plugin Directly from Local Files

```bash
claude plugins add /path/to/claude-plugins/plugins/<plugin-name>
```

### Test Hook Scripts

```bash
# Pipe JSON input to test hooks directly
echo '{"tool_name":"Bash","cwd":"/path","tool_input":{"command":"ls"}}' | bash plugins/interactive-notifications/hooks/interactive-permission.sh

# View debug logs
tail -f ~/.claude/hooks/debug.log
tail -f ~/.claude/hooks/permission.log
tail -f ~/.claude/hooks/smart-permissions.log
```

### Repository Structure

```
plugins/
├── smart-permissions/          # AI-powered auto-allow/deny hook
│   ├── hooks/                  # Bash scripts for PreToolUse + PermissionRequest
│   ├── permission-policy.md    # Customizable AI evaluation rules
│   └── manifest.json
├── interactive-notifications/  # Native macOS dialogs
│   ├── hooks/                  # Bash scripts for permissions, questions, idle, stop
│   └── manifest.json
├── macos-use-voice-alerts/     # Text-to-speech notifications
│   ├── commands/               # Skill markdown
│   └── .claude-plugin/
└── setup-statusline/           # Statusline configuration wizard
    ├── commands/               # Skill markdown
    └── .claude-plugin/
```

---

## Contributing

Contributions are welcome! To add a new plugin:

1. Fork this repository
2. Create a new directory under `plugins/`
3. Add required files (`manifest.json` or `.claude-plugin/plugin.json`, hooks, commands)
4. Update this README with documentation
5. Submit a pull request

---

## License

MIT License - see [LICENSE](LICENSE) for details.
