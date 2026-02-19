# Domain 09: Project Health

**Purpose:** Assess overall project hygiene — git health, TODO inventory, open issues/PR status, CI/CD health, file cleanup, configuration, license compliance, and lock files.

**Domain slug:** `project-health`
**ID prefix:** `project-health-NNN`

---

## Applicability

Always applicable.

---

## Check 1: Git Health

**Uncommitted changes:**
```bash
git status --porcelain 2>/dev/null | head -20
```
If uncommitted changes exist: **low** (informational)

**Stale branches:**
```bash
git for-each-ref --sort=-committerdate --format='%(refname:short) %(committerdate:relative)' refs/heads/ 2>/dev/null
```
Branches with no commits in 60+ days: **medium**
Count total stale branches.

**Large files in git history:**
```bash
git rev-list --objects --all 2>/dev/null | git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' 2>/dev/null | awk '/^blob/ && $3 > 1048576 {print $3, $4}' | sort -rn | head -10
```
Files >10MB in history: **medium**
Binary files (images, videos, zips) in history: **low**

**.gitignore completeness:**
Check for common patterns that SHOULD be in .gitignore:
```bash
grep -q 'node_modules' .gitignore 2>/dev/null || echo "MISSING: node_modules"
grep -q '\.env' .gitignore 2>/dev/null || echo "MISSING: .env"
grep -q 'vendor' .gitignore 2>/dev/null || echo "MISSING: vendor"
grep -q '\.DS_Store' .gitignore 2>/dev/null || echo "MISSING: .DS_Store"
grep -q '*.log' .gitignore 2>/dev/null || echo "MISSING: *.log"
```
Only flag patterns relevant to detected stack. Missing .env in .gitignore: **high**. Others: **low**.

---

## Check 2: TODO/FIXME Inventory

Find all markers:
```
\b(?:TODO|FIXME|HACK|XXX|WORKAROUND|TEMP|TEMPORARY)\b
```
Exclude vendor/node_modules/.git.

For each, get age with `git blame`:
```bash
git blame -L {line},{line} -- {file} 2>/dev/null
```

Build age distribution:
- <7 days | 7-30 days | 30-90 days | 90-180 days | 180+ days

Report as summary finding with total count + distribution.
Flag individual TODOs older than 180 days with content.

### Severity
- Summary: **low** if <10 total, **medium** if >10
- Individual 180+ day TODOs mentioning security/auth/critical: **medium**

---

## Check 3: Open Issues & PR Status

**Only if `gh` CLI available and authenticated.**

```bash
gh issue list --state=open --limit=20 --json number,title,createdAt,labels 2>/dev/null
```
```bash
gh pr list --state=open --json number,title,createdAt,isDraft 2>/dev/null
```

Report:
- Count of open issues, oldest issue age
- Count of open PRs, stale PRs (>14 days old)
- Issues labeled `bug` or `security`: flag count

If `gh` not available: skip and note.

### Severity
- Security-labeled open issue: **medium**, `important: true`
- Very stale PR (>30 days): **medium**
- General stats: **low**

---

## Check 4: CI/CD Health

```bash
gh run list --limit=5 --json name,status,conclusion,createdAt 2>/dev/null
```

Report latest workflow runs. Failing runs: **high**. No CI at all: **medium**.

If `gh` not available, check for workflow files:
```bash
ls .github/workflows/*.yml .github/workflows/*.yaml 2>/dev/null
```
Also check for `.gitlab-ci.yml`, `Jenkinsfile`, `bitbucket-pipelines.yml`.

---

## Check 5: File Hygiene

Search for files that shouldn't be in the repo:
```bash
find PROJECT_ROOT -type f \( -name '*.log' -o -name '*.bak' -o -name '*.swp' -o -name '*.swo' -o -name '*.tmp' -o -name '.DS_Store' -o -name 'Thumbs.db' -o -name 'desktop.ini' -o -name 'npm-debug.log' -o -name 'debug.log' -o -name 'error_log' \) -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/vendor/*' 2>/dev/null
```

Database dumps in non-migration dirs:
```bash
find PROJECT_ROOT -type f \( -name '*.sql' -o -name '*.sql.gz' \) -not -path '*/migrations/*' -not -path '*/db/*' -not -path '*/.git/*' 2>/dev/null
```

Coverage reports checked in:
```bash
test -d PROJECT_ROOT/coverage && echo "FOUND: coverage/"
test -d PROJECT_ROOT/.nyc_output && echo "FOUND: .nyc_output/"
```

### Severity
- DB dumps with potential sensitive data: **medium**
- Debug logs: **low**
- .DS_Store/temp files: **low**

---

## Check 6: Configuration Health

**Missing .env.example:**
If `.env` referenced in code but no `.env.example` or `.env.sample` exists: **low**

**Inconsistent config patterns:**
Check if some settings come from env, others hardcoded:
- Grep for `getenv(`, `process.env.`, `os.environ` — these are env-based
- Grep for hardcoded URLs, ports, database names in source (not config files)
- If mixed patterns: **low**

---

## Check 7: License Compliance

Read license field from package manifests:
- `package.json`: `"license"` field
- `composer.json`: `"license"` field
- `Gemfile`: check for gem licenses

Check for restrictive licenses in dependencies:
- GPL/AGPL in an MIT/Apache project: **medium**
- No license specified in project: **low**

Note: informational only — flag potential conflicts, don't make legal judgments.

---

## Check 8: Dependency Lock Files

Verify lock files are committed:
```bash
git ls-files package-lock.json yarn.lock pnpm-lock.yaml composer.lock Pipfile.lock poetry.lock Gemfile.lock 2>/dev/null
```

- Missing lock file for detected package manager: **high**
- Lock file exists but not committed: **medium**

---

## Output Reminder

Return findings as JSON array. Use `"domain": "project-health"` and IDs like `project-health-001`. Categories: `git-health`, `todo-inventory`, `open-issues`, `ci-cd`, `file-hygiene`, `config-health`, `license-compliance`, `lock-files`.
