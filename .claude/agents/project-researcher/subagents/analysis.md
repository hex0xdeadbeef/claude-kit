# SUBAGENT: ANALYSIS
**Model:** opus
**Phases:** ANALYZE + MAP + DATABASE (optional)
**Input:** state.validate (path, mode), state.discover.*, state.detect.*, **state.graph.*** (v4.2)
**Output:** state.analyze + state.map + state.database

---

## REPO-MAP CONTEXT (v4.2)

This subagent receives `state.graph.repo_map.content` — a pre-ranked symbolic map of the project built by the GRAPH subagent. The repo-map provides:

- **Hub files:** Files with highest PageRank (most depended upon) → likely domain/core layer
- **Symbol signatures:** Function/method/type signatures grouped by file
- **Dependency structure:** Pre-computed import relationships

**How to use repo-map:**
1. **Architecture detection:** Hub files clustered in specific directories → strong architecture signal
2. **Layer identification:** Files grouped by fan-in/fan-out pattern → layer boundaries
3. **Interface detection:** Types with kind="interface" in hub files → architectural contracts
4. **Convention discovery:** Naming patterns visible across top-ranked symbols

**If repo-map is unavailable** (graph phase failed or partial): Fall back to direct AST/grep analysis as in v4.1. The repo-map is an optimization, not a hard dependency.

---

## ANALYZE PHASE (Phase 4)

Your goal: Extract deep structural insights using repo-map context + AST analysis, with grep as fallback. Identify architecture patterns, layer organization, dependency flow, and coding conventions.

### 3.1 Architecture Pattern Detection

Detect the overall architecture pattern using a two-stage approach: directory structure baseline + AST confirmation.

**Supported Patterns:**
- **Clean Architecture:** domain/, application/, infrastructure/, interfaces/ directories; domain has no external imports
- **Hexagonal (Ports & Adapters):** domain/, ports/, adapters/, app/ directories; interfaces in ports/
- **MVC:** models/, views/, controllers/ directories; controllers import models
- **Layered:** layers/ or explicit layer dirs (presentation/, business/, persistence/, data/); strict layering rules enforced
- **DDD (Domain-Driven Design):** bounded contexts as subdirs; each context has entities/, repositories/, services/; shared/ for shared kernel
- **Microservices:** cmd/ with multiple service binaries; each with own internal/ structure
- **Modular Monolith:** go.mod in root; internal/ with logical modules; module interdependencies tracked
- **Standard Go:** cmd/, internal/, pkg/ structure; internal/ is private, pkg/ is public library code

**Detection Process:**

1. **Repo-Map Analysis (v4.2, preferred if state.graph available):**
   - Inspect `state.graph.repo_map.content` for hub files → which directories contain most-depended symbols?
   - Check `state.graph.dependency_graph.hub_files` → do hub files cluster in domain/core directories?
   - Inspect `state.graph.symbol_table.by_kind` → high interface count in specific dirs → ports/contracts layer
   - Use `state.graph.dependency_graph.circular_deps` → clean architecture has zero domain→infra cycles
   - This pre-analysis from repo-map provides initial confidence BEFORE file-level AST analysis

2. **Directory Structure Baseline:**
   - List all top-level directories and meaningful subdirs in project root
   - Match against pattern templates
   - Record initial match with confidence: HIGH (strong match), MEDIUM (partial match), LOW (weak/no match)

3. **AST Evidence Confirmation:**
   - For each layer directory (e.g., internal/domain/, infrastructure/):
     - Count total interfaces (type X interface{})
     - Count total structs (type X struct{})
     - Count implementation verify lines (var _ Interface = (*Impl)(nil))
   - For domain/core layer:
     - Verify zero external package imports (only stdlib + internal)
     - Count custom error types (type X struct { /* ... */ } or type X string/error)
   - For each application layer:
     - Count how many imports point to domain layer (inbound dependencies)
   - For infrastructure layer:
     - Count how many external dependencies (pgx, redis, http, etc.)
   - Record architecture_evidence array: each entry is {indicator: "string", weight: 0.0-1.0}

4. **Confidence Calculation:**
   - Repo-map + directory structure + AST confirmation = VERY HIGH (0.90+)
   - Directory structure match + AST confirmation = HIGH (0.85+)
   - Repo-map + directory structure only = HIGH (0.80-0.89)
   - Directory structure match only = MEDIUM (0.60-0.84)
   - AST patterns only = MEDIUM (0.60-0.84)
   - Weak signals only = LOW (< 0.60)

