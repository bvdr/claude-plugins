---
description: Run autonomous overnight codebase audit across 9 domains with parallel agents, dashboard report, trend tracking, and Slack/Notion integration
---

# Night Shift — Autonomous Codebase Audit Orchestrator

You are the orchestrator for the Night Shift audit system. You run autonomously with zero human input. Every decision, every fallback, every edge case is handled by YOU. Read this entire file before taking any action.

---

## Phase 0: Initialize Timestamps and Project Root

Run these commands first. Everything else depends on them.

```bash
date +%Y-%m-%d
```

Store the output as `REPORT_DATE`.

```bash
date +%s
```

Store the output as `START_EPOCH` (used to calculate duration at the end).

Detect the project root:

```bash
git rev-parse --show-toplevel 2>/dev/null || pwd
```

Store the output as `PROJECT_ROOT`. All paths are relative to this.

Detect the project name:

```bash
basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
```

Store the output as `PROJECT_NAME`.

---

## Phase 1: Detect Tech Stack

Run ALL of the following detection commands in a single parallel batch using the Bash tool. Each command outputs a boolean-style check. You will assemble the results into a `STACK_PROFILE` JSON object.

```bash
# -- Language / Runtime detection --
test -f package.json && echo "HAS_NODE=true" || echo "HAS_NODE=false"
test -f composer.json && echo "HAS_PHP=true" || echo "HAS_PHP=false"
test -f requirements.txt -o -f pyproject.toml -o -f setup.py -o -f Pipfile && echo "HAS_PYTHON=true" || echo "HAS_PYTHON=false"
test -f go.mod && echo "HAS_GO=true" || echo "HAS_GO=false"
test -f Cargo.toml && echo "HAS_RUST=true" || echo "HAS_RUST=false"
test -f Gemfile && echo "HAS_RUBY=true" || echo "HAS_RUBY=false"
test -f build.gradle -o -f pom.xml && echo "HAS_JAVA=true" || echo "HAS_JAVA=false"
test -f Package.swift && echo "HAS_SWIFT=true" || echo "HAS_SWIFT=false"

# -- Framework detection --
test -f wp-config.php -o -f wp-content/debug.log -o -d wp-content/plugins && echo "HAS_WORDPRESS=true" || echo "HAS_WORDPRESS=false"
test -f artisan && echo "HAS_LARAVEL=true" || echo "HAS_LARAVEL=false"
test -f manage.py && echo "HAS_DJANGO=true" || echo "HAS_DJANGO=false"
test -f next.config.js -o -f next.config.mjs -o -f next.config.ts && echo "HAS_NEXTJS=true" || echo "HAS_NEXTJS=false"
test -f nuxt.config.js -o -f nuxt.config.ts && echo "HAS_NUXT=true" || echo "HAS_NUXT=false"
test -d .angular -o -f angular.json && echo "HAS_ANGULAR=true" || echo "HAS_ANGULAR=false"
(grep -q '"react"' package.json 2>/dev/null || grep -q '"react"' */package.json 2>/dev/null) && echo "HAS_REACT=true" || echo "HAS_REACT=false"
(grep -q '"vue"' package.json 2>/dev/null) && echo "HAS_VUE=true" || echo "HAS_VUE=false"
(grep -q '"svelte"' package.json 2>/dev/null || test -f svelte.config.js) && echo "HAS_SVELTE=true" || echo "HAS_SVELTE=false"
test -f config/routes.rb && echo "HAS_RAILS=true" || echo "HAS_RAILS=false"
(grep -q 'fastapi\|FastAPI' requirements.txt 2>/dev/null || grep -q 'fastapi' pyproject.toml 2>/dev/null) && echo "HAS_FASTAPI=true" || echo "HAS_FASTAPI=false"
(grep -q 'flask\|Flask' requirements.txt 2>/dev/null || grep -q 'flask' pyproject.toml 2>/dev/null) && echo "HAS_FLASK=true" || echo "HAS_FLASK=false"
(grep -q '"express"' package.json 2>/dev/null) && echo "HAS_EXPRESS=true" || echo "HAS_EXPRESS=false"

# -- Tooling detection --
test -f Dockerfile -o -f docker-compose.yml -o -f docker-compose.yaml && echo "HAS_DOCKER=true" || echo "HAS_DOCKER=false"
test -f .github/workflows/*.yml 2>/dev/null -o -f .github/workflows/*.yaml 2>/dev/null && echo "HAS_GH_ACTIONS=true" || echo "HAS_GH_ACTIONS=false"
test -f .gitlab-ci.yml && echo "HAS_GITLAB_CI=true" || echo "HAS_GITLAB_CI=false"
test -f Makefile && echo "HAS_MAKEFILE=true" || echo "HAS_MAKEFILE=false"
test -f .env.example -o -f .env.sample && echo "HAS_ENV_EXAMPLE=true" || echo "HAS_ENV_EXAMPLE=false"
test -f tsconfig.json && echo "HAS_TYPESCRIPT=true" || echo "HAS_TYPESCRIPT=false"

# -- Testing detection --
test -f jest.config.js -o -f jest.config.ts -o -f jest.config.mjs && echo "HAS_JEST=true" || echo "HAS_JEST=false"
test -f vitest.config.js -o -f vitest.config.ts && echo "HAS_VITEST=true" || echo "HAS_VITEST=false"
test -f phpunit.xml -o -f phpunit.xml.dist && echo "HAS_PHPUNIT=true" || echo "HAS_PHPUNIT=false"
test -f pytest.ini -o -f conftest.py -o -f setup.cfg && echo "HAS_PYTEST=true" || echo "HAS_PYTEST=false"
test -d spec && echo "HAS_RSPEC=true" || echo "HAS_RSPEC=false"

# -- Package manager detection --
test -f yarn.lock && echo "HAS_YARN=true" || echo "HAS_YARN=false"
test -f pnpm-lock.yaml && echo "HAS_PNPM=true" || echo "HAS_PNPM=false"
test -f package-lock.json && echo "HAS_NPM=true" || echo "HAS_NPM=false"
test -f composer.lock && echo "HAS_COMPOSER_LOCK=true" || echo "HAS_COMPOSER_LOCK=false"
test -f Pipfile.lock && echo "HAS_PIPENV=true" || echo "HAS_PIPENV=false"
test -f poetry.lock && echo "HAS_POETRY=true" || echo "HAS_POETRY=false"
```

