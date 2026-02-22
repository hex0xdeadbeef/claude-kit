# Inter-Phase State Contract

**Purpose:** Typed state object, передаваемый между фазами. Каждая фаза читает input из предыдущих секций и записывает свою секцию.

**Principle:** Формальный контракт данных устраняет хрупкую передачу через markdown и позволяет программную валидацию.

**Load when:** Начало каждой фазы — для проверки required fields от предыдущих фаз.

---

## STATE SCHEMA

Стейт — виртуальный YAML-объект, который агент поддерживает в памяти на протяжении всего выполнения. Каждая фаза обязана:
1. Проверить наличие required fields из предыдущих фаз
2. Заполнить свою секцию полностью
3. Вывести compact summary (не весь стейт)

---

### Phase 1: VALIDATE → `state.validate`

```yaml
validate:
  path: string              # REQUIRED — абсолютный путь к проекту
  mode: "CREATE" | "AUGMENT" | "UPDATE"  # REQUIRED
  git: bool                 # REQUIRED
  has_claude_dir: bool      # REQUIRED
  source_file_count: int    # REQUIRED — количество исходных файлов
  existing_artifacts:       # REQUIRED if mode != CREATE
    claude_md: bool
    skills: string[]        # имена существующих skills
    rules: string[]         # имена существующих rules
    commands: string[]
  git_analysis:             # REQUIRED if mode == UPDATE
    commits_since: int
    files_changed: int
    changed_layers: string[]
    update_scope: string[]
```

**FATAL if:** `path` не существует, `source_file_count == 0`

---

### Phase 1.5: DISCOVER → `state.discover`

```yaml
discover:
  is_monorepo: bool         # REQUIRED
  modules:                  # REQUIRED if is_monorepo
    - path: string          # относительный путь к модулю
      language: string      # primary language модуля
      type: "service" | "library" | "app" | "shared" | "tool"
      manifest: string      # go.mod | package.json | Cargo.toml | pom.xml
      depends_on: string[]  # пути к другим модулям (internal deps)
  strategy: "single" | "per-module" | "per-module-with-shared-context"
  root_module: string       # путь к "главному" модулю (если определён)
  analysis_targets: string[] # REQUIRED — список путей для анализа в следующих фазах
```

**Логика:** Если `is_monorepo == false`, то `analysis_targets = [state.validate.path]`.

---

### Phase 2: DETECT → `state.detect`

```yaml
detect:
  primary_language: string   # REQUIRED — "go" | "python" | "typescript" | "rust" | "java" | ...
  primary_confidence: float  # REQUIRED — 0.0-1.0
  secondary_languages:       # optional
    - language: string
      file_count: int
      role: string           # "frontend" | "scripts" | "tools" | "tests"
  frameworks:                # REQUIRED — хотя бы []
    - name: string           # "chi" | "gin" | "echo" | ...
      version: string        # "v5.1.0"
      category: "http" | "orm" | "grpc" | "cli" | "testing" | "logging" | "di"
      confidence: float
      detection_method: "manifest" | "import" | "ast"  # как обнаружено
  build_tools:               # REQUIRED
    - name: string           # "make" | "docker" | "github-actions"
      config_file: string    # "Makefile" | "Dockerfile"
  test_framework: string     # "testify" | "standard" | "gomock" | ...
  test_patterns:
    table_driven_count: int
    mock_count: int
    test_file_count: int
  linters: string[]          # ["golangci-lint", "prettier"]
  ast_available: bool        # REQUIRED — доступен ли ast-grep
```

**FATAL if:** `primary_language` не определён, `primary_confidence < 0.3`

---

### Phase 3: ANALYZE → `state.analyze`

```yaml
analyze:
  architecture: string       # REQUIRED — "clean" | "hexagonal" | "mvc" | "layered" | "ddd" | ...
  architecture_confidence: float  # REQUIRED
  architecture_evidence:     # REQUIRED — что именно подтверждает паттерн
    - indicator: string      # "internal/domain/ exists"
      weight: float          # 0.0-1.0
  layers:                    # REQUIRED
    - name: string           # "domain" | "usecase" | "infrastructure" | ...
      path: string           # "internal/domain"
      packages: string[]     # ["entity", "valueobject", "repository"]
      interface_count: int
      struct_count: int
      external_deps: string[] # пакеты вне проекта (нарушения?)
  violations:                # dependency rule violations
    - from_layer: string
      to_layer: string
      file: string
      import_path: string
  conventions:
    naming:
      files: string          # "snake_case" | "camelCase" | "kebab-case"
      types: string          # "PascalCase"
      functions: string      # "camelCase" | "PascalCase"
    errors:
      pattern: string        # "fmt.Errorf %w" | "errors.New" | "custom types"
      custom_error_types: string[]
    logging:
      library: string        # "slog" | "zap" | "logrus"
      structured: bool
    testing:
      style: string          # "table-driven" | "subtests" | "standard"
      framework: string
      mock_strategy: string  # "mockery" | "gomock" | "manual" | "none"
```

