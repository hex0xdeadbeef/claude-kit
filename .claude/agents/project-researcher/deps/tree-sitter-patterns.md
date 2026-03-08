# Tree-Sitter Analysis Patterns (v4.2)

**Purpose:** Structural code analysis via tree-sitter MCP instead of ast-grep CLI. Tree-sitter is an incremental parser, the de facto standard for AI coding agents (Aider, Cline, Cursor).

**Principle:** Tree-sitter provides a complete AST with typed nodes. Unlike ast-grep (pattern matching), tree-sitter supports queries with predicates, wildcard nodes, and multi-capture. Via an MCP server — access to symbol extraction, usage search, and dependency analysis without CLI dependencies.

**Replaces:** `deps/ast-analysis.md` (ast-grep patterns). ast-grep patterns retained as legacy fallback.

**Load when:** DETECT, GRAPH, ANALYZE phases — as the primary code analysis method.

---

## MCP SERVER INTERFACE

### Availability Check

```yaml
# Check: is tree-sitter MCP available?
tree_sitter_check:
  method: "Check if mcp__tree_sitter tools exist in available tools"
  fallback_chain:
    1: "tree-sitter MCP server"     # primary — full API
    2: "ast-grep CLI"               # fallback — pattern matching only
    3: "grep"                       # last resort — text search

  state_field: "state.detect.analysis_method"
  values:
    - "tree-sitter-mcp"   # full API: symbols, usage, dependencies, queries
    - "ast-grep"           # pattern matching only
    - "grep"               # text search, lowest confidence
```

### MCP Tools Used

| Tool | Phase | Purpose |
|------|-------|---------|
| `register_project` | DETECT | Register project for analysis |
| `list_languages` | DETECT | Verify language support |
| `get_symbols` | DETECT, GRAPH | Extract functions, classes, interfaces per file |
| `find_usage` | GRAPH | Find all references to a symbol |
| `get_dependencies` | GRAPH | Extract import/dependency graph |
| `run_query` | DETECT, ANALYZE | Execute custom S-expression queries |
| `analyze_project` | GRAPH | Full project analysis (symbols + deps) |
| `get_ast` | ANALYZE | Get AST for specific file (deep analysis) |
| `find_similar_code` | ANALYZE | Pattern detection across files |

### Project Registration

```yaml
# At detection subagent startup:
register_project:
  path: "{state.validate.path}"
  name: "{project_name}"
  description: "Project analysis for project-researcher"

# Configuration:
config:
  cache:
    enabled: true
    max_size_mb: 100
    ttl_seconds: 600
  security:
    max_file_size_mb: 5
    excluded_dirs: [".git", "vendor", "node_modules", "__pycache__", "build", "dist", "generated"]
```

---

## LANGUAGE-SPECIFIC QUERY PATTERNS

### Notation

All patterns are S-expression queries for tree-sitter. Format:
```
(node_type field: (child_type) @capture_name) @parent_capture
```

Predicates:
- `#match?` — regex match on capture
- `#eq?` — exact match
- `#any-of?` — match against set

---

### GO PATTERNS

#### Functions & Methods

```scheme
;; All function declarations
(function_declaration
  name: (identifier) @function.name
  parameters: (parameter_list) @function.params
  body: (block) @function.body) @function.def

;; Method declarations (with receiver)
(method_declaration
  receiver: (parameter_list
    (parameter_declaration
      type: (_) @method.receiver_type))
  name: (field_identifier) @method.name
  parameters: (parameter_list) @method.params
  body: (block) @method.body) @method.def

;; Exported functions only (starts with uppercase)
(function_declaration
  name: (identifier) @function.name
  (#match? @function.name "^[A-Z]"))

;; Constructor functions (New*)
(function_declaration
  name: (identifier) @constructor.name
  (#match? @constructor.name "^New"))

;; Test functions
(function_declaration
  name: (identifier) @test.name
  (#match? @test.name "^Test"))

;; Functions accepting context.Context
(function_declaration
  name: (identifier) @function.name
  parameters: (parameter_list
    (parameter_declaration
      name: (identifier) @param.name
      type: (qualified_type) @param.type
      (#eq? @param.name "ctx"))))
```

#### Structs & Interfaces

