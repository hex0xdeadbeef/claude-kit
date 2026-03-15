# AST-Based Analysis Patterns

**Purpose:** Structural code analysis via ast-grep instead of text-based grep. Eliminates false positives from comments, strings, and imprecise regex matches.

**Principle:** AST sees code semantics, grep sees text. AST analysis yields accurate results on the first pass.

**Load when:** LEGACY FALLBACK ONLY — tree-sitter-patterns.md is the primary reference since v4.2. Load only when tree-sitter MCP is unavailable.

---

## AVAILABILITY CHECK

```bash
# Check ast-grep availability
if command -v ast-grep &>/dev/null || command -v sg &>/dev/null; then
    AST_AVAILABLE=true
    AST_CMD=$(command -v ast-grep || command -v sg)
else
    AST_AVAILABLE=false
    # Try to install
    npm install -g @ast-grep/cli 2>/dev/null && AST_AVAILABLE=true && AST_CMD="ast-grep"
fi

# Record in state
# state.detect.ast_available = $AST_AVAILABLE
```

**Fallback:** If `AST_AVAILABLE=false`, all patterns below have a grep fallback. Grep results are marked with `detection_method: "grep"` in state (lower confidence).

---

## GO PATTERNS

### Interfaces

```bash
# AST: Find all interfaces with methods
ast-grep --pattern 'type $NAME interface { $$$ }' --lang go

# Fallback grep:
grep -rn "type [A-Z][a-zA-Z]* interface {" --include="*.go"
```

### Structs

```bash
# AST: Find all structs
ast-grep --pattern 'type $NAME struct { $$$ }' --lang go

# AST: Structs with specific tags (json, db)
ast-grep --pattern '$FIELD $TYPE `json:"$TAG"`' --lang go
```

### Error Patterns

```bash
# AST: fmt.Errorf with %w (error wrapping)
ast-grep --pattern 'fmt.Errorf($FMT, $$$)' --lang go

# AST: errors.New
ast-grep --pattern 'errors.New($MSG)' --lang go

# AST: Custom error types (struct implementing Error())
ast-grep --pattern 'func ($RECV $TYPE) Error() string { $$$ }' --lang go

# AST: Sentinel errors
ast-grep --pattern 'var $NAME = errors.New($MSG)' --lang go

# Fallback grep:
grep -rn 'fmt.Errorf.*%w' --include="*.go" | wc -l
grep -rn 'errors.New' --include="*.go" | wc -l
```

### Function Signatures

```bash
# AST: Functions accepting context.Context as the first argument
ast-grep --pattern 'func $NAME(ctx context.Context, $$$) $$$' --lang go
ast-grep --pattern 'func ($RECV $TYPE) $NAME(ctx context.Context, $$$) $$$' --lang go

# AST: Functions returning error
ast-grep --pattern 'func $NAME($$$) ($$$, error) { $$$ }' --lang go

# AST: Exported functions (PascalCase — starts with uppercase)
ast-grep --pattern 'func $NAME($$$) $$$' --lang go
# Filter: $NAME starts with [A-Z]
```

### Dependency Injection

```bash
# AST: Constructor pattern (func New*)
ast-grep --pattern 'func New$NAME($$$) $$$' --lang go

# AST: Wire injectors
ast-grep --pattern 'func Initialize$NAME($$$) ($$$, error) { $$$ }' --lang go

# AST: Compile-time interface checks
ast-grep --pattern 'var _ $IFACE = (*$IMPL)(nil)' --lang go
ast-grep --pattern 'var _ $IFACE = &$IMPL{}' --lang go
```

### Import Analysis

```bash
# AST: All import blocks
ast-grep --pattern 'import ($$$)' --lang go

# AST: Specific import
ast-grep --pattern 'import ($$$ "$PACKAGE" $$$)' --lang go

# For dependency violation detection — verify that domain does not import infrastructure:
# 1. Find all imports in domain/
ast-grep --pattern 'import ($$$)' --lang go internal/domain/
# 2. Check for forbidden paths in results
```

