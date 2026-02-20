# Domain 03: Code Quality

**Purpose:** Detect dead code, linter violations, code duplication, excessive complexity, naming inconsistencies, stale TODO comments, logic errors, type coercion bugs, unchecked return values, error handling gaps, copy-paste bugs, and debug code left in production.

**Domain slug:** `code-quality`
**ID prefix:** `code-quality-NNN`

---

## Applicability

Always applicable. Adapt checks to detected languages.

---

## Check 1: Linter Violations

**Multi-pass approach:**
1. DISCOVER: Run available linters for detected languages
2. READ: For critical violations, read the surrounding code to understand the context
3. ANALYZE: Group by rule to find systemic patterns, not just individual violations
4. RESEARCH: WebSearch for unfamiliar lint rules to understand their impact

### PHP (if detected)
```bash
vendor/bin/phpcs --report=json --standard=WordPress-Extra -s $(find . -name '*.php' -not -path '*/vendor/*' -not -path '*/node_modules/*' | head -50) 2>/dev/null
```
If PHPCS not available, skip. Report top 10 violations by frequency.

### Node.js (if detected)
```bash
npx eslint --format=json --no-error-on-unmatched-pattern "src/**/*.{js,ts,jsx,tsx}" 2>/dev/null
```
Report top 10 by rule frequency.

### Python (if detected)
```bash
flake8 --format=json --max-line-length=120 --exclude=venv,.venv,__pycache__ . 2>/dev/null
```
Or: `pylint --output-format=json . 2>/dev/null`

### Severity
- Report total count as summary finding: **medium** if >20, **low** if ≤20
- Individual critical violations (security-related lint rules): **high**

---

## Check 2: Dead Code

**Multi-pass approach:**
1. DISCOVER: Find function/method definitions across the codebase
2. READ: For functions that appear unused, read the file to check for dynamic invocation patterns (hooks, callbacks, reflection)
3. ANALYZE: Cross-reference with framework patterns that might invoke functions indirectly

### Functions never called
Find function/method definitions:
- PHP: `function\s+(\w+)\s*\(`
- JS/TS: `(?:function\s+(\w+)|(?:const|let|var)\s+(\w+)\s*=\s*(?:async\s+)?function)`
- Python: `def\s+(\w+)\s*\(`

For each function name, grep the entire codebase for calls to that name (excluding the definition line itself and test files).

Functions defined but never called elsewhere = dead code.

**Efficiency:** Sample up to 100 function definitions. Prioritize recently-unchanged files (use `git log --since="6 months ago" --name-only` to identify active files; functions in inactive files are more likely dead).

**Framework exceptions (do NOT flag):**
- WordPress: functions used as hook callbacks (`add_action`/`add_filter` targets), template functions, shortcode handlers
- Express: route handler functions
- React: component functions (exported)
- Django: view functions referenced in urls.py

### Unused imports/requires
- Node: `import .* from ['"]` — check if the imported name is used in the file
- PHP: `use\s+[\w\\]+;` — check if the class/function alias is used
- Python: `^import\s+\w+|^from\s+\w+\s+import` — check usage

### Severity
- Dead function >50 lines: **medium**
- Dead function <50 lines: **low**
- Unused import: **low**

---

## Check 3: Code Duplication

**Multi-pass approach:**
1. DISCOVER: Find functions with identical or similar signatures across different files
2. READ: Read the duplicated functions to compare their implementations
3. ANALYZE: Determine if the duplication is intentional (e.g., interface implementations) or accidental

Search for similar code blocks:
- Find functions with identical or near-identical names across different files
- Look for blocks of code that appear verbatim in multiple files (>10 consecutive similar lines)

Strategy: Use Grep to find function signatures, then group by name. Functions with the same name in different files suggest duplication.

### Severity
- Duplicated business logic: **medium**
- Duplicated utility code: **low**

---

## Check 4: Complexity