**Output Fields:**
```
analyze:
  architecture:
    primary_pattern: "clean|hexagonal|mvc|layered|ddd|microservices|modular_monolith|standard_go"
    confidence: 0.85
    reasoning: "Clean architecture detected: domain/ has 8 interfaces, 12 entities; infrastructure/ isolated; zero cross-layer violations"
  architecture_evidence:
    - indicator: "domain_layer_isolation"
      weight: 0.95
      detail: "domain/ imports only stdlib and internal packages"
    - indicator: "interface_count_domain"
      weight: 0.88
      detail: "domain/ contains 8 interfaces (ports)"
    - indicator: "implementation_verification"
      weight: 0.92
      detail: "Found 6 compile-time interface verification patterns"
    - indicator: "directory_structure"
      weight: 0.85
      detail: "domain/, application/, infrastructure/, interfaces/ detected"
```

### 3.2 Layer Analysis

For each identified layer, extract package structure and layer-level statistics using AST.

**Layer Detection:**
- List all internal/* subdirectories (or top-level dirs if no internal/)
- Each subdir is a candidate layer
- For each layer:
  1. **Package Count:** How many Go packages (directories with .go files)?
  2. **AST Interface Count:** How many interface{} types defined?
  3. **AST Struct Count:** How many struct types defined?
  4. **AST Function Count:** How many public functions (Start with capital)?
  5. **AST Method Count:** How many receiver methods on types?
  6. **Import Analysis:** What packages does this layer import?
     - Count imports to stdlib vs. internal vs. external
     - List top 5 external dependencies by frequency

**Layer Hierarchy (if inferrable):**
- Core/domain layer: typically zero external imports, defines interfaces
- Application layer: imports core, implements core interfaces, imports infrastructure
- Infrastructure layer: imports external packages and application layer

**Grep Fallback (if AST unavailable):**
- Count .go files and packages per layer
- Estimate interface count via: `grep -r "^type .* interface" layer_dir | wc -l`
- Estimate struct count via: `grep -r "^type .* struct" layer_dir | wc -l`

**Output Fields:**
```
analyze:
  layers:
    - name: "domain"
      path: "internal/domain"
      package_count: 5
      interface_count: 8
      struct_count: 12
      function_count: 34
      method_count: 45
      external_imports: ["encoding/json", "fmt"] # stdlib only
      internal_imports: [] # should be empty
      confidence: 0.95
    - name: "application"
      path: "internal/application"
      package_count: 3
      interface_count: 2
      struct_count: 8
      function_count: 24
      method_count: 18
      external_imports: ["github.com/go-chi/chi"] # external libs OK
      internal_imports: ["internal/domain"] # should point inward
      confidence: 0.92
    - name: "infrastructure"
      path: "internal/infrastructure"
      package_count: 4
      interface_count: 0
      struct_count: 6
      function_count: 18
      method_count: 22
      external_imports: ["database/sql", "github.com/lib/pq"]
      internal_imports: ["internal/domain", "internal/application"]
      confidence: 0.90
  layer_count: 3
  core_layer: "domain"
```

### 3.3 Dependency Flow Analysis

Validate that dependencies flow correctly (inward to domain, not outward).

**Rules:**
1. Domain layer must not import application or infrastructure
2. Application layer can import domain but not infrastructure
3. Infrastructure can import anything (it's the boundary)
4. All layers can import stdlib and external packages
5. No circular dependencies within layers

**Analysis Process (AST-first):**
1. For each .go file in each layer, extract import statements
2. Parse import paths to identify:
   - Stdlib imports (no "." in path, e.g., "fmt", "encoding/json")
   - Internal imports (start with "module_name/internal/", e.g., "github.com/user/repo/internal/domain")
   - External imports (contain "." and not internal, e.g., "github.com/lib/pq")
3. For internal imports, determine target layer
4. Check: does source_layer import target_layer?
5. If violation: record as dependency_violation

**Grep Fallback:**
- For each layer, extract imports via: `grep -h "^import" layer_dir/**/*.go | sort | uniq`
- Parse to identify layer violations

**Violations:**
- If domain imports application or infrastructure → HIGH SEVERITY
- If application imports infrastructure directly → MEDIUM (acceptable if infrastructure exports domain interfaces)
- If circular imports detected → HIGH SEVERITY

**Output Fields:**
```
analyze:
  dependency_flow:
    valid_flow: true
    violations: []
    # OR if violations exist:
    violations:
      - from_layer: "domain"
        to_layer: "infrastructure"
        file: "internal/domain/entity.go"
        import_path: "internal/infrastructure/database"
        severity: "high"
        detail: "Domain should not import infrastructure directly"
      - from_layer: "application"
        to_layer: "infrastructure"
        file: "internal/application/service.go"
        import_path: "internal/infrastructure/http"
        severity: "low"
        detail: "Application importing infrastructure is acceptable if interfaces are properly abstracted"
    circular_dependencies: []
    # OR if circular deps exist:
    circular_dependencies:
      - cycle: ["package_a", "package_b", "package_a"]
        severity: "high"
    summary: "Dependency flow valid: domain isolated, application imports domain only, infrastructure imports both"
