---
description: Send a rich Slack notification to a channel using Block Kit formatting. Supports text, code blocks, headers, status updates, and custom layouts.
---

# Send Slack Notification

This skill sends a rich message to a Slack channel using the Slack API with Block Kit formatting.

## Pre-flight Check

1. Run `echo $SLACK_BOT_TOKEN` in Bash
2. If empty or not starting with `xoxb-`, tell the user:
   ```
   SLACK_BOT_TOKEN is not set. Run /setup-slack-notifications first to configure your Slack bot token.
   ```
   Then stop — do not proceed.

---

## Gather Message Details

Check if the user provided a message and channel inline (e.g. `/send-slack #general Here's the update`). If they did, parse it and skip the questions.

If not, use AskUserQuestion to gather details:

```json
{
  "questions": [
    {
      "question": "Which Slack channel should the message go to?",
      "header": "Channel",
      "options": [
        {"label": "#general", "description": "The default general channel"},
        {"label": "#engineering", "description": "Engineering team channel"},
        {"label": "#random", "description": "The random channel"}
      ],
      "multiSelect": false
    },
    {
      "question": "What type of message do you want to send?",
      "header": "Format",
      "options": [
        {"label": "Text message (Recommended)", "description": "Simple rich text with markdown formatting"},
        {"label": "Status update", "description": "Header + body with context footer — great for progress updates"},
        {"label": "Code snippet", "description": "Formatted code block with optional description"},
        {"label": "Custom blocks", "description": "I'll describe the layout and you build the Block Kit JSON"}
      ],
      "multiSelect": false
    }
  ]
}
```

The user may select "Other" for the channel to type a custom channel name. Strip the `#` prefix if they include it.

Then ask the user for the actual message content in a follow-up chat message (not via AskUserQuestion — just ask them to type it).

---

## Message Templates

Based on the format choice, build the appropriate Block Kit payload.

### Text Message

```json
{
  "channel": "<channel>",
  "text": "<plain_text_fallback>",
  "blocks": [
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "<user_message>"
      }
    }
  ]
}
```

Slack mrkdwn supports: `*bold*`, `_italic_`, `~strikethrough~`, `` `inline code` ``, ` ```code block``` `, `<url|link text>`, `> blockquote`, bullet lists with `•`.

### Status Update

```json
{
  "channel": "<channel>",
  "text": "<plain_text_fallback>",
  "blocks": [
    {
      "type": "header",
      "text": {
        "type": "plain_text",
        "text": "<header_text>"
      }
    },
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "<body_text>"
      }
    },
    {
      "type": "divider"
    },
    {
      "type": "context",
      "elements": [
        {
          "type": "mrkdwn",
          "text": "Sent from Claude Code"
        }
      ]
    }
  ]
}
```

Ask the user for a header line and the body content separately.

### Code Snippet

```json
{
  "channel": "<channel>",
  "text": "<plain_text_fallback>",
  "blocks": [
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "<optional_description>"
      }
    },
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "```<code_content>```"
      }
    }
  ]
}
```

Ask the user for the code and an optional description.

### Custom Blocks

Let the user describe what they want in natural language. Build the Block Kit JSON using these available block types:
- `header` — large bold text (plain_text only)
- `section` — text with optional accessory (mrkdwn or plain_text)
- `divider` — horizontal line
- `context` — small footer text with optional images
- `image` — full-width image with alt text
- `actions` — buttons (though bots typically don't handle interactions from Claude Code)

Compose blocks based on the user's description and confirm the structure before sending.

---

## Sending the Message

Once the payload is ready, send it via curl:

```bash
curl -s -X POST https://slack.com/api/chat.postMessage \
  -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '<json_payload>'
```

**Important**: The JSON payload must be properly escaped for the shell. Use a heredoc or write to a temp file if the message contains quotes or special characters:

```bash
PAYLOAD='<json_payload>'
curl -s -X POST https://slack.com/api/chat.postMessage \
  -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" | jq .
```

For complex payloads with special characters, write to a temp file:

```bash
cat > /tmp/slack-payload.json << 'EOFPAYLOAD'
<json_payload>
EOFPAYLOAD
curl -s -X POST https://slack.com/api/chat.postMessage \
  -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
  -H "Content-Type: application/json" \
  -d @/tmp/slack-payload.json | jq .
rm -f /tmp/slack-payload.json
```

---

## Response Handling

Parse the API response:

**Success** (`"ok": true`):
```
Message sent to #<channel>!
🔗 https://<workspace>.slack.com/archives/<channel_id>/p<timestamp>
```

Build the permalink from the response fields:
- `channel` — the channel ID
- `ts` — the message timestamp (remove the dot for the URL: `1234567890.123456` → `p1234567890123456`)

**Common errors**:
- `channel_not_found` — Channel doesn't exist or bot isn't in the private channel. Suggest the user invite the bot with `/invite @BotName` in the channel.
- `not_in_channel` — Bot needs to be invited to the private channel. For public channels, `chat:write.public` scope handles this.
- `invalid_auth` / `token_revoked` — Token issue. Tell user to run `/setup-slack-notifications` again.
- `too_many_attachments` — Simplify the blocks payload.
- `msg_too_long` — Message exceeds 40,000 characters. Split it up.

---

## Notes

- **Security**: Never log, display, or commit the bot token. Only reference it via `$SLACK_BOT_TOKEN`.
- **Rate limits**: Slack allows ~1 message/second per channel. Not a concern for manual skill usage.
- **Platform**: Works on macOS and Linux (uses `curl` and `jq`)
- **Block Kit reference**: https://api.slack.com/block-kit
