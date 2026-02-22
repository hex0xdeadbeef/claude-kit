# PHASE 3: ANALYZE

**Goal:** Определить архитектуру и паттерны проекта.

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

**Detection algorithm:**
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

---

## 3.2 Layer Analysis

Для каждого обнаруженного слоя:

```bash
# Найти все пакеты в слое
find internal/{layer} -type d -maxdepth 2

# Найти интерфейсы
grep -r "type.*interface" internal/{layer}/

# Найти зависимости
grep -r "import" internal/{layer2}/ | grep -v "internal/{layer1}"
```

**Output per layer:**
```markdown
### Layer: {layer_1}
- Packages: {sublayer_1}, {sublayer_2}, {sublayer_3}
- Entities: {Entity1}, {Entity2}, {Entity3}
- Interfaces: {Entity1}Repository, {Entity2}Repository
- External deps: NONE (clean)

### Layer: {layer_2}
- Packages: {entity_1}, {entity_2}, {entity_3}
- Uses: {layer_1}/{sublayer_1}, {layer_1}/{sublayer_2}
- Defines: {layer}/service interfaces
- External deps: NONE

### Layer: {layer_3}
- Packages: {db_impl}, {cache_impl}, {http_impl}
- Implements: {layer_1}/repository, {layer}/service
- External deps: {db_driver}, {cache_driver}, {http_framework}
```

---

## 3.3 Dependency Flow Analysis

```
Правило: Зависимости должны указывать внутрь (к domain).

{layer_1}      ← {layer_2}      ← {layer_3}
               ← {interfaces}   ← cmd

Нарушение: {layer_1} → {layer_3} (VIOLATION)
```

**Detection:**
```bash
# Найти нарушения dependency rule
grep -r "import" internal/{core_layer}/ | grep "{infra_layer}"  # Должно быть 0
grep -r "import" internal/{core_layer}/ | grep "{app_layer}"    # Должно быть 0
```

---

## 3.4 Convention Discovery

### Naming patterns

```bash
# Function naming
grep -roh "func [A-Z][a-zA-Z]*" --include="*.go" | sort | uniq -c | sort -rn | head -20

# Type naming
grep -roh "type [A-Z][a-zA-Z]*" --include="*.go" | sort | uniq -c | sort -rn | head -20

# File naming
find . -name "*.go" -not -name "*_test.go" | sed 's/.*\///' | sort | uniq -c | sort -rn | head -20
```

### Testing patterns

```bash
# Table-driven tests
grep -r "tests := \[\]struct" --include="*_test.go" | wc -l

# Testify usage
grep -r "require\." --include="*_test.go" | wc -l
grep -r "assert\." --include="*_test.go" | wc -l

# Mocks
find . -name "*mock*.go" | wc -l
```

### Error handling

```bash
# Error wrapping
grep -r 'fmt.Errorf.*%w' --include="*.go" | wc -l

# Custom errors
grep -r 'errors.New' --include="*.go" | wc -l

# Error types
grep -r 'type.*Error struct' --include="*.go"
```

### Logging patterns

```bash
# slog
grep -r 'slog\.' --include="*.go" | wc -l

# logrus
grep -r 'logrus\.' --include="*.go" | wc -l

# zap
grep -r 'zap\.' --include="*.go" | wc -l
```

---

## Output

```
[PHASE 3/6] ANALYZE -- DONE
- Architecture: Clean Architecture (HIGH confidence)
- Layers: {layer_1}, {layer_2}, {layer_3}, cmd
- Dependency violations: 0
- Naming: snake_case files, PascalCase types, camelCase funcs
- Testing: Table-driven (85%), {test_framework} (require)
- Errors: fmt.Errorf %w pattern
- Logging: {logger} (structured)
```
