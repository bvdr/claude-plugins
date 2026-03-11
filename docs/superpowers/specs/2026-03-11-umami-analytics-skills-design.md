# Umami Analytics Skills Suite — Design Spec

**Date:** 2026-03-11
**Status:** Draft
**Author:** Bogdan Dragomir

## Overview

A suite of 5 Claude Code skills for comprehensive Umami Analytics integration. Covers the full lifecycle: setup, tracking implementation, report creation, and data querying — all targeting self-hosted Umami instances.

## Goals

- Enable thorough tracking of everything a user does (pageviews, events, identity, revenue)
- Full user journey reconstruction across sessions via `umami.identify()` + distinct IDs
- Conversion optimization via funnels, goals, attribution reports
- Behavioral segmentation via retention, breakdown, cohort analysis
- Support both client-side (JS/HTML) and server-side (`POST /api/send`) tracking
- Execute API calls directly against the Umami instance (confirm before writes)

## Architecture

```
User says anything Umami-related
        │
  bvdr:using-umami (hub)
    │ Detects intent, checks .umami.json, routes
    │
    ├── bvdr:umami-setup      → Credentials, script tag, config, verify
    ├── bvdr:umami-track      → Client+server tracking implementation
    ├── bvdr:umami-reports    → Create/run 8 report types
    └── bvdr:umami-query      → Stats, metrics, events, sessions, realtime
```

### Config File: `.umami.json`

Stored at project root. **Must be added to `.gitignore`** (contains API token).

```json
{
  "host": "https://analytics.mysite.com",
  "websiteId": "94db1cb1-74f4-4a40-ad6c-962362670409",
  "token": "eyTxxxxx...",
  "domain": "mysite.com"
}
```

---

## Skill 1: `bvdr:using-umami` (Hub Router)

**Purpose:** Entry point for all Umami operations. Routes to the right sub-skill.

**Behavior:**

1. Check if `.umami.json` exists at project root
   - Missing → invoke `bvdr:umami-setup`
   - Present → read and validate required fields (`host`, `websiteId`, `token`)

2. Quick health check: `POST /api/auth/verify` with stored token
   - 401 → token expired, prompt re-auth via `umami-setup`
   - Connection fail → warn, suggest checking host URL
   - Note: `POST /api/auth/verify` is preferred over hitting a data endpoint — it's lighter and semantically correct for token validation

3. Route by intent:

| Intent keywords | Routes to |
|---|---|
| set up, connect, install, configure | `bvdr:umami-setup` |
| track, event, identify, implement, data attributes, revenue tracking, server-side | `bvdr:umami-track` |
| funnel, journey, retention, goal, UTM, attribution, breakdown, report | `bvdr:umami-reports` |
| stats, metrics, visitors, pageviews, sessions, realtime, query, event data | `bvdr:umami-query` |

4. Ambiguous intent → ask user to choose area

**The hub does NO implementation work.** Only routing + health check.

---

## Skill 2: `bvdr:umami-setup`

**Purpose:** First-time setup, connection verification, script tag installation.

**Flow:**

1. Check if `.umami.json` already exists
2. If not, collect:
   - Umami host URL
   - Username/password
3. Authenticate: `POST {host}/api/auth/login` → get token
4. List websites: `GET {host}/api/websites` → user picks or creates new
5. Write `.umami.json` to project root
6. Add `.umami.json` to `.gitignore` (create/append/skip as needed)
7. Detect project framework and install script tag:
   - **Next.js** → `<Script>` component in layout.tsx/app
   - **React (Vite/CRA)** → `<script>` in index.html
   - **Plain HTML** → `<script defer>` in `<head>`
   - Always includes `data-website-id` and correct `src`
8. Verify connection: `GET /api/websites/:websiteId` + `GET /api/websites/:websiteId/active`
9. Print summary: host, website name, domain, active visitor count

**Re-run behavior (`.umami.json` exists):** Offer to:
- Verify connection
- Refresh token (re-authenticate)
- Switch website
- Reconfigure from scratch

---

## Skill 3: `bvdr:umami-track`

**Purpose:** Implement comprehensive tracking in the user's codebase.

### Mode A: Tracking Plan (analyze + suggest)

Triggered by: "help me track", "what should I track", "analyze my app"

1. Read `.umami.json`
2. Scan codebase for:
   - Page routes/views (Next.js pages/app router, React Router, plain HTML)
   - User interaction points (forms, buttons, CTAs, checkout)
   - Auth flows (login, signup, logout — candidates for `umami.identify()`)
   - Revenue/purchase events
   - Existing Umami tracking (`umami.track`, `data-umami-event`)
