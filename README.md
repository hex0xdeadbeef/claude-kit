# Claude Kit

Reusable configuration kit for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that provides a structured multi-agent development workflow with built-in planning, implementation, and code review phases.

Supports any language and framework — Go, Python, TypeScript, Rust, Java, and 26 more via tree-sitter analysis.

## Quick Start

### Installation

Copy the kit into your project:

```bash
cp -r .claude/ /path/to/your/project/
cp CLAUDE.md /path/to/your/project/
```

### First Steps

```bash
# Initialize .claude/ configuration for the project
/meta-agent onboard

# Analyze codebase and generate PROJECT-KNOWLEDGE.md
/project-researcher
```

## Commands

### `/workflow` — Full Development Cycle

The main command that orchestrates the entire development process. Executes all phases sequentially with user confirmation between steps.

**Pipeline:** task-analysis → planner → plan-review → coder → code-review

```bash
/workflow Add new REST endpoint for profiles
/workflow --auto Implement resource update         # autonomous mode, no confirmations
/workflow --from-phase 3                            # resume from specified phase
/workflow --minimal Add field to model              # minimal research, critical checks only
```

**Modes:**

- **INTERACTIVE** (default) — confirmation before each phase
- **AUTONOMOUS** (`--auto`) — all phases automatically, no confirmations
- **RESUME** (`--from-phase N`) — resume from specified phase
- **MINIMAL** (`--minimal`) — minimal research, critical checks only

**Phases:**

1. **Task Analysis** — task complexity classification (S/M/L/XL) and route selection
2. **Planning** — codebase research, implementation plan creation
3. **Plan Review** — plan validation against architecture (skipped for S-complexity)
4. **Implementation** — code writing strictly per approved plan, running tests
5. **Code Review** — change review: architecture, security, quality

**Result:** implemented, tested, and reviewed code with a git commit.

---

### `/planner` — Implementation Planning

Researches the codebase and creates a detailed implementation plan with code examples and acceptance criteria. Does not modify project files.

```bash
/planner Add pagination to list endpoint
/planner --minimal Add field to model               # minimal plan without deep research
```

**Result:** plan file at `.claude/prompts/{feature}.md`

---

### `/coder` — Code Implementation

Implements code strictly per approved plan. Runs formatting, linting, and tests after implementation.

```bash
/coder                          # auto-find plan in prompts/
/coder my-feature               # implement specific plan
```

**Result:** working code with passing tests + evaluate output with deviation documentation.

---

### `/review-checklist` — Review Checklist Reference

Displays the code review checklist: architecture, security (OWASP), code quality, performance. Used as a reference for manual or automated reviews.

```bash
/review-checklist
```

---

### `/meta-agent` — Artifact Lifecycle Manager

Creates, enhances, audits, and manages Claude Code artifacts (commands, skills, rules, agents). 9-phase workflow with quality gates.

```bash
/meta-agent onboard                    # initialize .claude/ for a new project
/meta-agent create command my-cmd      # create a new slash command
/meta-agent create skill my-skill      # create a new reusable skill
/meta-agent create agent my-agent      # create a new agent
/meta-agent enhance command my-cmd     # improve an existing artifact
/meta-agent audit                      # quality report for all artifacts
/meta-agent delete rule my-rule        # delete an artifact
/meta-agent rollback                   # rollback last change
/meta-agent list                       # list all artifacts
```

**Session management:**

```bash
/meta-agent --resume {run_id}          # resume from last checkpoint
/meta-agent abort {run_id}             # mark run as aborted
/meta-agent cleanup                    # remove runs older than 7 days
```

**Flags:**

- `--dry-run` — preview changes without applying
- `--track` — enable task tracking via beads
- `--explore` — force Tree of Thought in planning phase

**Artifact types:** `command`, `skill`, `rule`, `agent`

---

### `/project-researcher` — Project Analysis

Autonomous agent for deep codebase analysis: architecture, dependencies, and DB schema. Generates `PROJECT-KNOWLEDGE.md` used by other commands as context.

Architecture: orchestrator + 7 specialized subagents (detection, discovery, graph, analysis, generation, verification, report).

```bash
/project-researcher
```

---

### `/db-explorer` — Database Explorer

Explores PostgreSQL schema and data via MCP. Requires configured `postgres` MCP server.

```bash
/db-explorer                    # explore entire schema
/db-explorer users              # explore specific table
```

## Which Command to Use

| Scenario | Command |
|---|---|
| Full feature implementation from scratch | `/workflow` |
| Quick implementation of a simple task | `/workflow --minimal` |
| Autonomous implementation without confirmations | `/workflow --auto` |
| Need a plan before writing code | `/planner` |
| Plan approved, need implementation | `/coder` |
| Setting up kit in a new project | `/meta-agent onboard` |
| Creating new commands/skills/agents | `/meta-agent create` |
| Preview artifact changes | `/meta-agent enhance --dry-run` |
| Understand project structure | `/project-researcher` |
| Explore DB schema | `/db-explorer` |