### Testing Patterns

```bash
# AST: Table-driven tests
ast-grep --pattern 'tests := []struct { $$$ }{ $$$ }' --lang go
ast-grep --pattern 'tt := []struct { $$$ }{ $$$ }' --lang go
ast-grep --pattern 'cases := []struct { $$$ }{ $$$ }' --lang go

# AST: Testify require/assert
ast-grep --pattern 'require.$METHOD($$$)' --lang go
ast-grep --pattern 'assert.$METHOD($$$)' --lang go

# AST: Test functions
ast-grep --pattern 'func Test$NAME(t *testing.T) { $$$ }' --lang go

# AST: Benchmark functions
ast-grep --pattern 'func Benchmark$NAME(b *testing.B) { $$$ }' --lang go

# AST: TestMain
ast-grep --pattern 'func TestMain(m *testing.M) { $$$ }' --lang go
```

### HTTP Handlers

```bash
# AST: net/http handler pattern
ast-grep --pattern 'func $NAME(w http.ResponseWriter, r *http.Request) { $$$ }' --lang go

# AST: Chi/Echo/Gin handler patterns (context-based)
ast-grep --pattern 'func $NAME(c $CTX) $$$' --lang go
# Filter by $CTX type: echo.Context, *gin.Context, chi context etc.

# AST: Middleware pattern
ast-grep --pattern 'func $NAME(next http.Handler) http.Handler { $$$ }' --lang go
```

### Logging

```bash
# AST: slog
ast-grep --pattern 'slog.$METHOD($$$)' --lang go

# AST: zap
ast-grep --pattern '$LOGGER.Info($$$)' --lang go
ast-grep --pattern '$LOGGER.Error($$$)' --lang go
ast-grep --pattern 'zap.$METHOD($$$)' --lang go

# AST: logrus
ast-grep --pattern 'logrus.$METHOD($$$)' --lang go
ast-grep --pattern 'log.$METHOD($$$)' --lang go
```

---

## PYTHON PATTERNS

### Class Definitions

```bash
# AST: Classes
ast-grep --pattern 'class $NAME($$$): $$$' --lang python

# AST: Dataclasses
ast-grep --pattern '@dataclass
class $NAME: $$$' --lang python

# AST: Pydantic models
ast-grep --pattern 'class $NAME(BaseModel): $$$' --lang python
```

### Async Functions

```bash
# AST: Async functions
ast-grep --pattern 'async def $NAME($$$): $$$' --lang python

# AST: Async with context manager
ast-grep --pattern 'async with $EXPR as $VAR: $$$' --lang python
```

### FastAPI/Flask Routes

```bash
# AST: FastAPI route decorators
ast-grep --pattern '@app.get($$$)' --lang python
ast-grep --pattern '@router.post($$$)' --lang python

# AST: Flask routes
ast-grep --pattern '@app.route($$$)' --lang python
```

### Type Hints

```bash
# AST: Typed function signatures
ast-grep --pattern 'def $NAME($$$) -> $TYPE: $$$' --lang python
```

---

## TYPESCRIPT PATTERNS

### Interfaces & Types

```bash
# AST: Interfaces
ast-grep --pattern 'interface $NAME { $$$ }' --lang typescript
ast-grep --pattern 'export interface $NAME { $$$ }' --lang typescript

# AST: Type aliases
ast-grep --pattern 'type $NAME = $$$' --lang typescript
```

### NestJS Patterns

```bash
# AST: Injectable services
ast-grep --pattern '@Injectable()
export class $NAME { $$$ }' --lang typescript

# AST: Controllers
ast-grep --pattern '@Controller($$$)
export class $NAME { $$$ }' --lang typescript

# AST: Module
ast-grep --pattern '@Module($$$)
export class $NAME { $$$ }' --lang typescript
```

### React Patterns

