# PHASE 3: ANALYZE

**Goal:** Определить архитектуру и паттерны проекта.

**Required state:** `state.detect.primary_language`, `state.detect.frameworks`, `state.detect.ast_available`

**Outputs:** `state.analyze`

---

## 3.1 Architecture Pattern Detection

| Pattern | Indicators | Confidence |
|---------|------------|------------|
| Clean Architecture | `internal/domain/`, `internal/usecase/`, `internal/infrastructure/`, ports/adapters | HIGH |
| Hexagonal | `domain/`, `application/`, `adapter/`, ports | HIGH |
| MVC | `models/`, `views/`, `controllers/` | HIGH |
| Layered | `service/`, `repository/`, `handler/` or `controller/` | MEDIUM |
| DDD | `domain/aggregate/`, `domain/entity/`, `domain/valueobject/` | HIGH |
| Microservices | Multiple `cmd/`, `services/`, separate go.mod per service | HIGH |
| Modular Monolith | `modules/`, `internal/<module>/` with clear boundaries | MEDIUM |
| Standard Go | `cmd/`, `internal/`, `pkg/` (no specific pattern) | LOW |

### Detection: Directory structure + AST evidence

**Step 1 — Directory structure (baseline):**
```bash
# Clean Architecture
[ -d "internal/domain" ] && [ -d "internal/usecase" ] && [ -d "internal/infrastructure" ] && echo "Clean Architecture"

# Hexagonal
[ -d "domain" ] && [ -d "application" ] && [ -d "adapter" ] && echo "Hexagonal"

# MVC
[ -d "models" ] && [ -d "views" ] && [ -d "controllers" ] && echo "MVC"

# DDD
[ -d "domain/entity" ] || [ -d "domain/aggregate" ] && echo "DDD"

# Microservices
find . -name "go.mod" | wc -l  # More than 1 = likely microservices
ls cmd/ 2>/dev/null | wc -l    # Multiple binaries
```

**Step 2 — AST evidence (повышает confidence):**
```bash
if $AST_AVAILABLE; then
    # Clean Architecture evidence: interfaces в domain/, реализации в infrastructure/
    domain_interfaces=$(ast-grep --pattern 'type $NAME interface { $$$ }' --lang go internal/domain/ 2>/dev/null | wc -l)
    infra_implementations=$(ast-grep --pattern 'func ($R $TYPE) $METHOD($$$) $$$' --lang go internal/infrastructure/ 2>/dev/null | wc -l)

    # Ports: интерфейсы в port/ или ports/
    port_interfaces=$(ast-grep --pattern 'type $NAME interface { $$$ }' --lang go internal/port/ internal/ports/ 2>/dev/null | wc -l)

    # DDD evidence: aggregate roots с методами
    aggregate_structs=$(ast-grep --pattern 'type $NAME struct { $$$ }' --lang go internal/domain/aggregate/ domain/aggregate/ 2>/dev/null | wc -l)

    # Evidence-based confidence:
    # directory match + interfaces in domain + implementations in infra = HIGH
    # directory match only = MEDIUM
    # directory partial match = LOW
fi
```

**Architecture evidence записывается в state:**
```yaml
architecture_evidence:
  - indicator: "internal/domain/ directory exists"
    weight: 0.3
  - indicator: "12 interfaces in internal/domain/"
    weight: 0.3
  - indicator: "Implementations in internal/infrastructure/ match domain interfaces"
    weight: 0.3
  - indicator: "No domain → infrastructure imports"
    weight: 0.1
```

---

## 3.2 Layer Analysis

Для каждого обнаруженного слоя — AST-first анализ:

