# Project Knowledge: claude-go-kit

**Last Updated:** 2026-02-23T00:00:00Z
**Version:** v1.0 (git: 3f8bee9)
**Researcher:** project-researcher agent v3.0
**Analysis Method:** grep-based (ast-grep not available; config-only kit — no source code)

---

## Executive Summary

`claude-go-kit` is a reusable Claude Code configuration kit for Go projects. It provides a curated set of agents, slash commands, templates, and shell scripts for AI-assisted development. The kit follows a **YAML-first** convention and a **4-layer artifact architecture**: commands (user-facing thin wrappers), agents (heavy multi-phase automation), templates (project starters), and scripts (hooks + sync utilities).

The kit is designed to be `cp`-ed into any Go project and bootstrapped via `/meta-agent onboard`. It is not a traditional software project — there is no Go source code, no build system, and no test suite. The primary artifacts are Markdown files with YAML frontmatter, organized into `.claude/` subdirectories following Claude Code conventions.

GitHub: https://github.com/hex0xdeadbeef/claude-kit (branch: `sync/initial`)

---

## Project Structure

### Module Map

**Type:** single module (config-only, no language manifest)
**Strategy:** single

| Module | Language | Type | Description |
|--------|----------|------|-------------|
| `.claude/agents/` | Markdown/YAML | agents | Multi-phase automation agents |
| `.claude/commands/` | Markdown/YAML | commands | User-invocable slash commands (9 total) |
| `.claude/templates/` | Markdown/YAML | templates | Artifact starters (5 templates) |
| `.claude/scripts/` | Shell | scripts | sync-to-github.sh |
| `.claude/agents/meta-agent/scripts/` | Shell | hooks | YAML lint, size gate, reference checker, phase verifier |

**File distribution:** 80 `.md` (88%), 6 `.sh` (7%), 1 `.json` (1%), 4 other

---

## Architecture Deep-Dive

### Pattern: Config-as-Code Kit with Phase-Based Agent Architecture

The kit organizes Claude Code configuration into four distinct layers:

1. **Commands layer** (`.claude/commands/`) — thin wrappers user-invocable as `/command-name`. They load agent instructions or contain the full skill inline. Use YAML frontmatter for metadata and model routing.

2. **Agents layer** (`.claude/agents/`) — heavy, multi-phase agents with `deps/` subdirectories for progressive context loading. Agents are invoked via the Task tool (exception: project-researcher and meta-agent also have command wrappers).

3. **Templates layer** (`.claude/templates/`) — artifact starter files used by meta-agent to scaffold new commands, agents, skills, and rules.

4. **Scripts layer** (`.claude/scripts/` + `agents/meta-agent/scripts/`) — shell scripts for GitHub sync and Claude Code hooks (PreToolUse, PostToolUse, Stop).

### Evidence

| Indicator | Weight | Method |
|-----------|--------|--------|
| All 9 commands have YAML frontmatter | 0.3 | grep |
| Agents use deps/ progressive loading pattern | 0.3 | directory |
| settings.json hooks point to meta-agent/scripts/ | 0.2 | file |
| Templates follow agent/command/skill/rule naming | 0.1 | directory |
| CLAUDE.md documents 4-layer structure | 0.1 | file |

**Confidence: HIGH (0.95)**

### Layers

| Layer | Path | Files | Key Artifacts | External Deps |
|-------|------|-------|---------------|--------------|
| commands | `.claude/commands/` | 9 md + 16 deps | workflow, planner, coder, code-review, meta-agent, project-researcher | none |
| agents | `.claude/agents/` | 48 md total | meta-agent v9.0, project-researcher v3.0, db-explorer | MCP: memory, context7, postgres |
| templates | `.claude/templates/` | 5 md | agent, command, skill, rule, plan-template | none |
| scripts | `.claude/scripts/` + meta-agent/scripts/ | 6 sh | sync-to-github.sh, yaml-lint.sh, check-artifact-size.sh, check-references.sh, verify-phase-completion.sh | git, GitHub |