```

### 3.4 Convention Discovery

Identify naming conventions, error handling patterns, logging approach, and testing style.

**3.4.1 Naming Conventions:**

Via AST: parse all identifiers from .go files across the project
- File naming: Check .go filenames → snake_case or camelCase?
- Type naming: Extract `type X struct/interface` → all PascalCase? (Go convention)
- Function naming: Extract `func Name()` → public PascalCase, private camelCase?
- Constant naming: Extract `const X = ...` → UPPER_CASE or other?
- Package naming: Check package declarations → all lowercase? (Go convention)
- Method naming: Extract `func (r *Receiver) Method()` → naming style

Via Grep fallback:
- File naming: `ls -1 *.go | grep [a-z]_[a-z]` → count snake_case
- Type naming: `grep "^type [A-Z]" *.go | wc -l` → percentage of PascalCase

**3.4.2 Error Handling:**

Via AST: scan all error-related code
- Count `fmt.Errorf("%w", err)` usage → modern pattern
- Count `errors.New("string")` usage → basic pattern
- Count custom error types: `type X struct { /* ... */ }` implementing Error() → advanced
- Count sentinel errors: `var ErrX = errors.New("...")` pattern
- Check for error wrapping: `%w` usage indicates error chain awareness

Via Grep fallback:
- `grep -c "fmt.Errorf.*%w" **/*.go` → count
- `grep -c "errors.New" **/*.go` → count
- `grep "^var Err" **/*.go` → list sentinel errors

**3.4.3 Logging:**

Via AST: identify logging framework and usage intensity
- Count `slog.Log|Info|Warn|Error` calls → slog usage
- Count `zap.L|S|SugaredLogger` calls → zap usage
- Count `logrus.` calls → logrus usage
- Count `log.Print` calls → stdlib usage
- Determine primary logger from frequency

Via Grep fallback:
- `grep -c "slog\." **/*.go` → count
- `grep -c "zap\." **/*.go` → count
- `grep -c "logrus\." **/*.go` → count

**3.4.4 Testing:**

Via AST: analyze test structure
- Count `func Test*` functions
- Count subtests: `t.Run("name", func(t *testing.T) { ... })`
- Count test helpers: `func (t *T) Helper()` → indicates well-organized test helpers
- Count table-driven tests: `for _, tt := range tests` pattern
- Count test setup: `func TestMain(m *testing.M)`, `func setup()`, `func teardown()`

Via Grep fallback:
- `grep -c "func Test" **/*_test.go` → total tests
- `grep -c "t.Run(" **/*_test.go` → subtests
- `grep -c "t.Helper()" **/*_test.go` → test helpers

**Output Fields:**
```
analyze:
  conventions:
    naming:
      file_style: "snake_case"
      type_style: "PascalCase"
      function_style: "PascalCase|camelCase"
      constant_style: "UPPER_CASE|MixedCase"
      package_style: "lowercase"
      confidence: 0.98
    error_handling:
      primary_pattern: "error_wrapping" # or "basic" or "custom_types"
      fmt_errorf_with_w: 45
      errors_new_count: 12
      custom_error_types: 3
      sentinel_errors: 7
      summary: "Modern error wrapping with fmt.Errorf(%w) is primary pattern; 45 instances found"
    logging:
      framework: "slog" # or "zap", "logrus", "stdlib"
      slog_count: 67
      zap_count: 0
      logrus_count: 0
      stdlib_count: 5
      summary: "slog is primary logging framework; 67 calls across codebase"
    testing:
      test_count: 34
      subtests_count: 28
      test_helpers_count: 6
      table_driven_count: 12
      test_setup_functions: 2
      summary: "Well-organized testing: 28 subtests, 6 test helpers, 12 table-driven tests"
```

---

## MAP PHASE (Phase 5)

Your goal: Create detailed maps of entry points, core domain, design patterns, integrations, and dependency graphs.

### 4.1 Entry Points

Identify all user-facing or system-facing entry points.

**Entry Point Types:**

1. **`func main()`** (CLI/binary entry point)
   - AST: Find `func main()` in cmd/ or root directory
   - Extract CLI framework: cobra, urfave/cli, flag, or none

2. **HTTP Handlers** (REST/HTTP API entry points)
   - AST pattern: `func(w http.ResponseWriter, r *http.Request)`
   - Find via: `grep -r "http.ResponseWriter, \*http.Request" **/*.go`
   - Extract: handler name, path, HTTP method if inferable
   - HTTP framework: chi, gin, echo, gorilla/mux, stdlib mux, or raw http

3. **gRPC Service Methods** (gRPC API entry points)
   - AST: Find protobuf-generated receiver methods on *Server types
   - Pattern: `func (s *Service) MethodName(ctx context.Context, req *pb.Request) (*pb.Response, error)`
   - Extract: service name, method name, request/response types

4. **Cobra Commands** (CLI commands)
   - AST: Find `&cobra.Command{}` initializations
   - Extract: command name, parent command, Run function

5. **Worker/Background Job Entry Points**
   - AST: Find methods named `Run()`, `Start()`, `Execute()` on worker types
   - Pattern: triggered by scheduler, message queue consumer, etc.

6. **Message Queue Consumers** (Kafka, RabbitMQ, NATS)
   - AST: Find consumer type definitions and handler registrations
   - Pattern: `Consumer.Subscribe()`, `consumer.Handle()`, handler functions

**Analysis Process (AST-first):**

For each entry point type:
1. Search codebase for the AST pattern
2. Extract: entry point name, signature, location (file + line)
3. For HTTP handlers: infer HTTP method from router registration if possible
4. For gRPC: link to .proto definitions
5. Count total entry points per type

**Grep Fallback:**
- Main: `grep -r "^func main()" cmd/ **/*.go`
- HTTP handlers: `grep -r "http.ResponseWriter, \*http.Request" **/*.go`
- gRPC: `grep -r "func (s \*.*Server)" **/*.go`
- Cobra: `grep -r "&cobra.Command" **/*.go`

**Output Fields:**
```
map:
  entry_points:
    - type: "main"
      name: "main"
      file: "cmd/server/main.go"
      framework: "cobra"
      description: "Main CLI entry point with cobra command structure"
      count: 1
    - type: "http_handler"
      framework: "chi"
      count: 12
      handlers:
        - name: "GetUserHandler"
          file: "internal/interface/http/handler_user.go"
          method: "GET"
          path: "/api/users/:id"
        - name: "CreateUserHandler"
          file: "internal/interface/http/handler_user.go"
          method: "POST"
          path: "/api/users"
      # ... more handlers
    - type: "grpc_service"
      framework: "grpc"
      count: 2
      services:
        - name: "UserService"
          file: "internal/interface/grpc/service_user.go"
          methods:
            - method: "GetUser"
              request_type: "pb.GetUserRequest"
              response_type: "pb.GetUserResponse"
    - type: "worker"
      count: 1
      workers:
        - name: "EmailWorker"
          file: "internal/worker/email.go"
          trigger: "message queue consumer"
  entry_point_count: 16
  primary_style: "http+cobra"
