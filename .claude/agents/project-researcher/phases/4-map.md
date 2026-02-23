# PHASE 4: MAP

**Goal:** Построить карту критических путей, абстракций и граф зависимостей.

**Required state:** `state.analyze.architecture`, `state.analyze.layers`, `state.detect.ast_available`

**Outputs:** `state.map`

**SEE:** `deps/state-contract.md` для полной схемы state, `deps/ast-analysis.md` для каталога AST-паттернов.

---

## 4.1 Entry Points

### AST-first detection:

```bash
if $AST_AVAILABLE; then
    # Main packages
    ast-grep --pattern 'func main() { $$$ }' --lang go

    # HTTP handlers (по сигнатуре)
    ast-grep --pattern 'func $NAME(w http.ResponseWriter, r *http.Request) { $$$ }' --lang go
    ast-grep --pattern 'func $NAME(c $CTX) $$$' --lang go  # framework-specific

    # gRPC service implementations
    ast-grep --pattern 'func ($S $SERVER) $METHOD(ctx context.Context, $$$) ($$$, error) { $$$ }' --lang go

    # CLI commands (cobra)
    ast-grep --pattern 'cobra.Command{ $$$ }' --lang go

    # Workers / background jobs
    ast-grep --pattern 'func ($W $WORKER) Run($$$) $$$' --lang go
    ast-grep --pattern 'func ($W $WORKER) Start($$$) $$$' --lang go
else
    # Fallback
    find . -name "main.go" -exec dirname {} \;
    grep -r "cobra\|urfave/cli\|flag\." --include="*.go" -l
    grep -r "func.*http\." --include="*.go" -l
    find . -name "*.proto" -exec grep "service " {} \;
fi
```

**Output → `state.map.entry_points`:**
```yaml
entry_points:
  - type: "cli"
    path: "cmd/api/main.go"
    description: "Main API server"
    framework: "chi"
  - type: "http"
    path: "internal/transport/http/router.go"
    description: "API router with 25 endpoints"
    framework: "chi"
  - type: "worker"
    path: "cmd/worker/main.go"
    description: "Background job processor"
    framework: ""
```

---

## 4.2 Core Domain

### AST-first entity/interface discovery:

```bash
if $AST_AVAILABLE; then
    # Find entities/aggregates in domain layer
    for layer in $(echo "${state.analyze.layers}" | grep "domain"); do
        # Structs = potential entities
        ast-grep --pattern 'type $NAME struct { $$$ }' --lang go "$layer/"

        # Interfaces = ports/repositories
        ast-grep --pattern 'type $NAME interface { $$$ }' --lang go "$layer/"
    done

    # Find implementations (compile-time checks)
    ast-grep --pattern 'var _ $IFACE = (*$IMPL)(nil)' --lang go
    ast-grep --pattern 'var _ $IFACE = &$IMPL{}' --lang go
else
    # Grep fallback
    find . -path "*domain*" -name "*.go" -not -name "*_test.go"
    grep -r "type.*interface" *domain* *port* 2>/dev/null
fi
```

**Output → `state.map.core_domain`:**
```yaml
core_domain:
  entities:
    - name: "Order"
      path: "internal/domain/entity/order.go"
      type: "aggregate_root"
      key_fields: ["ID", "UserID", "Status", "Items", "CreatedAt"]
    - name: "OrderItem"
      path: "internal/domain/entity/order_item.go"
      type: "entity"
      key_fields: ["ID", "ProductID", "Quantity", "Price"]
    - name: "Money"
      path: "internal/domain/valueobject/money.go"
      type: "value_object"
      key_fields: ["Amount", "Currency"]
  interfaces:
    - name: "OrderRepository"
      path: "internal/domain/repository/order.go"
      methods: ["Create", "GetByID", "Update", "List"]
      implementations: ["internal/infrastructure/postgres/order_repo.go"]
    - name: "OrderService"
      path: "internal/domain/service/order.go"
      methods: ["CreateOrder", "CancelOrder", "GetOrder"]
      implementations: ["internal/usecase/order/service.go"]
```

---

## 4.3 Key Abstractions & Design Patterns

