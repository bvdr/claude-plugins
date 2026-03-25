# /ideation-marketing Command Design Spec

## Overview

A standalone `/ideation-marketing` command for the `bvdr-ideation-and-roadmap` plugin that performs a full marketing audit — covering both strategy/content ideas and technical marketing improvements — for any project it analyzes.

Completely independent from `/ideation` and `/roadmap`. Own context pipeline, own specialist agents, own HTML report template.

## Requirements

- Standalone top-level command (not a subcommand of `/ideation`)
- Full marketing audit: strategy/content ideas AND technical marketing improvements
- Marketing-specific context agents that still understand the project deeply
- Live URL discovery and analysis (meta tags, Open Graph, social presence)
- Analytics integration via CLI tools or MCP servers when available
- 4 parallel specialist agents: `seo-technical`, `content-strategy`, `growth-tactics`, `brand-positioning`
- Forked HTML report template with marketing-specific sections
- Marketing-specific GitHub issue labels
- Same subcommand pattern as `/ideation`: run, help, accept, dismiss, status, create-issues, create-issue

## Command Structure

### Subcommands

| Subcommand | Description |
|------------|-------------|
| `run` (default) | Full marketing audit |
| `help` | Usage info |
| `accept <id> [id...]` | Accept marketing ideas |
| `dismiss <id> [id...]` | Dismiss ideas |
| `status` | Show current idea statuses |
| `create-issues` | Create GitHub issues for all accepted ideas |
| `create-issue <id>` | Create a single GitHub issue |

### Flags

| Flag | Description |
|------|-------------|
| `--only <types>` | Run only specific agents (e.g., `--only seo-technical,content-strategy`) |
| `--refresh` | Force re-run context agents, ignore 24hr cache |
| `--no-open` | Don't auto-open HTML report in browser |
| `--skip-live` | Skip live URL analysis (for offline/CI use) |

## Output Directory Structure

```
{PROJECT_ROOT}/.claude/marketing-ideation/
├── deep-analysis.json              # Marketing-specific context cache (24hr TTL)
├── marketing-ideation-1/           # Auto-incremented per run
│   ├── marketing-ideation.json     # Final merged ideas
│   ├── report.html                 # Interactive report
│   ├── .gitignore
│   ├── Readme.txt
│   ├── seo_technical_ideas.json    # Agent outputs
│   ├── content_strategy_ideas.json
│   ├── growth_tactics_ideas.json
│   └── brand_positioning_ideas.json
├── marketing-ideation-2/
│   └── ...
└── issues-tracker.json             # Maps ideas to GH issues
```

## Idea Schema

```json
{
  "id": "mkt-seo-001",
  "type": "seo-technical|content-strategy|growth-tactics|brand-positioning",
  "title": "Short descriptive title",
  "description": "What this improvement does",
  "rationale": "Why the code/market/data reveals this opportunity",
  "estimated_effort": "trivial|small|medium|large|complex",
  "affected_files": ["file1.ts"],
  "related_issues": [{ "number": 42, "title": "...", "relationship": "addresses|complements" }],
  "status": "draft|pending|accepted|dismissed|created",
  "created_at": "ISO timestamp",
  "data_sources": ["analytics", "live-scan", "competitive-research", "codebase"]
}
```

The `data_sources` field is new compared to `/ideation` — tracks which data informed the idea so users know the confidence level.

## Pipeline Architecture

### Phase 0: Setup

- Parse arguments, detect subcommand and flags
- Detect PROJECT_ROOT (git root)
- Create output directory `.claude/marketing-ideation/marketing-ideation-{N}/`
- Check cache: `deep-analysis.json` (24hr TTL, respect `--refresh` flag)

### Phase 1: Context Agents (3 sequential)

#### Agent 1: `project-understanding.md`

Lighter version of git-analysis + codebase-scan, focused on marketing-relevant signals.

**Analyzes**:
- Recent commits (200), merged PRs (6 months), open issues — filtered for public-facing changes (UI, docs, landing pages, README, changelogs)
- Tech stack, project type, README summary, existing public-facing assets (landing pages, docs site, blog, changelog)
- Target audience inference from README, docs, package description, GitHub topics

**Output**: `project-understanding.json`
- `project_name`, `project_type`, `project_summary`
- `tech_stack`, `target_audience`
- `public_assets`: detected landing pages, docs sites, blogs, social links
- `recent_highlights`: shipped features worth marketing, notable milestones
- `github_metrics`: stars, forks, open issues count, contributor count

#### Agent 2: `marketing-landscape.md`

Competitors' marketing tactics (not features).

**Analyzes**:
- Blog frequency, content types, SEO keywords targeted
- Social channels, community presence
- Pricing page tactics, onboarding flows