```

### 4.2 Core Domain

Identify domain entities, aggregates, and value objects (or equivalent abstractions).

**Analysis Process (AST-first):**

1. **Domain Layer Identification:**
   - Locate domain or core layer (typically `internal/domain/` or `internal/core/`)

2. **Entity Detection:**
   - Extract all struct types from domain layer
   - Filter: entities typically have IDs, are mutable, have lifecycle
   - Check for patterns:
     - Has `ID` or `Id` field
     - Has timestamp fields (CreatedAt, UpdatedAt, DeletedAt)
     - Large struct (many fields) suggests entity vs. value object

3. **Interface Detection (Ports):**
   - Extract all interface types from domain or ports layer
   - Classify:
     - Repository interfaces: `Get*`, `Create*`, `Update*`, `Delete*`, `List*` methods
     - Service interfaces: business logic contracts
     - External integrations: payment, email, storage interfaces
   - Record: interface name, methods, expected implementations

4. **Compile-time Verification:**
   - Search for patterns: `var _ Interface = (*Implementation)(nil)`
   - These indicate explicit interface satisfaction
   - Pair implementation with interface

5. **Aggregate Patterns:**
   - If struct contains other structs as fields → possible aggregate root
   - If struct has *Repository field → entity with persistence port
   - If struct embeds other types → value object composition

**Grep Fallback:**
- Domain structs: `grep -r "^type [A-Z].*struct" internal/domain/ **/*.go`
- Domain interfaces: `grep -r "^type [A-Z].*interface" internal/domain/ **/*.go`
- Repositories: `grep -r "type.*Repository interface" **/*.go`

**Mapping Implementations to Interfaces:**
- For each interface, grep for `type X struct` in implementation layers
- Check if implementation file imports the interface
- Infer based on naming conventions (e.g., UserRepository interface → UserPostgresRepository struct)

**Output Fields:**
```
map:
  core_domain:
    entities:
      - name: "User"
        file: "internal/domain/user.go"
        fields:
          - name: "ID"
            type: "string"
            tag: "pk"
          - name: "Email"
            type: "string"
          - name: "CreatedAt"
            type: "time.Time"
          - name: "UpdatedAt"
            type: "time.Time"
        is_aggregate_root: true
        description: "Core user entity with email and timestamp tracking"
      - name: "Order"
        file: "internal/domain/order.go"
        fields:
          - name: "ID"
            type: "string"
          - name: "UserID"
            type: "string"
          - name: "Items"
            type: "[]OrderItem"
          - name: "Total"
            type: "decimal.Decimal"
        is_aggregate_root: true
        description: "Order aggregate with line items"
    interfaces:
      - name: "UserRepository"
        file: "internal/domain/repository.go"
        methods:
          - name: "GetByID"
            signature: "GetByID(ctx context.Context, id string) (*User, error)"
          - name: "Create"
            signature: "Create(ctx context.Context, user *User) error"
          - name: "Update"
            signature: "Update(ctx context.Context, user *User) error"
        implementations:
          - name: "UserPostgresRepository"
            file: "internal/infrastructure/postgres/user_repository.go"
            verified: true # var _ UserRepository = (*UserPostgresRepository)(nil)
      - name: "EmailService"
        file: "internal/domain/service.go"
        methods:
          - name: "Send"
            signature: "Send(ctx context.Context, to string, subject string, body string) error"
        implementations:
          - name: "EmailServiceImpl"
            file: "internal/infrastructure/email/service.go"
            verified: true
    value_objects: []
    entity_count: 2
    interface_count: 6
```

### 4.3 Design Patterns

Identify common design patterns used in the codebase.

**Patterns to Detect (via AST):**

1. **Constructor Pattern:**
   - Function named `NewX` or `New*X` returning an instance
   - Detects: `func New*(args) *Type { ... }`

2. **Factory Pattern:**
   - Function or method returning interface type (polymorphism)
   - Detects: `func Create*(args) Interface { ... }`

3. **Builder Pattern:**
   - Type with `With*` methods and final `Build()` method
   - Detects: `func (b *Builder) With*(arg) *Builder` and `Build() Type`

4. **Strategy Pattern:**
   - Interface with multiple implementations
   - Detects: interface with ≥2 implementations

5. **Middleware Pattern:**
   - Function returning function signature
   - Detects: `func Middleware*(...) func(Handler) Handler` or similar

6. **Repository Pattern:**
   - Interface with CRUD-like methods
   - Detects: interface containing Get*, Create*, Update*, Delete*, List*

7. **Dependency Injection:**
   - Constructor takes interfaces/configs as parameters
   - Use of container libraries: wire, dig, fx
   - Detects: constructor with >2 interface parameters

8. **Singleton/Service Locator:**
   - Global instance or registry
   - Detects: `var Global*` or `func Get*Service() Service`

**Analysis Process (AST):**

For each pattern:
1. Search for canonical AST signatures
2. Count occurrences
3. List examples (type name, file location)
4. Confidence: based on naming conventions and AST matches

**Grep Fallback:**
- Constructors: `grep -r "^func New" **/*.go | wc -l`
- Builders: `grep -r "\.With.*func" **/*.go`
- Middleware: `grep -r "func.*Middleware" **/*.go`

**Output Fields:**
```
map:
  design_patterns:
    - pattern: "constructor"
      count: 28
      examples:
        - "NewUserRepository"
        - "NewEmailService"
        - "NewHTTPServer"
      confidence: 0.98
      detail: "Standard Go pattern; all domain types have New* constructors"
    - pattern: "factory"
      count: 4
      examples:
        - "func CreateLogger(config Config) Logger"
        - "func CreateDatabase(dsn string) Database"
      confidence: 0.85
      detail: "Factory methods for complex type creation"
    - pattern: "builder"
      count: 2
      examples:
        - "QueryBuilder"
        - "RequestBuilder"
      confidence: 0.92
      detail: "Builder pattern for complex object construction"
    - pattern: "strategy"
      count: 6
      examples:
        - "Handler interface with multiple implementations"
        - "Logger interface with slog/zap implementations"
      confidence: 0.90
      detail: "Strategy pattern for pluggable algorithms"
    - pattern: "middleware"
      count: 5
      examples:
        - "AuthMiddleware"
        - "LoggingMiddleware"
        - "RateLimitMiddleware"
      confidence: 0.88
      detail: "HTTP middleware chain pattern"
    - pattern: "repository"
      count: 3
      examples:
        - "UserRepository"
        - "OrderRepository"
        - "ProductRepository"
      confidence: 0.95
      detail: "Repository pattern for data access abstraction"
    - pattern: "dependency_injection"
      count: 1
      di_framework: "wire"
      examples:
        - "cmd/server/wire_gen.go (generated)"
      confidence: 0.98
      detail: "Google Wire for compile-time DI"
