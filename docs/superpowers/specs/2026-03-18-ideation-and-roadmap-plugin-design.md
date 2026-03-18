# Ideation & Roadmap Plugin — Design Spec

**Date**: 2026-03-18
**Status**: Review Complete
**Plugin location**: `plugins/bvdr-ideation-and-roadmap/`
**Marketplace**: `bvdr` (directory-based at `/Users/bogdand/gits/bvdr/claude-plugins`)

---

## 1. Overview

A Claude Code plugin that provides two skills — `/ideation` and `/roadmap` — for deep, AI-powered project analysis. Both skills dispatch parallel subagents with specialized prompts adapted from Auto-Claude's proven agent architecture.

**Key differentiators vs Auto-Claude:**
- Deep git history mining (500 commits, all merged PRs in last year, open issues/PRs)
- Web-based competitive research via WebSearch
- Blindspot detection (neglected code, missing patterns, stale dependencies)
- Interactive HTML reports with filters, search, and dark/light mode
- GitHub issue creation with full lifecycle tracking (pending → accepted/dismissed → created)
- Open issues/milestones awareness — aligns suggestions with stated project direction

---

## 2. Plugin Structure

Follows the bvdr marketplace plugin convention: `.claude-plugin/plugin.json` + `commands/` for skills, `agents/` for subagent prompts, `assets/` for HTML templates.

```
plugins/bvdr-ideation-and-roadmap/
├── .claude-plugin/
│   └── plugin.json                   # plugin manifest (bvdr convention)
├── README.md
├── commands/
│   ├── ideation.md                   # /ideation orchestrator skill
│   └── roadmap.md                    # /roadmap orchestrator skill
├── agents/
│   ├── context/
│   │   ├── git-analysis.md           # subagent: git history, PRs, issues
│   │   ├── codebase-scan.md          # subagent: code patterns, TODOs, structure
│   │   └── competitive-research.md   # subagent: web research, market analysis
│   ├── ideation/
│   │   ├── code-improvements.md
│   │   ├── code-quality.md
│   │   ├── documentation.md
│   │   ├── security.md
│   │   ├── performance.md
│   │   └── ui-ux.md
│   └── roadmap/
│       ├── discovery.md              # project understanding + competitive positioning
│       └── features.md              # prioritized feature generation
└── assets/
    ├── ideation-report-template.html # HTML template for ideation report
    └── roadmap-report-template.html  # HTML template for roadmap report
```

### .claude-plugin/plugin.json
```json
{
  "name": "bvdr-ideation-and-roadmap",
  "version": "1.0.0",
  "description": "Deep AI-powered project ideation and roadmap generation with parallel subagents, competitive analysis, and interactive HTML reports",
  "author": {
    "name": "Bogdan Dragomir",
    "url": "https://github.com/bvdr"
  }
}
```

---

## 3. Agent Dispatch Mechanism

### How orchestrator skills dispatch subagents

The `commands/ideation.md` and `commands/roadmap.md` orchestrator skills use Claude Code's **Agent tool** to dispatch subagents. The orchestrator:

1. **Reads the agent prompt file** from `agents/` using the Read tool (relative to plugin install path)
2. **Composes a full prompt** by combining: the agent prompt + file paths to context data (e.g., `deep-analysis.json`)
3. **Dispatches via Agent tool** with these parameters:
   - `subagent_type`: `"general-purpose"` (agents need Bash, Read, Grep, Glob, WebSearch access)
   - `prompt`: The composed prompt including the agent instructions + context file paths
   - `run_in_background`: `true` for parallel execution (ideation agents), `false` for sequential (deep analysis phases)
   - `description`: Short label like `"Ideation: security analysis"`

### Context passing strategy

Agents receive context via **file paths**, not inline data (avoids bloating prompts):

```
Your analysis context is at: {project_root}/.claude/ideation/deep-analysis.json
Read this file first to understand the project before beginning your analysis.
```

Each agent prompt has a `## CONTEXT FILES` section at the top listing which files to read. The orchestrator fills in the absolute paths before dispatching.

### Deep analysis: 3 sequential subagents merged

The deep analysis is too large for a single agent. It splits into 3 focused subagents that run **sequentially** (each builds on the previous):

1. **git-analysis** (`agents/context/git-analysis.md`) — 500 commits, merged PRs (1yr), open PRs, closed PRs, open issues, branch analysis, file churn → writes `git-analysis.json`
2. **codebase-scan** (`agents/context/codebase-scan.md`) — reads `git-analysis.json`, then scans code structure, TODOs, patterns, dependencies, test coverage indicators, Claude context (memory files, claude-mem/beads observations via MCP search, existing specs/plans, CLAUDE.md conventions) → writes `codebase-scan.json`
3. **competitive-research** (`agents/context/competitive-research.md`) — reads `git-analysis.json` + `codebase-scan.json`, performs WebSearch for competitors, market gaps → writes `competitive-research.json`

