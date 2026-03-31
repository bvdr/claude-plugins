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

### Hook Plugins

#### [Smart Permissions](plugins/bvdr-smart-permissions)

AI-powered permission hook that auto-approves safe operations and auto-denies dangerous ones.

- **Layer 1**: Fast deterministic regex rules (~5ms) — no LLM involved
- **Layer 2**: Claude Haiku fallback for ambiguous cases (~8-10s)
- Composes with interactive-notifications as a fallback

```bash
/plugin install bvdr-smart-permissions@bvdr
```

**Platform:** macOS, Linux | **Requires:** `jq`, `claude` CLI (optional for Layer 2)

---

#### [Interactive Notifications](plugins/bvdr-interactive-notifications)

Respond to Claude Code from anywhere on your Mac via native macOS dialogs — no need to switch to the terminal.

- Permission dialogs with Yes / No / Reply buttons
- Question dialogs with buttons or selectable lists
- Idle alerts and task completion notifications
- Shows folder path, tool details, and your last request

```bash
/plugin install bvdr-interactive-notifications@bvdr
```

**Platform:** macOS | **Requires:** `jq`

---

### Autonomous Agent Plugins

#### [Ideation & Roadmap](plugins/bvdr-ideation-and-roadmap)

Deep AI-powered project analysis with parallel subagents, competitive research, and interactive HTML reports.

- **`/ideation`** — Dispatches 6 parallel agents analyzing code improvements, code quality, documentation, security, performance, and UI/UX
- **`/roadmap`** — Generates strategic feature roadmaps with MoSCoW prioritization across phases
- **Deep analysis foundation** — 500 commits, 1 year of merged PRs, open issues, web competitive research, Claude memory/beads context
- **Interactive HTML reports** — Clickable filter badges, thumbs up/down review, notes/comments overlay, GitHub issue links, one-click Copy-to-Claude sync
- **Review workflow** — Accept/dismiss ideas in the browser, add notes, then sync to Claude Code which updates JSON + creates GH issues
- **GitHub integration** — Auto-creates issues for accepted ideas with formatted bodies, labels, and issue tracker

```bash
/plugin install bvdr-ideation-and-roadmap@bvdr
```

**Commands:**

| Command | Description |
|---------|-------------|
| `/ideation` | Run all 6 ideation types |
| `/ideation --only sec,perf` | Run specific types (aliases: ci, cq, doc, sec, perf, ux) |
| `/ideation accept id1 id2` | Mark ideas as accepted |
| `/ideation dismiss id` | Mark idea as dismissed |
| `/ideation create-issues` | Create GH issues for accepted ideas |
| `/ideation status` | Show review summary |
| `/roadmap` | Generate full roadmap |
| `/roadmap --skip-discovery` | Reuse existing discovery, regenerate features |
| `/roadmap accept id1 id2` | Mark features as accepted |
| `/roadmap create-issues` | Create GH issues for accepted features |

**Platform:** macOS, Linux | **Requires:** `gh` CLI (optional, for GitHub integration)

---

#### [Night Shift](plugins/bvdr-nightshift)

Autonomous deep codebase audit with a 2-level agent swarm — 9 Level 1 audit domains + 6 Level 2 enhancement agents.

- Sequential Opus agents with state persistence for stop/resume
- Dashboard report with executive summary and trend tracking
- Slack summary and Notion task integration

```bash
/plugin install bvdr-nightshift@bvdr
```

**Platform:** macOS, Linux

---

### Skills Plugin

#### [bvdr](plugins/bvdr)

A collection of Claude Code skills for macOS productivity and Slack integration.

```bash
/plugin install bvdr@bvdr
```

**Included skills:**

| Skill | Command | Description |
|-------|---------|-------------|
| Umami Hub | `/bvdr:using-umami` | Entry point for all Umami Analytics operations — routes to setup, tracking, reports, or query skills |
| Umami Setup | `/bvdr:umami-setup` | Connect to a self-hosted Umami instance, install tracker script, configure `.umami.json` |
| Umami Track | `/bvdr:umami-track` | Implement tracking: custom events, user identification, data attributes, revenue, server-side events |
| Umami Reports | `/bvdr:umami-reports` | Create and run 8 report types: funnel, journey, retention, goals, UTM, attribution, breakdown, revenue |
| Umami Query | `/bvdr:umami-query` | Query stats, metrics, event data, sessions, realtime visitors via the Umami API |
| Voice Alerts | `/bvdr:enable-voice-alerts` | Verbal notifications using macOS text-to-speech when Claude needs attention or completes tasks |
| Setup Statusline | `/bvdr:setup-statusline` | Interactive wizard to configure a custom Claude Code statusline (folder display, git info, colors) |
| Setup Slack Notifications | `/bvdr:setup-slack-notifications` | Interactive setup wizard for creating a Slack bot and configuring your environment |
| Send Slack Notification | `/bvdr:send-slack-notification` | Send rich Slack messages with Block Kit formatting (text, code blocks, headers, status updates) |
| Gemini Evaluate | `/bvdr:evaluate` | Get a second opinion from Google's Gemini 3.1 Pro on Claude's last output |

**Platform:** macOS | **Requires:** `jq`, `git` (optional for statusline)

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
echo '{"tool_name":"Bash","cwd":"/path","tool_input":{"command":"ls"}}' | bash plugins/bvdr-interactive-notifications/hooks/interactive-permission.sh

# View debug logs
tail -f ~/.claude/hooks/debug.log
tail -f ~/.claude/hooks/permission.log
tail -f ~/.claude/hooks/smart-permissions.log
```

### Repository Structure

```
plugins/
├── bvdr-ideation-and-roadmap/     # Deep project analysis with parallel subagents
│   ├── .claude-plugin/plugin.json
│   ├── commands/                  # Orchestrator skills
│   │   ├── ideation.md              # /ideation — 6 parallel analysis agents
│   │   └── roadmap.md               # /roadmap — discovery + feature generation
│   ├── agents/                    # Subagent prompt files
│   │   ├── context/                 # Deep analysis (git, codebase, competitive)
│   │   ├── ideation/                # 6 ideation agents (adapted from Auto-Claude)
│   │   └── roadmap/                 # Discovery + features agents
│   └── assets/                    # Interactive HTML report templates
├── bvdr-nightshift/               # Autonomous codebase audit swarm
│   ├── .claude-plugin/plugin.json
│   ├── commands/night-shift.md
│   └── domains/                   # 15 audit domain agent prompts
├── bvdr-smart-permissions/        # AI-powered auto-allow/deny hook
│   ├── hooks/
│   ├── permission-policy.md
│   └── manifest.json
├── bvdr-interactive-notifications/ # Native macOS dialogs
│   ├── hooks/
│   └── manifest.json
└── bvdr/                          # Skills collection
    ├── commands/                  # Umami, Slack, voice alerts, statusline
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
