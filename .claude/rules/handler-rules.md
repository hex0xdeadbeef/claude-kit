---
paths:
  - "internal/handler/**/*.go"
  - "internal/api/**/*.go"
  - "internal/transport/**/*.go"
---
# Handler Layer Rules

HTTP/API handlers: entry point for external requests. Thin layer — validate, delegate, respond.

## Checklist

- Validate all input (request body, query params, path params) before calling service
- Return semantically correct HTTP status codes (400 validation, 401/403 auth, 404 not found, 409 conflict, 500 internal, etc.)
- Delegate business logic to service layer — handler contains NO business logic
- Wrap errors with layer context: `fmt.Errorf("handler.{Method}: %w", err)`
- Use DTOs for request/response — never expose domain models directly
- Accept dependencies via constructor injection (not global variables)

## Forbidden

### Direct database access
**Why:** Violates layered architecture. Impossible to test handler without DB.

**Bad:**
```go
func (h *Handler) GetUser(w http.ResponseWriter, r *http.Request) {
    row := h.db.QueryRow("SELECT * FROM users WHERE id = ?", id)
}
```

**Good:**
```go
func (h *Handler) GetUser(w http.ResponseWriter, r *http.Request) {
    user, err := h.userService.GetByID(r.Context(), id)
}
```

### Business logic in handler
**Why:** Handler should be thin — validate, delegate, respond.

**Bad:**
```go
func (h *Handler) CreateOrder(w http.ResponseWriter, r *http.Request) {
    if order.Total > user.Balance { // business rule in handler
        http.Error(w, "insufficient funds", http.StatusBadRequest)
        return
    }
}
```

**Good:**
```go
func (h *Handler) CreateOrder(w http.ResponseWriter, r *http.Request) {
    order, err := h.orderService.Create(r.Context(), req)
    // service handles business rules, handler handles HTTP
}
```

## References
- See `architecture.md` for import matrix
- See `service-rules.md` for service layer contract
- See `go-conventions.md` for error wrapping format