```scheme
;; Struct declarations
(type_declaration
  (type_spec
    name: (type_identifier) @struct.name
    type: (struct_type) @struct.body)) @struct.def

;; Interface declarations
(type_declaration
  (type_spec
    name: (type_identifier) @interface.name
    type: (interface_type) @interface.body)) @interface.def

;; Interface method specs
(interface_type
  (method_spec
    name: (field_identifier) @iface_method.name
    parameters: (parameter_list) @iface_method.params))

;; Compile-time interface check: var _ Interface = (*Impl)(nil)
(var_declaration
  (var_spec
    name: (identifier) @check.blank
    (#eq? @check.blank "_")
    type: (_) @check.interface
    value: (expression_list
      (call_expression) @check.impl)))
```

#### Imports

```scheme
;; Import declarations (grouped)
(import_declaration
  (import_spec_list
    (import_spec
      path: (interpreted_string_literal) @import.path))) @import.block

;; Single import
(import_declaration
  (import_spec
    path: (interpreted_string_literal) @import.path)) @import.single

;; Named import
(import_declaration
  (import_spec_list
    (import_spec
      name: (identifier) @import.alias
      path: (interpreted_string_literal) @import.path)))
```

#### Error Patterns

```scheme
;; fmt.Errorf with %w (error wrapping)
(call_expression
  function: (selector_expression
    operand: (identifier) @pkg
    field: (field_identifier) @func)
  (#eq? @pkg "fmt")
  (#eq? @func "Errorf")
  arguments: (argument_list
    (interpreted_string_literal) @fmt_string
    (#match? @fmt_string "%w"))) @error.wrap

;; errors.New
(call_expression
  function: (selector_expression
    operand: (identifier) @pkg
    field: (field_identifier) @func)
  (#eq? @pkg "errors")
  (#eq? @func "New")) @error.new

;; Sentinel errors: var ErrX = errors.New(...)
(var_declaration
  (var_spec
    name: (identifier) @sentinel.name
    (#match? @sentinel.name "^Err"))) @error.sentinel

;; Error() method implementation (custom error type)
(method_declaration
  name: (field_identifier) @method.name
  (#eq? @method.name "Error")
  result: (type_identifier) @return_type
  (#eq? @return_type "string")) @error.custom_type
```

#### HTTP Handlers

```scheme
;; net/http handler: func(w http.ResponseWriter, r *http.Request)
(function_declaration
  name: (identifier) @handler.name
  parameters: (parameter_list
    (parameter_declaration
      type: (qualified_type
        package: (identifier) @pkg1
        name: (type_identifier) @type1)
      (#eq? @pkg1 "http")
      (#eq? @type1 "ResponseWriter"))
    (parameter_declaration
      type: (pointer_type
        (qualified_type
          package: (identifier) @pkg2
          name: (type_identifier) @type2))
      (#eq? @pkg2 "http")
      (#eq? @type2 "Request")))) @handler.def

;; Middleware: func(next http.Handler) http.Handler
(function_declaration
  name: (identifier) @middleware.name
  parameters: (parameter_list
    (parameter_declaration
      type: (qualified_type) @param_type))
  result: (qualified_type) @return_type
  (#match? @param_type "Handler")
  (#match? @return_type "Handler")) @middleware.def
```

#### Testing

```scheme
;; Table-driven tests
(short_var_declaration
  left: (expression_list
    (identifier) @var.name
    (#any-of? @var.name "tests" "tt" "cases" "testCases"))
  right: (expression_list
    (composite_literal
      type: (slice_type
        element: (struct_type))))) @test.table_driven

;; t.Run subtests
(call_expression
  function: (selector_expression
    operand: (identifier) @obj
    field: (field_identifier) @method)
  (#eq? @obj "t")
  (#eq? @method "Run")) @test.subtest

;; Testify require/assert
(call_expression
  function: (selector_expression
    operand: (identifier) @pkg
    field: (field_identifier) @method)
  (#any-of? @pkg "require" "assert")) @test.assertion
```

#### Logging

```scheme
;; slog calls
(call_expression
  function: (selector_expression
    operand: (identifier) @pkg
    field: (field_identifier) @method)
  (#eq? @pkg "slog")
  (#any-of? @method "Info" "Warn" "Error" "Debug" "Log")) @log.slog

;; zap calls
(call_expression
  function: (selector_expression
    operand: (_) @obj
    field: (field_identifier) @method)
  (#any-of? @method "Info" "Warn" "Error" "Debug" "Fatal" "Panic")
  arguments: (argument_list
    (interpreted_string_literal) @log.msg)) @log.structured
```

---

### PYTHON PATTERNS

#### Functions & Classes

