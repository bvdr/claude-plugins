# Domain 01: Security Scan

**Purpose:** Identify security vulnerabilities including hardcoded secrets, injection flaws, missing input validation, dangerous function usage, authentication/authorization gaps, OWASP header issues, session security weaknesses, file upload risks, and insecure deserialization.

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

**Multi-pass approach:**
1. DISCOVER: Grep for secret patterns across the codebase
2. READ: For each match, read the surrounding function (10-20 lines context) to understand if it's a real secret or a placeholder/test value
3. ANALYZE: Check if the value has high entropy, matches known key formats, or is used in production code paths
4. RESEARCH: WebSearch for any leaked key patterns (e.g., "ghp_ token format", "AWS AKIA key format") to understand risk

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

**Multi-pass approach:**
1. DISCOVER: Grep for `$wpdb->` calls and raw SQL patterns
2. READ: For each match, read the full function containing the query (not just the matched line)
3. ANALYZE: Trace the data flow — where do the variables in the query come from? Are they from user input ($_GET, $_POST, $_REQUEST)?
4. RESEARCH: WebSearch "WordPress SQL injection prevention best practices" to verify your assessment

**$wpdb without prepare:**
```
\$wpdb\s*->\s*(?:query|get_results|get_var|get_row|get_col)\s*\(
```
Read the full function context. If SQL contains `$` variable interpolation without `prepare()` wrapper: finding.

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

**Multi-pass approach:**
1. DISCOVER: Grep for echo/print statements with variables
2. READ: For each match, read the template/view file to understand the output context (HTML body, attribute, script, URL)
3. ANALYZE: Check if the variable is escaped appropriately for its context (esc_html for body, esc_attr for attributes, esc_url for URLs, esc_js for script contexts)
4. RESEARCH: WebSearch "WordPress XSS prevention escaping functions" for context-specific guidance

**echo without escaping:**
```
echo\s+\$(?!this)
```
Check if wrapped in `esc_html()`, `esc_attr()`, `esc_url()`, `esc_textarea()`, `wp_kses()`, `wp_kses_post()`, `intval()`, `absint()`, or `(int)`.

**PHP short echo without escaping:**
```
<\?=\s*\$(?!this)
```

**Node.js (if detected) — innerHTML assignment:**
```
\.innerHTML\s*=
```
Without DOMPurify or sanitization: **high**

