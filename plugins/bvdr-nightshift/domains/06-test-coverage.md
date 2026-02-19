# Domain 06: Test Coverage Gaps

**Purpose:** Identify untested source files, untested critical paths, test quality issues, and recently changed code without test updates.

**Domain slug:** `test-coverage`
**ID prefix:** `test-coverage-NNN`

---

## Applicability

Most useful when testing tools detected in STACK_PROFILE.testing. If no testing tools found, do lighter analysis (Check 1 and 2 only).

---

## Check 1: Source-to-Test Mapping

Detect test framework from STACK_PROFILE and map source files to tests:
- `src/foo.js` → `tests/foo.test.js`, `__tests__/foo.test.js`, `src/foo.test.js`, `src/foo.spec.js`
- `src/Foo.php` → `tests/FooTest.php`, `tests/Unit/FooTest.php`
- `src/foo.py` → `tests/test_foo.py`, `test/test_foo.py`
- `app/models/foo.rb` → `spec/models/foo_spec.rb`

Strategy:
1. Find all source files (exclude vendor/node_modules/test dirs)
2. For each, check if a corresponding test file exists using the naming conventions above
3. Report source files with NO test file

Prioritize by importance — flag these as higher severity:
- Files containing `auth`, `login`, `payment`, `checkout`, `order`, `migrate`, `webhook`, `api`
- Files in `controllers/`, `routes/`, `handlers/`, `api/` directories

### Severity
- Critical path file without tests: **high**, `important: true`
- Regular file without tests: **medium**
- Test files exist but are empty/minimal: **medium**

---

## Check 2: Critical Path Coverage

Identify files handling critical operations by name pattern:
```
(?:auth|login|logout|register|password|payment|checkout|order|billing|invoice|migrate|webhook|callback|subscription|refund|charge|transfer)
```

For each found file, check for corresponding test file. If no test: **high**, `important: true`.

---

## Check 3: Test Quality Analysis

Sample 5-10 test files and analyze:

**Happy-path-only tests:**
- Read test file, count test cases (functions starting with `test`, `it(`, `describe(`)
- Check if any test names include words like `error`, `fail`, `invalid`, `empty`, `null`, `edge`, `boundary`, `missing`, `unauthorized`
- If all test names are positive-only: **medium** — "Tests may only cover happy paths"

**Assertion quality:**
- Check test functions contain actual assertions (`assert`, `expect`, `should`, `assertEquals`, `toBe`, etc.)
- Test functions without assertions = **medium** — "Test runs without verifying behavior"

### Severity: **medium** for quality issues

---

## Check 4: Recently Changed Untested Code

```bash
git log --since="30 days ago" --name-only --format=format: 2>/dev/null | sort -u | grep -v '^$'
```

For each recently changed source file:
- Check if it has a corresponding test file
- Check if the test file was ALSO changed in the same period
- Source changed but test NOT changed = potential coverage regression

### Severity: **medium**

---

## Check 5: Test Suite Health

If test runner detected AND safe to run:

### Jest
```bash
npx jest --ci --json --silent 2>/dev/null
```

### PHPUnit
```bash
vendor/bin/phpunit --no-coverage --log-junit /dev/stdout 2>/dev/null
```

### Pytest
```bash
python -m pytest --tb=short -q 2>/dev/null
```

**CAUTION:** Only run if:
- Test runner is clearly configured (config file exists)
- No database fixtures that might modify data
- No external service dependencies evident

If running tests seems risky, SKIP and note: "Test suite not executed — may require external services"

Report: total tests, passing, failing, time. Failing tests: **high**.

---

## Output Reminder

Return findings as JSON array. Use `"domain": "test-coverage"` and IDs like `test-coverage-001`. Categories: `missing-tests`, `critical-path`, `test-quality`, `coverage-regression`, `suite-health`.
