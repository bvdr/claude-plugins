# Domain 14: Cross-Domain Correlation

**Purpose:** Find patterns across all 9 Level 1 domains that individual auditors miss. Detect systemic issues, cascading risks, coverage gaps, and trend correlations that only become visible when viewing all L1 findings together. This is a Level 2 domain — it operates primarily on Level 1 findings.

**Domain slug:** `cross-domain-correlation`
**ID prefix:** `cross-domain-correlation-NNN`
**Level:** 2 (receives Level 1 findings as input)

---

## Applicability

Applicable when L1 findings exist from at least 3 different domains. If fewer than 3 domains produced findings, the correlation analysis has insufficient data — produce a single summary finding noting limited data and skip detailed analysis.

---

## Input: Level 1 Findings

You receive all Level 1 findings as a JSON array in the `L1_FINDINGS` variable. You also receive `PREVIOUS_RUN` (the most recent history entry, or `null` if no history exists) for trend analysis.

This domain's purpose is meta-analysis: finding patterns in the findings themselves, not in the code. However, you SHOULD read code files when needed to verify suspected correlations.

---

## Check 1: Systemic Patterns

**Multi-pass approach:**
1. REVIEW: Build a file frequency map — for each file referenced in L1 findings, count how many different L1 domains flagged it
2. DISCOVER: For files appearing in 4+ domains, read the file to understand what makes it problematic across so many dimensions
3. ANALYZE: Determine if there is a systemic pattern (e.g., "all god files also have security issues" or "all untested files also have performance problems")
4. RESEARCH: WebSearch "codebase hotspot analysis" and "risk-based code analysis" for analytical frameworks

### File hotspot analysis

Build this data structure from L1 findings:
```
{
  "file_path": {
    "domains": ["security", "code-quality", "architecture", "test-coverage"],
    "finding_ids": ["security-003", "code-quality-012", "architecture-005", "test-coverage-008"],
    "severities": ["high", "medium", "high", "high"],
    "categories": ["missing-auth", "complexity", "god-file", "missing-tests"]
  }
}
```

**Hotspot thresholds:**
- File in 4+ L1 domains: **Systemic hotspot** — this file has fundamental structural problems
- File in 3 L1 domains: **Emerging hotspot** — worth monitoring
- File in 2 L1 domains: informational only — do not report unless both are high severity

For each systemic hotspot:
1. List all L1 findings that reference it
2. Identify the ROOT CAUSE (usually architectural — the file does too much)
3. Explain why fixing individual L1 findings won't solve the problem — the file needs restructuring
4. Suggest the restructuring approach

### Domain co-occurrence patterns

