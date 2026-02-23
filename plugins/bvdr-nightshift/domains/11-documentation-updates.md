# Domain 11: Documentation Updates

**Purpose:** Find stale, missing, or inaccurate documentation by comparing README, CLAUDE.md, inline comments, and API docs against the actual codebase. This is a Level 2 domain — it builds on Level 1 audit findings (especially from `docs-drift`) to provide deeper, cross-referenced documentation analysis and generate specific update suggestions.

**Domain slug:** `documentation-updates`
**ID prefix:** `documentation-updates-NNN`
**Level:** 2 (receives Level 1 findings as input)

---

## Applicability

Always applicable. Every project has documentation that can go stale. This domain goes deeper than L1's `docs-drift` by cross-referencing L1 findings to discover documentation gaps that pattern matching alone cannot find.

---

## Input: Level 1 Findings

You receive all Level 1 findings as a JSON array in the `L1_FINDINGS` variable. Use them to:
- Build on `docs-drift` findings — those identify surface-level drift; this domain identifies what the docs SHOULD say
- Use findings from ALL L1 domains to discover undocumented behaviors, gotchas, and setup requirements
- Cross-reference `security` findings with documentation to check if security requirements are documented
- Cross-reference `architecture` findings with documentation to check if architectural decisions are recorded

---

## Check 1: README Accuracy

**Multi-pass approach:**
1. REVIEW: Check L1 `docs-drift` findings for any README accuracy issues already identified
2. DISCOVER: Find all README files and read them in full
3. READ: For every command, path, and version mentioned in a README, verify against the codebase
4. ANALYZE: Build a list of inaccuracies with specific corrections
5. RESEARCH: WebSearch for any external URLs in the README to check they still resolve

### Verification targets

**Commands and scripts:**
Extract all code blocks from README files. For each command:
- Verify the binary exists: `command -v {binary} 2>/dev/null`
- Verify referenced scripts exist: `test -f {script_path}`
- Verify referenced config files exist
- Verify flags are still valid (e.g., if README says `npm run build`, check `package.json` for a `build` script)

**File paths and directories:**
Extract paths from backtick-wrapped text and link targets:
```
`([^`]*(?:\/|\.)[^`]*)`
\[([^\]]+)\]\((?!https?://|mailto:|#)([^)]+)\)
```
Resolve each path relative to the README's location and verify existence.

**Version numbers:**
```
\bv?\d+\.\d+(?:\.\d+)?\b
```
Cross-reference with `package.json` version, `composer.json` version, git tags, and any version constants in the code.

**Installation/setup steps:**
Walk through each numbered step in "Getting Started" or "Installation" sections:
1. Are prerequisite tools mentioned?
2. Do referenced config template files (`.env.example`, `config.sample.php`) exist?
3. Are database setup steps included if the project uses a database?
4. Are environment-specific instructions current?

### Severity
- Incorrect command in README: **medium**
- Broken file path in README: **medium**
- Stale version number: **low**
- Missing critical setup step (identified by L1 findings): **medium**, `important: true`
- README claims feature that no longer exists: **medium**

---

## Check 2: API Documentation

**Multi-pass approach:**
1. REVIEW: Check L1 findings from `docs-drift` (API endpoint verification) and `architecture` (API surface mapping)
2. DISCOVER: Find all API documentation files (OpenAPI/Swagger specs, API.md, Postman collections, inline route docs)
3. READ: Read both the API documentation and the actual route definitions
4. ANALYZE: Build a complete map of documented-vs-actual endpoints, noting discrepancies
5. RESEARCH: WebSearch "{framework} API documentation best practices" for recommended documentation patterns

### Endpoint inventory

Build two lists:

**Actual endpoints from code:**

WordPress REST API:
```
register_rest_route\s*\(\s*['"]([^'"]+)['"]\s*,\s*['"]([^'"]+)['"]
```

WordPress AJAX:
```
add_action\s*\(\s*['"]wp_ajax_(?:nopriv_)?(\w+)['"]
```

