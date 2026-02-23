---
description: Run autonomous deep codebase audit across 15 domains with sequential Opus agents, dashboard report, trend tracking, and Slack/Notion integration
---

# Night Shift v2.1 — Autonomous Deep Codebase Audit Orchestrator

You are the orchestrator for the Night Shift audit system. You run autonomously with zero human input. Every decision, every fallback, every edge case is handled by YOU. Read this entire file before taking any action.

---

## Phase 0: Initialize State and Project Root

This phase handles both fresh starts and resumed runs. Follow the three steps in order.

### Step 1: Check for existing state file

The state file lives at `${REPORT_DIR}/state.json`, where `REPORT_DIR` defaults to `${PROJECT_ROOT}/reports/night-shift`. Since we may not know `PROJECT_ROOT` yet on a fresh run, first attempt to detect it:

```bash
git rev-parse --show-toplevel 2>/dev/null || pwd
```

Store as `PROJECT_ROOT` (may be overwritten if resuming). Set `REPORT_DIR` to `${PROJECT_ROOT}/reports/night-shift`.

Now attempt to read `${REPORT_DIR}/state.json`:

- **If the file exists and contains valid JSON with `status == "in_progress"`:**
  - Log: `"Resuming Night Shift run from {run_id}"`
  - Load all cached data from the state file: `project_root`, `project_name`, `stack_profile`, `stack_summary`, `start_epoch`, `findings`
  - Override `PROJECT_ROOT`, `PROJECT_NAME`, `REPORT_DIR`, `START_EPOCH`, `REPORT_DATE` with the values from the state file
  - If `stack_profile` is not null, restore `STACK_PROFILE` and `STACK_SUMMARY`
  - If `findings.level1` or `findings.level2` are non-empty, restore them into `ALL_FINDINGS`
  - Set `RESUMING = true`
  - Determine the first incomplete phase by scanning `phases` for the first entry where `status != "completed"` — skip directly to that phase

- **If the file exists and contains valid JSON with `status == "completed"`:**
  - Log: `"Previous run completed. Starting fresh."`
  - Delete the state file
  - Set `RESUMING = false`

- **If the file is missing, empty, or contains invalid JSON:**
  - Set `RESUMING = false`

### Step 2: Initialize timestamps and project info (only if not resuming)

If `RESUMING == true`, skip this step entirely — all values were loaded from state.

Run these commands first. Everything else depends on them.

```bash
date +%Y-%m-%d
```

Store the output as `REPORT_DATE`.

```bash
date +%s
```

Store the output as `START_EPOCH` (used to calculate duration at the end).

Detect the project root (if not already set):

```bash
git rev-parse --show-toplevel 2>/dev/null || pwd
```

Store the output as `PROJECT_ROOT`. All paths are relative to this.

Detect the project name:

```bash
basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
```

Store the output as `PROJECT_NAME`.

### Step 3: Write initial state file (only if not resuming)

If `RESUMING == true`, skip this step — the state file already exists.

Ensure the report directory exists:

```bash
mkdir -p "${PROJECT_ROOT}/reports/night-shift"
```

Store the resolved path as `REPORT_DIR` (or fall back to `${HOME}/.night-shift/reports/${PROJECT_NAME}/` if creation fails).

Write the initial `state.json` to `${REPORT_DIR}/state.json` with this schema:

