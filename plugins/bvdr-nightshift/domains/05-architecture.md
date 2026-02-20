# Domain 05: Architecture Review

**Purpose:** Analyze structural integrity — god files, circular dependencies, coupling, pattern consistency, separation of concerns, dependency direction violations, feature entanglement, configuration sprawl, API surface mapping, state management issues, and migration debt.

**Domain slug:** `architecture`
**ID prefix:** `architecture-NNN`

---

## Applicability

Always applicable. Adapt analysis to detected languages.

---

## Check 1: God Files (Excessive Responsibility)

**Multi-pass approach:**
1. DISCOVER: Find the largest source files in the project
2. READ: Read the top 15 largest files to understand their responsibilities
3. ANALYZE: Determine if a file handles multiple unrelated concerns, cross-reference with git churn

Find files >500 lines (exclude vendor/node_modules/.git/dist/build):
```bash
find PROJECT_ROOT -type f \( -name '*.php' -o -name '*.js' -o -name '*.ts' -o -name '*.py' -o -name '*.rb' -o -name '*.go' \) -not -path '*/vendor/*' -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/dist/*' -not -path '*/build/*' | xargs wc -l 2>/dev/null | sort -rn | head -20
```

For each file >500 lines, check if also frequently changed:
```bash
git log --oneline --since="90 days ago" -- "{file}" 2>/dev/null | wc -l
```

For the top 10 largest files, read them and assess:
- How many distinct responsibilities does the file have?
- Does it mix data access, business logic, and presentation?
- Could it be split into focused modules?

- >500 lines, <5 changes in 90 days: **medium** (large but stable)
- >500 lines, 5+ changes in 90 days: **high** (large and active hotspot)
- >1000 lines: **high** regardless

### Severity
- Large + frequently changed: **high** | Large + stable: **medium**

---

## Check 2: File Churn Hotspots

**Multi-pass approach:**
1. DISCOVER: Query git log for most frequently changed files
2. READ: Read the top 5 most-churned files to understand why they change frequently
3. ANALYZE: Cross-reference with size from Check 1 — large + frequently changed = highest risk

```bash
git log --format=format: --name-only --since="90 days ago" 2>/dev/null | sort | uniq -c | sort -rn | head -20
```

Report top 10 most-changed files with their change count. Cross-reference with size from Check 1.

### Severity: **medium** (informational but important for prioritizing other findings)

---

## Check 3: Circular Dependencies

**Multi-pass approach:**
1. DISCOVER: Build a more complete import graph by scanning all source files for imports
2. READ: For detected cycles, read both files to understand the circular relationship
3. ANALYZE: Determine if the cycle is structural (hard to break) or incidental (easy refactor)

### Node/TypeScript
Trace import chains: for each file, follow `import ... from '...'` and `require('...')` to build a dependency graph.

Strategy:
1. Scan all source files for import statements
2. Build a directed graph of file dependencies
3. Detect cycles using depth-first traversal
4. For cycles involving more than 2 files, trace the full chain

