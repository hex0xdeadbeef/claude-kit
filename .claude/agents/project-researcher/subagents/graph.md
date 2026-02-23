# SUBAGENT: GRAPH (v4.2)

**Model:** sonnet
**Phases:** GRAPH
**Input:** state.validate (path, mode), state.discover.*, state.detect.*
**Output:** state.graph

**New in v4.2:** Построение repo-map — ранжированной символьной карты проекта через tree-sitter. Результат используется как входной контекст для ANALYSIS subagent, значительно повышая точность архитектурного анализа.

---

## OVERVIEW

GRAPH фаза строит три связанных артефакта:
1. **Symbol Table** — все определения (функции, типы, интерфейсы) с метаданными
2. **Dependency Graph** — граф зависимостей между файлами/пакетами
3. **Repo-Map** — ранжированный (PageRank) список символов, сжатый до token budget

```
Inputs:                           GRAPH Subagent                        Output:
                             ┌─────────────────────┐
state.detect.analysis_method │  1. Symbol Extract   │
state.detect.primary_language│  2. Dep Graph Build  │→ state.graph
state.discover.analysis_targets│ 3. PageRank Rank  │
project files (via tools)    │  4. Token Budget     │
                             └─────────────────────┘
```

---

## PHASE: GRAPH

### Step 1: Analysis Method Selection

Определить доступный метод анализа из `state.detect.analysis_method`:

```yaml
method_selection:
  "tree-sitter-mcp":
    primary_tools: [get_symbols, get_dependencies, find_usage, analyze_project]
    symbol_extraction: "MCP get_symbols per file"
    dependency_extraction: "MCP get_dependencies"
    cross_reference: "MCP find_usage for exported symbols"
    confidence_baseline: 1.0

  "ast-grep":
    primary_tools: [ast-grep CLI, bash]
    symbol_extraction: "ast-grep patterns from deps/tree-sitter-patterns.md (legacy section)"
    dependency_extraction: "ast-grep import patterns + go list fallback"
    cross_reference: "grep-based (limited)"
    confidence_baseline: 0.85

  "grep":
    primary_tools: [grep, bash]
    symbol_extraction: "grep patterns from reference/language-patterns.md"
    dependency_extraction: "grep import patterns"
    cross_reference: "not available"
    confidence_baseline: 0.65
```

---

### Step 2: Symbol Extraction

Extract all code symbols from project files.

**With tree-sitter MCP:**

```yaml
# For each analysis target:
for target in state.discover.analysis_targets:
  # Option A: Full project analysis (preferred for single projects)
  result = analyze_project(project_path=target)

  # Option B: Per-file extraction (for fine-grained control)
  for file in list_files(project_path=target):
    symbols = get_symbols(
      file_path=file,
      symbol_types=["functions", "classes", "structs", "interfaces", "imports"]
    )
```

**Symbol Record Format:**

```yaml
symbol:
  name: string              # "UserRepository", "NewServer", "HandleGetUser"
  kind: string              # "function" | "method" | "struct" | "interface" | "class" | "type" | "trait" | "enum"
  file: string              # relative file path
  line: int                 # line number
  signature: string         # full signature (if available)
  exported: bool            # public/exported?
  receiver: string          # for methods: receiver type
  params: string[]          # parameter types
  returns: string[]         # return types
  decorators: string[]      # for Python/TS: decorator names
```

**Filters:**
- Exclude test files (`*_test.go`, `test_*.py`, `*.test.ts`) from primary symbol table
- Exclude generated code (`*_gen.go`, `wire_gen.go`, `*.pb.go`)
- Exclude vendor/node_modules (already excluded by tree-sitter config)

**With ast-grep fallback:**

```bash
# Go: extract function names
ast-grep --pattern 'func $NAME($$$) $$$' --lang go --json | jq '.[] | .text'

# Go: extract struct names
ast-grep --pattern 'type $NAME struct { $$$ }' --lang go --json | jq '.[] | .metaVariables.single.NAME.text'

# Go: extract interface names
ast-grep --pattern 'type $NAME interface { $$$ }' --lang go --json | jq '.[] | .metaVariables.single.NAME.text'
```

