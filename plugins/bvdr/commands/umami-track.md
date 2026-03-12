---
description: Use when implementing Umami Analytics tracking in a codebase — adding custom events, identifying users, data attributes, revenue tracking, or analyzing what should be tracked.
---

# Umami Tracking Implementation

Implement comprehensive tracking in a user's codebase. Two modes: analyze and suggest a tracking plan, or directly implement specific tracking.

## Prerequisites

Read `.umami.json` from project root for `host`, `websiteId`, `domain`. If missing, invoke `bvdr:umami-setup` first.

## Mode A: Tracking Plan

**Triggered by:** "help me track", "what should I track", "analyze my app", "tracking plan"

### Step 1: Scan the codebase

Look for:
- **Page routes/views** — Next.js `app/` or `pages/` directory, React Router routes, plain HTML files
- **User interaction points** — forms, buttons with onClick/onSubmit, CTAs, checkout flows
- **Auth flows** — login, signup, logout, registration pages/components (candidates for `umami.identify()`)
- **Revenue/purchase events** — cart, checkout, payment, subscription components
- **Existing Umami tracking** — search for `umami.track`, `umami.identify`, `data-umami-event` already in code

### Step 2: Present tracking plan

Organize by category:

**Pageviews:**
- List auto-tracked pages (Umami tracks all pageviews by default when `data-auto-track` is not `"false"`)
- Flag any pages that need manual tracking (SPAs with client-side routing that Umami might miss)

**Identity (umami.identify):**
- Where to call `umami.identify(userId, { ... })` — typically after login/signup
- What session properties to attach (name, email, plan, role, etc.)
- Distinct ID enables cross-session and cross-device tracking

**Core Events:**
- Signup completed, login, logout
- Key feature first-use
- Onboarding steps

**Conversion Events:**
- Form submissions
- Purchase/checkout completion
- Subscription actions
- CTA clicks

**Engagement Events:**
- Feature discovery clicks
- Navigation patterns
- Search usage
- Filter/sort interactions

**Revenue Events:**
- Must include both `revenue` (number) and `currency` (ISO 4217 string)
- Example: `{ revenue: 49.99, currency: 'USD' }`

### Step 3: After approval, implement

Implement each tracking point using the appropriate method (see Mode B).

---

## Mode B: Direct Implementation

**Triggered by:** "track this button", "add event for X", "identify users here"

Choose the right method based on the use case:

### Method 1: HTML Data Attributes

Best for: simple click tracking on HTML elements.

```html
<!-- Basic event -->
<button data-umami-event="signup-click">Sign up</button>

<!-- Event with custom properties -->
<button
  data-umami-event="signup-click"
  data-umami-event-plan="pro"
  data-umami-event-source="homepage"
>Sign up</button>
```

**Warnings:**
- All property values are stored as **strings** — use JavaScript method if you need numbers, booleans, or dates
- Adding `data-umami-event` to an element **will prevent other event listeners** on that element from firing
- Event name goes in `data-umami-event`, properties in `data-umami-event-{key}`

### Method 2: JavaScript `umami.track()`

Best for: typed data, conditional tracking, non-click events, dynamic values.

```javascript
// Simple named event
umami.track('signup-click');

// Custom pageview payload (sends only specified properties, no auto-merge)
umami.track({ url: '/virtual-page', title: 'Custom Page Title' });

// Event with typed data (numbers stay as numbers)
umami.track('purchase-complete', {
  revenue: 49.99,
  currency: 'USD',
  plan: 'pro',
  items: 3
});

// Override pageview properties
umami.track(props => ({
  ...props,
  url: '/virtual-page',
  title: 'Custom Page Title'
}));

// Manual pageview (when data-auto-track="false")
umami.track();
```

### Method 3: `umami.identify()`

Best for: associating sessions with known users, attaching user properties.

```javascript
// Set distinct ID (enables cross-session tracking)
umami.identify('user-123');

// Set distinct ID with session properties
umami.identify('user-123', {
  name: 'Bob',
  email: 'bob@example.com',
  plan: 'pro',
  role: 'admin'
});

// Session properties without explicit ID
umami.identify({
  plan: 'pro',
  theme: 'dark'
});
```

