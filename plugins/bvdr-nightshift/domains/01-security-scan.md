# Domain 01: Security Scan

**Purpose:** Identify security vulnerabilities including hardcoded secrets, injection flaws, missing input validation, dangerous function usage, and authentication/authorization gaps.

**Domain slug:** `security`
**ID prefix:** `security-NNN`

---

## Applicability

Always applicable. Every project has security concerns. Gate checks by `STACK_PROFILE` — only run language/framework-specific checks for detected stacks.

## Pre-Scan Setup

Exclude these paths globally: `node_modules`, `vendor`, `.git`, `dist`, `build`, `__pycache__`, `.tox`, `.venv`, `venv`, `.next`, `.nuxt`, `coverage`, `.cache`, `storage/framework`

Source file extensions based on STACK_PROFILE:
- PHP: `*.php` | Node: `*.js`, `*.ts`, `*.jsx`, `*.tsx`, `*.mjs`, `*.cjs` | Python: `*.py` | Ruby: `*.rb` | Go: `*.go` | Rust: `*.rs` | Java: `*.java` | Swift: `*.swift`

---

## Check 1: Hardcoded Secrets (All Projects)

Scan all source files with these Grep patterns (exclude `*.md`, `*.lock`, `*.example`, `*.sample`, test fixtures):

**Passwords:**
```
(?:password|passwd|pwd|pass)\s*[:=]\s*['"][^'"]{4,}['"]
```
Exclude placeholder values: `password123`, `changeme`, `your_password_here`, `<PASSWORD>`, `REPLACE_ME`, `xxx`, `***`

**API keys:**
```
(?:api[_-]?key|apikey|api[_-]?secret)\s*[:=]\s*['"][^'"]{8,}['"]
```

**Generic secrets/tokens:**
```
(?:secret|token|private[_-]?key|auth[_-]?token|access[_-]?token)\s*[:=]\s*['"][^'"]{8,}['"]
```

**Bearer/Basic auth:**
```
(?:Bearer|Basic)\s+[A-Za-z0-9+/=]{20,}
```

**Private keys:**
```
-----BEGIN\s+(RSA\s+|EC\s+|DSA\s+|OPENSSH\s+)?PRIVATE KEY-----
```

**Stripe keys:**
```
(?:sk|pk|rk)[-_](?:live|test)[-_][a-zA-Z0-9]{20,}
```

**GitHub PAT:**
```
ghp_[a-zA-Z0-9]{36}
```

**AWS keys:**
```
(?:AKIA|ABIA|ACCA|ASIA)[A-Z0-9]{16}
```

**Connection strings:**
```
(?:mongodb|postgres|mysql|redis|amqp|sqlite):\/\/[^\s'"]+:[^\s'"]+@[^\s'"]+
```

**.env file check:**
```bash
grep -q '\.env' .gitignore 2>/dev/null && echo "ENV_GITIGNORED=true" || echo "ENV_GITIGNORED=false"
git ls-files '*.env' '.env*' 2>/dev/null
```
If `.env` tracked by git: **critical**. If `.env` not in `.gitignore`: **high**.

### Severity
- Real-looking API key/password/private key in source: **critical**
- `.env` file tracked by git: **critical**
- `.env` not in `.gitignore`: **high**
- Pattern match with placeholder-like value: **low**
- Suspicious high-entropy string unconfirmed: **medium**

---

## Check 2: SQL Injection (PHP/WordPress)

**Skip if:** `STACK_PROFILE.languages.php == false`

**$wpdb without prepare:**
```
\$wpdb\s*->\s*(?:query|get_results|get_var|get_row|get_col)\s*\(
```
Read 5 lines context. If SQL contains `$` variable interpolation without `prepare()` wrapper: finding.

**Direct variable in SQL:**
```
(?:SELECT|INSERT|UPDATE|DELETE|REPLACE)\s+.*\$(?!wpdb)
```

**String concatenation in SQL:**
```
(?:query|get_results|get_var|get_row)\s*\(\s*['"].*['"]\s*\.
```

Exclude: lines with `$wpdb->prepare(`, comments, test mocks.

### Severity
- Variable interpolation without prepare: **critical**
- String concatenation building SQL: **high**
- Unparameterized query on internal data: **medium**

---

## Check 3: XSS (PHP/WordPress)

**Skip if:** `STACK_PROFILE.languages.php == false`