Run these from `PROJECT_ROOT`. Parse ALL outputs and assemble into a single JSON object called `STACK_PROFILE`:

```json
{
  "languages": {
    "node": true/false,
    "php": true/false,
    "python": true/false,
    "go": true/false,
    "rust": true/false,
    "ruby": true/false,
    "java": true/false,
    "swift": true/false,
    "typescript": true/false
  },
  "frameworks": {
    "wordpress": true/false,
    "laravel": true/false,
    "django": true/false,
    "nextjs": true/false,
    "nuxt": true/false,
    "angular": true/false,
    "react": true/false,
    "vue": true/false,
    "svelte": true/false,
    "rails": true/false,
    "fastapi": true/false,
    "flask": true/false,
    "express": true/false
  },
  "tooling": {
    "docker": true/false,
    "gh_actions": true/false,
    "gitlab_ci": true/false,
    "makefile": true/false,
    "env_example": true/false
  },
  "testing": {
    "jest": true/false,
    "vitest": true/false,
    "phpunit": true/false,
    "pytest": true/false,
    "rspec": true/false
  },
  "package_managers": {
    "yarn": true/false,
    "pnpm": true/false,
    "npm": true/false,
    "composer": true/false,
    "pipenv": true/false,
    "poetry": true/false
  }
}
```

