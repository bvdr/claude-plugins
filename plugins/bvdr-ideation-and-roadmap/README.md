# bvdr-ideation-and-roadmap

AI-powered project ideation, marketing audit, and roadmap generation for Claude Code. Run `/ideation` to surface improvement ideas across 6 analysis types, `/ideation-marketing` to perform a full marketing audit across 4 domains, or `/roadmap` to generate a prioritized feature roadmap — all backed by deep codebase analysis, competitive research, and interactive HTML reports.

## What It Does

### /ideation

Dispatches parallel subagents to analyze your codebase across 6 dimensions and surface actionable improvement ideas. Each idea is assigned a unique ID so you can accept, dismiss, and convert to GitHub issues.

**6 Ideation Types:**

| Alias | Full Name | What It Covers |
|-------|-----------|----------------|
| `ci` | code-improvements | Refactoring opportunities, architectural improvements, tech debt reduction |
| `cq` | code-quality | Linting issues, complexity hotspots, naming, dead code, duplication |
| `doc` | documentation | Missing or stale docs, README gaps, inline comment coverage |
| `sec` | security | OWASP-aligned findings, dependency vulnerabilities, auth and input handling |
| `perf` | performance | Slow queries, N+1 patterns, asset loading, memory hotspots, caching gaps |
| `ux` | ui-ux | Accessibility issues, interaction patterns, error messaging, visual consistency |

### /ideation-marketing

Performs a full marketing audit of your project — combining technical SEO analysis, content strategy, growth tactics, and brand positioning into an interactive HTML report. Integrates with analytics tools (via CLI or MCP) and analyzes your live URL for SEO signals.

**4 Marketing Analysis Types:**

| Alias | Full Name | What It Covers |
|-------|-----------|----------------|
| `seo` | seo-technical | Meta tags, Open Graph, structured data, sitemap, crawlability |
| `content` | content-strategy | Blog topics, tutorials, case studies, content calendar |
| `growth` | growth-tactics | Onboarding, referrals, community, launch strategies |
| `brand` | brand-positioning | Messaging, differentiation, value prop, audience |

### /roadmap

Generates a prioritized strategic roadmap based on deep discovery of your codebase, open issues, recent commits, and competitive research. Features are scored by impact and effort, grouped into phases, and surfaced in an interactive HTML report.

---

## Installation

```bash
claude plugin marketplace add bvdr
claude plugin install bvdr-ideation-and-roadmap
```

---

## Usage

### /ideation

```
/ideation                              — run all 6 ideation types
/ideation --only type1,type2           — run specific types (aliases: ci, cq, doc, sec, perf, ux)
/ideation --refresh                    — force re-run deep analysis (ignores cached discovery)
/ideation --no-open                    — don't auto-open HTML report after generation
/ideation help                         — show usage

/ideation accept id1 id2 ...           — mark ideas as accepted
/ideation dismiss id [--reason "..."]  — mark idea as dismissed with optional reason
/ideation status                       — show review summary (accepted / dismissed / pending counts)
/ideation create-issues                — create GitHub issues for all accepted ideas
/ideation create-issue id              — create a single GitHub issue for one idea
```

**Examples:**

```bash
# Run only security and performance analysis
/ideation --only sec,perf

# Run everything and keep the terminal focused (no browser open)
/ideation --no-open

# Review ideas
/ideation status
/ideation accept idea-042 idea-007
/ideation dismiss idea-013 --reason "out of scope for v2"

# Push to GitHub
/ideation create-issues
```

---

### /ideation-marketing

```
/ideation-marketing                              — run all 4 marketing analysis types
/ideation-marketing --only type1,type2           — run specific types (aliases: seo, content, growth, brand)
/ideation-marketing --refresh                    — force re-run deep analysis (ignores cached discovery)
/ideation-marketing --skip-live                  — skip live URL & marketing landscape analysis (offline/CI use)
/ideation-marketing --no-open                    — don't auto-open HTML report after generation
/ideation-marketing help                         — show usage

/ideation-marketing accept id1 id2 ...           — mark ideas as accepted
/ideation-marketing dismiss id [--reason "..."]  — mark idea as dismissed with optional reason
/ideation-marketing status                       — show review summary
/ideation-marketing create-issues                — create GitHub issues for all accepted ideas
/ideation-marketing create-issue id              — create a single GitHub issue for one idea
```