```

### 4.4 External Integrations

Identify all external service integrations.

**Data Source: go.mod Analysis:**

Parse go.mod file:
1. Extract all `require` statements
2. For each dependency, classify by category:
   - **Database:** pgx, mysql, mongodb, sqlite, sqlc
   - **Cache:** redis, memcached
   - **Message Queue:** kafka, rabbitmq, nats, pubsub
   - **HTTP Client:** resty, axios, httpclient
   - **Cloud Services:** aws-sdk, google-cloud-go, azure-sdk-for-go
   - **Observability:** prometheus, datadog, jaeger, opentelemetry
   - **API Gateway:** kong, traefik
   - **Container/Orchestration:** docker-sdk, k8s client
   - **Testing:** testify, ginkgo

**AST Cross-Reference:**

For identified external packages:
1. Search for usage in codebase: `grep -r "import.*[external_package]" **/*.go`
2. Count occurrences
3. Identify wrapper/adapter layers
4. Check for dependency on interfaces (abstraction) vs. direct usage

**Integration Adapter Detection:**

Look for adapter patterns:
- Types that wrap external library types
- Interfaces that abstract external dependencies
- Example: `type PostgresUserRepository struct { db *pgx.Conn }`

**Output Fields:**
```
map:
  external_integrations:
    databases:
      - name: "PostgreSQL"
        package: "github.com/jackc/pgx/v5"
        version: "v5.4.2"
        usage_count: 23
        files:
          - "internal/infrastructure/postgres/repository.go"
          - "internal/infrastructure/postgres/migrations.go"
        wrapper: "internal/infrastructure/db/postgres.go"
        abstraction_level: "high" # wrapped by interface
      - name: "Redis"
        package: "github.com/redis/go-redis/v9"
        version: "v9.0.1"
        usage_count: 8
        files:
          - "internal/infrastructure/cache/redis.go"
        wrapper: "internal/infrastructure/cache/cache.go"
        abstraction_level: "high"
    message_queues:
      - name: "NATS"
        package: "github.com/nats-io/nats.go"
        version: "v1.25.0"
        usage_count: 12
        files:
          - "internal/infrastructure/queue/nats_consumer.go"
        wrapper: "internal/infrastructure/queue/consumer.go"
        abstraction_level: "high"
    observability:
      - name: "Prometheus"
        package: "github.com/prometheus/client_golang"
        version: "v1.14.0"
        usage_count: 5
        files:
          - "internal/infrastructure/metrics/prometheus.go"
        detail: "HTTP metrics via promhttp"
      - name: "slog (structured logging)"
        package: "log/slog" # stdlib
        usage_count: 67
        detail: "Primary logging framework"
    http_framework:
      - name: "chi (HTTP router)"
        package: "github.com/go-chi/chi/v5"
        version: "v5.0.8"
        usage_count: 15
        wrapper: "internal/interface/http/router.go"
    cloud_services: []
    di_framework:
      - name: "Google Wire"
        package: "github.com/google/wire"
        files:
          - "cmd/server/wire.go"
        generated_file: "cmd/server/wire_gen.go"
  integration_count: 8
  abstraction_summary: "Well-abstracted integrations; primary databases/queues/services wrapped in domain-level interfaces"
```

### 4.5 Dependency Graph

Build a detailed package dependency map and compute metrics.

**Analysis Process (Best to Fallback):**

**Option 1: go list (BEST):**
```bash
go list -json ./... | jq '.[] | {ImportPath, Imports}'
```
For each package:
1. Parse ImportPath (package name)
2. Parse Imports (list of imported packages)
3. Filter to internal imports only (starts with module name)
4. Exclude vendor/, testdata/

**Option 2: AST Fallback:**
For each .go file:
1. Parse `import` statements
2. Extract import paths
3. Group by source package (directory)
4. Build graph: source_package → [imported_packages]

**Option 3: Grep Fallback:**
```bash
grep -h "^import" **/*.go | grep internal | sort | uniq
```

**Graph Construction:**

1. Create nodes: each internal package is a node
2. Create edges: if A imports B, add edge A→B
3. Compute metrics per package:
   - **Fan-in:** how many packages import this one? (incoming edges)
   - **Fan-out:** how many packages does this import? (outgoing edges)

**Metrics Computation:**

1. **Hub Packages:** Top 5 packages by fan-in (most depended upon)
   - High fan-in = core, stable, foundational

2. **God Packages:** Packages with fan-out > 10 (importing too much)
   - High fan-out = may be doing too much, violates SRP

3. **Isolated Packages:** Packages with fan-in = 0 and used nowhere
   - These are root/leaf packages or may be dead code

4. **Circular Dependencies:** Detect cycles in graph
   - Run `go vet` or implement cycle detection (DFS)

5. **Depth Map:** Compute longest path from entry points to core
   - Level 0: core domain packages
   - Level N: packages N steps away from core

**Output Fields:**
```
map:
  dependency_graph:
    packages:
      count: 34
      by_layer:
        domain: 5
        application: 8
        infrastructure: 12
        interface: 6
        cmd: 3
    metrics:
      hub_packages:
        - name: "internal/domain"
          fan_in: 8
          fan_out: 1
          description: "Core domain layer; imported by most packages"
        - name: "internal/domain/entity"
          fan_in: 7
          fan_out: 0
          description: "Core entities; foundational"
        - name: "internal/application/service"
          fan_in: 5
          fan_out: 3
          description: "Application services; central business logic"
      god_packages:
        - name: "cmd/server"
          fan_in: 0
          fan_out: 11
          description: "Entry point; imports everything; acceptable"
      isolated_packages:
        - name: "internal/config"
          fan_in: 2
          fan_out: 0
          description: "Configuration; leaf package"
      circular_dependencies: []
      max_depth: 4
      depth_distribution:
        "level_0": 5 # core domain
        "level_1": 8 # application/services
        "level_2": 12 # infrastructure
        "level_3": 6 # interfaces
        "level_4": 3 # entry points (cmd)
    graph_structure: "layered_acyclic"
    summary: "Well-structured dependency graph; domain is core hub, no circular dependencies, clear layering"
