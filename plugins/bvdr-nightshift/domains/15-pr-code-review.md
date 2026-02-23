# Domain 15: PR Code Review

**Purpose:** Review open non-dependabot pull requests with line-level feedback. This domain is independent from Level 1 findings — it operates directly on GitHub PR data using the `gh` CLI. It produces both JSON findings for the dashboard AND separate detailed review markdown files per PR.

**Domain slug:** `pr-code-review`
**ID prefix:** `pr-code-review-NNN`
**Level:** 2 (independent — does NOT use Level 1 findings)

---

## Applicability

This domain has strict pre-flight requirements. Skip the entire domain if ANY of these fail:

1. **GitHub CLI available:** Run `gh auth status 2>&1` — if it fails, skip with reason "GitHub CLI not authenticated"
2. **Open PRs exist:** Run `gh pr list --state=open --json number,title,author 2>/dev/null` — if empty array or error, skip with reason "No open PRs found"
3. **Non-bot PRs exist:** Filter out PRs where `author.login` matches `dependabot`, `renovate`, `renovate-bot`, `github-actions`, `snyk-bot`, or any author login containing `bot` or `[bot]`. If no PRs remain after filtering, skip with reason "Only bot PRs open"

If all checks pass, proceed with the filtered list of non-bot PRs.

---

## Pre-Flight Setup

Before reviewing PRs, create the output directory for review files:

```bash
mkdir -p ${REPORT_DIR}/pr-reviews
```

If `REPORT_DIR` is not set, use `${PROJECT_ROOT}/reports/night-shift/pr-reviews` as the default.

---

## Check 1: Pre-Flight Verification

**Multi-pass approach:**
1. DISCOVER: Run `gh auth status` to verify GitHub CLI is authenticated
2. DISCOVER: Run `gh pr list --state=open --json number,title,author,createdAt,baseRefName,headRefName,isDraft,labels` to get all open PRs
3. ANALYZE: Filter out bot PRs (dependabot, renovate, github-actions, snyk-bot, any login containing "bot")
4. ANALYZE: Sort remaining PRs by creation date (oldest first — they need review most)

### Commands to run

```bash
gh auth status 2>&1
```

```bash
gh pr list --state=open --json number,title,author,createdAt,baseRefName,headRefName,isDraft,labels --limit 20
```

### Bot filter patterns
Filter out PRs where `author.login` matches any of:
- `dependabot`
- `dependabot[bot]`
- `renovate`
- `renovate-bot`
- `renovate[bot]`
- `github-actions`
- `github-actions[bot]`
- `snyk-bot`
- `snyk[bot]`
- Any author login containing the substring `bot` (case-insensitive)

### Output
Produce a single summary finding:
- `title`: "PR review pre-flight: {N} PRs to review"
- `description`: List of PR numbers, titles, and authors
- `category`: `pr-hygiene`

### Severity: **low** (informational)

---

## Check 2: Review Each PR

**Multi-pass approach:**
For EACH non-bot PR (up to 10 PRs maximum):

1. DISCOVER: Get the PR details and diff
2. READ: Read the full diff carefully, understanding every change
3. ANALYZE: Check for bugs, security issues, performance problems, maintainability concerns, testing gaps, and WordPress/framework standards violations
4. RESEARCH: WebSearch for any unfamiliar patterns, libraries, or APIs used in the diff
5. REPORT: Write a detailed review file AND produce a JSON summary finding

### Commands per PR

**Get PR details:**
```bash
gh pr view {number} --json number,title,body,author,createdAt,baseRefName,headRefName,additions,deletions,changedFiles,files,reviews,comments
```

**Get PR diff:**
```bash
gh pr diff {number}
```

### What to review in each PR

**Bugs and logic errors:**
- Off-by-one errors
- Null/undefined reference risks
- Type mismatches
- Race conditions
- Incorrect boolean logic
- Missing error handling for new code paths
- Unhandled edge cases

**Security issues:**
- SQL injection in new queries
- XSS in new output
- Missing input validation on new endpoints
- Missing authentication/authorization checks
- Hardcoded secrets or credentials
- Insecure deserialization
- Path traversal risks

**Performance problems:**
- N+1 queries introduced
- Unbounded queries (missing LIMIT)
- Unnecessary database calls in loops
- Large payload processing without pagination
- Missing indexes for new queries
- Blocking I/O in async contexts

**Maintainability concerns:**
- Functions that are too long (>50 lines of new code in one function)
- Deep nesting (3+ levels)
- Magic numbers or hardcoded strings that should be constants
- Copy-pasted code that should be a shared function
- Missing or misleading comments
- Unclear variable/function names

**Testing gaps:**
- New functionality without corresponding tests
- Modified logic without updated tests
- Edge cases not covered by existing or new tests
- Test assertions that don't verify the actual behavior

**WordPress/Framework standards (if applicable):**
- WordPress Coding Standards violations (spacing, naming, Yoda conditions)
- Missing `esc_html()`, `esc_attr()`, `esc_url()` for output
- Missing `$wpdb->prepare()` for database queries
- Missing nonce verification for form handlers
- Missing capability checks for admin operations
- Direct use of `$_GET`, `$_POST` without sanitization

### Diff analysis strategy
1. Parse the diff to identify changed files and their line ranges
2. For each changed file:
   - Read the FULL file (not just the diff) to understand context
   - Focus review on the changed lines but consider how they interact with surrounding code
   - Note the file path, line numbers, and nature of the change
3. Group findings by file within the PR

---

## Check 3: Write Review File Per PR

For EACH reviewed PR, write a detailed review markdown file using the Write tool.