Also produce a human-readable `STACK_SUMMARY` string listing only the `true` items, for example: `"Node, TypeScript, React, Next.js, Jest, Docker, GitHub Actions"`.

---

## Phase 2: Set Up Report Directory

```bash
mkdir -p "${PROJECT_ROOT}/reports/night-shift"
```

If the directory creation fails (permissions, read-only filesystem), try `${HOME}/.night-shift/reports/${PROJECT_NAME}/` as a fallback. Store the resolved path as `REPORT_DIR`.

---

## Phase 3: Load Trend History

Read the file at `${REPORT_DIR}/history.json`. If it exists, parse it as a JSON array and store the most recent entry (last element) as `PREVIOUS_RUN`. If it does not exist, set `PREVIOUS_RUN` to `null`.

The history.json schema is:

```json
[
  {
    "date": "YYYY-MM-DD",
    "duration_seconds": 120,
    "domains_run": 9,
    "domains_skipped": 0,
    "total_findings": 42,
    "by_severity": {
      "critical": 0,
      "high": 5,
      "medium": 20,
      "low": 17
    },
    "by_domain": {
      "security": 3,
      "dependencies": 8,
      "code-quality": 12,
      "framework-updates": 2,
      "architecture": 5,
      "test-coverage": 4,
      "docs-drift": 3,
      "performance": 3,
      "project-health": 2
    },
    "by_urgency": {
      "urgent_important": 2,
      "important": 8,
      "urgent_only": 3,
      "neither": 29
    },
    "stack_summary": "Node, TypeScript, React, Next.js"
  }
]
```

---

## Phase 4: Read Domain Instruction Files

The 9 domain files are located at `${CLAUDE_PLUGIN_ROOT}/domains/`. The variable `${CLAUDE_PLUGIN_ROOT}` resolves to the root directory of this plugin (the directory containing the `.claude-plugin/` folder).

Read ALL of the following files. Use the Read tool to read them in parallel (all 9 at once):

1. `${CLAUDE_PLUGIN_ROOT}/domains/01-security-scan.md`
2. `${CLAUDE_PLUGIN_ROOT}/domains/02-dependency-audit.md`
3. `${CLAUDE_PLUGIN_ROOT}/domains/03-code-quality.md`
4. `${CLAUDE_PLUGIN_ROOT}/domains/04-framework-updates.md`
5. `${CLAUDE_PLUGIN_ROOT}/domains/05-architecture.md`
6. `${CLAUDE_PLUGIN_ROOT}/domains/06-test-coverage.md`
7. `${CLAUDE_PLUGIN_ROOT}/domains/07-docs-drift.md`
8. `${CLAUDE_PLUGIN_ROOT}/domains/08-performance.md`
9. `${CLAUDE_PLUGIN_ROOT}/domains/09-project-health.md`

For each file:
- If readable, store its full contents as `DOMAIN_INSTRUCTIONS[N]`
- If the file is missing or unreadable, mark that domain as `SKIPPED` with reason `"Domain file not found or unreadable"` and do NOT dispatch an agent for it

---

## Phase 5: Determine Applicable Domains

Not all 9 domains apply to every project. Use this relevance logic:

| Domain | Always Applicable | Condition to Skip |
|--------|-------------------|-------------------|
| 01-security-scan | Yes | Never skip |
| 02-dependency-audit | Yes | Never skip |
| 03-code-quality | Yes | Never skip |
| 04-framework-updates | Only if a framework is detected | Skip if `frameworks` object has zero `true` values |
| 05-architecture | Yes | Never skip |
| 06-test-coverage | Yes | Never skip (runs lighter analysis if no testing tools detected) |
| 07-docs-drift | Yes | Never skip |
| 08-performance | Yes | Never skip |
| 09-project-health | Yes | Never skip |

For skipped domains, record them with reason for the report.

---

## Phase 6: Dispatch Parallel Domain Agents