```

---

## DATABASE SECTION (Phase 5.6, Optional)

**Condition:** Only execute if PostgreSQL is detected in dependencies AND `mcp__postgres` tools are available.

If condition not met: set `database.available = false` and `database.reason`.

**Schema Discovery:**

If PostgreSQL is detected:
1. Check if MCP PostgreSQL tools are available via system capability check
2. If available, connect to database (if credentials available in environment/config)
3. Execute: List all tables, columns, constraints, indexes
4. Parse schema information

**Entity-Table Mapping:**

For each domain entity identified in 4.2:
1. Infer table name: snake_case(EntityName) or configured via tags
2. Search schema for matching table
3. For each entity field:
   - Find corresponding column in table
   - Compare types: time.Time → TIMESTAMP, string → VARCHAR, etc.
   - Check for nullable mismatch
4. Record: alignment status (aligned/mismatch/unmapped)

**Alignment Report:**

```
database:
  available: true
  connection_status: "connected"
  dialect: "postgresql"
  tables_found: 5
  schema_mapping:
    - entity_name: "User"
      table_name: "users"
      alignment: "aligned"
      fields:
        - entity_field: "ID"
          column_name: "id"
          entity_type: "string"
          db_type: "uuid"
          nullable_match: true
        - entity_field: "Email"
          column_name: "email"
          entity_type: "string"
          db_type: "varchar(255)"
          nullable_match: true
          unique: true
      indexes:
        - "idx_users_email"
      constraints:
        - "pk_users_id"
    - entity_name: "Order"
      table_name: "orders"
      alignment: "aligned"
      fields:
        - entity_field: "ID"
          column_name: "id"
          entity_type: "string"
          db_type: "uuid"
          nullable_match: true
        - entity_field: "UserID"
          column_name: "user_id"
          entity_type: "string"
          db_type: "uuid"
          nullable_match: true
        - entity_field: "Total"
          column_name: "total_amount"
          entity_type: "decimal.Decimal"
          db_type: "numeric(19,2)"
          nullable_match: true
      foreign_keys:
        - "fk_orders_user_id → users.id"
      indexes:
        - "idx_orders_user_id"
        - "idx_orders_created_at"
  unmapped_tables:
    - "audit_log"
    - "session"
  summary: "Good alignment; 2/2 entities mapped to tables; 2 unmapped tables (audit, session) for infrastructure use"