Express/Node.js:
```
(?:app|router)\.(?:get|post|put|patch|delete)\s*\(\s*['"]([^'"]+)['"]
```

Slim Framework (PHP):
```
\$app->(?:get|post|put|patch|delete)\s*\(\s*['"]([^'"]+)['"]
```

Laravel:
```
Route::(?:get|post|put|patch|delete|resource)\s*\(\s*['"]([^'"]+)['"]
```

**Documented endpoints from docs:**
Read API documentation files and extract endpoint definitions.

**Compare:**
- Endpoints in code but NOT in docs: undocumented API surface
- Endpoints in docs but NOT in code: stale documentation
- Method mismatches (docs say GET, code is POST)
- Parameter mismatches (docs list different params than code accepts)

### Response format documentation
For documented endpoints, verify:
- Response schema matches actual return values (read the handler code)
- Error responses are documented
- Authentication requirements are documented

### Severity
- Undocumented public endpoint: **high**, `important: true`
- Stale endpoint in docs (removed from code): **medium**
- Missing error response documentation: **medium**
- Missing authentication documentation for protected endpoint: **high**
- No API documentation at all with >5 endpoints: **high**, `important: true`

---

## Check 3: Inline Documentation Quality

**Multi-pass approach:**
1. REVIEW: Check L1 findings for any functions flagged as complex, buggy, or security-sensitive
2. DISCOVER: Find public functions/methods that lack docblocks
3. READ: Read 30-40 functions with existing docblocks to assess accuracy
4. ANALYZE: Compare docblock claims (params, return types, descriptions) against actual function behavior
5. RESEARCH: WebSearch "{language} documentation standards" (e.g., "PHPDoc standards", "JSDoc best practices")

### Missing docblocks on public functions

**PHP:**
Find public/protected methods without a docblock:
```
(?<!/\*\*[^*]*\*/\s*)(?:public|protected)\s+function\s+\w+\s*\(
```
Strategy: Search for `public function` and `protected function`, then check if the preceding lines contain `/** ... */`.

**JavaScript/TypeScript:**
Find exported functions without JSDoc:
```
(?<!/\*\*[^*]*\*/\s*)export\s+(?:async\s+)?function\s+\w+
```

**Python:**
Find public functions (not starting with `_`) without docstrings:
```
def\s+(?!_)\w+\s*\([^)]*\)\s*:?\s*\n\s+(?!"""|''')
```

### Docblock accuracy verification

For functions WITH docblocks, sample 30-40 and check:

**Parameter mismatches:**
- `@param` lists a parameter that doesn't exist in the function signature
- Function has a parameter not listed in `@param`
- `@param` type doesn't match the actual type hint
- `@param` description is wrong or misleading

**Return type mismatches:**
- `@return` says `bool` but function returns `int` or `string`
- `@return void` but function has `return $value` statements
- No `@return` but function returns a value

**Description accuracy:**
- Docblock says "Creates a user" but function actually updates a user (copy-paste from another function)
- Docblock describes behavior the function no longer performs
- Docblock references classes/methods that no longer exist

### Priority targeting from L1 findings

Functions flagged in L1 findings (security issues, bugs, complex logic) should have EXCELLENT documentation. Check if they do. If L1 flagged a function for a security issue but the function has no docblock explaining the security constraints — that's a **high** severity documentation gap.

### Severity
- Missing docblock on public function in critical path (auth, payment, migration): **medium**, `important: true`
- Missing docblock on regular public function: **low**
- Inaccurate `@param` or `@return`: **medium**
- Misleading description (says one thing, does another): **medium**, `important: true`
- Security-sensitive function without security documentation: **high**

---

## Check 4: Configuration Documentation

**Multi-pass approach:**
1. REVIEW: Check L1 findings from `project-health` (environment parity) and `architecture` (config sprawl) for config issues
2. DISCOVER: Find all environment variables used in code and all config files
3. READ: Read `.env.example` or equivalent template files
4. ANALYZE: Compare variables used in code against documented variables
5. RESEARCH: WebSearch "environment variable documentation best practices {framework}"

### Environment variable inventory

