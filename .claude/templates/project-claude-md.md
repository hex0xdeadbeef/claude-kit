# Project: Go Backend Workflow

## Language Profile
- Language: Go >= 1.24
- Commands: VERIFY=`go vet ./... && make fmt && make lint && make test`, FMT=`make fmt`, LINT=`make lint`, TEST=`make test`, VET=`go vet ./...`
- Error wrapping: `fmt.Errorf("context: %w", err)` — NEVER log AND return same error
- Domain entities: NO encoding/json tags (tags belong in DTOs)
- Source: `internal/**/*.go`, Generated: `*_gen.go`, Mocks: `*/mocks/*.go`
- Config: update `config.yaml.example` + `README.md` when config changes
- Concurrency: goroutines, channels, mutex, sync; race check: `go test -race`

## Architecture (Import Matrix)
Layers: handler → service/controller → repository → models
- handler NEVER imports repository directly
- models: only stdlib imports
- service: may import repository, NEVER handler
- Domain entities must be pure — no serialization annotations

## Error Handling (All Agents)
| Error | Severity | Action |
|-------|----------|--------|
| Memory/ST/Context7/PostgreSQL MCP unavailable | NON_CRITICAL | Warn, proceed without |
| Beads unavailable | NON_CRITICAL | Skip beads phases |
| Plan not found | FATAL | EXIT — run /planner first |
| Plan not approved | FATAL | EXIT — run /plan-review first |
| PROJECT-KNOWLEDGE.md missing | NON_CRITICAL | Use profile above as defaults |
| Tests fail 3x | STOP_AND_WAIT | Show errors, request manual fix |
| Import violation | STOP_AND_FIX | Fix before proceeding |
| Loop limit exceeded (3x) | STOP | Show iteration summary, request user help |

## Workflow Commands
<!-- TODO(Phase 2): Update when migrating to agents/ -->
- Full dev cycle: `/workflow`
- Planning only: `/planner`
- Implementation: `/coder`

## Hooks
- PreCompact: saves workflow state before context compaction (automatic)
- SubagentStop: records review agent completion markers (automatic)
- Stop: blocks if uncommitted changes exist (automatic)
- Config: `.claude/settings.json`