```

If no database connection available:
```
database:
  available: false
  reason: "PostgreSQL in dependencies but no MCP postgres tools available; set environment variables to enable schema discovery"
```

---

## Step Quality Checklist

For this subagent to pass, ALL of these must be true:

- [ ] **Architecture identified:** primary_pattern set, confidence ≥ 0.70, reasoning provided
- [ ] **Layers analyzed:** ≥ 3 layers identified with package counts, interface counts, external imports documented
- [ ] **Dependency flow validated:** valid_flow = true OR violations documented with severity
- [ ] **Conventions documented:** naming, error handling, logging, testing styles all identified
- [ ] **≥ 1 entry point found:** at least one entry point (main, HTTP handler, gRPC, etc.) identified
- [ ] **≥ 1 domain entity found:** at least one entity with ID field and timestamp fields identified
- [ ] **Design patterns detected:** ≥ 2 patterns identified with examples
- [ ] **External integrations mapped:** ≥ 1 external dependency identified and wrapped status documented
- [ ] **Dependency graph computed:** package count, fan-in/fan-out for hub packages, circular deps checked
- [ ] **Progress summary provided:** concise one-liner showing key findings

---

## Output Format

Return state updates as YAML:

```yaml
subagent_result:
  status: "success"
  state_updates:
    analyze:
      architecture: "clean"
      architecture_confidence: 0.88
      architecture_evidence:
        - indicator: "domain_layer_isolation"
          weight: 0.95
      layers:
        - name: "domain"
          path: "internal/domain"
          package_count: 5
          interface_count: 8
          struct_count: 12
          external_imports: ["fmt", "time"]
          internal_imports: []
          confidence: 0.95
        - name: "application"
          path: "internal/application"
          package_count: 3
          interface_count: 2
          struct_count: 8
          external_imports: ["context"]
          internal_imports: ["internal/domain"]
          confidence: 0.92
        - name: "infrastructure"
          path: "internal/infrastructure"
          package_count: 4
          interface_count: 0
          struct_count: 6
          external_imports: ["github.com/lib/pq", "github.com/redis/go-redis/v9"]
          internal_imports: ["internal/domain", "internal/application"]
          confidence: 0.90
      layer_count: 3
      core_layer: "domain"
      dependency_flow:
        valid_flow: true
        violations: []
        circular_dependencies: []
        summary: "Dependency flow valid: domain isolated, application imports domain, infrastructure imports both"
      conventions:
        naming:
          file_style: "snake_case"
          type_style: "PascalCase"
          function_style: "PascalCase"
          confidence: 0.98
        error_handling:
          primary_pattern: "error_wrapping"
          fmt_errorf_with_w: 45
          errors_new_count: 12
          summary: "Modern error wrapping with fmt.Errorf(%w)"
        logging:
          framework: "slog"
          slog_count: 67
          summary: "slog is primary logging framework"
        testing:
          test_count: 34
          subtests_count: 28
          test_helpers_count: 6
          summary: "Well-organized testing with subtests and helpers"
    map:
      entry_points:
        - type: "main"
          count: 1
          framework: "cobra"
        - type: "http_handler"
          count: 12
          framework: "chi"
        - type: "grpc_service"
          count: 2
          framework: "grpc"
        - type: "worker"
          count: 1
      entry_point_count: 16
      core_domain:
        entities:
          - name: "User"
            file: "internal/domain/user.go"
            is_aggregate_root: true
            field_count: 5
          - name: "Order"
            file: "internal/domain/order.go"
            is_aggregate_root: true
            field_count: 6
        entity_count: 2
        interface_count: 6
      design_patterns:
        - pattern: "constructor"
          count: 28
          confidence: 0.98
        - pattern: "repository"
          count: 3
          confidence: 0.95
        - pattern: "middleware"
          count: 5
          confidence: 0.88
      external_integrations:
        databases:
          - name: "PostgreSQL"
            package: "github.com/jackc/pgx/v5"
            usage_count: 23
            abstraction_level: "high"
        cache:
          - name: "Redis"
            package: "github.com/redis/go-redis/v9"
            usage_count: 8
            abstraction_level: "high"
        message_queues:
          - name: "NATS"
            package: "github.com/nats-io/nats.go"
            usage_count: 12
            abstraction_level: "high"
        integration_count: 8
      dependency_graph:
        packages:
          count: 34
        metrics:
          hub_packages:
            - name: "internal/domain"
              fan_in: 8
              fan_out: 1
          god_packages: []
          circular_dependencies: []
          max_depth: 4
        graph_structure: "layered_acyclic"
    database:
      available: true
      connection_status: "connected"
      dialect: "postgresql"
      tables_found: 5
      schema_mapping:
        - entity_name: "User"
          table_name: "users"
          alignment: "aligned"
          field_count: 5
        - entity_name: "Order"
          table_name: "orders"
          alignment: "aligned"
          field_count: 6
      summary: "Good alignment; 2/2 entities mapped to tables"
  progress_summary: "analyze.architecture=clean (0.88), layers=3, conventions=complete, map.entry_points=16, entry_types=4, entities=2, patterns=7, integrations=8, dep_graph.packages=34, database=postgresql"
  timestamp: "2025-02-23T10:30:00Z"
```

---

## References

- **Tree-Sitter Patterns:** See `deps/tree-sitter-patterns.md` for query patterns (v4.2)
- **Legacy AST Patterns:** See `deps/ast-analysis.md` for ast-grep patterns (deprecated fallback)
- **GRAPH Subagent:** See `subagents/graph.md` for repo-map construction
- **Go Conventions:** https://golang.org/doc/effective_go
- **Clean Architecture:** https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html
- **DDD Patterns:** https://domain-driven-design.org/
