---
paths:
  - "internal/repository/**/*.go"
  - "internal/storage/**/*.go"
  - "internal/store/**/*.go"
  - "internal/db/**/*.go"
---
# Repository Layer Rules

Data access layer: database queries, external storage, cache operations.

## Checklist

- Use parameterized queries — NEVER string concatenation for SQL
- Close resources with `defer` (rows, statements, transactions)
- Handle `sql.ErrNoRows` explicitly — return domain-specific error, not raw SQL error
- Wrap errors with layer context: `fmt.Errorf("repo.{Method}: %w", err)`
- Return domain models (not database-specific types like `sql.NullString`)
- Accept `context.Context` as first parameter — use context-aware methods (`QueryContext`, `ExecContext`)

## Forbidden

### Non-context-aware database methods
**Why:** Prevents cancellation and timeout propagation.

**Bad:**
```go
rows, err := r.db.Query(query, args...) // no context
```

**Good:**
```go
rows, err := r.db.QueryContext(ctx, query, args...)
```

### String concatenation in SQL
**Why:** SQL injection vulnerability.

**Bad:**
```go
query := "SELECT * FROM users WHERE name = '" + name + "'"
```

**Good:**
```go
query := "SELECT * FROM users WHERE name = $1"
row := r.db.QueryRowContext(ctx, query, name)
```

### Leaking database types
**Why:** Repository should return domain types, isolating DB details.

**Bad:**
```go
func (r *Repo) GetUser(ctx context.Context, id string) (*sql.Row, error) {
```

**Good:**
```go
func (r *Repo) GetUser(ctx context.Context, id string) (*models.User, error) {
```

## References
- See `models-rules.md` for domain type contracts
- See `go-conventions.md` for error wrapping format
