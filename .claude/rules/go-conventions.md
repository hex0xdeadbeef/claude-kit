---
paths:
  - "**/*.go"
---
# Go Conventions (active when editing any Go file)

Error handling:
- Error wrapping: fmt.Errorf("context: %w", err) — NEVER log AND return same error
- Return early on error (guard clause pattern)
- Wrap with caller context: fmt.Errorf("serviceName.methodName: %w", err)

Concurrency:
- goroutines, channels, mutex, sync primitives
- Race check: always run `go test -race` for concurrent code
- Use context.Context for cancellation and timeouts

Config:
- Update `config.yaml.example` when adding new config fields
- Update `README.md` when config changes affect setup