### PHP
Same with `use` statements and `require`/`include` chains. Also check for:
- Circular class dependencies (Class A uses Class B, Class B uses Class A)
- Circular hook dependencies (Plugin A hooks into Plugin B's filter, and vice versa)

### Python
Follow `import` and `from ... import` statements. Check for circular imports that Python handles at runtime but indicate design problems.

### Severity
- Circular dependency between core modules: **high**
- Circular dependency between utility modules: **medium**
- Circular dependency involving 3+ files: **high**, `important: true`

---

## Check 4: Coupling Analysis

**Multi-pass approach:**
1. DISCOVER: Count imports per file across the codebase
2. READ: For highly-coupled files, read the imports to understand the nature of the coupling
3. ANALYZE: Distinguish between necessary coupling (e.g., a controller importing its service) and problematic coupling (e.g., a utility importing business logic)

Find files with excessive imports:
- Node: count `import` statements per file. Files with >15 imports: **medium**
- PHP: count `use` statements per file. Files with >15: **medium**
- Python: count `import`/`from...import` per file. >15: **medium**

Find files importing across many different directories:
- Extract directory paths from imports
- Files importing from 5+ different top-level directories: **medium**

**Afferent coupling (incoming):** Files imported by many others = high responsibility, hard to change
**Efferent coupling (outgoing):** Files importing many others = high dependency, fragile

### Severity
- File with >20 imports: **high**
- File imported by >15 other files (high afferent coupling): **medium**, `important: true`
- File with both high afferent and efferent coupling: **high**

---

## Check 5: Pattern Inconsistency

**Multi-pass approach:**
1. DISCOVER: Search for different coding patterns used for the same purpose
2. READ: Read examples of each pattern to confirm they're doing the same thing differently
3. ANALYZE: Identify which pattern is dominant and which are deviations

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

### Data access patterns
Check if the project mixes:
- Direct SQL queries AND ORM calls
- `$wpdb` calls AND WP Query API
- Raw HTTP AND SDK calls

Mixed patterns in the same layer: **medium**

---

## Check 6: Separation of Concerns

**Multi-pass approach:**
1. DISCOVER: Search for SQL, business logic, and presentation mixed in the wrong layers
2. READ: Read the offending files to confirm the concern violation
3. ANALYZE: Assess the severity based on how tightly the concerns are intertwined

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

### Data fetching in presentation layer
- React components making direct API calls (should use hooks/services)
- PHP templates querying the database directly
- View files containing business calculations

### Severity: **medium**

---

## Check 7: Dependency Direction Violations

**Multi-pass approach:**
1. DISCOVER: Map the project's directory structure to identify architectural layers
2. READ: Read import statements to build a dependency map between layers
3. ANALYZE: Check if dependencies flow in the correct direction (outer layers depend on inner, not vice versa)

### Define layer hierarchy
Detect the project's layer structure:

**Typical WordPress project:**
```
Templates/Views → Controllers/Handlers → Services/Business Logic → Models/Data Access → Database
```

**Typical Node.js/Express project:**
```
Routes → Controllers → Services → Repositories → Database
```

**Typical React project:**
```
Pages → Components → Hooks → Services → API Client
```

### Check for violations
For each source file, determine its layer based on directory and filename:
- `routes/`, `controllers/`, `handlers/` → outer layer
- `services/`, `lib/`, `core/` → middle layer
- `models/`, `repositories/`, `data/` → inner layer
- `utils/`, `helpers/` → shared (can be imported by any layer)

Then check imports: inner layers importing from outer layers = violation.

Example violations:
- Model/repository importing a controller
- Service importing a route handler
- Utility importing business logic
- Database layer importing HTTP/request objects

### Severity
- Inner layer importing outer layer: **medium**, `important: true`
- Core business logic depending on framework-specific code: **high**
- Data layer depending on presentation layer: **high**

---

## Check 8: Feature Entanglement

**Multi-pass approach:**
1. DISCOVER: Identify feature boundaries (directories, modules, plugins)
2. READ: Check imports between feature modules
3. ANALYZE: Determine if features directly import from each other instead of going through a shared layer

### Identify features
Features are typically organized by:
- Directory: `features/auth/`, `features/billing/`, `features/orders/`
- Plugin: WordPress plugins are naturally separate features
- Module: `modules/user/`, `modules/product/`

### Cross-feature imports
For each feature directory, check if files import from other feature directories:
```
import.*from.*['"]\.\.\/.*(?:features|modules|plugins)\/(?!CURRENT_FEATURE)
```

### What's acceptable
- Importing from `shared/`, `common/`, `lib/`, `utils/` — fine
- Importing types/interfaces from other features — acceptable
- Importing implementations from other features — violation

### What's problematic
- Feature A directly calling Feature B's internal functions
- Feature A reading Feature B's database tables directly
- Feature A modifying Feature B's state

### Severity
- Direct cross-feature implementation import: **medium**
- Cross-feature database access: **high**
- Tight coupling between 3+ features: **high**, `important: true`

---

## Check 9: Configuration Sprawl

**Multi-pass approach:**
1. DISCOVER: Find all configuration files in the project
2. READ: Read config files to check for duplicate or conflicting settings
3. ANALYZE: Assess if configuration is scattered across too many locations

### Find config files
```bash
find PROJECT_ROOT -maxdepth 4 -type f \( -name '*.config.*' -o -name '.env*' -o -name '*.json' -o -name '*.yml' -o -name '*.yaml' -o -name '*.ini' -o -name '*.conf' -o -name 'settings.*' \) -not -path '*/node_modules/*' -not -path '*/vendor/*' -not -path '*/.git/*' 2>/dev/null
```

### Check for issues
1. **Duplicate settings**: Same setting defined in multiple config files with different values
2. **Conflicting environments**: `.env` and `config.php` both defining `DB_HOST` with different values
3. **Scattered config**: Configuration spread across >5 different config files/formats
4. **Missing environment separation**: Production settings in development config or vice versa

### Severity
- Conflicting settings across config files: **high**
- >10 config files at root level: **medium**
- Production credentials in development config: **high** (also a security issue)
- Config sprawl without clear hierarchy: **low**

---

## Check 10: API Surface Mapping

**Multi-pass approach:**
1. DISCOVER: Find all public API endpoints (REST routes, AJAX handlers, CLI commands)
2. READ: Read the endpoint handlers to understand what they do
3. ANALYZE: Check documentation coverage and consistency

### WordPress REST API
```
register_rest_route\s*\(
```

### WordPress AJAX
```
add_action\s*\(\s*['"]wp_ajax_
add_action\s*\(\s*['"]wp_ajax_nopriv_
```

### Express/Node.js
```
(?:app|router)\.(?:get|post|put|patch|delete|all)\s*\(
```

### Django
```
path\s*\(\s*['"]
url\s*\(\s*r?['"]
```

### Laravel
```
Route::(?:get|post|put|patch|delete|resource)\s*\(
```

### PHP Slim Framework
```
\$app->(?:get|post|put|patch|delete)\s*\(
```

### Analysis
For each discovered endpoint:
1. Is it documented somewhere? (README, API docs, OpenAPI spec)
2. Does it have authentication/authorization?
3. Does it have input validation?
4. Is the HTTP method appropriate for the operation?

### Severity
- Undocumented public API endpoint: **medium**
- API endpoint with no input validation: **high** (cross-reference with security domain)
- Inconsistent API naming patterns: **low**
- API endpoints >20 with no documentation at all: **medium**, `important: true`

---

## Check 11: State Management Audit

**Multi-pass approach:**
1. DISCOVER: Search for global state, singletons, and shared mutable state
2. READ: Read the state management code to understand scope and lifecycle
3. ANALYZE: Identify state that could cause race conditions, stale data, or testing difficulties

### Global state patterns

**PHP:**
```
\bglobal\s+\$
\bstatic\s+\$\w+\s*=
```

**JavaScript/TypeScript:**
```
\bwindow\.\w+\s*=
\bglobalThis\.\w+\s*=
\blet\s+\w+\s*=.*(?:export|module\.exports)
```
Module-level `let` that gets mutated = shared mutable state.

**WordPress globals:**
```
\bglobal\s+\$(?:wpdb|post|wp_query|current_user|pagenow)
```
WordPress globals are expected, but custom globals are not.

### Singleton patterns
```
(?:getInstance|get_instance|instance\s*\(\))\s*
```
Singletons are not inherently bad but make testing harder and hide dependencies.

### Shared mutable state
- Class properties modified by multiple methods without synchronization
- Static properties used as caches without invalidation
- Global arrays/objects used for inter-component communication

### Severity
- Custom global variables: **medium**
- Mutable module-level state: **medium**
- Static class properties used as shared cache: **low**
- Singleton pattern making testing difficult: **low**
- Race condition risk from shared mutable state: **high**

---

## Check 12: Migration Debt

**Multi-pass approach:**
1. DISCOVER: Find database migrations, their status, and any TODO/incomplete migrations
2. READ: Read recent migrations and migration configuration
3. ANALYZE: Check for pending migrations, rolled-back migrations, or migration-related TODOs

### Database migrations

**Phinx (PHP):**
```bash
vendor/bin/phinx status 2>/dev/null || ./bin/phinx status 2>/dev/null
```

**Laravel:**
```bash
php artisan migrate:status 2>/dev/null
```

**Django:**
```bash
python manage.py showmigrations 2>/dev/null
```

**Node (Knex/Sequelize/TypeORM):**
Check for migration directories and their status files.

### Check for issues
1. **Pending migrations**: Migrations that exist but haven't been run
2. **TODOs in migrations**: Search migration files for TODO/FIXME comments
3. **Rolled-back migrations**: Migrations that were rolled back and never re-applied
4. **Data migrations mixed with schema**: Migrations that modify data and schema in the same file
5. **Missing down/rollback**: Migrations without a corresponding rollback method

### Schema debt
Search for raw SQL that suggests missing migrations:
```
ALTER TABLE|CREATE TABLE|DROP TABLE|ADD COLUMN|DROP COLUMN
```
In non-migration files = schema changes outside the migration system.

### Severity
- Pending migrations not applied: **medium**
- TODOs in migration files: **low**
- Schema changes outside migration system: **medium**
- Migration without rollback method: **low**
- Data + schema in same migration: **low**

---

## Output Reminder

Return findings as JSON array. Use `"domain": "architecture"` and IDs like `architecture-001`. Categories: `god-file`, `churn-hotspot`, `circular-dependency`, `coupling`, `pattern-inconsistency`, `separation-of-concerns`, `dependency-direction`, `feature-entanglement`, `config-sprawl`, `api-surface`, `state-management`, `migration-debt`.
