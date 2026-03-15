# Inter-Phase State Contract

**Purpose:** Typed state object passed between phases and subagents. The orchestrator maintains the global state; subagents receive only required fields and return their own section.

**Principle:** A formal data contract eliminates fragile transfer via markdown and enables programmatic validation.

**Load when:** Orchestrator — during initialization. Subagents — receive a relevant subset in the prompt.

**SEE:** `deps/orchestration.md` for the subagent call protocol.

---

## STATE SCHEMA

The state is a virtual YAML object. The orchestrator maintains the full state in memory. Each subagent:
1. Receives required fields from previous phases from the orchestrator
2. Populates its own section completely
3. Returns `subagent_result` with `state_updates` (only its own section)

---

### DISCOVERY Subagent → `state.validate` + `state.discover`

```yaml
validate:
  path: string              # REQUIRED — absolute path to the project
  mode: "CREATE" | "AUGMENT" | "UPDATE"  # REQUIRED
  git: bool                 # REQUIRED
  git_root: string          # path to .git or null
  git_remote: string        # remote URL or null
  commit_count: int
  has_claude_dir: bool      # REQUIRED
  source_file_count: int    # REQUIRED — number of source files
  extension_distribution:   # file extension counts
    ".go": int
    ".ts": int
  claude_artifacts:         # detailed .claude/ contents (if has_claude_dir)
    files: string[]
    dirs: string[]
  existing_artifacts:       # REQUIRED if mode != CREATE
    claude_md: bool
    skills: string[]        # names of existing skills
    rules: string[]         # names of existing rules
    commands: string[]
  git_analysis:             # REQUIRED if mode == UPDATE; aka git_context in discovery.md output
    commits_since: int
    files_changed: int
    changed_layers: string[]
    update_scope: string[]
```

```yaml
discover:
  is_monorepo: bool         # REQUIRED
  modules:                  # REQUIRED if is_monorepo
    - path: string          # relative path to the module
      language: string      # primary language of the module
      type: "service" | "library" | "app" | "shared" | "tool"
      manifest: string      # go.mod | package.json | Cargo.toml | pom.xml
      depends_on: string[]  # paths to other modules (internal deps)
  manifests:
    - path: string
      type: string          # "go.mod" | "package.json" | ...
      language: string
      version_info: object
  internal_dependencies: object  # module → [dependent modules]
  strategy: "single" | "per-module" | "per-module-with-shared-context"
  strategy_rationale: string # why this strategy was chosen
  # NOTE: "per-module"/"per-module-with-shared-context" map to orchestrator
  # execution modes: "pipeline" (≤3 modules) or "batch" (4+ modules).
  # SEE: deps/orchestration.md → PARALLEL EXECUTION
  root_module: string       # path to the "main" module (if identified)
  analysis_targets:         # REQUIRED — targets for downstream subagents
    - path: string
      language: string
      type: "root_module" | "service" | "library" | "app" | "shared" | "tool"
  # NOTE: discovery.md ALREADY outputs objects (not strings).
  # Orchestration pseudo-code in orchestration.md:200-224 iterates
  # analysis_targets using `module_path=target` — this is LLM-interpreted
  # pseudo-code, not executable code, so the type is safe.
```

**FATAL if:** `path` does not exist, `source_file_count == 0`
**Logic:** If `is_monorepo == false`, then `analysis_targets = [state.validate.path]`.

---

### DETECTION Subagent → `state.detect`

**Receives:** `state.validate.path`, `state.validate.mode`, `state.validate.source_file_count`, `state.discover.analysis_targets`, `state.discover.is_monorepo`

```yaml
detect:
  analysis_method: string       # REQUIRED — "tree-sitter-mcp" | "ast-grep" | "grep"
  primary_language: string      # REQUIRED — "go" | "python" | "typescript" | "rust" | "java" | ...
  primary_confidence: float     # REQUIRED — 0.0-1.0
  secondary_languages:          # optional
    - language: string
      file_count: int
      role: string              # "frontend" | "scripts" | "tools" | "tests"
  language_counts:              # raw file counts by extension
    ".go": int
    ".ts": int
  frameworks:                   # REQUIRED — at least []
    - name: string              # "chi" | "gin" | "echo" | ...
      version: string           # "v5.1.0"
      category: "http" | "orm" | "grpc" | "cli" | "testing" | "logging" | "di"
      confidence: float
      detection_method: "manifest" | "manifest + AST" | "manifest + grep" | "grep only"
      match_count: int          # AST or grep match count
  build_tools:                  # REQUIRED
    files:
      - name: string            # "Makefile" | "Dockerfile"
        path: string            # "./Makefile"
        details: object         # optional (multi_stage, has_docker, etc.)
    ci_cd:
      providers: string[]       # ["GitHub Actions", "GitLab CI"]
      pipeline_count: int
      stages: string[]          # ["test", "build", "deploy"]
    linters: string[]           # ["golangci-lint", "prettier"]
  testing:                      # REQUIRED
    frameworks: string[]        # ["testing (builtin)", "testify"]
    mock_tools: string[]        # ["gomock"]
    test_file_count: int
    test_case_count: int
    table_driven_tests: int     # for Go
    assertion_style: string     # "testify/assert" | "require" | "expect"
    detection_method: string    # "manifest + AST + grep"
```

