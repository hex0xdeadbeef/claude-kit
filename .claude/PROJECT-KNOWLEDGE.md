# Project Knowledge: Claude Kit

**Last Updated:** 2026-03-09
**Version:** 8c77a7c (sync/initial)
**Researcher:** project-researcher agent v4.2
**Analysis Method:** grep-based (no Go source code; Markdown/Shell project)

---

## Executive Summary

Claude Kit is a reusable configuration kit for Claude Code that provides a structured multi-agent development workflow. The project itself contains no application source code -- it is a framework of Markdown specifications, Shell hook scripts, and JSON configuration that, when copied into a target project, enables a 5-phase development pipeline (task-analysis, planning, plan-review, implementation, code-review) with autonomous agents, checkpoint recovery, and quality gates.

The kit is language-agnostic by design. The default Language Profile in CLAUDE.md targets Go >= 1.24, but this is a template default intended to be overridden per target project via this PROJECT-KNOWLEDGE.md file or direct customization.

---

## Project Structure

### Module Map

**Type:** single module
**Strategy:** single

| Module | Language | Type | Dependencies |
|--------|----------|------|-------------|
| . (root) | Markdown / Shell (Bash) | configuration-kit | git, python3, bash, osascript (optional) |

### Directory Layout (depth 3)

```
claude-kit/
├── CLAUDE.md                          # Root project instructions (loaded every session)
├── README.md                          # User-facing documentation
├── .gitignore
└── .claude/
    ├── settings.json                  # Permissions, hooks, MCP servers (git-committed)
    ├── settings.local.json.example    # Personal overrides template
    ├── PROJECT-KNOWLEDGE.md           # This file (auto-generated research)
    ├── agents/                        # Autonomous agents (6)
    │   ├── plan-reviewer.md           # Plan validation (sonnet, clean context)
    │   ├── code-reviewer.md           # Code review (sonnet, clean context)
    │   ├── code-researcher.md         # Read-only exploration (haiku)
    │   ├── meta-agent/                # Artifact lifecycle (24 deps, 5 scripts)
    │   ├── project-researcher/        # Codebase analysis (7 subagents)
    │   └── db-explorer/               # PostgreSQL exploration
    ├── commands/                       # Slash commands (7)
    │   ├── workflow.md                # /workflow — 5-phase orchestrator (opus)
    │   ├── planner.md                 # /planner — research + plan creation (opus)
    │   ├── coder.md                   # /coder — implementation per plan (sonnet)
    │   ├── meta-agent.md              # /meta-agent — artifact CRUD
    │   ├── project-researcher.md      # /project-researcher — this analysis
    │   ├── db-explorer.md             # /db-explorer — PostgreSQL via MCP
    │   └── review-checklist.md        # /review-checklist — reference display
    ├── skills/                        # Reusable domain knowledge (6 packages)
    │   ├── workflow-protocols/        # 9 files: orchestration, handoff, checkpoint, re-routing
    │   ├── planner-rules/             # 8 files: task analysis, data flow, sequential thinking
    │   ├── coder-rules/               # 5 files: implementation rules, MCP tools
    │   ├── plan-review-rules/         # 5 files: architecture checks, required sections
    │   ├── code-review-rules/         # 5 files: security (OWASP), review checklists
    │   └── tdd-go/                    # 3 files: TDD workflow for Go projects
    ├── rules/                         # Path-triggered constraints (8 rules)
    ├── templates/                     # Artifact creation templates (6)
    ├── scripts/                       # Lifecycle hook scripts (10)
    ├── prompts/                       # Generated implementation plans (runtime)
    ├── workflow-state/                # Runtime state (gitignored)
    ├── agent-memory/                  # Agent-specific persistent memory
    ├── archive/                       # Archived artifacts
    └── worktrees/                     # Git worktree management
```

---

## Architecture Deep-Dive

### Pattern: Multi-Agent Orchestrator Pipeline

