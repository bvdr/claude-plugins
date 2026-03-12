---
description: Use when querying Umami Analytics data — viewing stats, metrics, event data, session activity, realtime visitors, or exploring analytics data via the API.
---

# Umami Query

Query the Umami API for analytics data. All operations are read-only and execute directly.

## Prerequisites

Read `.umami.json` from project root for `host`, `websiteId`, `token`. If missing, invoke `bvdr:umami-setup`.

## Smart Defaults

- No date range specified → default to **last 7 days**
- User says "today" → calculate `startAt`/`endAt` for current day
- User says "this month" → first day of current month to now
- All `startAt`/`endAt` values are in **milliseconds since epoch**
- Calculate with: `date +%s000` (bash) or `Date.now()` (JS)
- Format results as readable tables
- After showing results, suggest relevant follow-up queries

## Endpoints

### Website Stats

Overview metrics for a date range.

```bash
curl -s "{host}/api/websites/{websiteId}/stats?startAt={startMs}&endAt={endMs}" \
  -H "Authorization: Bearer {token}"
```

Response: `{ "pageviews": N, "visitors": N, "visits": N, "bounces": N, "totaltime": N, "comparison": {...} }`

### Active Visitors

Unique visitors in last 5 minutes.

```bash
curl -s "{host}/api/websites/{websiteId}/active" \
  -H "Authorization: Bearer {token}"
```

Response: `{ "visitors": N }`

### Pageviews Over Time

Time series of pageviews and sessions.

```bash
curl -s "{host}/api/websites/{websiteId}/pageviews?startAt={startMs}&endAt={endMs}&unit=day&timezone=Europe/Bucharest" \
  -H "Authorization: Bearer {token}"
```

`unit` values and limits:
- `minute` — max range: 60 minutes
- `hour` — max range: 30 days
- `day` — max range: 6 months
- `month`, `year` — no limit

Add `&compare=prev` for previous period comparison or `&compare=yoy` for year-over-year.

Response: `{ "pageviews": [{"x": "2026-03-01", "y": 150}], "sessions": [{"x": "2026-03-01", "y": 80}] }`

### Metrics Breakdown

Break down data by any dimension.

```bash
curl -s "{host}/api/websites/{websiteId}/metrics?startAt={startMs}&endAt={endMs}&type=path&limit=20" \
  -H "Authorization: Bearer {token}"
```

`type` values: `path`, `entry`, `exit`, `title`, `query`, `referrer`, `channel`, `domain`, `country`, `region`, `city`, `browser`, `os`, `device`, `language`, `screen`, `event`, `hostname`, `tag`, `distinctId`

Params: `limit` (default 500), `offset` (default 0)

Response: `[{ "x": "/about", "y": 342 }]`

### Expanded Metrics

Richer per-entry breakdown.

```bash
curl -s "{host}/api/websites/{websiteId}/metrics/expanded?startAt={startMs}&endAt={endMs}&type=path" \
  -H "Authorization: Bearer {token}"
```

Response: `[{ "name": "/about", "pageviews": 342, "visitors": 120, "visits": 150, "bounces": 40, "totaltime": 52000 }]`

### Event Series

Time series per event name.

```bash
curl -s "{host}/api/websites/{websiteId}/events/series?startAt={startMs}&endAt={endMs}&unit=day&timezone=Europe/Bucharest" \
  -H "Authorization: Bearer {token}"
```

Response: `[{ "x": "signup-click", "t": "2026-03-01", "y": 15 }]`

### Events List

Paginated list of website event details within a time range.

```bash
curl -s "{host}/api/websites/{websiteId}/events?startAt={startMs}&endAt={endMs}&page=1&pageSize=20" \
  -H "Authorization: Bearer {token}"
```

Optional: `&search={text}` to filter by event name. Response includes `data` array, `count`, `page`, `pageSize`.

### Event Data (Grouped)

Event data grouped by event name.

```bash
curl -s "{host}/api/websites/{websiteId}/event-data?startAt={startMs}&endAt={endMs}" \
  -H "Authorization: Bearer {token}"
```

**Single event by ID:**
```bash
curl -s "{host}/api/websites/{websiteId}/event-data/{eventId}" \
  -H "Authorization: Bearer {token}"
```

### Event Data Exploration

**List events with their properties:**
```bash
curl -s "{host}/api/websites/{websiteId}/event-data/events?startAt={startMs}&endAt={endMs}" \
  -H "Authorization: Bearer {token}"
```
Response: `[{ "eventName": "purchase", "propertyName": "plan", "dataType": 1, "total": 50 }]`
Data types: 1 = string, 2 = number