**Output**: `marketing-landscape.json`
- `competitors`: [{name, url, content_strategy, social_channels, seo_keywords, community_presence, strengths, weaknesses}]
- `market_gaps`: marketing angles competitors aren't covering
- `keyword_opportunities`: terms with potential based on competitor analysis
- `content_patterns`: what content types perform in this space

#### Agent 3: `live-analysis.md`

Discovers and analyzes the project's live presence. Skipped if `--skip-live` flag is set.

**URL Discovery**: checks README, `package.json` homepage, GitHub Pages, repo description, docs config files.

**If URL found**: web fetch to analyze meta tags, Open Graph tags, Twitter cards, structured data, robots.txt, sitemap.xml presence.

**Analytics Integration** (discovery cascade):
1. Check for MCP servers — analytics-related MCP servers (Google Analytics, Plausible, PostHog, Mixpanel, Vercel Analytics). Preferred — gives structured data access.
2. Check for CLI tools — `vercel analytics`, `plausible-cli`, `posthog`, `netlify`, or project-specific scripts in `package.json`.
3. Check for analytics config in codebase — scan for `gtag` IDs, Plausible script tags, PostHog init calls to identify what's tracked even without data access.
4. If nothing found — record "no analytics access" as a finding, note which provider appears configured, suggest how to enable access.

**Data extraction when access exists** (pull what's available, don't fail if partial):
- Traffic overview: page views, unique visitors, bounce rate (last 30 days)
- Top pages: most visited pages/routes
- Referral sources: where traffic comes from
- Search queries: what terms drive organic traffic
- User flow: common entry/exit pages

**Social presence**: searches for the project on Twitter/X, Reddit, HackerNews, DEV.to, Product Hunt.

**If no URL found**: logs it as a finding ("project has no public URL — marketing gap"), skips web analysis, continues with social/community signals.

**Output**: `live-analysis.json`
- `live_url`: detected URL or null
- `seo_signals`: {meta_tags, open_graph, twitter_cards, structured_data, robots_txt, sitemap}
- `analytics_data`: {source, metrics} or null
- `social_presence`: [{platform, url, followers, activity_level}]
- `community_mentions`: [{platform, url, sentiment, date}]

All three merge into `deep-analysis.json` at the base directory level, cached 24 hours.

### Phase 2: Specialist Agents (4 parallel)

All agents consume `deep-analysis.json`. Maximum 15 ideas per agent. Must reference `data_sources` for each idea. Must check open issues to avoid duplicating existing work. Must prioritize ideas around recently shipped features.

#### `seo-technical.md`

Technical marketing improvements in or missing from the codebase.

**Analyzes**: meta tags, Open Graph, Twitter cards, structured data (JSON-LD), canonical URLs, sitemap.xml, robots.txt, alt text, semantic HTML, URL structure, page load signals.

**Cross-references**: live-analysis SEO signals, analytics search queries, competitor keyword opportunities.

**Idea types**: missing meta tags, broken Open Graph previews, missing structured data, sitemap gaps, crawlability issues, heavy tracking scripts, accessibility as SEO.

**ID prefix**: `mkt-seo-NNN`

#### `content-strategy.md`

Content ideas grounded in the project and market gaps.

**Analyzes**: README quality, existing docs/blog, changelog, feature list, competitor content patterns, community questions (issues, discussions), analytics top pages.

**Idea types**: blog post topics (tied to shipped features or competitive gaps), tutorial opportunities, case study angles, comparison pages, changelog-to-marketing pipeline, docs-as-marketing improvements, content calendar suggestions.

**Each idea includes**: suggested title, target audience, key angle, estimated reach/impact.

**ID prefix**: `mkt-content-NNN`

#### `growth-tactics.md`

Actionable growth and distribution opportunities.

**Analyzes**: onboarding flow (README → install → first use), referral/sharing mechanisms, community presence, social channels, analytics user flow and drop-offs, competitor growth tactics.

**Idea types**: onboarding improvements, referral mechanisms, community building (Discord, GitHub Discussions), launch strategies (Product Hunt, HackerNews), partnership/integration opportunities, contributor attraction, newsletter setup, social sharing from product.

**ID prefix**: `mkt-growth-NNN`

#### `brand-positioning.md`

Messaging, differentiation, and market positioning.

**Analyzes**: current messaging (README, tagline, description), competitor positioning, market gaps, community sentiment, GitHub star/fork trajectory.

**Idea types**: tagline/value prop improvements, README messaging rewrite, "why us vs X" positioning, unique angle identification, audience segmentation, pricing/tier positioning, visual identity observations.

**ID prefix**: `mkt-brand-NNN`

### Phase 3: Merge & Report

