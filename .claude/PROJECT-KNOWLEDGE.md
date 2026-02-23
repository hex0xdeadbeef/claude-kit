# PROJECT-KNOWLEDGE.md

**Last Updated:** 2026-02-23T00:00:00Z
**Version:** git:sync/initial (11 commits)
**Researcher:** project-researcher agent v4.2.0
**Analysis Mode:** AUGMENT
**Analysis Method:** grep-based (tree-sitter not applicable to Markdown/YAML kit)

---

## Executive Summary

`claude-go-kit` is a reusable Claude Code configuration kit for Go projects. It is **not a Go application** — it is a collection of Claude Code agents, slash commands, hook scripts, dependency modules, and templates that are copied into a target project's `.claude/` directory to bootstrap AI-assisted development workflows.

The kit provides a complete, opinionated development pipeline: project analysis → planning → plan-review → coding → code-review, plus meta-level tooling for managing the AI artifacts themselves. It targets Go projects as the primary use case (reflected in hook scripts and template conventions) but the orchestration infrastructure is language-agnostic.

**Primary language:** Markdown/YAML (0.88 confidence). 82 `.md` files, 6 `.sh` scripts, 4 `.json` config files — 93 total files.

---

## Project Structure

```
claude-go-kit/
├── CLAUDE.md                          # Project-level instructions (root entry point for Claude)
├── .gitignore
├── .claude/
│   ├── settings.json                  # Claude Code config: model, MCP servers, hooks, permissions
│   ├── archive/                       # Rollback storage (.gitkeep placeholder)
│   ├── prompts/                       # Generated plan files (runtime output, .gitkeep)
│   ├── agents/
│   │   ├── meta-agent/
│   │   │   ├── README.md              # Agent definition (v9.0.0, opus model)
│   │   │   ├── deps/                  # 20+ dependency modules (lazy-loaded per phase)
│   │   │   │   ├── artifact-quality.md     # HUB: fan-in=11 (most referenced file)
│   │   │   │   ├── eval-optimizer.md       # HUB: fan-in=11 (eval-reflect loop)
│   │   │   │   ├── blocking-gates.md       # 8 phase gates with recovery strategies
│   │   │   │   ├── phase-contracts.md      # Typed inter-phase communication (8 contracts)
│   │   │   │   ├── phases-enhance.md       # ENHANCE mode phase details
│   │   │   │   ├── phases-create.md        # CREATE mode phase details
│   │   │   │   ├── phases-onboard.md       # ONBOARD mode phase details
│   │   │   │   ├── artifact-constitution.md # 5-principle constitutional evaluation
│   │   │   │   ├── artifact-archive.md     # ADAS pattern library (self-improving)
│   │   │   │   ├── subagents.md            # DAG subagent registry
│   │   │   │   ├── agent-teams.md          # Peer-to-peer team patterns (v10.0)
│   │   │   │   ├── context-management.md   # 4-tier lazy loading with budget
│   │   │   │   ├── load-order.md           # Explicit load/unload strategy
│   │   │   │   ├── self-improvement.md     # Reflexion episodic memory
│   │   │   │   ├── troubleshooting.md      # 7 key items + common mistakes
│   │   │   │   └── ...                     # (observability, progress-tracking, etc.)
│   │   │   └── scripts/               # Deterministic hook scripts (4 files)
│   │   │       ├── check-artifact-size.sh  # PreToolUse: SIZE_GATE (blocks large writes)
│   │   │       ├── yaml-lint.sh            # PostToolUse: YAML validation on Edit
│   │   │       ├── check-references.sh     # PostToolUse: reference link validation
│   │   │       └── verify-phase-completion.sh  # Stop: phase completion check
│   │   ├── project-researcher/
│   │   │   ├── AGENT.md               # Orchestrator definition (v4.2.0, opus model)
│   │   │   ├── README.md              # User-facing README
│   │   │   ├── deps/                  # Research-specific dep modules
│   │   │   ├── subagents/             # 7 subagent instruction files
│   │   │   │   ├── discovery.md       # VALIDATE+DISCOVER (haiku)
│   │   │   │   ├── detection.md       # DETECT language/frameworks (sonnet)
│   │   │   │   ├── graph.md           # Symbol table + PageRank repo-map (sonnet)
│   │   │   │   ├── analysis.md        # Architecture+Map+DB analysis (opus)
│   │   │   │   ├── generation.md      # Artifact generation (sonnet)
│   │   │   │   ├── verification.md    # Artifact validation (sonnet)
│   │   │   │   └── report.md          # Final summary (haiku)
│   │   │   ├── phases/
│   │   │   │   └── critique.md        # Inline CRITIQUE blocking gate (opus)
│   │   │   └── templates/
│   │   │       └── project-knowledge.md  # Template for this file
│   │   └── db-explorer/
│   │       └── AGENT.md               # DB schema explorer (v1.1.0, sonnet model)
│   ├── commands/                      # 9 slash command definitions
│   │   ├── meta-agent.md              # /meta-agent (v9.0.0, opus)
│   │   ├── workflow.md                # /workflow (v2.1.0, opus)
│   │   ├── planner.md                 # /planner (opus)
│   │   ├── plan-review.md             # /plan-review (sonnet)
│   │   ├── coder.md                   # /coder (opus)
│   │   ├── code-review.md             # /code-review (sonnet)
│   │   ├── project-researcher.md      # /project-researcher (opus)
│   │   ├── db-explorer.md             # /db-explorer (sonnet)
│   │   ├── review-checklist.md        # /review-checklist (sonnet)
│   │   └── deps/                      # Shared command dependency modules (6 files)
│   │       ├── workflow-phases.md     # Full phase details, loop limits, context isolation
│   │       ├── shared-autonomy.md     # Autonomy modes (INTERACTIVE/AUTONOMOUS/RESUME)
│   │       ├── shared-mcp.md          # MCP tool availability patterns
│   │       ├── shared-error-handling.md # Error severity classification
│   │       ├── shared-beads.md        # Task tracker integration
│   │       └── session-recovery.md    # Checkpoint-based recovery algorithm
│   ├── templates/                     # 5 scaffold templates
│   │   ├── agent.md                   # Agent definition scaffold
│   │   ├── command.md                 # Command definition scaffold
│   │   ├── skill.md                   # Skill card scaffold
│   │   ├── rule.md                    # Rule file scaffold
│   │   └── plan-template.md           # Implementation plan scaffold
│   └── scripts/
│       └── sync-to-github.sh          # Distribution sync script
```