**With grep fallback:**

```bash
# Go
grep -rn "^func " --include="*.go" | grep -v "_test.go"
grep -rn "^type [A-Z][a-zA-Z]* struct" --include="*.go"
grep -rn "^type [A-Z][a-zA-Z]* interface" --include="*.go"
```

---

### Step 3: Dependency Graph Construction

Build directed graph of file/package dependencies.

**Graph Structure:**
```yaml
graph:
  nodes: file[]             # each source file is a node
  edges:                    # directed: file A imports/depends on file B
    - from: string          # source file
      to: string            # target file
      type: "import" | "call" | "type_reference"
      weight: int           # number of references (edge weight)
```

**With tree-sitter MCP:**

```yaml
# Step 3a: File-level dependencies
deps = get_dependencies(project_path=target)
# Returns: {file: [imported_files/packages]}

# Step 3b: Cross-file references (for exported symbols)
for symbol in exported_symbols:
  usages = find_usage(
    symbol_name=symbol.name,
    file_path=symbol.file
  )
  # Each usage creates an edge: usage.file → symbol.file
  # Weight = count of usages from that file
```

**With go list (Go projects):**

```bash
go list -json ./... 2>/dev/null | jq '{ImportPath, Imports, GoFiles}'
```

**With grep/ast-grep fallback:**

```bash
# Go: Extract imports per file
grep -rn '^import' --include="*.go" | grep -v "_test.go"

# Python: Extract imports
grep -rn "^from \|^import " --include="*.py"

# TypeScript: Extract imports
grep -rn "^import " --include="*.ts" --include="*.tsx"
```

**Edge Construction Rules:**
1. Import statement → edge from importing file to imported package/file
2. For monorepo internal imports: resolve to actual file paths
3. External imports (stdlib, third-party) → mark as external nodes (not ranked)
4. Weight = count of distinct import references per file pair

---

### Step 4: PageRank Computation

Apply PageRank algorithm to rank files and symbols by importance.

