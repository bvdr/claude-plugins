# Domain 07: Documentation Drift

**Purpose:** Detect documentation out of sync with the codebase — broken paths, stale commands, misleading comments, broken links, and outdated AI configuration files.

**Domain slug:** `docs-drift`
**ID prefix:** `docs-drift-NNN`

---

## Applicability

Always applicable. Every project has at least some documentation.

---

## Check 1: README Accuracy

Find READMEs:
```bash
find PROJECT_ROOT -maxdepth 3 -name 'README*' -not -path '*/node_modules/*' -not -path '*/vendor/*' -not -path '*/.git/*' 2>/dev/null
```

For each README, read and extract:

**a) File/directory paths** (backtick-wrapped, in links, in lists):
- Resolve relative to README's directory
- Verify existence: `test -e {resolved_path}`
- **Severity: medium** for missing paths

**b) Commands** (from code blocks):
- Extract the binary (first word)
- Verify: `command -v {binary} 2>/dev/null` or `test -f PROJECT_ROOT/{script_path}`
- Do NOT execute commands
- **Severity: medium** for commands with missing binaries

**c) Stale version numbers/dates:**
- Grep for `\bv?\d+\.\d+(\.\d+)?\b` — cross-reference with actual version in package.json/composer.json
- Grep for dates `\b20\d{2}[-/]\d{2}[-/]\d{2}\b` — flag >365 days old
- **Severity: low**

---

## Check 2: CLAUDE.md / AI Config Accuracy

Find AI config files:
```bash
find PROJECT_ROOT -maxdepth 3 \( -name 'CLAUDE.md' -o -name '.cursorrules' -o -name 'copilot-instructions.md' \) -not -path '*/vendor/*' 2>/dev/null
```

For each file:

**a) Referenced file paths** — resolve and verify existence. **Severity: medium**

**b) Referenced commands** — verify binary exists. **Severity: medium**

**c) Referenced branch names** — verify against `git branch -a`. **Severity: medium**

**d) Referenced infrastructure paths** (sockets, configs) — verify exist. **Severity: medium**

---

## Check 3: API Documentation

Find API docs: `openapi.yaml`, `swagger.json`, `api-docs.md`, `API.md`

If found, cross-reference documented endpoints with actual route definitions:
- Extract endpoint paths from OpenAPI spec
- Find route definitions in code (adapt to framework)
- Endpoints in docs but NOT in code: **medium** (stale)
- Endpoints in code but NOT in docs: **high** (undocumented API surface)

---

## Check 4: Code Comment Accuracy

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

Find all .md files (exclude vendor/node_modules):
```bash
git log -1 --format='%ai' -- "{filepath}" 2>/dev/null
```

- 180-365 days old: **low**
- 365+ days old: **medium**

Exclude: LICENSE.md, CODE_OF_CONDUCT.md, files in archive/ directories.

---

## Check 6: Broken Internal Links

In all markdown files, extract internal links:
- Relative file links: `\[([^\]]+)\]\((?!https?://|mailto:|#|tel:)([^)\s]+)\)`
- Anchor-only links: `\[([^\]]+)\]\(#([^)]+)\)`

For file links: resolve path, check existence.
For anchor links: verify heading exists in target file.

- Broken file link: **medium**
- Broken anchor link: **low**

Process up to 50 markdown files. Prioritize `docs/`, README files, CLAUDE.md.

---

## Output Reminder

Return findings as JSON array. Use `"domain": "docs-drift"` and IDs like `docs-drift-001`. Categories: `readme-accuracy`, `ai-config-accuracy`, `api-docs`, `comment-accuracy`, `doc-freshness`, `broken-links`.
