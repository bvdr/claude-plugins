# Domain 06: Test Coverage Gaps

**Purpose:** Identify untested source files, untested critical paths, test quality issues, recently changed code without test updates, flaky test patterns, assertion density problems, missing boundary/edge case tests, and integration test gaps.

**Domain slug:** `test-coverage`
**ID prefix:** `test-coverage-NNN`

---

## Applicability

Most useful when testing tools detected in STACK_PROFILE.testing. If no testing tools found, do lighter analysis (Check 1 and 2 only).

---

## Check 1: Source-to-Test Mapping

**Multi-pass approach:**
1. DISCOVER: Find all source files and all test files
2. READ: For unmapped source files, read them to assess their importance
3. ANALYZE: Prioritize by criticality — auth, payment, migration, API files matter most

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

**Multi-pass approach:**
1. DISCOVER: Identify files handling critical operations by name and content
2. READ: Read each critical file to understand its complexity and risk
3. ANALYZE: Check not just if a test exists, but if the test covers the critical operations

Identify files handling critical operations by name pattern:
```
(?:auth|login|logout|register|password|payment|checkout|order|billing|invoice|migrate|webhook|callback|subscription|refund|charge|transfer)
```

For each found file:
1. Check for corresponding test file. If no test: **high**, `important: true`
2. If test exists, read it to verify it covers:
   - The happy path (successful operation)
   - Error/failure paths
   - Edge cases (empty input, duplicate, concurrent)

---

## Check 3: Test Quality Analysis

**Multi-pass approach:**
1. DISCOVER: Find all test files
2. READ: Read 15-20 test files (not just 5-10) to get a representative sample
3. ANALYZE: Assess test quality across multiple dimensions

Sample 15-20 test files and analyze:

**Happy-path-only tests:**
- Read test file, count test cases (functions starting with `test`, `it(`, `describe(`)
- Check if any test names include words like `error`, `fail`, `invalid`, `empty`, `null`, `edge`, `boundary`, `missing`, `unauthorized`
- If all test names are positive-only: **medium** — "Tests may only cover happy paths"

**Assertion quality:**
- Check test functions contain actual assertions (`assert`, `expect`, `should`, `assertEquals`, `toBe`, etc.)
- Test functions without assertions = **medium** — "Test runs without verifying behavior"

**Test isolation:**
- Check for shared mutable state between tests
- Tests modifying global state without cleanup
- Tests depending on execution order

**Mock overuse:**
- Count mocks vs real assertions. If >70% of test setup is mocking with minimal assertions: **low** (tests may be testing the mocks, not the code)

### Severity: **medium** for quality issues

---

## Check 4: Recently Changed Untested Code

**Multi-pass approach:**
1. DISCOVER: Get list of files changed in the last 30 days
2. READ: For changed source files without corresponding test changes, read the diff to understand the scope of changes
3. ANALYZE: Assess if the changes are significant enough to require test updates

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

**Multi-pass approach:**
1. DISCOVER: Check if test runner is configured and safe to run
2. ANALYZE: If safe, run the test suite and report results
3. READ: For failing tests, read the test code to understand if it's a real failure or a flaky test

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

## Check 6: Flaky Test Detection

**Multi-pass approach:**
1. DISCOVER: Search test files for patterns that commonly cause flakiness
2. READ: Read the test functions containing flaky patterns to assess risk
3. ANALYZE: Determine if the flaky pattern is properly handled (e.g., mocked time, seeded random)

**Time-dependent tests:**
```
setTimeout|sleep|usleep|time_nanosleep|Date\.now|new Date\(\)|time\(\)|microtime
```
In test files: check if time is mocked or if the test relies on real time.

**Random data without seeds:**
```
Math\.random\(\)|rand\(\)|mt_rand\(\)|random\.\w+|faker\.\w+
```
In test files without corresponding seed setup: tests may produce different results on each run.

**Network calls without mocking:**
```
fetch\(|axios\.\w+\(|wp_remote_\w+\(|curl_exec\(|requests\.\w+\(|http\.get\(
```
In test files: if not using mocks/stubs, tests depend on external services.

**File system operations:**
```
fs\.\w+|file_get_contents|file_put_contents|fopen|readFile|writeFile
```
In test files without tmp directory setup: tests may conflict or leave artifacts.

**Process/port dependencies:**
```
localhost:\d+|127\.0\.0\.1:\d+|0\.0\.0\.0:\d+
```
In test files: tests depend on a specific service being available.

