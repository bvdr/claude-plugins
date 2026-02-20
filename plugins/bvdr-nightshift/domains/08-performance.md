# Domain 08: Performance Analysis

**Purpose:** Identify slow queries, N+1 patterns, missing indexes, large assets, blocking operations, missing pagination, memory leak patterns, autoloaded options bloat, object cache gaps, WP-Cron issues, asset loading problems, table size issues, HTTP request chains, and OPcache configuration.

**Domain slug:** `performance`
**ID prefix:** `performance-NNN`

---

## Applicability

Always applicable. Database checks only if DB access is available.

---

## Check 1: Database Performance

**Only if MySQL/PostgreSQL is accessible** (check for socket files, connection config in wp-config.php/.env/settings files).

**Multi-pass approach:**
1. DISCOVER: Grep for SQL patterns across the codebase, find all queries
2. READ: Read the functions containing complex queries to understand their context
3. ANALYZE: Run EXPLAIN on top 20 complex queries — this is mandatory, not optional
4. RESEARCH: WebSearch "MySQL query optimization" for specific EXPLAIN output patterns

### Find queries in source code
Grep for SQL patterns:
```
(?:SELECT|INSERT|UPDATE|DELETE)\s+
\$wpdb\s*->\s*(?:get_results|get_var|get_row|get_col|query|prepare)
```

### Detect database credentials

**First, detect database credentials** from project config files:
- WordPress: parse `wp-config.php` for `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_HOST`
- Also check for socket path in `wp-config.php` or CLAUDE.md
- Laravel/PHP: parse `.env` for `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`, `DB_HOST`
- Node: parse `.env` for `DATABASE_URL` or similar
- Python/Django: parse `settings.py` for `DATABASES` dict
- If a MySQL socket file is found: `find /tmp -name 'mysqld.sock' 2>/dev/null` or check config for socket path

If credentials cannot be determined, note: "Database credentials not detected — skipping EXPLAIN analysis" and move to non-DB checks.

### Run EXPLAIN on complex queries (MANDATORY)

For the top 20 queries with JOINs, subqueries, or complex WHERE clauses found in source code, construct and run `EXPLAIN`:
```bash
mysql --socket="{socket}" -u {user} -p{password} {db} -e "EXPLAIN {query}" 2>/dev/null
```

Look for:
- `type: ALL` (full table scan): **high**
- `possible_keys: NULL` (missing indexes): **high**
- `Extra: Using temporary; Using filesort`: **medium**
- `rows` estimate >10,000 on a frequently-called query: **high**

### Check for missing indexes
```bash
mysql --socket="{socket}" -u {user} -p{password} {db} -e "SHOW INDEX FROM {table}" 2>/dev/null
```
Cross-reference with columns used in WHERE/JOIN clauses.

### Severity
- Full table scan on large table: **high**
- Missing index on frequently-queried column: **high**
- Temporary table / filesort: **medium**

---

## Check 2: N+1 Query Patterns

**Multi-pass approach:**
1. DISCOVER: Search for database queries inside loops
2. READ: Read the full loop and surrounding function to confirm N+1 pattern
3. ANALYZE: Estimate the impact — how many iterations does the loop typically have?

### PHP
```
(?:foreach|while|for)\s*\(.*\{[\s\S]*?\$wpdb\s*->
```
Or use multi-line Grep: find `$wpdb->get_` calls, then Read 10 lines before each to check if inside a loop.

### Node.js
Find `await` database calls inside `for`/`forEach`/`map`:
```
\.(?:forEach|map)\s*\(.*(?:await|\.then).*(?:query|find|findOne|get)
```

### Python
```
for\s+.*:\s*\n.*cursor\.execute|\.objects\.(?:get|filter)
```

### Severity: **high** (N+1 is a major performance issue)

---

## Check 3: Unbounded Queries

**Multi-pass approach:**
1. DISCOVER: Search for SELECT * and queries without LIMIT
2. READ: Read the query context to understand if bounding is handled elsewhere
3. ANALYZE: Check if the table could grow unbounded

**SELECT * usage:**
```
SELECT\s+\*\s+FROM
```
In non-migration, non-test files: **medium**

**Missing LIMIT:**
- WordPress: `WP_Query` or `get_posts` without `posts_per_page` or `numberposts`
- General SQL: SELECT without LIMIT on tables that could be large
- **Severity: medium**

---

## Check 4: Large Assets in Repo

```bash
find PROJECT_ROOT -type f -size +1M -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/vendor/*' 2>/dev/null
```

Flag: large images, videos, PDFs, database dumps checked into git.

### Severity: **medium** (should use Git LFS or .gitignore)

---

## Check 5: Synchronous/Blocking Operations