```json
{
  "version": "2.1",
  "run_id": "{ISO 8601 timestamp, e.g. 2026-02-23T03:14:00Z}",
  "report_date": "{REPORT_DATE}",
  "project_root": "{PROJECT_ROOT}",
  "project_name": "{PROJECT_NAME}",
  "stack_profile": null,
  "stack_summary": null,
  "status": "in_progress",
  "start_epoch": "{START_EPOCH}",
  "phases": {
    "init": { "status": "completed", "completed_at": "{ISO 8601 timestamp}" },
    "stack_detect": { "status": "pending" },
    "report_dir": { "status": "pending" },
    "history_load": { "status": "pending" },
    "read_domains": { "status": "pending" },
    "filter_domains": { "status": "pending" },
    "level1_dispatch": {
      "status": "pending",
      "domains_completed": [],
      "domains_pending": [],
      "domains_skipped": [],
      "domains_failed": []
    },
    "level2_dispatch": {
      "status": "pending",
      "domains_completed": [],
      "domains_pending": [],
      "domains_skipped": [],
      "domains_failed": []
    },
    "validate": { "status": "pending" },
    "critical_alert": { "status": "pending" },
    "classify": { "status": "pending" },
    "report": { "status": "pending" },
    "history_update": { "status": "pending" },
    "slack": { "status": "pending" },
    "notion": { "status": "pending" },
    "summary": { "status": "pending" },
    "cleanup": { "status": "pending" }
  },
  "findings": {
    "level1": [],
    "level2": []
  }
}
```

Use the Write tool to create this file. The `run_id` should be the current ISO 8601 timestamp (e.g., output of `date -u +%Y-%m-%dT%H:%M:%SZ`).

---

### State Update Protocol

After completing any phase or domain agent, update `state.json`:

1. Read the current state file
2. Update the relevant phase's `status` to `"completed"` and set `completed_at` to the current ISO 8601 timestamp
3. For dispatch phases: move the domain from `domains_pending` to `domains_completed` (or `domains_failed` on failure), and append new findings to `findings.level1` or `findings.level2`
4. Write the updated state back

This is CRITICAL for resumability. If you skip a state update and the run is interrupted, that work is lost.

After each of Phases 1-5, update `state.json` to mark the phase completed and store any computed values (`stack_profile` and `stack_summary` for Phase 1, `report_dir` for Phase 2, etc.).

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

The 15 domain files are located at `${CLAUDE_PLUGIN_ROOT}/domains/`. The variable `${CLAUDE_PLUGIN_ROOT}` resolves to the root directory of this plugin (the directory containing the `.claude-plugin/` folder).

Read ALL of the following files. Use the Read tool to read them in parallel (all 15 at once):

### Level 1 Domains (core audit)

1. `${CLAUDE_PLUGIN_ROOT}/domains/01-security-scan.md`
2. `${CLAUDE_PLUGIN_ROOT}/domains/02-dependency-audit.md`
3. `${CLAUDE_PLUGIN_ROOT}/domains/03-code-quality.md`
4. `${CLAUDE_PLUGIN_ROOT}/domains/04-framework-updates.md`
5. `${CLAUDE_PLUGIN_ROOT}/domains/05-architecture.md`
6. `${CLAUDE_PLUGIN_ROOT}/domains/06-test-coverage.md`
7. `${CLAUDE_PLUGIN_ROOT}/domains/07-docs-drift.md`
8. `${CLAUDE_PLUGIN_ROOT}/domains/08-performance.md`
9. `${CLAUDE_PLUGIN_ROOT}/domains/09-project-health.md`

### Level 2 Domains (enhancement — run after Level 1 completes)

10. `${CLAUDE_PLUGIN_ROOT}/domains/10-code-simplification.md`
11. `${CLAUDE_PLUGIN_ROOT}/domains/11-documentation-updates.md`
12. `${CLAUDE_PLUGIN_ROOT}/domains/12-logic-diagrams.md`
13. `${CLAUDE_PLUGIN_ROOT}/domains/13-remediation-planning.md`
14. `${CLAUDE_PLUGIN_ROOT}/domains/14-cross-domain-correlation.md`
15. `${CLAUDE_PLUGIN_ROOT}/domains/15-pr-code-review.md`

For each file:
- If readable, store its full contents as `DOMAIN_INSTRUCTIONS[N]`
- If the file is missing or unreadable, mark that domain as `SKIPPED` with reason `"Domain file not found or unreadable"` and do NOT dispatch an agent for it