**List all property fields:**
```bash
curl -s "{host}/api/websites/{websiteId}/event-data/fields?startAt={startMs}&endAt={endMs}" \
  -H "Authorization: Bearer {token}"
```

**Get values for a specific event + property:**
```bash
curl -s "{host}/api/websites/{websiteId}/event-data/values?startAt={startMs}&endAt={endMs}&event=purchase&propertyName=plan" \
  -H "Authorization: Bearer {token}"
```
Response: `[{ "value": "pro", "total": 30 }, { "value": "free", "total": 20 }]`

**Event data properties summary:**
```bash
curl -s "{host}/api/websites/{websiteId}/event-data/properties?startAt={startMs}&endAt={endMs}" \
  -H "Authorization: Bearer {token}"
```
Response: `[{ "propertyName": "plan", "total": 50 }]`

**Event data stats overview:**
```bash
curl -s "{host}/api/websites/{websiteId}/event-data/stats?startAt={startMs}&endAt={endMs}" \
  -H "Authorization: Bearer {token}"
```
Response: `{ "events": N, "properties": N, "records": N }`

### Sessions

**List sessions:**
```bash
curl -s "{host}/api/websites/{websiteId}/sessions?startAt={startMs}&endAt={endMs}&page=1&pageSize=20" \
  -H "Authorization: Bearer {token}"
```

**Single session detail:**
```bash
curl -s "{host}/api/websites/{websiteId}/sessions/{sessionId}" \
  -H "Authorization: Bearer {token}"
```

**Session activity log (full journey for one session):**
```bash
curl -s "{host}/api/websites/{websiteId}/sessions/{sessionId}/activity" \
  -H "Authorization: Bearer {token}"
```

**Session properties:**
```bash
curl -s "{host}/api/websites/{websiteId}/sessions/{sessionId}/properties" \
  -H "Authorization: Bearer {token}"
```

**Session stats:**
```bash
curl -s "{host}/api/websites/{websiteId}/sessions/stats?startAt={startMs}&endAt={endMs}" \
  -H "Authorization: Bearer {token}"
```
Response: `{ "pageviews": { "value": N }, "visitors": { "value": N }, "visits": { "value": N }, "countries": { "value": N }, "events": { "value": N } }`

**Weekly heatmap (24h x 7 days):**
```bash
curl -s "{host}/api/websites/{websiteId}/sessions/weekly?startAt={startMs}&endAt={endMs}&timezone=Europe/Bucharest" \
  -H "Authorization: Bearer {token}"
```

**Aggregate session data:**
```bash
# Properties — counts by property name
curl -s "{host}/api/websites/{websiteId}/session-data/properties?startAt={startMs}&endAt={endMs}" \
  -H "Authorization: Bearer {token}"
# Response: [{ "propertyName": "plan", "total": 120 }]

# Values — counts for a specific property
curl -s "{host}/api/websites/{websiteId}/session-data/values?startAt={startMs}&endAt={endMs}&propertyName=plan" \
  -H "Authorization: Bearer {token}"
# Response: [{ "value": "pro", "total": 80 }]
```

### Realtime

Last 30 minutes of live activity.

```bash
curl -s "{host}/api/realtime/{websiteId}" \
  -H "Authorization: Bearer {token}"
```

Response includes: `countries`, `urls`, `referrers`, `events`, `series`, `totals` (views, visitors, events, countries).

---

## Filter Parameters

All endpoints that accept filters support these query parameters:

`path`, `referrer`, `title`, `query`, `browser`, `os`, `device`, `country`, `region`, `city`, `hostname`, `tag`, `distinctId`, `segment`, `cohort`

Example with filters:
```bash
curl -s "{host}/api/websites/{websiteId}/stats?startAt={startMs}&endAt={endMs}&country=US&browser=Chrome" \
  -H "Authorization: Bearer {token}"
```

## Suggested Follow-ups

After showing results, suggest relevant next queries:
- High bounce rate → "Want to see exit pages? (metrics type=exit)"
- Low pageviews on a page → "Want to check referrers? (metrics type=referrer)"
- Many events → "Want to explore event properties? (event-data/events)"
- Specific user of interest → "Want to see their full session? (sessions/{id}/activity)"

## Pagination

List endpoints (sessions, events, reports) support `page` + `pageSize`. When results indicate more pages are available, automatically fetch the next page and combine results. Default `pageSize` is 20.

## Error Handling

- 401 → token expired, invoke `bvdr:umami-setup` to refresh
- 404 → website ID may have been deleted, suggest running `bvdr:umami-setup` again
- Empty results → verify date range, suggest wider range
- Connection error → check if Umami instance is running

## Notes

- Never display the full API token in output — truncate to first 10 characters + `...`