**Multi-pass approach:**
1. DISCOVER: Search for synchronous I/O functions
2. READ: Read the context to determine if it's in a request handler or a startup/CLI script
3. ANALYZE: Sync I/O in request handlers = blocking; in startup scripts = usually fine

### Node.js (if detected)
```
fs\.(?:readFileSync|writeFileSync|mkdirSync|readdirSync|statSync|existsSync|unlinkSync)
```
In non-script, non-CLI files: **medium**

```
(?:execSync|spawnSync)
```
In server/app files: **medium**

### Python (if detected)
Blocking I/O in async contexts:
```
(?:time\.sleep|open\()\s*
```
Inside async functions: **medium**

---

## Check 6: Missing Pagination

**Multi-pass approach:**
1. DISCOVER: Search for list/collection endpoints returning all records
2. READ: Read the endpoint handler to check if pagination is implemented
3. ANALYZE: Estimate the potential dataset size

Search for list/collection endpoints returning all records:
- `findAll()`, `fetchAll()`, `get_posts()` without limit
- API handlers returning arrays without pagination params
- **Severity: medium**

---

## Check 7: Memory/Resource Patterns

**Multi-pass approach:**
1. DISCOVER: Search for patterns that commonly cause memory leaks
2. READ: Read the surrounding code to understand the lifecycle
3. ANALYZE: Determine if the pattern could cause unbounded memory growth

**Arrays growing in loops:**
```
\$\w+\[\]\s*=   # PHP array append in loop
\.push\(         # JS array push - check if in loop
```

**Event listeners without cleanup (Node):**
```
\.on\(|\.addEventListener\(
```
Check if in a function that's called repeatedly without corresponding `removeEventListener`/`.off()`.

**WordPress hooks with closures:**
```
add_action\s*\(.*function\s*\(
add_filter\s*\(.*function\s*\(
```
Closures can't be removed = memory leak in long-running processes: **low**

---

## Check 8: Frontend Performance (if applicable)

**Multi-pass approach:**
1. DISCOVER: Check for unminified assets, missing lazy loading, render-blocking resources
2. READ: Read the build configuration to understand the asset pipeline
3. ANALYZE: Identify low-hanging fruit optimizations

**Unminified JS/CSS in production directories:**
Check for `.js`/`.css` files in `public/`, `dist/`, `build/` that are >100KB and not minified (contain newlines + indentation).

**Missing lazy loading:**
```
<img\s+(?![^>]*loading=['"]lazy['"])
```
In HTML/PHP template files: **low**

---

## Check 9: Autoloaded WP Options

**Skip if:** `STACK_PROFILE.frameworks.wordpress == false` or database not accessible

**Multi-pass approach:**
1. DISCOVER: Query wp_options for all autoloaded options and their sizes
2. READ: For large autoloaded options, understand what plugin/feature stores them
3. ANALYZE: Calculate total autoload payload and identify bloat
4. RESEARCH: WebSearch "WordPress autoload options performance optimization" for best practices

### Query autoloaded options
```bash
mysql --socket="{socket}" -u {user} -p{password} {db} -e "SELECT option_name, LENGTH(option_value) as size FROM wp_options WHERE autoload = 'yes' ORDER BY size DESC LIMIT 30" 2>/dev/null
```

### Total autoload size
```bash
mysql --socket="{socket}" -u {user} -p{password} {db} -e "SELECT SUM(LENGTH(option_value)) as total_autoload_bytes, COUNT(*) as autoload_count FROM wp_options WHERE autoload = 'yes'" 2>/dev/null
```

### What to flag
- Individual option >100KB with autoload=yes: **high** — should be loaded on demand
- Individual option >50KB with autoload=yes: **medium**
- Total autoload payload >1MB: **high**, `important: true`
- Total autoload payload >500KB: **medium**
- Transient data stored with autoload=yes: **medium** (transients should not autoload)
- Options from deactivated plugins still autoloading: **medium**

### Common culprits
Look for option names containing:
- `_transient_` (should not autoload)
- `_site_transient_` (should not autoload)
- `cron` (wp_cron data can bloat)
- Plugin-specific options from deactivated plugins

### Severity
- Single option >100KB autoloaded: **high**
- Total autoload >1MB: **high**, `important: true`
- Transients autoloading: **medium**
- Total autoload 500KB-1MB: **medium**

---

## Check 10: Object Cache Analysis

**Skip if:** `STACK_PROFILE.frameworks.wordpress == false`

**Multi-pass approach:**
1. DISCOVER: Check for object cache configuration and drop-in
2. READ: Read the cache configuration to understand what's cached
3. ANALYZE: Assess if the caching strategy is appropriate for the site's scale
4. RESEARCH: WebSearch "WordPress object cache {detected_cache_plugin} best practices"