**FATAL if:** `primary_language` is not determined, `primary_confidence < 0.3`

---

### GRAPH Subagent → `state.graph` (v4.2)

**Receives:** `state.validate.path`, `state.detect.analysis_method`, `state.detect.primary_language`, `state.discover.analysis_targets`

```yaml
graph:
  analysis_method: string          # REQUIRED — "tree-sitter-mcp" | "ast-grep" | "grep"
  method_confidence: float         # REQUIRED — 1.0 | 0.85 | 0.65

  symbol_table:
    total_symbols: int             # REQUIRED — total extracted symbols
    total_files: int               # REQUIRED — files with symbols
    by_kind:                       # REQUIRED
      function: int
      method: int
      struct: int
      interface: int
      class: int
      type: int
      trait: int
      enum: int
    exported_count: int            # REQUIRED — public/exported symbols
    test_symbols_excluded: int     # filtered test symbols
    generated_excluded: int        # filtered generated code

  dependency_graph:
    total_nodes: int               # REQUIRED — files in graph
    total_edges: int               # REQUIRED — dependency edges
    internal_edges: int            # intra-project edges
    external_packages: int         # unique external packages
    avg_fan_in: float
    avg_fan_out: float
    max_fan_in:
      file: string
      count: int
    max_fan_out:
      file: string
      count: int
    hub_files:                     # REQUIRED — top 5 by fan-in
      - file: string
        fan_in: int
        fan_out: int
        primary_symbols: string[]
    isolated_files: string[]
    circular_deps:
      - cycle: string[]
        severity: "high" | "medium"

  pagerank:
    algorithm: "pagerank" | "fan-in-approximation"  # REQUIRED
    top_files:                     # REQUIRED — top 20 files by rank
      - file: string
        rank: float                # 0.0-1.0 normalized
        symbols: int
        primary_kind: string
    convergence: bool
    iterations: int

  repo_map:
    content: string                # REQUIRED — formatted repo-map text
    token_count: int               # REQUIRED — estimated tokens
    token_budget: int              # allocated budget
    files_included: int            # files in repo-map
    files_total: int               # total project files
    coverage: float                # files_included / files_total
    sections:
      hub: int
      important: int
      other: int
      truncated: int
```

**FATAL if:** `symbol_table.total_symbols == 0`, `repo_map.content` is empty
**WARN if:** `pagerank.convergence == false`, `coverage < 0.3`

---

### ANALYSIS Subagent → `state.analyze` + `state.map` + `state.database`

**Receives:** `state.validate.path`, `state.validate.mode`, `state.discover.*`, `state.detect.*`, **`state.graph.*`** (v4.2, OPTIONAL — analysis falls back to direct AST/grep if graph unavailable)

```yaml
analyze:
  architecture: string       # REQUIRED — "clean" | "hexagonal" | "mvc" | "layered" | "ddd" | ...
  architecture_confidence: float  # REQUIRED
  architecture_evidence:     # REQUIRED — what exactly confirms the pattern
    - indicator: string      # "internal/domain/ exists"
      weight: float          # 0.0-1.0
  layers:                    # REQUIRED
    - name: string           # "domain" | "usecase" | "infrastructure" | ...
      path: string           # "internal/domain"
      packages: string[]     # ["entity", "valueobject", "repository"]
      interface_count: int
      struct_count: int
      external_deps: string[] # packages outside the project (violations?)
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
        implementations: string[]  # paths to implementations
  design_patterns:
    - pattern: string        # "Repository" | "Factory" | "Strategy" | ...
      location: string
      usage: string
  external_integrations:
    - type: "database" | "cache" | "queue" | "api" | "storage"
      name: string           # "PostgreSQL" | "Redis" | "Kafka"
      driver: string         # "pgx" | "go-redis"
      config_location: string
  dependency_graph:
    total_packages: int
    max_depth: int
    hub_packages:
      - package: string
        fan_in: int
        fan_out: int
    circular_deps: string[][]
    isolated_packages: string[]
```