### File path
```
${REPORT_DIR}/pr-reviews/PR-{number}-review.md
```

### Review file format

```markdown
# PR #{number}: {title}

**Branch:** `{headRefName}` -> `{baseRefName}`
**Author:** {author.login}
**Reviewed:** {current_date} by Night Shift

---

## Summary

{2-4 sentence summary of what the PR does and its overall quality. Be constructive and specific.}

---

## Findings

{For each finding, ordered by severity (critical first):}

### `{file_path}:{line_range}`

**Severity:** {critical|high|medium|low}

```{language}
{Code snippet from the diff showing the issue — 5-15 lines of context}
```

**Issue:** {Specific description of the problem. Be precise — reference the exact variable, function, or logic that is wrong.}

**Suggestion:** {Specific fix. If possible, show the corrected code.}

---

{Repeat for each finding in this PR}

## Overall Assessment

{1 paragraph overall assessment. Mention:
- Whether the PR is ready to merge, needs minor fixes, or needs significant rework
- The most critical issue if any
- Positive aspects of the PR (good patterns, thorough tests, etc.)
- Specific action items for the PR author}
```

### Writing the review file
Use the Write tool to create the review file:
```
Write tool: file_path="${REPORT_DIR}/pr-reviews/PR-{number}-review.md", content="{review content}"
```

---

## Check 4: Create JSON Summary Finding Per PR

For EACH reviewed PR, also produce a JSON finding for the main dashboard report.

### Finding format
```json
{
  "id": "pr-code-review-NNN",
  "domain": "pr-code-review",
  "title": "PR #{number}: {title} — {issue_count} issues found",
  "severity": "{highest severity among PR findings}",
  "urgent": false,
  "important": true if any critical/high findings else false,
  "description": "Reviewed PR #{number} ({additions}+ {deletions}-). Found {issue_count} issues: {critical_count} critical, {high_count} high, {medium_count} medium, {low_count} low. Top issue: {most severe finding title}.",
  "file": null,
  "line": null,
  "evidence": "Review details: ${REPORT_DIR}/pr-reviews/PR-{number}-review.md\n\nTop findings:\n- {finding_1_summary}\n- {finding_2_summary}\n- {finding_3_summary}",
  "recommendation": "{Overall recommendation: merge/fix-then-merge/needs-rework}. {Most important action item}.",
  "effort": "small",
  "category": "pr-review"
}
```

### Severity mapping for PR summary
The PR summary finding's severity should be the HIGHEST severity among all issues found in that PR:
- PR has a critical finding: summary severity = **critical**
- PR has high findings but no critical: summary severity = **high**
- PR has medium findings only: summary severity = **medium**
- PR has low findings only or no findings: summary severity = **low**
- PR with no issues: still produce a finding with severity **low** and title "PR #{number}: {title} — Clean review"

---

## Check 5: PR Hygiene Summary

After reviewing all PRs, produce a hygiene summary finding.

**Multi-pass approach:**
1. REVIEW: Analyze the collection of all PR reviews
2. ANALYZE: Look for patterns across PRs (recurring issues, common gaps)

### Hygiene metrics to track
- **Stale PRs**: PRs older than 14 days without recent activity
- **Draft PRs**: PRs marked as draft (note for awareness, do not count as issues)
- **Large PRs**: PRs with >500 lines changed (harder to review)
- **Missing descriptions**: PRs with empty or minimal body text
- **Missing tests**: PRs that change source code but include no test changes
- **Common issues**: If the same type of issue appears in 3+ PRs, it's a systemic pattern

### Summary finding
```json
{
  "id": "pr-code-review-NNN",
  "domain": "pr-code-review",
  "title": "PR hygiene: {N} open PRs, {stale_count} stale, {issue_count} total issues",
  "severity": "medium if stale_count > 0 else low",
  "urgent": false,
  "important": true if stale_count > 2 or any critical PR findings,
  "description": "Reviewed {N} non-bot PRs. {stale_count} stale (>14 days), {large_count} large (>500 lines), {no_tests_count} missing test changes. Most common issues: {top_3_issue_types}.",
  "evidence": "PRs reviewed: {comma-separated PR numbers}\nReview files: ${REPORT_DIR}/pr-reviews/\n\nPR age distribution: {oldest} to {newest}",
  "recommendation": "{Actionable advice based on patterns}",
  "effort": "small",
  "category": "pr-hygiene"
}
```

### Severity
- Stale PRs (>14 days): **medium**
- Very stale PRs (>30 days): **medium**, `important: true`
- Large PR without description: **low**
- Systemic issue pattern across 3+ PRs: **medium**
- All PRs clean with good hygiene: **low** (positive acknowledgment)

---

## Output Reminder

Return findings as JSON array. Use `"domain": "pr-code-review"` and IDs like `pr-code-review-001`. Categories: `pr-review`, `pr-hygiene`.

**Dual output reminder:** This domain produces BOTH:
1. **JSON findings** (returned as the standard finding array) — for the main dashboard report
2. **Markdown review files** (written to `${REPORT_DIR}/pr-reviews/PR-{number}-review.md`) — for detailed line-level feedback

Both outputs are required. The JSON findings provide a dashboard overview; the review files provide the detailed, actionable feedback that PR authors need.

**Tool usage reminder:**
- Use the **Bash tool** for all `gh` commands (`gh auth status`, `gh pr list`, `gh pr view`, `gh pr diff`)
- Use the **Write tool** for creating review markdown files
- Use the **Read tool** to read full source files referenced in diffs (for context beyond the diff)
- Use **WebSearch** to verify unfamiliar patterns or libraries in PR code