**Multi-pass approach:**
1. DISCOVER: Find the largest files and functions
2. READ: Read the top 10-15 largest functions in full to assess cyclomatic complexity
3. ANALYZE: Count decision points (if/else, switch cases, ternary, &&/||, catch blocks, loops) for cyclomatic complexity estimation

### Large files
```bash
find PROJECT_ROOT -name '*.php' -o -name '*.js' -o -name '*.ts' -o -name '*.py' -o -name '*.rb' | xargs wc -l 2>/dev/null | sort -rn | head -20
```
Exclude vendor/node_modules/.git.

- Files >500 lines: **medium**
- Files >1000 lines: **high**

### Large functions
Read the top 10-15 largest files and identify functions >100 lines (count lines between function definition and closing brace/dedent).

For the top 10 largest functions:
- Count decision points: `if`, `else if`, `elseif`, `case`, `catch`, `while`, `for`, `foreach`, `&&`, `||`, `?:`
- Cyclomatic complexity >15: **high**
- Cyclomatic complexity 10-15: **medium**
- Functions >100 lines: **medium**
- Functions >200 lines: **high**

### Deep nesting
Search for deeply nested code (4+ levels of indentation beyond the function's base):
- PHP/JS: count `{` nesting levels
- Python: count indentation levels

### Severity
- Deeply nested code (>4 levels): **medium**
- Functions with >8 parameters: **medium**
- Cyclomatic complexity >15: **high**

---

## Check 5: Naming Convention Consistency

Learn the project's dominant convention by sampling 50 function names:
- If >70% are snake_case: that's the convention
- If >70% are camelCase: that's the convention
- Flag deviations from the dominant pattern

For PHP/WordPress: check against WordPress standards (snake_case functions, PascalCase classes).

### Severity: **low**

---

## Check 6: Stale TODOs

**Multi-pass approach:**
1. DISCOVER: Find all TODO/FIXME/HACK markers
2. READ: Read the surrounding code to understand what the TODO is about
3. ANALYZE: Use git blame to determine age, assess if the TODO is still relevant

Find all TODO/FIXME/HACK/XXX comments:
```
\b(?:TODO|FIXME|HACK|XXX|WORKAROUND)\b
```

For each, use `git blame` to determine age:
```bash
git blame -L {line},{line} -- {file} 2>/dev/null
```

Age distribution:
- <30 days: recent, no finding
- 30-90 days: count only
- 90-180 days: **low**
- 180+ days: **medium**

Report: total count, age distribution, and individual old TODOs (180+ days).

---

## Check 7: Logic Error Detection

**Multi-pass approach:**
1. DISCOVER: Grep for complex conditional expressions (3+ conditions combined with && or ||)
2. READ: Read the full function containing complex conditionals
3. ANALYZE: Look for specific logic error patterns:
   - Impossible conditions (always true or always false)
   - Redundant conditions (condition already covered by earlier check)
   - Off-by-one errors in loop bounds and array indices
   - Assignment in conditionals (`if ($x = 5)` instead of `if ($x == 5)`)
   - Unreachable code after return/break/continue
   - Missing break in switch cases (fall-through)

**Patterns to search:**

**Assignment in conditional (PHP):**
```
if\s*\(\s*\$\w+\s*=[^=]
```
Exclude `===` and `==`. This catches `if ($x = value)` which is usually a bug.

**Assignment in conditional (JS):**
```
if\s*\(\s*\w+\s*=[^=]
```

**Unreachable code:**
```
(?:return|throw|break|continue)\s*;?\s*\n\s*(?![\s}]*(else|catch|finally|case|default))
```
Code after unconditional return/throw = dead code.

**Missing break in switch (PHP/JS):**
Find `case` labels, read the block, check if it ends with `break`, `return`, `throw`, or has a `// fall-through` comment.

**Identical conditions in if/elseif chain:**
Read if/elseif chains and check for repeated conditions.

**Negation errors:**
```
!\s*\w+\s*[!=]==?\s*(?:null|undefined|false|true|0|'')
```
Double negation or negation of negative check — easy to get wrong.

### Severity
- Assignment in conditional: **high**
- Unreachable code: **medium**
- Missing break in switch (fall-through without comment): **high**
- Impossible/redundant condition: **medium**
- Off-by-one in loop: **high**

---

## Check 8: Type Coercion Bugs

**Multi-pass approach:**
1. DISCOVER: Search for loose comparison operators
2. READ: Read the comparison context to understand what types are being compared
3. ANALYZE: Identify comparisons where type coercion could produce unexpected results
4. RESEARCH: WebSearch "PHP loose comparison table" or "JavaScript type coercion gotchas" for reference

### JavaScript/TypeScript (if detected)
**Loose equality:**
```
[^!=]\s*==\s*[^=]
```
Exclude `===` and `!==`. Flag uses of `==` and `!=` (should use `===` and `!==`).

**Specific dangerous coercions:**
- `== null` (catches both null and undefined — may be intentional, note as informational)
- `== 0` or `== ''` (empty string == 0 is true in JS — often a bug)
- `== false` (many values are falsy in JS)

### PHP (if detected)
**Loose comparison pitfalls:**
```
==\s*(?:0|''|null|false|true|\[\])
```
PHP loose comparison is notoriously tricky (`"0" == false` is true, `"" == 0` is true).

**in_array without strict mode:**
```
\bin_array\s*\([^)]+\)\s*(?!.*,\s*true)
```
`in_array()` without `true` as third argument uses loose comparison: **medium**.

**array_search without strict:**
```
\barray_search\s*\([^)]+\)\s*(?!.*,\s*true)
```

### Severity
- `==` where `===` is needed in security-sensitive code: **high**
- `in_array` without strict mode: **medium**
- General `==` usage in non-critical code: **low**
- `== 0` or `== ''` comparisons: **medium**

---

## Check 9: Unchecked Return Values

**Multi-pass approach:**
1. DISCOVER: Search for function calls to APIs that return error indicators
2. READ: Read the surrounding code to see if the return value is checked
3. ANALYZE: Determine if ignoring the return value could cause data corruption, silent failures, or security issues

**Database calls without return check:**

### WordPress/PHP
```
\$wpdb\s*->\s*(?:insert|update|delete|replace|query)\s*\(
```
These return `false` on failure. Check if the return value is captured and checked:
- `$result = $wpdb->insert(...)` + `if ($result === false)` = good
- `$wpdb->insert(...)` on its own line = unchecked = **medium**

### Node.js
```
await\s+(?:fs\.promises\.\w+|fetch|axios\.\w+|db\.\w+)\s*\(
```
Check if result is captured. Uncaptured async operations may silently fail.

### General
- File operations (`fwrite`, `fclose`, `file_put_contents`): check return value
- API calls (`wp_remote_get`, `wp_remote_post`): check for `WP_Error`
- `mail()` / `wp_mail()`: check boolean return

### Severity
- Unchecked database write operation: **medium**, `important: true`
- Unchecked API call: **medium**
- Unchecked file operation: **medium**
- Unchecked `wp_mail()`: **low**

---

## Check 10: Error Handling Gaps

**Multi-pass approach:**
1. DISCOVER: Search for try/catch blocks and error handling patterns
2. READ: Read the catch blocks to see what happens with the error
3. ANALYZE: Identify empty catches, catch-all patterns that swallow errors, and inconsistent error handling

**Empty catch blocks:**

### PHP
```
catch\s*\([^)]*\)\s*\{\s*\}
```

### JavaScript/TypeScript
```
catch\s*\(\w*\)\s*\{\s*\}
```

### Python
```
except(?:\s+\w+)?:\s*\n\s*pass
```

**Catch-all that swallows errors:**
```
catch\s*\(\s*(?:Exception|\\\Exception|Error|Throwable)\s+\$\w+\s*\)\s*\{[^}]*(?:return\s+(?:null|false|void|undefined)|\})\s*$
```
Catching generic Exception and returning null/false without logging = silent failure.

**Inconsistent error paths:**
Read 10-15 key functions (API handlers, webhook processors, migration code). Check if error handling is consistent:
- Some paths throw, others return null
- Some errors are logged, others silently swallowed
- Mix of error styles in same module

### Severity
- Empty catch block: **high**
- Catch-all swallowing errors without logging: **high**
- Bare `except: pass` in Python: **high**
- Inconsistent error handling patterns: **medium**
- Catch block that only logs but doesn't re-throw in critical path: **medium**

---

## Check 11: Copy-Paste Bug Detection

**Multi-pass approach:**
1. DISCOVER: Find functions with similar signatures (same name prefix, same parameter patterns) across different files
2. READ: Read pairs of similar functions side-by-side
3. ANALYZE: Diff the implementations — look for subtle differences that suggest copy-paste with incomplete modification (e.g., wrong variable name, wrong table name, wrong field reference)

**Strategy:**

1. Extract all function signatures with their file paths:
```
function\s+(\w+)\s*\(([^)]*)\)
```

2. Group functions by name similarity:
   - Same prefix (e.g., `process_order_`, `process_refund_`)
   - Same parameter pattern
   - Same parent class method across subclasses

3. For each pair of similar functions:
   - Read both in full
   - Look for:
     - **Variable name from the other function** (e.g., `$order_id` used where `$refund_id` should be)
     - **Wrong table/model reference** (referencing the wrong database table)
     - **Incomplete rename** (function name changed but internal references not updated)
     - **Missing condition** (one version has a check, the copy doesn't)

4. Also check for **duplicated error messages** that reference the wrong context:
```
(?:error|exception|log).*(?:creating|updating|deleting)\s+(?:order|user|product)
```
Read context to verify the message matches the actual operation.

### Severity
- Wrong variable from copy-paste in production code: **high**
- Incomplete rename in copied function: **medium**
- Duplicated code blocks (>20 lines) that should be a shared function: **medium**
- Similar functions with consistent implementations: no finding

---

## Check 12: Debug Code Detection

**Multi-pass approach:**
1. DISCOVER: Search for debug statements in non-test files
2. READ: For each match, read the context to determine if it's intentional logging or leftover debug code
3. ANALYZE: Distinguish between legitimate logging (structured, configurable) and debug leftovers

**PHP debug statements (in non-test files):**
```
\bvar_dump\s*\(
\bprint_r\s*\(
\bvar_export\s*\(.*true\s*\)
\bdd\s*\(
\bdump\s*\(
\berror_log\s*\(\s*['"]DEBUG
\bxdebug_break\s*\(
```

**JavaScript/TypeScript debug statements (in non-test files):**
```
\bconsole\.\s*(?:log|debug|dir|table|trace|time|timeEnd|group|groupEnd)\s*\(
\bdebugger\s*;?\s*$
\balert\s*\(
```
Exclude: files in `__tests__/`, `*.test.*`, `*.spec.*`, `test/`, `tests/`

**Python debug statements:**
```
\bprint\s*\((?!.*file=)
\bbreakpoint\s*\(
\bpdb\.set_trace\s*\(
\bipdb\.set_trace\s*\(
```

**Note:** Distinguish between:
- **Leftover debug code** (no structured format, random placement): finding
- **Intentional logging** (structured format, in logging framework): not a finding
- `console.log` in a Node.js server file: **medium** (should use proper logger)
- `debugger` statement: **high** (will pause execution in browser)
- `var_dump`/`dd` in PHP: **high** (will output to user in web context)

### Severity
- `debugger` statement in non-test file: **high**
- `var_dump`/`dd` in non-test PHP file: **high**
- `console.log` in production server code: **medium**
- `print_r` in PHP template: **high**
- Debug logging with "DEBUG" prefix: **low** (likely intentional but should be leveled)

---

## Output Reminder

Return findings as JSON array. Use `"domain": "code-quality"` and IDs like `code-quality-001`. Categories: `linter`, `dead-code`, `duplication`, `complexity`, `naming`, `stale-todo`, `logic-error`, `type-coercion`, `unchecked-return`, `error-handling`, `copy-paste`, `debug-code`.
