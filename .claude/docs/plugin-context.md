# Claude Kit — Plugin-Mode Context

> Injected as `additionalContext` at SessionStart by `inject-kit-context.sh` **only** when the kit
> runs as a native plugin (`CLAUDE_PLUGIN_ROOT` set) AND the user's project has no `CLAUDE.md` of
> its own. A plugin-root `CLAUDE.md` is NOT loaded by Claude Code, so this carries the CLAUDE.md
> "project context" tier (Language Profile cascade + error handling) that the plugin's skills do
> not. If your project has its own `CLAUDE.md` / `.claude/PROJECT-KNOWLEDGE.md`, those win and this
> is skipped.

## Language Profile (kit default — override per project)

- Language: Go >= 1.24
- Commands: VERIFY=`go vet ./... && make fmt && make lint && make test`, BUILD=`go build ./...`, FMT=`make fmt`, LINT=`make lint`, TEST=`make test`, VET=`go vet ./...`
- Source: `internal/**/*.go`, Generated: `*_gen.go`, Mocks: `*/mocks/*.go`
- Architecture: layered — handler → service → repository → models
- Concurrency: goroutines, channels, mutex, sync; race check: `go test -race`

**Cascade (single source of truth for language slots):** `.claude/PROJECT-KNOWLEDGE.md` →
this profile → SKIP. For a non-Go project, supply your own `CLAUDE.md` Language Profile or run
`/project-researcher` (or `/claude-kit:project-researcher` in plugin namespace) to generate
`.claude/PROJECT-KNOWLEDGE.md`; that overrides everything here.

## Pipeline (carried by the plugin's commands + skills)

`/workflow` orchestrates: task-analysis → `/designer` (L/XL) → `/planner` → plan-reviewer (agent)
→ `/coder` → code-reviewer (agent) → commit. Complexity routing: S (skip plan-review) / M / L (+
Sequential Thinking) / XL (ST required). Typed handoff contracts + VERDICT/VERDICT_JSON envelopes
flow between phases; the canonical issue ID is `sha256(category|location|problem)[:8]`. In the
plugin namespace these commands are `/claude-kit:workflow`, `/claude-kit:planner`, etc.

## TDD policy

`/coder` unconditionally loads the tdd-rules skill at startup; Red-Green-Refactor is the default
Phase-2 implementation rhythm (no plan marker required). Per-language test idioms resolve via the
same cascade (PROJECT-KNOWLEDGE.md → LANGUAGE > kit-default Go > `_default`).

## Error handling (essentials)

| Error | Severity | Action |
| ----- | -------- | ------ |
| MCP server unavailable (sequential-thinking / context7 / tree_sitter) | NON_CRITICAL | Warn, proceed without |
| Plan not found / not approved | FATAL | Run `/planner` / plan-review first |
| `.claude/PROJECT-KNOWLEDGE.md` missing | NON_CRITICAL | Use this profile as defaults |
| Review loop limit (3x) | STOP_AND_WAIT | Show iteration summary, request user help |
| Test/lint failure loop (3x) | STOP_AND_WAIT | Load systematic-debugging skill → root cause |
| Import/architecture violation | STOP_AND_FIX | Fix before proceeding |

## Notes

- Strict-mode contract validation (handoff / verdict / issue-id) defaults to **strict** in plugin
  mode (no env seeding needed). Dangerous-command blocking + file protection run as plugin hooks.
- This context is intentionally concise; the full policies live in the plugin's skills
  (workflow-protocols, planner-rules, coder-rules, etc.) which load on demand.
