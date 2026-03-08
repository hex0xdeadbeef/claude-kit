# Project Knowledge: claude-kit

**Last Updated:** 2026-03-08T15:10:00Z
**Version:** b230d91
**Researcher:** project-researcher agent v3.0
**Analysis Method:** grep-based

---

## Executive Summary

claude-kit is a reusable Claude Code configuration kit that provides a comprehensive set of agents, commands, templates, and hooks for AI-assisted software development. The project itself is written primarily in Markdown (YAML-first format) with Shell scripts for enforcement hooks. It follows a hub-and-spoke architecture where commands serve as entry points that delegate to agents, which in turn contain dependency documents for phase-specific logic and shell scripts for quality enforcement.

The kit is designed to be copied into any Go project and provides a full development lifecycle: from project onboarding and research through planning, coding, and code review. It includes 3 agents (meta-agent, project-researcher, db-explorer), 9 slash commands, 7 shell scripts, 6 templates, and extensive dependency documentation totaling approximately 22,650 lines across 106 files.

---

## Project Structure

### Module Map

**Type:** single module
**Strategy:** single

| Module | Language | Type | Dependencies |
|--------|----------|------|-------------|
| claude-kit (.claude/) | Markdown + Shell | configuration-kit | memory MCP, sequential-thinking MCP, context7 MCP, tree_sitter MCP, jq, git |

### Directory Tree

```
.claude/
├── agents/
│   ├── db-explorer/          # Database exploration agent
│   │   └── deps/             # Query templates
│   ├── meta-agent/           # Artifact lifecycle management agent
│   │   ├── deps/             # 20+ dependency documents (phases, gates, contracts)
│   │   ├── scripts/          # 5 shell scripts (hooks, linters, validators)
│   │   └── templates/        # Onboarding templates (mcp.json, settings.json)
│   └── project-researcher/   # Codebase analysis agent
│       ├── deps/             # Orchestration, AST, reflexion, state contracts
│       ├── examples/         # Sample reports, confidence scoring
│       ├── phases/           # Critique phase
│       ├── reference/        # Language patterns, scoring
│       ├── subagents/        # 7 subagents (detection, discovery, graph, analysis, generation, verification, report)
│       └── templates/        # project-knowledge.md template
├── archive/                  # Archived artifacts (.gitkeep)
├── commands/
│   ├── workflow.md           # Full dev cycle orchestrator
│   ├── planner.md            # Research → implementation plan
│   ├── plan-review.md        # Plan validation
│   ├── coder.md              # Implementation per approved plan
│   ├── code-review.md        # Code review before merge
│   ├── meta-agent.md         # Artifact CRUD operations
│   ├── project-researcher.md # Codebase analysis
│   ├── db-explorer.md        # Database schema exploration
│   ├── review-checklist.md   # Code review checklist reference
│   └── deps/                 # Command-specific dependencies
│       ├── core/             # Shared: autonomy, beads, context-isolation, error-handling, mcp-tools
│       ├── workflow/         # Checkpoint, handoff, orchestration, pipeline metrics
│       ├── planner/          # Task analysis, data flow, checklists
│       ├── plan-review/      # Architecture checks, required sections
│       ├── coder/            # Implementation checklists
│       └── code-review/      # Security checklist, examples
├── prompts/                  # Custom prompts (.gitkeep)
├── scripts/
│   └── sync-to-github.sh    # GitHub synchronization script
├── templates/
│   ├── agent.md              # Agent creation template
│   ├── command.md            # Command creation template
│   ├── skill.md              # Skill creation template
│   ├── rule.md               # Rule creation template
│   └── plan-template.md      # Plan creation template
├── settings.json             # Claude Code configuration (model, hooks, permissions)
└── settings.local.json       # Local overrides
```

---

## Architecture Deep-Dive

### Pattern: Hub-and-Spoke with Pipeline Orchestration

