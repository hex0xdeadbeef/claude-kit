---
paths:
  - "**/*_test.go"
---
# Testing Conventions (active when editing test files)

Test style:
- Table-driven tests (Go idiomatic pattern)
- Test function naming: Test{Function}_{Scenario}_{Expected}
- Use testify/assert or testify/require for assertions

Race detection:
- Run `go test -race ./...` for packages with concurrency
- CI runs with -race flag by default

Mocks:
- Generated mocks in `*/mocks/*.go` — NEVER edit manually
- Regenerate: update interface, then run `go generate ./...`
- Use mockery or gomock conventions from existing codebase

Test organization:
- Unit tests: same package, `_test.go` suffix
- Integration tests: `//go:build integration` tag
- Test fixtures: `testdata/` directory (auto-ignored by Go tooling)