```bash
if $AST_AVAILABLE; then
    # Count interfaces per layer
    for layer_dir in internal/*/; do
        layer_name=$(basename "$layer_dir")
        iface_count=$(ast-grep --pattern 'type $NAME interface { $$$ }' --lang go "$layer_dir" 2>/dev/null | wc -l)
        struct_count=$(ast-grep --pattern 'type $NAME struct { $$$ }' --lang go "$layer_dir" 2>/dev/null | wc -l)
        echo "$layer_name: interfaces=$iface_count, structs=$struct_count"
    done

    # Find all packages in layer
    find internal/{layer} -type d -maxdepth 2
else
    # Grep fallback
    for layer_dir in internal/*/; do
        layer_name=$(basename "$layer_dir")
        iface_count=$(grep -r "type [A-Z][a-zA-Z]* interface {" "$layer_dir" --include="*.go" 2>/dev/null | wc -l)
        struct_count=$(grep -r "type [A-Z][a-zA-Z]* struct {" "$layer_dir" --include="*.go" 2>/dev/null | wc -l)
        echo "$layer_name: interfaces=$iface_count, structs=$struct_count"
    done
fi
```

**Output per layer → `state.analyze.layers[]`:**
```yaml
layers:
  - name: "domain"
    path: "internal/domain"
    packages: ["entity", "valueobject", "repository"]
    interface_count: 12
    struct_count: 8
    external_deps: []  # clean
  - name: "usecase"
    path: "internal/usecase"
    packages: ["order", "user", "payment"]
    interface_count: 3
    struct_count: 6
    external_deps: []
  - name: "infrastructure"
    path: "internal/infrastructure"
    packages: ["postgres", "redis", "http"]
    interface_count: 0
    struct_count: 15
    external_deps: ["pgx", "go-redis"]
```

---

## 3.3 Dependency Flow Analysis (AST-enhanced)

```
Правило: Зависимости должны указывать внутрь (к domain).

{layer_1}      ← {layer_2}      ← {layer_3}
               ← {interfaces}   ← cmd

Нарушение: {layer_1} → {layer_3} (VIOLATION)
```

### AST-based import analysis:

```bash
if $AST_AVAILABLE; then
    # Извлечь все imports из каждого слоя
    for layer_dir in internal/*/; do
        layer_name=$(basename "$layer_dir")
        # AST: найти все import блоки
        ast-grep --pattern 'import ($$$)' --lang go "$layer_dir" 2>/dev/null
    done

    # Проверить нарушения: domain не должен импортировать infrastructure
    domain_imports=$(ast-grep --pattern 'import ($$$)' --lang go internal/domain/ 2>/dev/null)
    # Проверить наличие "internal/infrastructure" или "internal/usecase" в domain imports
else
    # Grep fallback
    grep -r "import" internal/domain/ --include="*.go" | grep "infrastructure"  # Should be 0
    grep -r "import" internal/domain/ --include="*.go" | grep "usecase"         # Should be 0
fi
```

**Violations записываются в state:**
```yaml
violations:
  - from_layer: "domain"
    to_layer: "infrastructure"
    file: "internal/domain/service/order.go"
    import_path: "internal/infrastructure/postgres"
```

---

## 3.4 Convention Discovery

### Naming patterns

```bash
if $AST_AVAILABLE; then
    # Function naming — AST точнее, видит только объявления
    ast-grep --pattern 'func $NAME($$$) $$$' --lang go | head -30

    # Type naming
    ast-grep --pattern 'type $NAME struct { $$$ }' --lang go | head -20
    ast-grep --pattern 'type $NAME interface { $$$ }' --lang go | head -20
else
    # Grep fallback
    grep -roh "func [A-Z][a-zA-Z]*" --include="*.go" | sort | uniq -c | sort -rn | head -20
    grep -roh "type [A-Z][a-zA-Z]*" --include="*.go" | sort | uniq -c | sort -rn | head -20
fi

# File naming (одинаково для AST и grep)
find . -name "*.go" -not -name "*_test.go" -not -path "*/vendor/*" | sed 's/.*\///' | sort | uniq -c | sort -rn | head -20
```

### Error handling (AST-enhanced)

