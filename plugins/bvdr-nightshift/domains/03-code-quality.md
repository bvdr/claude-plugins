# Domain 03: Code Quality

**Purpose:** Detect dead code, linter violations, code duplication, excessive complexity, naming inconsistencies, and stale TODO comments.

**Domain slug:** `code-quality`
**ID prefix:** `code-quality-NNN`

---

## Applicability

Always applicable. Adapt checks to detected languages.

---

## Check 1: Linter Violations

Run available linters and report top findings.

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

### Functions never called
Find function/method definitions:
- PHP: `function\s+(\w+)\s*\(`
- JS/TS: `(?:function\s+(\w+)|(?:const|let|var)\s+(\w+)\s*=\s*(?:async\s+)?function)`
- Python: `def\s+(\w+)\s*\(`

For each function name, grep the entire codebase for calls to that name (excluding the definition line itself and test files).

Functions defined but never called elsewhere = dead code.

**Efficiency:** Sample up to 100 function definitions. Prioritize recently-unchanged files (use `git log --since="6 months ago" --name-only` to identify active files; functions in inactive files are more likely dead).

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

Search for similar code blocks:
- Find functions with identical or near-identical names across different files
- Look for blocks of code that appear verbatim in multiple files (>10 consecutive similar lines)

Strategy: Use Grep to find function signatures, then group by name. Functions with the same name in different files suggest duplication.

### Severity
- Duplicated business logic: **medium**
- Duplicated utility code: **low**

---

## Check 4: Complexity

### Large files
```bash
find PROJECT_ROOT -name '*.php' -o -name '*.js' -o -name '*.ts' -o -name '*.py' -o -name '*.rb' | xargs wc -l 2>/dev/null | sort -rn | head -20
```
Exclude vendor/node_modules/.git.

- Files >500 lines: **medium**
- Files >1000 lines: **high**

### Large functions
Read the top 10 largest files and identify functions >100 lines (count lines between function definition and closing brace/dedent).

- Functions >100 lines: **medium**
- Functions >200 lines: **high**

### Deep nesting
Search for deeply nested code (4+ levels of indentation beyond the function's base):
- PHP/JS: count `{` nesting levels
- Python: count indentation levels

### Severity
- Deeply nested code (>4 levels): **medium**
- Functions with >8 parameters: **medium**

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

## Output Reminder

Return findings as JSON array. Use `"domain": "code-quality"` and IDs like `code-quality-001`. Categories: `linter`, `dead-code`, `duplication`, `complexity`, `naming`, `stale-todo`.
