# Go — code completeness reference shape

Resolved when `PROJECT-KNOWLEDGE.md → LANGUAGE = go`. Idiomatic Go with the
ERROR_WRAP form `fmt.Errorf("context: %w", err)`.

## Reference scenario — `Service.Get(ctx, id)` retrieves a domain item

```go
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

Invariants illustrated:
1. Full body — no `...` placeholders.
2. ERROR_WRAP — `fmt.Errorf("…: %w", err)` on every error path.
3. Explicit return types — `(*Item, error)` declared, both branches return both.
4. No truncation — happy path, repo error, not-found case all covered.
