# Root Cause Tracing

## Overview

Bugs often manifest deep in the call stack (ErrNoRows from repo, but originating from
empty ID passed by handler). Your instinct is to fix where the error appears, but
that's treating a symptom.

**Core principle:** Trace backward through the call chain until you find the original
trigger, then fix at the source.

## When to Use

**Use when:**

- Error happens deep in execution (not at entry point)
- Stack trace shows long call chain
- Unclear where invalid data originated
- Need to find which test causes state pollution

## The Tracing Process

### 1. Observe the Symptom

```
Error: repository.Find: sql: no rows in result set
```

### 2. Find Immediate Cause

**What code directly causes this?**

```go
func (r *UserRepository) Find(ctx context.Context, id string) (*User, error) {
    // queries with id == "" → no rows
}
```

### 3. Ask: What Called This?

```go
UserRepository.Find(ctx, id)
  → called by UserService.GetUser(ctx, id)
  → called by UserHandler.Handle(r)
  → called by test TestGetUser_Returns200
```

### 4. Keep Tracing Up

**What value was passed?**

- `id = ""` (empty string!)
- Empty string passed to repo → no match → ErrNoRows
- That's a symptom — find where empty string came from

### 5. Find Original Trigger

**Where did empty string come from?**

```go
// Test setup: userID declared at package level, not inside test
var userID string // = "" initially

func TestGetUser_Returns200(t *testing.T) {
    // userID still "" — setup function not called yet
    resp := handler.Handle(makeRequest(userID))
}
```

**Root cause:** Variable not initialized before test uses it.

## Adding Instrumentation

When you can't trace manually, add diagnostic logging:

```go
import (
    "fmt"
    "os"
    "runtime/debug"
)

// Before the problematic operation
func (r *UserRepository) Find(ctx context.Context, id string) (*User, error) {
    // Add BEFORE the query, not after it fails
    fmt.Fprintf(os.Stderr, "DEBUG repo.Find: id=%q, stack:\n%s\n",
        id, debug.Stack())

    row := r.db.QueryRowContext(ctx, "SELECT * FROM users WHERE id = $1", id)
    // ...
}
```

**`fmt.Fprintf(os.Stderr, ...)` always prints** — visible in `go test` output regardless
of log level or test verbosity flags.

**Run and capture:**

```bash
go test -v -run TestGetUser -count=1 ./... 2>&1 | grep -A 5 'DEBUG repo.Find'
```

**Analyze output:**

- Check what `id` value was passed
- Read stack trace to find call origin
- Look for test file names and line numbers

## Finding Which Test Causes Pollution

If state appears during tests but you don't know which test:

```bash
# Run each test in isolation (disables cache, runs one test)
go test -v -run TestFoo -count=1 ./pkg/...
go test -v -run TestBar -count=1 ./pkg/...

# Run all tests, stop at first failure
go test -failfast ./...

# Detect order-dependent failures (randomize test order)
go test -shuffle=on -count=3 ./...
```

**Manual bisection:**

1. Run first half of test file → passes? Good.
2. Run second half → fails? Polluter is in second half.
3. Recurse until you find the specific test.

## Real Example: Empty userID

**Symptom:** `repository.Find: sql: no rows in result set` in TestGetUser

**Trace chain:**

1. `repo.Find` called with `id = ""`
2. `UserService.GetUser` passed empty string
3. `UserHandler.Handle` extracted param incorrectly
4. Test called handler before setting up URL params

**Root cause:** `chi.URLParam(r, "id")` returns `""` when test request built without URL params

**Fix:** Build test request with proper URL params:

```go
r := httptest.NewRequest("GET", "/users/123", nil)
rctx := chi.NewRouteContext()
rctx.URLParams.Add("id", "123")
r = r.WithContext(context.WithValue(r.Context(), chi.RouteCtxKey, rctx))
```

**Also added defense-in-depth:**

- Layer 1: Handler validates `id != ""` before calling service
- Layer 2: Service validates `id != ""` before calling repo
- Layer 3: Test helper `makeRequest(id string)` always sets URL param
- Layer 4: Debug logging in `repo.Find` (temporary, removed after fix)

## Key Principle

**NEVER fix just where the error appears.** Trace back to find the original trigger.

## Stack Trace Tips

- Use `fmt.Fprintf(os.Stderr, ...)` — always visible in `go test` output
- Use `debug.Stack()` for complete call chain (`import "runtime/debug"`)
- Add before the dangerous operation, not after it fails
- Include relevant values: id, ctx values, pointer addresses
- Remove instrumentation after finding root cause

## Real-World Impact

Systematic tracing finds root cause in 1–3 steps vs 10+ guesses.
Fixed at source = bug cannot recur via same path.
