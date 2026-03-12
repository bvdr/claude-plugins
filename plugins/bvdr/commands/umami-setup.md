---
description: Use when setting up Umami Analytics for a project, connecting to an Umami instance, installing the tracker script, or verifying an existing connection.
---

# Umami Setup

Configure a project to use Umami Analytics. Handles authentication, website selection, script tag installation, and connection verification.

## Flow

1. Check if `.umami.json` exists at project root
   - If exists → offer re-run options (see below)
   - If not → proceed with setup

2. Collect connection details using AskUserQuestion:
   - Umami host URL (e.g., `https://analytics.mysite.com`)
   - Username
   - Password

3. Authenticate against the Umami instance:

```bash
curl -s -X POST "{host}/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username": "{username}", "password": "{password}"}'
```

Response: `{ "token": "eyT...", "user": { "id": "...", "username": "...", "role": "...", "isAdmin": true } }`

If authentication fails, show the error and ask the user to check their credentials.

4. List available websites:

```bash
curl -s "{host}/api/websites" \
  -H "Authorization: Bearer {token}"
```

Present the list to the user and let them pick one. If they want to create a new website, confirm first then:

```bash
curl -s -X POST "{host}/api/websites" \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{"name": "{name}", "domain": "{domain}"}'
```

5. Write `.umami.json` to project root:

```json
{
  "host": "https://analytics.mysite.com",
  "websiteId": "94db1cb1-74f4-4a40-ad6c-962362670409",
  "token": "eyTxxxxx...",
  "domain": "mysite.com"
}
```

6. Add `.umami.json` to `.gitignore`:
   - If `.gitignore` doesn't exist → create it with `.umami.json`
   - If `.gitignore` exists but doesn't contain `.umami.json` → append it
   - If already listed → skip

7. Detect project framework and install the tracker script tag:

   **Next.js (app router):** Add to `app/layout.tsx` or `app/layout.js`:
   ```jsx
   import Script from 'next/script'

   // Inside the <body> tag:
   <Script
     src="{host}/umami.js"
     data-website-id="{websiteId}"
     strategy="afterInteractive"
   />
   ```

   **Next.js (pages router):** Add to `pages/_app.tsx` or `pages/_document.tsx`:
   ```jsx
   import Script from 'next/script'

   <Script
     src="{host}/umami.js"
     data-website-id="{websiteId}"
     strategy="afterInteractive"
   />
   ```

   **React (Vite/CRA):** Add to `index.html` inside `<head>`:
   ```html
   <script defer src="{host}/umami.js" data-website-id="{websiteId}"></script>
   ```

   **Plain HTML:** Add to `<head>`:
   ```html
   <script defer src="{host}/umami.js" data-website-id="{websiteId}"></script>
   ```

   **Detection heuristics:**
   - `next.config.*` or `app/layout.*` exists → Next.js
   - `vite.config.*` exists → Vite/React
   - `package.json` with `react-scripts` → CRA
   - `*.html` files → Plain HTML

8. Verify connection:

```bash
# Check website exists
curl -s "{host}/api/websites/{websiteId}" \
  -H "Authorization: Bearer {token}"

# Check active visitors
curl -s "{host}/api/websites/{websiteId}/active" \
  -H "Authorization: Bearer {token}"
```

9. Print summary:
```
Umami Analytics connected!

Host: {host}
Website: {websiteName}
Domain: {domain}
Active visitors: {count}

Config saved to: .umami.json (added to .gitignore)
Tracker script installed in: {file_path}

To reconfigure: /umami-setup
```

## Re-run Behavior

If `.umami.json` already exists, offer these options:

- **Verify connection** — test the stored token via `POST {host}/api/auth/verify` and check website exists
- **Refresh token** — re-authenticate with username/password, update token in `.umami.json`
- **Switch website** — list websites, let user pick a different one
- **Reconfigure from scratch** — delete `.umami.json` and start over

## Error Handling

- **401 from auth endpoint** → wrong credentials, ask user to retry
- **404 Not Found** → website ID may have been deleted, suggest running setup again to pick a new website
- **Connection refused** → host URL unreachable, ask user to verify
- **Empty website list** → no websites configured, offer to create one
- **Token in `.umami.json` expired** → `POST /api/auth/verify` returns 401 → prompt re-auth

## Notes

- Self-hosted Umami JWT tokens do not expire by default, but instance admins can configure expiry
- Never display the full token in output — truncate to first 10 characters + `...`