1. Collect 4 agent output files
2. Normalize fields (effort levels, file naming, type dashes → underscores for HTML)
3. Merge with existing `marketing-ideation.json` (preserve accepted/dismissed/created items, remove old pending items, auto-dismiss duplicates of previously dismissed ideas by title+type)
4. Generate summary stats by type, status, effort
5. Sanitize JSON for HTML injection (escape backticks, `${`, `</script>`)
6. Inject into marketing report template
7. Write `marketing-ideation.json` and `report.html` to run directory
8. Open report in browser (unless `--no-open`)
9. Print terminal summary: top 5 quick wins, breakdown by type

### How Specialist Agents Use Analytics Data

| Agent | Uses analytics for |
|-------|-------------------|
| `seo-technical` | Top search queries, organic traffic trends, pages missing from search |
| `content-strategy` | Top pages (what resonates), referral sources (where audience lives), content coverage gaps |
| `growth-tactics` | User flow (drop-off points), bounce rate (onboarding issues), referral sources (partnership opportunities) |
| `brand-positioning` | Traffic vs competitors, audience demographics, sentiment from community mentions |

Analytics data is a bonus, not a requirement. Every agent works without it — ideas are less data-informed but still valid. The `data_sources` field tracks availability.

## HTML Report Template

Forked from `ideation-report-template.html` with marketing-specific customizations.

### Color scheme

| Type | Color | Rationale |
|------|-------|-----------|
| `seo-technical` | Green | Technical, actionable |
| `content-strategy` | Blue | Creative, content |
| `growth-tactics` | Orange | Growth, action-oriented |
| `brand-positioning` | Purple | Strategic, brand |

### Marketing-specific sections

- **Marketing Health Score** — top-level summary card with quick assessment across 4 domains (SEO coverage, content presence, growth mechanisms, brand clarity), derived from ideas found
- **Data Sources Badge** — each idea card shows which sources informed it (codebase, live-scan, analytics, competitive-research) as small badges
- **Analytics Summary** — if analytics data was available, sidebar panel with key metrics (traffic, top pages, referral sources) as context
- **Quick Wins section** — filtered view of trivial/small effort ideas, front and center

### Preserved from ideation template

- Filter by type, status, effort
- Dark/light mode toggle
- Search
- Expandable detail cards
- Export to clipboard/markdown
- Deep Analysis summary panel

## GitHub Issue Integration

### Labels

Each issue gets two labels:
- Type label: `seo-technical`, `content-strategy`, `growth-tactics`, or `brand-positioning`
- Source label: `marketing-ideation`

### Issue body format

```markdown
## {title}

{description}

### Rationale
{rationale}

### Data Sources
{data_sources as list}

### Estimated Effort
{estimated_effort}

### Affected Files
{affected_files or "Strategy idea — no specific files"}

---
*Generated by /ideation-marketing*
```

### Idempotency

Same pattern as `/ideation`:
- `issues-tracker.json` prevents duplicate issue creation
- `status: "created"` + `gh_issue` field links back to GitHub
- Safe to re-run `create-issues` without duplicates

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Missing agent files | Log warning, skip that type, continue with others |
| JSON parse errors | Log warning, skip that file, merge available data |
| No live URL found | Record as finding, skip web analysis, continue |
| Analytics unavailable | Record "no analytics access", continue without data |
| `gh` CLI unavailable | Print error and stop for create-issues operations |
| `open` fails (non-macOS) | Silently ignore, print path in terminal |
| Agent timeout | Continue with partial data, log warning |
| No git repo | Skip git phases, continue with codebase scan and web analysis |
| No GitHub remote | Skip PR/issue analysis, log warning |

## File Manifest

### New files (9)

| File | Purpose |
|------|---------|
| `commands/ideation-marketing.md` | Orchestrator command |
| `agents/marketing-context/project-understanding.md` | Context: project understanding |
| `agents/marketing-context/marketing-landscape.md` | Context: competitor marketing tactics |
| `agents/marketing-context/live-analysis.md` | Context: live URL + analytics + social |
| `agents/marketing/seo-technical.md` | Specialist: SEO & technical marketing |
| `agents/marketing/content-strategy.md` | Specialist: content ideas |
| `agents/marketing/growth-tactics.md` | Specialist: growth opportunities |
| `agents/marketing/brand-positioning.md` | Specialist: messaging & positioning |
| `assets/marketing-ideation-report-template.html` | Interactive HTML report |

### Modified files (2)

| File | Change |
|------|--------|
| `.claude-plugin/plugin.json` | Register `/ideation-marketing` command |
| `README.md` | Document the new command |

### Version bump

Minor version bump (e.g., `1.0.1` → `1.1.0`) in both `plugin.json` and `marketplace.json` (if exists).

## Effort Estimation Scale (shared with /ideation)

| Level | Time | Description |
|-------|------|-------------|
| trivial | 1-2 hours | Direct copy with minor changes |
| small | Half day | Clear pattern to follow |
| medium | 1-3 days | Pattern exists but needs adaptation |
| large | 3-7 days | Architectural pattern enables capability |
| complex | 1-2 weeks | Foundation supports major addition |