**Template literal injection (Node):**
```
`.*\$\{.*req\.(body|query|params)
```

### Severity
- Unescaped user-controlled variable in HTML output: **high**
- Unescaped database variable: **medium**
- Unescaped in admin-only templates: **medium**
- innerHTML with user input: **high**

---

## Check 4: Missing Input Validation (PHP/WordPress)

**Skip if:** `STACK_PROFILE.languages.php == false`

**Multi-pass approach:**
1. DISCOVER: Grep for $_GET, $_POST, $_REQUEST usage
2. READ: For each match, read the full function to trace how the input is used
3. ANALYZE: Check if sanitization happens before the value is used in any operation (DB, output, file, etc.)

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

**Multi-pass approach:**
1. DISCOVER: Grep for dangerous function calls
2. READ: For each match, read the function to understand what data flows into the dangerous call
3. ANALYZE: Determine if user-controlled data can reach the dangerous function
4. RESEARCH: WebSearch for framework-specific alternatives (e.g., "PHP eval alternatives", "safe deserialization")

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

**Multi-pass approach:**
1. DISCOVER: Search for sensitive files in web-accessible directories
2. READ: If found, read the first few lines to assess severity (real credentials vs examples)
3. ANALYZE: Check .gitignore for proper exclusions
4. RESEARCH: WebSearch "web server security file exposure prevention" for framework-specific guidance

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

**Multi-pass approach:**
1. DISCOVER: Grep for route/endpoint registrations
2. READ: For each endpoint, read the full handler function to check for auth middleware/capability checks
3. ANALYZE: Map which endpoints are public vs protected, identify gaps in the auth boundary
4. RESEARCH: WebSearch for framework-specific auth best practices

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

**Multi-pass approach:**
1. DISCOVER: Grep for CORS headers and middleware configuration
2. READ: Read the full config file to understand CORS policy
3. ANALYZE: Check if wildcard is used in production, or if credentials are allowed with wildcard origin

**Wildcard CORS:**
```
Access-Control-Allow-Origin.*\*
```

**Credentials with wildcard (very dangerous):**
```
Access-Control-Allow-Credentials.*true
```
Combined with wildcard origin = **critical**.

### Severity
- Wildcard CORS with credentials in production: **critical**
- Wildcard CORS in production config: **high**
- Wildcard CORS in dev-only config: **low**

---

## Check 9: OWASP Security Headers

**Multi-pass approach:**
1. DISCOVER: Search for security header configuration in server config files (`.htaccess`, `nginx.conf`, `web.config`), middleware, and response headers set in code
2. READ: Read the server/middleware config files in full
3. ANALYZE: Check which OWASP-recommended headers are present and which are missing
4. RESEARCH: WebSearch "OWASP recommended security headers {current_year}" for the latest recommendations

**Headers to check:**

| Header | Pattern to Search | Missing = |
|--------|------------------|-----------|
| Content-Security-Policy | `Content-Security-Policy` | **high** |
| Strict-Transport-Security (HSTS) | `Strict-Transport-Security` | **high** |
| X-Frame-Options | `X-Frame-Options` | **medium** |
| X-Content-Type-Options | `X-Content-Type-Options` | **medium** |
| Referrer-Policy | `Referrer-Policy` | **medium** |
| Permissions-Policy | `Permissions-Policy\|Feature-Policy` | **low** |
| X-XSS-Protection | `X-XSS-Protection` | **low** (deprecated but still useful) |

**Where to search:**
- `.htaccess` files
- Server config includes (nginx.conf, apache.conf)
- PHP: `header()` calls setting security headers
- Node/Express: `helmet` package usage, manual header setting
- WordPress: Check for security header plugins (e.g., `headers-security-advanced-hsts-wp`)
- Django: `SECURE_*` settings in settings.py
- Laravel: middleware setting headers

**CSP analysis (if present):**
- Check for `unsafe-inline` in script-src: **medium** (weakens CSP significantly)
- Check for `unsafe-eval` in script-src: **high** (defeats much of CSP's purpose)
- Check for wildcard `*` in CSP directives: **medium**

### Severity
- Missing CSP: **high**, `important: true`
- Missing HSTS: **high**, `important: true`
- Missing X-Frame-Options: **medium**
- CSP with unsafe-eval: **high**
- Missing all headers: **high**, `urgent: true, important: true`

---

## Check 10: Rate Limiting

**Multi-pass approach:**
1. DISCOVER: Search for rate limiting middleware, plugins, or configuration
2. READ: Read auth-related route handlers and API endpoints
3. ANALYZE: Determine if authentication endpoints, API routes, and AJAX handlers have rate limiting
4. RESEARCH: WebSearch "rate limiting best practices {framework}" for framework-specific solutions

**What to search for:**

### WordPress
- Rate limiting plugins: `grep -r "rate.limit\|throttl\|brute.force" wp-content/plugins/*/`
- Login attempt limiting: search for `wp_login_failed` hooks, Limit Login Attempts plugin
- XML-RPC protection: check if `xmlrpc.php` is blocked or rate-limited
- REST API rate limiting: search for rate limit headers in REST response filters

### Node.js/Express
- `express-rate-limit` package in dependencies
- Custom rate limiting middleware
- API gateway rate limiting config

### PHP/Laravel
- `ThrottleRequests` middleware
- Custom rate limiting in `.htaccess`

### General
- `.htaccess` rate limiting rules
- Cloudflare/CDN rate limiting (check for WAF config files)
- Fail2ban configuration references

**Endpoints that MUST have rate limiting:**
- Login/authentication endpoints
- Password reset endpoints
- Registration endpoints
- API endpoints accepting user input
- File upload endpoints

### Severity
- No rate limiting on login/auth endpoints: **high**, `important: true`
- No rate limiting on API endpoints: **medium**
- XML-RPC enabled without protection (WordPress): **high**
- Rate limiting present but too permissive (>100 attempts/minute): **medium**

---

## Check 11: Session Security

**Multi-pass approach:**
1. DISCOVER: Search for session configuration, auth keys, cookie settings
2. READ: Read the full configuration files containing session/auth settings
3. ANALYZE: Check for default/placeholder values, missing security flags
4. RESEARCH: WebSearch "session security best practices {framework}" for current recommendations

### WordPress
**Auth keys and salts:**
Read `wp-config.php` and check:
```
AUTH_KEY|SECURE_AUTH_KEY|LOGGED_IN_KEY|NONCE_KEY|AUTH_SALT|SECURE_AUTH_SALT|LOGGED_IN_SALT|NONCE_SALT
```
- Check if values are the default WordPress placeholder: `put your unique phrase here`
- Check if values are short (<32 chars) or low-entropy
- Default/placeholder auth keys = **critical**, `urgent: true, important: true`

**Cookie flags:**
Search for cookie configuration:
```
COOKIE_DOMAIN|COOKIEPATH|ADMIN_COOKIE_PATH|COOKIEHASH
```
Also check `session.cookie_secure`, `session.cookie_httponly`, `session.cookie_samesite` in PHP config.

### Node.js
**Session configuration:**
```
session\s*\(\s*\{
cookie\s*:\s*\{
```
Check for:
- `httpOnly: true` (missing = **high**)
- `secure: true` (missing in production = **high**)
- `sameSite: 'strict'` or `'lax'` (missing = **medium**)
- `secret` being a hardcoded string (= **high**)

### General
- Session ID in URL parameters: **critical**
- Session timeout not configured: **medium**
- Session regeneration after login missing: **medium**

### Severity
- Default WordPress auth keys/salts: **critical**, `urgent: true, important: true`
- Missing httpOnly on session cookies: **high**
- Missing secure flag in production: **high**
- Missing SameSite attribute: **medium**

---

## Check 12: File Upload Validation

**Multi-pass approach:**
1. DISCOVER: Search for file upload handling code
2. READ: Read the full upload handler function to understand the validation chain
3. ANALYZE: Check for MIME type validation, extension whitelisting, file size limits, and storage location security
4. RESEARCH: WebSearch "file upload security {framework} OWASP" for current attack vectors

**PHP file uploads:**
```
\$_FILES\s*\[
move_uploaded_file\s*\(
wp_handle_upload\s*\(
wp_handle_sideload\s*\(
```

**Node.js file uploads:**
```
multer\s*\(
formidable\s*\(
busboy
upload\.single\s*\(
upload\.array\s*\(
```

**Python file uploads:**
```
request\.files
FileUpload
UploadedFile
```

**For each upload handler, check:**
1. **MIME type validation**: Is the file type verified server-side (not just client-side)?
2. **Extension whitelist**: Is there an explicit allowlist of permitted extensions?
3. **File size limit**: Is there a maximum file size enforced?
4. **Storage location**: Are uploads stored outside the web root? Are they served through a controlled endpoint?
5. **Filename sanitization**: Is the original filename sanitized to prevent directory traversal?
6. **Content validation**: For images, is the content actually validated (e.g., `getimagesize()`)?

### Severity
- No MIME type validation on upload: **high**
- No extension whitelist: **high**
- Uploads stored in web-accessible directory with original filename: **high**
- Missing file size limit: **medium**
- Client-side-only validation: **high**
- Proper WordPress upload handling (`wp_handle_upload` with type checking): **low** (informational)

---

## Check 13: CSRF Beyond Nonces

**Multi-pass approach:**
1. DISCOVER: Search for state-changing operations (POST handlers, data modification endpoints)
2. READ: Read the handler functions to check for CSRF protection
3. ANALYZE: Look for state-changing GET requests, forms without tokens, missing SameSite cookies

**State-changing GET requests (any framework):**
```
(?:app|router)\.get\s*\(.*(?:delete|remove|update|create|modify|toggle|enable|disable)
```
Also in WordPress:
```
admin_url\s*\(.*action=(?:delete|remove|activate|deactivate)
```
State-changing operations on GET = **high** (CSRF via link/image)

**Forms without CSRF tokens:**
Search for `<form` tags in templates and check for CSRF token fields:
- WordPress: `wp_nonce_field` or hidden `_wpnonce` field
- Laravel: `@csrf` or `csrf_field()`
- Django: `{% csrf_token %}`
- Express: `csurf` middleware

**SameSite cookie attribute:**
Check if session cookies have SameSite=Strict or SameSite=Lax set. Missing SameSite on auth cookies = **medium**.

### Severity
- State-changing GET request: **high**
- Form without CSRF token: **high**
- Missing SameSite on session cookies: **medium**
- CSRF protection present but GET actions not protected: **medium**

---

## Check 14: Directory Traversal

**Multi-pass approach:**
1. DISCOVER: Search for file path construction from user input
2. READ: Read the full function to trace how file paths are built
3. ANALYZE: Check if path sanitization prevents `../` traversal
4. RESEARCH: WebSearch "directory traversal prevention {language}" for language-specific guidance

**PHP path traversal patterns:**
```
file_get_contents\s*\(.*\$_(GET|POST|REQUEST)
readfile\s*\(.*\$_(GET|POST|REQUEST)
include\s*\(.*\$_(GET|POST|REQUEST)
require\s*\(.*\$_(GET|POST|REQUEST)
fopen\s*\(.*\$_(GET|POST|REQUEST)
```

**Node.js path traversal:**
```
path\.join\s*\(.*req\.(params|query|body)
fs\.\w+\s*\(.*req\.(params|query|body)
res\.sendFile\s*\(.*req\.(params|query|body)
```

**Python path traversal:**
```
open\s*\(.*request\.(args|form|data)
send_file\s*\(.*request\.(args|form|data)
```

**Check for path sanitization:**
- PHP: `realpath()`, `basename()`, path prefix validation
- Node: `path.resolve()` with base directory check, `path.normalize()`
- Python: `os.path.realpath()`, `os.path.abspath()` with prefix check

### Severity
- User input flows to file operation without path sanitization: **high**
- Include/require with user input: **critical**
- Path sanitization present but bypassable (e.g., only strips `../` once): **high**
- File path from user input with proper sanitization: no finding

---

## Check 15: Information Disclosure

**Multi-pass approach:**
1. DISCOVER: Search for debug settings, error display configuration, version headers
2. READ: Read configuration files to understand debug/error settings
3. ANALYZE: Determine if debug information would be exposed in production
4. RESEARCH: WebSearch "information disclosure prevention {framework}" for best practices

**Debug mode in production:**

### WordPress
```
WP_DEBUG.*true
WP_DEBUG_DISPLAY.*true
WP_DEBUG_LOG.*true
```
Check if these are set without environment-specific conditions. In production: **medium-high**.

### PHP
```
display_errors.*On
display_startup_errors.*On
error_reporting.*E_ALL
```
In production-facing config: **medium**

### Laravel
```
APP_DEBUG\s*=\s*true
```
In `.env` without environment gating: **medium**

### Node.js
```
stack.*trace|stackTrace|err\.stack
```
In response handlers (not logging): **medium**

**Version information disclosure:**
- `X-Powered-By` header not disabled: **low**
- Server version in headers: **low**
- WordPress version in HTML source (`<meta name="generator"`): **low**
- PHP version in headers: **low**

**Error page information:**
- Stack traces in error responses: **medium**
- Database error messages exposed to users: **high**
- Internal paths exposed in error messages: **medium**

### Severity
- WP_DEBUG_DISPLAY=true in production: **high**
- Stack traces in API error responses: **medium**
- Version headers exposed: **low**
- Database errors shown to users: **high**, `important: true`

---

## Check 16: Insecure Deserialization

**Multi-pass approach:**
1. DISCOVER: Search for deserialization function calls
2. READ: Read the function context to understand what data is being deserialized
3. ANALYZE: Trace the data source — is it user-controlled? From cookies? From database?
4. RESEARCH: WebSearch "{language} insecure deserialization CVE {current_year}" for recent vulnerabilities and attack vectors

### PHP
```
\bunserialize\s*\(
```
Check what data flows into `unserialize()`:
- Data from `$_COOKIE`, `$_GET`, `$_POST`, `$_REQUEST`: **critical**
- Data from database that users can influence: **high**
- Data from trusted internal source: **low** (still recommend `json_decode` instead)

**PHP object injection:**
If `unserialize` is used AND the codebase has classes with `__wakeup()`, `__destruct()`, `__toString()` magic methods: **critical** (PHP Object Injection / POP chain risk)

### Python
```
pickle\.loads?\s*\(
yaml\.load\s*\((?!.*Loader\s*=\s*yaml\.SafeLoader)
marshal\.loads?\s*\(
shelve\.open\s*\(
```

### Node.js
```
node-serialize
serialize-javascript
```
If `node-serialize` is in dependencies: **critical** (known RCE vulnerability — WebSearch "node-serialize CVE")

### Java (if detected)
```
ObjectInputStream
readObject\s*\(
XMLDecoder
XStream\.fromXML
```

### Ruby (if detected)
```
Marshal\.load
YAML\.load(?!_safe)
```

### Severity
- Deserialization of user-controlled data: **critical**, `urgent: true, important: true`
- `node-serialize` in dependencies: **critical**, `urgent: true, important: true`
- Deserialization of database data without validation: **high**
- `unserialize` used anywhere (recommend `json_decode`): **medium**
- `yaml.load` without SafeLoader: **high**

---

## Output Reminder

Return findings as a JSON array using `"domain": "security"` and IDs like `security-001`. Only report findings with evidence. Include code snippets in evidence (up to 500 chars).