```yaml
database:
  available: bool            # REQUIRED
  skip_reason: string        # if not available
  tables:
    - name: string
      columns: int
      primary_key: string
      foreign_keys: string[]
      domain_entity: string
      alignment: "aligned" | "mismatch" | "unmapped"
  alignment_issues: string[]
  statistics:
    total_tables: int
    total_columns: int
    total_foreign_keys: int
    alignment_rate: float    # 0.0-1.0
```

---

### CRITIQUE (Inline in Orchestrator) → `state.critique`

**Reads:** `state.detect.*`, `state.analyze.*`, `state.map.*`, `state.graph.*` (OPTIONAL)

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

**BLOCKING:** Do not continue if `gate_passed == false`

---

### GENERATION Subagent → `state.generate`

**Receives:** Full state (all previous phases)

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

### VERIFICATION Subagent → `state.verify`

**Receives:** `state.generate.artifacts`, `state.validate.path`

```yaml
verify:
  yaml_valid: bool
  references_valid: bool
  sizes_valid: bool
  structure_valid: bool
  duplicates_clean: bool
  issues:
    - code: string            # "YAML_PARSE_ERROR" | "REFERENCE_UNRESOLVED" | "SIZE_WARNING" | ...
      artifact: string        # file path of the affected artifact
      severity: "error" | "warning" | "info"
      message: string         # human-readable description
      fix: string             # suggested correction
  yaml_errors: int
  reference_errors: int
  size_warnings: int
  size_errors: int
  structure_issues: int
  duplicate_issues: int
  summary: string             # human-readable summary
  gate_passed: bool          # REQUIRED
```

**BLOCKING:** Do not continue if `gate_passed == false`

---

## SUBAGENT INTERFACE

### Input Format (from orchestrator to subagent)

```yaml
subagent_input:
  project_path: string       # absolute path to the project
  agent_root: string         # path to the project-researcher directory
  config:
    dry_run: bool            # analysis only, no file writing
    mode: string             # CREATE | AUGMENT | UPDATE
    module_target: string    # specific module (for monorepo parallelization)
  state:                     # only required fields for this subagent
    validate: { ... }
    discover: { ... }
    # ... only what is needed
```

### Output Format (from subagent to orchestrator)

```yaml
subagent_result:
  status: "success" | "failure" | "partial"
  state_updates:
    {phase_name}:
      {field}: {value}
  progress_summary: string   # one-line summary
  error:                     # only if status != "success"
    code: string             # ERROR_CODE
    message: string
    recovery: string         # suggested action
```

---

## VALIDATION RULES

### Per-Subagent Required State

| Subagent | Required Input State |
|----------|---------------------|
| discovery | (none — reads filesystem) |
| detection | `state.validate.path`, `state.discover.analysis_targets` |
| **graph** | **`state.validate.path`, `state.detect.analysis_method`, `state.detect.primary_language`, `state.discover.analysis_targets`** |
| analysis | `state.validate.path`, `state.discover.*`, `state.detect.*`, **`state.graph.*`** |
| CRITIQUE (inline) | `state.detect.*`, **`state.graph.*`**, `state.analyze.*`, `state.map.*` |
| generation | `state.critique.gate_passed == true`, all previous state |
| verification | `state.generate.artifacts`, `state.validate.path` |
| report | `state.verify.gate_passed == true`, all state |

**On missing required field:** FATAL — the orchestrator must re-run the previous subagent.

---

## MONOREPO STATE MERGING

### Execution Modes

The merge protocol depends on the execution mode:

| Mode | Condition | Subagent Shape | Merge Timing |
|------|-----------|---------------|--------------|
| **Sequential** | `strategy == "single"` | Separate detection, analysis | After each subagent |
| **Pipeline** | `strategy != "single"` AND modules ≤ 3 | Compound (detect+analyze per module) | After all compound subagents complete |
| **Batch** | `strategy != "single"` AND modules > 3 | Separate detection, analysis | After each batch (all detect → merge → all analyze → merge) |

### Compound Subagent Result Format (Pipeline Mode)

Compound subagents return DETECTION + GRAPH + ANALYSIS results in a single `subagent_result`:

