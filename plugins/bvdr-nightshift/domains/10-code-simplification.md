# Domain 10: Code Simplification

**Purpose:** Identify overly complex code that can be simplified. Find functions that are too long, deeply nested conditionals, unnecessary abstractions, convoluted control flow, and redundant patterns. This is a Level 2 domain — it builds on Level 1 audit findings to surface simplification opportunities that individual domain auditors may have noted but not explored.

**Domain slug:** `code-simplification`
**ID prefix:** `code-simplification-NNN`
**Level:** 2 (receives Level 1 findings as input)

---

## Applicability

Always applicable. Every codebase benefits from simplification analysis. Adapt checks to detected languages from `STACK_PROFILE`.

---

## Input: Level 1 Findings

You receive all Level 1 findings as a JSON array in the `L1_FINDINGS` variable. Use them to:
- Identify files that appeared across multiple L1 domains (these are complexity hotspots)
- Find L1 findings that mention complexity, nesting, length, or abstraction issues
- Use L1-identified critical files as starting points for deeper simplification analysis

---

## Check 1: Cyclomatic Complexity (Deep Nesting)

**Multi-pass approach:**
1. REVIEW: Scan L1 findings for any mentions of nesting, complexity, or deeply nested code (domains `code-quality`, `architecture`, `performance` often flag these)
2. DISCOVER: Find functions with 3+ levels of nesting beyond the function's base indentation
3. READ: Read each deeply nested function in full to understand its logic
4. ANALYZE: Determine if the nesting can be reduced with early returns, guard clauses, or extraction
5. RESEARCH: WebSearch "reduce cyclomatic complexity {language} refactoring patterns" for best practices

### Detection patterns

**PHP — deeply nested code (3+ levels within a function):**
```
if\s*\(.*\{\s*\n\s+if\s*\(.*\{\s*\n\s+if\s*\(
```
Also check for nested foreach/for/while loops combined with conditionals.

**JavaScript/TypeScript — deep nesting:**
```
if\s*\(.*\{\s*\n\s+if\s*\(.*\{\s*\n\s+if\s*\(
```
And promise chains nested 3+ levels deep:
```
\.then\s*\(.*\{\s*\n.*\.then\s*\(.*\{\s*\n.*\.then\s*\(
```

**Python — deep indentation (16+ spaces or 4+ tabs from function start):**
```
^                    \S
```
Count indentation levels relative to the function's `def` line.

**Quantitative approach:**
For top 20 largest functions (by line count), manually count decision points:
- Each `if`, `else if`, `elseif`, `elif`, `case`, `catch`, `except`, `while`, `for`, `foreach`, `&&`, `||`, `?:` adds 1 to cyclomatic complexity
- Complexity 10-15: worth noting
- Complexity 16-25: **medium** — this function needs simplification
- Complexity 25+: **high** — this function is a maintenance hazard

### Simplification suggestions

For each finding, suggest a specific refactoring:
- **Guard clauses**: Invert the condition and return early instead of wrapping in an `if` block
- **Extract method**: Pull nested logic into a well-named helper function
- **Strategy/map pattern**: Replace long if/elseif chains with a lookup map or strategy pattern
- **Early return**: Move validation/error checks to the top of the function

### Severity
- 3 levels of nesting: **low** (flag for awareness)
- 4 levels of nesting: **medium**
- 5+ levels of nesting: **high**
- Cyclomatic complexity 16-25: **medium**
- Cyclomatic complexity 25+: **high**, `important: true`

---

## Check 2: Long Functions

**Multi-pass approach:**
1. REVIEW: Check L1 findings from `code-quality` and `architecture` domains for mentions of large functions or god files
2. DISCOVER: Find all functions exceeding 50 lines
3. READ: Read each long function to understand its structure and identify natural split points
4. ANALYZE: Determine if the function does multiple distinct things that could be separate functions
5. RESEARCH: WebSearch "single responsibility principle function length best practices" for guidelines

### Detection strategy

Find all function definitions and measure their length:

**PHP:**
```bash
grep -n 'function\s\+\w\+\s*(' PROJECT_ROOT/**/*.php
```
For each function start line, find the matching closing brace (tracking brace depth). Functions >50 lines = candidate.

**JavaScript/TypeScript:**
```bash
grep -n '^\s*\(async\s\+\)\?function\s\+\w\+\|^\s*\(const\|let\|var\)\s\+\w\+\s*=\s*\(async\s\+\)\?\((\|function\)' PROJECT_ROOT/src/**/*.{js,ts,jsx,tsx}
```

**Python:**
```bash
grep -n '^\s*def\s\+\w\+' PROJECT_ROOT/**/*.py
```

### Classification

For each function >50 lines, read it and classify:
- **Sequential steps**: Function does A, then B, then C in sequence — each step could be a separate function
- **Multiple responsibilities**: Function handles validation AND processing AND logging — violates SRP
- **Long switch/if-else**: 50+ lines of case handling — could use a dispatch map
- **Data transformation pipeline**: Series of transformations that could be chained or composed

### Severity
- 50-100 lines: **low** — worth noting for future cleanup
- 100-200 lines: **medium** — should be split
- 200-500 lines: **high** — maintenance hazard
- 500+ lines: **high**, `important: true` — urgent simplification needed

---

## Check 3: Unnecessary Abstractions

**Multi-pass approach:**
1. REVIEW: Check L1 findings from `architecture` domain for coupling and abstraction mentions
2. DISCOVER: Find wrapper functions, pass-through classes, and single-use abstractions
3. READ: Read both the abstraction and its usage sites to confirm it adds no value
4. ANALYZE: Determine if the abstraction was created speculatively ("might need it later") vs serving a real purpose
5. RESEARCH: WebSearch "YAGNI principle unnecessary abstraction" for common anti-patterns