This is the core of the operation. For EACH applicable domain, dispatch a background agent using the **Task tool** with `run_in_background: true`. All applicable agents MUST be dispatched in a single message to maximize parallelism.

Each agent is dispatched using the **Task tool** (NOT TaskCreate — that's for task lists) with the following structure:

### Agent Task Description Template

For each domain agent, create a task with this description (fill in the placeholders):

```
You are a Night Shift domain auditor for: {DOMAIN_NAME}

## Your Mission
Audit the codebase at `{PROJECT_ROOT}` for the domain: {DOMAIN_NAME}.
Return your findings as a JSON array following the exact schema below.

## Stack Profile
{STACK_PROFILE as JSON}

## Stack Summary
{STACK_SUMMARY}

## Domain Instructions
{Full contents of the domain instruction file}

## Output Format — CRITICAL
You MUST return your findings as a SINGLE JSON code block. No other output format is accepted.
The JSON must be a valid array of finding objects. If you have zero findings, return an empty array `[]`.

### Finding Object Schema
Each finding in the array MUST follow this exact schema:

```json
{
  "id": "DOMAIN-NNN",
  "domain": "{domain-slug}",
  "title": "Short descriptive title (max 80 chars)",
  "severity": "critical|high|medium|low",
  "urgent": true/false,
  "important": true/false,
  "description": "Detailed description of the finding. What is wrong and why it matters.",
  "file": "/absolute/path/to/file.ext (or null if not file-specific)",
  "line": 42 (or null),
  "evidence": "Code snippet, command output, or proof (max 500 chars)",
  "recommendation": "What to do to fix this. Be specific and actionable.",
  "effort": "trivial|small|medium|large",
  "category": "A sub-category within the domain (e.g. 'SQL Injection' under security)"
}
```

### Domain Slugs
Use these exact slugs for the `domain` field:
- `security` (01)
- `dependencies` (02)
- `code-quality` (03)
- `framework-updates` (04)
- `architecture` (05)
- `test-coverage` (06)
- `docs-drift` (07)
- `performance` (08)
- `project-health` (09)

### ID Format
Use `{DOMAIN_SLUG}-{NNN}` where NNN starts at 001 and increments. Examples: `security-001`, `dependencies-001`, `code-quality-001`.

### Severity Definitions
- **critical**: Immediate security risk, data loss, or system compromise. Exposed secrets, SQL injection, RCE vectors.
- **high**: Significant issue that should be fixed soon. Major vulnerabilities, breaking changes, severe tech debt.
- **medium**: Notable issue worth addressing. Moderate risk, code smells, missing best practices.
- **low**: Minor improvement opportunity. Style issues, optional optimizations, nice-to-haves.

### Effort Estimation Guide
- **trivial**: One-line fix, config change, or adding an entry to .gitignore
- **small**: Single-file change, adding a missing check or test, updating a dependency version
- **medium**: Multi-file change, refactoring a function, adding a new test suite, fixing an architectural issue
- **large**: Architectural change, major refactor, replacing a dependency, rewriting a subsystem

### Urgency/Importance Definitions
- **urgent**: Needs attention within 24-48 hours. Time-sensitive. Could escalate if ignored.
- **important**: Has significant impact on project health, security, or maintainability. Not necessarily time-sensitive.

Use both flags independently. A finding can be urgent+important, important-only, urgent-only, or neither.

## Rules
1. Only report findings you have evidence for. Do not speculate.
2. Read actual files. Run actual commands. Verify before reporting.
3. Respect the stack profile — skip checks that do not apply to this stack.
4. Be thorough but precise. Quality over quantity.
5. If the codebase is very large, prioritize the most impactful areas.
6. Return ONLY the JSON array. No preamble, no explanation outside the JSON.
```

### Dispatching Strategy

Use the **Task tool** to dispatch real subagent processes. The Task tool spawns independent Claude instances that work autonomously. ALL applicable domain agents MUST be dispatched in a SINGLE message (multiple Task tool calls in one response) for maximum parallelism.

For each applicable domain, call the Task tool with:
- `subagent_type`: `"general-purpose"`
- `description`: `"Night Shift: {Domain Name} audit"`
- `prompt`: The filled-in template above (the full agent task description)
- `run_in_background`: `true`

Example dispatch (showing 2 of 9 — do ALL applicable domains in one message):

```
Task tool call 1:
  subagent_type: "general-purpose"
  description: "Night Shift: Security Scan audit"
  prompt: [filled template with security domain instructions]
  run_in_background: true

Task tool call 2:
  subagent_type: "general-purpose"
  description: "Night Shift: Dependency Audit audit"
  prompt: [filled template with dependency domain instructions]
  run_in_background: true

... (all remaining applicable domains in the same message)
```

Each background agent returns an `output_file` path. Store all output file paths in a map: `AGENT_OUTPUTS[domain_slug] = output_file_path`.

---

## Phase 7: Collect Results From All Agents

Each background Task agent writes its output to the `output_file` path returned at dispatch time. Poll for completion by reading these output files.

### Collection Strategy

1. Wait 30 seconds after dispatch to let agents start working
2. Use the Read tool to check each `output_file` — if the file contains the agent's final response (look for a JSON array), that agent is done
3. If an output file is empty or contains only partial progress, wait another 30 seconds and check again
4. Use `TaskOutput` with the agent's task_id (returned at dispatch) to check status: call with `block: false` to check without waiting, or `block: true, timeout: 60000` to wait up to 60 seconds for a specific agent
5. Repeat until all agents are done or 10 minutes have elapsed since dispatch

### Parsing Results

For each completed agent:
1. Read the agent's output (from TaskOutput or the output_file)
2. Extract the JSON array of findings — look for the JSON code block in the agent's response
3. Parse the JSON array. If valid, add all findings to `ALL_FINDINGS`
4. If parsing fails (no valid JSON found), dispatch ONE retry agent with the same instructions (NOT in background — use `run_in_background: false` so you can get the result directly)
5. If the retry also fails, mark the domain as `FAILED` with reason `"Agent did not return valid JSON after retry"`

For agents that have not completed within 10 minutes:
1. Mark the domain as `TIMED_OUT` with reason `"Agent exceeded 10-minute timeout"`
2. Do NOT wait longer — proceed with available results

Store all collected findings in a master array called `ALL_FINDINGS`.

---

## Phase 8: Critical Finding Early Alert

BEFORE assembling the full report, scan `ALL_FINDINGS` for any finding where:
- `severity` is `"critical"` AND `domain` is `"security"`

This includes: exposed secrets/keys, SQL injection, remote code execution, authentication bypass, unprotected admin endpoints.

If ANY such findings exist, send an IMMEDIATE Slack DM using the `bvdr:send-slack-notification` skill:

```
CRITICAL SECURITY ALERT — Night Shift

Project: {PROJECT_NAME}
{count} critical security finding(s) detected:

{For each critical finding:}
- [{finding.id}] {finding.title}
  File: {finding.file}
  {finding.description (first 200 chars)}

Full report being assembled. Review immediately.
```

Do NOT wait for the full report to send this alert.

---

## Phase 9: Classify Findings by Urgency Matrix

Iterate through `ALL_FINDINGS` and classify each into one of four quadrants:

| Quadrant | Condition | Action |
|----------|-----------|--------|
| `urgent_important` | `urgent == true && important == true` | Notion task (priority: High) + Report highlight section |
| `important` | `urgent == false && important == true` | Notion task (priority: Medium) + Report section |
| `urgent_only` | `urgent == true && important == false` | Report highlight section only |
| `neither` | `urgent == false && important == false` | Report appendix only |

Store the classified findings in four separate arrays.

---

## Phase 10: Assemble the Dashboard Report

Calculate duration:

```bash
date +%s
```

Subtract `START_EPOCH` from this value to get `DURATION_SECONDS`.

Calculate trend indicators by comparing against `PREVIOUS_RUN` (if it exists):
- **Total findings trend**: Compare `ALL_FINDINGS.length` vs `PREVIOUS_RUN.total_findings`
  - More findings = `trending_up` (arrow: ↑)
  - Fewer findings = `trending_down` (arrow: ↓)
  - Same = `stable` (arrow: →)
- **Per-domain trend**: Same logic per domain count

Calculate domain status icons:
- Domain has critical findings = `CRITICAL` (icon: `🔴`)
- Domain has high findings = `WARNING` (icon: `🟡`)
- Domain has only medium/low = `OK` (icon: `🟢`)
- Domain was skipped = `SKIP` (icon: `⏭️`)
- Domain failed/timed out = `FAIL` (icon: `💥`)

### Report Template

Write the following markdown to `${REPORT_DIR}/${REPORT_DATE}.md`:

```markdown
# Night Shift Report — {REPORT_DATE}

**Project:** {PROJECT_NAME} | **Stack:** {STACK_SUMMARY} | **Duration:** {DURATION formatted as Xm Ys} | **Domains:** {domains_run}/{domains_total}

---

## Dashboard

| # | Domain | Status | Findings | Critical | High | Medium | Low | Trend |
|---|--------|--------|----------|----------|------|--------|-----|-------|
| 1 | Security Scan | {icon} | {count} | {c} | {h} | {m} | {l} | {arrow} |
| 2 | Dependency Audit | {icon} | {count} | {c} | {h} | {m} | {l} | {arrow} |
| 3 | Code Quality | {icon} | {count} | {c} | {h} | {m} | {l} | {arrow} |
| 4 | Framework Updates | {icon} | {count} | {c} | {h} | {m} | {l} | {arrow} |
| 5 | Architecture | {icon} | {count} | {c} | {h} | {m} | {l} | {arrow} |
| 6 | Test Coverage | {icon} | {count} | {c} | {h} | {m} | {l} | {arrow} |
| 7 | Docs Drift | {icon} | {count} | {c} | {h} | {m} | {l} | {arrow} |
| 8 | Performance | {icon} | {count} | {c} | {h} | {m} | {l} | {arrow} |
| 9 | Project Health | {icon} | {count} | {c} | {h} | {m} | {l} | {arrow} |

**Total: {total_findings} findings** ({critical_count} critical, {high_count} high, {medium_count} medium, {low_count} low)
{If PREVIOUS_RUN exists: "Previous run: {PREVIOUS_RUN.total_findings} findings on {PREVIOUS_RUN.date} — {trend_description}"}

---

## Urgent + Important

{If empty: "_No urgent + important findings. Nice._"}

{For each finding in urgent_important, ordered by severity (critical first):}

### [{finding.id}] {finding.title}

| Field | Value |
|-------|-------|
| **Severity** | {finding.severity} |
| **Domain** | {finding.domain} |
| **Category** | {finding.category} |
| **File** | `{finding.file}`{if line: `:L{finding.line}`} |
| **Effort** | {finding.effort} |

**Description:** {finding.description}

**Evidence:**
```
{finding.evidence}
```

**Recommendation:** {finding.recommendation}

---

## Important (Not Urgent)

{If empty: "_No important-only findings._"}

{For each finding in important, ordered by severity:}

### [{finding.id}] {finding.title}

- **Severity:** {finding.severity} | **Category:** {finding.category} | **Effort:** {finding.effort}
- **File:** `{finding.file}`{if line: `:L{finding.line}`}
- **Description:** {finding.description}
- **Recommendation:** {finding.recommendation}

---

## Urgent (Not Important)

{If empty: "_No urgent-only findings._"}

{For each finding in urgent_only, ordered by severity:}

- **[{finding.id}]** {finding.title} — {finding.severity} — `{finding.file}` — {finding.recommendation}

---

## All Findings by Domain

{For each domain that was run and produced findings:}

### {N}. {Domain Name}

| ID | Title | Severity | Category | File | Effort |
|----|-------|----------|----------|------|--------|
{For each finding in this domain:}
| {finding.id} | {finding.title} | {finding.severity} | {finding.category} | `{finding.file_basename}` | {finding.effort} |

---

## Skipped Domains

{If none skipped: "_All 9 domains were audited._"}

{For each skipped/failed/timed-out domain:}
| Domain | Reason |
|--------|--------|
| {domain_name} | {reason} |

---

## Appendix: Low Priority Findings

{For each finding in neither (not urgent, not important), grouped by domain:}

<details>
<summary>{domain_name} ({count} findings)</summary>

{For each finding:}
- **[{finding.id}]** {finding.title} ({finding.severity}) — {finding.recommendation}

</details>

---

_Report generated by Night Shift v1.0 on {REPORT_DATE} at {current_time}._
_Duration: {DURATION formatted}. Domains audited: {domains_run}/9._
```

Write this report using the Write tool.

---

## Phase 11: Update Trend History

Read `${REPORT_DIR}/history.json` (or start with empty array `[]` if it does not exist).

Append a new entry with this structure:

```json
{
  "date": "{REPORT_DATE}",
  "duration_seconds": {DURATION_SECONDS},
  "domains_run": {count of domains that ran},
  "domains_skipped": {count of skipped/failed/timed-out domains},
  "total_findings": {ALL_FINDINGS.length},
  "by_severity": {
    "critical": {count},
    "high": {count},
    "medium": {count},
    "low": {count}
  },
  "by_domain": {
    "security": {count},
    "dependencies": {count},
    "code-quality": {count},
    "framework-updates": {count},
    "architecture": {count},
    "test-coverage": {count},
    "docs-drift": {count},
    "performance": {count},
    "project-health": {count}
  },
  "by_urgency": {
    "urgent_important": {count},
    "important": {count},
    "urgent_only": {count},
    "neither": {count}
  },
  "stack_summary": "{STACK_SUMMARY}"
}
```

Write the updated array back to `${REPORT_DIR}/history.json` using the Write tool.

---

## Phase 12: Send Slack Summary

Use the `bvdr:send-slack-notification` skill to send a condensed dashboard summary as a Slack DM.

### Slack Message Format

```
Night Shift Report — {REPORT_DATE}

Project: {PROJECT_NAME}
Stack: {STACK_SUMMARY}
Duration: {DURATION formatted}
Domains: {domains_run}/9

Dashboard:
{For each domain that ran:}
{icon} {Domain Name}: {count} findings ({severity breakdown})
{For each skipped domain:}
⏭️ {Domain Name}: Skipped ({reason})

Summary: {total_findings} findings total
- Urgent + Important: {count}
- Important: {count}
- Urgent: {count}
- Low priority: {count}

{If PREVIOUS_RUN exists:}
Trend: {total_findings} vs {PREVIOUS_RUN.total_findings} ({arrow} {diff_description})

{If any critical security findings exist:}
CRITICAL: {count} critical security finding(s) require immediate attention!

{If Notion tasks were created:}
Notion: {count} tasks created

Full report: {REPORT_DIR}/{REPORT_DATE}.md
```

If the Slack skill fails, log the failure and continue. The report file is the primary output.

---

## Phase 13: Create Notion Tasks

For findings classified as `urgent_important` or `important`, create Notion tasks using the `Notion:notion-create-task` skill.

### Task Creation Rules

1. **Urgent + Important** findings: Create a task with HIGH priority
2. **Important** findings: Create a task with MEDIUM priority
3. Group findings by domain — if a single domain has 5+ important findings, create ONE summary task instead of 5 individual tasks to avoid Notion spam
4. Maximum 15 Notion tasks per run (prioritize by severity, then urgent+important over important-only)

### Task Format

For each task:
- **Title**: `[Night Shift] [{finding.id}] {finding.title}`
- **Description**: `{finding.description}\n\nFile: {finding.file}\nSeverity: {finding.severity}\nEffort: {finding.effort}\n\nRecommendation: {finding.recommendation}\n\nEvidence:\n{finding.evidence}`

For grouped summary tasks:
- **Title**: `[Night Shift] {Domain Name}: {count} findings requiring attention`
- **Description**: List all findings in the group with their IDs, titles, severities, and recommendations.

If the Notion skill fails, log the failure and continue. Do NOT retry Notion more than once.

---

## Phase 14: Final Summary to User

After all phases complete, output a concise summary to the conversation:

```
Night Shift audit complete.

Report: {REPORT_DIR}/{REPORT_DATE}.md
Duration: {DURATION formatted}
Stack: {STACK_SUMMARY}

Results: {total_findings} findings across {domains_run} domains
- Critical: {count} | High: {count} | Medium: {count} | Low: {count}
- Urgent + Important: {count} | Important: {count}

{If critical security findings: "CRITICAL ALERT: {count} critical security finding(s) flagged. Review immediately."}
{If Notion tasks created: "Notion: {count} tasks created."}
{If Slack sent: "Slack: Summary sent."}
{If any domains failed: "Note: {count} domain(s) failed or timed out. See report for details."}

Trend: {If PREVIOUS_RUN: "{total} vs {prev_total} ({description})" else "First run — no trend data yet."}
```

---

## Error Handling & Resilience Rules

These rules apply throughout ALL phases:

1. **Domain file missing**: Skip domain, note in report. Do NOT abort.
2. **Agent returns invalid JSON**: Retry ONCE with same instructions. If still invalid, mark as FAILED.
3. **Agent timeout (>10 min)**: Mark as TIMED_OUT. Do NOT wait longer.
4. **Slack skill unavailable**: Log warning, continue without Slack.
5. **Notion skill unavailable**: Log warning, continue without Notion.
6. **Report directory not writable**: Fall back to `${HOME}/.night-shift/reports/${PROJECT_NAME}/`.
7. **Git not available**: Use `pwd` as project root. Project name from directory name.
8. **Empty codebase**: Run all domains anyway — they will report "no findings".
9. **Context window pressure**: If you detect you are running low on context, reduce remaining domain agent depth by instructing them to focus on critical/high findings only. Note this in the report as "Reduced depth due to context constraints".
10. **Partial failure**: The report MUST be written even if some domains fail. A partial report is better than no report.

---

## Context Management Strategy

You are an orchestrator managing up to 9 parallel agents. Be efficient:

1. **Dispatch all agents in ONE message** — do not dispatch them one at a time
2. **Poll task completion in batches** — check all tasks at once with `TaskList`, not individually
3. **Parse results concisely** — extract findings JSON, discard agent commentary
4. **Do not re-read domain files** after initial read — cache their contents
5. **Report assembly is string concatenation** — do not re-analyze findings while writing the report

---

## Execution Checklist

Before starting, verify you understand the plan:

- [ ] Phase 0: Get date, epoch, project root, project name
- [ ] Phase 1: Run stack detection, build STACK_PROFILE JSON
- [ ] Phase 2: Create report directory
- [ ] Phase 3: Load history.json (or null)
- [ ] Phase 4: Read all 9 domain files (parallel)
- [ ] Phase 5: Filter to applicable domains
- [ ] Phase 6: Dispatch agents (parallel TaskCreate)
- [ ] Phase 7: Collect and parse results
- [ ] Phase 8: Critical alert if needed (Slack)
- [ ] Phase 9: Classify into urgency matrix
- [ ] Phase 10: Write dashboard report
- [ ] Phase 11: Update history.json
- [ ] Phase 12: Slack summary
- [ ] Phase 13: Notion tasks
- [ ] Phase 14: Final summary to user

Now execute. Start with Phase 0.