---

## Architecture Deep-Dive

### Pattern: Layered + Hub-and-Spoke (Artifact Hub)

**Confidence:** 0.91

The kit follows a **layered architecture with hub-and-spoke dependency topology**:

```
┌─────────────────────────────────────────────────┐
│  Layer 1: Entry Points                          │
│  commands/*.md (9 files) — slash command        │
│  definitions invoked directly by users          │
├─────────────────────────────────────────────────┤
│  Layer 2: Core Agents                           │
│  agents/*/README.md or AGENT.md — orchestrators │
│  that own phase execution and subagent dispatch  │
├─────────────────────────────────────────────────┤
│  Layer 3: Subagents                             │
│  agents/project-researcher/subagents/*.md —     │
│  isolated execution contexts (Task tool calls)  │
├─────────────────────────────────────────────────┤
│  Layer 4: Dep Modules                           │
│  agents/*/deps/*.md — lazy-loaded per phase,    │
│  commands/deps/*.md — shared cross-command logic │
├─────────────────────────────────────────────────┤
│  Layer 5: Infrastructure                        │
│  scripts/*.sh (hooks), settings.json,           │
│  templates/*.md (scaffolds)                     │
└─────────────────────────────────────────────────┘
```

**Dependency flow (top-down, no circular deps detected):**

```
commands/*.md
    └─→ agents/*/README.md | AGENT.md
            └─→ agents/*/subagents/*.md  (Task tool, isolated context)
            └─→ agents/*/deps/*.md       (lazy loaded per phase)
                    └─→ agents/meta-agent/deps/artifact-quality.md  [HUB, fan-in=11]
                    └─→ agents/meta-agent/deps/eval-optimizer.md    [HUB, fan-in=11]
commands/deps/*.md  (shared, referenced inline via HTML comments)
```

### Layer Descriptions

| Layer | Path | File Count | Total Lines | Description |
|-------|------|-----------|-------------|-------------|
| core_agents | `.claude/agents/` | 3 | 1121 | Orchestrator definitions; own phase execution |
| interface_commands | `.claude/commands/` | 9 | 3563 | User-facing slash commands; delegate to agents or dep modules |
| support_deps | `agents/*/deps/` + `commands/deps/` | 47 | 13685 | Lazy-loaded reference modules; bulk of the kit's content |
| subagents | `agents/project-researcher/subagents/` | 7 | 4351 | Isolated task-execution agents; called via Task tool |
| infrastructure_scripts | `agents/meta-agent/scripts/` | 4 | 349 | Deterministic hook scripts run by Claude Code hooks |
| template_scaffolds | `.claude/templates/` | 5 | 501 | Artifact scaffolds for create/onboard operations |