After reading all domain files, update `state.json`: mark `read_domains` phase as completed.

---

## Phase 5: Determine Applicable Domains

Not all 15 domains apply to every project. Use this relevance logic:

### Level 1 Domains

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

### Level 2 Domains

| Domain | Always Applicable | Condition to Skip |
|--------|-------------------|-------------------|
| 10-code-simplification | Yes | Never skip |
| 11-documentation-updates | Yes | Never skip |
| 12-logic-diagrams | Yes | Never skip |
| 13-remediation-planning | Yes | Never skip |
| 14-cross-domain-correlation | Yes | Never skip |
| 15-pr-code-review | Only if `gh` authenticated | Skip if `gh auth status 2>&1` fails OR no open non-dependabot PRs |

To check PR review applicability:
```bash
gh auth status 2>&1 && gh pr list --state=open --json number,author --limit=50 2>/dev/null
```
Filter out PRs where author login contains "dependabot", "renovate", or "bot". If zero remain, skip domain 15.

For skipped domains, record them with reason for the report.

After determining applicable domains, update `state.json`:
- Set `level1_dispatch.domains_pending` to the list of applicable L1 domain slugs
- Set `level2_dispatch.domains_pending` to the list of applicable L2 domain slugs
- Mark `filter_domains` phase as completed

---

## Phase 6a: Level 1 Sequential Dispatch

This is the core of the operation. For EACH applicable Level 1 domain, dispatch an agent using the **Task tool** — one at a time, sequentially. Wait for each agent to complete before dispatching the next.