```bash
if $AST_AVAILABLE; then
    # Constructor pattern (New*)
    ast-grep --pattern 'func New$NAME($$$) $$$' --lang go

    # Factory pattern
    ast-grep --pattern 'func ($F $FACTORY) Create($$$) $$$' --lang go

    # Builder pattern
    ast-grep --pattern 'func ($B $BUILDER) Build() $$$' --lang go

    # Strategy/Handler pattern
    ast-grep --pattern 'type $NAME interface {
        Handle($$$) $$$
    }' --lang go

    # Middleware
    ast-grep --pattern 'func $NAME(next http.Handler) http.Handler { $$$ }' --lang go

    # DI containers
    grep -E "wire|dig|fx|inject" go.mod 2>/dev/null
else
    grep -r "Factory\|Builder\|Strategy\|Observer" --include="*.go"
    grep -r "wire\|dig\|fx\|inject" go.mod 2>/dev/null
fi
```

**Output → `state.map.design_patterns`:**
```yaml
design_patterns:
  - pattern: "Repository"
    location: "internal/domain/repository/"
    usage: "Data access abstraction"
  - pattern: "Factory"
    location: "internal/infrastructure/postgres/"
    usage: "Connection pool creation"
  - pattern: "Middleware"
    location: "internal/transport/http/middleware/"
    usage: "Auth, logging, recovery"
```

---

## 4.4 External Integrations

```bash
# From go.mod — categorize external dependencies
if [ -f "go.mod" ]; then
    # Database drivers
    grep -E "pgx|mysql|mongodb|sqlite" go.mod

    # Cache
    grep -E "redis|memcache" go.mod

    # Message queues
    grep -E "kafka|rabbitmq|nats" go.mod

    # HTTP clients
    grep -E "resty|fasthttp" go.mod

    # Cloud SDKs
    grep -E "aws-sdk|azure|cloud.google" go.mod

    # Observability
    grep -E "prometheus|opentelemetry|datadog" go.mod
fi
```

**Output → `state.map.external_integrations`:**
```yaml
external_integrations:
  - type: "database"
    name: "PostgreSQL"
    driver: "pgx"
    config_location: "internal/infrastructure/postgres/connection.go"
  - type: "cache"
    name: "Redis"
    driver: "go-redis"
    config_location: "internal/infrastructure/redis/client.go"
```

---

## 4.5 DEPENDENCY GRAPH (NEW)

**Goal:** Построить directed dependency graph между пакетами проекта. Извлечь метрики: fan-in/fan-out, hub-пакеты, циклические зависимости.

### 4.5.1 Build Graph

**Go projects:**
```bash
# Лучший метод — go list
if command -v go &>/dev/null && [ -f "go.mod" ]; then
    # Получить все пакеты и их imports
    go list -json ./... 2>/dev/null | jq -r '[.ImportPath, (.Imports // [] | join(","))] | @tsv'

    # Или более детальный вывод
    go list -json ./... 2>/dev/null | jq '{
        package: .ImportPath,
        imports: [(.Imports // [])[] | select(startswith("'"$(head -1 go.mod | awk '{print $2}')"'"))]
    }'
fi
```

**AST fallback (если go list недоступен):**
```bash
if $AST_AVAILABLE; then
    # Для каждого .go файла извлечь imports
    for gofile in $(find . -name "*.go" -not -path "*/vendor/*" -not -name "*_test.go"); do
        dir=$(dirname "$gofile")
        ast-grep --pattern 'import ($$$)' --lang go "$gofile"
    done
fi
```

**Grep fallback (последний resort):**
```bash
# Извлечь internal imports из каждого пакета
ROOT_MODULE=$(head -1 go.mod | awk '{print $2}')
for pkg_dir in $(find . -type d -not -path "*/vendor/*" -not -path "*/.git/*"); do
    imports=$(grep -r "\"$ROOT_MODULE" "$pkg_dir"/*.go 2>/dev/null | grep -o "\"$ROOT_MODULE[^\"]*\"" | sort -u)
    if [ -n "$imports" ]; then
        echo "$pkg_dir → $imports"
    fi
done
```

### 4.5.2 Compute Metrics

```bash
# Fan-in: сколько пакетов импортируют данный пакет
# Fan-out: сколько пакетов импортирует данный пакет

# Из graph data вычислить:
for package in $ALL_PACKAGES; do
    fan_in=$(grep -c "→.*$package" graph_data)   # кто импортирует меня
    fan_out=$(grep -c "$package →" graph_data)    # кого я импортирую
    echo "$package: fan_in=$fan_in, fan_out=$fan_out"
done

# Hub packages: top 5 by fan_in
sort -t= -k2 -rn fan_metrics | head -5

# God packages: high fan_out (>10 imports)
awk -F= '$3 > 10' fan_metrics

# Isolated packages: fan_in == 0 (кроме cmd/)
awk -F= '$2 == 0' fan_metrics | grep -v "cmd/"
```

