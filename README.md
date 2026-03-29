<p align="center">
  <strong>Claude Kit</strong><br/>
  Reusable configuration kit for <a href="https://docs.anthropic.com/en/docs/claude-code">Claude Code</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Claude_Code-config_kit-5A45FF?style=flat-square&logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCI+PHBhdGggZD0iTTEyIDJMMiAxOWgyMEwxMiAyeiIgZmlsbD0id2hpdGUiLz48L3N2Zz4=" alt="Claude Code Config Kit"/>
  <img src="https://img.shields.io/badge/agents-5_pipeline-1a73e8?style=flat-square" alt="Agents"/>
  <img src="https://img.shields.io/badge/skills-6_packages-f9ab00?style=flat-square" alt="Skills"/>
  <img src="https://img.shields.io/badge/hooks-19_scripts-0d904f?style=flat-square" alt="Hooks"/>
  <img src="https://img.shields.io/badge/languages-31_via_tree--sitter-00897b?style=flat-square" alt="Languages"/>
</p>

---

Structured multi-agent development workflow with built-in planning, implementation, and code review phases. Supports any language and framework — Go, Python, TypeScript, Rust, Java, and 26 more via tree-sitter analysis.

---

## 📑 Table of Contents

- [⚡ Quick Start](#-quick-start)
- [🔧 Commands](#-commands)
- [🏗 Architecture](#-architecture)
- [🔌 MCP Servers](#-mcp-servers)
- [📂 Project Structure](#-project-structure)
- [🪝 Hooks](#-hooks)
- [📐 Conventions](#-conventions)

---

## ⚡ Quick Start

### Installation

```bash
curl -sL https://raw.githubusercontent.com/hex0xdeadbeef/claude-kit/main/install.sh | bash
```

### Update existing installation

```bash
bash install.sh --update
```

### First Steps

```bash
# 1. Edit CLAUDE.md — update Language Profile to match your project stack
# 2. Analyze codebase and generate PROJECT-KNOWLEDGE.md
/project-researcher

# 3. Validate configuration
/meta-agent onboard
```

### Options

```bash
KIT_VERSION=v1.0.0 bash install.sh    # install specific version
INSTALL_DIR=/path/to/project bash install.sh --update   # install to specific directory
```

<details>
<summary>Manual Installation (advanced)</summary>

```bash
git clone https://github.com/hex0xdeadbeef/claude-kit.git
cd claude-kit
bash install.sh                        # install to current directory
bash install.sh --update               # update existing installation

# Or copy manually:
cp -r .claude/ /path/to/your/project/
cp CLAUDE.md /path/to/your/project/
# Merge .gitignore manually

# Optional: personal settings overrides (gitignored, never overwritten by updates)
cp .claude/settings.local.json.example /path/to/your/project/.claude/settings.local.json
```

</details>

---

## 🔧 Commands

### `/workflow` — Full Development Cycle

The main command that orchestrates the entire development process. Executes all phases sequentially with user confirmation between steps.

**Pipeline:** `task-analysis` → `designer*` → `planner` → `plan-review` → `coder` → `code-review`

\* designer runs for L/XL tasks only. S/M skip to planner.

```bash
/workflow Add new REST endpoint for profiles
/workflow --auto Implement resource update         # autonomous mode, no confirmations
/workflow --from-phase 3                            # resume from specified phase
/workflow --from-phase 0.7                           # resume from design phase
```

<details>
<summary>⚙️ Modes & Phases</summary>

**Modes:**

| Mode | Flag | Description |
|------|------|-------------|
| Interactive | *(default)* | Confirmation before each phase |
| Autonomous | `--auto` | All phases automatically, no confirmations |
| Resume | `--from-phase N` | Resume from specified phase |

**Phases:**

| # | Phase | Description |
|---|-------|-------------|
| 1 | Task Analysis | Complexity classification (S/M/L/XL) and route selection |
| 1.5 | Design | Requirements exploration + approach selection *(L/XL only, optional for M new_feature/integration)* |
| 2 | Planning | Codebase research, implementation plan creation |
| 3 | Plan Review | Plan validation against architecture *(skipped for S-complexity)* |
| 4 | Implementation | Code writing strictly per approved plan, running tests |
| 5 | Code Review | Change review: architecture, security, quality |
| 6 | Completion | Git commit + lessons learned *(if non-trivial)* |

</details>

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

### `/meta-agent` — Artifact Lifecycle Manager

Creates, enhances, audits, and manages Claude Code artifacts (commands, skills, rules, agents). 9-phase workflow with quality gates.

<details>
<summary>📋 Usage examples</summary>

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

**Flags:** `--dry-run` (preview) · `--explore` (Tree of Thought)

**Artifact types:** `command` · `skill` · `rule` · `agent`

</details>

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

---

### `/review-checklist` — Review Checklist Reference

Displays the code review checklist: architecture, security (OWASP), code quality, performance.

```bash
/review-checklist
```

---

### 🗺 Command Selection Guide

| Scenario | Command |
|----------|---------|
| Full feature implementation from scratch | `/workflow` |
| Autonomous implementation without confirmations | `/workflow --auto` |
| Need a plan before writing code | `/planner` |
| Plan approved, need implementation | `/coder` |
| Setting up kit in a new project | `/meta-agent onboard` |
| Creating new commands/skills/agents | `/meta-agent create` |
| Preview artifact changes | `/meta-agent enhance --dry-run` |
| Understand project structure | `/project-researcher` |
| Explore DB schema | `/db-explorer` |

---

## 🏗 Architecture

The system is a **5-phase development pipeline** managed by the orchestrator (`/workflow`), which sequentially delegates work to specialized agents. Each agent has a strictly defined responsibility zone, model assignment, and skill set.

<details>
<summary>🎨 Color Legend</summary>

```mermaid
flowchart LR
    L1["opus — planning,<br/>orchestration"]
    L2["sonnet — review,<br/>implementation"]
    L3["haiku — fast search,<br/>monitoring"]
    L4["completion,<br/>post-processing"]
    L5["blocking gate,<br/>stop condition"]
    L6["skills,<br/>context enrichment"]
    L7["neutral —<br/>infrastructure"]

    A1[ ] -->|"mandatory flow"| A2[ ]
    B1[ ] -.->|"optional (L/XL only)"| B2[ ]

    style L1 fill:#1a73e8,color:#fff,stroke:#1557b0
    style L2 fill:#9334e6,color:#fff,stroke:#7627bb
    style L3 fill:#00897b,color:#fff,stroke:#00695c
    style L4 fill:#0d904f,color:#fff,stroke:#0a7040
    style L5 fill:#d93025,color:#fff,stroke:#b3261e
    style L6 fill:#f9ab00,color:#333,stroke:#e69500
    style L7 fill:#e0e0e0,color:#333,stroke:#999
    style A1 fill:none,stroke:none
    style A2 fill:none,stroke:none
    style B1 fill:none,stroke:none
    style B2 fill:none,stroke:none
```

</details>

<details>
<summary>🔄 Development Pipeline</summary>

```mermaid
flowchart TB
    subgraph STARTUP ["Startup"]
        TA["Task Analysis<br/>(S/M/L/XL)"] --> S1["Memory search"]
        S1 --> S3["Session recovery check"]
    end

    S3 -->|S| ROUTE_S["Minimal route:<br/>skip Plan Review"]
    S3 -->|M| ROUTE_M["Standard route"]
    S3 -->|L| ROUTE_L["Full route +<br/>Sequential Thinking"]
    S3 -->|XL| ROUTE_XL["Full route +<br/>ST required"]

    ROUTE_S --> PLANNER
    ROUTE_M --> PLANNER
    ROUTE_L --> PLANNER
    ROUTE_XL --> PLANNER

    subgraph PHASE1 ["Phase 1: Planning — /planner (opus)"]
        PLANNER["Understand scope"] --> RESEARCH["Research codebase"]
        RESEARCH --> DESIGN["Design solution"]
        DESIGN --> DOCUMENT["Write plan to<br/>prompts/feature.md"]
    end

    RESEARCH -.->|"L/XL: Task tool"| CRES["code-researcher<br/>(haiku)"]

    DOCUMENT --> CHECK_S{"S-complexity?"}
    CHECK_S -->|Yes| EVALUATE
    CHECK_S -->|No| PLAN_REVIEW

    subgraph PHASE2 ["Phase 2: Plan Review — plan-reviewer (sonnet)"]
        PLAN_REVIEW["Read plan +<br/>check architecture"]
        PLAN_REVIEW --> VERDICT1{"Verdict?"}
    end

    VERDICT1 -->|APPROVED| EVALUATE
    VERDICT1 -->|NEEDS_CHANGES| LOOP1{"Iteration < 3?"}
    VERDICT1 -->|REJECTED| STOP1["STOP pipeline"]

    LOOP1 -->|Yes| PLANNER
    LOOP1 -->|"No: limit reached"| STOP2["STOP: show summary,<br/>request user help"]

    subgraph PHASE3 ["Phase 3: Implementation — /coder (sonnet)"]
        EVALUATE{"Evaluate plan:<br/>PROCEED / REVISE / RETURN"}
        EVALUATE -->|PROCEED| IMPLEMENT["Implement Parts<br/>in dependency order"]
        EVALUATE -->|REVISE| ADJUST["Note adjustments"] --> IMPLEMENT
        IMPLEMENT --> SIMPLIFY{"SIMPLIFY<br/>(L/XL, ≥5 parts)"}
        SIMPLIFY -->|"applied / skipped"| VERIFY{"fmt + lint + test"}
        VERIFY -->|PASS| HANDOFF3["Form handoff"]
        VERIFY -->|"FAIL (max 3x)"| STOP3["STOP: test failures,<br/>request manual fix"]
    end

    EVALUATE -->|RETURN| PLAN_REVIEW

    IMPLEMENT -.->|"L/XL: Task tool"| CRES

    HANDOFF3 --> CODE_REVIEW

    subgraph PHASE4 ["Phase 4: Code Review — code-reviewer (sonnet, worktree)"]
        CODE_REVIEW["Read diff +<br/>check architecture, security,<br/>tests, style"]
        CODE_REVIEW --> VERDICT2{"Verdict?"}
    end

    VERDICT2 -->|APPROVED| COMPLETION
    VERDICT2 -->|APPROVED_WITH_COMMENTS| COMPLETION
    VERDICT2 -->|CHANGES_REQUESTED| LOOP2{"Iteration < 3?"}

    LOOP2 -->|Yes| EVALUATE
    LOOP2 -->|"No: limit reached"| STOP4["STOP: show summary,<br/>request user help"]

    subgraph PHASE5 ["Phase 5: Completion"]
        COMPLETION["Git commit"] --> LESSONS{"Non-trivial?"}
        LESSONS -->|Yes| SAVE["Save lessons<br/>to Memory"]
        LESSONS -->|No| FINAL["Done"]
        SAVE --> FINAL
    end

    style STARTUP fill:#e0e0e0,color:#333,stroke:#999
    style PHASE1 fill:#1a73e8,color:#fff,stroke:#1557b0
    style PHASE2 fill:#9334e6,color:#fff,stroke:#7627bb
    style PHASE3 fill:#9334e6,color:#fff,stroke:#7627bb
    style PHASE4 fill:#9334e6,color:#fff,stroke:#7627bb
    style PHASE5 fill:#0d904f,color:#fff,stroke:#0a7040
    style STOP1 fill:#d93025,color:#fff,stroke:#b3261e
    style STOP2 fill:#d93025,color:#fff,stroke:#b3261e
    style STOP3 fill:#d93025,color:#fff,stroke:#b3261e
    style STOP4 fill:#d93025,color:#fff,stroke:#b3261e
    style CRES fill:#00897b,color:#fff,stroke:#00695c
```

</details>

<details>
<summary>📨 Handoff Data Flow</summary>

```mermaid
flowchart LR
    PL2["/planner"] -->|"artifact path<br/>key_decisions<br/>known_risks<br/>complexity"| PR2["plan-reviewer"]

    PR2 -->|"APPROVED:<br/>verdict, approved_notes,<br/>iteration N/3"| CO2["/coder"]
    PR2 -.->|"NEEDS_CHANGES:<br/>issues list"| PL2

    CO2 -->|"branch<br/>parts_implemented<br/>evaluate_adjustments<br/>deviations_from_plan<br/>risks_mitigated"| CR2["code-reviewer"]

    CR2 -->|"APPROVED:<br/>verdict, iteration N/3"| DONE2["completion"]
    CR2 -.->|"CHANGES_REQUESTED:<br/>issues[]"| CO2

    style PL2 fill:#1a73e8,color:#fff,stroke:#1557b0
    style PR2 fill:#9334e6,color:#fff,stroke:#7627bb
    style CO2 fill:#9334e6,color:#fff,stroke:#7627bb
    style CR2 fill:#9334e6,color:#fff,stroke:#7627bb
    style DONE2 fill:#0d904f,color:#fff,stroke:#0a7040
```

</details>

<details>
<summary>🧩 Standalone Commands</summary>

```mermaid
flowchart LR
    subgraph META ["/meta-agent · opus"]
        direction TB
        MA1["INIT → EXPLORE → ANALYZE"] --> MA2["PLAN → CONSTITUTE → DRAFT"] --> MA3["APPLY → VERIFY → CLOSE"]
    end
    META --> ART["Artifacts:<br/>commands, skills,<br/>rules, agents"]

    subgraph PROJ ["/project-researcher · opus"]
        direction TB
        PR1["discovery → detection → graph"] --> PR2["analysis → critique → generation"] --> PR3["verification → report"]
    end
    PROJ --> PK["PROJECT-KNOWLEDGE.md"]

    subgraph DBE ["/db-explorer · sonnet"]
        DB_TOOLS["MCP postgres:<br/>list_tables, describe, query"]
    end
    DBE --> SCH["Schema Report"]

    style META fill:#1a73e8,color:#fff,stroke:#1557b0
    style PROJ fill:#1a73e8,color:#fff,stroke:#1557b0
    style DBE fill:#9334e6,color:#fff,stroke:#7627bb
```

</details>

<details>
<summary>📦 Skill Loading</summary>

```mermaid
flowchart LR
    subgraph SKILLS ["Skills (on-demand loading)"]
        WP["workflow-protocols · 9 files"]
        PLR["planner-rules · 8 files"]
        CDR["coder-rules · 5 files"]
        PRR["plan-review-rules · 5 files"]
        CRR["code-review-rules · 5 files"]
        TDD["tdd-go · 3 files"]
    end

    WF2["/workflow"] --> WP
    PL2["/planner"] --> PLR
    CO2["/coder"] --> CDR
    CO2 -->|"if TDD in plan"| TDD
    PREV["plan-reviewer"] --> PRR
    CREV["code-reviewer"] --> CRR

    WP -->|startup| A1["autonomy.md,<br/>orchestration-core.md"]
    WP -->|on-demand| A2["handoff-protocol.md,<br/>checkpoint-protocol.md,<br/>re-routing.md,<br/>pipeline-metrics.md"]

    PLR -->|startup| B1["mcp-tools.md"]
    PLR -->|"L/XL only"| B2["sequential-thinking-guide.md"]
    PLR -->|"M+ only"| B3["data-flow.md"]

    style SKILLS fill:#f9ab00,color:#333,stroke:#e69500
    style WF2 fill:#1a73e8,color:#fff,stroke:#1557b0
    style PL2 fill:#1a73e8,color:#fff,stroke:#1557b0
    style CO2 fill:#9334e6,color:#fff,stroke:#7627bb
    style PREV fill:#9334e6,color:#fff,stroke:#7627bb
    style CREV fill:#9334e6,color:#fff,stroke:#7627bb
```

</details>

<details>
<summary>🪝 Hook Lifecycle</summary>

```mermaid
flowchart TB
    IL["InstructionsLoaded:<br/>validate-instructions.sh"] --> UP["User Prompt"]
    UP -->|UserPromptSubmit| ENR["enrich-context.sh<br/>+ exploration budget"]
    ENR --> CMD["Command Execution"]

    CMD --> TOOL{"Tool Call?"}
    TOOL -->|"Write / Edit"| PRE1["protect-files.sh (blocking)"]
    TOOL -->|Write| PRE2["check-artifact-size.sh (blocking)"]
    TOOL -->|Bash| PRE3["block-dangerous-commands.sh (blocking)"]
    TOOL -->|Bash| PRE4["pre-commit-build.sh (blocking)"]

    PRE1 --> EXEC["Tool Executes"]
    PRE2 --> EXEC
    PRE3 --> EXEC
    PRE4 --> EXEC

    EXEC -->|"Write / Edit"| POST1["auto-fmt-go.sh<br/>(non-blocking)"]
    EXEC -->|Edit| POST2["yaml-lint.sh<br/>(non-blocking)"]
    EXEC -->|Write| POST3["check-references.sh<br/>(non-blocking)"]
    EXEC -->|"Write / Edit"| POST4["check-plan-drift.sh<br/>(non-blocking)"]

    POST1 --> CONT["Continue"]
    POST2 --> CONT
    POST3 --> CONT
    POST4 --> CONT

    CONT -->|"context limit"| COMPACT["PreCompact (non-blocking):<br/>save-progress-before-compact.sh"]
    COMPACT --> PCOMPACT["PostCompact (non-blocking):<br/>verify-state-after-compact.sh"]
    CONT -->|"subagent exits"| SUBSTOP["SubagentStop (blocking):<br/>save-review-checkpoint.sh"]
    CONT -->|"worktree created"| WT["WorktreeCreate (non-blocking):<br/>prepare-worktree.sh"]
    CONT --> STOP["Stop (blocking):<br/>1. verify-phase-completion.sh<br/>2. check-uncommitted.sh"]
    CONT -.->|"API error"| SFAIL["StopFailure:<br/>log-stop-failure.sh"]

    STOP --> SESS["SessionEnd:<br/>session-analytics.sh"]
    SESS --> NOTIFY["Notification:<br/>notify-user.sh"]

    style IL fill:#f9ab00,color:#333,stroke:#e69500
    style UP fill:#1a73e8,color:#fff,stroke:#1557b0
    style ENR fill:#f9ab00,color:#333,stroke:#e69500
    style CMD fill:#e0e0e0,color:#333,stroke:#999
    style PRE1 fill:#d93025,color:#fff,stroke:#b3261e
    style PRE2 fill:#d93025,color:#fff,stroke:#b3261e
    style PRE3 fill:#d93025,color:#fff,stroke:#b3261e
    style PRE4 fill:#d93025,color:#fff,stroke:#b3261e
    style EXEC fill:#e0e0e0,color:#333,stroke:#999
    style POST1 fill:#0d904f,color:#fff,stroke:#0a7040
    style POST2 fill:#0d904f,color:#fff,stroke:#0a7040
    style POST3 fill:#0d904f,color:#fff,stroke:#0a7040
    style POST4 fill:#0d904f,color:#fff,stroke:#0a7040
    style COMPACT fill:#9334e6,color:#fff,stroke:#7627bb
    style PCOMPACT fill:#9334e6,color:#fff,stroke:#7627bb
    style SUBSTOP fill:#9334e6,color:#fff,stroke:#7627bb
    style WT fill:#9334e6,color:#fff,stroke:#7627bb
    style STOP fill:#d93025,color:#fff,stroke:#b3261e
    style SFAIL fill:#00897b,color:#fff,stroke:#00695c
    style SESS fill:#00897b,color:#fff,stroke:#00695c
    style NOTIFY fill:#00897b,color:#fff,stroke:#00695c
```

</details>

### ⚙️ Model Routing

| Model | Effort | Components | MaxTurns | Purpose |
|-------|--------|------------|----------|---------|
| **opus** | high | `/workflow`, `/planner`, `/project-researcher`, `/meta-agent` | — | Deep reasoning, orchestration, planning |
| **sonnet** | high | `/coder`, `plan-reviewer`, `code-reviewer`, `/db-explorer` | 30 | Implementation, review, execution |
| **haiku** | medium | `code-researcher`, PR subagents (discovery, report) | 20 | Fast read-only search |

### 📊 Complexity Routing

| Complexity | Parts | Layers | Plan Review | Sequential Thinking | code-researcher |
|------------|-------|--------|-------------|--------------------|-----------------|
| **S** | 1 | 1 | skip | not needed | skip |
| **M** | 2–3 | 2 | standard | as needed | skip |
| **L** | 4–6 | 3+ | standard | recommended | yes |
| **XL** | 7+ | 4+ | standard | required | yes |

### 🔑 Key Principles

- **Sequential execution** — phases don't run in parallel
- **Handoff Protocol** — 4 typed payload contracts between phases with narrative casting
- **Context Isolation** — review phases run as isolated subagents (clean context, no authorship bias)
- **Loop Limits** — max 3 iterations per review cycle, then STOP and ask user
- **Checkpoint Protocol** — state saved after each phase for session recovery (12 YAML fields)
- **Evaluate Protocol** — coder critically evaluates plan before implementation (PROCEED/REVISE/RETURN gate)
- **Conditional Deps Loading** — S-complexity skips heavy skill loading, saves ~6,300 tokens
- **Re-Routing** — pipeline adjusts route on complexity mismatch (downgrade/upgrade)
- **Cron Auto-Save** — periodic checkpoint auto-save for L/XL tasks via CronCreate (every 10min)
- **Simplify Protocol** — optional code simplification before review (L/XL, ≥5 parts, 30% guard)
- **Worktree Optimization** — sparse checkout via `worktree.sparsePaths` reduces worktree size in monorepos

---

## 🔌 MCP Servers

Configure in `~/.claude/mcp.json`:

### Required

| Server | Package | Purpose |
|--------|---------|---------|
| `context7` | `@upstash/context7-mcp` | Library documentation lookup |
| `sequential-thinking` | — | Structured reasoning for complex tasks |

### Optional

| Server | Package | Purpose |
|--------|---------|---------|
| `postgres` | `@anthropic/mcp-postgres` | Required for `/db-explorer` |
| `tree_sitter` | `mcp-server-tree-sitter` | Code analysis (symbols, deps, repo-map) — used by `/project-researcher` |

<details>
<summary>🔧 Installing tree_sitter MCP Server</summary>

The original `mcp-server-tree-sitter` v0.5.1 is incompatible with `py-tree-sitter >= 0.24` (removed `Query.captures()` API). Use the patched fork:

```bash
pipx install git+ssh://git@github.com/hex0xdeadbeef/mcp-server-tree-sitter.git
```

Then add to `~/.claude/mcp.json`:

```json
{
  "mcpServers": {
    "tree_sitter": {
      "command": "mcp-server-tree-sitter",
      "args": ["--stdio"]
    }
  }
}
```

</details>

---

## 📂 Project Structure

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
│   ├── code-review-rules/ # Security checklist (OWASP), review checklists
│   └── tdd-go/            # TDD workflow for Go projects
├── templates/             # Templates for creating new artifacts
├── prompts/               # Generated implementation plans
├── scripts/               # Lifecycle hook scripts (15 scripts)
├── rules/                 # Cross-cutting constraints (architecture rules)
├── workflow-state/        # Runtime state (gitignored, generated during workflow)
├── agent-memory/          # Agent-specific persistent memory
├── archive/               # Archived artifacts
├── worktrees/             # Git worktree management
├── settings.json          # Claude Code project settings + hooks (git-committed)
├── settings.local.json.example  # Template for personal overrides
└── PROJECT-KNOWLEDGE.md   # Auto-generated project knowledge base
```

---

## 🪝 Hooks

Configured in `.claude/settings.json`. Enforce quality automatically:

| Hook | Trigger | Purpose |
|------|---------|---------|
| `validate-instructions.sh` | InstructionsLoaded | Validate critical rules loaded into context |
| `enrich-context.sh` | UserPromptSubmit | Enrich prompt with project context + exploration budget |
| `protect-files.sh` | PreToolUse (Write/Edit) | Protect critical config files from agent modification |
| `check-artifact-size.sh` | PreToolUse (Write) | Block writes exceeding size thresholds |
| `block-dangerous-commands.sh` | PreToolUse (Bash) | Block destructive shell commands |
| `pre-commit-build.sh` | PreToolUse (Bash) | Validate `go build` before git commit |
| `auto-fmt-go.sh` | PostToolUse (Write/Edit) | Auto-format Go code |
| `yaml-lint.sh` | PostToolUse (Edit) | Validate YAML structure |
| `check-references.sh` | PostToolUse (Write) | Validate all file references |
| `check-plan-drift.sh` | PostToolUse (Write/Edit) | Detect plan drift during implementation |
| `save-progress-before-compact.sh` | PreCompact | Save checkpoint before context compaction |
| `verify-state-after-compact.sh` | PostCompact | Verify workflow state integrity after compaction |
| `save-review-checkpoint.sh` | SubagentStop | Persist review completion state |
| `prepare-worktree.sh` | WorktreeCreate | Prepare worktree environment for code review |
| `verify-phase-completion.sh` | Stop | Ensure all meta-agent phases completed |
| `check-uncommitted.sh` | Stop | Warn on uncommitted changes |
| `session-analytics.sh` | SessionEnd | Record session analytics |
| `log-stop-failure.sh` | StopFailure | Log API errors to session analytics |
| `notify-user.sh` | Notification | Desktop notifications for agent events |

---

## 📐 Conventions

- Artifacts use YAML-first format (>80% YAML, minimal prose)
- Language: English for code, YAML keys, and artifact specs
- Size limits enforced by hooks (`check-artifact-size.sh`)
- Examples use grep/glob patterns to find current code, not hardcoded snippets
