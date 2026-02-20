# Domain 07: Documentation Drift

**Purpose:** Detect documentation out of sync with the codebase — broken paths, stale commands, misleading comments, broken links, outdated AI configuration files, changelog gaps, deployment doc issues, environment setup problems, and API doc endpoint mismatches.

**Domain slug:** `docs-drift`
**ID prefix:** `docs-drift-NNN`

---

## Applicability

Always applicable. Every project has at least some documentation.

---

## Check 1: README Accuracy

**Multi-pass approach:**
1. DISCOVER: Find all README files in the project
2. READ: Read each README in full — understand what it claims about the project
3. ANALYZE: Verify every claim: file paths, commands, features, versions, installation steps
4. RESEARCH: WebSearch for any external URLs referenced in the README to check if they're still valid

Find READMEs:
```bash
find PROJECT_ROOT -maxdepth 3 -name 'README*' -not -path '*/node_modules/*' -not -path '*/vendor/*' -not -path '*/.git/*' 2>/dev/null
```

For each README, read the full file and verify:

**a) File/directory paths** (backtick-wrapped, in links, in lists):
- Resolve relative to README's directory
- Verify existence: `test -e {resolved_path}`
- **Severity: medium** for missing paths

**b) Commands** (from code blocks):
- Extract the binary (first word)
- Verify: `command -v {binary} 2>/dev/null` or `test -f PROJECT_ROOT/{script_path}`
- Check command arguments against current project structure (e.g., does the referenced config file exist?)
- Do NOT execute commands
- **Severity: medium** for commands with missing binaries

**c) Feature claims:**
- Does the README claim features that don't exist in the code?
- Does it reference modules/plugins that have been removed?
- Does it describe a workflow that no longer matches the code?
- **Severity: medium** for stale feature claims

**d) Stale version numbers/dates:**
- Grep for `\bv?\d+\.\d+(\.\d+)?\b` — cross-reference with actual version in package.json/composer.json
- Grep for dates `\b20\d{2}[-/]\d{2}[-/]\d{2}\b` — flag >365 days old
- **Severity: low**

**e) Installation/setup instructions:**
- Verify each step can be followed with the current project state
- Check if referenced config files exist
- Check if prerequisite tools are mentioned
- **Severity: medium** for broken setup instructions

---

## Check 2: CLAUDE.md / AI Config Accuracy

**Multi-pass approach:**
1. DISCOVER: Find all AI config files
2. READ: Read each file in full
3. ANALYZE: Verify every referenced path, command, branch, and infrastructure path against the actual project

Find AI config files:
```bash
find PROJECT_ROOT -maxdepth 3 \( -name 'CLAUDE.md' -o -name '.cursorrules' -o -name 'copilot-instructions.md' \) -not -path '*/vendor/*' 2>/dev/null
```

For each file:

**a) Referenced file paths** — resolve and verify existence. **Severity: medium**

**b) Referenced commands** — verify binary exists. **Severity: medium**

**c) Referenced branch names** — verify against `git branch -a`. **Severity: medium**

**d) Referenced infrastructure paths** (sockets, configs) — verify exist. **Severity: medium**

**e) Referenced table/database names** — verify against actual database schema if accessible. **Severity: medium**

**f) Coding standards claims** — spot-check 2-3 claims against actual code. **Severity: low**

---

## Check 3: API Documentation

**Multi-pass approach:**
1. DISCOVER: Find API documentation files
2. READ: Read the API docs and the actual route definitions
3. ANALYZE: Compare documented endpoints against actual endpoints

Find API docs: `openapi.yaml`, `swagger.json`, `api-docs.md`, `API.md`

If found, cross-reference documented endpoints with actual route definitions:
- Extract endpoint paths from OpenAPI spec
- Find route definitions in code (adapt to framework)
- Endpoints in docs but NOT in code: **medium** (stale)
- Endpoints in code but NOT in docs: **high** (undocumented API surface)

---

## Check 4: Code Comment Accuracy

**Multi-pass approach:**
1. DISCOVER: Find functions with docblocks
2. READ: Read 20-30 functions with their docblocks in full
3. ANALYZE: Check for specific types of mismatches between comments and code