3. Present tracking plan by category:
   - **Pageviews** — auto-tracked or manual overrides
   - **Identity** — where to call `umami.identify(userId, { ... })`
   - **Core events** — signup, login, key feature usage
   - **Conversion events** — purchase, subscription, form submit
   - **Engagement events** — clicks, feature discovery
   - **Revenue events** — `{ revenue: N, currency: 'USD' }`
4. After approval → implement

### Mode B: Direct Implementation

Triggered by: "track this button", "add event for X"

Implement using the appropriate method:

**HTML data attributes** (simple click tracking):
```html
<button data-umami-event="signup-click" data-umami-event-plan="pro">Sign up</button>
```

**JavaScript `umami.track()`** (typed data, conditional, non-click):
```javascript
umami.track('purchase-complete', { revenue: 49.99, currency: 'USD', plan: 'pro' });
```

**`umami.identify()`** (session identification):
```javascript
umami.identify(user.id, { name: user.name, plan: user.plan, role: user.role });
```

**Server-side `POST /api/send`** (backend events — **no authentication required**):
```javascript
fetch('https://analytics.mysite.com/api/send', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json', 'User-Agent': 'MyApp/1.0' },
  body: JSON.stringify({
    type: 'event',
    payload: {
      website: 'WEBSITE_ID',
      hostname: 'mysite.com',
      url: '/api/webhook',
      name: 'subscription-renewed',
      data: { plan: 'pro', mrr: 49.99 }
    }
  })
});
```

**Important:** The `/api/send` endpoint does **not** require an Authorization header. Do not attach the API token to these requests. Required fields: `website`, `hostname`, `url`. A valid `User-Agent` header must be present.

### Reference Constraints (baked into skill):

| Constraint | Limit |
|---|---|
| Event name | 50 characters max (documented) |
| String values | 500 characters max (from Umami docs track-events page) |
| Number precision | 4 decimal places (from Umami docs track-events page) |
| Object properties | 50 max (from Umami docs track-events page) |
| Arrays | Converted to string, 500 chars max (from Umami docs track-events page) |
| Distinct IDs | 50 characters max (from Umami docs distinct-ids page) |

### Gotchas (skill must warn about):

- Data attributes save all values as **strings** — use JS for typed data
- `data-umami-event` on an element **may block other click handlers**
- Event data **cannot** be sent without an event name
- `data-before-send` is the only hook to inspect/modify/cancel payloads
- `data-domains` matches `window.location.hostname` exactly (www vs non-www)
- GTM strips data attributes — must use dynamic script creation
- Revenue tracking requires both `revenue` (number) and `currency` (ISO 4217)

---

## Skill 4: `bvdr:umami-reports`

**Purpose:** Create and run all 8 Umami report types via the API.

**Behavior:**
- Read operations → execute directly
- Write operations (create/delete report) → ask for confirmation first