**Examples:**

```bash
# Run only SEO and content strategy analysis
/ideation-marketing --only seo,content

# Run without live URL analysis (offline mode)
/ideation-marketing --skip-live

# Review ideas
/ideation-marketing status
/ideation-marketing accept mkt-seo-001 mkt-content-003
/ideation-marketing dismiss mkt-growth-005 --reason "not applicable to B2B"

# Push to GitHub
/ideation-marketing create-issues
```

---

### /roadmap

```
/roadmap                               — generate full roadmap
/roadmap --refresh                     — force re-run deep analysis
/roadmap --skip-discovery              — reuse existing discovery.json (skip codebase scan)
/roadmap --no-open                     — don't auto-open HTML report
/roadmap help                          — show usage

/roadmap accept id1 id2 ...            — mark features as accepted
/roadmap dismiss id [--reason "..."]   — mark feature as dismissed with optional reason
/roadmap status                        — show review summary
/roadmap create-issues                 — create GitHub issues for all accepted features
/roadmap create-issue id               — create a single GitHub issue for one feature
```

**Examples:**

```bash
# Generate roadmap reusing last discovery scan
/roadmap --skip-discovery

# Review and act on features
/roadmap status
/roadmap accept feature-001 feature-005
/roadmap dismiss feature-009 --reason "blocked by external dependency"
/roadmap create-issues
```

---

## How Deep Analysis Works

Before generating ideas or a roadmap, the plugin runs a discovery phase that collects:

- **Last 500 commits** — identifies churn hotspots, recent focus areas, and velocity trends
- **Merged PRs from the last year** — surfaces patterns in what got built and what got reverted
- **All open issues** — understands existing backlog and community pain points
- **Competitive research** — web searches for comparable products, recent industry trends, and common feature gaps in your domain
- **Claude project context** — reads your CLAUDE.md, README, package manifests, and config files to understand the tech stack and constraints

Discovery results are cached in `.claude/ideation/discovery.json` and `.claude/roadmap/discovery.json`. Use `--refresh` to invalidate the cache and re-run from scratch, or `--skip-discovery` (roadmap only) to skip the scan entirely and reuse whatever was last cached.

---

## Output

### Directories

```
.claude/
  ideation/
    deep-analysis.json                    — cached codebase + competitive analysis
    ideation-N/
      ideation.json                       — all generated ideas with IDs and status
      report.html                         — interactive HTML report
  marketing-ideation/
    deep-analysis.json                    — cached marketing context analysis
    issues-tracker.json                   — maps ideas to GH issues (shared across runs)
    marketing-ideation-N/
      marketing-ideation.json             — all generated marketing ideas with IDs and status
      report.html                         — interactive HTML report
      seo_technical_ideas.json            — SEO agent output
      content_strategy_ideas.json         — content agent output
      growth_tactics_ideas.json           — growth agent output
      brand_positioning_ideas.json        — brand agent output
  roadmap/
    discovery.json                        — cached codebase + competitive analysis
    features.json                         — all generated features with IDs and status
    report.html                           — interactive HTML report
```

### HTML Reports

Both commands produce a self-contained interactive HTML report that opens automatically in your browser (pass `--no-open` to skip). Reports include:

- Filter by type, priority, and status
- Toggle dark / light mode
- Expandable detail cards for each idea or feature
- Effort vs. impact scoring visualization (roadmap)
- Export to clipboard or markdown

---

## GitHub Issue Lifecycle

Ideas and features move through a simple lifecycle:

```
pending → accepted → created (GitHub issue)
        ↘ dismissed
```

- Use `accept` / `dismiss` to triage in `.claude/*/ideas.json` or `features.json`
- Use `create-issues` or `create-issue id` to push accepted items to GitHub as issues
- Issues are labeled automatically based on type (`ideation`, `roadmap`, `security`, `performance`, etc.)
- Already-created issues are skipped on subsequent runs (idempotent)