After all 3 complete, the orchestrator merges their outputs into `deep-analysis.json`.

### Ideation: 6 parallel subagents

After deep analysis, the orchestrator dispatches all 6 (or `--only` subset) ideation agents **in parallel** using `run_in_background: true`:

```
# Orchestrator dispatches all 6 in a single message with multiple Agent tool calls
Agent(prompt="...", run_in_background=true, description="Ideation: code improvements")
Agent(prompt="...", run_in_background=true, description="Ideation: code quality")
Agent(prompt="...", run_in_background=true, description="Ideation: documentation")
Agent(prompt="...", run_in_background=true, description="Ideation: security")
Agent(prompt="...", run_in_background=true, description="Ideation: performance")
Agent(prompt="...", run_in_background=true, description="Ideation: ui-ux")
```

Each agent writes its own output file. The orchestrator waits for all to complete, then merges.

### Roadmap: 2 sequential subagents

1. **discovery** agent (needs deep analysis complete)
2. **features** agent (needs discovery complete + optional ideation input)

Both run with `run_in_background: false` (sequential dependency).

---

## 4. Output Directories

> **Note:** Intermediate subagent files (`git-analysis.json`, `codebase-scan.json`, `competitive-research.json`) are written to the output directory during deep analysis. They are kept for debugging but are not part of the public contract — only `deep-analysis.json` (the merged result) is consumed by downstream agents.

Both skills write to self-contained folders in the project directory:

### `.claude/ideation/`
```
.claude/ideation/
├── .gitignore                    # ignores everything in this folder
├── Readme.txt                    # explains what this folder is and which plugin created it
├── deep-analysis.json            # shared deep analysis output
├── code-improvements.json        # per-type results
├── code-quality.json
├── documentation.json
├── security.json
├── performance.json
├── ui-ux.json
├── ideation.json                 # merged results with status tracking
├── issues-tracker.json           # GH issue creation tracker
└── report.html                   # interactive HTML report
```

### `.claude/roadmap/`
```
.claude/roadmap/
├── .gitignore
├── Readme.txt
├── deep-analysis.json            # reused from ideation if <24h old, otherwise regenerated
├── discovery.json                # project understanding + competitive positioning
├── roadmap.json                  # prioritized features with status tracking
├── issues-tracker.json           # GH issue creation tracker
└── report.html                   # interactive HTML report
```

### .gitignore (same for both)
```
# Generated by bvdr-ideation-and-roadmap plugin
# These are analysis artifacts, not source code
*
!.gitignore
!Readme.txt
```

### Readme.txt (template)
```
This folder contains analysis output generated by the bvdr-ideation-and-roadmap
Claude Code plugin (https://github.com/bvdr/claude-plugins).

These files are generated artifacts and are git-ignored by default.
To regenerate, run /ideation or /roadmap in Claude Code.
```

---

## 5. Deep Analysis Agent

### Purpose
Shared foundation agent that both `/ideation` and `/roadmap` consume. Produces `deep-analysis.json` with comprehensive project understanding.

### Caching and Schema Versioning

All generated JSON files include a `schema_version` field:
```json
{ "schema_version": "1.0", "...": "..." }
```

When the orchestrator reads a cached file, it checks `schema_version`. If the version doesn't match the current expected version, the cache is invalidated and the analysis is re-run.

