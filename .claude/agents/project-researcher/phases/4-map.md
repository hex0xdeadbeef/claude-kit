# PHASE 4: MAP

**Goal:** Построить карту критических путей и абстракций.

---

## 4.1 Entry Points

```bash
# Main packages
find . -name "main.go" -exec dirname {} \;

# CLI commands
grep -r "cobra\|urfave/cli\|flag\." --include="*.go" -l

# HTTP handlers
grep -r "func.*http\.\|{http_framework}\." --include="*.go" -l

# gRPC services
find . -name "*.proto" -exec grep "service " {} \;
```

**Output format:**
```markdown
### Entry Points

| Type | Location | Description |
|------|----------|-------------|
| CLI | cmd/{app}/main.go | Main application entry |
| HTTP | internal/{layer}/router.go | API router |
| gRPC | internal/{layer}/server.go | gRPC server |
| Worker | cmd/{worker}/main.go | Background job processor |
```

---

## 4.2 Core Domain

```bash
# Find entities/aggregates
find . -path "*/{core_layer}/*" -name "*.go" -not -name "*_test.go"

# Find core interfaces
grep -r "type.*interface" */{core_layer}/* */{interfaces_layer}/* 2>/dev/null
```

**Output format:**
```markdown
### Core Domain

| Entity | Location | Description |
|--------|----------|-------------|
| {Entity1} | internal/{layer}/entity/{entity1}.go | {Entity1} aggregate root |
| {Entity2} | internal/{layer}/entity/{entity2}.go | {Entity2} entity |
| {Entity3} | internal/{layer}/entity/{entity3}.go | {Entity3} value object |

### Key Interfaces

| Interface | Location | Implementations |
|-----------|----------|-----------------|
| {Entity1}Repository | internal/{layer}/{interfaces}/{entity1}.go | {db_impl}/{entity1}.go |
| {Entity2}Service | internal/{layer}/{interfaces}/{entity2}.go | {app_layer}/{entity2}/service.go |
```

---

## 4.3 Key Abstractions

```bash
# Find all interfaces
grep -r "type.*interface {" --include="*.go" -A 5

# Find patterns
grep -r "Factory\|Builder\|Strategy\|Observer" --include="*.go"

# Find DI containers
grep -r "wire\|dig\|fx\|inject" go.mod 2>/dev/null
```

---

## 4.4 External Integrations

```bash
# From go.mod/imports
grep -E "github.com|gitlab.com" go.mod | grep -v "internal\|{org_name}"

# Categorize
# - Database: {db_driver}, mysql, mongodb, redis
# - HTTP clients: resty, fasthttp
# - Message queues: kafka, rabbitmq, nats
# - Cloud: aws-sdk, azure, gcp
```

**Output format:**
```markdown
### External Integrations

| Type | Package | Usage |
|------|---------|-------|
| Database | {db_driver} | {database} client |
| Cache | {cache_driver} | {cache} client |
| Queue | {queue_driver} | {queue_system} producer/consumer |
| HTTP | {http_client} | External API calls |
```

---

## Output

```
[PHASE 4/6] MAP -- DONE
- Entry points: 3 (CLI, HTTP, Worker)
- Domain entities: 5
- Key interfaces: 8
- External integrations: 6
```

---

# PHASE 4.5: DATABASE ANALYSIS (optional)

**Goal:** Анализ схемы PostgreSQL через MCP для полного понимания data model.

**Condition:** Выполняется только если:
- Обнаружен PostgreSQL (`{db_driver}` в go.mod или `psycopg2`/`asyncpg` в requirements.txt)
- MCP postgres server доступен
- Есть `migrations/` директория

---

## 4.5.1 Check Database Availability

```bash
# Check if postgres MCP is configured
if mcp__postgres__list_tables works; then
    DB_AVAILABLE=true
else
    DB_AVAILABLE=false
    echo "[PHASE 4.5/6] DATABASE ANALYSIS -- SKIPPED (no DB connection)"
fi
```

---

## 4.5.2 Schema Discovery

```
# List all tables
mcp__postgres__list_tables

# For each table, get structure
for table in $TABLES; do
    mcp__postgres__describe_table(table)
done
```

---

## 4.5.3 Schema Analysis

**Collect:**
- Table names and column types
- Primary keys and foreign keys
- Indexes
- Constraints

**Compare with:**
- Domain entities (internal/{core_layer}/entity/*.go)
- Migration files (migrations/*.sql)
- Code generation output files (if codegen tool detected)

---

## 4.5.4 Entity-Table Mapping

```markdown
### Database Schema

| Table | Columns | PK | FKs | Domain Entity |
|-------|---------|----|----|---------------|
| {table_1} | 4 | id | 0 | entity.{Entity1} |
| {table_2} | 10 | id | 1 ({fk_col}) | entity.{Entity2} |
| {table_3} | 8 | id | 0 | entity.{Entity3} |
| {table_4} | 12 | id | 2 | entity.{Entity4} |
| {table_5} | 8 | id | 2 | entity.{Entity5} |

### Data Statistics (sample)

| Table | Row Count | Last Updated |
|-------|-----------|--------------|
| {table_1} | 5 | 2024-01-10 |
| {table_2} | 12 | 2024-01-10 |
```

---

## 4.5.5 Schema-Entity Alignment Check

```bash
# For each table:
# 1. Get columns from DB: mcp__postgres__describe_table
# 2. Get fields from entity: grep struct fields
# 3. Compare and report mismatches

ALIGNMENT_ISSUES=()

for table in $TABLES; do
    DB_COLUMNS=$(mcp__postgres__describe_table $table)
    ENTITY_FIELDS=$(grep -A 50 "type ${Table} struct" internal/{core_layer}/entity/*.go)

    # Compare and find mismatches
    # Add to ALIGNMENT_ISSUES if found
done
```

---

## Output

```
[PHASE 4.5/6] DATABASE ANALYSIS -- DONE
- Tables found: 5
- Total columns: 42
- Foreign keys: 6
- Entity alignment: 5/5 ALIGNED
- Schema documented in PROJECT-KNOWLEDGE.md
```

**Skip message (if no DB):**
```
[PHASE 4.5/6] DATABASE ANALYSIS -- SKIPPED (no postgres MCP or DB unavailable)
```
