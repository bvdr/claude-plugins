---
description: Interactive setup wizard for Slack bot notifications. Guides you through creating a Slack app, obtaining a Bot OAuth token, and configuring your environment.
---

# Setup Slack Notifications

This skill walks you through configuring a Slack bot token so you can send rich notifications from Claude Code.

## Pre-flight Check

Before starting the wizard, check if the token is already configured:

1. Run `echo $SLACK_BOT_TOKEN` in Bash to check if it's set
2. If it starts with `xoxb-`, the token is already configured. Verify it works:

```bash
curl -s -X POST https://slack.com/api/auth.test \
  -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
  -H "Content-Type: application/json" | jq .
```

3. If `"ok": true`, tell the user their token is valid and show the workspace/bot name. Done.
4. If not set or invalid, proceed with the setup wizard below.

---

## Setup Wizard

Use the AskUserQuestion tool with this single question to determine the user's starting point:

```json
{
  "questions": [
    {
      "question": "Where are you in the Slack bot setup process?",
      "header": "Setup stage",
      "options": [
        {"label": "Start from scratch", "description": "I need to create a Slack app and get a bot token"},
        {"label": "I have a token already", "description": "I already have a xoxb-... bot token ready to configure"},
        {"label": "Check my setup", "description": "I think it's configured, just verify it works"}
      ],
      "multiSelect": false
    }
  ]
}
```

---

## Path: Start from scratch

Walk the user through these steps. Present them as numbered instructions (not automated — the user does these in their browser):

### Step 1 — Create a Slack App

Tell the user:

```
1. Go to https://api.slack.com/apps
2. Click "Create New App" → "From scratch"
3. Name it whatever you like (e.g. "Claude Notifier")
4. Select your workspace
5. Click "Create App"
```

### Step 2 — Add Bot Token Scopes

Tell the user:

```
6. In the left sidebar, click "OAuth & Permissions"
7. Scroll down to "Scopes" → "Bot Token Scopes"
8. Click "Add an OAuth Scope" and add these two scopes:
   - chat:write        (send messages to channels the bot is in)
   - chat:write.public (send messages to any public channel)
```

### Step 3 — Install to Workspace

Tell the user:

```
9.  Scroll back up and click "Install to Workspace"
10. Click "Allow" to authorize the bot
11. Copy the "Bot User OAuth Token" — it starts with xoxb-
```

### Step 4 — Configure the token

After the user confirms they have the token, ask for it using AskUserQuestion:

```json
{
  "questions": [
    {
      "question": "Paste your Bot User OAuth Token (starts with xoxb-):",
      "header": "Token",
      "options": [
        {"label": "I've copied it", "description": "I have the xoxb-... token in my clipboard, let me paste it next"}
      ],
      "multiSelect": false
    }
  ]
}
```

The user will likely select "Other" and paste their token. If they select "I've copied it", ask them to type/paste the token directly in the chat.

**CRITICAL**: Never store or commit the token. It goes only in their shell profile.

### Step 5 — Add to shell profile

Detect the user's shell and add the export:

1. Check which shell profile exists (in order): `~/.zshrc`, `~/.bashrc`, `~/.bash_profile`
2. Read the file to check if `SLACK_BOT_TOKEN` is already exported
3. If not present, append this line to the shell profile:

```bash
export SLACK_BOT_TOKEN="xoxb-the-token-they-provided"
```

4. Tell the user to either restart their terminal or run `source ~/.zshrc` (or whichever file was updated)

### Step 6 — Verify

After the user sources their profile or confirms the token is set, run:

```bash
curl -s -X POST https://slack.com/api/auth.test \
  -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
  -H "Content-Type: application/json" | jq .
```

If `"ok": true`, setup is complete. Show the workspace and bot user name from the response.

---

## Path: I have a token already

1. Ask the user to paste their token (same AskUserQuestion as Step 4 above)
2. Validate it starts with `xoxb-`
3. Add to shell profile (Step 5)
4. Verify (Step 6)

---

## Path: Check my setup

1. Run the `echo $SLACK_BOT_TOKEN` check
2. If set, run the auth.test verification
3. Report results

---

## Completion Message

After successful setup:

```
Slack notifications configured!

🤖 Bot: <bot_name>
🏢 Workspace: <workspace_name>
🔑 Token: xoxb-...xxxx (last 4 chars)

Your SLACK_BOT_TOKEN is set in: <shell_profile_path>

To send a notification, run: /send-slack-notification
To reconfigure later, run: /setup-slack-notifications
```

## Error Handling

- **Invalid token format**: Must start with `xoxb-`. If the user pastes something else, tell them it looks wrong and point them back to the OAuth & Permissions page.
- **auth.test fails with `invalid_auth`**: Token is expired or revoked. Guide them to regenerate it from https://api.slack.com/apps.
- **auth.test fails with `not_authed`**: Token wasn't passed correctly. Double-check the environment variable is set.
- **No jq installed**: Tell the user to install it (`brew install jq`) and retry.

## Notes

- **Security**: The token is stored only in the user's shell profile as an environment variable — never in any config file, repo, or committed code
- **Platform**: Works on macOS and Linux
- **Dependencies**: `curl` and `jq`
