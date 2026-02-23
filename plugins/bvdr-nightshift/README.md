# bvdr-nightshift

Autonomous deep codebase audit for Claude Code. Run `/night-shift` to dispatch a 2-level swarm of sequential Opus-powered auditors — 9 Level 1 audit domains + 6 Level 2 enhancement agents — with mandatory web research, unlimited depth, and stop/resume capability. Designed to run overnight.

## What It Does

When you type `/night-shift`, the plugin:

1. **Detects your tech stack** (Node, PHP, Python, Go, Rust, Ruby, WordPress, Laravel, Next.js, etc.)
2. **Level 1 — Dispatches 9 sequential Opus audit agents**, each specializing in a domain with 120 turns of deep analysis
3. **Level 2 — Dispatches 6 sequential enhancement agents** that build on Level 1 findings (simplification, docs, diagrams, remediation, correlation, PR review)
4. **Multi-pass analysis**: discover → read → analyze → research → report
5. **Mandatory web research** — every agent uses WebSearch to verify findings
6. **Stop/resume** — state persisted to `state.json` after each agent; if interrupted, resumes from where it stopped
7. **Generates a dashboard report** with executive summary, saved locally as markdown
8. **Tracks trends** across nightly runs (improving vs deteriorating)
9. **Reviews open PRs** — auto-reviews non-dependabot PRs with line-level feedback and separate review files
10. **Sends a Slack DM** with the condensed dashboard summary
11. **Creates Notion tasks** for findings that need human attention

## How It Works

Night Shift v2.1 uses a **2-level sequential execution model**:

- **Level 1** (9 audit domains): Scan the codebase for issues across security, dependencies, code quality, etc.
- **Level 2** (6 enhancement domains): Build on Level 1 findings with simplification suggestions, documentation updates, logic diagrams, remediation plans, cross-domain correlation, and PR code reviews.

Each agent runs to completion before the next one starts. This gives every agent:

- **Full context window** — no competing for shared resources
- **120 turns** — enough to read dozens of files, trace data flows, and run web research
- **Opus 4.6 model** — maximum reasoning capability for finding real bugs, not just pattern matches
- **Multi-pass analysis** — agents discover, read, analyze, research, and report

## Audit Domains

| # | Domain | Checks | What It Covers |
|---|--------|--------|----------------|
| 01 | Security Scan | 16 | Secrets, SQL injection, XSS, auth gaps, OWASP headers, rate limiting, session security, file upload, CSRF, directory traversal, info disclosure, deserialization |
| 02 | Dependency Audit | 9 | CVEs with deep web research, outdated packages, unused deps, abandoned packages, license conflicts, dependency tree depth, transitive vulnerability tracing |
| 03 | Code Quality | 12 | Linter violations, dead code, duplication, complexity, naming, stale TODOs, logic errors, type coercion bugs, unchecked returns, error handling gaps, copy-paste bugs, debug code |
| 04 | Framework Updates | 9 | Plugin/package updates with changelog analysis, PHP compatibility matrix, plugin conflict detection, deprecation timelines, security patch prioritization |
| 05 | Architecture | 12 | God files, circular deps, coupling, patterns, separation of concerns, dependency direction violations, feature entanglement, config sprawl, API surface mapping, state management, migration debt |
| 06 | Test Coverage | 9 | Missing tests, critical path coverage, test quality, coverage regression, suite health, flaky test detection, assertion density, boundary/edge case coverage, integration test gaps |
| 07 | Docs Drift | 10 | README accuracy, CLAUDE.md validity, API docs, comment accuracy, freshness, broken links, changelog accuracy, deployment docs, setup docs, API endpoint verification |
| 08 | Performance | 15 | Slow queries with EXPLAIN, N+1 patterns, unbounded queries, large assets, blocking I/O, pagination, memory leaks, autoloaded WP options, object cache, WP-Cron, asset loading, table sizes, HTTP chains, OPcache |
| 09 | Project Health | 12 | Git hygiene, TODO inventory, CI status, file cleanup, config health, license compliance, lock files, commit quality, branch naming, merge strategy, environment parity |

