# Domain 02: Dependency Audit

**Purpose:** Detect known vulnerabilities (CVEs), outdated packages, unused dependencies, abandoned packages, license conflicts, supply chain risks, and transitive vulnerability exposure across all package managers.

**Domain slug:** `dependencies`
**ID prefix:** `dependencies-NNN`

---

## Applicability

Always applicable. Even projects without formal package managers may have vendored dependencies.

---

## Check 1: Known Vulnerabilities (CVEs)

**Multi-pass approach:**
1. DISCOVER: Run audit commands for each detected package manager
2. READ: For each high/critical CVE, read the package's usage in the codebase to assess actual exposure
3. ANALYZE: Determine if the vulnerable code path is actually used in the project
4. RESEARCH: For every high/critical CVE, WebSearch for CVSS score, exploit availability, and patch information. Cross-reference multiple databases (NVD, GitHub Advisory, Snyk).

### Node.js (if `STACK_PROFILE.languages.node == true`)
```bash
npm audit --json 2>/dev/null
```
Parse JSON output. Each advisory has: `severity` (info/low/moderate/high/critical), `module_name`, `vulnerable_versions`, `patched_versions`, `title`, `url`.

Map npm severities: critical→critical, high→high, moderate→medium, low→low, info→low.

### PHP (if `STACK_PROFILE.languages.php == true`)
```bash
composer audit --format=json 2>/dev/null
```
If `--format=json` not supported:
```bash
composer audit 2>/dev/null
```
Parse text output for advisory listings.

### Python (if `STACK_PROFILE.languages.python == true`)
```bash
pip-audit --format=json 2>/dev/null
```
Fallback:
```bash
safety check --json 2>/dev/null
```
Fallback: `python -m pip_audit --format=json 2>/dev/null`

### Ruby (if `STACK_PROFILE.languages.ruby == true`)
```bash
bundle audit check 2>/dev/null
```

### Go (if `STACK_PROFILE.languages.go == true`)
```bash
govulncheck ./... 2>/dev/null
```
Fallback if `govulncheck` not installed:
```bash
go list -m -json all 2>/dev/null
```
Then use WebSearch to check known CVEs for major dependencies.

### Rust (if `STACK_PROFILE.languages.rust == true`)
```bash
cargo audit 2>/dev/null
```

### Java (if `STACK_PROFILE.languages.java == true`)
Note: Automated CVE scanning for Java requires external tools (OWASP Dependency-Check, Snyk). If none are available, check `pom.xml` or `build.gradle` for known-vulnerable versions of common libraries (Log4j, Spring, Jackson) via WebSearch.

### Deep CVE Research (for all high/critical findings)

For each CVE found with severity high or critical:
1. WebSearch: `{CVE-ID} CVSS score exploit`
2. WebSearch: `{CVE-ID} {package-name} patch fix version`
3. Check if an exploit is publicly available (increases urgency)
4. Check if the vulnerable function/feature is actually used in this project
5. Include CVE ID, CVSS score, exploit availability, and fix version in the finding

### Severity
- Critical CVE with public exploit: **critical**, `urgent: true, important: true`
- Critical CVE without known exploit: **critical**, `important: true`
- High CVE: **high**, `important: true`
- Moderate CVE: **medium**
- Low/info CVE: **low**

---

## Check 2: Outdated Dependencies

### Node.js
```bash
npm outdated --json 2>/dev/null
```
For yarn: `yarn outdated --json 2>/dev/null`
For pnpm: `pnpm outdated --format json 2>/dev/null`

### PHP
```bash
composer outdated --direct --format=json 2>/dev/null
```

### Python
```bash
pip list --outdated --format=json 2>/dev/null
```

For each outdated package, compare current vs latest:
- Patch behind (1.2.3 → 1.2.4): **low**
- Minor behind (1.2.3 → 1.3.0): **low**
- 1 major behind (1.x → 2.x): **medium**
- 2+ major behind: **high**
- 3+ major behind: **high**, `urgent: true`

---

## Check 3: Unused Dependencies

**Multi-pass approach:**
1. DISCOVER: Read package manifest to get all dependency names
2. READ: For each dependency, search source files for actual usage (imports, requires, config references)
3. ANALYZE: Account for indirect usage through config files, build tools, and plugins

### Node.js
Read `package.json` → extract all dependency names from `dependencies` and `devDependencies`.
For each dependency, grep source files for import/require:
```
(?:import|require)\s*\(?['"]PACKAGE_NAME
```
Scan `*.js`, `*.ts`, `*.jsx`, `*.tsx`, `*.mjs`, `*.cjs`. Exclude `node_modules/`.

Also check for usage in config files: `webpack.config.*`, `vite.config.*`, `jest.config.*`, `babel.config.*`, `.eslintrc*`, `tsconfig.json`, `postcss.config.*`, etc.

Dependencies not found in any source or config: **medium**.

### PHP
Read `composer.json` → extract `require` package names.
For each, grep PHP files for:
```
use\s+.*VENDOR\\PACKAGE
```
And class references. Packages not referenced: **medium**.

---

## Check 4: Abandoned Packages

**Multi-pass approach:**
1. DISCOVER: List all direct dependencies from manifests
2. ANALYZE: Check last publish date for each
3. RESEARCH: For packages not updated in 2+ years, WebSearch "{package} abandoned alternative replacement" to find recommended alternatives

