# bvdr-nightshift

Autonomous overnight codebase audit for Claude Code. Run `/night-shift` to dispatch a team of parallel audit agents that analyze your codebase across 9 domains and deliver a morning report.

## What It Does

When you type `/night-shift`, the plugin:

1. **Detects your tech stack** (Node, PHP, Python, Go, Rust, Ruby, WordPress, Laravel, Next.js, etc.)
2. **Dispatches up to 9 parallel audit agents**, each specializing in a domain
3. **Collects findings** with severity classification and urgency matrix
4. **Generates a dashboard report** saved locally as markdown
5. **Tracks trends** across nightly runs (improving vs deteriorating)
6. **Sends a Slack DM** with the condensed dashboard summary
7. **Creates Notion tasks** for findings that need human attention

## Audit Domains

| # | Domain | What It Checks |
|---|--------|----------------|
| 01 | Security Scan | Hardcoded secrets, SQL injection, XSS, missing auth, dangerous functions |
| 02 | Dependency Audit | CVEs, outdated packages, unused deps, abandoned packages |
| 03 | Code Quality | Linter violations, dead code, duplication, complexity, stale TODOs |
| 04 | Framework Updates | Plugin/package update safety with changelog + breaking change analysis |
| 05 | Architecture | God files, circular deps, coupling, pattern consistency, hotspots |
| 06 | Test Coverage | Missing tests, untested critical paths, test quality, suite health |
| 07 | Docs Drift | README accuracy, CLAUDE.md validity, stale docs, broken links |
| 08 | Performance | Slow queries, N+1 patterns, missing indexes, large assets, blocking I/O |
| 09 | Project Health | Git hygiene, TODO inventory, CI status, file cleanup, license compliance |

## Installation

```bash
claude plugin install bvdr-nightshift
```

Or from the marketplace:

```bash
claude plugin marketplace add bvdr
claude plugin install bvdr-nightshift
```

## Usage

```
/night-shift
```

That's it. The agent runs autonomously until done. Close your laptop, go to sleep.

## Report Output

Reports are saved to `{project_root}/reports/night-shift/YYYY-MM-DD.md` with a dashboard format:

```
# Night Shift Report - 2026-02-19

Project: my-app | Stack: Node, TypeScript, React, Next.js | Duration: 12m 34s | Domains: 9/9

## Dashboard

| Domain        | Status | Findings | Trend |
|---------------|--------|----------|-------|
| Security      | 🟢     | 0        | →     |
| Dependencies  | 🟡     | 3        | ↓     |
| Code Quality  | 🟡     | 14       | ↓     |
| ...           | ...    | ...      | ...   |

Total: 24 findings (was 28, ↓ fewer)
```

## Trend Tracking

Each run appends to `reports/night-shift/history.json`. Reports show improvement/regression arrows comparing against the previous night.

## Integrations

### Slack (optional)
Requires the `bvdr:send-slack-notification` skill to be configured. Sends a condensed dashboard to your DM channel.

### Notion (optional)
Requires the `Notion:notion-create-task` skill. Creates tasks in your Work Inbox for findings classified as Important or Urgent+Important.

### GitHub (optional)
Uses `gh` CLI if available to check open issues, PR status, and CI health.

## Severity & Urgency Matrix

Findings are classified on two independent axes:

| | Important | Not Important |
|---|---|---|
| **Urgent** | Notion task (High priority) + Report highlight | Report highlight only |
| **Not Urgent** | Notion task (Medium priority) + Report | Report appendix |

The agent decides which quadrant each finding belongs to based on:
- **Urgent**: Needs attention within 24-48 hours, time-sensitive
- **Important**: Significant impact on security, health, or maintainability

## Project Agnostic

Night Shift works on any codebase. It detects your stack automatically and adapts:
- Skips inapplicable checks (no npm audit for Python-only projects)
- Uses the right linters for your language
- Checks framework-specific patterns (WordPress, Laravel, Django, etc.)
- Falls back gracefully when tools aren't installed

## Configuration

No configuration needed. The plugin works out of the box. Optional integrations (Slack, Notion) require their respective skills to be set up independently.

## License

MIT