```scheme
;; Function definitions
(function_definition
  name: (identifier) @function.name
  parameters: (parameters) @function.params
  body: (block) @function.body) @function.def

;; Async function definitions
(function_definition
  name: (identifier) @function.name
  parameters: (parameters) @function.params
  body: (block) @function.body
  (#match? @function.name "^async_")) @function.async_def

;; Class definitions
(class_definition
  name: (identifier) @class.name
  superclasses: (argument_list)? @class.bases
  body: (block) @class.body) @class.def

;; Decorated classes (dataclass, pydantic)
(decorated_definition
  (decorator
    (identifier) @decorator.name)
  definition: (class_definition
    name: (identifier) @class.name)) @class.decorated

;; Pydantic BaseModel
(class_definition
  name: (identifier) @class.name
  superclasses: (argument_list
    (identifier) @base
    (#eq? @base "BaseModel"))) @class.pydantic
```

#### Imports

```scheme
;; import X
(import_statement
  name: (dotted_name) @import.module) @import

;; from X import Y
(import_from_statement
  module_name: (dotted_name) @import.from
  name: (dotted_name) @import.item) @import.from_stmt

;; from X import *
(import_from_statement
  module_name: (dotted_name) @import.from
  (wildcard_import)) @import.wildcard
```

#### FastAPI/Flask/Django

```scheme
;; Route decorators
(decorated_definition
  (decorator
    (call
      function: (attribute
        object: (identifier) @router
        attribute: (identifier) @method)
      (#any-of? @method "get" "post" "put" "delete" "patch")))
  definition: (function_definition
    name: (identifier) @handler.name)) @route.def

;; Django view classes
(class_definition
  name: (identifier) @view.name
  superclasses: (argument_list
    (identifier) @base
    (#any-of? @base "View" "APIView" "GenericAPIView" "ModelViewSet"))) @view.django
```

---

### TYPESCRIPT PATTERNS

#### Functions & Classes

```scheme
;; Function declarations
(function_declaration
  name: (identifier) @function.name
  parameters: (formal_parameters) @function.params
  body: (statement_block) @function.body) @function.def

;; Arrow functions assigned to const
(lexical_declaration
  (variable_declarator
    name: (identifier) @function.name
    value: (arrow_function
      parameters: (formal_parameters) @function.params
      body: (_) @function.body))) @function.arrow

;; Class declarations
(class_declaration
  name: (type_identifier) @class.name
  body: (class_body) @class.body) @class.def

;; Interface declarations
(interface_declaration
  name: (type_identifier) @interface.name
  body: (object_type) @interface.body) @interface.def

;; Type alias declarations
(type_alias_declaration
  name: (type_identifier) @type.name
  value: (_) @type.value) @type.def

;; Method definitions in class
(method_definition
  name: (property_identifier) @method.name
  parameters: (formal_parameters) @method.params
  body: (statement_block) @method.body) @method.def
```

#### Imports

```scheme
;; Named imports: import { X } from 'Y'
(import_statement
  (import_clause
    (named_imports
      (import_specifier
        name: (identifier) @import.name)))
  source: (string) @import.source) @import.named

;; Default import: import X from 'Y'
(import_statement
  (import_clause
    (identifier) @import.default)
  source: (string) @import.source) @import.default_stmt

;; Namespace import: import * as X from 'Y'
(import_statement
  (import_clause
    (namespace_import
      (identifier) @import.namespace))
  source: (string) @import.source) @import.namespace_stmt
```

#### NestJS / React

```scheme
;; NestJS decorators
(class_declaration
  (decorator
    (call_expression
      function: (identifier) @decorator.name
      (#any-of? @decorator.name "Injectable" "Controller" "Module")))
  name: (type_identifier) @class.name) @nestjs.class

;; React hooks
(call_expression
  function: (identifier) @hook.name
  (#match? @hook.name "^use[A-Z]")) @react.hook

;; React useState
(variable_declarator
  name: (array_pattern
    (identifier) @state.var
    (identifier) @state.setter)
  value: (call_expression
    function: (identifier) @hook
    (#eq? @hook "useState"))) @react.useState
```

---

### RUST PATTERNS

#### Functions & Types

```scheme
;; Function definitions
(function_item
  name: (identifier) @function.name
  parameters: (parameters) @function.params
  body: (block) @function.body) @function.def

;; Struct definitions
(struct_item
  name: (type_identifier) @struct.name
  body: (field_declaration_list)? @struct.body) @struct.def

;; Trait definitions
(trait_item
  name: (type_identifier) @trait.name
  body: (declaration_list) @trait.body) @trait.def

;; Impl blocks
(impl_item
  trait: (_)? @impl.trait
  type: (_) @impl.type
  body: (declaration_list) @impl.body) @impl.def

;; Enum definitions
(enum_item
  name: (type_identifier) @enum.name
  body: (enum_variant_list) @enum.body) @enum.def
```