### Architectural Evidence

| Indicator | Confidence | Method |
|-----------|-----------|--------|
| Layered file hierarchy (commands → agents → deps) | 0.95 | directory structure |
| Hub files with fan-in=11 (artifact-quality, eval-optimizer) | 0.93 | dependency graph |
| PageRank top-5 concentrated in meta-agent deps | 0.88 | graph analysis |
| Subagent isolation via Task tool (own context) | 0.85 | subagent instructions |
| Hook observer pattern in settings.json | 0.97 | direct config read |

---

## Dependency Topology

### Graph Summary

| Metric | Value |
|--------|-------|
| Total symbols | 94 (across 87 files) |
| Total nodes | 87 |
| Total edges | 142 |
| Circular dependencies | 0 (none detected) |
| Hub files | 4 with fan-in >= 8 |

### Hub Files (highest fan-in)

| File | Fan-In | Fan-Out | Role |
|------|--------|---------|------|
| `agents/meta-agent/deps/artifact-quality.md` | 11 | — | Core quality standards and evaluation criteria |
| `commands/meta-agent.md` | 11 | — | Primary user interface to meta-agent |
| `agents/meta-agent/deps/eval-optimizer.md` | 11 | — | Eval-reflect loop logic (Reflexion pattern) |
| `agents/meta-agent/README.md` | 8 | 25 | Agent orchestrator definition |
| `agents/meta-agent/deps/blocking-gates.md` | ~7 | — | Gate definitions referenced throughout phases |

### PageRank Top-5

1. `agents/meta-agent/deps/artifact-quality.md` (1.00)
2. `commands/meta-agent.md` (0.98)
3. `agents/meta-agent/deps/eval-optimizer.md` (0.95)
4. `agents/meta-agent/README.md` (0.88)
5. `agents/meta-agent/deps/blocking-gates.md` (0.84)

### Circular Dependencies

None detected.

---

## Technology Stack

### Primary Language

- **Markdown/YAML** — 88% confidence
- File counts: `.md` = 82, `.sh` = 6, `.json` = 4
- Total files: 93

### Frameworks / Platforms

| Framework | Version | Confidence | Detection Method |
|-----------|---------|-----------|-----------------|
| Claude Code (Anthropic) | — | 1.00 | settings.json, command format |
| @modelcontextprotocol/server-memory | — | 1.00 | settings.json enabledMcpjsonServers |
| @modelcontextprotocol/server-sequential-thinking | — | 1.00 | settings.json enabledMcpjsonServers |
| mcp-server-tree-sitter | — | 1.00 | settings.json enabledMcpjsonServers |
| @upstash/context7-mcp | — | 1.00 | settings.json enabledMcpjsonServers |
| jq (CLI) | — | 0.95 | referenced in hook scripts |
| ast-grep (CLI) | — | 0.90 | fallback in project-researcher |

### MCP Server Configuration (settings.json)

```json
"enabledMcpjsonServers": ["memory", "sequential-thinking", "context7", "tree_sitter"]
```

- **memory**: Persistent agent knowledge (lessons learned, reflections, metrics)
- **sequential-thinking**: Multi-step structured reasoning for complex phases
- **context7**: Library documentation lookup (resolve-library-id, query-docs)
- **tree_sitter**: Code structural analysis (symbols, deps, repo-map) — optional

### Required MCP (configure in ~/.claude/mcp.json)

- `@modelcontextprotocol/server-memory` — episodic memory, self-improvement
- `@upstash/context7-mcp` — documentation lookup
- `@modelcontextprotocol/server-sequential-thinking` — reasoning

### Optional MCP

- `@anthropic/mcp-postgres` — for db-explorer agent

---

## Core Domain

### Artifact Types (Domain Entities)

| Artifact Type | Count | Template | Primary Location |
|--------------|-------|---------|-----------------|
| command | 9 | `templates/command.md` | `.claude/commands/` |
| agent | 3 | `templates/agent.md` | `.claude/agents/*/` |
| skill | 0 | `templates/skill.md` | `.claude/skills/*/` (would be created) |
| rule | 0 | `templates/rule.md` | `.claude/rules/*/` (would be created) |
| dep_module | 47 | — | `agents/*/deps/`, `commands/deps/` |
| subagent | 7 | — | `agents/project-researcher/subagents/` |
| hook_script | 4 | — | `agents/meta-agent/scripts/` |
| template | 5 | — | `.claude/templates/` |