```bash
if $AST_AVAILABLE; then
    # Error wrapping style
    errorf_wrap=$(ast-grep --pattern 'fmt.Errorf($FMT, $$$)' --lang go | wc -l)
    errors_new=$(ast-grep --pattern 'errors.New($MSG)' --lang go | wc -l)

    # Custom error types
    custom_errors=$(ast-grep --pattern 'func ($R $TYPE) Error() string { $$$ }' --lang go)

    # Sentinel errors
    sentinel_errors=$(ast-grep --pattern 'var $NAME = errors.New($MSG)' --lang go)
else
    errorf_wrap=$(grep -r 'fmt.Errorf.*%w' --include="*.go" 2>/dev/null | wc -l)
    errors_new=$(grep -r 'errors.New' --include="*.go" 2>/dev/null | wc -l)
    custom_errors=$(grep -r 'type.*Error struct' --include="*.go" 2>/dev/null)
fi
```

### Logging patterns

```bash
if $AST_AVAILABLE; then
    slog_count=$(ast-grep --pattern 'slog.$METHOD($$$)' --lang go | wc -l)
    zap_count=$(ast-grep --pattern 'zap.$METHOD($$$)' --lang go | wc -l)
    logrus_count=$(ast-grep --pattern 'logrus.$METHOD($$$)' --lang go | wc -l)
else
    slog_count=$(grep -r 'slog\.' --include="*.go" 2>/dev/null | wc -l)
    zap_count=$(grep -r 'zap\.' --include="*.go" 2>/dev/null | wc -l)
    logrus_count=$(grep -r 'logrus\.' --include="*.go" 2>/dev/null | wc -l)
fi

# Determine primary logger
# max(slog_count, zap_count, logrus_count) → primary
```

### Testing patterns (from state.detect)

Testing patterns уже собраны в Phase 2. Здесь уточняем стиль:

```bash
if $AST_AVAILABLE; then
    # Subtests
    subtest_count=$(ast-grep --pattern 't.Run($NAME, func(t *testing.T) { $$$ })' --lang go | wc -l)

    # Test helpers
    helper_count=$(ast-grep --pattern 't.Helper()' --lang go | wc -l)
fi
```

---

## State Output → `state.analyze`

```yaml
analyze:
  architecture: "clean"
  architecture_confidence: 0.88
  architecture_evidence:
    - indicator: "internal/domain/ exists with 12 interfaces"
      weight: 0.3
    - indicator: "internal/usecase/ exists with service implementations"
      weight: 0.3
    - indicator: "internal/infrastructure/ implements domain interfaces"
      weight: 0.2
    - indicator: "No dependency violations detected"
      weight: 0.1
  layers:
    - name: "domain"
      path: "internal/domain"
      packages: ["entity", "valueobject", "repository"]
      interface_count: 12
      struct_count: 8
      external_deps: []
    - name: "usecase"
      path: "internal/usecase"
      packages: ["order", "user", "payment"]
      interface_count: 3
      struct_count: 6
      external_deps: []
    - name: "infrastructure"
      path: "internal/infrastructure"
      packages: ["postgres", "redis", "http"]
      interface_count: 0
      struct_count: 15
      external_deps: ["pgx", "go-redis"]
  violations: []
  conventions:
    naming:
      files: "snake_case"
      types: "PascalCase"
      functions: "PascalCase exported, camelCase internal"
    errors:
      pattern: "fmt.Errorf %w"
      custom_error_types: ["NotFoundError", "ValidationError"]
    logging:
      library: "slog"
      structured: true
    testing:
      style: "table-driven"
      framework: "testify"
      mock_strategy: "mockery"
```

## Output

```
[PHASE 3/10] ANALYZE — DONE
State: analyze.architecture=clean (0.88), layers=3, violations=0
- Conventions: snake_case files, fmt.Errorf %w, slog, table-driven tests
- Evidence: 12 domain interfaces, 0 violations, AST-confirmed
```
