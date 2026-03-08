# Project Knowledge: claude-kit

**Last Updated:** 2026-03-09T00:00:00Z
**Version:** 8c491e0 (sync/initial)
**Researcher:** project-researcher agent v3.0
**Analysis Method:** grep-based (Tier 3)

---

## Executive Summary

claude-kit is a reusable Claude Code configuration kit that provides a complete AI-assisted development infrastructure for any project. It ships a layered artifact system consisting of commands (user-facing entry points), agents (autonomous executors), skills (reusable domain knowledge), templates (scaffolding), scripts (deterministic hooks), and rules (cross-cutting constraints). The project is written entirely in Markdown and Shell (bash), with no application code — its sole purpose is to orchestrate Claude Code's behavior through structured configuration.

The architecture follows an orchestrated artifact system pattern where commands delegate to agents, agents consume skills, and templates/scripts/rules provide cross-cutting support. Three orchestrators (workflow, meta-agent, project-researcher) coordinate multi-phase workflows with quality gates, model routing (opus for judgment, sonnet for generation, haiku for exploration), and progressive context loading.

---

## Project Structure

### Module Map

**Type:** single module
**Strategy:** single

| Module | Language | Type | Dependencies |
|--------|----------|------|-------------|
| . (root) | Markdown/Shell | configuration kit | MCP servers (memory, sequential-thinking, context7, tree_sitter) |

### Directory Tree

```
claude-kit/
├── CLAUDE.md                          # Project-level instructions for Claude Code
├── README.md                          # Usage documentation
├── .gitignore
└── .claude/
    ├── settings.json                  # Model config, MCP servers, hooks, permissions
    ├── agents/                        # Autonomous executors (6 agents)
    │   ├── meta-agent/                # Artifact CRUD lifecycle (9-phase workflow)
    │   │   ├── deps/                  # 18 dependency files (phases, gates, protocols)
    │   │   ├── scripts/               # 5 validation hooks (size, lint, references, drift)
    │   │   └── templates/onboarding/  # Bootstrap templates (mcp.json, settings.json)
    │   ├── project-researcher/        # Deep codebase analysis → PROJECT-KNOWLEDGE.md
    │   │   ├── AGENT.md               # Main agent definition
    │   │   ├── deps/                  # 7 dependency files (AST, state contract, etc.)
    │   │   ├── subagents/             # 7 subagents (discovery, detection, graph, etc.)
    │   │   ├── phases/                # Phase definitions (critique)
    │   │   ├── reference/             # Scoring, language patterns
    │   │   ├── examples/              # Sample reports, confidence scoring
    │   │   └── templates/             # project-knowledge.md template
    │   ├── db-explorer/               # PostgreSQL schema exploration via MCP
    │   │   ├── AGENT.md
    │   │   └── deps/queries.md
    │   ├── plan-reviewer.md           # Validates implementation plans
    │   ├── code-reviewer.md           # Code review of changes
    │   └── code-researcher.md         # Codebase exploration for planning
    ├── commands/                       # User-facing slash commands (7 commands)
    │   ├── workflow.md                # Full dev cycle orchestrator (opus)
    │   ├── meta-agent.md              # Artifact lifecycle management (opus)
    │   ├── planner.md                 # Research → implementation plan
    │   ├── coder.md                   # Implement per approved plan
    │   ├── project-researcher.md      # Trigger project analysis
    │   ├── db-explorer.md             # Database schema exploration
    │   └── review-checklist.md        # Code review checklist reference
    ├── skills/                        # Reusable domain knowledge (5 skills)
    │   ├── workflow-protocols/        # Orchestration, handoff, checkpoints (9 files)
    │   ├── planner-rules/             # Planning methodology, task analysis (8 files)
    │   ├── coder-rules/               # Implementation rules, MCP tools (5 files)
    │   ├── code-review-rules/         # Review checklists, security (5 files)
    │   └── plan-review-rules/         # Architecture checks, required sections (5 files)
    ├── templates/                     # Scaffolding for new artifacts (6 templates)
    │   ├── agent.md
    │   ├── command.md
    │   ├── skill.md
    │   ├── rule.md
    │   ├── plan-template.md
    │   └── project-claude-md.md
    ├── scripts/                       # Lifecycle hooks (4 scripts)
    │   ├── sync-to-github.sh          # Sync configuration to remote
    │   ├── check-uncommitted.sh       # Warn on uncommitted changes
    │   ├── save-progress-before-compact.sh  # Pre-compact state save
    │   └── save-review-checkpoint.sh  # Review state persistence
    ├── rules/                         # Cross-cutting constraints
    │   └── architecture.md            # Go architecture rules (template for target projects)
    ├── prompts/                       # Reusable prompt fragments
    │   └── workflow-migration.md
    ├── agent-memory/                  # Persistent agent state
    │   └── code-reviewer/
    └── archive/                       # Archived/rolled-back artifacts
        └── .gitkeep
```