### Core Agents

**meta-agent** (`agents/meta-agent/README.md`, v9.0.0, model: opus)
- Manages Claude Code artifact lifecycle: create, enhance, audit, delete, rollback
- 9-phase workflow: INIT → EXPLORE → ANALYZE → PLAN(ToT) → CONSTITUTE → DRAFT(+eval+reflect) → APPLY → VERIFY → CLOSE(+archive)
- Key patterns: Constitutional AI (CONSTITUTE phase), Reflexion (DRAFT eval-reflect loop), Tree of Thought (PLAN phase), ADAS archive (CLOSE phase)

**project-researcher** (`agents/project-researcher/AGENT.md`, v4.2.0, model: opus)
- Orchestrates deep project analysis → generates PROJECT-KNOWLEDGE.md and .claude/ artifacts
- 10-phase pipeline via 7 specialized subagents + 1 inline CRITIQUE gate
- Modes: CREATE (no .claude/), AUGMENT (.claude/ exists, no PROJECT-KNOWLEDGE.md), UPDATE (PROJECT-KNOWLEDGE.md exists)
- Monorepo support: pipeline parallelism (≤3 modules) or batch 3-wave (4+ modules)

**db-explorer** (`agents/db-explorer/AGENT.md`, v1.1.0, model: sonnet)
- Explores PostgreSQL schema via MCP (read-only)
- Requires mcp-postgres configured

### Key Workflows

**Development Cycle** (via `/workflow`):
```
task-analysis → /planner → /plan-review → /coder → /code-review → git commit
```

**Artifact Lifecycle** (via `/meta-agent`):
```
INIT → EXPLORE → ANALYZE → PLAN(ToT) → CONSTITUTE → DRAFT(+eval+reflect) → APPLY → VERIFY → CLOSE(+archive)
```

**Project Research** (via `/project-researcher`):
```
DISCOVERY → DETECTION → GRAPH → ANALYSIS → CRITIQUE → GENERATION → VERIFICATION → REPORT
```

---

## Entry Points Map

### Slash Commands

| Command | File | Model | Version | Primary Purpose |
|---------|------|-------|---------|----------------|
| `/meta-agent` | `commands/meta-agent.md` | opus | 9.0.0 | Artifact lifecycle management |
| `/workflow` | `commands/workflow.md` | opus | 2.1.0 | Full dev cycle orchestrator |
| `/planner` | `commands/planner.md` | opus | — | Research codebase → implementation plan |
| `/plan-review` | `commands/plan-review.md` | sonnet | — | Validate plan before coding |
| `/coder` | `commands/coder.md` | opus | — | Implement per approved plan |
| `/code-review` | `commands/code-review.md` | sonnet | — | Code review before merge |
| `/project-researcher` | `commands/project-researcher.md` | opus | — | Deep project analysis |
| `/db-explorer` | `commands/db-explorer.md` | sonnet | — | Database schema exploration |
| `/review-checklist` | `commands/review-checklist.md` | sonnet | — | Code review checklist reference |

### Hook Entry Points (Deterministic)

| Hook | Trigger | Script | Gate | Action |
|------|---------|--------|------|--------|
| SIZE_GATE | PreToolUse (Write) | `check-artifact-size.sh` | SIZE_GATE | block |
| YAML_LINT | PostToolUse (Edit) | `yaml-lint.sh` | EXTERNAL_VALIDATION_GATE | warn |
| REF_CHECK | PostToolUse (Write) | `check-references.sh` | EXTERNAL_VALIDATION_GATE | warn |
| PHASE_CHECK | Stop | `verify-phase-completion.sh` | STEP_QUALITY_GATE | warn |
| Go format | PostFileEdit/Write (`**/*.go`) | `gofmt -w ${FILE}` | — | auto-format |

---

## Conventions Catalog

### Naming Conventions

| Area | Convention | Examples |
|------|-----------|---------|
| File names | kebab-case | `artifact-quality.md`, `check-artifact-size.sh` |
| YAML keys | snake_case | `phase_contracts`, `blocking_gates`, `eval_optimizer` |
| Section dividers | UPPER_CASE with ════ | `# ════ WORKFLOW ════` |
| Artifact types | lowercase singular | `command`, `skill`, `rule`, `agent` |
| Phase names | UPPER_CASE | `INIT`, `EXPLORE`, `ANALYZE`, `DRAFT` |
| Gate names | UPPER_CASE + `_GATE` | `SIZE_GATE`, `QUALITY_GATE`, `CRITIQUE_GATE` |