### Check for object cache
```bash
test -f wp-content/object-cache.php && echo "OBJECT_CACHE_DROPIN=true" || echo "OBJECT_CACHE_DROPIN=false"
```

### Check WP_CACHE constant
```
define\s*\(\s*['"]WP_CACHE['"]\s*,\s*true\s*\)
```
In `wp-config.php`.

### Check for cache plugins
```bash
wp plugin list --status=active --format=json 2>/dev/null || wplocal plugin list --status=active --format=json 2>/dev/null
```
Look for: Redis Object Cache, Memcached, W3 Total Cache, WP Super Cache, LiteSpeed Cache

### Check for persistent cache usage in code
```
wp_cache_get\s*\(
wp_cache_set\s*\(
wp_cache_delete\s*\(
```
Count usage across the codebase. Heavy `wp_cache_get/set` usage without a persistent object cache backend = wasted effort (default is non-persistent).

### Severity
- No object cache with heavy `wp_cache_*` usage: **medium**, `important: true`
- `WP_CACHE` not defined: **low**
- Object cache plugin installed but not configured: **medium**
- Object cache properly configured: no finding

---

## Check 11: WP-Cron Analysis

**Skip if:** `STACK_PROFILE.frameworks.wordpress == false`

**Multi-pass approach:**
1. DISCOVER: List all scheduled cron events
2. READ: Read the callback functions for cron events to assess their performance impact
3. ANALYZE: Check for long-running handlers, too-frequent schedules, and DISABLE_WP_CRON usage

### List cron events
```bash
wp cron event list --format=json 2>/dev/null || wplocal cron event list --format=json 2>/dev/null
```

### Check DISABLE_WP_CRON
```
DISABLE_WP_CRON
```
In `wp-config.php`. If `true`, check if a system cron is configured (check for cron job referencing `wp-cron.php`).

### Analyze cron handlers
For each custom cron event (exclude WordPress core events):
1. Find the callback function registered for the event
2. Read the function to assess:
   - Does it do heavy database work? (queries without limits)
   - Does it make external HTTP requests? (timeouts)
   - Does it process unbounded datasets? (all users, all posts)
   - How long could it reasonably run?

### What to flag
- Cron handler processing all records without batching: **medium**
- Cron running every minute with heavy operations: **high**
- `DISABLE_WP_CRON=true` without system cron: **high** (cron never runs)
- `DISABLE_WP_CRON` not set (WP-Cron runs on page load): **low** (acceptable for low-traffic)
- Duplicate cron events (same hook scheduled multiple times): **medium**

### Severity
- Heavy cron without batching: **medium**
- Cron disabled without system replacement: **high**
- Minute-frequency heavy cron: **high**
- Duplicate cron schedules: **medium**

---

## Check 12: Asset Loading Audit

**Skip if:** `STACK_PROFILE.frameworks.wordpress == false`

**Multi-pass approach:**
1. DISCOVER: Search for wp_enqueue_script and wp_enqueue_style calls
2. READ: Read the enqueue calls to check for optimization flags
3. ANALYZE: Identify assets loaded globally that should be conditional, missing defer/async, footer loading

### Find all enqueued assets
```
wp_enqueue_script\s*\(
wp_enqueue_style\s*\(
wp_register_script\s*\(
wp_register_style\s*\(
```

### Check for optimization issues

**Global loading (loaded on every page):**
- Scripts/styles enqueued in `wp_enqueue_scripts` without conditional checks
- Assets that should only load on specific pages (e.g., admin-only scripts on frontend)
- **Severity: medium** if asset is >50KB

**Missing footer loading:**
```
wp_enqueue_script\s*\([^)]*\)\s*(?!.*true\s*\))
```
Scripts loaded in header instead of footer (last parameter `true` = footer): **low**

**Missing defer/async:**
Check for `wp_script_add_data` calls adding `defer` or `async` attributes.
Large scripts without defer/async: **low**

**Render-blocking CSS:**
- Styles loaded in header without media attribute optimization
- Large CSS files that could be split by page: **low**

### Severity
- Large script (>100KB) loaded globally on every page: **medium**
- Admin-only asset loaded on frontend: **medium**
- Scripts in header that could be in footer: **low**
- Missing defer on non-critical scripts: **low**

---

## Check 13: Table Size Analysis

**Skip if:** Database not accessible

**Multi-pass approach:**
1. DISCOVER: Query information_schema for table sizes
2. READ: For large tables, check their indexes
3. ANALYZE: Cross-reference large tables with query patterns from Check 1
4. RESEARCH: WebSearch "MySQL large table optimization" for specific table patterns