**Variables used in code:**

PHP:
```
getenv\s*\(\s*['"](\w+)['"]
\$_ENV\s*\[\s*['"](\w+)['"]
\$_SERVER\s*\[\s*['"](\w+)['"]
```

Node.js:
```
process\.env\.(\w+)
process\.env\[['"](\w+)['"]\]
```

Python:
```
os\.environ\.get\s*\(\s*['"](\w+)['"]
os\.environ\[['"](\w+)['"]\]
os\.getenv\s*\(\s*['"](\w+)['"]
```

WordPress (`wp-config.php`):
```
define\s*\(\s*['"](\w+)['"]
```

**Variables documented in `.env.example` or similar:**
Read `.env.example`, `.env.sample`, or the "Configuration" section of README.

### Gap analysis
1. Variables in code but NOT in `.env.example`: **medium** — new developers won't know these exist
2. Variables in `.env.example` but NOT used in code: **low** — stale documentation
3. Variables without description/comment in `.env.example`: **low**
4. Variables with default values in code that contradict `.env.example`: **medium**
5. Sensitive variables (containing `KEY`, `SECRET`, `PASSWORD`, `TOKEN`) without security notes: **low**

### Configuration file documentation
If the project has multiple config files (especially WordPress projects with `wp-config.php`, `settings.php`, etc.):
- Is there documentation explaining which config file is for what?
- Are required constants documented?
- Are environment-specific overrides documented?

### Severity
- Required variable missing from `.env.example`: **medium**, `important: true`
- Config file undocumented in README/CLAUDE.md: **low**
- Stale variable in `.env.example`: **low**
- No `.env.example` at all when `.env` is used: **medium**
- Missing documentation for config hierarchy (which file overrides which): **low**

---

## Check 5: Documentation Suggestions from L1 Findings

**Multi-pass approach:**
1. REVIEW: Read ALL L1 findings systematically, looking for anything that implies missing documentation
2. DISCOVER: For each category of L1 finding, check if the related behavior is documented anywhere
3. ANALYZE: Generate specific documentation suggestions based on L1 findings
4. RESEARCH: WebSearch "how to document {specific_topic}" for documentation patterns

### L1 finding categories that imply documentation needs

**Security findings -> Security documentation:**
If L1 security found:
- Authentication/authorization requirements -> Check if auth requirements are documented
- Input validation rules -> Check if validation rules are documented for API consumers
- CORS configuration -> Check if CORS policy is documented
- Rate limiting rules -> Check if rate limits are documented for API consumers

**Architecture findings -> Architecture documentation:**
If L1 architecture found:
- Circular dependencies -> The dependency relationship should be documented with reasoning
- Feature entanglement -> Feature boundaries should be documented
- Pattern inconsistencies -> The intended patterns should be documented

**Performance findings -> Performance documentation:**
If L1 performance found:
- N+1 queries -> Query patterns and optimization notes should be documented
- Caching requirements -> Cache invalidation strategies should be documented

**Test coverage findings -> Testing documentation:**
If L1 test coverage found:
- Critical paths without tests -> Testing strategy should be documented
- Test setup requirements -> Test environment setup should be documented

### How to generate suggestions
For each L1 finding that implies a documentation gap:
1. Identify WHERE the documentation should go (README, CLAUDE.md, inline comment, separate doc)
2. Draft the SPECIFIC content that should be added (not just "add documentation" — write what the doc should say)
3. Note the L1 finding ID that triggered this suggestion

### Severity
- Missing security documentation implied by L1 security findings: **medium**, `important: true`
- Missing architecture documentation implied by L1 architecture findings: **low**
- Missing performance documentation implied by L1 performance findings: **low**
- Missing testing documentation implied by L1 test coverage findings: **low**
- Pattern of 5+ L1 findings all implying the same documentation gap: **medium**

---

## Output Reminder

Return findings as JSON array. Use `"domain": "documentation-updates"` and IDs like `documentation-updates-001`. Categories: `readme-accuracy`, `api-docs`, `inline-docs`, `config-docs`, `l1-documentation`.