The 24-hour cache reuse (roadmap reusing ideation's deep analysis) uses an atomic write pattern: agents write to `deep-analysis.tmp.json` first, then the orchestrator renames to `deep-analysis.json` after validation. This prevents half-written file reads.

### Data Sources

| Source | Command/Method | What we extract |
|--------|---------------|-----------------|
| Last 500 commits | `git log --oneline -500` | Work patterns, trajectory, hot/cold spots |
| Merged PRs (last year) | `gh pr list --state merged --limit 500 --json ...` | What was intentionally shipped |
| Open PRs | `gh pr list --state open --json ...` | In-flight work, don't duplicate |
| Closed-not-merged PRs | `gh pr list --state closed --json ...` | Abandoned approaches, don't re-suggest |
| Open issues | `gh issue list --state open --json number,title,labels,milestone,body` | Planned work, stated direction |
| Issue labels | From above | Priority signals, categorization |
| Issue milestones | From above | Release planning, deadlines |
| Stale branches | `git branch -a --sort=-committerdate` | Abandoned work indicators |
| File churn | `git log --name-only` analysis | Hot spots (frequently modified) |
| Cold spots | Inverse of churn — dirs with no recent commits | Neglected areas |
| TODO/FIXME/HACK | Grep across codebase | Team's own informal backlog |
| README/docs | File reads | Stated purpose, existing documentation |
| Package files | package.json, pyproject.toml, etc. | Tech stack, dependencies |
| Competitive research | WebSearch for similar tools/products | Market positioning, feature gaps |
| Claude memory files | Read `~/.claude/projects/*/memory/MEMORY.md` and memory files | Past decisions, user preferences, project context from prior sessions |
| claude-mem plugin | `mcp__plugin_claude-mem_mcp-search__search` / `get_observations` / `timeline` | Cross-session observations, past research, decisions, bugs encountered |
| Beads (if available) | Check for beads MCP tools or `.beads/` directory | Session context, conversation history, work artifacts from prior sessions |
| Superpowers specs | Read `docs/superpowers/specs/*.md` if exists | Existing design specs, planned features, architectural decisions |
| Superpowers plans | Read `docs/superpowers/plans/*.md` if exists | Implementation plans in progress or completed |
| CLAUDE.md files | Read `.claude/CLAUDE.md`, `CLAUDE.md` in project root | Project-specific instructions, conventions, constraints |

### Output Schema: `deep-analysis.json`

```json
{
  "project_name": "string",
  "project_type": "web-app|mobile-app|cli|library|api|desktop-app|other",
  "tech_stack": {
    "languages": ["string"],
    "frameworks": ["string"],
    "key_dependencies": ["string"]
  },
  "git_activity": {
    "total_commits_analyzed": 500,
    "date_range": { "from": "ISO date", "to": "ISO date" },
    "recent_commits_summary": "string — narrative summary of patterns",
    "hot_spots": [
      { "path": "string", "change_count": 0, "context": "string" }
    ],
    "cold_spots": [
      { "path": "string", "last_modified": "ISO date", "context": "string" }
    ],
    "merged_prs_last_year": [
      { "number": 0, "title": "string", "merged_at": "ISO date", "summary": "string" }
    ],
    "open_prs": [
      { "number": 0, "title": "string", "author": "string", "summary": "string" }
    ],
    "abandoned_work": [
      { "type": "closed_pr|stale_branch", "title": "string", "context": "string" }
    ]
  },
  "open_issues": [
    {
      "number": 0,
      "title": "string",
      "labels": ["string"],
      "milestone": "string|null",
      "summary": "string"
    }
  ],
  "direction": {
    "recently_shipped": ["string — features/changes from merged PRs"],
    "in_progress": ["string — from open PRs and active branches"],
    "attempted_and_dropped": ["string — from closed PRs and stale branches"],
    "team_backlog": ["string — from TODOs, FIXMEs, open issues"],
    "stated_priorities": ["string — from milestones, labeled issues"]
  },
  "competitive_analysis": {
    "search_queries_used": ["string"],
    "competitors": [
      {
        "name": "string",
        "url": "string",
        "features": ["string"],
        "pain_points": ["string"],
        "pricing": "string|null"
      }
    ],
    "missing_features": ["string — features competitors have that project doesn't"],
    "market_gaps": ["string — opportunities no competitor addresses"],
    "differentiators": ["string — what makes this project unique"]
  },
  "claude_context": {
    "memory_insights": ["string — relevant memories from Claude memory files"],
    "claude_mem_observations": ["string — relevant observations from claude-mem plugin"],
    "beads_context": ["string — relevant context from beads sessions if available"],
    "existing_specs": [
      { "path": "string", "title": "string", "status": "string", "summary": "string" }
    ],
    "existing_plans": [
      { "path": "string", "title": "string", "status": "string", "summary": "string" }
    ],
    "project_conventions": ["string — from CLAUDE.md files"]
  },
  "blindspots": {
    "untested_areas": ["string — directories/modules with no test indicators"],
    "undocumented_areas": ["string — public APIs with no docs"],
    "stale_dependencies": [
      { "name": "string", "current_version": "string", "context": "string" }
    ],
    "missing_patterns": ["string — e.g., no rate limiting, no input validation, no error boundaries"]
  },
  "created_at": "ISO timestamp"
}
```

### Caching
- Output is cached to `deep-analysis.json`
- The `/roadmap` skill reuses `.claude/ideation/deep-analysis.json` if it exists and is < 24 hours old
- Force refresh with `--refresh` flag on either skill

---

## 6. Ideation Skill (`/ideation`)

### Commands

```
/ideation                                    # run all 6 types
/ideation --only security,performance        # run specific types (see IDEATION TYPES below)
/ideation --refresh                          # force re-run deep analysis
/ideation --no-open                          # don't auto-open HTML report
/ideation help                               # show usage guide

/ideation accept ci-003 ci-005 sec-001       # mark ideas as accepted
/ideation dismiss ci-004 --reason "tried Q3" # mark idea as dismissed
/ideation status                             # show review status summary
/ideation create-issues                      # create GH issues for all accepted
/ideation create-issue ci-003                # create GH issue for specific idea
```

### Flow

1. **Parse args** — determine subcommand (run/accept/dismiss/status/create-issues/help)
2. **For `run` (default):**
   a. Run deep-analysis agent → `deep-analysis.json`
   b. Dispatch 6 ideation subagents in parallel (or subset with `--only`)
   c. Each agent writes `{type}.json`
   d. Merge all results into `ideation.json` with `status: "pending"` for each idea
   e. Generate `report.html`
   f. Open report in browser (`open report.html`)
   g. Print terminal summary
3. **For `accept`:** Update idea status in `ideation.json`, regenerate `report.html`
4. **For `dismiss`:** Update idea status + optional reason in `ideation.json`, regenerate `report.html`
5. **For `status`:** Read `ideation.json` and `issues-tracker.json`, print summary
6. **For `create-issues`:** Create GH issues for all accepted ideas, update tracker, regenerate report
7. **For `create-issue <id>`:** Create GH issue for specific accepted idea

### 6 Ideation Agent Types

| Type | Agent file | Focus | Deep analysis integration |
|------|-----------|-------|--------------------------|
| `code-improvements` | `agents/ideation/code-improvements.md` | Pattern extensions, architecture opportunities | Uses hot spots to prioritize high-churn areas; skips ideas that overlap with open issues |
| `code-quality` | `agents/ideation/code-quality.md` | Refactoring, code smells, complexity | Uses cold spots to find neglected code; considers abandoned PRs for context |
| `documentation` | `agents/ideation/documentation.md` | Missing docs, API docs, inline comments | Cross-refs competitive analysis for documentation standards |
| `security` | `agents/ideation/security.md` | OWASP, secrets, auth, validation | Uses dependency staleness data; considers open security issues |
| `performance` | `agents/ideation/performance.md` | Bundle size, N+1, memory, caching | Uses hot spots for perf-sensitive paths; checks competitor perf claims |
| `ui-ux` | `agents/ideation/ui-ux.md` | Accessibility, consistency, UX | Compares against competitor UX via competitive analysis |

### Agent Input Contract

Each ideation agent receives:
- `deep-analysis.json` — full project context
- Project directory access — for code analysis
- Their specialized prompt — analysis instructions and output format

### Agent Output Contract

Each agent writes a JSON file with this structure:
```json
{
  "{type}": [
    {
      "id": "{prefix}-001",
      "type": "{type}",
      "title": "string",
      "description": "string",
      "rationale": "string",
      "estimated_effort": "trivial|small|medium|large|complex",
      "affected_files": ["string"],
      "existing_patterns": ["string"],
      "implementation_approach": "string",
      "related_issues": [
        { "number": 0, "title": "string", "relationship": "addresses|complements|conflicts" }
      ],
      "status": "draft",
      "created_at": "ISO timestamp"
    }
  ]
}
```

Type-specific additional fields:
- **code-quality**: `category`, `severity` (critical/major/minor/suggestion), `currentState`, `proposedChange`, `codeExample`, `metrics`
- **security**: `category`, `severity` (critical/high/medium/low), `vulnerability` (CWE ref), `remediation`, `references`
- **performance**: `category`, `impact` (high/medium/low), `currentMetric`, `expectedImprovement`, `tradeoffs`
- **documentation**: `category`, `targetAudience`, `currentDocumentation`, `proposedContent`, `priority`
- **ui-ux**: `category`, `affected_components`, `current_state`, `proposed_change`, `user_benefit`

### Merged Output: `ideation.json`

```json
{
  "id": "ideation-YYYYMMDD-HHMMSS",
  "project_name": "string",
  "ideas": [
    {
      "...all fields from agent output...",
      "status": "pending|accepted|dismissed|created",
      "dismissed_reason": "string|null",
      "reviewed_at": "ISO timestamp|null",
      "gh_issue": {
        "number": 0,
        "url": "string"
      }
    }
  ],
  "summary": {
    "total_ideas": 0,
    "by_type": { "code_improvements": 0 },
    "by_status": { "pending": 0, "accepted": 0, "dismissed": 0, "created": 0 },
    "by_effort": { "trivial": 0 }
  },
  "generated_at": "ISO timestamp",
  "updated_at": "ISO timestamp"
}
```

### Terminal Summary (after run)

```
=== IDEATION COMPLETE ===

Deep Analysis: 500 commits, 87 merged PRs (last year), 23 open issues, 3 competitors

Ideas Generated: 24

  Code Improvements:  5 (2 trivial, 2 medium, 1 large)
  Code Quality:       4 (1 critical, 2 major, 1 minor)
  Documentation:      3 (2 high priority, 1 medium)
  Security:           4 (1 critical, 2 high, 1 medium)
  Performance:        5 (2 high impact, 3 medium)
  UI/UX:              3 (1 usability, 1 accessibility, 1 visual)

Top 5 Quick Wins:
  1. [ci-003] Add search to user list (trivial)
  2. [sec-002] Remove hardcoded API key in config (trivial)
  3. [cq-001] Extract duplicated validation logic (small)
  4. [perf-003] Replace moment.js with date-fns (small)
  5. [doc-002] Add API endpoint documentation (small)

Report: .claude/ideation/report.html (opening in browser...)

Next: Review the report, then run:
  /ideation accept <id> [<id>...]     — accept ideas
  /ideation dismiss <id> [--reason]   — dismiss ideas
  /ideation create-issues             — create GH issues for accepted
```

---

## 7. Roadmap Skill (`/roadmap`)

### Commands

```
/roadmap                                     # full roadmap generation
/roadmap --refresh                           # force re-run deep analysis
/roadmap --skip-discovery                    # re-run features only (reuse existing discovery.json)
/roadmap --no-open                           # don't auto-open HTML report
/roadmap help                                # show usage guide

/roadmap accept feature-1 feature-3          # mark features as accepted
/roadmap dismiss feature-12 --reason "..."   # mark feature as dismissed
/roadmap status                              # show review status summary
/roadmap create-issues                       # create GH issues for all accepted
/roadmap create-issue feature-3              # create GH issue for specific feature
```

### Flow

1. **Parse args** — determine subcommand
2. **For `run` (default):**
   a. Check for cached deep analysis (`.claude/ideation/deep-analysis.json` < 24h old)
   b. If not cached, run deep-analysis agent → `.claude/roadmap/deep-analysis.json`
   c. Check for existing ideation (`.claude/ideation/ideation.json`) — feed as input if exists
   d. Run discovery agent → `discovery.json`
   e. Run features agent (consumes discovery.json + ideation.json) → `roadmap.json`
   f. Generate `report.html`
   g. Open report in browser
   h. Print terminal summary
3. **For accept/dismiss/status/create-issues:** Same pattern as ideation

### Roadmap Agent Pipeline

**Step 1: Discovery Agent** (`agents/roadmap/discovery.md`)

Consumes: `deep-analysis.json`, project files
Produces: `discovery.json`

Additional analysis beyond deep-analysis:
- Product vision inference (README, landing page, docs)
- Target audience identification
- Maturity assessment (idea → prototype → mvp → growth → mature)
- Competitive positioning via WebSearch (pricing, positioning, market share)
- Market gaps and differentiation opportunities

```json
{
  "project_name": "string",
  "project_type": "string",
  "tech_stack": { "...from deep-analysis..." },
  "target_audience": {
    "primary_persona": "string",
    "secondary_personas": ["string"],
    "pain_points": ["string"],
    "goals": ["string"],
    "usage_context": "string"
  },
  "product_vision": {
    "one_liner": "string",
    "problem_statement": "string",
    "value_proposition": "string",
    "success_metrics": ["string"]
  },
  "current_state": {
    "maturity": "idea|prototype|mvp|growth|mature",
    "existing_features": ["string"],
    "known_gaps": ["string"],
    "technical_debt": ["string"]
  },
  "competitive_context": {
    "competitors": [{ "name": "", "features": [], "pain_points": [], "pricing": "" }],
    "missing_features": ["string"],
    "market_gaps": ["string"],
    "differentiators": ["string"]
  },
  "constraints": {
    "technical": ["string"],
    "resources": ["string"],
    "dependencies": ["string"]
  },
  "created_at": "ISO timestamp"
}
```

**Step 2: Features Agent** (`agents/roadmap/features.md`)

Consumes: `discovery.json`, `deep-analysis.json`, optionally `ideation.json`
Produces: `roadmap.json`

```json
{
  "id": "roadmap-YYYYMMDD",
  "project_name": "string",
  "version": "1.0",
  "vision": "string",
  "target_audience": {
    "primary": "string",
    "secondary": ["string"]
  },
  "phases": [
    {
      "id": "phase-1",
      "name": "Foundation",
      "description": "string",
      "order": 1,
      "status": "planned",
      "features": ["feature-1", "feature-2"],
      "milestones": [
        {
          "id": "milestone-1-1",
          "title": "string",
          "description": "string",
          "features": ["feature-1"],
          "status": "planned"
        }
      ]
    }
  ],
  "features": [
    {
      "id": "feature-1",
      "title": "string",
      "description": "string",
      "rationale": "string",
      "priority": "must|should|could|wont",
      "complexity": "low|medium|high",
      "impact": "low|medium|high",
      "phase_id": "phase-1",
      "dependencies": ["feature-id"],
      "acceptance_criteria": ["string"],
      "user_stories": ["As a ..., I want ..., so that ..."],
      "source": "ideation:{id}|competitive|blindspot|team-momentum|open-issue:{number}",
      "competitor_insight_ids": ["string"],
      "related_issues": [
        { "number": 0, "title": "string", "relationship": "addresses|complements" }
      ],
      "status": "pending|accepted|dismissed|created",
      "dismissed_reason": null,
      "reviewed_at": null,
      "gh_issue": null
    }
  ],
  "metadata": {
    "commits_analyzed": 500,
    "merged_prs_last_year": 0,
    "open_issues_analyzed": 0,
    "competitors_researched": 0,
    "ideation_ideas_incorporated": 0,
    "prioritization_framework": "MoSCoW",
    "created_at": "ISO timestamp",
    "updated_at": "ISO timestamp"
  }
}
```

### Backward-looking intelligence

The features agent uses deep analysis to:
- **Don't re-suggest**: Skip features matching abandoned PRs or dismissed ideation ideas
- **Build on momentum**: Boost priority for features that complement recently shipped work
- **Respect in-flight**: Note features that overlap with open PRs
- **Honor stated direction**: Align with open issues and milestones
- **Learn from history**: Use merged PR patterns to understand team velocity and preferences

### Terminal Summary (after run)

```
=== ROADMAP GENERATED ===

Project: MyApp (mvp maturity)
Vision: "One-liner vision statement"
Competitors Analyzed: 3 (CompA, CompB, CompC)
Commits: 500 | Merged PRs (1yr): 87 | Open Issues: 23

Phases: 4 | Features: 18

Phase 1 - Foundation (6 features):
  MUST:   Feature A, Feature B, Feature C
  SHOULD: Feature D, Feature E
  COULD:  Feature F

Phase 2 - Enhancement (5 features): ...
Phase 3 - Scale (4 features): ...
Phase 4 - Vision (3 features): ...

Feature Sources:
  From ideation ideas:    8
  From competitive gaps:  5
  From blindspot analysis: 3
  From team momentum:     2

Report: .claude/roadmap/report.html (opening in browser...)

Next: Review the report, then run:
  /roadmap accept <id> [<id>...]     — accept features
  /roadmap dismiss <id> [--reason]   — dismiss features
  /roadmap create-issues             — create GH issues for accepted
```

---

## 8. Interactive HTML Reports

Both skills generate a self-contained `.html` file — inline CSS + JS, no external dependencies, works fully offline.

### Generation approach

HTML reports are generated from **template files** in `assets/`:
- `assets/ideation-report-template.html` — full HTML with inline CSS/JS, contains `{{IDEATION_DATA}}` placeholder
- `assets/roadmap-report-template.html` — full HTML with inline CSS/JS, contains `{{ROADMAP_DATA}}` placeholder

The orchestrator reads the template, replaces the data placeholder with the JSON results (serialized as a JS variable), and writes the final `report.html`. This is far more reliable and token-efficient than having an LLM generate the entire HTML each time.

The templates are static assets checked into the plugin repo. To update the report design, edit the template — all future runs use the new design automatically.

### Common Features (both reports)

- **Dark/light mode toggle** — respects system preference, manual override
- **Filter bar** — filter by type, priority, effort, status
- **Search** — free-text search across all cards
- **Sort options** — by effort, priority, type, status
- **Status badges** on each card:
  - Pending = no badge (default)
  - Accepted = green "Accepted" badge
  - Dismissed = gray strikethrough with reason tooltip
  - Created = green "Issue #42" badge linking to GitHub
- **Responsive layout** — works on any screen size
- **Design aesthetic** — modern, clean, Linear/Notion-inspired

### Ideation Report (`.claude/ideation/report.html`)

- **Dashboard header**: project name, date, total ideas, breakdown by type and effort
- **Cards view**: each idea as a card with:
  - Color-coded badge by type (code=blue, security=red, perf=orange, etc.)
  - Effort pill (trivial → complex)
  - Severity indicator (for security, code quality)
  - Status badge
  - Affected files list (collapsible)
  - Implementation approach (collapsible)
  - Related GH issues (linked)
  - Rationale
- **Competitive insights section**: what competitors have, linked to relevant ideas
- **Git insights section**: hot spots, cold spots, abandoned work

### Roadmap Report (`.claude/roadmap/report.html`)

- **Vision banner**: project name, one-liner vision, maturity badge
- **Phase timeline**: visual timeline showing phases
- **Feature board**: columns per phase, cards per feature
  - MoSCoW color coding (must=red, should=orange, could=blue, won't=gray)
  - Complexity/impact badges
  - Source tag (ideation, competitive gap, blindspot, momentum, open issue)
  - Status badge
  - Expandable: user stories, acceptance criteria, dependencies, competitor insights
- **Filters**: by priority, complexity, impact, source, phase, status
- **Dependency indicators**: visual links between dependent features
- **Competitive analysis section**: competitor comparison table
- **Statistics footer**: commits analyzed, PRs reviewed, competitors researched

---

## 9. GitHub Issue Lifecycle

### Status flow per idea/feature:

```
pending → accepted → created (with GH issue link)
pending → dismissed (with optional reason)
```

### Issue creation format:

When creating a GH issue from an idea:

```markdown
## {title}

{description}

### Rationale
{rationale}

### Implementation Approach
{implementation_approach}

### Affected Files
- `file1.ts`
- `file2.ts`

### Estimated Effort
{estimated_effort}

### Related Issues
- #{number} — {relationship}

---
*Generated by [bvdr-ideation-and-roadmap](https://github.com/bvdr/claude-plugins) plugin*
*Source: {type} ideation — {id}*
```

### Labels:
The skill auto-applies labels based on idea type:
- `code-improvement`, `code-quality`, `documentation`, `security`, `performance`, `ui-ux`
- Severity labels where applicable: `critical`, `high`, `medium`, `low`
- `ideation-generated` or `roadmap-generated` label for traceability

### Issues Tracker: `issues-tracker.json`

```json
{
  "created_issues": [
    {
      "idea_id": "ci-003",
      "gh_issue_number": 42,
      "gh_issue_url": "https://github.com/owner/repo/issues/42",
      "created_at": "ISO timestamp"
    }
  ],
  "last_updated": "ISO timestamp"
}
```

After creating issues, the HTML report is regenerated so badges reflect current state.

---

## 10. Agent Prompt Adaptation Strategy

### Principle: Preserve Auto-Claude's prompts, adapt minimally

Auto-Claude's prompts produce excellent results. The agent prompts in this plugin should be **faithful adaptations** of the originals at `/Applications/Auto-Claude.app/Contents/Resources/backend/prompts/`, preserving:

- The exact analysis phases and their order
- The thinking/reasoning frameworks (e.g., `<ultrathink>` blocks)
- The category systems and severity classifications
- The good/bad example sections
- The validation rules and output schemas
- The critical rules sections

### What changes (and only this):

1. **Input contract**: Agents receive `deep-analysis.json` (richer) instead of Auto-Claude's `project_index.json` + `ideation_context.json`
2. **Open issues awareness**: Add section to each prompt instructing agent to check `open_issues` in deep analysis and not duplicate existing tickets
3. **Direction awareness**: Add section for agents to consider `direction.recently_shipped`, `direction.in_progress`, and `direction.attempted_and_dropped`
4. **Competitive data**: Add section for agents to use `competitive_analysis` from deep analysis
5. **Output format**: Preserve Auto-Claude schemas, add `related_issues` and `status` fields
6. **Remove Graphiti references**: Replace graph hints integration with deep-analysis references
7. **Remove Puppeteer dependency**: UI/UX agent uses static code analysis as primary, browser automation as optional if MCP tools available
8. **Tool references**: Replace Auto-Claude custom tool wrappers with Claude Code native tools (Read, Grep, Glob, Bash, WebSearch)

### Source mapping:

| Plugin agent file | Auto-Claude source |
|------------------|--------------------|
| `agents/ideation/code-improvements.md` | `prompts/ideation_code_improvements.md` |
| `agents/ideation/code-quality.md` | `prompts/ideation_code_quality.md` |
| `agents/ideation/documentation.md` | `prompts/ideation_documentation.md` |
| `agents/ideation/security.md` | `prompts/ideation_security.md` |
| `agents/ideation/performance.md` | `prompts/ideation_performance.md` |
| `agents/ideation/ui-ux.md` | `prompts/ideation_ui_ux.md` |
| `agents/roadmap/discovery.md` | `prompts/roadmap_discovery.md` |
| `agents/roadmap/features.md` | `prompts/roadmap_features.md` |
| `agents/context/git-analysis.md` | NEW — git history mining (no Auto-Claude equivalent) |
| `agents/context/codebase-scan.md` | NEW — code patterns + Claude context sources |
| `agents/context/competitive-research.md` | NEW — web-based competitive analysis |

---

## 11. Help Output

### `/ideation help`

```
IDEATION - AI-powered project improvement analysis

USAGE:
  /ideation                              Run all 6 ideation types
  /ideation --only type1,type2           Run specific types only
  /ideation --refresh                    Force re-run deep analysis
  /ideation --no-open                    Don't auto-open HTML report
  /ideation help                         Show this help

REVIEW:
  /ideation accept <id> [<id>...]        Mark ideas as accepted
  /ideation dismiss <id> [--reason ""]   Mark idea as dismissed
  /ideation status                       Show review summary

GITHUB:
  /ideation create-issues                Create GH issues for all accepted
  /ideation create-issue <id>            Create GH issue for specific idea

IDEATION TYPES (use with --only, comma-separated):
  code-improvements   Pattern extensions and architecture opportunities
  code-quality        Refactoring, code smells, complexity
  documentation       Missing docs, API docs, inline comments
  security            OWASP, secrets, auth, input validation
  performance         Bundle size, N+1 queries, memory, caching
  ui-ux               Accessibility, consistency, responsiveness

  Short aliases: ci, cq, doc, sec, perf, ux
  Example: /ideation --only sec,perf

OUTPUT:
  .claude/ideation/report.html           Interactive HTML report
  .claude/ideation/ideation.json         Machine-readable results
```

### `/roadmap help`

```
ROADMAP - AI-powered strategic feature roadmap generation

USAGE:
  /roadmap                               Generate full roadmap
  /roadmap --refresh                     Force re-run deep analysis
  /roadmap --skip-discovery               Re-run features only (reuse discovery.json)
  /roadmap --no-open                     Don't auto-open HTML report
  /roadmap help                          Show this help

REVIEW:
  /roadmap accept <id> [<id>...]         Mark features as accepted
  /roadmap dismiss <id> [--reason ""]    Mark feature as dismissed
  /roadmap status                        Show review summary

GITHUB:
  /roadmap create-issues                 Create GH issues for all accepted
  /roadmap create-issue <id>             Create GH issue for specific feature

ANALYSIS:
  - Analyzes 500 commits + all merged PRs (last year)
  - Reviews open issues, milestones, and active PRs
  - Performs web-based competitive research
  - Consumes ideation results if available (.claude/ideation/)
  - MoSCoW prioritization (must/should/could/won't)

OUTPUT:
  .claude/roadmap/report.html            Interactive HTML report
  .claude/roadmap/roadmap.json           Machine-readable results
```

---

## 12. Edge Cases & Error Handling

- **Re-run after partial review**: When `/ideation` or `/roadmap` is re-run on a project with existing results:
  1. Load existing `ideation.json` / `roadmap.json`
  2. Preserve all items with `status` != `pending` (accepted, dismissed, created)
  3. Remove old `pending` items (they'll be regenerated)
  4. Generate new ideas/features
  5. Merge: new items added as `pending`, preserved items kept with their status
  6. If a new item matches an existing dismissed item (same title + type), mark it `dismissed` automatically with reason "previously dismissed"
- **Duplicate issue protection**: Before creating a GH issue for idea X, check `issues-tracker.json` — if `idea_id` already exists, skip it and log "Issue already created: #{number}"
- **`--skip-discovery` without existing discovery.json**: Error with message "No existing discovery.json found. Run `/roadmap` first without `--skip-discovery`."
- **No git repo**: Warn and skip git analysis, proceed with code-only analysis
- **No `gh` CLI**: Warn, skip PR/issue analysis, disable create-issues commands
- **No GitHub remote**: Same as above
- **Private repo with no issues**: Proceed without issue context
- **WebSearch fails**: Proceed without competitive analysis, note in output
- **Empty project**: Generate minimal analysis, note low confidence
- **Existing ideation/roadmap**: Append/merge, don't overwrite accepted/dismissed items
- **Re-run after review**: Preserve accepted/dismissed status, add new ideas as pending