### Format Convention: YAML-First

All artifacts follow the YAML-first principle (>80% YAML, minimal prose):

```yaml
---
name: "artifact-name"
description: "What it does"
model: opus
version: 1.0.0
---

workflow:
  phases: ["INIT", "EXPLORE", "DRAFT"]
  key: "Execute ALL phases. NEVER skip."

rules:
  - rule: "Sequential execution"
    description: "..."
```

Avoid:
- Prose paragraphs where YAML lists suffice
- Markdown tables where YAML maps suffice
- Hardcoded code examples (use grep/glob patterns instead)

### Error Handling Conventions

**Phase Gate Escalation Pattern:**

```yaml
gates:
  - gate: "GATE_NAME"
    trigger: "condition"
    action: "auto-recovery → fallback → user escalation"
    blocking: true
    recovery: "SEE: deps/blocking-gates.md#recovery_strategies"

# Error severity levels:
# FATAL: Stop immediately (path not found, empty project, gate failed after retry)
# STOP_AND_WAIT: Stop, request manual intervention (tests fail 3x)
# NON_CRITICAL: Warn and continue with degraded quality (MCP unavailable)
```

### Bilingual Authoring Convention

The kit uses **English for all code, YAML keys, and artifact specs** (primary). Russian appears in ~30% of files as description prose (primarily workflow orchestration files and command files) — this is an authoring artifact of the original author, not a project convention for end users. The `CLAUDE.md` and all templates are English-only.

- `ai_first_principles.language.artifacts`: English
- `ai_first_principles.language.user_facing`: Match project language for README/docs

### Testing Conventions

No test files in this project (it is a configuration kit, not a Go application). Quality is enforced via:
- 4 hook scripts (deterministic validation)
- Per-phase step quality checks (process reward model)
- Constitutional AI evaluation (P1-P5, threshold 0.85)
- Eval-optimizer loop (max 3 iterations per artifact)

---

## Pattern Catalog

### Design Patterns Detected

| Pattern | Location | Confidence | Purpose |
|---------|----------|-----------|---------|
| Orchestrator + Subagent | `agents/project-researcher/AGENT.md`, `agents/meta-agent/README.md` | 0.85 | Parallel execution with isolated contexts |
| Phase Gate Pipeline | `agents/meta-agent/deps/blocking-gates.md`, `agents/project-researcher/AGENT.md` | 0.85 | Quality gates between phases |
| Template Method | `templates/*.md` (5 files) | 0.95 | Scaffold for artifact creation |
| Hub and Spoke | `agents/meta-agent/deps/artifact-quality.md` (fan-in=11) | 0.93 | Central quality reference |
| Lazy Loading / Progressive Offloading | `agents/meta-agent/deps/context-management.md`, `deps/load-order.md` | 0.92/0.94 | 4-tier context budget management |
| Hook Observer | `settings.json` hooks config | 0.97 | Deterministic validation gates |
| State Machine | `agents/project-researcher/AGENT.md` (modes), `commands/workflow.md` (phases) | 0.93 | Phase transitions with gated advancement |
| Reflexion | `agents/meta-agent/deps/self-improvement.md`, `deps/eval-optimizer.md` | 0.90 | Episodic memory + eval-reflect loop |
| Constitutional AI | `agents/meta-agent/deps/artifact-constitution.md` | 0.88 | 5-principle quality evaluation (Bai et al., 2022) |
| Tree of Thought | `agents/meta-agent/deps/plan-exploration.md` | 0.85 | Design space exploration in PLAN phase (Yao et al., 2023) |
| ADAS Archive | `agents/meta-agent/deps/artifact-archive.md` | 0.85 | Self-improving pattern library (Hu et al., 2024) |
| Phase Contracts (MetaGPT) | `agents/meta-agent/deps/phase-contracts.md` | 0.88 | Typed inter-phase communication (Hong et al., 2023) |
| Agent Teams (peer-to-peer) | `agents/meta-agent/deps/agent-teams.md` | 0.85 | v10.0 CREATE mode: researcher+scanner+designer teammates |
| MAR (Multi-Agent Reflexion) | `agents/meta-agent/deps/eval-optimizer.md` | 0.82 | 3 critic subagents: correctness, clarity, efficiency |
| Model Routing | `agents/meta-agent/README.md#model_routing` | 0.90 | haiku (search/validate), sonnet (generate), opus (judge) |

