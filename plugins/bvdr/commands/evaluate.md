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

Write the content to `/tmp/gemini-eval-content.txt` using python3 (NOT a bash heredoc — heredocs break if the content contains the delimiter string):

```bash
python3 -c "
import sys
content = sys.stdin.read()
with open('/tmp/gemini-eval-content.txt', 'w') as f:
    f.write(content)
" << 'EVAL_INPUT_PY'
<paste the user request + assistant response here>
EVAL_INPUT_PY
```

If the content itself contains `EVAL_INPUT_PY`, use python3 to write the file directly instead:

```bash
python3 -c "
with open('/tmp/gemini-eval-content.txt', 'w') as f:
    f.write('''<content here, triple-quote escaped>''')
"
```

## Build the Evaluation Prompt

Write the system prompt + content to `/tmp/gemini-eval-prompt.txt`:

```bash
cat > /tmp/gemini-eval-prompt.txt << 'GEMINI_EVAL_PROMPT_EOF'
You are an expert technical reviewer providing a second opinion on AI-generated output.

Evaluate the following content critically and constructively. Cover:

1. **Correctness** — Are there factual errors, wrong assumptions, or flawed logic?
2. **Completeness** — What's missing? Any blind spots or edge cases not addressed?
3. **Quality** — Is it well-structured, clear, and actionable?
4. **Risks** — Any potential issues, security concerns, or pitfalls?
5. **Suggestions** — Concrete improvements, alternatives, or things to reconsider.

Be direct. If it's good, say so briefly and focus on what could be better. If it's bad, explain why.

---

CONTENT TO EVALUATE:

<content from /tmp/gemini-eval-content.txt will be appended here by the script>
GEMINI_EVAL_PROMPT_EOF
```

## Call Gemini API

Run this python3 script to make the API call. It handles JSON escaping properly:

```bash
python3 << 'PYEOF'
import json, urllib.request, urllib.error, os, sys

api_key = os.environ.get("GEMINI_API_KEY", "")
model = os.environ.get("GEMINI_MODEL", "gemini-3.1-pro-preview")

if not api_key:
    print("Error: GEMINI_API_KEY not set", file=sys.stderr)
    sys.exit(1)

# Read the prompt and content
with open("/tmp/gemini-eval-prompt.txt") as f:
    prompt = f.read()
with open("/tmp/gemini-eval-content.txt") as f:
    content = f.read()

full_prompt = prompt + "\n" + content

payload = json.dumps({
    "contents": [{"parts": [{"text": full_prompt}]}],
    "generationConfig": {
        "temperature": 0.7,
        "maxOutputTokens": 8192
    }
})

url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
req = urllib.request.Request(
    url,
    data=payload.encode("utf-8"),
    headers={"Content-Type": "application/json"},
    method="POST"
)

try:
    with urllib.request.urlopen(req, timeout=120) as resp:
        result = json.loads(resp.read().decode("utf-8"))
    text = result["candidates"][0]["content"]["parts"][0]["text"]
    print(text)
except urllib.error.HTTPError as e:
    body = e.read().decode("utf-8")
    try:
        err = json.loads(body)
        msg = err.get("error", {}).get("message", body)
    except json.JSONDecodeError:
        msg = body
    print(f"Gemini API error ({e.code}): {msg}", file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
```

## Cleanup

```bash
rm -f /tmp/gemini-eval-content.txt /tmp/gemini-eval-prompt.txt
```

## Present Results

**Always show the full Gemini response to the user.** Present it under a clear header:

```
## Gemini Evaluation (model: <model_used>)

<gemini's full response — do NOT summarize or truncate>
```

Then add your own take below:

```
## Claude's Response to Evaluation

<For each point Gemini raised, state whether you agree or push back, and why. Be specific.>
```

Do NOT just relay the response passively — engage with it critically.