### 4.5.3 Detect Circular Dependencies

```bash
# Go: встроенная проверка
go vet ./... 2>&1 | grep "import cycle"

# Или программно: найти пути A→B→...→A в графе
# Простая эвристика: для каждого пакета проверить, импортирует ли он (транзитивно) сам себя
```

### 4.5.4 Graph Visualization (ASCII)

```
Dependency Depth Map:

Level 0 (core):     internal/domain/
Level 1 (app):      internal/usecase/
Level 2 (ports):    internal/port/
Level 3 (adapters): internal/infrastructure/, internal/transport/
Level 4 (entry):    cmd/

Hub packages (highest fan-in):
  internal/domain/entity     ← 15 packages depend on this
  internal/domain/repository ← 12 packages
  pkg/errors                 ← 8 packages

God packages (high fan-out):
  cmd/api/main.go            → imports 11 packages
  internal/infrastructure/di → imports 9 packages
```

### State Output → `state.map.dependency_graph`

```yaml
dependency_graph:
  total_packages: 34
  max_depth: 4
  hub_packages:
    - package: "internal/domain/entity"
      fan_in: 15
      fan_out: 1
    - package: "internal/domain/repository"
      fan_in: 12
      fan_out: 2
    - package: "pkg/errors"
      fan_in: 8
      fan_out: 0
  god_packages:
    - package: "cmd/api"
      fan_in: 0
      fan_out: 11
    - package: "internal/infrastructure/di"
      fan_in: 1
      fan_out: 9
  circular_deps: []  # or [["pkg/a", "pkg/b", "pkg/a"]]
  isolated_packages: ["internal/tools/migration"]
  depth_map:
    0: ["internal/domain/"]
    1: ["internal/usecase/"]
    2: ["internal/port/"]
    3: ["internal/infrastructure/", "internal/transport/"]
    4: ["cmd/"]
```

---

## 4.6 DATABASE ANALYSIS (optional)

**Condition:** Выполняется только если:
- Обнаружен PostgreSQL (`pgx` в go.mod или `psycopg2`/`asyncpg` в requirements.txt)
- MCP postgres server доступен
- Есть `migrations/` директория

### 4.6.1 Check Database Availability

```bash
if mcp__postgres__list_tables works; then
    DB_AVAILABLE=true
else
    DB_AVAILABLE=false
    echo "[PHASE 4.6/10] DATABASE ANALYSIS — SKIPPED (no DB connection)"
fi
```

### 4.6.2 Schema Discovery

```
mcp__postgres__list_tables

for table in $TABLES; do
    mcp__postgres__describe_table(table)
done
```

### 4.6.3 Entity-Table Mapping

```bash
# Map DB tables to domain entities
for table in $TABLES; do
    # Find matching entity struct
    if $AST_AVAILABLE; then
        entity=$(ast-grep --pattern "type $TABLE struct { \$\$\$ }" --lang go internal/domain/)
    else
        entity=$(grep -r "type.*${table}.*struct" --include="*.go" internal/domain/)
    fi
    echo "$table → $entity"
done
```

### 4.6.4 Schema-Entity Alignment Check

| Table | Domain Entity | Status |
|-------|---------------|--------|
| `orders` | `entity.Order` | ALIGNED |
| `order_items` | `entity.OrderItem` | ALIGNED |
| `audit_log` | (none) | UNMAPPED |

### State Output → `state.database`

```yaml
database:
  available: true
  tables:
    - name: "orders"
      columns: 10
      primary_key: "id"
      foreign_keys: ["user_id"]
      domain_entity: "Order"
      alignment: "aligned"
  alignment_issues: []
  statistics:
    total_tables: 12
    total_columns: 85
    total_foreign_keys: 15
    alignment_rate: 0.92
```

---

## Output

```
[PHASE 4/10] MAP — DONE
State: map.entry_points=3, entities=5, interfaces=8, integrations=6
- Dependency graph: 34 packages, depth=4, hubs=[domain/entity, domain/repository]
- Circular deps: none
- Isolated: [tools/migration]

[PHASE 4.6/10] DATABASE — DONE
State: database.tables=12, alignment=92%
```
