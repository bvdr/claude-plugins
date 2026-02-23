# Domain 04: Framework Updates

**Purpose:** Detect outdated frameworks, plugins, packages, and runtime versions. Assess update risk by checking changelogs, community reports, and compatibility. Rate every update as Safe, Caution, or Risk. Identify PHP compatibility issues, plugin conflicts, deprecation timelines, and security patches that need prioritization.

**Domain slug:** `framework-updates`
**ID prefix:** `framework-updates-NNN`

---

## Applicability

ONLY applicable when `STACK_PROFILE.frameworks` has at least one `true` value, OR any language runtime is detected. If nothing detected, return `[]`.

---

## Check 1: WordPress Plugin/Theme Updates

**Skip if:** `STACK_PROFILE.frameworks.wordpress == false`

**Multi-pass approach:**
1. DISCOVER: List all plugins/themes and their update status
2. READ: For each available update, read the plugin's code to understand what APIs are used
3. ANALYZE: Assess risk by checking version bump magnitude and the project's reliance on the plugin
4. RESEARCH: For each update, WebSearch for changelog, breaking changes, and community reports

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

**Multi-pass approach:**
1. DISCOVER: Run outdated check for the detected package manager
2. ANALYZE: Focus on major version bumps in critical packages
3. RESEARCH: WebSearch for changelogs and breaking changes on major bumps

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

**Multi-pass approach:**
1. DISCOVER: Run composer outdated for direct dependencies
2. ANALYZE: Separate WordPress-specific packages from general PHP packages
3. RESEARCH: For major bumps, WebSearch for migration guides

```bash
composer outdated --direct --format=json 2>/dev/null
```

Same analysis as Node. For `wpackagist-*` packages: apply WP-specific analysis.

---

## Check 4: Python/Ruby Updates

Same pattern for `pip list --outdated --format=json` and `bundle outdated --parseable`.

---

## Check 5: Runtime Version Checks

**Multi-pass approach:**
1. DISCOVER: Detect current runtime versions
2. RESEARCH: WebSearch for each runtime's end-of-life schedule
3. ANALYZE: Assess urgency based on EOL timeline

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

## Check 6: PHP Compatibility Matrix

**Skip if:** `STACK_PROFILE.languages.php == false`

**Multi-pass approach:**
1. DISCOVER: Detect current PHP version and framework/CMS minimum requirements
2. READ: Read `composer.json` for PHP version constraints, read `wp-config.php` or framework docs for requirements
3. ANALYZE: Check if current PHP version meets all requirements and when it reaches EOL
4. RESEARCH: WebSearch "PHP {version} end of life", "WordPress minimum PHP requirement {current_year}", "{framework} PHP compatibility"

### Current PHP version
```bash
php -v 2>/dev/null | head -1
```

### PHP EOL check
WebSearch: `"PHP {major.minor}" end of life date`

PHP EOL timeline (verify with WebSearch for latest):
- PHP 8.0: EOL November 2023
- PHP 8.1: EOL December 2025
- PHP 8.2: Active support until December 2025, security until December 2026
- PHP 8.3: Active support until November 2026
- PHP 8.4: Active support until November 2027

### Framework minimum requirements
- **WordPress**: WebSearch "WordPress minimum PHP version requirement" — recent versions require PHP 7.2.24+, recommend 7.4+
- **Laravel**: Check `composer.json` for `php` requirement
- **Symfony**: Check `composer.json` for `php` requirement

### Compatibility with pending updates
If WordPress or framework updates are available (from Check 1), verify the new version's PHP requirements don't exceed the current PHP version.

### Severity
- PHP version already past EOL: **high**, `urgent: true, important: true`
- PHP version reaching EOL within 6 months: **high**, `important: true`
- PHP version incompatible with pending framework update: **high**, `urgent: true`
- PHP version compatible but not optimal: **low**

---

## Check 7: Plugin Conflict Detection (WordPress)

**Skip if:** `STACK_PROFILE.frameworks.wordpress == false`

**Multi-pass approach:**
1. DISCOVER: List all active plugins
2. READ: Check for known conflict patterns in plugin code (same hooks at same priority, competing functionality)
3. RESEARCH: WebSearch for known conflicts between detected plugin combinations

### Active plugins
```bash
wp plugin list --status=active --format=json 2>/dev/null || wplocal plugin list --status=active --format=json 2>/dev/null
```

### Known conflict patterns
1. **Multiple caching plugins**: Check for more than one caching plugin active (W3 Total Cache + WP Super Cache, etc.)
2. **Multiple SEO plugins**: Check for Yoast + RankMath, etc.
3. **Multiple security plugins**: Wordfence + Sucuri + iThemes, etc.
4. **Conflicting optimization plugins**: Multiple image optimizers, multiple minifiers

