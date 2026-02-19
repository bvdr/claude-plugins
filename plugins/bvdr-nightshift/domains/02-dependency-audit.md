# Domain 02: Dependency Audit

**Purpose:** Detect known vulnerabilities (CVEs), outdated packages, unused dependencies, and abandoned packages across all package managers.

**Domain slug:** `dependencies`
**ID prefix:** `dependencies-NNN`

---

## Applicability

Always applicable. Even projects without formal package managers may have vendored dependencies.

---

## Check 1: Known Vulnerabilities (CVEs)

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

For each CVE found with severity high or critical, use WebSearch to get details:
- Search: `{CVE-ID} {package-name} severity fix`
- Include CVE ID, description, and fix version in finding

### Severity
- Critical CVE: **critical**, `urgent: true, important: true`
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

For direct dependencies that seem suspicious (very old, low download count):
- Check npm: `npm view {package} time.modified 2>/dev/null` — if last publish > 2 years ago
- Check composer: search Packagist for last update date
- Flag packages with no updates in 2+ years as **medium** with recommendation to find alternatives.

---

## Check 5: Lock File Health

Check lock files exist and are committed:
- `package.json` without `package-lock.json`/`yarn.lock`/`pnpm-lock.yaml`: **medium**
- `composer.json` without `composer.lock`: **medium**
- Lock file exists but not tracked by git: **medium**

Check lock file freshness (if manifest is newer than lock by >7 days): **medium**

---

## Output Reminder

Return findings as JSON array. Use `"domain": "dependencies"` and IDs like `dependencies-001`.
