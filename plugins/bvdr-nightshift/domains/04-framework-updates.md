# Domain 04: Framework Updates

**Purpose:** Detect outdated frameworks, plugins, packages, and runtime versions. Assess update risk by checking changelogs, community reports, and compatibility. Rate every update as Safe, Caution, or Risk.

**Domain slug:** `framework-updates`
**ID prefix:** `framework-updates-NNN`

---

## Applicability

ONLY applicable when `STACK_PROFILE.frameworks` has at least one `true` value, OR any language runtime is detected. If nothing detected, return `[]`.

---

## Check 1: WordPress Plugin/Theme Updates

**Skip if:** `STACK_PROFILE.frameworks.wordpress == false`

### Detect updates
```bash
wp plugin list --format=json 2>/dev/null || wplocal plugin list --format=json 2>/dev/null
```
```bash
wp theme list --format=json 2>/dev/null || wplocal theme list --format=json 2>/dev/null
```
```bash
wp core check-update --format=json 2>/dev/null || wplocal core check-update --format=json 2>/dev/null
```

If WP-CLI not available, report as single **medium** finding.

### For each update available:
1. Compare version bump: patch (safe), minor (check), major (risk)
2. WebSearch: `{plugin-name} changelog {new-version}` — look for "breaking change", "deprecated", "removed", "requires PHP"
3. WebSearch: `{plugin-name} {new-version} bug OR issue OR broken` — check community reports
4. Check if project code uses APIs that might be affected by the update
5. Rate: **Safe** / **Caution** / **Risk**

### WordPress core
- Minor/security updates: **medium**, Safe
- Major updates: **medium**, Caution
- Multiple major versions behind: **high**, Risk

### PHP compatibility
```bash
php --version 2>/dev/null | head -1
```
If PHP below minimum for available WP update: **high**, `urgent: true`

### Severity
- Safe: **low** | Caution: **medium** | Risk: **high**
- 3+ major versions behind: **high**, `urgent: true`

---

## Check 2: Node.js Package Updates

**Skip if:** `STACK_PROFILE.languages.node == false`

```bash
npm outdated --json 2>/dev/null
```
(Or yarn/pnpm equivalent based on detected package manager)

For major version bumps on critical packages (`react`, `next`, `express`, `typescript`, `webpack`, `vite`, `jest`):
1. WebSearch for changelog and breaking changes
2. Check for deprecation: `npm view {package} deprecated 2>/dev/null`

### Severity
- Patch behind: **low** | Minor behind: **low**
- 1 major behind: **medium** | 2+ major: **high** | 3+ major: **high**, `urgent: true`
- Deprecated: **high**, `important: true`

---

## Check 3: PHP Composer Updates

**Skip if:** `STACK_PROFILE.languages.php == false`

```bash
composer outdated --direct --format=json 2>/dev/null
```

Same analysis as Node. For `wpackagist-*` packages: apply WP-specific analysis.

---

## Check 4: Python/Ruby Updates

Same pattern for `pip list --outdated --format=json` and `bundle outdated --parseable`.

---

## Check 5: Runtime Version Checks

For each detected runtime:
```bash
node --version 2>/dev/null
php --version 2>/dev/null | head -1
python --version 2>/dev/null || python3 --version 2>/dev/null
ruby --version 2>/dev/null
```

WebSearch: `{runtime} end of life schedule {current_year}`

- EOL version: **high**, `urgent: true, important: true`
- Security-only support: **medium**, `important: true`
- Active support: no finding

---

## Rate Limiting

- Max 20 WebSearch calls per audit run
- Skip web search for patch-only updates on well-known packages
- For 30+ outdated packages, focus on direct dependencies only

---

## Output Reminder

Return findings as JSON array. Use `"domain": "framework-updates"` and IDs like `framework-updates-001`. Categories: `wordpress-plugin`, `wordpress-theme`, `wordpress-core`, `node-package`, `php-package`, `python-package`, `ruby-gem`, `runtime-version`, `lock-file`.

Include in `evidence`: current version, available version, and brief changelog/community note.