The project uses a hub-and-spoke pattern where commands are the hub (entry points) that delegate work to spoke agents. Each agent encapsulates its own dependencies, scripts, and templates. Two major pipeline orchestrations exist: the workflow command (task-analysis -> planner -> plan-review -> coder -> code-review) and the meta-agent workflow (9-phase INIT -> CLOSE pipeline).

### Evidence

| Indicator | Weight | Method |
|-----------|--------|--------|
| commands/ directory with 9 entry points dispatching to agents | HIGH | directory |
| meta-agent.md references 20+ dep files via phases | HIGH | grep |
| workflow.md orchestrates 5 sequential sub-commands | HIGH | grep |
| agents contain self-contained deps/ directories | MEDIUM | directory |
| settings.json hooks delegate to agent scripts | MEDIUM | grep |

### Layers

| Layer | Path | Files | Purpose |
|-------|------|-------|---------|
| Commands | commands/ | 9 | Entry-point layer: slash commands users invoke directly |
| Agents | agents/ | 3 | Agent layer: autonomous processors with own deps and logic |
| Dependencies | commands/deps/ + agents/*/deps/ | 64 | Core logic layer: phase contracts, checklists, guides |
| Scripts | agents/meta-agent/scripts/ + scripts/ | 7 | Enforcement layer: shell hooks for size, lint, references |
| Templates | templates/ | 6 | Scaffolding layer: artifact creation templates |
| Config | . | 2 | Configuration layer: settings.json, settings.local.json |

### Dependency Flow

```
User invokes slash command
        │
        ▼
  ┌─────────────┐
  │  commands/   │  (entry points: /workflow, /planner, /coder, etc.)
  │  *.md        │
  └──────┬───────┘
         │ delegates to
         ▼
  ┌─────────────┐
  │  agents/     │  (meta-agent, project-researcher, db-explorer)
  │  AGENT.md    │
  └──────┬───────┘
         │ loads
         ▼
  ┌─────────────────┐
  │  agents/*/deps/  │  (phase logic, contracts, gates)
  │  *.md            │
  └──────┬───────────┘
         │ enforced by
         ▼
  ┌──────────────────────┐
  │  agents/*/scripts/   │  (hooks: size gate, yaml lint, ref check)
  │  *.sh                │
  └──────────────────────┘
```

### Dependency Violations

*(No circular dependencies detected)*

### Architectural Decisions

| Decision | Rationale | Confidence |
|----------|-----------|------------|
| YAML-first format for all artifacts (>80% YAML, minimal prose) | Structured, parseable, consistent across all artifact types | HIGH |
| Hub-and-spoke over flat commands | Separation of concerns: commands are thin, agents hold logic | HIGH |
| Shell hooks for enforcement instead of in-prompt rules | Deterministic, testable, cannot be ignored by the model | HIGH |
| Progressive model offloading (opus for orchestration, sonnet for subagents) | Cost optimization while preserving quality for critical phases | MEDIUM |
| 9-phase meta-agent pipeline with blocking gates | Prevents skipping steps, ensures quality at each stage | HIGH |

---

## Dependency Topology

### Graph Summary

| Metric | Value |
|--------|-------|
| Total files | 106 |
| Total edges | 87 |
| Circular dependencies | none |

### Hub Files (highest fan-in/fan-out)

| File | Fan-In | Fan-Out | Role |
|------|--------|---------|------|
| commands/meta-agent.md | - | 32 | Primary hub: references most dep files |
| agents/meta-agent/deps/blocking-gates.md | 8 | - | Core contract: referenced by many phases |
| agents/meta-agent/deps/phase-contracts.md | 7 | - | Core contract: phase input/output specs |

### God Packages (high fan-out)

| File | Fan-Out | Recommendation |
|------|---------|---------------|
| commands/meta-agent.md | 32 | Expected for orchestrator — no action needed |

---

## Technology Stack

### Primary Language: Markdown

- Format: YAML-first (>80% YAML structure, minimal prose)
- Standard: CommonMark with YAML frontmatter

### Secondary Language: Shell (Bash)

- Scripts: 7 shell scripts for hooks and automation
- Dependencies: jq (JSON processing), git, gofmt (for target Go projects)

### MCP Servers

| Server | Package | Category | Purpose | Required |
|--------|---------|----------|---------|----------|
| memory | @modelcontextprotocol/server-memory | persistence | Persistent agent memory across sessions | Yes |
| sequential-thinking | (built-in) | reasoning | Structured multi-step reasoning | Yes |
| context7 | @upstash/context7-mcp | documentation | Library documentation lookup | Yes |
| tree_sitter | (built-in) | analysis | AST-based code analysis | Yes |
| postgres | @anthropic/mcp-postgres | database | Database exploration (for db-explorer) | Optional |

### CLI Tools

| Tool | Purpose | Usage |
|------|---------|-------|
| jq | JSON parsing | Hook scripts parse tool input |
| git | Version control | Sync, commit, branch operations |
| gofmt | Go formatting | PostFileEdit/PostFileWrite hooks |

---

## Core Domain

### Entities

| Entity | Description | Key Fields |
|--------|-------------|------------|
| Artifact | Any managed file (command, skill, rule, agent) | type, name, path, size_lines, version |
| Phase | A stage in a pipeline workflow | name, gate, contract, score |
| Gate | Quality checkpoint between phases | name, when, checks, enforcement, on_fail |
| Run | An execution of a multi-phase workflow | run_id, workspace_path, budget_state, phases_completed |
| Subagent | A delegated worker within an agent | name, model, phases, state_input, state_output |

### Key Workflows

1. **Development Workflow** (`/workflow`): task-analysis -> planner -> plan-review -> coder -> code-review. Full development cycle with user confirmation gates between phases.

2. **Meta-Agent Workflow** (`/meta-agent`): INIT -> EXPLORE -> ANALYZE -> PLAN -> CONSTITUTE -> DRAFT -> APPLY -> VERIFY -> CLOSE. Artifact lifecycle management with 7 blocking gates.

3. **Project Research** (`/project-researcher`): VALIDATE -> DISCOVER -> DETECT -> GRAPH -> ANALYZE -> CRITIQUE -> GENERATE -> VERIFY -> REPORT. Codebase analysis producing PROJECT-KNOWLEDGE.md.

4. **Database Exploration** (`/db-explorer`): Interactive PostgreSQL schema exploration via MCP.

---

## Conventions Catalog

### Naming Conventions

```
# File naming: kebab-case
commands/code-review.md
agents/meta-agent/deps/blocking-gates.md

# Directory naming: kebab-case
agents/project-researcher/

# Constants: UPPER_SNAKE_CASE
SIZE_GATE, YAML_LINT, REF_CHECK, PHASE_CHECK

# YAML keys: snake_case
phase_count, output_contract, success_criteria

# Artifact format: YAML-first (>80% YAML, minimal prose)
```

### Error Handling Conventions

```bash
# Hook scripts return JSON decisions:
{"decision": "approve"}
{"decision": "block", "reason": "File exceeds 800 line critical threshold"}

# Exit codes: always 0 (non-zero = hook ignored by Claude Code)
# Enforcement: deterministic shell scripts, not prompt-based rules
```

### Testing Conventions

```
# No automated test suite exists
# Quality enforcement via:
#   1. Shell hook scripts (PreToolUse, PostToolUse, Stop)
#   2. Blocking gates between phases
#   3. Step-quality scoring within agents
#   4. Constitutional evaluation in meta-agent DRAFT phase
```

---

## Entry Points Map

### Slash Commands

| Command | Model | Purpose |
|---------|-------|---------|
| /workflow | opus | Full dev cycle orchestration |
| /planner | opus | Research codebase -> implementation plan |
| /plan-review | opus | Validate plan before coding |
| /coder | opus | Implement code per approved plan |
| /code-review | opus | Code review before merge |
| /meta-agent | opus | Artifact CRUD lifecycle |
| /project-researcher | opus | Codebase analysis -> PROJECT-KNOWLEDGE.md |
| /db-explorer | opus | Database schema exploration |
| /review-checklist | - | Code review checklist reference |

### Agents

| Agent | Location | Purpose |
|-------|----------|---------|
| meta-agent | agents/meta-agent/ | 9-phase artifact lifecycle manager with 20+ deps |
| project-researcher | agents/project-researcher/ | Multi-subagent codebase analyzer |
| db-explorer | agents/db-explorer/ | PostgreSQL schema explorer via MCP |

### Shell Scripts (Hooks)

| Script | Hook Type | Purpose |
|--------|-----------|---------|
| check-artifact-size.sh | PreToolUse(Write) | Block writes exceeding size thresholds |
| yaml-lint.sh | PostToolUse(Edit) | Validate YAML structure after edits |
| check-references.sh | PostToolUse(Write) | Validate file references after writes |
| verify-phase-completion.sh | Stop | Ensure all phases completed before stopping |
| check-plan-drift.sh | (manual) | Detect drift between plan and implementation |
| sync-to-github.sh | (manual) | Synchronize .claude/ to GitHub |

---

## External Integrations

### MCP Servers

| Server | Purpose | Auth |
|--------|---------|------|
| memory | Persistent entity/relation storage | Local (configured in ~/.claude/mcp.json) |
| sequential-thinking | Structured reasoning for complex decisions | Local |
| context7 | Library documentation lookup | API key |
| tree_sitter | AST parsing for code analysis | Local |
| postgres | Database schema exploration (optional) | Connection string |

### Version Control

| Integration | Usage |
|-------------|-------|
| GitHub | sync-to-github.sh script, git remote at github.com:hex0xdeadbeef/claude-kit.git |
| git | Commit tracking, branch management, auto-sync |

---

## Design Patterns Catalog

| Pattern | Instances | Location | Purpose |
|---------|-----------|----------|---------|
| Pipeline Orchestration | 2 | workflow.md, meta-agent.md | Sequential phase execution with gates |
| Hub-and-Spoke | 1 | commands/ -> agents/ | Thin entry points delegating to rich agents |
| Progressive Offloading | 3 | meta-agent subagents | Route expensive work to cheaper models |
| Quality Gate | 7 | blocking-gates.md | Block progression on quality failures |
| Typed Contract | 1 | phase-contracts.md | Strict input/output specs between phases |
| Subagent Delegation | 2 | meta-agent, project-researcher | Spawn focused sub-workers for phases |
| Model Routing | 1 | settings.json | opus for orchestration, sonnet for subagents |
| Template Scaffolding | 5 | templates/ | Consistent structure for new artifacts |

---

## Technical Debt

| Area | Issue | Severity | Recommendation |
|------|-------|----------|----------------|
| Testing | No automated test suite; quality relies on hooks and gates only | MEDIUM | Consider adding shell script tests (bats/shunit2) for hook scripts |
| Confidence | grep-based analysis capped at 0.85 — no AST analysis available for Markdown | LOW | Expected limitation for a Markdown-primary project |
| Templates | Some template sections assume Go-specific patterns (go.mod, *_test.go) | LOW | Generalize templates for multi-language support |

---

## Change History

### b230d91 - 2026-03-08

**Initial PROJECT-KNOWLEDGE.md generation**
- Generated via project-researcher agent (AUGMENT mode)
- Analysis method: grep-based (confidence: 0.85)
- All sections populated from accumulated research state

---

## Metadata

- **Analysis Mode:** AUGMENT
- **Analysis Method:** grep-based
- **AST Available:** no (Markdown-primary project)
- **Confidence Score:** 0.85 (MEDIUM-HIGH, capped for grep-based analysis)
- **Low Confidence Areas:** none identified — project structure is explicit and well-documented
- **Recommended Reviews:** verify MCP server configurations match actual ~/.claude/mcp.json
- **Monorepo:** no
- **Files Analyzed:** 106
- **Total Lines:** 22,650
- **Test Files:** 0
- **Test Coverage:** N/A (no automated tests)

---