For direct dependencies:
- Check npm: `npm view {package} time.modified 2>/dev/null` — if last publish > 2 years ago
- Check composer: search Packagist for last update date
- Flag packages with no updates in 2+ years as **medium** with recommendation to find alternatives.
- If the package has a deprecation notice, flag as **high** with `important: true`.

---

## Check 5: Lock File Health

Check lock files exist and are committed:
- `package.json` without `package-lock.json`/`yarn.lock`/`pnpm-lock.yaml`: **medium**
- `composer.json` without `composer.lock`: **medium**
- Lock file exists but not tracked by git: **medium**

Check lock file freshness (if manifest is newer than lock by >7 days): **medium**

---

## Check 6: Deep CVE Web Research

**Multi-pass approach:**
1. DISCOVER: Extract the top 10 most critical direct dependencies (by usage or by being security-sensitive)
2. RESEARCH: For each, WebSearch `"{package}" CVE {current_year}` and `"{package}" security vulnerability`
3. ANALYZE: Check for 0-day vulnerabilities or advisories not yet in automated audit databases

This check catches vulnerabilities that automated tools miss:
- Recently disclosed CVEs not yet in npm/composer audit databases
- Security issues reported on GitHub but not in NVD
- Supply chain compromises (package takeover, typosquatting)

**For each dependency, search:**
```
WebSearch: "{package-name}" CVE {current_year}
WebSearch: "{package-name}" security vulnerability advisory
```

**Also check for supply chain indicators:**
- Package ownership recently changed
- Unusual version bump patterns
- Known typosquat targets (e.g., `lodash` → `lodahs`)

### Severity
- Active 0-day without patch: **critical**, `urgent: true, important: true`
- Recent CVE not in audit DB: **high**, `important: true`
- Supply chain concern (ownership change): **medium**, `important: true`
- No additional findings beyond automated audit: no finding

---

## Check 7: License Conflict Detection

**Multi-pass approach:**
1. DISCOVER: Read license fields from all package manifests
2. READ: Check `LICENSE` files in direct dependency directories for actual license text
3. ANALYZE: Build a compatibility matrix — identify conflicts between project license and dependency licenses

### License extraction

**Node.js:**
```bash
npm ls --json --all 2>/dev/null
```
Parse `license` field from each package. Or read individual `package.json` files in `node_modules/`.

**PHP:**
Read `composer.lock` and extract license fields from each package entry.

**Python:**
```bash
pip show {package} 2>/dev/null
```
Extract `License` field.

### Conflict rules

| Project License | Problematic Dependency License | Severity |
|----------------|-------------------------------|----------|
| MIT/BSD/Apache | GPL-2.0, GPL-3.0 | **medium** |
| MIT/BSD/Apache | AGPL-3.0 | **high** |
| Any proprietary | GPL, AGPL | **high**, `important: true` |
| Any | SSPL, BSL, Elastic License | **medium** (review required) |
| Any | No license specified | **low** |

### Severity
- GPL/AGPL dependency in permissively-licensed project: **medium**
- AGPL dependency in proprietary project: **high**, `important: true`
- No license on a dependency: **low**
- All licenses compatible: no finding

---

## Check 8: Dependency Tree Depth

**Multi-pass approach:**
1. DISCOVER: Map the full dependency tree
2. ANALYZE: Identify packages that pull in excessive transitive dependencies (supply chain attack surface)

### Node.js
```bash
npm ls --all --json 2>/dev/null | head -500
```
Or analyze `package-lock.json` for tree depth.

**Metrics to check:**
- Total number of transitive dependencies (>500 for a project = **medium**)
- Single direct dependency pulling in >50 transitive deps: **medium** (large supply chain surface)
- Dependency tree depth >10 levels: **low** (informational)

### PHP
```bash
composer show --tree 2>/dev/null | head -100
```

**What to flag:**
- Packages with disproportionate dependency trees compared to functionality
- Multiple packages providing the same functionality (e.g., two HTTP clients)
- Deeply nested dependency chains that increase maintenance risk

### Severity
- >500 total transitive dependencies: **medium**, `important: true`
- Single dep with >50 transitive deps: **medium**
- >10 levels deep: **low**

---

## Check 9: Transitive Vulnerability Tracing

**Multi-pass approach:**
1. DISCOVER: For each CVE found in Check 1, identify which direct dependency pulls in the vulnerable package
2. READ: Trace the dependency chain from direct dep to vulnerable transitive dep
3. ANALYZE: Determine if upgrading the direct dependency would resolve the vulnerability
4. RESEARCH: WebSearch for the direct dependency's plans to update the vulnerable transitive dep

### Node.js
For each vulnerable transitive package:
```bash
npm ls {vulnerable-package} 2>/dev/null
```
This shows which direct dependencies require the vulnerable package.

### PHP
```bash
composer why {vulnerable-package} 2>/dev/null
```
Or:
```bash
composer depends {vulnerable-package} 2>/dev/null
```

### Analysis

For each vulnerable transitive dependency:
1. Identify the direct dependency that pulls it in
2. Check if a newer version of the direct dependency uses a patched version
3. Check if there's a `resolutions`/`overrides` workaround available
4. Report the full chain: `direct-dep → ... → vulnerable-dep@version`

### Severity
- Vulnerable transitive dep with no upgrade path: **high**, `important: true`
- Vulnerable transitive dep fixable by upgrading direct dep: **medium**
- Vulnerable transitive dep with override/resolution available: **low**

---

## Output Reminder

Return findings as JSON array. Use `"domain": "dependencies"` and IDs like `dependencies-001`. Include CVE IDs, CVSS scores, and fix versions in evidence where applicable.