Each agent is dispatched using the **Task tool** (NOT TaskCreate — that's for task lists).

### Analysis Philosophy

Every domain agent receives this philosophy block in its prompt. This is the core improvement of Night Shift v2 — agents are given the freedom and time to do thorough, senior-level analysis.

```
## Analysis Philosophy
You are a senior auditor with unlimited time and full codebase access.

**Multi-pass analysis:**
1. DISCOVER: Glob/Grep to map the relevant codebase surface
2. READ: Read key files in full — understand code, don't just pattern-match
3. ANALYZE: Look for actual bugs, logic errors, design problems
4. RESEARCH: WebSearch to verify findings against CVEs, best practices, docs
5. REPORT: Rich evidence with code snippets and specific recommendations

**Rules:**
- No file read limit. No finding cap. Be thorough.
- WebSearch for every domain — verify best practices, check CVEs, research fixes.
- Read code, don't guess from grep patterns.
- Evidence should include code snippets (up to 500 chars).
- Recommendations must be specific and actionable.
```

### Agent Prompt Template

For each domain agent, create a task with this prompt (fill in the placeholders):

```
You are a Night Shift domain auditor for: {DOMAIN_NAME}

## Your Mission
Audit the codebase at `{PROJECT_ROOT}` for the domain: {DOMAIN_NAME}.
Return your findings as a JSON array.

## Analysis Philosophy
You are a senior auditor with unlimited time and full codebase access.

**Multi-pass analysis:**
1. DISCOVER: Glob/Grep to map the relevant codebase surface
2. READ: Read key files in full — understand code, don't just pattern-match
3. ANALYZE: Look for actual bugs, logic errors, design problems
4. RESEARCH: WebSearch to verify findings against CVEs, best practices, docs
5. REPORT: Rich evidence with code snippets and specific recommendations

**Rules:**
- No file read limit. No finding cap. Be thorough.
- WebSearch for every domain — verify best practices, check CVEs, research fixes.
- Read code, don't guess from grep patterns.
- Evidence should include code snippets (up to 500 chars).
- Recommendations must be specific and actionable.

## Stack Summary: {STACK_SUMMARY}
## Stack Profile: {STACK_PROFILE as compact single-line JSON}

## Domain Instructions
{Full contents of the domain instruction file}

## Output Format
Return a SINGLE JSON code block with an array of findings. Zero findings = `[]`.

Each finding object: `{"id":"DOMAIN-NNN","domain":"{domain-slug}","title":"max 80 chars","severity":"critical|high|medium|low","urgent":bool,"important":bool,"description":"What is wrong and why","file":"/path or null","line":N or null,"evidence":"max 500 chars — include code snippets","recommendation":"Specific fix","effort":"trivial|small|medium|large","category":"sub-category"}`

ID format: `{DOMAIN_SLUG}-001`, `{DOMAIN_SLUG}-002`, etc.
Severity: critical=security risk/data loss, high=fix soon, medium=worth addressing, low=nice-to-have.
Effort: trivial=one-line, small=single-file, medium=multi-file, large=architectural.
urgent=needs attention in 24-48h. important=significant impact. Use independently.

## Rules
1. Only report findings with evidence. No speculation.
2. Respect the stack profile — skip inapplicable checks.
3. Be thorough. Read files, trace data flows, verify with WebSearch.
4. Return ONLY the JSON array. No preamble, no explanation outside the JSON.
```

### Dispatch Configuration

For each applicable domain, call the Task tool with:
- `subagent_type`: `"general-purpose"` — full access to all tools including WebSearch
- `description`: `"Night Shift: {Domain Name} audit"`
- `prompt`: The filled-in template above
- `run_in_background`: `false` — wait for each agent to complete
- `max_turns`: `120` — agents have unlimited depth for thorough analysis
- `model`: `"opus"` — maximum capability for deep analysis

### Sequential Loop

```
for each applicable domain in order (01 through 09):
  1. Dispatch agent with Task tool (blocking — run_in_background: false)
  2. When agent returns, extract JSON findings from its response
  3. Parse and validate JSON
  4. If valid: append findings to ALL_L1_FINDINGS
  5. If invalid: mark domain as FAILED with reason "Agent did not return valid JSON"
  6. Proceed to next domain
```

Do NOT dispatch the next domain until the current one completes.

Store all collected findings in a master array called `ALL_L1_FINDINGS`.

### State Checkpoint (after each L1 domain)

After each domain agent returns and its findings are parsed:
1. Read `state.json`
2. Move the domain slug from `level1_dispatch.domains_pending` to `level1_dispatch.domains_completed`
3. Append the parsed findings to `findings.level1`
4. Write updated `state.json`

When all L1 domains complete:
1. Set `level1_dispatch.status` to `"completed"`
2. Store `ALL_L1_FINDINGS` = all Level 1 findings (for passing to L2 agents)
3. Write updated `state.json`

---

## Phase 6b: Level 2 Sequential Dispatch

Level 2 agents run after ALL Level 1 agents complete. They receive the full Level 1 findings as additional context.

### Level 2 Agent Prompt Template

For each Level 2 domain, use this prompt template (extends the Level 1 template):

```
You are a Night Shift Level 2 enhancement agent for: {DOMAIN_NAME}

## Your Mission
Analyze the codebase at `{PROJECT_ROOT}` and the Level 1 audit findings below
to produce {DOMAIN_SPECIFIC} recommendations.
Return your findings as a JSON array.

## Analysis Philosophy
You are a senior engineer with unlimited time and full codebase access.

**Multi-pass analysis:**
1. REVIEW: Study the Level 1 findings to understand the codebase state
2. DISCOVER: Glob/Grep to find relevant code patterns
3. READ: Read key files in full — understand code, don't just pattern-match
4. SYNTHESIZE: Combine L1 findings with your own analysis
5. REPORT: Rich evidence with code snippets and specific recommendations

**Rules:**
- No file read limit. No finding cap. Be thorough.
- WebSearch to verify best practices and research approaches.
- Read code, don't guess from grep patterns.
- Evidence should include code snippets (up to 500 chars).
- Recommendations must be specific and actionable.
- You produce ADVISORY findings only — do NOT modify any files.

## Level 1 Audit Findings
{ALL_L1_FINDINGS as JSON array}

## Stack Summary: {STACK_SUMMARY}
## Stack Profile: {STACK_PROFILE as compact JSON}

## Domain Instructions
{Full contents of the Level 2 domain instruction file}

## Output Format
Same JSON finding format as Level 1:
{"id":"DOMAIN-NNN","domain":"{domain-slug}","title":"max 80 chars","severity":"critical|high|medium|low","urgent":bool,"important":bool,"description":"What is wrong and why","file":"/path or null","line":N or null,"evidence":"max 500 chars — include code snippets","recommendation":"Specific fix","effort":"trivial|small|medium|large","category":"sub-category"}

ID format: `{DOMAIN_SLUG}-001`, `{DOMAIN_SLUG}-002`, etc.

## Rules
1. Only report findings with evidence. No speculation.
2. Respect the stack profile — skip inapplicable checks.
3. Be thorough. Read files, trace data flows, verify with WebSearch.
4. Return ONLY the JSON array. No preamble, no explanation outside the JSON.
```

### Special handling for Domain 15 (PR Code Review)

Domain 15 uses a modified prompt. It does NOT include Level 1 findings (it is independent). Replace the "Level 1 Audit Findings" section with:

```
## Additional Instructions for PR Code Review
- Use `gh pr list` and `gh pr diff` via Bash tool to access PR data
- Create review files at `{REPORT_DIR}/pr-reviews/PR-{number}-review.md` using the Write tool
- Create the pr-reviews directory first: `mkdir -p {REPORT_DIR}/pr-reviews`
- Follow the superpowers:requesting-code-review methodology for structured reviews
- Return JSON findings AND write review files — both are required deliverables
```

### Dispatch Configuration (Level 2)

Same as Level 1:
- `subagent_type`: `"general-purpose"`
- `run_in_background`: `false`
- `max_turns`: `120`
- `model`: `"opus"`

### Sequential Loop (Level 2)

```
for each applicable Level 2 domain in order (10 through 15):
  1. Dispatch agent with Task tool (blocking)
  2. When agent returns, extract JSON findings
  3. Parse and validate JSON
  4. If valid: append findings to ALL_L2_FINDINGS
  5. If invalid: mark domain as FAILED
  6. Update state.json (move domain to completed, append findings to findings.level2)
  7. Proceed to next domain
```

When all L2 domains complete:
1. Set `level2_dispatch.status` to `"completed"`
2. Write updated `state.json`

---

## Phase 7: Validate Collected Results

After the sequential loops in Phase 6a and 6b, validate BOTH `ALL_L1_FINDINGS` and `ALL_L2_FINDINGS` separately:

1. Verify each finding has required fields: `id`, `domain`, `title`, `severity`, `description`
2. Strip findings missing required fields (log a warning)
3. Deduplicate findings with identical `title` + `file` + `line` combinations
4. Count total findings per domain and per severity

For domains that returned no findings and were not skipped, note them as clean.

After validation, combine: `ALL_FINDINGS = ALL_L1_FINDINGS + ALL_L2_FINDINGS`. Track the individual counts as `L1_COUNT` (length of validated L1 findings) and `L2_COUNT` (length of validated L2 findings) for use in later phases.

Update `state.json`: mark the `validate` phase as completed.

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

Classification applies to ALL findings equally — both Level 1 and Level 2 findings are classified using the same urgency matrix.

Iterate through `ALL_FINDINGS` and classify each into one of four quadrants:

| Quadrant | Condition | Action |
|----------|-----------|--------|
| `urgent_important` | `urgent == true && important == true` | Notion task (priority: High) + Report highlight section |
| `important` | `urgent == false && important == true` | Notion task (priority: Medium) + Report section |
| `urgent_only` | `urgent == true && important == false` | Report highlight section only |
| `neither` | `urgent == false && important == false` | Report appendix only |

Store the classified findings in four separate arrays.

Update `state.json`: mark the `classify` phase as completed.

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

**Project:** {PROJECT_NAME} | **Stack:** {STACK_SUMMARY} | **Duration:** {DURATION formatted as Xh Ym Zs} | **Domains:** {domains_run}/{domains_total}

---

## Executive Summary

{Write 3-5 sentences summarizing the overall health of the codebase. Highlight the most critical findings. Compare against the previous run if available. Mention which domains are cleanest and which need the most attention. This should be written in prose, not bullet points.}

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
| | **--- Level 2: Enhancement ---** | | | | | | | |
| 10 | Code Simplification | {icon} | {count} | {c} | {h} | {m} | {l} | {arrow} |
| 11 | Documentation Updates | {icon} | {count} | {c} | {h} | {m} | {l} | {arrow} |
| 12 | Logic Diagrams | {icon} | {count} | {c} | {h} | {m} | {l} | {arrow} |
| 13 | Remediation Planning | {icon} | {count} | {c} | {h} | {m} | {l} | {arrow} |
| 14 | Cross-Domain Correlation | {icon} | {count} | {c} | {h} | {m} | {l} | {arrow} |
| 15 | PR Code Review | {icon} | {count} | {c} | {h} | {m} | {l} | {arrow} |

**Total: {total_findings} findings** (L1: {l1_count}, L2: {l2_count})
({critical_count} critical, {high_count} high, {medium_count} medium, {low_count} low)
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

{For each Level 1 domain that was run and produced findings:}

### {N}. {Domain Name}

| ID | Title | Severity | Category | File | Effort |
|----|-------|----------|----------|------|--------|
{For each finding in this domain:}
| {finding.id} | {finding.title} | {finding.severity} | {finding.category} | `{finding.file_basename}` | {finding.effort} |

---

## Level 2: Enhancement Analysis

{For each Level 2 domain that was run and produced findings:}

### {N}. {Domain Name}

| ID | Title | Severity | Category | File | Effort |
|----|-------|----------|----------|------|--------|
{For each finding in this domain:}
| {finding.id} | {finding.title} | {finding.severity} | {finding.category} | `{finding.file_basename}` | {finding.effort} |

{Special for Logic Diagrams domain: render Mermaid diagrams from evidence fields inline}

{Special for PR Code Review domain: link to individual review files in pr-reviews/ directory}

---

## Skipped Domains

{If none skipped: "_All 15 domains were audited._"}

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

_Report generated by Night Shift v2.1 on {REPORT_DATE} at {current_time}._
_Duration: {DURATION formatted}. Domains audited: {domains_run}/15._
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
  "domains_run": {count of L1 + L2 domains that ran},
  "domains_skipped": {count of skipped/failed/timed-out domains},
  "total_findings": {ALL_FINDINGS.length},
  "level1_findings": {L1_COUNT},
  "level2_findings": {L2_COUNT},
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
    "project-health": {count},
    "code-simplification": {count},
    "documentation-updates": {count},
    "logic-diagrams": {count},
    "remediation-planning": {count},
    "cross-domain-correlation": {count},
    "pr-code-review": {count}
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

Update `state.json`: mark the `history_update` phase as completed.

---

## Phase 12: Send Slack Summary

Use the `bvdr:send-slack-notification` skill to send a condensed dashboard summary as a Slack DM.

### Slack Message Format

```
Night Shift Report — {REPORT_DATE}

Project: {PROJECT_NAME}
Stack: {STACK_SUMMARY}
Duration: {DURATION formatted}
Domains: {domains_run}/15

Level 1 Audit:
{For each L1 domain that ran:}
{icon} {Domain Name}: {count} findings ({severity breakdown})
{For each skipped L1 domain:}
⏭️ {Domain Name}: Skipped ({reason})

Level 2 Enhancement:
{For each L2 domain that ran:}
{icon} {Domain Name}: {count} findings
{For each skipped L2 domain:}
⏭️ {Domain Name}: Skipped ({reason})

Summary: {total_findings} findings total (L1: {l1_count}, L2: {l2_count})
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

Update `state.json`: mark the `slack` phase as completed.

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
- Level 1: {l1_count} findings across {l1_domains_run} audit domains
- Level 2: {l2_count} findings across {l2_domains_run} enhancement domains
- Critical: {count} | High: {count} | Medium: {count} | Low: {count}
- Urgent + Important: {count} | Important: {count}

{If critical security findings: "CRITICAL ALERT: {count} critical security finding(s) flagged. Review immediately."}
{If Notion tasks created: "Notion: {count} tasks created."}
{If Slack sent: "Slack: Summary sent."}
{If any domains failed: "Note: {count} domain(s) failed or timed out. See report for details."}

Trend: {If PREVIOUS_RUN: "{total} vs {prev_total} ({description})" else "First run — no trend data yet."}
```

---

## Phase 15: Cleanup State

Mark the run as completed:

1. Read `state.json`
2. Set `status` to `"completed"`
3. Set all phase statuses to `"completed"` (except any that were `"skipped"` or `"failed"`)
4. Write updated `state.json`

The state file is preserved for reference. It will be overwritten on the next fresh run.

---

## Error Handling & Resilience Rules

These rules apply throughout ALL phases:

1. **Domain file missing**: Skip domain, note in report. Do NOT abort.
2. **Agent returns invalid JSON**: Mark domain as FAILED with reason. Do NOT retry — sequential mode means each agent has ample time and context to get it right.
3. **Agent timeout (>45 min per domain)**: Mark as TIMED_OUT. Proceed to next domain.
4. **Slack skill unavailable**: Log warning, continue without Slack.
5. **Notion skill unavailable**: Log warning, continue without Notion.
6. **Report directory not writable**: Fall back to `${HOME}/.night-shift/reports/${PROJECT_NAME}/`.
7. **Git not available**: Use `pwd` as project root. Project name from directory name.
8. **Empty codebase**: Run all domains anyway — they will report "no findings".
9. **Partial failure**: The report MUST be written even if some domains fail. A partial report is better than no report.
10. **State file corruption**: If `state.json` cannot be parsed during resume, treat it as a fresh run. Log a warning about the corrupted state file.
11. **State file from different project**: Compare `project_root` — if different, log warning, start fresh.
12. **L2 agent can't parse L1 findings**: Pass empty array as L1 findings, note in the L2 agent's findings.
13. **`gh` CLI not available**: Skip domain 15, note in report as skipped.
14. **No open PRs**: Skip domain 15, note reason "No open non-dependabot PRs found".
15. **PR review file write fails**: Log warning, include findings in main report only.
16. **Resume after >24h**: Log warning "State is {N} hours old — findings may be stale" but proceed.

---

## Execution Checklist

Before starting, verify you understand the plan:

- [ ] Phase 0: Check for state.json → resume or init fresh
- [ ] Phase 1: Run stack detection, build STACK_PROFILE JSON
- [ ] Phase 2: Create report directory
- [ ] Phase 3: Load history.json (or null)
- [ ] Phase 4: Read all 15 domain files (parallel read)
- [ ] Phase 5: Filter to applicable domains (L1 + L2)
- [ ] Phase 6a: Dispatch Level 1 agents sequentially (state checkpoint after each)
- [ ] Phase 6b: Dispatch Level 2 agents sequentially (pass L1 findings, state checkpoint after each)
- [ ] Phase 7: Validate collected results (L1 + L2)
- [ ] Phase 8: Critical alert if needed (Slack)
- [ ] Phase 9: Classify into urgency matrix
- [ ] Phase 10: Write dashboard report with L1 + L2 sections
- [ ] Phase 11: Update history.json with L2 domain counts
- [ ] Phase 12: Slack summary with L2 line
- [ ] Phase 13: Notion tasks
- [ ] Phase 14: Final summary to user with L1/L2 breakdown
- [ ] Phase 15: Mark state.json as completed

Now execute. Start with Phase 0.