**Total: ~104 checks across 9 Level 1 domains.**

### Level 2: Enhancement Domains

| # | Domain | Purpose |
|---|--------|---------|
| 10 | Code Simplification | Identify overly complex code, suggest refactoring opportunities based on L1 findings |
| 11 | Documentation Updates | Find stale/missing docs, suggest updates driven by L1 findings |
| 12 | Logic Diagrams | Produce Mermaid diagrams for complex flows identified in audit |
| 13 | Remediation Planning | Group L1 findings into prioritized, actionable fix plans with effort estimates |
| 14 | Cross-Domain Correlation | Find systemic patterns across L1 domains, cascading risk chains |
| 15 | PR Code Review | Auto-review open non-dependabot PRs with line-level feedback and separate review files |

Level 2 agents receive all Level 1 findings as input (except domain 15, which reads PRs directly from GitHub).

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

## Performance Expectations

Night Shift trades speed for depth. Each domain agent runs sequentially with up to 120 turns of analysis, mandatory web research, and full file reads.

| Metric | v1.1 (Parallel Sonnet) | v2.0 (Sequential Opus) | v2.1 (2-Level Swarm) |
|--------|------------------------|------------------------|----------------------|
| Duration | 10-15 minutes | 2-4.5 hours | 3-6 hours |
| Agent model | Sonnet | Opus 4.6 | Opus 4.6 |
| Turns per domain | 30 | 120 | 120 |
| Domains | 9 | 9 | 15 (9 L1 + 6 L2) |
| Total checks | ~50 | ~104 | ~104 + L2 enhancements |
| Web research | Optional | Mandatory | Mandatory |
| File reads | Max 15 per domain | Unlimited | Unlimited |
| Finding depth | Pattern matching | Multi-pass analysis | Multi-pass + cross-domain |
| Stop/resume | No | No | Yes (state.json) |

**Designed for overnight runs.** Start it before bed, review the report in the morning.

## Report Output

Reports are saved to `{project_root}/reports/night-shift/YYYY-MM-DD.md` with a dashboard format including an executive summary:

```
# Night Shift Report - 2026-02-20

Project: my-app | Stack: PHP, WordPress, Node | Duration: 4h 30m | Domains: 15/15

## Executive Summary
The codebase is in generally good shape with no critical security vulnerabilities...

## Dashboard

| Domain                          | Status | Findings | Trend |
|---------------------------------|--------|----------|-------|
| Security                        | 🟢     | 2        | ↓     |
| Dependencies                    | 🟡     | 5        | →     |
| Code Quality                    | 🟡     | 14       | ↓     |
| ...                             | ...    | ...      | ...   |
| **--- Level 2: Enhancement ---**|        |          |       |
| Code Simplification             | 🟢     | 3        | —     |
| PR Code Review                  | 🟡     | 2        | —     |

Total: 54 findings (L1: 42, L2: 12) — was 42, ↓ improving
```

## Trend Tracking

Each run appends to `reports/night-shift/history.json`. Reports show improvement/regression arrows comparing against the previous night.

## Integrations

### Slack (optional)
Requires the `bvdr:send-slack-notification` skill to be configured. Sends a condensed dashboard to your DM channel. Critical security findings trigger an immediate alert before the full report.

### Notion (optional)
Requires the `Notion:notion-create-task` skill. Creates tasks in your Work Inbox for findings classified as Important or Urgent+Important.

### GitHub (optional)
Uses `gh` CLI if available to check open issues, PR status, and CI health. Domain 15 (PR Code Review) requires `gh auth status` to succeed — skipped automatically if not authenticated.

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

## Stop/Resume