### Report CRUD

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/reports` | List all reports |
| POST | `/api/reports` | Create report (confirm first) |
| GET | `/api/reports/:reportId` | Get one |
| POST | `/api/reports/:reportId` | Update (confirm first) |
| DELETE | `/api/reports/:reportId` | Delete (confirm first) |

### Report Types

**Funnel** (`POST /api/reports/funnel`)
- `steps` (min 2) — URL path or event name per step
- `window` — time window between steps for conversion (verify unit — hours or days — against API at implementation time)
- Output: step completion counts, drop-off rates

**Journey** (`POST /api/reports/journey`)
- `steps` (3–7) — navigation path depth
- `startStep` (optional) — page or event to start from
- `endStep` (optional) — page or event to end at
- Output: top pathways, conversion/drop-off per node

**Retention** (`POST /api/reports/retention`)
- `date` — month/year for cohort
- Output: cohort grid, distinct visitors and return frequency

**Goals** (`POST /api/reports/goals`)
- `action` — page URL or event name
- Output: users hitting action / total users = conversion rate

**UTM** (`POST /api/reports/utm`)
- Date range only
- Output: breakdown by Source, Medium, Campaign, Term, Content

**Breakdown** (`POST /api/reports/breakdown`)
- `fields` — what to segment by (default: Path)
- Metrics: Visitors, Visits, Views, Bounce Rate, Visit Duration

**Attribution** (`POST /api/reports/attribution`)
- `model` — First-Click or Last-Click
- `type` — viewed page or triggered event
- `conversionStep` — URL or event that counts as conversion
- Output: referrer sources through chosen model

**Revenue** (`POST /api/reports/revenue`)
- `currency` — ISO 4217 code (defaults to USD)
- Output: aggregated revenue from events with `revenue` + `currency` properties

### Common Parameters (all report endpoints)

- `startDate`, `endDate` — ISO 8601 format
- `timezone`
- Filters: `path`, `referrer`, `title`, `query`, `browser`, `os`, `device`, `country`, `region`, `city`, `hostname`, `tag`, `distinctId`, `segment`, `cohort`

---

## Skill 5: `bvdr:umami-query`

**Purpose:** Query the Umami API for analytics data. All read-only — executes directly.

### Endpoints

**Stats** (`GET /api/websites/:websiteId/stats`)
- Params: `startAt` (ms), `endAt` (ms), filters
- Response: pageviews, visitors, visits, bounces, totaltime
- Comparison: `compare=prev` or `compare=yoy`

**Pageviews** (`GET /api/websites/:websiteId/pageviews`)
- Params: `startAt`, `endAt`, `unit` (year|month|day|hour|minute), `timezone`
- Unit limits: minute (60 min max), hour (30 days max), day (6 months max), month/year (no limit)

**Metrics** (`GET /api/websites/:websiteId/metrics`)
- `type`: path, entry, exit, title, query, referrer, channel, domain, country, region, city, browser, os, device, language, screen, event, hostname, tag, distinctId
- Params: `limit` (default 500), `offset`

**Expanded metrics** (`GET /api/websites/:websiteId/metrics/expanded`)
- Same params, richer response: name, pageviews, visitors, visits, bounces, totaltime

**Event series** (`GET /api/websites/:websiteId/events/series`)
- Time series per event name

**Event data exploration:**
- `GET .../event-data/events` — event names + properties + data types
- `GET .../event-data/fields` — property names + values + totals
- `GET .../event-data/values` — values for specific event + property
- `GET .../event-data/properties` — event / property / total mappings
- `GET .../event-data/stats` — summary counts

**Sessions:**
- `GET .../sessions` — paginated list
- `GET .../sessions/:sessionId` — single session
- `GET .../sessions/:sessionId/activity` — full activity log
- `GET .../sessions/:sessionId/properties` — custom properties
- `GET .../sessions/stats` — aggregate stats
- `GET .../sessions/weekly` — 24h x 7 day heatmap
- `GET .../session-data/properties` — aggregate property data
- `GET .../session-data/values` — aggregate value data

**Realtime** (`GET /api/realtime/:websiteId`)
- Last 30 minutes: countries, URLs, referrers, events, series, totals

**Active** (`GET /api/websites/:websiteId/active`)
- Unique visitors in last 5 minutes

### Smart Defaults

- No date range specified → default to last 7 days
- "today" → calculate ms timestamps for current day
- Format results as readable tables
- Suggest follow-up queries (high bounce → "want to see exit pages?")

### Timestamp Handling

- Stats/metrics endpoints: `startAt`/`endAt` in **milliseconds since epoch**
- Report endpoints: `startDate`/`endDate` in **ISO 8601**
- Skills handle conversion automatically

---

## Validation Process

After writing each skill file, the skill content is validated against the live Umami documentation:

1. Fetch relevant doc pages (`umami.is/docs/...`)
2. Cross-check every method signature, parameter name, endpoint path, and constraint
3. Fix any discrepancies before finalizing

---

## File Structure

```
plugins/bvdr/commands/
├── using-umami.md          # Hub router
├── umami-setup.md          # Setup & config
├── umami-track.md          # Tracking implementation
├── umami-reports.md        # Report creation & execution
└── umami-query.md          # Data querying
```

## Plugin Registration

Skills registered in `plugins/bvdr/.claude-plugin/plugin.json` under the existing `bvdr` plugin.

## Error Handling

- **401 Unauthorized** → token expired. Route to `umami-setup` for re-authentication.
- **404 Not Found** → website ID may have been deleted. Warn user, suggest running setup again.
- **Connection refused / timeout** → host unreachable. Display the configured host URL, suggest checking if the instance is running.
- **Pagination** → list endpoints (websites, sessions, events, reports) support `page` + `pageSize`. Skills should handle pagination automatically for large result sets.
- **Token lifecycle** → self-hosted Umami JWT tokens do not expire by default, but the instance admin can configure expiry. Use `POST /api/auth/verify` to validate before data calls. If verification fails, re-authenticate transparently.

## Security

- `.umami.json` contains API token — **must** be in `.gitignore`
- Skills never commit `.umami.json`
- Token is only used for API calls, never displayed in full