Claude Kit implements a **multi-agent orchestrator** pattern where a central command (`/workflow`) drives a sequential 5-phase pipeline, delegating each phase to specialized agents or sub-commands. Review phases run as isolated subagents (clean context) to prevent authorship bias.

**Confidence:** 0.88 (HIGH, calibrated)

### Evidence

| Indicator | Weight | Method |
|-----------|--------|--------|
| /workflow command with sequential phase execution | HIGH | grep (commands/workflow.md) |
| Handoff protocol with typed payload contracts | HIGH | grep (skills/workflow-protocols/) |
| Context isolation for review agents (plan-reviewer, code-reviewer) | HIGH | grep (agents/*.md) |
| Checkpoint protocol for session recovery | MEDIUM | grep (skills/workflow-protocols/checkpoint-protocol.md) |
| Re-routing on complexity mismatch | MEDIUM | grep (skills/workflow-protocols/re-routing.md) |
| Pipeline metrics and analytics | MEDIUM | grep (skills/workflow-protocols/pipeline-metrics.md) |

### Layers

| Layer | Path | Files | Purpose |
|-------|------|-------|---------|
| Orchestration | .claude/commands/ | 7 | Slash commands: entry points for user interaction |
| Agents | .claude/agents/ | 6 | Autonomous execution units with isolated context |
| Skills | .claude/skills/ | 6 packages (35 files) | Reusable domain knowledge loaded on-demand |
| Rules | .claude/rules/ | 8 | Path-triggered constraints for code quality |
| Hooks | .claude/scripts/ | 15 (10 + 5 meta-agent) | Lifecycle hooks enforcing quality gates |
| Templates | .claude/templates/ | 6 | Scaffolding for new artifact creation |

### Dependency Flow

```
User
  │
  ▼
/workflow (orchestrator, opus)
  │
  ├──▶ Phase 0.5: Task Analysis (inline, complexity S/M/L/XL)
  │
  ├──▶ Phase 1: /planner (sub-command, opus)
  │         └── uses: code-researcher agent (haiku)
  │
  ├──▶ Phase 2: plan-reviewer agent (sonnet, isolated)
  │         └── verdict: APPROVED | NEEDS_CHANGES (max 3x loop)
  │
  ├──▶ Phase 3: /coder (sub-command, sonnet)
  │         └── runs: fmt → lint → test
  │
  └──▶ Phase 4: code-reviewer agent (sonnet, isolated)
            └── verdict: APPROVED | CHANGES_REQUIRED (max 3x loop)

Standalone commands:
  /meta-agent ──▶ artifact CRUD (create/enhance/audit/delete)
  /project-researcher ──▶ codebase analysis (7 subagents)
  /db-explorer ──▶ PostgreSQL exploration via MCP
```

### Dependency Violations

*(None detected -- the kit enforces strict layering via rules and hook scripts.)*

### Architectural Decisions

| Decision | Rationale | Confidence |
|----------|-----------|------------|
| Commands vs Agents split | Commands share orchestrator context; agents run in clean context for unbiased review | HIGH |
| Model routing (opus/sonnet/haiku) | opus for deep reasoning (planning), sonnet for execution (coding/review), haiku for fast read-only search | HIGH |
| YAML-first artifact format | >80% YAML for machine-parseable specifications, minimal prose | HIGH |
| Event-driven skill loading | Load protocols on-demand per event triggers, not all upfront, to save context tokens | HIGH |
| Conditional deps for S-complexity | Skip heavy skill loading for simple tasks, saves ~6,300 tokens | MEDIUM |
| Go as default Language Profile | Template default for target projects, not the kit's own language | MEDIUM |

---

## Dependency Topology

### Graph Summary

| Metric | Value |
|--------|-------|
| Total files | 140 |
| Total symbols (cross-references) | 132 |
| Total edges (dependency links) | 281 |
| Circular dependencies | none detected |

### Hub Files (highest fan-in)

| File | Fan-In | Fan-Out | Role |
|------|--------|---------|------|
| CLAUDE.md | 27 | - | Central project instructions, loaded every session |
| README.md | 12 | - | User-facing documentation, installation guide |
| settings.json | 7 | - | Permissions, hooks, MCP server configuration |

### PageRank (relative importance)

```
1.00  CLAUDE.md               — root configuration, referenced by all agents
0.44  README.md               — user documentation
0.39  settings.json           — runtime configuration (hooks, permissions)
```

### Depth Map

```
Level 0 (core):      CLAUDE.md, settings.json, rules/*
Level 1 (skills):    skills/workflow-protocols/, skills/planner-rules/, skills/coder-rules/
Level 2 (commands):  commands/workflow.md, commands/planner.md, commands/coder.md
Level 3 (agents):    agents/plan-reviewer.md, agents/code-reviewer.md, agents/code-researcher.md
Level 4 (complex):   agents/meta-agent/, agents/project-researcher/ (multi-file agents with deps)
```

---

## Technology Stack

### Primary Language: Markdown

The kit is written entirely in Markdown (specifications) and Shell (hooks). There is no application source code -- it is a configuration framework.

- Markdown files: 112 (specifications, protocols, skills, rules)
- Shell scripts: 16 (lifecycle hooks, automation)
- JSON files: 4 (settings, schemas)
- Total lines of content: ~25,000

### Primary Scripting: Shell (Bash)

- Standard: `set -euo pipefail` in all scripts
- Python3 used for JSON processing within shell scripts
- No external shell dependencies beyond coreutils + git

### Frameworks

| Framework | Category | Purpose | Detection |
|-----------|----------|---------|-----------|
| Claude Code | AI development tool | Runtime platform for the kit | manifest (settings.json) |
| MCP (Model Context Protocol) | Integration | Memory, sequential-thinking, context7, tree-sitter, postgres | manifest (settings.json) |

### MCP Server Integrations

| Server | Required | Purpose |
|--------|----------|---------|
| memory (@modelcontextprotocol/server-memory) | Required | Persistent agent memory across sessions |
| context7 (@upstash/context7-mcp) | Required | Library documentation lookup |
| sequential-thinking | Required | Structured reasoning for complex tasks |
| tree_sitter | Optional | Code analysis (symbols, dependencies, repo-map) |
| postgres (@anthropic/mcp-postgres) | Optional | Required only for /db-explorer |

---

## Core Domain

### Entities

| Entity | Location | Type | Purpose |
|--------|----------|------|---------|
| Artifact | agents/meta-agent/ | aggregate_root | Commands, skills, rules, agents -- managed by /meta-agent |
| WorkflowPipeline | commands/workflow.md | aggregate_root | 5-phase development pipeline with state transitions |
| Checkpoint | skills/workflow-protocols/checkpoint-protocol.md | entity | Session recovery state (12 YAML fields) |
| Plan | prompts/*.md (runtime) | entity | Implementation plan generated by /planner |
| HandoffPayload | skills/workflow-protocols/handoff-protocol.md | value_object | Typed contract between pipeline phases (4 contracts) |

### Value Objects

| Value Object | Purpose | Values |
|--------------|---------|--------|
| Complexity | Task sizing for route selection | S, M, L, XL |
| Verdict | Review phase outcome | APPROVED, NEEDS_CHANGES, CHANGES_REQUIRED, REJECTED, SKIP |
| Severity | Error classification | FATAL, STOP_AND_WAIT, STOP_AND_FIX, STOP, NON_CRITICAL |

### Key Interfaces (Protocol Contracts)

| Protocol | Location | Methods/Phases | Purpose |
|----------|----------|----------------|---------|
| Handoff Protocol | skills/workflow-protocols/handoff-protocol.md | 4 contracts | Phase-to-phase data transfer |
| Checkpoint Protocol | skills/workflow-protocols/checkpoint-protocol.md | save/restore | Session recovery |
| Re-routing Protocol | skills/workflow-protocols/re-routing.md | downgrade/upgrade | Complexity mismatch handling |
| Pipeline Metrics | skills/workflow-protocols/pipeline-metrics.md | record/analyze | Completion tracking |

---

## Conventions Catalog

### Naming Conventions

```
# File naming: kebab-case
commands/workflow.md, skills/workflow-protocols/, agents/plan-reviewer.md

# Skill packages: kebab-case directories with SKILL.md entry point
skills/coder-rules/SKILL.md, skills/workflow-protocols/SKILL.md

# Agent naming: kebab-case with .md or directory
agents/code-reviewer.md (simple), agents/meta-agent/ (complex with deps/)
```

### Content Format

```
# YAML-first format (>80% YAML, minimal prose)
# Frontmatter required on all artifacts:
---
name: artifact-name
description: "What this artifact does"
model: sonnet | opus | haiku    # (commands/agents only)
---
```

### Scripting Conventions

```bash
# All scripts use strict mode
set -euo pipefail

# JSON processing via python3 (not jq)
python3 -c "import json; ..."

# Exit codes: 0 (success/allow), 2 (block/deny with STDERR message)
```

### Error Handling Conventions

| Error | Severity | Action |
|-------|----------|--------|
| MCP server unavailable | NON_CRITICAL | Warn, proceed without |
| Plan not found | FATAL | EXIT |
| Tests fail 3x | STOP_AND_WAIT | Show errors, request manual fix |
| Import violation | STOP_AND_FIX | Fix before proceeding |
| Loop limit exceeded (3x) | STOP | Show iteration summary, request user help |

### Review Conventions

```
# Verdicts: 5 types
APPROVED        — pass, proceed to next phase
NEEDS_CHANGES   — return to author with feedback (plan-review)
CHANGES_REQUIRED— return to author with feedback (code-review)
REJECTED        — fundamental issues, restart phase
SKIP            — phase not applicable (e.g., S-complexity skips plan-review)

# Loop limit: 3 iterations max per review cycle
# On loop limit exceeded: STOP, show summary, request user help
```

---

## Entry Points Map

### Slash Commands (User-Facing)

| Command | Location | Model | Purpose |
|---------|----------|-------|---------|
| /workflow | commands/workflow.md | opus | Full 5-phase development cycle |
| /planner | commands/planner.md | opus | Codebase research + plan creation |
| /coder | commands/coder.md | sonnet | Implementation per approved plan |
| /meta-agent | commands/meta-agent.md | sonnet | Artifact lifecycle management |
| /project-researcher | commands/project-researcher.md | - | Codebase analysis (delegates to agent) |
| /db-explorer | commands/db-explorer.md | - | PostgreSQL exploration via MCP |
| /review-checklist | commands/review-checklist.md | - | Review checklist reference display |

### Agents (Programmatic)

| Agent | Location | Model | Invoked By |
|-------|----------|-------|------------|
| plan-reviewer | agents/plan-reviewer.md | sonnet | /workflow (Phase 2) |
| code-reviewer | agents/code-reviewer.md | sonnet | /workflow (Phase 4) |
| code-researcher | agents/code-researcher.md | haiku | /planner (exploration) |
| meta-agent | agents/meta-agent/ | sonnet | /meta-agent command |
| project-researcher | agents/project-researcher/ | multi-model | /project-researcher command |
| db-explorer | agents/db-explorer/ | - | /db-explorer command |

---

## External Integrations

### MCP Servers

| Server | Driver | Purpose | Auth Method |
|--------|--------|---------|-------------|
| memory | @modelcontextprotocol/server-memory | Persistent memory across sessions | Local (no auth) |
| sequential-thinking | built-in | Structured reasoning | Local |
| context7 | @upstash/context7-mcp | Library documentation lookup | API key |
| tree_sitter | MCP server | Code analysis (symbols, deps) | Local |
| postgres | @anthropic/mcp-postgres | Database exploration | Connection string |

### System Tools

| Tool | Purpose | Required |
|------|---------|----------|
| git | Version control, commit history analysis | Yes |
| python3 | JSON processing in hook scripts | Yes |
| bash | Hook script execution | Yes |
| osascript / notify-send | Desktop notifications | No (optional) |
| gofmt | Go code formatting (target project) | No (optional) |

---

## Pattern Catalog

### Design Patterns Used

| Pattern | Location | Purpose |
|---------|----------|---------|
| Orchestrator | commands/workflow.md | Central coordinator for 5-phase pipeline |
| Strategy | skills/workflow-protocols/re-routing.md | Route selection based on complexity |
| Hook Chain | settings.json (hooks section) | 8 lifecycle hook types with script chains |
| Template Method | templates/*.md | Artifact scaffolding with fill-in sections |
| Checkpoint Recovery | skills/workflow-protocols/checkpoint-protocol.md | Session state persistence and resume |
| Context Isolation | agents/ (review agents) | Clean context for unbiased review |
| Event-Driven Loading | skills/workflow-protocols/SKILL.md | On-demand protocol loading per event triggers |

### Hook System Architecture

| Hook Type | Trigger | Scripts |
|-----------|---------|---------|
| UserPromptSubmit | Every user prompt | enrich-context.sh |
| PreToolUse | Before Write/Edit/Bash | protect-files.sh, check-artifact-size.sh, block-dangerous-commands.sh |
| PostToolUse | After Write/Edit | auto-fmt-go.sh, yaml-lint.sh, check-references.sh |
| PreCompact | Before context compaction | save-progress-before-compact.sh |
| SubagentStop | After plan-reviewer/code-reviewer | save-review-checkpoint.sh |
| Stop | Session end | verify-phase-completion.sh, check-uncommitted.sh |
| SessionEnd | Session termination | session-analytics.sh |
| Notification | Agent events | notify-user.sh |

---

## Technical Debt

| Area | Issue | Severity | Recommendation |
|------|-------|----------|----------------|
| Language Profile | CLAUDE.md defaults to Go, but kit is language-agnostic | LOW | Documented as template default; users override via PROJECT-KNOWLEDGE.md |
| tdd-go skill | Go-specific TDD skill included in generic kit | LOW | Consider making language-specific skills optional or template-based |
| No automated tests | Shell scripts lack unit tests | MEDIUM | Consider adding bats or shunit2 tests for critical hook scripts |

---

## Important Distinction: Kit vs Target Project

This PROJECT-KNOWLEDGE.md describes **the kit itself** (Markdown/Shell configuration framework), not a target project where the kit is deployed.

When the kit is copied into a target Go project:
- The Language Profile in CLAUDE.md applies to that target project
- The rules in `.claude/rules/` (architecture.md, go-conventions.md, etc.) activate for Go source files
- This PROJECT-KNOWLEDGE.md should be regenerated via `/project-researcher` to reflect the target project

**Kit identity:** Markdown specifications + Shell hooks (configuration framework)
**Target project defaults:** Go >= 1.24 (template Language Profile, meant to be overridden)

---

## Change History

### 8c77a7c - 2026-03-09

**Initial analysis (AUGMENT mode):**
- Generated PROJECT-KNOWLEDGE.md from existing .claude/ artifacts
- All existing artifacts preserved (7 commands, 6 agents, 6 skill packages, 8 rules, 15 scripts, 6 templates)
- Identified multi-agent orchestrator architecture pattern
- Documented kit vs target project distinction per critique feedback

---

## Metadata

- **Analysis Mode:** AUGMENT
- **Analysis Method:** grep-based
- **AST Available:** no (not applicable -- no source code)
- **Confidence Score:** HIGH (0.85 calibrated)
- **Low Confidence Areas:** none (kit structure is self-documenting via YAML frontmatter)
- **Recommended Reviews:** Language Profile section in CLAUDE.md (verify Go defaults match target project)
- **Monorepo:** no
- **Modules Analyzed:** 1
