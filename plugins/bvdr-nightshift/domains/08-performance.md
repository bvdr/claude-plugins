# Domain 08: Performance Analysis

**Purpose:** Identify slow queries, N+1 patterns, missing indexes, large assets, blocking operations, missing pagination, and memory leak patterns.

**Domain slug:** `performance`
**ID prefix:** `performance-NNN`

---

## Applicability

Always applicable. Database checks only if DB access is available.

---

## Check 1: Database Performance

**Only if MySQL/PostgreSQL is accessible** (check for socket files, connection config in wp-config.php/.env/settings files).

### Find queries in source code
Grep for SQL patterns:
```
(?:SELECT|INSERT|UPDATE|DELETE)\s+
\$wpdb\s*->\s*(?:get_results|get_var|get_row|get_col|query|prepare)
```

### Run EXPLAIN on complex queries
For queries with JOINs or subqueries found in source, construct and run `EXPLAIN`:
```bash
mysql --socket="{socket}" -u root -proot {db} -e "EXPLAIN {query}" 2>/dev/null
```
Look for:
- `type: ALL` (full table scan): **high**
- `possible_keys: NULL` (missing indexes): **high**
- `Extra: Using temporary; Using filesort`: **medium**

### Check for missing indexes
```bash
mysql --socket="{socket}" -u root -proot {db} -e "SHOW INDEX FROM {table}" 2>/dev/null
```
Cross-reference with columns used in WHERE/JOIN clauses.

### Severity
- Full table scan on large table: **high**
- Missing index on frequently-queried column: **high**
- Temporary table / filesort: **medium**

---

## Check 2: N+1 Query Patterns

Search for database queries inside loops:

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

Search for list/collection endpoints returning all records:
- `findAll()`, `fetchAll()`, `get_posts()` without limit
- API handlers returning arrays without pagination params
- **Severity: medium**

---

## Check 7: Memory/Resource Patterns

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

**Unminified JS/CSS in production directories:**
Check for `.js`/`.css` files in `public/`, `dist/`, `build/` that are >100KB and not minified (contain newlines + indentation).

**Missing lazy loading:**
```
<img\s+(?![^>]*loading=['"]lazy['"])
```
In HTML/PHP template files: **low**

---

## Output Reminder

Return findings as JSON array. Use `"domain": "performance"` and IDs like `performance-001`. Categories: `slow-query`, `n-plus-one`, `unbounded-query`, `large-asset`, `blocking-io`, `missing-pagination`, `memory-leak`, `frontend`.
