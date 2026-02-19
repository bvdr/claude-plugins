# Domain 05: Architecture Review

**Purpose:** Analyze structural integrity — god files, circular dependencies, coupling, pattern consistency, separation of concerns, and change hotspots.

**Domain slug:** `architecture`
**ID prefix:** `architecture-NNN`

---

## Applicability

Always applicable. Adapt analysis to detected languages.

---

## Check 1: God Files (Excessive Responsibility)

Find files >500 lines (exclude vendor/node_modules/.git/dist/build):
```bash
find PROJECT_ROOT -type f \( -name '*.php' -o -name '*.js' -o -name '*.ts' -o -name '*.py' -o -name '*.rb' -o -name '*.go' \) -not -path '*/vendor/*' -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/dist/*' -not -path '*/build/*' | xargs wc -l 2>/dev/null | sort -rn | head -20
```

For each file >500 lines, check if also frequently changed:
```bash
git log --oneline --since="90 days ago" -- "{file}" 2>/dev/null | wc -l
```

- >500 lines, <5 changes in 90 days: **medium** (large but stable)
- >500 lines, 5+ changes in 90 days: **high** (large and active hotspot)
- >1000 lines: **high** regardless

### Severity
- Large + frequently changed: **high** | Large + stable: **medium**

---

## Check 2: File Churn Hotspots

```bash
git log --format=format: --name-only --since="90 days ago" 2>/dev/null | sort | uniq -c | sort -rn | head -20
```

Report top 10 most-changed files with their change count. Cross-reference with size from Check 1.

### Severity: **medium** (informational but important for prioritizing other findings)

---

## Check 3: Circular Dependencies

### Node/TypeScript
Trace import chains: for each file, follow `import ... from '...'` and `require('...')` to build a simplified dependency graph. Look for cycles (A→B→C→A).

Strategy:
1. Pick 10-20 core source files (most imported files, found by grepping for their paths in import statements)
2. For each, trace 3 levels of imports
3. Check if any import chain loops back

### PHP
Same with `use` statements and `require`/`include` chains.

### Severity: **high** (circular deps are design problems)

---

## Check 4: Coupling Analysis

Find files with excessive imports:
- Node: count `import` statements per file. Files with >15 imports: **medium**
- PHP: count `use` statements per file. Files with >15: **medium**
- Python: count `import`/`from...import` per file. >15: **medium**

Find files importing across many different directories:
- Extract directory paths from imports
- Files importing from 5+ different top-level directories: **medium**

---

## Check 5: Pattern Inconsistency

### Error handling
Grep for different error handling patterns and count each:
- `try/catch` blocks
- Return `null`/`false`/`undefined` on error
- Error callbacks
- Result/Either types
- `wp_die()` / `abort()` patterns

If 3+ different patterns found: **low** (informational)

### Configuration management
Check for hardcoded values that should be configurable:
```
(?:localhost|127\.0\.0\.1|0\.0\.0\.0)(?::\d+)?
```
In non-config, non-test files: **low**

---

## Check 6: Separation of Concerns

### SQL in controllers/routes
Grep for SQL keywords in route/controller files:
```
(?:SELECT|INSERT|UPDATE|DELETE)\s+
```
In files matching `*controller*`, `*route*`, `*handler*`, `*endpoint*` (but not in model/repository files): **medium**

### Business logic in templates
Grep for complex logic in template/view files:
- PHP: `*.blade.php`, `*.twig` files with `\bif\s*\(.*&&|\bfor\s*\(|\bforeach\s*\(` (more than simple conditionals)
- JS/TS: check if React component files (>200 lines) contain fetch calls or complex data transformation

### Severity: **medium**

---

## Output Reminder

Return findings as JSON array. Use `"domain": "architecture"` and IDs like `architecture-001`. Categories: `god-file`, `churn-hotspot`, `circular-dependency`, `coupling`, `pattern-inconsistency`, `separation-of-concerns`.
