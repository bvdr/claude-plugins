# Domain 09: Project Health

**Purpose:** Assess overall project hygiene — git health, TODO inventory, open issues/PR status, CI/CD health, file cleanup, configuration, license compliance, lock files, commit message quality, branch naming consistency, PR merge strategy, and environment parity.

**Domain slug:** `project-health`
**ID prefix:** `project-health-NNN`

---

## Applicability

Always applicable.

---

## Check 1: Git Health

**Multi-pass approach:**
1. DISCOVER: Run git status, branch analysis, and history checks
2. READ: For stale branches, read their last commit to assess if they contain important unmerged work
3. ANALYZE: Assess overall git hygiene

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

**Multi-pass approach:**
1. DISCOVER: Find all TODO markers in the codebase
2. READ: For markers >180 days old, read the surrounding code to assess urgency
3. ANALYZE: Build age distribution and identify critical stale TODOs

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

**Multi-pass approach:**
1. DISCOVER: Search for files that shouldn't be in the repo
2. READ: For suspicious files, check if they contain sensitive data
3. ANALYZE: Assess if the files are tracked by git or just untracked clutter

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

## Check 9: Commit Message Quality

**Multi-pass approach:**
1. DISCOVER: Sample the last 50 commits
2. READ: Analyze commit message format and content
3. ANALYZE: Detect the dominant convention and flag deviations

### Sample commits
```bash
git log --oneline -50 2>/dev/null
```

### Analyze patterns
1. **Format detection**: Do commits follow a convention?
   - Conventional Commits: `feat:`, `fix:`, `chore:`, `docs:`, etc.
   - Ticket-prefixed: `JIRA-123: description`
   - Free-form: no consistent pattern

2. **Quality checks:**
   - Single-word commits (e.g., `fix`, `update`, `wip`): count them
   - Very long first lines (>72 chars): count them
   - Empty commit messages: count them
   - All-lowercase or all-uppercase: note dominant style

3. **Report:**
   - Dominant convention (if any)
   - Percentage following convention
   - Count of low-quality commits (single-word, empty, unclear)

### Severity
- >30% of commits are single-word or empty: **low**
- No consistent commit convention: **low** (informational)
- Consistent convention well-followed: no finding

---

## Check 10: Branch Naming Consistency

**Multi-pass approach:**
1. DISCOVER: List all branches (local and remote)
2. ANALYZE: Detect the dominant naming pattern and flag deviations

### List branches
```bash
git branch -a --format='%(refname:short)' 2>/dev/null
```

### Detect patterns
Common conventions:
- `feature/description` / `bugfix/description` / `hotfix/description`
- `TICKET-123-description`
- `username/description`
- `type/TICKET-description`

1. Group branches by prefix pattern
2. Identify dominant convention
3. Flag branches that deviate significantly

### Severity
- No consistent branch naming: **low** (informational)
- Branches with no descriptive name (e.g., `test`, `temp`, `asdf`): **low**
- Consistent naming convention: no finding

---

## Check 11: PR Merge Strategy Analysis

**Multi-pass approach:**
1. DISCOVER: Examine recent merge commits to detect the strategy
2. ANALYZE: Check for consistency in merge approach

### Detect merge strategy
```bash
git log --merges --oneline -20 2>/dev/null
```

```bash
git log --oneline -50 2>/dev/null | grep -c "Merge pull request\|Merge branch"
```

### Check for squash merges
```bash
git log --oneline -50 2>/dev/null
```
If most non-merge commits have PR references in the message (e.g., `(#123)`), squash merges are likely used.

### Analysis
1. **Consistency**: Is the same strategy used throughout?
   - All regular merges: consistent
   - All squash merges: consistent
   - Mixed: inconsistent
2. **Impact**: Mixed strategies make git history harder to follow

### Severity
- Mixed merge strategies: **low** (informational)
- Consistent strategy: no finding

---

## Check 12: Environment Parity Check

**Multi-pass approach:**
1. DISCOVER: Find all environment config templates and actual configs
2. READ: Compare .env.example structure against .env structure
3. ANALYZE: Check if all required variables are documented

### Find environment files
```bash
find PROJECT_ROOT -maxdepth 3 -name '.env*' -not -path '*/node_modules/*' -not -path '*/vendor/*' -not -path '*/.git/*' 2>/dev/null
```

### Compare .env.example with required variables

**Extract variables from .env.example:**
Read `.env.example` (or `.env.sample`) and extract variable names.

**Extract variables used in code:**
```
(?:getenv|process\.env\.|os\.environ\.get|env\()\s*\(?\s*['"](\w+)['"]
```

**Compare:**
1. Variables in code but NOT in .env.example: **medium** — developers won't know they're needed
2. Variables in .env.example but NOT used in code: **low** — might be stale
3. Variables with no default/description in .env.example: **low**

### Multiple environment check
If multiple .env files exist (`.env.local`, `.env.staging`, `.env.production`):
- Compare structure across environments
- Flag variables present in one but missing in another
- Flag variables with different naming conventions

### Severity
- Required variable missing from .env.example: **medium**, `important: true`
- Stale variable in .env.example: **low**
- Environment config structure mismatch: **medium**
- All variables documented and consistent: no finding

---

## Output Reminder

Return findings as JSON array. Use `"domain": "project-health"` and IDs like `project-health-001`. Categories: `git-health`, `todo-inventory`, `open-issues`, `ci-cd`, `file-hygiene`, `config-health`, `license-compliance`, `lock-files`, `commit-quality`, `branch-naming`, `merge-strategy`, `environment-parity`.