**Place `umami.identify()` calls:**
- After successful login/signup
- After user data is loaded from API/session
- On app initialization if user is already authenticated

### Method 4: Server-Side `POST /api/send`

Best for: backend events (webhooks, cron jobs, API handlers). **No authentication required.**

```javascript
// Node.js example
await fetch('{host}/api/send', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'User-Agent': 'MyApp/1.0'  // Required — must be a valid User-Agent
  },
  body: JSON.stringify({
    type: 'event',
    payload: {
      website: '{websiteId}',     // Required
      hostname: '{domain}',       // Required
      url: '/api/webhook',        // Required
      name: 'subscription-renewed',
      data: {
        plan: 'pro',
        mrr: 49.99
      }
    }
  })
});
```

**Important:** `/api/send` does NOT require an Authorization header. Do not attach the API token. A valid `User-Agent` header must be present or the request will be rejected.

Optional payload fields: `referrer`, `title`, `screen`, `language`, `tag`, `id` (distinct ID).

### Method 5: Outbound Link Tracking

For tracking clicks on external links:

```html
<!-- Manual per-link -->
<a href="https://external.com"
  data-umami-event="outbound-link-click"
  data-umami-event-url="https://external.com"
>Visit site</a>
```

Or auto-detect all external links (add script at bottom of body):
```javascript
(() => {
  const name = 'outbound-link-click';
  document.querySelectorAll('a').forEach(a => {
    if (a.host !== window.location.host && !a.getAttribute('data-umami-event')) {
      a.setAttribute('data-umami-event', name);
      a.setAttribute('data-umami-event-url', a.href);
    }
  });
})();
```

---

## Advanced Configuration

### `data-before-send` Hook

Intercept and modify/cancel events before they're sent:

```html
<script defer src="{host}/script.js"
  data-website-id="{websiteId}"
  data-before-send="beforeSendHandler"
></script>
```

```javascript
function beforeSendHandler(type, payload) {
  // Filter out internal pages
  if (payload.url.startsWith('/admin')) {
    return false; // Cancel send
  }
  // Modify payload
  payload.url = payload.url.replace(/\?.*$/, ''); // Strip query params
  return payload;
}
```

### Tracker Configuration Attributes

All set on the `<script>` tag:

| Attribute | Default | Description |
|---|---|---|
| `data-website-id` | (required) | Website UUID |
| `data-host-url` | script origin | Override collection endpoint URL |
| `data-auto-track` | `"true"` | Set `"false"` for manual-only tracking |
| `data-domains` | all | Comma-delimited domain whitelist (matches `window.location.hostname` exactly — watch www vs non-www) |
| `data-tag` | none | Group events under a tag (filterable in dashboard, useful for A/B testing) |
| `data-exclude-search` | `"false"` | Strip query parameters from URLs |
| `data-exclude-hash` | `"false"` | Strip hash fragments from URLs |
| `data-do-not-track` | `"false"` | Respect browser DNT setting |
| `data-before-send` | none | JS function name to intercept sends |

### Google Tag Manager

GTM strips data attributes from script tags. Use dynamic script creation:

```javascript
(function () {
  var el = document.createElement('script');
  el.setAttribute('src', '{host}/script.js');
  el.setAttribute('data-website-id', '{websiteId}');
  document.body.appendChild(el);
})();
```

---

## Constraints Reference

| Constraint | Limit |
|---|---|
| Event name | 50 characters max |
| String values | 500 characters max |
| Number precision | 4 decimal places max |
| Object properties | 50 max per event |
| Arrays | Converted to string, 500 chars max |
| Distinct IDs | 50 characters max |

## Common Mistakes

- Sending event data without an event name — **not allowed**
- Using data attributes for numeric values — they become strings
- Forgetting `User-Agent` header on server-side `/api/send` calls
- Using `data-domains` without matching www/non-www exactly
- Not calling `umami.identify()` early enough — events before identify won't be linked