### Severity
- Network calls without mocking in tests: **medium**
- Time-dependent assertions without mocked time: **medium**
- Random data without seed: **low**
- File system operations without cleanup: **low**
- Tests depending on specific ports/services: **medium**

---

## Check 7: Assertion Density

**Multi-pass approach:**
1. DISCOVER: Count test functions and assertions across all test files
2. READ: For test files with low assertion density, read them to understand why
3. ANALYZE: Calculate assertions-per-test ratio

### Counting

**Jest/Mocha/Vitest:**
- Test functions: `it\s*\(|test\s*\(`
- Assertions: `expect\s*\(|assert\s*[.(]`

**PHPUnit:**
- Test functions: `function\s+test\w+\s*\(|@test`
- Assertions: `\$this->assert\w+\(|\$this->expect\w+\(`

**Pytest:**
- Test functions: `def\s+test_\w+`
- Assertions: `assert\s+`

### Metrics
- Calculate total assertions / total test functions = assertion density
- Assertion density <1.0: **medium** — many tests run without verifying anything
- Assertion density <1.5: **low** — tests could be more thorough
- Assertion density >3.0: generally healthy

### Individual test files
- Test file with 0 assertions: **high** — "Test file runs but never checks results"
- Test file with fewer assertions than test functions: **medium**

### Severity
- Overall assertion density <1.0: **medium**, `important: true`
- Individual test file with 0 assertions: **high**
- Assertion density <1.5: **low**

---

## Check 8: Boundary/Edge Case Coverage

**Multi-pass approach:**
1. DISCOVER: Identify critical path functions (from Check 2)
2. READ: Read both the function and its tests
3. ANALYZE: Check if tests cover boundary conditions for the function's parameters

### For each critical path function with tests:

**Check for these test scenarios:**
- **Null/empty input**: Does the test pass null, empty string, empty array?
- **Maximum values**: Does the test use very large numbers, long strings?
- **Invalid types**: Does the test pass wrong types (string where number expected)?
- **Duplicate input**: Does the test handle duplicate submissions?
- **Concurrent access**: For shared resources, does the test check race conditions?
- **Boundary values**: For ranges, does the test check min, max, min-1, max+1?

**How to assess:**
Read test file, look for test names or assertions involving:
```
null|empty|zero|negative|overflow|boundary|edge|invalid|duplicate|concurrent|race|max|min|limit
```

If critical function tests lack ANY edge case testing: **medium**
If critical function tests only have happy path: **high**

### Severity
- Critical function with happy-path-only tests: **high**, `important: true`
- Critical function missing null/empty input tests: **medium**
- Non-critical function missing edge cases: **low**

---

## Check 9: Integration Test Gap Analysis

**Multi-pass approach:**
1. DISCOVER: Map all integration points in the codebase (database, APIs, external services, message queues)
2. READ: Check for integration test files/directories
3. ANALYZE: Compare integration points against integration test coverage
4. RESEARCH: WebSearch "{framework} integration testing best practices" for guidance

### Identify integration points

**Database integration:**
- Files with direct database queries ($wpdb, ORM calls, raw SQL)
- Database migration files
- Repository/DAO classes

**External API integration:**
- Files making HTTP requests (wp_remote_get, fetch, axios, requests)
- Webhook handlers
- Payment gateway integrations
- OAuth/SSO integrations

**Message queue / event integration:**
- Files publishing/consuming events
- Cron job handlers
- Background job processors

### Check for integration tests
- Look for directories: `tests/integration/`, `tests/e2e/`, `tests/functional/`, `spec/integration/`
- Look for test files with integration-related names
- Check for test database configuration (separate test database)
- Check for mock server setup (WireMock, MSW, nock)

### Calculate ratio
- Count unit test files vs integration test files
- Unit-to-integration ratio >10:1 with many integration points: **medium**
- No integration tests at all with database/API usage: **high**, `important: true`
- Integration tests exist but don't cover payment/auth flows: **high**

### Severity
- No integration tests with significant external dependencies: **high**, `important: true`
- Integration tests exist but miss critical paths: **medium**
- Low unit-to-integration ratio for a highly integrated project: **medium**
- Integration tests present and comprehensive: no finding

---

## Output Reminder

Return findings as JSON array. Use `"domain": "test-coverage"` and IDs like `test-coverage-001`. Categories: `missing-tests`, `critical-path`, `test-quality`, `coverage-regression`, `suite-health`, `flaky-test`, `assertion-density`, `boundary-coverage`, `integration-gap`.