### Dependency Flow

```
User input (/slash-command)
      │
      ▼
.claude/commands/*.md   ──Read──▶   .claude/agents/{name}/AGENT.md
      │                                      │
      ▼                                      ▼
deps/shared-*.md                .claude/agents/{name}/deps/*.md
(workflow-phases, mcp,           .claude/agents/{name}/phases/*.md
 autonomy, beads, error)                  │
                                          ▼
                               MCP servers (memory, context7,
                                sequential-thinking, postgres)
```

### Dependency Violations

*(Empty — clean architecture, no violations detected)*

### Architectural Decisions

| Decision | Rationale | Date | Confidence |
|----------|-----------|------|------------|
| YAML-first frontmatter on all artifacts | Machine-parseable, aligns with Claude Code conventions | 2026-01-20 | HIGH |
| Progressive context loading via deps/ | Reduces active context by ~60%, stays within Claude context limits | 2026-01-18 | HIGH |
| Commands as thin wrappers over agents | Agents accessible via Task tool; commands give user-facing slash syntax | 2026-02-23 | HIGH |
| Hooks as deterministic validation gates | Prevents artifact size violations and broken references at write-time | 2026-01-18 | HIGH |
| `sync/initial` branch (not `main`) | Main branch protected on GitHub | 2026-02-23 | MEDIUM |

---

## Dependency Topology

### Graph Summary

| Metric | Value |
|--------|-------|
| Total artifact files | 91 |
| Total commands | 9 |
| Total agents | 3 |
| Total templates | 5 |
| Total scripts | 6 |
| Shared deps (cross-command) | 5 |
| Max depth (command→agent→deps) | 3 levels |
| Circular dependencies | none |
| Isolated artifacts | db-explorer (minimal, no phase structure) |

### Hub Artifacts (highest fan-in)

| Artifact | Fan-In | Fan-Out | Role |
|----------|--------|---------|------|
| `commands/deps/workflow-phases.md` | 3 | 0 | workflow context reference for multiple commands |
| `commands/deps/shared-autonomy.md` | 1 | 0 | autonomy pattern reference |
| `commands/deps/shared-mcp.md` | 1 | 0 | MCP usage patterns |
| `commands/deps/shared-error-handling.md` | 1 | 0 | error handling reference |
| `commands/deps/shared-beads.md` | 1 | 0 | beads integration |

### Depth Map

```
Level 0 (entry):    .claude/commands/*.md
Level 1 (agents):   .claude/agents/{name}/AGENT.md or README.md
Level 2 (deps):     .claude/agents/{name}/deps/*.md
                    .claude/agents/{name}/phases/*.md
Level 3 (external): MCP servers (memory, context7, sequential-thinking, postgres)
```

### God Artifacts (high fan-out)

| Artifact | Fan-Out | Recommendation |
|----------|---------|----------------|
| `meta-agent/README.md` | loads 25 deps on demand | Expected — orchestrates all artifact operations |
| `project-researcher/AGENT.md` | loads 9 phases + 5 deps | Expected — 10-phase research pipeline |

### Circular Dependencies

None detected.

### Isolated Artifacts (0 fan-in from other commands)

- `db-explorer/deps/queries.md` — referenced only by db-explorer command
- `.claude/templates/*.md` — referenced by meta-agent during CREATE operations only

---

## Technology Stack

### Primary Language: Markdown
- Variant: CommonMark with YAML frontmatter
- Rendered by Claude Code

### Secondary: Shell (Bash)
- 6 `.sh` files: hook scripts + sync utility
- All use `set -e` strict mode

### Frameworks / Runtimes

| Framework | Version | Category | Purpose | Detection |
|-----------|---------|----------|---------|-----------|
| Claude Code | CLI current | AI assistant | Runtime for all artifacts | directory |
| meta-agent | v9.0 | artifact-management | CRUD for commands/agents/skills/rules | README.md |
| project-researcher | v3.0.0 | codebase-analysis | Project research → PROJECT-KNOWLEDGE.md | AGENT.md |
| db-explorer | v1.0 | database | PostgreSQL schema exploration via MCP | deps/queries.md |