---

### Phase 4: MAP → `state.map`

```yaml
map:
  entry_points:              # REQUIRED
    - type: "cli" | "http" | "grpc" | "worker" | "cron" | "lambda"
      path: string
      description: string
      framework: string      # link to detect.frameworks
  core_domain:
    entities:                # REQUIRED
      - name: string
        path: string
        type: "aggregate_root" | "entity" | "value_object"
        key_fields: string[]
    interfaces:
      - name: string
        path: string
        methods: string[]
        implementations: string[]  # пути к реализациям
  design_patterns:
    - pattern: string        # "Repository" | "Factory" | "Strategy" | ...
      location: string
      usage: string
  external_integrations:
    - type: "database" | "cache" | "queue" | "api" | "storage"
      name: string           # "PostgreSQL" | "Redis" | "Kafka"
      driver: string         # "pgx" | "go-redis"
      config_location: string
  dependency_graph:          # NEW — from dependency graph analysis
    total_packages: int
    max_depth: int
    hub_packages:            # packages with highest fan-in
      - package: string
        fan_in: int
        fan_out: int
    circular_deps: string[][]  # groups of cyclically dependent packages
    isolated_packages: string[] # packages with 0 fan-in (potentially dead code)
```

---

### Phase 5: DATABASE → `state.database`

```yaml
database:
  available: bool            # REQUIRED
  skip_reason: string        # if not available
  tables:
    - name: string
      columns: int
      primary_key: string
      foreign_keys: string[]
      domain_entity: string  # mapped entity name
      alignment: "aligned" | "mismatch" | "unmapped"
  alignment_issues: string[]
  statistics:
    total_tables: int
    total_columns: int
    total_foreign_keys: int
    alignment_rate: float    # 0.0-1.0
```

---

### Phase 6: CRITIQUE → `state.critique`

```yaml
critique:
  completeness: "pass" | "fail"
  accuracy: "pass" | "fail"
  quality: "pass" | "fail"
  relevance: "pass" | "fail"
  issues:
    - description: string
      severity: "critical" | "warning" | "info"
      fix: string
  plan_adjustments: string[]
  confidence_after_review: float
  gate_passed: bool          # REQUIRED
```

**BLOCKING:** Не продолжать если `gate_passed == false`

---

### Phase 7: GENERATE → `state.generate`

```yaml
generate:
  artifacts:
    - type: "claude_md" | "skill" | "rule" | "command" | "project_knowledge" | "memory_json"
      name: string
      path: string
      status: "created" | "preserved" | "updated" | "skipped"
      lines: int
  total_created: int
  total_preserved: int
  total_updated: int
```

---

### Phase 8: VERIFY → `state.verify`

```yaml
verify:
  yaml_valid: bool
  references_valid: bool
  sizes_valid: bool
  structure_valid: bool
  duplicates_clean: bool
  issues:
    - check: string
      status: "pass" | "fail" | "warning"
      details: string
  gate_passed: bool          # REQUIRED
```

**BLOCKING:** Не продолжать если `gate_passed == false`

---

## VALIDATION RULES

Перед стартом каждой фазы проверить:

| Phase | Required State |
|-------|---------------|
| DISCOVER | `state.validate.path`, `state.validate.mode` |
| DETECT | `state.validate.*`, `state.discover.analysis_targets` |
| ANALYZE | `state.detect.primary_language`, `state.detect.frameworks` |
| MAP | `state.analyze.architecture`, `state.analyze.layers` |
| DATABASE | `state.map.external_integrations` (check for DB) |
| CRITIQUE | `state.detect.*`, `state.analyze.*`, `state.map.*` |
| GENERATE | `state.critique.gate_passed == true` |
| VERIFY | `state.generate.artifacts` |
| REPORT | `state.verify.gate_passed == true` |

**On missing required field:** FATAL — вернуться к фазе, которая должна была его заполнить.

---

## COMPACT OUTPUT FORMAT

После каждой фазы выводить только summary, а не весь стейт:

```
[PHASE 2/10] DETECT — DONE
State: detect.primary_language=go (0.92), frameworks=[chi@v5, pgx@v5], ast_available=true
```

Полный стейт доступен через `state.*` для следующих фаз, но не дублируется в output.
