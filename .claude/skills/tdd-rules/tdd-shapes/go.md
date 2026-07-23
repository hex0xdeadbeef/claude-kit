# Go — TDD reference shape

Resolved when `PROJECT-KNOWLEDGE.md → LANGUAGE = go`. Idiomatic Go with
`*testing.T`, table-driven `t.Run`, testify (`require`/`assert`/mock).

## Reference scenario — `Service.Get(ctx, id)` — 3 cycles Red-Green-Refactor

### Cycle 1: happy path

**RED** — `go test ./...` must fail here: `Service.Get` does not exist yet.
```go
func TestServiceGet_ReturnsItemWhenFound(t *testing.T) {
    repo := mocks.NewRepository(t)
    repo.EXPECT().FindByID(mock.Anything, "123").
        Return(&Item{ID: "123", Name: "Test"}, nil)
    svc := NewService(repo)

    item, err := svc.Get(context.Background(), "123")

    require.NoError(t, err)
    require.NotNil(t, item)
    assert.Equal(t, "123", item.ID)
    assert.Equal(t, "Test", item.Name)
}
```

**GREEN** — `go test ./...` now passes.
```go
func (s *Service) Get(ctx context.Context, id string) (*Item, error) {
    return s.repo.FindByID(ctx, id)
}
```

**REFACTOR**: none needed.

### Cycle 2: not-found error

**RED** — `go test ./...` must fail here: `Get` returns `nil, nil` silently.
```go
func TestServiceGet_ReturnsErrNotFoundWhenMissing(t *testing.T) {
    repo := mocks.NewRepository(t)
    repo.EXPECT().FindByID(mock.Anything, "999").Return(nil, nil)
    svc := NewService(repo)

    _, err := svc.Get(context.Background(), "999")

    require.Error(t, err)
    assert.True(t, errors.Is(err, ErrNotFound))
}
```

**GREEN**:
```go
var ErrNotFound = errors.New("not found")

func (s *Service) Get(ctx context.Context, id string) (*Item, error) {
    item, err := s.repo.FindByID(ctx, id)
    if err != nil {
        return nil, err
    }
    if item == nil {
        return nil, fmt.Errorf("get item %s: %w", id, ErrNotFound)
    }
    return item, nil
}
```

### Cycle 3: repo error wrapping (table-driven)

**RED** (incremental — add ONE case per cycle) — must fail here: the repository error is returned unwrapped.
```go
func TestServiceGet_ErrorPaths(t *testing.T) {
    tests := []struct {
        name    string
        repoOut *Item
        repoErr error
        wantErr error
    }{
        {name: "repo connection refused",
         repoOut: nil, repoErr: errors.New("connection refused"),
         wantErr: errors.New("get item 123")},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            repo := mocks.NewRepository(t)
            repo.EXPECT().FindByID(mock.Anything, "123").Return(tt.repoOut, tt.repoErr)
            svc := NewService(repo)

            _, err := svc.Get(context.Background(), "123")

            require.Error(t, err)
            assert.Contains(t, err.Error(), "get item 123")
            assert.True(t, errors.Is(err, tt.repoErr))
        })
    }
}
```

**GREEN** — all 3 cycles pass.
```go
// Get returns the item stored under id. It returns an error wrapping ErrNotFound
// when no such item exists, and wraps any repository failure with the item id so
// callers can attribute the failure without inspecting the repository layer.
func (s *Service) Get(ctx context.Context, id string) (*Item, error) {
    item, err := s.repo.FindByID(ctx, id)
    if err != nil {
        return nil, fmt.Errorf("get item %s: %w", id, err)
    }
    if item == nil {
        return nil, fmt.Errorf("get item %s: %w", id, ErrNotFound)
    }
    return item, nil
}
```

Note the doc comment on the final `Get`: it states what the function returns and the
error contract callers rely on. It says nothing about the TDD cycle that produced it —
per `coder-rules/SKILL.md` § Comment Policy, comments describe the code, never the
process. Cycle status belongs in this prose, not in the code.

Invariants illustrated:
1. RED shown first in every cycle.
2. Test names descriptive (`TestServiceGet_ReturnsItemWhenFound`, not `TestGet1`).
3. All 3 paths: happy / not-found / repo-error-wrap. Table-driven case added incrementally.

For benchmark TDD, integration tests, and additional table-driven patterns,
add follow-up examples to this file or to `tdd-rules/references/go-extras.md` if size budget breached.