**Algorithm (inspired by Aider's repo-map):**

```yaml
pagerank:
  algorithm: "personalized_pagerank"
  parameters:
    damping_factor: 0.85       # standard PageRank damping
    max_iterations: 100        # convergence limit
    tolerance: 1e-6            # convergence threshold

  personalization:
    # Bias ranking toward files most likely to be architecturally significant
    entry_point_files: 1.5     # files with main(), handlers → higher weight
    interface_files: 1.3       # files defining interfaces → higher weight
    domain_layer_files: 1.2    # files in domain/core layer → higher weight
    default: 1.0               # all other files
```

**Implementation (conceptual — executed via bash/python in subagent):**

```python
# Pseudo-code for PageRank computation:
import networkx as nx

G = nx.DiGraph()

# Add nodes (files) with attributes
for file in project_files:
    G.add_node(file, symbols=file_symbols[file])

# Add edges (dependencies) with weights
for edge in dependency_edges:
    G.add_edge(edge.from, edge.to, weight=edge.weight)

# Personalization vector
personalization = {}
for node in G.nodes():
    if is_entry_point(node):
        personalization[node] = 1.5
    elif has_interfaces(node):
        personalization[node] = 1.3
    elif is_domain_layer(node):
        personalization[node] = 1.2
    else:
        personalization[node] = 1.0

# Compute PageRank
ranks = nx.pagerank(G, alpha=0.85, personalization=personalization)

# Distribute file rank to symbols
ranked_symbols = []
for file, rank in sorted(ranks.items(), key=lambda x: -x[1]):
    for symbol in file_symbols[file]:
        symbol_rank = rank / len(file_symbols[file])
        ranked_symbols.append((symbol, symbol_rank))
```

**Practical Note:** Subagent не обязан запускать Python с networkx. Можно:
1. Использовать tree-sitter MCP `analyze_project` (если доступен)
2. Реализовать упрощённый PageRank через bash + jq
3. Или просто ранжировать по fan-in (количество файлов, импортирующих данный файл)

**Simplified Ranking (fallback, no Python):**

```yaml
simplified_ranking:
  method: "fan-in count"
  formula: "rank(file) = count(files that import this file)"
  bias:
    - "entry_points: rank *= 1.5"
    - "interface_files: rank *= 1.3"
    - "domain_layer: rank *= 1.2"
  note: "Approximates PageRank for most project structures. Full PageRank recommended for >100 files."
```

---

### Step 5: Token Budget & Repo-Map Generation

Generate token-budgeted repo-map for downstream consumption.

**Token Budget:**

```yaml
token_budget:
  default: 4000              # tokens allocated for repo-map in ANALYSIS context
  min: 1000                  # minimum useful repo-map size
  max: 8000                  # maximum (for very large projects)

  scaling:
    "<50 files": 2000
    "50-200 files": 4000
    "200-500 files": 6000
    ">500 files": 8000

  estimation: "~4 tokens per symbol line in repo-map"
```

**Repo-Map Format:**

```
# Repo-Map (ranked by importance)
# Format: file_path | symbol_kind | symbol_name | signature

## Hub Files (top 10% by rank)

internal/domain/repository.go
│ interface  UserRepository
│ │ method   GetByID(ctx context.Context, id string) (*User, error)
│ │ method   Create(ctx context.Context, user *User) error
│ │ method   Update(ctx context.Context, user *User) error
│ interface  OrderRepository
│ │ method   GetByID(ctx context.Context, id string) (*Order, error)

internal/domain/entity.go
│ struct     User {ID, Email, Name, CreatedAt, UpdatedAt}
│ struct     Order {ID, UserID, Items, Total, Status, CreatedAt}

internal/application/service.go
│ struct     UserService
│ │ method   GetUser(ctx, id) (*User, error)
│ │ method   CreateUser(ctx, input) (*User, error)
│ function   NewUserService(repo UserRepository, log *slog.Logger) *UserService

## Important Files (10-30% by rank)

internal/infrastructure/postgres/user_repo.go
│ struct     UserPostgresRepo
│ │ method   GetByID(ctx, id) (*User, error)
│ function   NewUserPostgresRepo(db *pgx.Pool) *UserPostgresRepo

cmd/server/main.go
│ function   main()
│ function   setupRouter(svc *UserService) *chi.Mux

## Other Files (30-100% by rank, truncated to budget)

internal/interface/http/handler.go
│ function   HandleGetUser(svc *UserService) http.HandlerFunc
│ function   HandleCreateUser(svc *UserService) http.HandlerFunc

# ... (truncated to fit token budget)
```

**Generation Algorithm:**

```yaml
repo_map_generation:
  1_sort: "Sort symbols by rank (descending)"
  2_group: "Group by file, preserve file rank order"
  3_format: "For each file: path + indented symbols with kind + name + signature"
  4_budget_check: "Binary search: find max symbols that fit in token_budget"
  5_truncate: "Cut at token boundary, add '# ... (N more files)' footer"
  6_sections: "Split into Hub (top 10%), Important (10-30%), Other (rest)"
```

---

## OUTPUT FORMAT

```yaml
subagent_result:
  status: "success" | "failure" | "partial"
  state_updates:
    graph:
      analysis_method: "tree-sitter-mcp" | "ast-grep" | "grep"
      method_confidence: 1.0 | 0.85 | 0.65

      symbol_table:
        total_symbols: int              # total extracted symbols
        total_files: int                # files with symbols
        by_kind:                        # count per symbol kind
          function: int
          method: int
          struct: int
          interface: int
          class: int
          type: int
          trait: int
          enum: int
        exported_count: int             # public/exported symbols
        test_symbols_excluded: int      # test symbols filtered out
        generated_excluded: int         # generated code filtered out

      dependency_graph:
        total_nodes: int                # files in graph
        total_edges: int                # dependency edges
        internal_edges: int             # intra-project edges
        external_packages: int          # unique external packages referenced
        avg_fan_in: float               # average incoming edges per node
        avg_fan_out: float              # average outgoing edges per node
        max_fan_in:                     # most-imported file
          file: string
          count: int
        max_fan_out:                    # file with most imports
          file: string
          count: int
        hub_files:                      # top 5 by fan-in (most depended upon)
          - file: string
            fan_in: int
            fan_out: int
            primary_symbols: string[]   # key symbols in this file
        isolated_files: string[]        # files with fan_in=0 and fan_out=0
        circular_deps:                  # detected circular dependencies
          - cycle: string[]             # [file_a, file_b, file_a]
            severity: "high" | "medium"

      pagerank:
        algorithm: "pagerank" | "fan-in-approximation"
        top_files:                      # top 20 files by rank
          - file: string
            rank: float                 # normalized 0.0-1.0
            symbols: int               # symbol count in file
            primary_kind: string        # dominant symbol kind
        convergence: bool               # true if PageRank converged
        iterations: int                 # iterations until convergence

      repo_map:
        content: string                 # the formatted repo-map text
        token_count: int                # estimated tokens
        token_budget: int               # allocated budget
        files_included: int             # files in repo-map
        files_total: int                # total project files
        coverage: float                 # files_included / files_total
        sections:
          hub: int                      # files in hub section
          important: int                # files in important section
          other: int                    # files in other section
          truncated: int                # files omitted due to budget

  progress_summary: "graph: {total_symbols} symbols, {total_edges} edges, PageRank top={top_file}, repo-map={token_count}/{token_budget} tokens ({coverage}% coverage)"
```

---

## STEP QUALITY CHECKLIST

- [ ] Analysis method correctly selected from state.detect.analysis_method
- [ ] Symbol table built: total_symbols > 0
- [ ] Exported symbols identified (exported_count > 0)
- [ ] Dependency graph constructed: total_edges > 0 (or explicit "no dependencies" for trivial projects)
- [ ] Hub files identified (≥1 file with fan_in > 0)
- [ ] Circular dependencies checked (empty list or documented cycles)
- [ ] Ranking applied (PageRank or fan-in approximation)
- [ ] Repo-map generated and fits within token_budget
- [ ] Repo-map coverage ≥ 30% of files (or justified why lower)
- [ ] Test files excluded from primary symbol table
- Min pass: 8/10

---

## EXECUTION CONTEXT

- **Working Directory:** Project root (state.validate.path)
- **Tools Available:** Read, Grep, Bash, Glob + tree-sitter MCP tools (if available)
- **Python Available:** For PageRank computation (pip install networkx if needed)
- **Performance:** For projects >500 files, limit symbol extraction to top-level declarations only
- **Error Handling:** If tree-sitter MCP unavailable, fall back gracefully to ast-grep/grep
- **Output Size:** repo_map.content should be ≤8000 tokens (≤32KB text)

---

## MONOREPO HANDLING

For monorepo projects, GRAPH can execute per-module or project-wide:

```yaml
monorepo_strategy:
  "per-module":
    execution: "One GRAPH call per module"
    graph_scope: "Module-local dependencies only"
    merge: "Orchestrator merges per-module graphs, adds inter-module edges"

  "project-wide":
    execution: "Single GRAPH call for entire project"
    graph_scope: "All modules, including inter-module dependencies"
    merge: "No merge needed"

  decision: |
    IF state.discover.modules.length <= 3:
      # Part of compound subagent (pipeline parallelism)
      # GRAPH runs per-module inside compound call
      strategy = "per-module"
    ELSE:
      # Batch mode — GRAPH runs once project-wide after all DETECT merged
      strategy = "project-wide"
```

**Compound Subagent Integration (pipeline mode):**
When GRAPH is part of a compound subagent (DETECT + GRAPH + ANALYZE), it runs between DETECT and ANALYZE within the same Task call, receiving detection results directly.

---

## REFERENCES

- **Query Patterns:** `deps/tree-sitter-patterns.md`
- **State Contract:** `deps/state-contract.md` → `state.graph`
- **Aider repo-map:** https://aider.chat/docs/repomap.html
- **PageRank:** https://en.wikipedia.org/wiki/PageRank
- **tree-sitter MCP:** https://github.com/wrale/mcp-server-tree-sitter