### Query table sizes
```bash
mysql --socket="{socket}" -u {user} -p{password} {db} -e "SELECT table_name, table_rows, ROUND(data_length/1024/1024, 2) as data_mb, ROUND(index_length/1024/1024, 2) as index_mb, ROUND((data_length + index_length)/1024/1024, 2) as total_mb FROM information_schema.tables WHERE table_schema = '{db}' ORDER BY (data_length + index_length) DESC LIMIT 20" 2>/dev/null
```

### What to flag
- Table >100MB without appropriate indexes: **high**, `important: true`
- Table >1M rows queried without LIMIT in code: **high**
- Table >500MB: **medium** (may need partitioning or archiving)
- `wp_postmeta` or `wp_options` >100MB: **high** (common WordPress bloat)
- `wp_posts` with many revisions (>50 per post): **medium**

### Index coverage
For each large table (>100MB):
```bash
mysql --socket="{socket}" -u {user} -p{password} {db} -e "SHOW INDEX FROM {table}" 2>/dev/null
```
Cross-reference with WHERE/JOIN columns from source code queries.

### Severity
- Large table without indexes on queried columns: **high**, `important: true`
- wp_postmeta/wp_options bloat >100MB: **high**
- Table >500MB without partitioning strategy: **medium**
- Healthy large table with good indexes: no finding

---

## Check 14: HTTP Request Chain Detection

**Multi-pass approach:**
1. DISCOVER: Search for external HTTP request calls
2. READ: Read the functions making HTTP requests to understand the call pattern
3. ANALYZE: Identify waterfall patterns (sequential requests that could be parallelized) and unnecessary requests

### PHP/WordPress
```
wp_remote_get\s*\(
wp_remote_post\s*\(
wp_remote_request\s*\(
curl_exec\s*\(
file_get_contents\s*\(\s*['"]https?://
```

### Node.js
```
fetch\s*\(
axios\.\w+\s*\(
http\.(?:get|request)\s*\(
```

### Python
```
requests\.(?:get|post|put|delete)\s*\(
urllib\.request\.urlopen\s*\(
httpx\.\w+\s*\(
```

### What to flag

**Sequential requests (waterfall):**
Multiple HTTP requests in the same function executed sequentially when they could be parallelized:
```php
$result1 = wp_remote_get($url1);
$result2 = wp_remote_get($url2);  // Could be parallel
$result3 = wp_remote_get($url3);  // Could be parallel
```

**HTTP requests in loops:**
```
foreach.*\{[\s\S]*?wp_remote_
```
Making an HTTP request per iteration: **high**

**Missing timeouts:**
HTTP requests without explicit timeout setting: **medium**

**HTTP requests in page rendering:**
External API calls during WordPress template rendering (not cached): **high**

### Severity
- HTTP request chain (3+ sequential requests): **high**
- HTTP request in a loop: **high**
- External API call during page render without caching: **high**
- Missing timeout on HTTP request: **medium**
- Single necessary HTTP request with timeout: no finding

---

## Check 15: PHP OPcache Check

**Skip if:** `STACK_PROFILE.languages.php == false`

**Multi-pass approach:**
1. DISCOVER: Check PHP OPcache configuration
2. ANALYZE: Verify OPcache is enabled with appropriate settings
3. RESEARCH: WebSearch "PHP OPcache recommended settings {php_version}" for current best practices

### Check OPcache status
```bash
php -i 2>/dev/null | grep -i opcache
```
Or:
```bash
php -r "echo json_encode(opcache_get_status(false));" 2>/dev/null
```

### Key settings to check
```bash
php -i 2>/dev/null | grep -E 'opcache\.(enable|memory_consumption|interned_strings_buffer|max_accelerated_files|revalidate_freq|validate_timestamps)'
```

### What to flag
- OPcache disabled (`opcache.enable=0`): **medium** (significant performance loss)
- `opcache.memory_consumption` < 128: **low** (may run out of memory for large projects)
- `opcache.max_accelerated_files` < 10000 for large projects: **low**
- `opcache.validate_timestamps=1` in production: **low** (minor performance gain to disable)
- `opcache.revalidate_freq=0` in production: **low** (checks on every request)
- OPcache not installed at all: **medium**

### Severity
- OPcache disabled: **medium**
- OPcache not installed: **medium**
- Suboptimal OPcache settings: **low**
- OPcache properly configured: no finding

---

## Output Reminder

Return findings as JSON array. Use `"domain": "performance"` and IDs like `performance-001`. Categories: `slow-query`, `n-plus-one`, `unbounded-query`, `large-asset`, `blocking-io`, `missing-pagination`, `memory-leak`, `frontend`, `autoload-bloat`, `object-cache`, `wp-cron`, `asset-loading`, `table-size`, `http-chain`, `opcache`.