### MCP Servers

| Server | Package | Required | Purpose |
|--------|---------|----------|---------|
| memory | `@modelcontextprotocol/server-memory` | YES | Cross-session agent memory |
| context7 | `@upstash/context7-mcp` | YES | Library docs lookup |
| sequential-thinking | — | YES | Structured multi-step reasoning |
| postgres | `@anthropic/mcp-postgres` | NO | db-explorer agent only |

---

## Core Domain

### Agents (Core Artifacts)

| Agent | Location | Version | Phases | Deps Count |
|-------|----------|---------|--------|------------|
| meta-agent | `.claude/agents/meta-agent/README.md` | v9.0 | 9 (INIT→EXPLORE→ANALYZE→PLAN→CONSTITUTE→DRAFT→APPLY→VERIFY→CLOSE) | 25 |
| project-researcher | `.claude/agents/project-researcher/AGENT.md` | v3.0.0 | 10 (VALIDATE→DISCOVER→DETECT→ANALYZE→MAP→DATABASE→CRITIQUE→GENERATE→VERIFY→REPORT) | 5 deps + 9 phases |
| db-explorer | `.claude/agents/db-explorer/deps/queries.md` | v1.0 | 2 (CONNECT, EXPLORE) | 1 |

### Commands (Entry Points)

| Command | Location | Version | Model | Purpose |
|---------|----------|---------|-------|---------|
| /workflow | `.claude/commands/workflow.md` | 2.1.0 | opus | Full dev cycle: task-analysis → planner → plan-review → coder → code-review |
| /planner | `.claude/commands/planner.md` | 2.1.0 | opus | Research codebase → detailed implementation plan |
| /coder | `.claude/commands/coder.md` | 1.3.0 | opus | Implement code strictly per approved plan |
| /plan-review | `.claude/commands/plan-review.md` | 3.2.0 | sonnet | Validate plan before coding |
| /code-review | `.claude/commands/code-review.md` | 1.3.0 | sonnet | Code review before merge |
| /meta-agent | `.claude/commands/meta-agent.md` | — | — | Artifact lifecycle (onboard, create, enhance, audit, delete) |
| /project-researcher | `.claude/commands/project-researcher.md` | — | — | Thin wrapper → project-researcher agent |
| /db-explorer | `.claude/commands/db-explorer.md` | — | sonnet | PostgreSQL schema exploration |
| /review-checklist | `.claude/commands/review-checklist.md` | 1.2.0 | sonnet | Architecture/security/quality checklist reference |

### Templates

| Template | Location | Lines | Purpose |
|----------|----------|-------|---------|
| agent.md | `.claude/templates/agent.md` | 153 | Scaffold new agent |
| command.md | `.claude/templates/command.md` | 67 | Scaffold new slash command |
| skill.md | `.claude/templates/skill.md` | 89 | Scaffold new reusable skill |
| rule.md | `.claude/templates/rule.md` | 65 | Scaffold new rule |
| plan-template.md | `.claude/templates/plan-template.md` | 132 | Implementation plan structure |

---

## Database Schema

**Note:** N/A — config kit, no database.

---

## Conventions Catalog

### Naming Conventions

```
// File naming
kebab-case.md           → code-review.md, plan-review.md, db-explorer.md
                          NOT snake_case, NOT camelCase

// Agent directories
kebab-case/             → meta-agent/, project-researcher/, db-explorer/

// YAML frontmatter keys
camelCase or kebab      → description, allowed-tools, model, version, updated
```

### Code Structure Patterns (Artifact Structure)

```yaml
---                          # YAML frontmatter (required)
description: "..."           # Required: 1-line description
model: opus|sonnet|haiku     # Optional: model routing
version: 1.0.0               # Optional: semantic version
updated: YYYY-MM-DD          # Optional: ISO date
allowed-tools: [...]         # Optional: tool whitelist
---

# Title

## Phase N: Name
Instructions...
```