### Model Routing Strategy

```
haiku  → codebase_analyzer, artifact_scanner, context_loader, dependency_analyzer
sonnet → content generation, APPLY changes, dynamic subagents, clarity_critic
opus   → correctness_critic, reflector_agent, judgment phases (PLAN, CONSTITUTE)
```

---

## External Integrations

### MCP Servers (Tool Integrations)

| MCP Server | Required | Tools Used | Purpose |
|------------|---------|-----------|---------|
| memory | Recommended | create_entities, search_nodes, add_observations, create_relations | Lessons learned, pipeline metrics, episodic memory |
| sequential-thinking | Recommended | sequentialthinking | Multi-step reasoning for XL-complexity tasks |
| context7 | Recommended | resolve-library-id, query-docs | Library documentation lookup |
| tree_sitter | Optional | symbols, dependencies, queries | Code structural analysis for project-researcher |
| postgres | Optional | list_tables, describe_table, query | DB schema exploration for db-explorer |

### Git Integration

- Remote: `https://github.com/hex0xdeadbeef/claude-kit.git`
- Distribution: `.claude/scripts/sync-to-github.sh`
- 11 commits on `sync/initial` branch

### Beads (Task Tracker)

Optional integration via `bd` CLI. Referenced in workflow.md and meta-agent.md:
- `bd create`, `bd close`, `bd sync` — task lifecycle
- `bd list --status=open|in_progress` — status checks
- Availability: NON_CRITICAL — workflow continues without it

---

## Distribution Mechanism

The kit is designed to be **copied** into target projects, not imported or depended upon:

```bash
cp -r .claude/ /path/to/your/project/
cp CLAUDE.md /path/to/your/project/
```

Then bootstrapped with:
```bash
/meta-agent onboard          # Customize kit for target project
/project-researcher          # Analyze codebase → PROJECT-KNOWLEDGE.md
```

This is the primary design characteristic that differentiates it from a library: all files are intended to be customized in-place within the target project's `.claude/` directory.

---

## Technical Debt / Known Issues

| Area | Issue | Severity | Notes |
|------|-------|---------|-------|
| Skills | 0 skill files exist | LOW | Templates exist; meta-agent creates them on demand |
| Rules | 0 rule files exist | LOW | Templates exist; meta-agent creates them on demand |
| Bilingual prose | ~30% files have Russian descriptions | LOW | Authoring artifact, does not affect functionality |
| .gitignore for meta-agent runs | .meta-agent/runs/ excluded | LOW | Correct behavior — run state is local/ephemeral |
| Archive | `.claude/archive/` is placeholder | INFO | Populated by /meta-agent delete/rollback operations |

---

## Change History

### sync/initial — 2026-02-23

Initial public version of claude-go-kit. Full .claude/ directory with:
- meta-agent v9.0.0 (Constitutional AI, Reflexion, ADAS archive, Phase Contracts, Agent Teams)
- project-researcher v4.2.0 (Tree-Sitter MCP, GRAPH subagent, PageRank repo-map)
- db-explorer v1.1.0
- 9 slash commands (workflow, planner, plan-review, coder, code-review, meta-agent, project-researcher, db-explorer, review-checklist)
- 4 deterministic hook scripts
- 5 artifact templates

---

## Metadata

- **Analysis Mode:** AUGMENT
- **Analysis Method:** grep-based / directory-structure-based
- **AST Available:** no (Markdown/YAML kit, not a compilable project)
- **Tree-Sitter MCP:** available but not applicable (no source code to parse)
- **Overall Confidence:** HIGH (direct file reads, no inference required)
- **Low Confidence Areas:** internal dep module cross-references (not fully traversed), exact bilingual file count (estimated ~30%)
- **Recommended Reviews:** verify agent versions match actual file contents if kit is updated
- **Monorepo:** no (single module, strategy: "single")
- **Modules Analyzed:** 1 (root configuration kit)
- **Source Files:** 93 total (82 .md, 6 .sh, 4 .json, 1 .gitignore)
- **Lines of Markdown:** ~23,560 (estimated from layer totals)
- **Test Files:** 0
- **Git Remote:** https://github.com/hex0xdeadbeef/claude-kit.git
- **Generated:** 2026-02-23T00:00:00Z