#### Imports & Modules

```scheme
;; use declarations
(use_declaration
  argument: (scoped_identifier
    path: (_) @use.path
    name: (identifier) @use.name)) @use.scoped

;; use with glob: use X::*
(use_declaration
  argument: (use_wildcard)) @use.wildcard

;; mod declarations
(mod_item
  name: (identifier) @mod.name) @mod.def
```

#### Error Handling

```scheme
;; Result return type
(function_item
  name: (identifier) @function.name
  return_type: (generic_type
    type: (type_identifier) @return.type
    (#eq? @return.type "Result"))) @function.returns_result

;; ? operator (try operator)
(try_expression
  (_) @try.expr) @try.op
```

---

### JAVA PATTERNS

#### Classes & Interfaces

```scheme
;; Class declarations
(class_declaration
  name: (identifier) @class.name
  body: (class_body) @class.body) @class.def

;; Interface declarations
(interface_declaration
  name: (identifier) @interface.name
  body: (interface_body) @interface.body) @interface.def

;; Method declarations
(method_declaration
  name: (identifier) @method.name
  parameters: (formal_parameters) @method.params
  body: (block) @method.body) @method.def

;; Annotations
(annotation
  name: (identifier) @annotation.name) @annotation.def
```

#### Spring Boot

```scheme
;; @RestController class
(class_declaration
  (modifiers
    (annotation
      name: (identifier) @anno
      (#eq? @anno "RestController")))
  name: (identifier) @controller.name) @spring.controller

;; @Service class
(class_declaration
  (modifiers
    (annotation
      name: (identifier) @anno
      (#eq? @anno "Service")))
  name: (identifier) @service.name) @spring.service

;; @Autowired injection
(field_declaration
  (modifiers
    (annotation
      name: (identifier) @anno
      (#eq? @anno "Autowired")))
  type: (_) @field.type
  declarator: (variable_declarator
    name: (identifier) @field.name)) @spring.autowired
```

#### Imports

```scheme
;; Import declarations
(import_declaration
  (scoped_identifier) @import.path) @import.java

;; Static imports
(import_declaration
  "static"
  (scoped_identifier) @import.static_path) @import.static
```

---

## KNOWN ISSUES

### tree-sitter 0.24+ API Change: `get_symbols` / `get_dependencies` may fail

**Symptom:** `mcp__tree_sitter__get_symbols` or `mcp__tree_sitter__get_dependencies` returns error:

```text
'tree_sitter.Query' object has no attribute 'captures'
```

**Root cause:** `mcp-server-tree-sitter ≤0.5.1` calls `query.captures(node)` which was removed in `tree-sitter 0.24+`. New API: `QueryCursor(query).captures(node)`.

**Status:** Fixed by patching `analysis.py` / `search.py` in the pipx venv. But may recur after `pipx upgrade`.

**Affected tools:** `get_symbols`, `get_dependencies`, `run_query`

**NOT affected:** `register_project`, `list_languages`, `list_files`, `get_ast`, `get_file`, `find_text`

**Fallback when symptoms appear:**

- For symbol extraction: use `get_ast` + `run_query` with patterns from this file
- For dependencies: use `go list -json ./...` (Go) or grep-based import extraction
- Record `analysis_method = "tree-sitter-mcp-partial"` in state, confidence_modifier = -0.05

---

## FALLBACK CHAIN

### Priority Order

```yaml
fallback_chain:
  1_tree_sitter_mcp_full:
    check: "MCP tools available AND get_symbols succeeds on a test file"
    capabilities: [symbols, usage, dependencies, queries, ast, similar_code]
    confidence_modifier: 0.0  # baseline
    state_value: "tree-sitter-mcp"

  1b_tree_sitter_mcp_partial:
    check: "MCP tools available BUT get_symbols fails with 'captures' error"
    capabilities: [ast, queries, find_text]  # get_ast + run_query still work
    confidence_modifier: -0.05
    state_value: "tree-sitter-mcp-partial"
    symbol_extraction: "run_query with patterns from this file"
    dependency_extraction: "go list / grep-based"
    note: "See KNOWN ISSUES section above"

  2_ast_grep:
    check: "command -v ast-grep || command -v sg"
    auto_install: "npm install -g @ast-grep/cli 2>/dev/null"
    capabilities: [pattern_matching]
    confidence_modifier: -0.03  # slightly lower (no cross-file analysis)
    state_value: "ast-grep"

  3_grep:
    check: "always available"
    capabilities: [text_search]
    confidence_modifier: -0.10
    state_value: "grep"
```