Sample 20-30 functions with docblocks. For each:
- Read docblock + function body
- Check for mismatches:
  - **Return mismatch:** `@return` doesn't match actual returns
  - **Parameter mismatch:** `@param` lists wrong/missing params
  - **Behavioral mismatch:** comment describes actions function doesn't perform
  - **Name mismatch:** comment references different function name (copy-paste)

### Severity: **medium** for behavioral mismatches, **low** for param/return mismatches

---

## Check 5: Documentation Freshness

**Multi-pass approach:**
1. DISCOVER: Find all documentation files
2. ANALYZE: Check last modification date via git log
3. READ: For very stale docs, read them to assess if they're still relevant

Find all .md files (exclude vendor/node_modules):
```bash
git log -1 --format='%ai' -- "{filepath}" 2>/dev/null
```

- 180-365 days old: **low**
- 365+ days old: **medium**

Exclude: LICENSE.md, CODE_OF_CONDUCT.md, files in archive/ directories.

---

## Check 6: Broken Internal Links

**Multi-pass approach:**
1. DISCOVER: Extract all internal links from markdown files
2. ANALYZE: Resolve and verify each link target
3. READ: For broken links, read the context to suggest what the link should point to

In all markdown files, extract internal links:
- Relative file links: `\[([^\]]+)\]\((?!https?://|mailto:|#|tel:)([^)\s]+)\)`
- Anchor-only links: `\[([^\]]+)\]\(#([^)]+)\)`

For file links: resolve path, check existence.
For anchor links: verify heading exists in target file.

- Broken file link: **medium**
- Broken anchor link: **low**

Process up to 50 markdown files. Prioritize `docs/`, README files, CLAUDE.md.

---

## Check 7: Changelog Accuracy

**Multi-pass approach:**
1. DISCOVER: Find changelog files (CHANGELOG.md, CHANGES.md, HISTORY.md, or changelog section in README)
2. READ: Read the latest changelog entries
3. ANALYZE: Compare against actual git tags and recent commits
4. RESEARCH: If the project uses conventional commits, verify the changelog reflects them

### Find changelog
```bash
find PROJECT_ROOT -maxdepth 2 -iname 'CHANGELOG*' -o -iname 'CHANGES*' -o -iname 'HISTORY*' 2>/dev/null | head -5
```

### Verify latest entry
1. Extract the latest version/date from the changelog
2. Compare against the latest git tag:
```bash
git describe --tags --abbrev=0 2>/dev/null
git log --tags --simplify-by-decoration --format='%ci %d' -1 2>/dev/null
```
3. Check if there are commits since the last changelog entry:
```bash
git log --oneline {last_tag}..HEAD 2>/dev/null | wc -l
```

### Issues to flag
- Changelog last entry doesn't match latest tag: **low**
- Significant commits (>10) since last changelog update: **medium**
- Changelog references features that don't exist: **medium**
- No changelog at all for a published package: **medium**

### Severity
- Many unreleased commits without changelog entry: **medium**
- Changelog version mismatch with package.json: **low**
- No changelog for published project: **medium**

---

## Check 8: Deployment Doc Verification

**Multi-pass approach:**
1. DISCOVER: Find deployment documentation (deploy.md, DEPLOYMENT.md, CI/CD config, Dockerfile)
2. READ: Read the deployment docs in full
3. ANALYZE: Verify every referenced script, environment variable, and path exists

### Find deployment docs
```bash
find PROJECT_ROOT -maxdepth 3 \( -iname 'deploy*' -o -iname 'DEPLOYMENT*' -o -iname 'HOSTING*' -o -iname 'INFRASTRUCTURE*' \) -not -path '*/node_modules/*' -not -path '*/vendor/*' 2>/dev/null
```

Also check: Dockerfile, docker-compose.yml, `.github/workflows/deploy*.yml`, `buddy.yml`, `Procfile`

### Verify
1. **Referenced scripts**: Do the deploy scripts mentioned in docs exist?
```bash
test -f {script_path}
```

2. **Environment variables**: Are all required env vars documented?
- Extract env var names from deployment docs
- Cross-reference with actual `.env.example` or CI config
- Missing documented env vars: **medium**

