# Domain 13: Remediation Planning

**Purpose:** Transform Level 1 findings into grouped, prioritized, actionable fix plans. This domain does not discover new issues — it organizes and prioritizes the issues already found by L1 auditors into a practical remediation roadmap. This is a Level 2 domain — it operates primarily on Level 1 findings.

**Domain slug:** `remediation-planning`
**ID prefix:** `remediation-planning-NNN`
**Level:** 2 (receives Level 1 findings as input)

---

## Applicability

Applicable when L1 findings exist. If `L1_FINDINGS` is empty or has fewer than 3 findings, produce a single summary finding noting the clean state and skip detailed planning.

---

## Input: Level 1 Findings

You receive all Level 1 findings as a JSON array in the `L1_FINDINGS` variable. This domain's entire purpose is to analyze, group, prioritize, and plan fixes for these findings. Every check below operates on `L1_FINDINGS`.

---

## Check 1: Group Related Findings

**Multi-pass approach:**
1. REVIEW: Read ALL L1 findings carefully, understanding each one's file, domain, category, and root cause
2. DISCOVER: Identify natural groupings by examining shared files, shared root causes, and shared fix approaches
3. READ: For findings that reference specific files, read the file to understand if multiple findings share a root cause
4. ANALYZE: Create fix groups where a single remediation effort addresses multiple findings at once

### Grouping strategies

**Group by file:**
Multiple L1 findings pointing to the same file often share a root cause. Build a map:
```
file_path -> [finding_1, finding_2, finding_3]
```
If 3+ findings reference the same file, create a fix group for that file.

**Group by root cause:**
Different L1 domains may flag different symptoms of the same problem:
- `security` flags missing input validation + `code-quality` flags unchecked return values -> Root cause: incomplete error handling pattern
- `architecture` flags god file + `code-quality` flags complexity + `test-coverage` flags missing tests -> Root cause: file needs decomposition before it can be properly tested
- `performance` flags N+1 queries + `architecture` flags coupling -> Root cause: tight coupling prevents efficient data access

Read the files involved to determine if findings share a root cause.

**Group by fix pattern:**
Some findings across different files can be fixed with the same approach:
- All `security` findings about missing `esc_html()` -> One fix pattern: add output escaping
- All `code-quality` findings about empty catch blocks -> One fix pattern: add error logging
- All `docs-drift` findings about broken paths -> One fix sweep: update all paths in docs

### Fix group output format
For each group, produce a finding with:
- `title`: Descriptive group name (e.g., "Fix group: Input validation in API handlers")
- `description`: List all L1 finding IDs in this group, the shared root cause, and the single fix approach
- `evidence`: List of L1 finding IDs in the group (e.g., "Groups findings: security-003, security-007, code-quality-012")
- `recommendation`: The specific fix approach that addresses all findings in the group

### Severity
- Fix group containing a critical L1 finding: **high**, `important: true`
- Fix group containing 5+ L1 findings: **medium**, `important: true`
- Fix group containing only low/medium findings: **medium**
- Fix group for documentation updates only: **low**

---

## Check 2: Determine Fix Order

**Multi-pass approach:**
1. REVIEW: Examine all fix groups and standalone findings by severity
2. ANALYZE: Apply the fix ordering rules below to produce a prioritized sequence
3. READ: For ambiguous priority cases, read the affected code to break ties based on risk
4. RESEARCH: WebSearch "vulnerability remediation prioritization framework" for industry-standard approaches

### Ordering rules (applied in this priority)

**Tier 1 — Fix immediately (this sprint/day):**
1. Critical security findings (exposed secrets, SQL injection, RCE, auth bypass)
2. Data loss or corruption risks
3. Production-breaking bugs

**Tier 2 — Fix soon (this week):**
1. High security findings (XSS, missing auth, CSRF)
2. High dependency vulnerabilities (CVEs with known exploits)
3. High stability findings (empty catch blocks in critical paths, unchecked DB writes)

**Tier 3 — Fix next (this month):**
1. Medium security findings
2. Medium code quality findings
3. Performance findings affecting user experience
4. Test coverage gaps on critical paths

**Tier 4 — Fix eventually (backlog):**
1. Low security findings
2. Documentation drift
3. Code style/convention issues
4. Nice-to-have refactoring

### Dependency ordering within tiers
Some fixes depend on others:
- Architecture refactoring should happen BEFORE adding tests (don't test code you're about to restructure)
- Security fixes should happen BEFORE performance optimization (secure first, optimize second)
- Documentation updates should happen AFTER code changes (don't document code that's about to change)

### Output format
Produce a single finding per tier with:
- `title`: "Fix order — Tier N: {description}" (e.g., "Fix order — Tier 1: Critical security remediations")
- `description`: Ordered list of fix groups/findings in this tier with reasoning
- `evidence`: Comma-separated L1 finding IDs in priority order
- `recommendation`: Specific execution order with dependencies noted