### Detection patterns

**Single-use wrapper functions:**
Find functions whose entire body is a single call to another function:
```
function\s+(\w+)\s*\([^)]*\)\s*\{?\s*\n\s*return\s+\w+\s*\([^)]*\)\s*;?\s*\n\s*\}?
```
Then verify the wrapper is only called from one place — if so, it adds indirection without value.

**Pass-through classes:**
Classes where every method delegates to another object without adding logic:
```
class\s+(\w+).*\{
```
Read the class. If >70% of methods are one-line delegations to an injected dependency, the class may be unnecessary.

**Interface with single implementation:**
```
interface\s+(\w+)
```
Search for implementations. If exactly one class implements the interface and no tests mock it, the interface is premature abstraction.

**Abstract class with single subclass:**
```
abstract\s+class\s+(\w+)
```
Same check — single subclass means the abstraction adds complexity without polymorphism.

**Factory that creates only one type:**
```
(?:Factory|Builder|Creator)\b
```
Read factory classes. If they always return the same type, the factory pattern is overkill.

### What is NOT unnecessary
Do not flag:
- Abstractions used for testing (interfaces mocked in tests)
- Adapters wrapping third-party libraries (useful for swapping implementations)
- WordPress hooks/filters (designed for extensibility even with single use)
- Dependency injection patterns (valuable for testability)

### Severity
- Single-use wrapper function: **low**
- Pass-through class: **medium**
- Interface/abstract with single implementation and no test mocks: **low**
- Factory creating only one type: **low**
- Multiple unnecessary abstractions forming a "lasagna" pattern (3+ layers of pass-through): **medium**, `important: true`

---

## Check 4: Redundant Code Patterns

**Multi-pass approach:**
1. REVIEW: Check L1 findings for duplication, dead code, and copy-paste mentions
2. DISCOVER: Search for common redundancy patterns in the codebase
3. READ: Read each redundant pattern in context to confirm it can be simplified
4. ANALYZE: Suggest the specific simplification for each case

### Redundancy patterns to detect

**Boolean expression redundancy:**
```
if\s*\(\s*\w+\s*===?\s*true\s*\)
if\s*\(\s*\w+\s*===?\s*false\s*\)
return\s+\w+\s*\?\s*true\s*:\s*false
return\s+\w+\s*===?\s*true
```
These can all be simplified: `if (x === true)` becomes `if (x)`, `return x ? true : false` becomes `return !!x` or `return Boolean(x)`.

**Redundant null/undefined checks before optional chaining:**
```
if\s*\(\s*\w+\s*(?:!==?|===?)\s*(?:null|undefined)\s*\)\s*\{[^}]*\w+\.\w+
```
In JS/TS, code that checks `if (x !== null) { x.foo }` when optional chaining `x?.foo` would suffice.

**Double negation or overly complex boolean logic:**
```
!\s*!\s*\w+
!!\w+\s*===?\s*(?:true|false)
```

**Unnecessary else after return:**
```
return\s+[^;]+;\s*\n\s*\}\s*else\s*\{
```
When the `if` branch returns, the `else` is unnecessary — the code after the `if` block is already the "else" path.

**Identical catch blocks:**
Multiple `try/catch` blocks in the same file with identical catch handling — could use a shared error handler.

**Repeated configuration/setup code:**
Same block of setup code (3+ lines) appearing in multiple functions — should be extracted.

### Severity
- Boolean redundancy: **low**
- Unnecessary else after return: **low**
- Repeated setup code (3+ occurrences): **medium**
- Identical catch blocks (3+ occurrences): **medium**
- Complex boolean logic that can be simplified: **low**

---

## Check 5: Simplification Opportunities from L1 Findings

**Multi-pass approach:**
1. REVIEW: Read ALL L1 findings carefully, looking for patterns that suggest simplification
2. DISCOVER: For files mentioned in 3+ L1 findings, read the full file
3. ANALYZE: Determine if the root cause of multiple L1 findings is underlying complexity that should be addressed
4. RESEARCH: For identified complexity hotspots, WebSearch "{framework} refactoring strategies" for applicable patterns

### What to look for in L1 findings

**Files appearing in multiple domains:**
If the same file appears in `code-quality` (complexity), `architecture` (god file), `performance` (slow), AND `test-coverage` (untested) — the root cause is likely that the file is too complex to test or optimize. The fix is simplification, not adding tests to complex code.

**Error handling findings pointing to complexity:**
If L1 found empty catch blocks, inconsistent error handling, or unchecked return values concentrated in specific files — the root cause may be that the code is too complex for the developer to reason about error paths.

**Duplication findings across related functions:**
If L1 found code duplication between functions that handle similar but slightly different cases — the simplification is to extract the common logic and parameterize the differences.

**Performance findings caused by complexity:**
If L1 found N+1 queries or unnecessary database calls inside loops — the root cause may be a function trying to do too much, making it hard to optimize.

### Aggregation strategy
1. Build a frequency map: `file_path -> [list of L1 finding IDs from different domains]`
2. Files with findings from 4+ different L1 domains: **medium**, `important: true` — these are systemic complexity hotspots
3. Files with findings from 3 L1 domains: **medium**
4. For each hotspot file, read it and write a specific simplification plan

### Severity
- File in 4+ L1 domains: **medium**, `important: true`
- File in 3 L1 domains: **medium**
- Pattern of L1 findings with shared root cause: **medium**
- L1 duplication findings that suggest extract-and-parameterize: **low**

---

## Output Reminder

Return findings as JSON array. Use `"domain": "code-simplification"` and IDs like `code-simplification-001`. Categories: `cyclomatic-complexity`, `long-function`, `unnecessary-abstraction`, `redundant-code`, `l1-simplification`.