### WebSearch for plugin pairs
For the top 10 most critical plugins, search:
```
"{plugin-1}" "{plugin-2}" conflict OR incompatible OR issue
```

### Hook priority collisions
Search for plugins hooking the same action/filter at the same priority. Read the hooks from active plugins:
```
add_action\s*\(\s*['"](\w+)['"]\s*,.*,\s*(\d+)
add_filter\s*\(\s*['"](\w+)['"]\s*,.*,\s*(\d+)
```
Same hook + same priority across different plugins = potential conflict.

### Severity
- Known conflicting plugin pair both active: **high**, `important: true`
- Multiple plugins serving same purpose: **medium**
- Hook priority collision in critical hooks: **medium**
- No known conflicts: no finding

---

## Check 8: Deprecation Timeline

**Multi-pass approach:**
1. DISCOVER: Search codebase for known deprecated function/API patterns
2. READ: Read the code using deprecated functions to understand the scope
3. RESEARCH: WebSearch "{framework} deprecations {version}" for timeline and migration guides
4. ANALYZE: Estimate effort to migrate away from deprecated functions

### WordPress deprecations
Search for commonly deprecated WordPress functions:
```
\b(?:get_currentuserinfo|get_user_by_email|set_current_user|get_userdatabylogin|get_the_author_email|is_comments_popup|get_the_content_feed|register_widget_control|wp_get_http|get_current_theme|add_contextual_help|screen_meta_screen)\s*\(
```

Also check:
```
\b(?:mysql_real_escape_string|mysql_query|mysql_connect|ereg|eregi|split|session_register)\s*\(
```
These PHP functions are removed in PHP 7+/8+.

### Framework-specific deprecations
WebSearch: `"{framework}" deprecated functions {major_version}`

For each deprecated function found:
1. What version deprecated it
2. What's the replacement
3. When will it be removed (if known)

### Node.js deprecations
```
require\s*\(\s*['"](?:domain|sys|punycode|querystring)['"]
```
Built-in modules that are deprecated in recent Node versions.

### Severity
- Using function removed in current runtime: **high**, `urgent: true`
- Using function deprecated and scheduled for removal: **medium**, `important: true`
- Using function deprecated but no removal date: **low**
- Deprecated function with easy replacement: **medium**

---

## Check 9: Security Patch Prioritization

**Multi-pass approach:**
1. DISCOVER: From the updates identified in Checks 1-4, identify which are security patches
2. RESEARCH: For each available update, WebSearch "{package} {version} security patch CVE" to determine if it's a security release
3. ANALYZE: Rank security patches by severity and exposure

### Identifying security patches

For each available update (from Checks 1-4):
1. WebSearch: `"{package}" {new-version} security fix`
2. WebSearch: `"{package}" {new-version} CVE`
3. Check if the changelog mentions "security", "vulnerability", "XSS", "SQL injection", "CSRF", "authentication", "authorization"

### WordPress-specific
```bash
wp plugin list --update=available --format=json 2>/dev/null || wplocal plugin list --update=available --format=json 2>/dev/null
```

For each plugin with updates:
1. WebSearch: `"{plugin-slug}" security vulnerability {current_year}`
2. Check WordPress.org for "Fixes a security issue" in recent changelogs
3. Check if the plugin is in WPScan vulnerability database

### Classification

| Update Type | Security? | Severity | Urgency |
|-------------|-----------|----------|---------|
| Security patch (CVE fix) | Yes | **high** | `urgent: true, important: true` |
| Version with "security" in changelog | Likely | **high** | `important: true` |
| Regular update, no security mentions | No | Use Check 1-4 severity | Normal |
| Update for package with known recent CVE | Yes | **critical** | `urgent: true, important: true` |

### Severity
- Unpatched known CVE with available fix: **critical**, `urgent: true, important: true`
- Security patch available but not critical: **high**, `important: true`
- Possible security improvement (new security features): **medium**
- Non-security update: defer to other checks

---

## Rate Limiting

- Max 30 WebSearch calls per audit run — prioritize security-related searches
- Skip web search for patch-only updates on well-known, stable packages
- For 30+ outdated packages, focus on direct dependencies only

---

## Output Reminder

Return findings as JSON array. Use `"domain": "framework-updates"` and IDs like `framework-updates-001`. Categories: `wordpress-plugin`, `wordpress-theme`, `wordpress-core`, `node-package`, `php-package`, `python-package`, `ruby-gem`, `runtime-version`, `php-compatibility`, `plugin-conflict`, `deprecation`, `security-patch`.

Include in `evidence`: current version, available version, and brief changelog/community note.
