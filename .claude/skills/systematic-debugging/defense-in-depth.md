# Defense-in-Depth Validation

## Overview

When you fix a bug caused by invalid data, adding validation at one place feels
sufficient. But that single check can be bypassed by different code paths,
refactoring, or mocks.

**Core principle:** Validate at EVERY layer data passes through. Make the bug
structurally impossible.

## Why Multiple Layers

Single validation: "We fixed the bug"
Multiple layers: "We made the bug impossible"

Different layers catch different cases:
- Entry validation catches most bugs
- Business logic catches edge cases
- Environment guards prevent context-specific dangers
- Debug logging helps when other layers fail

## The Four Layers

### Layer 1: Entry Point Validation
**Purpose:** Reject obviously invalid input at API boundary

```go
func (h *UserHandler) GetUser(w http.ResponseWriter, r *http.Request) {
    id := chi.URLParam(r, "id")
    if id == "" {
        http.Error(w, "id is required", http.StatusBadRequest)
        return
    }
    // ...
}
```

### Layer 2: Business Logic Validation
**Purpose:** Ensure data makes sense for this operation

```go
func (s *UserService) GetUser(ctx context.Context, id string) (*User, error) {
    const op = "UserService.GetUser"
    if id == "" {
        return nil, fmt.Errorf("%s: id required", op)
    }
    user, err := s.repo.Find(ctx, id)
    if err != nil {
        return nil, fmt.Errorf("%s: %w", op, err)
    }
    return user, nil
}
```

### Layer 3: Environment Guards
**Purpose:** Prevent dangerous operations in specific contexts

```go
// Test helper: validate test setup before the test runs
func mustCreateUser(t *testing.T, db *sql.DB, name string) string {
    t.Helper()
    if db == nil {
        t.Fatal("mustCreateUser: db is nil — check TestMain setup")
    }
    var id string
    err := db.QueryRowContext(context.Background(),
        "INSERT INTO users (name) VALUES ($1) RETURNING id", name).Scan(&id)
    require.NoError(t, err, "mustCreateUser: insert failed")
    return id
}

// Build tag guard for destructive operations (only run with -tags integration)
//go:build integration

func TestDeleteAllUsers(t *testing.T) { ... }
```

### Layer 4: Debug Instrumentation
**Purpose:** Capture context for forensics

```go
import (
    "log/slog"
    "runtime/debug"
)

func (r *UserRepository) Find(ctx context.Context, id string) (*User, error) {
    slog.Debug("repo.Find called",
        "id", id,
        "stack", string(debug.Stack()),
    )
    // proceed with query
}
```

**Note:** Remove Layer 4 instrumentation after root cause is found and fixed.
It is a diagnostic tool, not permanent logging.

## Applying the Pattern

When you find a bug:

1. **Trace the data flow** — Where does bad value originate? Where is it used?
2. **Map all checkpoints** — List every point data passes through
3. **Add validation at each layer** — Entry, business, environment, debug
4. **Test each layer** — Try to bypass layer 1, verify layer 2 catches it

## Example from Go Service

Bug: Empty `id` caused `sql: no rows in result set` deep in repository

**Data flow:**
1. Test builds request without URL params → `chi.URLParam` returns `""`
2. `UserHandler.GetUser` passes `""` to service
3. `UserService.GetUser` passes `""` to repo
4. `UserRepository.Find` queries with empty id → no match → ErrNoRows

**Four layers added:**
- Layer 1: `UserHandler.GetUser` validates `id != ""`
- Layer 2: `UserService.GetUser` validates `id != ""` with `fmt.Errorf`
- Layer 3: `mustCreateUser` test helper validates db is not nil via `t.Helper()`
- Layer 4: `slog.Debug` in `repo.Find` with `debug.Stack()` (temporary)

**Result:** Bug impossible to reproduce through normal code paths.

## Key Insight

All four layers were necessary. During testing:
- Different code paths bypassed entry validation (direct service calls in unit tests)
- Mocks bypassed business logic checks
- Edge cases in test setup needed environment guards
- Debug logging identified the exact call path

**Don't stop at one validation point.** Add checks at every layer.
