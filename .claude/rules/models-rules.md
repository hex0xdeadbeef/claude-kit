---
paths:
  - "internal/models/**/*.go"
  - "internal/domain/**/*.go"
  - "internal/entity/**/*.go"
---
# Domain Models Rules

Domain entities: pure business objects with no infrastructure dependencies.

## Checklist

- Import only stdlib packages — no third-party or infrastructure imports
- NO serialization tags (`json:`, `xml:`, `yaml:`, `gorm:`, `db:`, `bson:`)
- Use value objects for typed identifiers, money, emails (not raw primitives)
- Domain validation in model constructors or methods (not in handlers)
- Keep models focused — one entity per file, related types in same package
- Use constructor functions: `NewUser(name, email)` returns `(*User, error)`

## Forbidden

### Serialization tags on domain entities
**Why:** Serialization is infrastructure concern — use DTOs instead.

**Bad:**
```go
type User struct {
    ID    string `json:"id" db:"id"`
    Name  string `json:"name" db:"name"`
    Email string `json:"email" db:"email"`
}
```

**Good:**
```go
// internal/models/user.go — pure domain
type User struct {
    ID    UserID
    Name  string
    Email Email
}

// internal/handler/dto/user.go — DTO with tags
type UserResponse struct {
    ID    string `json:"id"`
    Name  string `json:"name"`
    Email string `json:"email"`
}
```

### Infrastructure imports
**Why:** Models must be independent of infrastructure.

**Bad:**
```go
import (
    "database/sql"
    "github.com/jmoiron/sqlx"
)
```

**Good:**
```go
import (
    "fmt"
    "time"
)
```

## References
- See `architecture.md` for import constraints (stdlib-only rule)
- See `handler-rules.md` for DTO usage patterns
