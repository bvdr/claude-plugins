---
description: Get a second opinion from Google's Gemini on your last output. Use when user says "evaluate", "assess", "second opinion", "gemini review", or "review this".
---

# Gemini Evaluate

Get an independent evaluation of Claude's last output from Google's Gemini.

## Pre-flight

1. Run `echo $GEMINI_API_KEY` in Bash
2. If empty, tell the user:
   > `GEMINI_API_KEY` is not set. Get one at https://aistudio.google.com/apikey and add to your shell config (`~/.zshrc`, `~/.bashrc`, etc.):
   > ```
   > export GEMINI_API_KEY="your-key-here"
   > ```
   Then stop.
3. Optionally check `echo $GEMINI_MODEL` — defaults to `gemini-3.1-pro-preview` if unset. User can override with any model name.

## What to Evaluate

Determine the content to evaluate:

- **If the user provided specific context** (e.g. `/evaluate this plan` or `/evaluate the migration approach`) — use that specific content from the conversation
- **Otherwise** — use YOUR (Claude's) last full assistant message before this skill was invoked

**IMPORTANT:** Always include BOTH the user's original request AND your response. Gemini cannot evaluate an answer without knowing the question. Format it as:

```
USER REQUEST:
<the user's message that prompted your response>

ASSISTANT RESPONSE:
<your response being evaluated>
```

Write the content to `/tmp/gemini-eval-content.json` as a JSON file using Node. This avoids all escaping issues:

```bash
node -e "
const fs = require('fs');
const content = fs.readFileSync('/dev/stdin', 'utf8');
fs.writeFileSync('/tmp/gemini-eval-content.json', JSON.stringify(content));
" << 'EVAL_INPUT_END'
<paste the user request + assistant response here>
EVAL_INPUT_END
```

If the content contains `EVAL_INPUT_END`, use Node to write it directly:

```bash
node -e "
const fs = require('fs');
fs.writeFileSync('/tmp/gemini-eval-content.json', JSON.stringify(\`<content here, backtick escaped>\`));
"
```

## Call Gemini API

Run this Node script. It builds the prompt, calls the API, and writes the raw response to `/tmp/gemini-eval-response.md`:

```bash
node -e "
const https = require('https');
const fs = require('fs');

const apiKey = process.env.GEMINI_API_KEY || '';
const model = process.env.GEMINI_MODEL || 'gemini-3.1-pro-preview';

if (!apiKey) { console.error('Error: GEMINI_API_KEY not set'); process.exit(1); }

const content = JSON.parse(fs.readFileSync('/tmp/gemini-eval-content.json', 'utf8'));

const systemPrompt = \`You are an expert technical reviewer providing a second opinion on AI-generated output.

Evaluate the following content critically and constructively. Cover:

1. **Correctness** — Are there factual errors, wrong assumptions, or flawed logic?
2. **Completeness** — What's missing? Any blind spots or edge cases not addressed?
3. **Quality** — Is it well-structured, clear, and actionable?
4. **Risks** — Any potential issues, security concerns, or pitfalls?
5. **Suggestions** — Concrete improvements, alternatives, or things to reconsider.

Be direct. If it's good, say so briefly and focus on what could be better. If it's bad, explain why.

---

CONTENT TO EVALUATE:

\` + content;

const payload = JSON.stringify({
  contents: [{ parts: [{ text: systemPrompt }] }],
  generationConfig: { temperature: 0.7, maxOutputTokens: 8192 }
});

const url = new URL(\`https://generativelanguage.googleapis.com/v1beta/models/\${model}:generateContent?key=\${apiKey}\`);

const req = https.request({
  hostname: url.hostname,
  path: url.pathname + url.search,
  method: 'POST',
  headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(payload) }
}, (res) => {
  let body = '';
  res.on('data', (chunk) => body += chunk);
  res.on('end', () => {
    try {
      const result = JSON.parse(body);
      if (result.error) {
        console.error('Gemini API error: ' + result.error.message);
        process.exit(1);
      }
      const text = result.candidates[0].content.parts[0].text;
      fs.writeFileSync('/tmp/gemini-eval-response.md', text);
      console.log('Gemini response saved to /tmp/gemini-eval-response.md');
    } catch (e) {
      console.error('Failed to parse response: ' + body.slice(0, 500));
      process.exit(1);
    }
  });
});
req.on('error', (e) => { console.error('Request failed: ' + e.message); process.exit(1); });
req.setTimeout(120000, () => { req.destroy(); console.error('Request timed out'); process.exit(1); });
req.write(payload);
req.end();
"
```

## Read and Display the Response

After the API call succeeds, read `/tmp/gemini-eval-response.md` using the **Read** tool and output its ENTIRE contents to the user verbatim.

Then clean up:

```bash
rm -f /tmp/gemini-eval-content.json /tmp/gemini-eval-response.md
```

## Present Results

**CRITICAL:** The user MUST see Gemini's actual words. Follow this exact order:

### Step 1 — Show Gemini's raw response

Output the ENTIRE content of `/tmp/gemini-eval-response.md` verbatim under this header. Copy-paste it exactly as-is. Do NOT summarize, paraphrase, shorten, or interpret it:

```
## Gemini Evaluation (model: <model_used>)

<FULL verbatim content from /tmp/gemini-eval-response.md — every single line>
```

### Step 2 — Add your take

Only AFTER showing the full response above, add your own section:

```
## Claude's Response to Evaluation

<For each point Gemini raised, state whether you agree or push back, and why. Be specific.>
```