Night Shift persists state to `reports/night-shift/state.json` after each agent completes. If interrupted (context limit, crash, manual stop), the next `/night-shift` run detects the in-progress state file and resumes from where it stopped — skipping completed phases and domains.

State tracks: completed phases, domain results, accumulated findings. If interrupted mid-domain, only that single domain reruns on resume.

## Changelog

### v2.1.0 — 2-Level Swarm with Resumability

Extends v2.0 with 6 new Level 2 enhancement agents and state persistence for stop/resume.

**New features:**
- **2-level swarm** — 6 Level 2 agents build on Level 1 findings (simplification, docs, diagrams, remediation, correlation, PR review)
- **Stop/resume** — state persisted to `state.json` after each agent; interrupted runs resume from where they stopped
- **PR code review** — auto-reviews open non-dependabot PRs with line-level feedback and separate review files per PR
- **15 domains total** — 9 Level 1 audit + 6 Level 2 enhancement

**Architecture:**
- Level 2 agents receive all Level 1 findings as JSON input
- Domain 15 (PR Code Review) is independent — reads PRs via `gh` CLI
- State file tracks phases, domain completion, and accumulated findings
- Report dashboard extended to 15 rows with L1/L2 separator

**Report changes:**
- Dashboard grows from 9 to 15 rows with visual Level 2 separator
- New "Level 2: Enhancement Analysis" report section
- Totals line shows L1/L2 breakdown
- History schema extended with L2 domain counts

### v2.0.0 — Deep Sequential Analysis Rewrite

Complete rewrite from shallow parallel audit to thorough sequential deep analysis.

**Architecture changes:**
- **Sequential execution** — agents run one at a time (not parallel), each with full context
- **Opus 4.6 model** — maximum reasoning capability (was Sonnet)
- **120 turns per domain** — unlimited depth for thorough analysis (was 30)
- **General-purpose agents** — full tool access including WebSearch (was Explore agents)
- **Multi-pass analysis** — discover → read → analyze → research → report
- **Mandatory web research** — every domain agent verifies findings against external sources
- **No artificial limits** — removed all context budget constraints, file read caps, and finding caps
- **Executive summary** — report now includes a prose summary of overall codebase health

**Domain expansions (50 → 104 checks):**
- Security: 8 → 16 checks (added OWASP headers, rate limiting, session security, file upload, CSRF, directory traversal, info disclosure, deserialization)
- Dependencies: 5 → 9 checks (added deep CVE research, license conflicts, tree depth, transitive tracing)
- Code Quality: 6 → 12 checks (added logic errors, type coercion, unchecked returns, error handling, copy-paste, debug code)
- Framework Updates: 5 → 9 checks (added PHP compatibility, plugin conflicts, deprecation timeline, security patches)
- Architecture: 6 → 12 checks (added dependency direction, feature entanglement, config sprawl, API surface, state management, migration debt)
- Test Coverage: 5 → 9 checks (added flaky tests, assertion density, boundary coverage, integration gaps)
- Docs Drift: 6 → 10 checks (added changelog, deployment docs, setup docs, API endpoint verification)
- Performance: 8 → 15 checks (added autoloaded options, object cache, WP-Cron, asset loading, table sizes, HTTP chains, OPcache)
- Project Health: 8 → 12 checks (added commit quality, branch naming, merge strategy, environment parity)

**Performance:**
- Expected duration: 2-4.5 hours (was 10-15 minutes)
- Designed for overnight execution

### v1.1.0 — Context Budget Fix

Fixed all 9 audit agents running out of context on large codebases.

**Changes:**
- Added context budget constraints to agent prompts
- Added `max_turns: 30` to agent dispatch
- Changed agent type to Explore (lighter agent)
- Set agent model to Sonnet

### v1.0.0 — Initial Release

First version of Night Shift with parallel Sonnet agents across 9 audit domains.

## Configuration

No configuration needed. The plugin works out of the box. Optional integrations (Slack, Notion) require their respective skills to be set up independently.

## License

MIT