### YAML-First Convention

```
# Rule: >80% YAML, minimal prose
# All artifacts use YAML frontmatter
# Phase state objects in YAML format
# settings.json in JSON

# Good: YAML frontmatter + concise markdown body
# Bad: Plain markdown without frontmatter, prose-heavy descriptions
```

### Progressive Context Loading (deps/ pattern)

```
# Rule: split heavy content into deps/ files, load on demand
# Agent main file:  ≤511 lines (project-researcher actual)
# Command files:    ≤600 lines target
# deps/ files:      no hard limit (loaded per phase only)

# Size limits enforced by hooks:
#   CLAUDE.md:       ≤200 lines
#   commands:        ≤600 lines
#   agents (main):   ≤600 lines
```

### Error Handling Conventions (Shell Scripts)

```bash
# Strict mode
set -e

# Hook exit codes
exit 1  # Blocks tool use (PreToolUse hooks)
exit 0  # Allows tool use

# Agent FATAL errors
"FATAL: Directory not found: <path>"
"FATAL: State validation failed — missing: <fields>"
```

### Logging Conventions

```bash
# Shell: colored output
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
echo -e "${GREEN}✓ Done${NC}"

# Agent progress format
"[PHASE N/10] NAME — DONE"
"State: key=value, key2=value2"
```

---

## Entry Points Map

### CLI (Slash Commands)