Analyze which L1 domains frequently flag the same files:
- **Security + Test Coverage**: Files with security issues AND no tests = highest risk (bugs can't be caught)
- **Architecture + Code Quality**: Files with architectural issues AND code quality issues = structural debt
- **Performance + Architecture**: Performance issues in architecturally problematic files = the architecture is causing the performance problem
- **Docs Drift + Architecture**: Documentation is stale for frequently changing code = the code changes too fast for docs to keep up

Count co-occurrence frequencies and report the top 3 most common domain pairs.

### Category pattern analysis

Look for categories from different domains that frequently co-occur:
- `god-file` (architecture) + `complexity` (code-quality) + `missing-tests` (test-coverage) = classic "too big to test" pattern
- `missing-auth` (security) + `undocumented-endpoint` (docs-drift) = shadow API surface
- `dead-code` (code-quality) + `stale-todo` (code-quality) + `doc-freshness` (docs-drift) = abandoned feature

### Severity
- Systemic hotspot (4+ domains): **medium**, `important: true`
- Emerging hotspot (3 domains, including security): **medium**, `important: true`
- Emerging hotspot (3 domains, no security): **medium**
- Domain co-occurrence pattern across 5+ files: **medium**, `important: true`
- Category pattern indicating abandoned feature: **low**

---

## Check 2: Cascading Risk Analysis

**Multi-pass approach:**
1. REVIEW: Identify L1 findings that, when combined, create risks greater than the sum of their parts
2. READ: For suspected cascading risks, read the affected code to verify the risk chain
3. ANALYZE: Map the cause-effect chain and assess the combined impact
4. RESEARCH: WebSearch "cascading failure analysis software" for systematic approaches

### Risk chain patterns

**Security + No Tests = Unverifiable Security:**
Find files where:
- L1 `security` domain flagged a vulnerability (any severity)
- L1 `test-coverage` domain flagged missing tests for the same file or function

This combination means:
1. There IS a known security issue
2. There are NO tests to verify a fix doesn't break anything
3. There are NO tests to catch regressions if the issue is reintroduced

Risk amplification: The security finding's effective severity increases by one level (medium -> high, high -> critical).

**Performance + No Error Handling = Silent Data Loss:**
Find files where:
- L1 `performance` domain flagged a slow query or timeout risk
- L1 `code-quality` domain flagged empty catch blocks or unchecked return values in the same area

This combination means timeout-related failures will be silently swallowed, potentially causing data inconsistency.

**Architecture Coupling + Security = Wide Blast Radius:**
Find files where:
- L1 `architecture` domain flagged high coupling or god file
- L1 `security` domain flagged a vulnerability in the same file

This combination means a security vulnerability in a highly-coupled file affects many callers — the blast radius of exploitation is maximized.

**Dependency Vulnerability + No Updates = Extended Exposure:**
Find cases where:
- L1 `dependencies` domain flagged a CVE
- L1 `framework-updates` domain flagged the same package or framework as having available updates
- The finding has existed in previous runs (if history available)

This combination means the vulnerability has been known and patchable, but remains unpatched.

**Missing Auth + Missing Docs = Shadow API:**
Find cases where:
- L1 `security` domain flagged missing authentication on an endpoint
- L1 `docs-drift` domain flagged the same endpoint as undocumented

This combination means an unprotected, unknown API surface — the most dangerous kind.

### Cascading risk output
For each identified risk chain:
- `title`: "Cascading risk: {short description}" (e.g., "Cascading risk: Unverifiable security in payment handler")
- `description`: The full cause-effect chain, listing each L1 finding involved
- `evidence`: "Chain: {finding-id-1} (security) + {finding-id-2} (no tests) = unverifiable security fix"
- `recommendation`: Address both findings together — the combined fix is more valuable than either individual fix

### Severity
- Security + No Tests on critical path: **high**, `urgent: true, important: true`
- Performance + No Error Handling in data pipeline: **high**, `important: true`
- Architecture Coupling + Security vulnerability: **high**, `important: true`
- Dependency CVE + No Updates (patchable but unpatched): **medium**, `important: true`
- Missing Auth + Missing Docs: **high**, `urgent: true, important: true`

---

## Check 3: Coverage Gap Analysis

**Multi-pass approach:**
1. REVIEW: Count findings per L1 domain and check for domains with zero findings
2. ANALYZE: Determine if zero findings means "clean" or "false negative" (the L1 auditor may have missed things)
3. READ: For domains with zero findings, spot-check the codebase to verify the clean state
4. RESEARCH: WebSearch "audit false negative detection" for techniques

### Zero-finding domain analysis

For each L1 domain that produced zero findings, assess if this is expected:

**Security (0 findings) — likely false negative if:**
- Project has user authentication (forms, login pages)
- Project handles payments or sensitive data
- Project has API endpoints
- Project is >5000 lines of code
- Action: Spot-check 3-5 files handling auth/payment/API for obvious security gaps

**Dependencies (0 findings) — likely false negative if:**
- Project has 50+ dependencies
- `package.json` or `composer.json` has not been updated in 6+ months
- Action: Run `npm audit` or `composer audit` manually to verify

**Code Quality (0 findings) — likely false negative if:**
- Project has 10+ source files
- Any file exceeds 500 lines
- Action: Read the 3 largest files and check for obvious quality issues

**Test Coverage (0 findings) — likely false negative if:**
- Project has NO test files at all (0 findings should still note the absence of tests)
- Action: Verify that the L1 agent actually checked for test files

**Performance (0 findings) — possibly valid if:**
- Project is a CLI tool, library, or documentation site
- Project has no database queries
- Action: Only flag if project has database access or serves web requests

### Expected finding range by project size
Provide context on whether the finding count seems right:
- Small project (<2000 lines): 5-15 findings expected
- Medium project (2000-20000 lines): 15-50 findings expected
- Large project (20000+ lines): 30-100+ findings expected

If actual findings are <50% of expected range: note as potentially under-audited.
If actual findings are >200% of expected range: note as potentially noisy (false positives).

### Severity
- Domain with 0 findings that likely has issues (based on project characteristics): **medium**, `important: true`
- Total finding count significantly below expected range: **low** (informational)
- Total finding count significantly above expected range: **low** (informational)

---

## Check 4: Trend Correlation

**Multi-pass approach:**
1. REVIEW: Compare current L1 findings against `PREVIOUS_RUN` data (if available)
2. ANALYZE: Identify which domains are improving, which are degrading, and which are stable
3. DISCOVER: If a domain's finding count increased significantly, identify what changed
4. RESEARCH: WebSearch "codebase health trend analysis" for analytical approaches

### Skip condition
If `PREVIOUS_RUN` is `null` (first run), produce a single informational finding noting that trend analysis requires at least two runs and skip the rest of this check.

### Trend analysis (when PREVIOUS_RUN exists)

**Per-domain delta:**
For each domain, calculate:
```
delta = current_count - previous_count
percent_change = (delta / max(previous_count, 1)) * 100
```

Flag significant changes:
- Domain finding count increased by >50%: **low** (degrading)
- Domain finding count decreased by >50%: no finding (improving — good!)
- New domain with findings that had 0 before: **low** (new issue area)

**Severity shift:**
Compare `by_severity` between current and previous:
- Critical count increased: **medium**, `important: true`
- High count increased by >3: **medium**
- Overall severity shifted up (more high/critical, fewer low): **medium**
- Overall severity shifted down: no finding (improving)

**Persistent findings:**
If the same file appears in findings across multiple runs (check finding titles and files against PREVIOUS_RUN patterns):
- Findings that persist across 3+ runs: note as "chronically unaddressed"
- Critical/high findings persisting across 2+ runs: **medium**, `important: true`

Note: Detailed per-finding persistence tracking is limited by the data in `PREVIOUS_RUN` (which has counts, not individual findings). Use domain and severity distributions to infer persistence.

### Trend summary
Produce a single summary finding with:
- Overall trend direction (improving, degrading, stable)
- Domains with the biggest changes
- Severity distribution shift
- Recommendations based on the trend (e.g., "Security findings increased — prioritize security review")

### Severity
- Critical findings increased from previous run: **medium**, `important: true`
- Overall trend is degrading (more findings, higher severity): **medium**
- Overall trend is improving: **low** (positive — still report for the record)
- Stable with no significant changes: **low** (informational)
- First run, no trend data: **low** (informational)

---

## Output Reminder

Return findings as JSON array. Use `"domain": "cross-domain-correlation"` and IDs like `cross-domain-correlation-001`. Categories: `systemic-pattern`, `cascading-risk`, `coverage-gap`, `trend-correlation`.

**Important note:** This domain provides META-analysis of L1 findings. Every finding MUST reference specific L1 finding IDs, domain names, or PREVIOUS_RUN data. Do not report code-level issues directly — that's the job of L1 domains. Report patterns, correlations, and systemic insights that individual L1 auditors cannot see.
