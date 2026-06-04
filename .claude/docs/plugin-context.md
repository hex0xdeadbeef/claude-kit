# Claude Kit — Plugin-Mode Context

> Injected as `additionalContext` at SessionStart by `inject-kit-context.sh` **only** when the kit
> runs as a native plugin (`CLAUDE_PLUGIN_ROOT` set) AND the user's project has no `CLAUDE.md` of
> its own. A plugin-root `CLAUDE.md` is NOT loaded by Claude Code, so this carries the CLAUDE.md
> "project context" tier (Language Profile cascade + error handling) that the plugin's skills do
> not. If your project has its own `CLAUDE.md` / `.claude/PROJECT-KNOWLEDGE.md`, those win and this
> is skipped.

## Bundled-artifact path resolution

The kit's commands tell you to `Read .claude/skills/...`, `.claude/templates/...`, and supporting
protocol files with **project-relative** paths. In plugin mode those bundled files do NOT live in
your project — they ship inside the plugin. At session start this hook injects a live directive:

```text
BUNDLED KIT ROOT: <absolute plugin install path>
```

**Resolve every kit `.claude/skills`, `.claude/templates`, and supporting protocol-file Read under
that BUNDLED KIT ROOT.** Project STATE — `.claude/prompts`, `.claude/workflow-state`,
`.claude/agent-memory` — stays under YOUR project root (it must persist across plugin updates; the
plugin cache is ephemeral). In a project-scoped install this distinction is moot: bundled files and
state are both under the project's own `.claude/`, so the project-relative paths already resolve.

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
flow between phases; the canonical issue ID is `sha256(category|location|problem)[:8]`. See
**Command namespace** below for how these commands are invoked in plugin mode.

## Command namespace (plugin mode)

You invoke the kit's commands with the plugin prefix: **`/claude-kit:workflow`**,
`/claude-kit:planner`, `/claude-kit:coder`, `/claude-kit:designer` (in a project-scoped `.claude/`
install they are bare: `/workflow`, etc.). You only need the prefix for the command **you type**.
Two different resolution mechanisms then carry the pipeline, and they are **not** the same:

- **Agent delegation** (orchestrator → planner → plan-reviewer → coder → code-reviewer) and the
  reviewer agents' own `-rules` skills (preloaded via agent frontmatter `skills:`) resolve **by
  description / name** — namespace-agnostic, so they flow correctly in plugin mode with no path
  rewrite.
- **The pipeline's reference skills** (`workflow-protocols`, `planner-rules`, `coder-rules`,
  `design-rules`, `tdd-rules`, …) are `disable-model-invocation: true`, so Claude does **not**
  load them by description. The commands load them by explicit **file Read**, and in plugin mode
  those files live under the bundled root — so they resolve via the **BUNDLED KIT ROOT** directive
  injected at session start (see *Bundled-artifact path resolution* above), **not** by namespace.

The kit's own docs and prompt bodies use the bare `/workflow` form on purpose: those references are
namespace-agnostic and correct for BOTH distributions (project-scoped and plugin) — mentally prefix
`claude-kit:` for the command you invoke when running as a plugin.

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
- **Worktree isolation:** the `code-reviewer` agent runs in an isolated git worktree (clean
  review context) in plugin mode too — the isolation works regardless. The *sparse-checkout
  optimization* (`worktree.sparsePaths`) is a per-project setting and is NOT imposed by the
  plugin (the kit's defaults are Go-specific: `internal/`, `cmd/`, …). If your monorepo would
  benefit from a smaller review worktree, set `worktree.sparsePaths` for YOUR project's layout
  in your own `.claude/settings.local.json` — Claude Code's native worktree creation honors it.
- This context is intentionally concise; the full policies live in the plugin's skills
  (workflow-protocols, planner-rules, coder-rules, etc.) which load on demand.
