---
paths:
  - "internal/service/**/*.go"
  - "internal/controller/**/*.go"
  - "internal/usecase/**/*.go"
---
# Service Layer Rules

Business logic layer: orchestrates domain operations, enforces business rules, manages transactions.

## Checklist

- Accept dependencies via interfaces (not concrete types) for testability
- Accept `context.Context` as first parameter in all public methods
- Wrap errors with layer context: `fmt.Errorf("service.{Method}: %w", err)`
- Keep business rules in service — not in handlers or repositories
- Use repository interfaces — never import concrete repository implementations
- Handle transaction boundaries at service level (not repository)

## Forbidden

### Importing handler packages
**Why:** Service must not depend on transport layer — it should work with any transport (HTTP, gRPC, CLI).

**Bad:**
```go
import "myapp/internal/handler" // service importing handler
```

**Good:**
```go
import "myapp/internal/repository" // service imports repository interface
```

### HTTP-specific logic
**Why:** Service layer must be transport-agnostic.

**Bad:**
```go
func (s *UserService) GetUser(w http.ResponseWriter, r *http.Request) {
```

**Good:**
```go
func (s *UserService) GetByID(ctx context.Context, id string) (*models.User, error) {
```

## References
- See `architecture.md` for import matrix
- See `repository-rules.md` for repository interface contracts
- See `go-conventions.md` for error wrapping format