### Severity
- Tier 1 ordering plan: **high**, `urgent: true, important: true`
- Tier 2 ordering plan: **high**, `important: true`
- Tier 3 ordering plan: **medium**
- Tier 4 ordering plan: **low**

---

## Check 3: Effort Estimation

**Multi-pass approach:**
1. REVIEW: For each fix group and standalone finding, assess the scope of the change
2. READ: Read the affected files to understand the complexity of the fix
3. ANALYZE: Estimate effort based on the number of files, the nature of the change, and the testing required
4. RESEARCH: WebSearch "software effort estimation techniques" for calibration

### Effort categories

**Trivial (< 30 minutes):**
- One-line changes: adding `esc_html()`, fixing a typo, adding a missing `break`
- Config changes: adding a `.gitignore` entry, updating a version number
- Comment/doc updates: fixing a stale path, adding a missing docblock

**Small (30 minutes — 2 hours):**
- Single-file changes: adding input validation to a function, adding error handling to a catch block
- Adding a missing test for an existing function
- Updating a README section to match current behavior
- Fixing a single security vulnerability in one handler

**Medium (2 hours — 1 day):**
- Multi-file changes: refactoring a function and updating all callers
- Adding test coverage for an untested module (3-5 test files)
- Fixing a pattern across multiple files (e.g., adding output escaping to all templates)
- Resolving a circular dependency

**Large (1 day — 1 week):**
- Architectural changes: decomposing a god file, extracting a service layer
- Major security overhaul: adding authentication to all unprotected endpoints
- Adding integration tests for a complex flow
- Migrating from one pattern to another across the codebase

### Estimation output
For each fix group, produce an effort estimate finding:
- `title`: "Effort estimate: {fix group name} — {effort level}"
- `description`: What needs to change, which files are affected, what testing is needed
- `evidence`: File list and approximate line count of changes
- `recommendation`: Step-by-step implementation plan
- Set the `effort` field to the estimated level (`trivial`, `small`, `medium`, `large`)

### Severity
- Effort estimates inherit the severity of the highest-severity finding in their group
- If a trivial fix resolves a critical finding: include a note highlighting the high ROI

---

## Check 4: Risk Assessment

**Multi-pass approach:**
1. REVIEW: For each fix group, assess the risk of implementing the fix
2. READ: Read the affected code to understand dependencies and side effects
3. ANALYZE: Evaluate deployment risk, rollback complexity, and blast radius
4. RESEARCH: WebSearch "deployment risk assessment checklist" for comprehensive risk factors

### Risk dimensions

**Deployment risk:**
- **Low**: Config-only change, documentation update, adding tests (no production code change)
- **Medium**: Code change in isolated function, change behind feature flag, change with existing test coverage
- **High**: Code change in shared utility used by many callers, database schema change, authentication flow change
- **Critical**: Payment processing change, data migration, API contract change affecting external consumers

**Rollback complexity:**
- **Easy**: Change can be reverted with a single `git revert` and no data migration
- **Moderate**: Change can be reverted but requires cache clearing, config updates, or service restarts
- **Hard**: Change involves database migrations that are not easily reversible
- **Very hard**: Change affects external state (sent emails, API responses to third parties, payment charges)

**Blast radius:**
- **Contained**: Change affects only one feature/module, no shared code modified
- **Moderate**: Change affects shared utility used by 2-5 callers
- **Wide**: Change affects shared code used across the application, or modifies a framework/library
- **System-wide**: Change affects database schema, authentication, or routing — impacts everything

### Testing requirements
For each fix group, specify what testing is needed before deployment:
- Unit tests that should pass
- Integration tests that should be run
- Manual testing steps
- Specific regression scenarios to verify

### Risk output format
For each fix group (or for the overall remediation plan), produce a risk assessment finding:
- `title`: "Risk assessment: {area}" (e.g., "Risk assessment: Payment handler security fixes")
- `description`: Deployment risk level, rollback complexity, blast radius, and testing requirements
- `evidence`: List of affected files and their import/dependency count
- `recommendation`: Risk mitigation strategy (e.g., "Deploy behind feature flag", "Run in staging for 48h first", "Prepare rollback script")

### Severity
- Fix with critical deployment risk: **medium**, `important: true`
- Fix with hard rollback: **medium**, `important: true`
- Fix with wide blast radius: **medium**
- Fix with low risk across all dimensions: **low** (note as easy win)

---

## Output Reminder

Return findings as JSON array. Use `"domain": "remediation-planning"` and IDs like `remediation-planning-001`. Categories: `fix-group`, `fix-order`, `effort-estimate`, `risk-assessment`.

**Important note:** This domain does not flag new code issues. Every finding should reference specific L1 finding IDs in its evidence or description. The value of this domain is organization, prioritization, and actionable planning — not discovery.
