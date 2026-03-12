---
description: Use when creating or running Umami Analytics reports — funnels, user journeys, retention, goals, UTM campaigns, attribution, breakdown, or revenue reports.
---

# Umami Reports

Create and run all 8 Umami report types via the API. Read operations execute directly. Write operations (create, update, delete) ask for confirmation first.

## Prerequisites

Read `.umami.json` from project root for `host`, `websiteId`, `token`. If missing, invoke `bvdr:umami-setup`.

## Report CRUD

### List reports
```bash
curl -s "{host}/api/reports?websiteId={websiteId}" \
  -H "Authorization: Bearer {token}"
```

### Create report (confirm first)
```bash
curl -s -X POST "{host}/api/reports" \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "websiteId": "{websiteId}",
    "type": "{reportType}",
    "name": "{reportName}",
    "description": "{description}",
    "parameters": { ... }
  }'
```

### Get report
```bash
curl -s "{host}/api/reports/{reportId}" \
  -H "Authorization: Bearer {token}"
```

### Update report (confirm first)
Note: Umami uses POST for updates (not PUT). Verify against your instance version at implementation time.
```bash
curl -s -X POST "{host}/api/reports/{reportId}" \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{ "name": "...", "parameters": { ... } }'
```

### Delete report (confirm first)
```bash
curl -s -X DELETE "{host}/api/reports/{reportId}" \
  -H "Authorization: Bearer {token}"
```

---

## Report Types

### Funnel

Track sequential step completion with drop-off rates.

```bash
curl -s -X POST "{host}/api/reports/funnel" \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "websiteId": "{websiteId}",
    "startDate": "2026-01-01T00:00:00Z",
    "endDate": "2026-03-12T23:59:59Z",
    "timezone": "Europe/Bucharest",
    "window": 60,
    "steps": [
      { "type": "path", "value": "/pricing" },
      { "type": "path", "value": "/signup" },
      { "type": "event", "value": "purchase-complete" }
    ]
  }'
```

- `steps` — minimum 2. Each step has `type` (`path` or `event`) and `value`
- `window` — time window in **minutes** a user has between funnel steps to count as a conversion
- Steps must be completed in order (other pages can be visited between steps)
- Output: step completion counts and drop-off rates

### Journey

Visualize top user navigation pathways.

```bash
curl -s -X POST "{host}/api/reports/journey" \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "websiteId": "{websiteId}",
    "startDate": "2026-01-01T00:00:00Z",
    "endDate": "2026-03-12T23:59:59Z",
    "timezone": "Europe/Bucharest",
    "steps": 5,
    "startStep": "/landing",
    "endStep": "/checkout/success"
  }'
```

- `steps` — 3 to 7 (depth of navigation path)
- `startStep` (optional) — specific page URL or event name to start from
- `endStep` (optional) — specific page URL or event name to end at
- Output: top pathways, conversion/drop-off at each node

### Retention

Cohort-based analysis of returning visitors.

```bash
curl -s -X POST "{host}/api/reports/retention" \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "websiteId": "{websiteId}",
    "startDate": "2026-01-01T00:00:00Z",
    "endDate": "2026-03-12T23:59:59Z",
    "timezone": "Europe/Bucharest"
  }'
```

- The API accepts `startDate`/`endDate` for the range. The UI also exposes a single `date` (month/year) picker for cohort selection — if your instance version uses that instead, pass `date` as `"YYYY-MM-01"` format.
- Output: cohort grid showing distinct visitors per day and their return frequency

### Goals

Track conversion rates against total visitors.

```bash
curl -s -X POST "{host}/api/reports/goals" \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "websiteId": "{websiteId}",
    "startDate": "2026-01-01T00:00:00Z",
    "endDate": "2026-03-12T23:59:59Z",
    "timezone": "Europe/Bucharest",
    "type": "path",
    "value": "/signup"
  }'
```

- `type` — `path` (viewed page) or `event` (triggered event)
- `value` — the URL path or event name to track as the conversion goal
- One goal per request. Run multiple requests to track multiple goals.
- Output: users hitting goal / total users = conversion rate

### UTM

Track campaign performance across 5 UTM parameters.

```bash
curl -s -X POST "{host}/api/reports/utm" \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "websiteId": "{websiteId}",
    "startDate": "2026-01-01T00:00:00Z",
    "endDate": "2026-03-12T23:59:59Z",
    "timezone": "Europe/Bucharest"
  }'
```

- Output: breakdown by Source, Medium, Campaign, Term, Content

### Breakdown

Segment analytics data by various dimensions.

```bash
curl -s -X POST "{host}/api/reports/breakdown" \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "websiteId": "{websiteId}",
    "startDate": "2026-01-01T00:00:00Z",
    "endDate": "2026-03-12T23:59:59Z",
    "timezone": "Europe/Bucharest",
    "fields": ["path"]
  }'
```

- `fields` — what to segment by (default: Path)
- Metrics returned: Visitors, Visits, Views, Bounce Rate, Visit Duration

### Attribution

Attribute conversions to traffic sources.

```bash
curl -s -X POST "{host}/api/reports/attribution" \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "websiteId": "{websiteId}",
    "startDate": "2026-01-01T00:00:00Z",
    "endDate": "2026-03-12T23:59:59Z",
    "timezone": "Europe/Bucharest",
    "model": "first-click",
    "type": "path",
    "step": "/checkout/success"
  }'
```

- `model` — `first-click` or `last-click`
- `type` — `path` (viewed page) or `event` (triggered event)
- `step` — the URL path or event name that counts as the conversion step
- Output: referrer sources attributed through chosen model

### Revenue

Aggregate revenue data from tracked events.

```bash
curl -s -X POST "{host}/api/reports/revenue" \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "websiteId": "{websiteId}",
    "startDate": "2026-01-01T00:00:00Z",
    "endDate": "2026-03-12T23:59:59Z",
    "timezone": "Europe/Bucharest",
    "currency": "USD"
  }'
```

- `currency` — ISO 4217 code (defaults to USD if unrecognized)
- Requires events tracked with `revenue` (number) and `currency` (string) properties
- Track via JS: `umami.track('purchase', { revenue: 19.99, currency: 'USD' })`

---

## Common Parameters (all report endpoints)

- `websiteId` — website UUID
- `startDate`, `endDate` — ISO 8601 format (e.g., `2026-01-01T00:00:00Z`)
- `timezone` — IANA timezone (e.g., `Europe/Bucharest`, `America/New_York`)
- Filters: `path`, `referrer`, `title`, `query`, `browser`, `os`, `device`, `country`, `region`, `city`, `hostname`, `tag`, `distinctId`, `segment`, `cohort`

## Behavior Rules

- **Read operations** (list reports, get report, run report queries) → execute directly, show results
- **Write operations** (create, update, delete reports) → always ask for user confirmation first
- Format results as readable tables when possible
- When presenting funnel results, highlight the biggest drop-off step
- When presenting journey results, show the top 3-5 pathways