```yaml
subagent_result:
  status: "success" | "failure" | "partial"
  compound: true                          # compound subagent flag
  module_target: "services/api"           # which module was processed
  state_updates:
    detect:
      primary_language: "go"
      primary_confidence: 0.92
      frameworks: [...]
      build_tools: [...]
      test_framework: "testify"
      analysis_method: "tree-sitter-mcp"
    graph:                                # NEW v4.2
      analysis_method: "tree-sitter-mcp"
      method_confidence: 1.0
      symbol_table: { total_symbols: 145, by_kind: { ... } }
      dependency_graph: { total_nodes: 23, total_edges: 52 }
      pagerank: { algorithm: "pagerank", top_files: [...] }
      repo_map: { content: "...", token_count: 2800, token_budget: 4000 }
    analyze:
      architecture: "clean"
      architecture_confidence: 0.88
      layers: [...]
      conventions: { ... }
    map:
      entry_points: [...]
      core_domain: { ... }
      design_patterns: [...]
      dependency_graph: { ... }
    database:
      available: false
      skip_reason: "no DB layer detected"
  progress_summary: "module=services/api: detect=go(0.92), graph=145sym/52edges, analyze=clean(0.88)"
  error:                                  # only if status != "success"
    phase: "detection" | "graph" | "analysis"  # REQUIRED for compound — which phase failed
    code: "..."
    message: "..."
    recovery: "..."
```

**Compound partial failure:**
- `error.phase == "detection"` → the entire `state_updates` is empty, the module is excluded from merge
- `error.phase == "graph"` → `state_updates.detect` is valid (merged), `state_updates.graph/analyze/map/database` are empty. Analysis runs without repo-map context.
- `error.phase == "analysis"` → `state_updates.detect` and `state_updates.graph` are valid (merged), `state_updates.analyze/map/database` are empty

### Per-Module State Lifecycle

```
Per-module results are stored in an intermediate format until aggregation:

state.detect.modules[]:
  - target: "services/api"           # module path
    status: "success" | "partial"    # per-module status
    ...detect fields...
  - target: "services/auth"
    status: "success"
    ...detect fields...

state.analyze.modules[]:
  - target: "services/api"
    status: "success" | "partial"
    ...analyze fields...

state.map.modules[]:
  - target: "services/api"
    ...map fields...

After merging all modules → aggregation into top-level fields.
```

### Per-Module Merge (from compound results)

```yaml
# Per-module results stored as:
detect:
  modules:
    - target: "services/api"
      status: "success"
      primary_language: "go"
      frameworks: [...]
    - target: "services/auth"
      status: "success"
      primary_language: "go"
      frameworks: [...]

# Aggregated fields (computed by orchestrator):
detect:
  primary_language: "go"              # majority vote
  primary_confidence: 0.90            # weighted average
  frameworks: [unique union]
  analysis_method: "tree-sitter-mcp"  # best available across modules
```

### Merge Functions

| Field | Strategy | Notes |
|-------|----------|-------|
| `primary_language` | Majority vote across modules | Tie → largest module (by source_file_count) wins |
| `primary_confidence` | Weighted average (by source_file_count) | Excludes failed modules |
| `frameworks` | Unique union (deduplicate by name) | Version conflict → highest version |
| **`symbol_table`** | **Sum counts across modules** | **`total_symbols = Σ module.total_symbols`** |
| **`dependency_graph` (graph)** | **Merge graphs + add inter-module edges** | **Per-module graphs merged into project-wide graph** |
| **`repo_map`** | **Regenerate from merged graph** | **PageRank re-run on merged graph; token budget scales** |
| `layers` | Concatenate, prefix with module path | `services/api::domain`, `services/auth::domain` |
| `entry_points` | Concatenate | Each tagged with module_target |
| `dependency_graph` (map) | Merge graphs + add inter-module edges | From `state.discover.internal_dependencies` |
| `conventions` | From root_module or majority | If root_module failed → fallback to majority |
| `architecture` | Per-module (not aggregated) | Each module can have its own architecture |

### Merge Validation

After merge, the orchestrator verifies:

```yaml
merge_validation:
  - total_modules_expected: N          # from state.discover.modules.length
  - total_modules_merged: M            # successfully merged
  - failed_modules: [list]             # modules excluded from merge
  - partial_modules: [list]            # modules with partial data
  - merge_complete: M == N             # true only if all succeeded
  - merge_viable: M >= 1              # at least one module succeeded
```

**FATAL if:** `merge_viable == false` (all modules failed)
**WARN if:** `merge_complete == false` (partial merge, continue with available data)

---

## COMPACT OUTPUT FORMAT

After each subagent call, the orchestrator outputs:

```
[PHASE {n}/10] {NAME} — DONE
State: {key_field=value, ...}
```

The full state is available via `state.*` for subsequent subagents but is not duplicated in the output.