---

## Architecture Deep-Dive

### Pattern: Orchestrated Artifact System

**Confidence:** 0.85 (grep-based analysis)

The project implements a layered artifact hierarchy where each layer has a clear responsibility boundary. Three orchestrators (workflow, meta-agent, project-researcher) coordinate multi-phase workflows that delegate to lower layers. The dependency flow is strictly acyclic: commands invoke agents, agents consume skills, and all layers may reference templates, scripts, and rules.

### Evidence

| Indicator | Weight | Method |
|-----------|--------|--------|
| 6 distinct artifact types with clear separation | HIGH | directory structure |
| 3 orchestrators with multi-phase workflows | HIGH | grep (phase definitions) |
| Acyclic dependency graph (78 edges, 0 cycles) | HIGH | reference analysis |
| Model routing (opus/sonnet/haiku) in commands | MEDIUM | grep (model: field) |
| Progressive loading via deps/ directories | MEDIUM | directory structure |

### Layers

| Layer | Path | Files | Role | External Deps |
|-------|------|-------|------|--------------|
| Commands | .claude/commands/ | 7 | User-facing entry points (slash commands) | none |
| Agents | .claude/agents/ | 6 (+ subfiles) | Autonomous executors with isolated contexts | MCP servers |
| Skills | .claude/skills/ | 5 (+ subfiles) | Reusable domain knowledge units | none |
| Templates | .claude/templates/ | 6 | Scaffolding for new artifacts | none |
| Scripts | .claude/scripts/ + agents/*/scripts/ | 9 | Deterministic validation hooks | bash |
| Rules | .claude/rules/ | 1 | Cross-cutting constraints | none |

### Dependency Flow

```
User invokes slash command
        │
        ▼
  ┌─────────────┐
  │  Commands    │  (workflow, meta-agent, planner, coder, ...)
  │  model:opus  │
  └──────┬───────┘
         │ delegates to
         ▼
  ┌─────────────┐
  │   Agents     │  (plan-reviewer, code-reviewer, code-researcher, ...)
  │  model:sonnet│
  └──────┬───────┘
         │ reads
         ▼
  ┌─────────────┐
  │   Skills     │  (workflow-protocols, planner-rules, coder-rules, ...)
  └──────┬───────┘
         │ uses
         ▼
  ┌──────────────────────────────────┐
  │  Templates │ Scripts │ Rules     │
  │  (scaffolding, hooks, constraints)│
  └──────────────────────────────────┘
```

### Dependency Violations

*(None detected — clean acyclic graph with 0 circular dependencies)*

### Architectural Decisions

| Decision | Rationale | Confidence |
|----------|-----------|------------|
| YAML-first format for commands/agents | Maximizes information density, reduces prose overhead | HIGH |
| Model routing (opus for judgment, sonnet for generation) | Cost/quality optimization per task type | HIGH |
| Progressive context loading via deps/ directories | Avoids context window overflow on large artifacts | HIGH |
| Gate-based quality control (advisory + deterministic) | Dual enforcement: shell scripts catch deterministic issues, agents catch semantic issues | MEDIUM |
| Severity classification (FATAL/CRITICAL/HIGH/MEDIUM/NON_CRITICAL) | Graduated response to issues, avoids false-positive blocking | MEDIUM |

---

## Dependency Topology

### Graph Summary

| Metric | Value |
|--------|-------|
| Total files analyzed | 114 |
| Total symbols | 82 |
| Total dependency edges | 78 |
| Circular dependencies | 0 |

### Hub Files (highest fan-out)

| File | Fan-Out | Role |
|------|---------|------|
| workflow.md | 12 | Primary orchestrator — coordinates full dev cycle |
| project-researcher/AGENT.md | 11 | Research orchestrator — delegates to 7 subagents |
| meta-agent.md | 10 | Artifact lifecycle orchestrator — 9-phase workflow |
| planner.md | 8 | Planning command — research + plan generation |
| coder.md | 7 | Implementation command — executes approved plans |

### Depth Map

```
Level 0 (foundation):  templates/, rules/, scripts/
Level 1 (knowledge):   skills/ (workflow-protocols, planner-rules, coder-rules, ...)
Level 2 (execution):   agents/ (plan-reviewer, code-reviewer, code-researcher, db-explorer)
Level 3 (orchestration): agents/ (meta-agent, project-researcher)
Level 4 (entry):       commands/ (workflow, meta-agent, planner, coder, ...)
```

### God Packages (high fan-out)

| File | Fan-Out | Recommendation |
|------|---------|---------------|
| workflow.md | 12 | Expected for top-level orchestrator |
| project-researcher/AGENT.md | 11 | Expected — manages 7 subagents |
| meta-agent.md | 10 | Expected — 9-phase workflow with many deps |

### Circular Dependencies

None detected.

### Isolated Packages (0 fan-in)

- `archive/` — storage for rolled-back artifacts, no incoming references
- `agent-memory/` — runtime state, not referenced by other artifacts
- `prompts/workflow-migration.md` — standalone migration prompt

---

## Technology Stack

### Primary Language: Markdown

- Format: YAML-first (>80% YAML, minimal prose) for commands and agents
- Anthropic Skills format for skill files
- Standard Markdown for documentation

### Secondary Language: Shell (bash)

- 10 shell scripts total (5 agent hooks + 1 sync + 4 lifecycle hooks)
- Used for deterministic validation and automation

### Frameworks

| Framework | Category | Purpose | Detection |
|-----------|----------|---------|-----------|
| Claude Code | AI agent framework | Core execution runtime | manifest (settings.json) |
| MCP (Model Context Protocol) | Tool integration | Server-based tool access | manifest (settings.json) |

### MCP Server Integrations

| Server | Package | Category | Required |
|--------|---------|----------|----------|
| memory | @modelcontextprotocol/server-memory | Persistent agent memory | Yes |
| sequential-thinking | (built-in) | Structured reasoning | Yes |
| context7 | @upstash/context7-mcp | Library documentation lookup | Yes |
| tree_sitter | (built-in) | AST-based code analysis | Yes |
| postgres | @anthropic/mcp-postgres | Database exploration | Optional |

---

## Core Domain

### Entities (Artifact Types)

| Entity | Location | Type | Key Fields | Relations |
|--------|----------|------|------------|-----------|
| Command | .claude/commands/*.md | entry_point | name, description, model, triggers | invokes Agents, reads Skills |
| Agent | .claude/agents/*/ | executor | AGENT.md, deps/, scripts/ | consumes Skills, uses Templates |
| Skill | .claude/skills/*/ | knowledge_unit | SKILL.md, subfiles | consumed by Agents/Commands |
| Template | .claude/templates/*.md | scaffolding | Markdown with placeholders | used by meta-agent for creation |
| Rule | .claude/rules/*.md | constraint | paths, triggers | applied globally by Claude Code |
| Script/Hook | .claude/scripts/*.sh | validator | bash script | triggered by settings.json hooks |

### Key Interfaces (Contracts)

| Interface | Location | Purpose |
|-----------|----------|---------|
| Handoff Protocol | skills/workflow-protocols/handoff-protocol.md | Contract for phase-to-phase data transfer |
| State Contract | agents/project-researcher/deps/state-contract.md | Schema for inter-subagent state passing |
| Phase Contract | agents/meta-agent/deps/phase-contracts.md | Requirements for each meta-agent phase |
| Blocking Gates | agents/meta-agent/deps/blocking-gates.md | Conditions that halt workflow progress |

### Workflows

**1. Full Development Cycle (/workflow)**
```
task-analysis → /planner → plan-review (agent) → /coder → code-review (agent)
```
- Orchestrated by workflow.md (opus model)
- User confirmation between phases (unless --auto)
- Max 3 review iterations before halt

**2. Artifact Lifecycle (/meta-agent)**
```
INIT → EXPLORE → ANALYZE → PLAN(ToT) → CONSTITUTE → DRAFT(+eval+reflect) → APPLY → VERIFY → CLOSE(+archive)
```
- 9-phase workflow with embedded sub-phases
- Tree of Thought exploration in PLAN phase (conditional)
- Constitutional evaluation in CONSTITUTE phase

**3. Project Research (/project-researcher)**
```
VALIDATE → DISCOVER → DETECT → GRAPH → ANALYZE → MAP → CRITIQUE → GENERATE
```
- 8-phase deep analysis pipeline
- Delegates to 7 specialized subagents
- Produces PROJECT-KNOWLEDGE.md as output

---

## Conventions Catalog

### Naming Conventions

```
# File naming: kebab-case
workflow.md, meta-agent.md, code-review-rules/

# Entry point files: PascalCase
AGENT.md, SKILL.md, CLAUDE.md

# Skill directories: kebab-case matching skill name
code-review-rules/, workflow-protocols/, planner-rules/

# Template files: kebab-case
plan-template.md, project-claude-md.md
```

### Format Conventions

```yaml
# Commands and Agents: YAML-first format
# - YAML frontmatter with name, description, model
# - Body content is >80% YAML blocks
# - Minimal prose between YAML sections

# Skills: Anthropic Skills format
# - SKILL.md as entry point
# - Supporting files in same directory
# - No YAML frontmatter requirement

# Rules: Markdown with optional YAML frontmatter
# - paths: glob patterns for activation
# - Content as imperative rules
```

### Error Handling Conventions

```
# Severity classification (4 levels):
FATAL       — Abort immediately, no recovery
CRITICAL    — Stop current phase, escalate to user
HIGH        — Block phase completion, require fix
MEDIUM      — Warn, allow continuation with acknowledgment
NON_CRITICAL — Log only, do not block (e.g., beads tool unavailable)
```

### Model Routing

```
# Model assignment by task type:
opus   — Judgment, orchestration, final decisions (workflow, meta-agent)
sonnet — Generation, review, analysis (agents, subagents)
haiku  — Search, exploration, fast lookups (code-researcher)
```

### Hook System

```
# settings.json hooks:
PreToolUse:    Write → check-artifact-size.sh
PostToolUse:   Edit → yaml-lint.sh + gofmt (conditional)
               Write → check-references.sh + gofmt (conditional)
Stop:          → verify-phase-completion.sh + check-uncommitted.sh
PreCompact:    → save-progress-before-compact.sh
SubagentStop:  plan-reviewer|code-reviewer → save-review-checkpoint.sh
```

---

## Entry Points Map

### Slash Commands

| Command | Model | Purpose | Delegates To |
|---------|-------|---------|-------------|
| /workflow | opus | Full dev cycle orchestrator | planner, coder, plan-reviewer, code-reviewer |
| /meta-agent | opus | Artifact CRUD lifecycle | Internal 9-phase workflow |
| /planner | sonnet | Research + implementation plan | code-researcher agent |
| /coder | sonnet | Implement per approved plan | Direct implementation |
| /project-researcher | sonnet | Deep project analysis | 7 subagents |
| /db-explorer | sonnet | Database schema exploration | db-explorer agent |
| /review-checklist | — | Code review checklist reference | None (reference doc) |

### Agent Entry Points

| Agent | Entry File | Type | Invoked By |
|-------|-----------|------|-----------|
| meta-agent | agents/meta-agent/ (via command) | orchestrator | /meta-agent command |
| project-researcher | agents/project-researcher/AGENT.md | orchestrator | /project-researcher command |
| db-explorer | agents/db-explorer/AGENT.md | executor | /db-explorer command |
| plan-reviewer | agents/plan-reviewer.md | reviewer | /workflow Phase 2 |
| code-reviewer | agents/code-reviewer.md | reviewer | /workflow Phase 4 |
| code-researcher | agents/code-researcher.md | explorer | /planner, /coder |

---

## Pattern Catalog

### Design Patterns Detected

| Pattern | Instances | Locations | Purpose |
|---------|-----------|-----------|---------|
| Orchestrator | 3 | workflow.md, meta-agent.md, project-researcher/AGENT.md | Multi-phase workflow coordination |
| Delegation with Isolation | 5 | All agent invocations | Context isolation between phases |
| Progressive Loading | 2 | meta-agent deps/, project-researcher deps/ | Load context incrementally to manage token budget |
| Gate-Based Quality Control | 3 | workflow, meta-agent, project-researcher | Dual: advisory (agent review) + deterministic (shell hooks) |
| Severity Classification | 4 | Error handling across commands/agents | Graduated response to issues |
| Template Method | 4 | templates/ directory | Consistent scaffolding for new artifacts |
| Reflexion / Self-Improvement | 2 | meta-agent (DRAFT eval+reflect), project-researcher (CRITIQUE) | Iterative quality improvement loops |
| Model Routing | 3 | workflow, meta-agent, project-researcher | Task-appropriate model selection |

---

## External Integrations

### MCP Servers

| Server | Purpose | Usage Pattern |
|--------|---------|---------------|
| memory | Persistent agent memory across sessions | Read/write entity-relation graph |
| sequential-thinking | Structured reasoning for complex decisions | Called during planning and analysis |
| context7 | Library documentation lookup | Called when working with external libraries |
| tree_sitter | AST-based code analysis | Used by project-researcher for code structure analysis |
| postgres (optional) | Database exploration | Used by db-explorer agent for schema inspection |

### External Tools

| Tool | Category | Required | Usage |
|------|----------|----------|-------|
| beads | Task tracking | NON_CRITICAL | Optional task tracking in workflow |
| gofmt | Code formatting | Conditional | Auto-format .go files on Edit/Write (via hooks) |
| jq | JSON processing | Yes | Used in hook scripts for TOOL_INPUT parsing |

---

## Technical Debt

| Area | Issue | Severity | Recommendation |
|------|-------|----------|----------------|
| Analysis confidence | Capped at 0.85 due to grep-based analysis (no AST) | LOW | Run with tree_sitter MCP available for higher confidence |
| Unexplored directories | archive/ and agent-memory/ contents not analyzed | LOW | Manual review if these contain significant state |
| Shell script count | Minor inconsistency in count (9 vs 10 across phases) | LOW | Reconcile: 5 agent hooks + 4 lifecycle scripts + 1 sync = 10 total |
| Rules coverage | Only 1 rule file (architecture.md) — serves as template for target projects | LOW | Expected for a kit project; rules generated per target project |
| Test coverage | No formal test suite; quality enforced via hooks + gates | MEDIUM | Consider adding integration tests for hook scripts |

---

## Change History

### Current — 2026-03-09

**Initial PROJECT-KNOWLEDGE.md generation (AUGMENT mode)**

- Full analysis of 114 files across 6 artifact types
- Identified 8 design patterns with 0.85 confidence
- Mapped 78 dependency edges with 0 circular dependencies
- Documented 3 orchestrator workflows with phase contracts

---

## Metadata

- **Analysis Mode:** AUGMENT
- **Analysis Method:** grep-based (Tier 3)
- **AST Available:** No (tree_sitter MCP listed but not used during analysis)
- **Confidence Score:** MEDIUM (0.85 — grep-based cap)
- **Low Confidence Areas:** Pattern instance counts, shell script categorization
- **Recommended Reviews:** Verify agent-memory/ and archive/ contents manually
- **Monorepo:** No
- **Modules Analyzed:** 1
- **Total Files:** 114 (102 .md, 10 .sh, 4 .json, excluding .git)
- **Total Symbols:** 82
- **Total Dependency Edges:** 78
