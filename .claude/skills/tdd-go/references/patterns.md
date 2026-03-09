# TDD Patterns for Go

## Table-Driven TDD

In TDD mode, table-driven tests are built incrementally — ONE case at a time.

### Pattern: Incremental Table Growth

```go
// Cycle 1: RED — add first case
func TestParseAge_ValidInput(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        want    int
        wantErr bool
    }{
        {name: "simple number", input: "25", want: 25, wantErr: false},
        // Future cases: t.Skip() or not yet added
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := ParseAge(tt.input)
            if tt.wantErr {
                require.Error(t, err)
                return
            }
            require.NoError(t, err)
            assert.Equal(t, tt.want, got)
        })
    }
}
// RED: ParseAge doesn't exist → compile error or wrong result
// GREEN: implement ParseAge with strconv.Atoi
// REFACTOR: clean up

// Cycle 2: RED — add second case
// Add to tests slice:
//   {name: "negative", input: "-5", want: 0, wantErr: true},
// RED: ParseAge("-5") returns -5, not error → FAIL
// GREEN: add validation `if age < 0 { return 0, ErrInvalidAge }`
// REFACTOR: extract validation to helper if needed

// Cycle 3: RED — add third case
// Add: {name: "non-numeric", input: "abc", want: 0, wantErr: true},
// Likely already passes (strconv.Atoi handles it) → revise test or skip
```

### Anti-pattern: Batch All Cases

```go
// BAD: All cases written upfront before any implementation
tests := []struct{ ... }{
    {"simple", "25", 25, false},
    {"negative", "-5", 0, true},
    {"non-numeric", "abc", 0, true},
    {"empty", "", 0, true},
    {"overflow", "999999999999", 0, true},
    {"zero", "0", 0, false},
}
// This violates ONE-at-a-time. Multiple failures at once = lost focus.
```

### Using t.Skip() for Planned Cases

```go
{name: "overflow", input: "999999999999", want: 0, wantErr: true},
// If not ready for this case yet:
// In the test loop, before the case:
if tt.name == "overflow" {
    t.Skip("not yet implemented — next TDD cycle")
}
```

## Test Helpers

### Factory Pattern for Test Setup

```go
// testutil/service.go (or within _test.go)
func newTestUserService(t *testing.T) (*UserService, *mocks.UserRepository) {
    t.Helper()
    repo := mocks.NewUserRepository(t)
    svc := NewUserService(repo)
    return svc, repo
}
```

Use helpers to reduce boilerplate in RED phase — faster test writing.

### Test Context Helper

```go
func testCtx(t *testing.T) context.Context {
    t.Helper()
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    t.Cleanup(cancel)
    return ctx
}
```

## Benchmark TDD

When plan includes performance requirements:

```
1. RED: Write benchmark that asserts performance threshold
2. GREEN: Implement to pass benchmark
3. REFACTOR: Optimize while maintaining correctness tests
```

```go
// RED: benchmark for O(1) lookup requirement
func BenchmarkCache_Get(b *testing.B) {
    cache := NewCache(1000)
    cache.Set("key", "value")
    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        cache.Get("key")
    }
    // Check: ns/op should be < 100ns for O(1)
}

// Run: go test -bench=BenchmarkCache_Get -benchmem ./...
```

## Error Path TDD

RED-GREEN for error scenarios follows the same cycle:

```go
// Cycle: Testing error wrapping
// RED:
func TestGetUser_NotFound_ReturnsSentinelError(t *testing.T) {
    svc, repo := newTestUserService(t)
    repo.EXPECT().Find(mock.Anything, "missing-id").Return(nil, repository.ErrNotFound)

    _, err := svc.GetUser(testCtx(t), "missing-id")

    require.Error(t, err)
    assert.True(t, errors.Is(err, repository.ErrNotFound))
}
// GREEN: implement error propagation with %w wrapping
// REFACTOR: extract error wrapping pattern
```

## Integration Test TDD

For tests requiring external dependencies (DB, Redis, etc.):

```go
//go:build integration

func TestUserRepository_Create_Integration(t *testing.T) {
    db := setupTestDB(t) // testcontainers or test DB
    repo := NewUserRepository(db)

    // RED-GREEN-REFACTOR same cycle, but with real DB
    user, err := repo.Create(testCtx(t), CreateUserParams{Name: "Alice"})
    require.NoError(t, err)
    assert.NotEmpty(t, user.ID)

    // Verify persistence
    found, err := repo.FindByID(testCtx(t), user.ID)
    require.NoError(t, err)
    assert.Equal(t, "Alice", found.Name)
}
```

Run integration tests separately: `go test -tags=integration -race ./...`