```bash
# AST: Functional components
ast-grep --pattern 'export function $NAME($$$): JSX.Element { $$$ }' --lang tsx
ast-grep --pattern 'const $NAME: React.FC<$$$> = ($$$) => { $$$ }' --lang tsx

# AST: Hooks
ast-grep --pattern 'const [$STATE, $SETTER] = useState($$$)' --lang tsx
ast-grep --pattern 'useEffect(() => { $$$ }, [$$$])' --lang tsx
```

---

## RUST PATTERNS

### Traits & Implementations

```bash
# AST: Trait definitions
ast-grep --pattern 'trait $NAME { $$$ }' --lang rust

# AST: Trait implementations
ast-grep --pattern 'impl $TRAIT for $TYPE { $$$ }' --lang rust

# AST: Structs
ast-grep --pattern 'struct $NAME { $$$ }' --lang rust
ast-grep --pattern 'pub struct $NAME { $$$ }' --lang rust
```

### Error Handling

```bash
# AST: Result return types
ast-grep --pattern 'fn $NAME($$$) -> Result<$OK, $ERR> { $$$ }' --lang rust

# AST: ? operator usage (error propagation)
ast-grep --pattern '$EXPR?' --lang rust

# AST: Custom error enums
ast-grep --pattern 'enum $NAME { $$$ }' --lang rust
# Filter by name *Error
```

### Async

```bash
# AST: Async functions
ast-grep --pattern 'async fn $NAME($$$) -> $RET { $$$ }' --lang rust
```

---

## JAVA PATTERNS

### Spring Boot

```bash
# AST: REST controllers
ast-grep --pattern '@RestController
public class $NAME { $$$ }' --lang java

# AST: Service
ast-grep --pattern '@Service
public class $NAME { $$$ }' --lang java

# AST: Repository
ast-grep --pattern 'public interface $NAME extends $REPO<$ENTITY, $ID> { $$$ }' --lang java

# AST: Autowired
ast-grep --pattern '@Autowired
$TYPE $NAME' --lang java
```

---

## USAGE IN PHASES

### Phase 2 (DETECT) — AST Integration

```
1. Check ast-grep availability → state.detect.ast_available
2. If available:
   - Use AST patterns for framework detection (import analysis)
   - Use AST for test pattern detection (table-driven, testify)
   - Set detection_method: "ast" on all findings
3. If NOT available:
   - Fallback to grep patterns from reference/language-patterns.md
   - Set detection_method: "grep" on all findings
   - Lower confidence by 0.1 for grep-based detections
```

### Phase 3 (ANALYZE) — AST Integration

```
1. Architecture detection:
   - AST: Count interfaces per directory → determine layer role
   - AST: Analyze import graph → detect dependency flow
   - AST: Find Constructor patterns → map DI strategy
2. Convention discovery:
   - AST: Error pattern analysis (wrapping style, custom types, sentinels)
   - AST: Logging library detection (precise, not grep-based)
   - AST: Test style analysis (table-driven count, mock count)
3. Violation detection:
   - AST: Extract imports per package
   - Compare against allowed dependency flow
   - Report violations with exact file:line
```

### Phase 4 (MAP) — AST Integration

```
1. Entry point detection:
   - AST: Find func main()
   - AST: Find HTTP handler signatures
   - AST: Find gRPC service implementations
2. Core domain:
   - AST: Find all structs in domain layer
   - AST: Find all interfaces (repository, service ports)
   - AST: Match implementations to interfaces (compile-time checks)
3. Design patterns:
   - AST: Constructor functions (New*)
   - AST: Factory/Builder/Strategy patterns
   - AST: Middleware chains
```

---

## CONFIDENCE ADJUSTMENT

| Detection Method | Confidence Modifier |
|-----------------|-------------------|
| AST match | +0.0 (baseline) |
| Manifest match (go.mod, package.json) | +0.0 (baseline) |
| grep match (single pattern) | -0.05 |
| grep match (complex regex) | -0.10 |
| Heuristic (directory name only) | -0.15 |

Example: If architecture is determined via AST (interfaces in domain/, no external imports) → confidence 0.90.
If via grep (directory names only) → confidence 0.75.