### ast-grep Legacy Patterns

If tree-sitter MCP is unavailable but ast-grep is installed — use patterns in legacy format:

```bash
# ast-grep pattern syntax (for fallback):
ast-grep --pattern 'type $NAME interface { $$$ }' --lang go
ast-grep --pattern 'func $NAME($$$) $$$' --lang go
ast-grep --pattern 'import ($$$)' --lang go
```

The full catalog of legacy ast-grep patterns is preserved in `deps/ast-analysis.md` (deprecated, read-only).

### Grep Fallback Patterns

```bash
# The most primitive level — text search:
grep -rn "type [A-Z][a-zA-Z]* interface {" --include="*.go"
grep -rn "func [A-Z][a-zA-Z]*(" --include="*.go"
grep -rn "^import" --include="*.go"
```

---

## CONFIDENCE ADJUSTMENT (v4.2)

| Analysis Method | Confidence Modifier | Notes |
|----------------|-------------------|-------|
| tree-sitter MCP (symbols + queries) | +0.0 (baseline) | Full AST, typed captures |
| tree-sitter MCP (analyze_project) | +0.02 | Cross-file analysis |
| ast-grep match | -0.03 | Pattern-only, no cross-file |
| Manifest match (go.mod, package.json) | +0.0 (baseline) | Version/dependency source of truth |
| grep match (single pattern) | -0.05 | False positives possible |
| grep match (complex regex) | -0.10 | Higher false positive rate |
| Heuristic (directory name only) | -0.15 | Weakest signal |

---

## USAGE IN PHASES

### Phase: DETECT (tree-sitter integration)

```yaml
detection_flow:
  1_register: "Register project with tree-sitter MCP"
  2_language: "Use list_languages to verify support"
  3_symbols: "get_symbols per file → count by type"
  4_frameworks:
    tier1: "Manifest parsing (go.mod, package.json)"
    tier2: "run_query with import patterns → confirm framework imports"
    tier3: "grep fallback if tree-sitter unavailable"
  5_testing: "run_query with test patterns → count table-driven, subtests, assertions"
  6_record: "Set detection_method per finding"
```

### Phase: GRAPH (new — tree-sitter powered)

```yaml
graph_flow:
  1_symbols: "get_symbols for all files → build symbol table"
  2_dependencies: "get_dependencies → build file-level dependency graph"
  3_usage: "find_usage for exported symbols → build call graph"
  4_pagerank: "Apply PageRank to dependency graph"
  5_budget: "Token-budget repo-map for context windows"
  6_output: "state.graph with ranked symbol map"
```

**SEE:** `subagents/graph.md` for full GRAPH subagent specification.

### Phase: ANALYZE (repo-map as input context)

```yaml
analysis_enhancement:
  input: "state.graph.repo_map (token-budgeted)"
  benefit: "Analysis subagent sees pre-ranked symbols → faster architecture detection"
  usage:
    - "Hub symbols → likely domain/core layer"
    - "High fan-in symbols → interfaces, contracts"
    - "Clusters → layer boundaries"
    - "Import patterns → dependency flow pre-computed"
```

---

## LANGUAGE SUPPORT MATRIX

| Language | tree-sitter MCP | ast-grep | Patterns in this file |
|----------|----------------|----------|-----------------------|
| Go | ✅ Full | ✅ Full | ✅ Complete |
| Python | ✅ Full | ✅ Full | ✅ Complete |
| TypeScript | ✅ Full | ✅ Full | ✅ Complete |
| Rust | ✅ Full | ✅ Full | ✅ Complete |
| Java | ✅ Full | ✅ Full | ✅ Complete |
| C/C++ | ✅ Full | ✅ Full | Partial (on demand) |
| Ruby | ✅ via pack | ❌ | On demand |
| PHP | ✅ via pack | ❌ | On demand |
| Swift | ✅ Full | ❌ | On demand |
| Kotlin | ✅ via pack | ❌ | On demand |
| Scala | ✅ via pack | ❌ | On demand |

**tree-sitter total:** 31 languages via tree-sitter-language-pack
**ast-grep total:** ~10 languages

---

## SEE ALSO

- `subagents/graph.md` — GRAPH subagent (builds repo-map)
- `subagents/detection.md` — DETECT subagent (uses tree-sitter for detection)
- `subagents/analysis.md` — ANALYZE subagent (receives repo-map)
- `deps/ast-analysis.md` — Legacy ast-grep patterns (deprecated, retained as fallback reference)