3. **Infrastructure references**: Server names, URLs, paths referenced in docs
- Check if referenced config files exist
- Check if referenced tools are installed

4. **Docker/CI config accuracy**:
- If Dockerfile references base images, check if they're current
- If CI config references scripts, verify they exist

### Severity
- Deploy doc references non-existent script: **medium**, `important: true`
- Required env vars not documented: **medium**
- Deployment steps reference removed functionality: **medium**
- Docker base image significantly outdated: **low**

---

## Check 9: Environment Setup Doc Testing

**Multi-pass approach:**
1. DISCOVER: Find setup/installation documentation
2. READ: Read the setup instructions step by step
3. ANALYZE: Verify each prerequisite and step against the actual project

### Find setup docs
Check README "Getting Started" / "Setup" / "Installation" sections.
Check for dedicated setup docs: `SETUP.md`, `CONTRIBUTING.md`, `docs/setup.md`

### Verify prerequisites
For each mentioned prerequisite (Node version, PHP version, database, etc.):
1. Check if a version constraint file exists (`.nvmrc`, `.node-version`, `.php-version`)
2. Verify the constraint matches the documentation
3. Check if required system tools are mentioned (`git`, `composer`, `npm`, database server)

### Verify setup steps
1. Does the documented config file template exist? (`.env.example`, `config.sample.php`)
2. Do the documented scripts exist? (`npm install`, `composer install`, custom scripts)
3. Are database setup instructions present? (migration commands, seed data)
4. Are the documented ports/URLs correct?

### Issues to flag
- `.nvmrc` says Node 18, docs say Node 16: **medium**
- Setup docs reference `yarn` but project uses `npm`: **medium**
- Setup docs skip essential step (e.g., no mention of database setup): **medium**
- `.env.example` missing variables that code requires: **medium**, `important: true`

### Severity
- Version mismatch between constraint file and docs: **medium**
- Missing essential setup step: **medium**, `important: true`
- Documented tool doesn't match actual project: **medium**
- Setup docs comprehensive and accurate: no finding

---

## Check 10: API Doc Endpoint Verification

**Multi-pass approach:**
1. DISCOVER: Scan all route/endpoint definitions in the codebase
2. READ: Read API documentation files
3. ANALYZE: Compare documented endpoints against actual route definitions — find mismatches in both directions

### Scan route definitions

**WordPress REST API:**
```
register_rest_route\s*\(\s*['"]([^'"]+)['"]\s*,\s*['"]([^'"]+)['"]
```

**WordPress AJAX:**
```
add_action\s*\(\s*['"]wp_ajax_(?:nopriv_)?(\w+)['"]
```

**Express/Node.js:**
```
(?:app|router)\.(?:get|post|put|patch|delete)\s*\(\s*['"]([^'"]+)['"]
```

**PHP Slim Framework:**
```
\$app->(?:get|post|put|patch|delete)\s*\(\s*['"]([^'"]+)['"]
```

**Laravel:**
```
Route::(?:get|post|put|patch|delete|resource)\s*\(\s*['"]([^'"]+)['"]
```

**Django:**
```
path\s*\(\s*['"]([^'"]+)['"]
```

### Compare against docs
1. Build list of actual endpoints from code
2. Build list of documented endpoints from API docs (OpenAPI, README API section, dedicated API docs)
3. Find:
   - **Documented but not in code** = stale documentation
   - **In code but not documented** = undocumented endpoint
   - **Different HTTP methods** = method mismatch
   - **Different URL patterns** = URL mismatch

### Severity
- Undocumented API endpoint (in code, not in docs): **medium**, `important: true`
- Stale documented endpoint (in docs, not in code): **medium**
- Method mismatch (docs say GET, code is POST): **medium**
- No API documentation at all with >5 endpoints: **high**, `important: true`

---

## Output Reminder

Return findings as JSON array. Use `"domain": "docs-drift"` and IDs like `docs-drift-001`. Categories: `readme-accuracy`, `ai-config-accuracy`, `api-docs`, `comment-accuracy`, `doc-freshness`, `broken-links`, `changelog-accuracy`, `deployment-docs`, `setup-docs`, `api-endpoint-verification`.