| Command | Location | Model | Purpose | Key Deps |
|---------|----------|-------|---------|----------|
| /workflow | commands/workflow.md | opus | Full dev cycle | deps/workflow-phases.md, shared-*.md |
| /planner | commands/planner.md | opus | Planning | deps/planner/*.md |
| /coder | commands/coder.md | opus | Implementation | deps/coder/*.md |
| /plan-review | commands/plan-review.md | sonnet | Plan validation | deps/plan-review/*.md |
| /code-review | commands/code-review.md | sonnet | Code review | deps/code-review/*.md |
| /meta-agent | commands/meta-agent.md | — | Artifact management | agents/meta-agent/ |
| /project-researcher | commands/project-researcher.md | — | Project research | agents/project-researcher/ |
| /db-explorer | commands/db-explorer.md | sonnet | DB exploration | agents/db-explorer/ |
| /review-checklist | commands/review-checklist.md | sonnet | Checklist reference | none |

### Hooks

| Hook | Trigger | Script | Purpose |
|------|---------|--------|---------|
| SIZE_GATE | PreToolUse(Write) | `meta-agent/scripts/check-artifact-size.sh` | Block oversized artifacts |
| YAML_LINT | PostToolUse(Edit) | `meta-agent/scripts/yaml-lint.sh` | Validate YAML after edits |
| REF_CHECK | PostToolUse(Write) | `meta-agent/scripts/check-references.sh` | Validate file references |
| PHASE_CHECK | Stop | `meta-agent/scripts/verify-phase-completion.sh` | Ensure phases completed |

---

## External Integrations

### MCP Servers

| Server | Config | Required | Tools Used |
|--------|--------|----------|-----------|
| memory | `~/.claude/mcp.json` | YES | `mcp__memory__create_entities`, `read_graph`, `search_nodes` |
| context7 | `~/.claude/mcp.json` | YES | `mcp__context7__resolve-library-id`, `query-docs` |
| sequential-thinking | `~/.claude/mcp.json` | YES | `mcp__sequential-thinking__sequentialthinking` |
| postgres | `~/.claude/mcp.json` | NO (db-explorer only) | `mcp__postgres__list_tables`, `describe_table`, `query` |

### External Services

| Service | Method | Location | Notes |
|---------|--------|----------|-------|
| GitHub | git + HTTPS | `~/.claude-sync/claude-kit/` backup repo | Branch: `sync/initial`; `git add -f` required due to global gitignore |

---

## Pattern Catalog

### Design Patterns Used

| Pattern | Location | Purpose |
|---------|----------|---------|
| Phase-based pipeline | All agents | Structured step-by-step execution with typed state |
| Progressive context loading | `agents/*/deps/` | Load only needed context per phase (~60% context reduction) |
| Thin wrapper command | `.claude/commands/` | User-facing slash syntax wraps heavy agent logic |
| Constitutional AI evaluation | meta-agent CONSTITUTE phase | Principles-based artifact evaluation (P1-P5) |
| Separated evaluator subagents | meta-agent deps/subagents.md | Reflexion pattern: separate evaluator + reflector |
| Inter-phase state contract | project-researcher deps/state-contract.md | Typed YAML state ensures no data loss between phases |
| Blocking hook gates | settings.json hooks | Deterministic validation at write/edit time |
| AST-first with grep fallback | project-researcher phases | Structural analysis with graceful degradation |
| ADAS archive | meta-agent deps/artifact-archive.md | Self-improving pattern library from successful runs |
| Tree of Thought (ToT) | meta-agent PLAN phase | Design space exploration for artifact generation |

---

## Decision Log

| Date | Decision | Rationale | Impact | Status |
|------|----------|-----------|--------|--------|
| 2026-01-18 | Added deps/ progressive loading | Context budget management | -60% active context per phase | Active |
| 2026-01-20 | YAML-first format | Machine-parseable, consistent | All artifacts parseable by meta-agent | Active |
| 2026-02-23 | project-researcher → v3.0 | AST analysis, DISCOVER phase, dependency graph | Better monorepo support, higher confidence | Active |
| 2026-02-23 | meta-agent → v9.0 | Constitutional AI, ADAS, phase contracts | More reliable artifact generation | Active |
| 2026-02-23 | `sync/initial` branch | `main` branch protected on GitHub | Sync works without bypassing protection | Active |
| 2026-02-23 | `git add -f .claude/` in sync script | Global `~/.gitignore` excludes `.claude/` | Sync script uses force-add | Active |
| 2026-02-23 | `CLAUDE.md` in global gitignore | Prevents accidental commit to non-kit repos | Must force-add when committing kit itself | Active |

---

## Technical Debt

| Area | Issue | Severity | Recommendation |
|------|-------|----------|----------------|
| db-explorer | No AGENT.md, minimal structure (only deps/queries.md) | LOW | Add AGENT.md with proper YAML frontmatter and phases |
| sync-to-github.sh | Branch divergence possible when pushing from both project dir and backup dir | MEDIUM | Only sync from one source; document in README |
| project-researcher AGENT.md | PHASE 5 listed as DATABASE but references `phases/4-map.md#4.6` | LOW | Create separate `phases/5-database.md` |
| settings.json hooks | Relative script paths break if not run from project root | MEDIUM | Document working directory requirement |
| commands/project-researcher.md | Missing version/updated in frontmatter | LOW | Add version, updated fields |

---

## Change History

### v1.0 — 2026-02-23

**Initial generation (AUGMENT mode):**
- `.claude/settings.json` with hooks configuration created
- `.claude/scripts/sync-to-github.sh` created and configured
- `.claude/commands/project-researcher.md` created (slash command wrapper)
- `CLAUDE.md` at project root created
- project-researcher upgraded to v3.0 (AST analysis, DISCOVER phase, dependency graph)
- meta-agent at v9.0 (Constitutional AI, ADAS archive, phase contracts)

**Sections updated:** All (initial generation)

---

## Metadata

- **Analysis Mode:** AUGMENT
- **Analysis Method:** grep-based
- **AST Available:** no (config-only kit — no source code files)
- **Confidence Score:** HIGH (0.92)
- **Low Confidence Areas:** db-explorer structure (minimal files)
- **Recommended Reviews:** sync-to-github.sh divergence handling, settings.json hook paths
- **Monorepo:** no
- **Modules Analyzed:** 1