**echo without escaping:**
```
echo\s+\$(?!this)
```
Check if wrapped in `esc_html()`, `esc_attr()`, `esc_url()`, `esc_textarea()`, `wp_kses()`, `wp_kses_post()`, `intval()`, `absint()`, or `(int)`.

**PHP short echo without escaping:**
```
<\?=\s*\$(?!this)
```

### Severity
- Unescaped user-controlled variable in HTML output: **high**
- Unescaped database variable: **medium**
- Unescaped in admin-only templates: **medium**

---

## Check 4: Missing Input Validation (PHP/WordPress)

**Skip if:** `STACK_PROFILE.languages.php == false`

**Unsanitized superglobals:**
```
\$_(?:GET|POST|REQUEST|SERVER|COOKIE)\s*\[
```
Check if passed through sanitize function within 3 lines.

**Missing nonce in AJAX handlers:**
```
add_action\s*\(\s*['"]wp_ajax_
```
Check callback for `wp_verify_nonce()` or `check_ajax_referer()` within first 20 lines.

**Missing capability check in admin handlers:**
```
add_action\s*\(\s*['"]admin_(?:init|post|menu)
```
Check for `current_user_can()` within first 20 lines.

### Severity
- Unsanitized input in SQL/output: **high**
- Missing nonce in public AJAX: **high**
- Missing capability check: **high**
- Unsanitized but not yet dangerous: **medium**

---

## Check 5: Dangerous Functions (Multi-Language)

### PHP (if detected)
```
\b(?:eval|assert)\s*\(
\b(?:exec|system|shell_exec|passthru|proc_open|popen)\s*\(
\bunserialize\s*\(
\bpreg_replace\s*\(\s*['"].*\/e['"]
```

### Node.js (if detected)
```
\beval\s*\(
new\s+Function\s*\(
child_process\.(?:exec|execSync)\s*\(
require\s*\(\s*(?!['\"])
```

### Python (if detected)
```
\beval\s*\(
\bexec\s*\(
pickle\.loads?\s*\(
subprocess\.(?:call|run|Popen)\s*\(.*shell\s*=\s*True
os\.system\s*\(
yaml\.load\s*\((?!.*Loader\s*=\s*yaml\.SafeLoader)
```

### Severity
- eval/exec with user input: **critical**
- unserialize/pickle.loads with untrusted data: **critical**
- preg_replace with /e: **critical**
- eval with hardcoded strings: **medium**
- child_process.exec with hardcoded commands: **low**

---

## Check 6: File Permission and Exposure (All Projects)

**.env in web-accessible directories:**
```bash
find PROJECT_ROOT -name '.env' -o -name '.env.*' 2>/dev/null | grep -v '.env.example' | grep -v node_modules | grep -v vendor
```

**Debug/log files in public dirs:**
```bash
find PROJECT_ROOT/public -name 'debug.log' -o -name '*.log' -o -name 'phpinfo.php' -o -name 'info.php' 2>/dev/null
```

**Backup/dump files in public dirs:**
```bash
find PROJECT_ROOT/public -name '*.sql' -o -name '*.sql.gz' -o -name '*.bak' -o -name '*.dump' 2>/dev/null
```

### Severity
- .env/SQL dump in web directory: **critical**
- phpinfo.php in web directory: **high**
- Debug log in web directory: **medium**

---

## Check 7: Authentication/Authorization Gaps

### WordPress (if detected)
**REST endpoints without permission_callback:**
```
register_rest_route\s*\(
```
Read 10 lines context. If missing `permission_callback` or set to `__return_true`: report.

### Express (if detected)
**Sensitive routes without auth middleware:**
```
(?:app|router)\.(?:get|post|put|patch|delete)\s*\(\s*['"]\/(admin|api|dashboard)
```

### Django/FastAPI/Laravel — similar patterns for each detected framework.

### Severity
- REST endpoint with `__return_true` permission: **high**
- Admin route without capability check: **high**
- Sensitive route without auth middleware: **high**

---

## Check 8: CORS Configuration

**Wildcard CORS:**
```
Access-Control-Allow-Origin.*\*
```

### Severity
- Wildcard CORS in production config: **high**
- Wildcard CORS in dev-only config: **low**

---

## Output Reminder

Return findings as a JSON array using `"domain": "security"` and IDs like `security-001`. Only report findings with evidence.