## Architecture

The system is a **5-phase development pipeline** managed by the orchestrator (`/workflow`), which sequentially delegates work to four specialized agents. Each agent has a strictly defined responsibility zone.

```
┌──────────────────────────────────────────────────────────────────────┐
│                       WORKFLOW (Orchestrator)                        │
│                                                                      │
│  Phase 0.5       Phase 1       Phase 2       Phase 3      Phase 4   │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐  ┌────────┐ │
│  │  TASK    │─▶│ PLANNER  │─▶│  PLAN    │─▶│ CODER   │─▶│ CODE   │ │
│  │ ANALYSIS │  │          │  │ REVIEW   │  │         │  │ REVIEW │ │
│  └──────────┘  └──────────┘  └──────────┘  └─────────┘  └────────┘ │
│                                   ▲  │          ▲  │               │
│                              NEEDS_CHANGES  CHANGES_REQ            │
│                              (max 3x loop)  (max 3x loop)         │
└──────────────────────────────────────────────────────────────────────┘
```

**Key principles:**

- **Sequential execution** — phases don't run in parallel
- **Handoff Protocol** — structured payload passed between phases
- **Context Isolation** — review phases run as isolated subagents (clean context, no authorship bias)
- **Loop Limits** — max 3 iterations per review cycle
- **Checkpoint Protocol** — state saved after each phase for session recovery
- **Conditional Deps Loading** — lightweight deps for simple tasks (S-complexity saves ~6,300 tokens)
- **Re-Routing** — pipeline adjusts route on complexity mismatch

## MCP Servers

Configure in `~/.claude/mcp.json`:

**Required:**

- `memory` (@modelcontextprotocol/server-memory) — persistent agent memory across sessions
- `context7` (@upstash/context7-mcp) — library documentation lookup
- `sequential-thinking` — structured reasoning for complex tasks

**Optional:**

- `postgres` (@anthropic/mcp-postgres) — required for `/db-explorer`
- `tree_sitter` — code analysis (symbols, dependencies, repo-map)

## Project Structure

```
.claude/
├── agents/                # Autonomous agents
│   ├── meta-agent/        # Artifact lifecycle management (deps, scripts, templates)
│   ├── project-researcher/# Codebase analysis (7 subagents, AST analysis, scoring)
│   ├── db-explorer/       # PostgreSQL exploration
│   ├── plan-reviewer.md   # Plan validation agent (invoked by /workflow)
│   ├── code-reviewer.md   # Code review agent (invoked by /workflow)
│   └── code-researcher.md # Codebase exploration agent
├── commands/              # Slash commands (/workflow, /planner, /coder, etc.)
├── skills/                # Reusable domain knowledge
│   ├── workflow-protocols/# Orchestration, handoff, checkpoints, re-routing
│   ├── planner-rules/     # Planning methodology, task analysis, data flow
│   ├── coder-rules/       # Implementation rules, MCP tools
│   ├── plan-review-rules/ # Architecture checks, required sections
│   └── code-review-rules/ # Security checklist (OWASP), review checklists
├── templates/             # Templates for creating new artifacts
├── prompts/               # Generated implementation plans
├── scripts/               # Lifecycle hooks (check-uncommitted, save-progress, etc.)
├── rules/                 # Cross-cutting constraints (architecture rules)
├── settings.json          # Claude Code project settings + hooks
└── PROJECT-KNOWLEDGE.md   # Auto-generated project knowledge base
```

## Hooks

The kit includes hooks (configured in `.claude/settings.json`) that enforce quality automatically:

| Hook | Trigger | Purpose |
| ------ | --------- | --------- |
| `check-artifact-size.sh` | PreToolUse (Write) | Block writes exceeding size thresholds |
| `yaml-lint.sh` | PostToolUse (Edit) | Validate YAML structure |
| `check-references.sh` | PostToolUse (Write) | Validate all file references |
| `gofmt` | PostToolUse (Edit/Write) | Auto-format Go code |
| `verify-phase-completion.sh` | Stop | Ensure all meta-agent phases completed |
| `check-uncommitted.sh` | Stop | Warn on uncommitted changes |
| `save-progress-before-compact.sh` | PreCompact | Save checkpoint before context compaction |
| `save-review-checkpoint.sh` | SubagentStop | Persist review completion state |

## Conventions

- Artifacts use YAML-first format (>80% YAML, minimal prose)
- Language: English for code, YAML keys, and artifact specs
- Size limits enforced by hooks (`check-artifact-size.sh`)
- Examples use grep/glob patterns to find current code, not hardcoded snippets
