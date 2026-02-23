# Project Knowledge: claude-go-kit

**Last Updated:** 2026-02-23
**Version:** v1.0.0 (commit: 3f8bee9)
**Researcher:** project-researcher agent v3.0
**Analysis Method:** grep-based (ast-grep not available)

---

## Executive Summary

`claude-go-kit` is a reusable Claude Code configuration kit designed for Go projects.
It is a **meta-project** — its entire "source code" IS the `.claude/` directory tree.
There are no traditional programming language files (.go/.py/.ts); the kit is composed
of Markdown/YAML artifact files, shell validation scripts, and JSON configuration.

The kit provides a complete AI-assisted development workflow: agents for project analysis
and artifact management, slash commands for the full dev cycle (task → plan → review →
implement → code-review), templates for creating new artifacts, and hook-based quality
gates enforced at write time.

**Confidence:** HIGH (0.95) — entire project analyzed from filesystem

---

## Project Structure

### Module Map

**Type:** single module (pure configuration kit)
**Strategy:** single

```
claude-go-kit/
├── CLAUDE.md                          # Project instructions (always loaded)
└── .claude/
    ├── settings.json                  # Claude Code settings + hooks
    ├── agents/
    │   ├── meta-agent/                # Artifact lifecycle manager (v9.0)
    │   │   ├── README.md
    │   │   ├── deps/                  # 24 supporting files (lazy loaded)
    │   │   ├── scripts/               # Hook validation scripts (4 files)
    │   │   └── templates/             # Onboarding templates
    │   ├── project-researcher/        # Codebase analysis agent (v3.0)
    │   │   ├── AGENT.md
    │   │   ├── phases/                # 9 phase files (progressive loading)
    │   │   ├── deps/                  # Supporting analysis files
    │   │   ├── reference/             # Language patterns + scoring
    │   │   ├── templates/             # project-knowledge.md template
    │   │   └── examples/
    │   └── db-explorer/               # PostgreSQL schema explorer
    │       └── deps/queries.md
    ├── commands/
    │   ├── workflow.md                # Full dev pipeline orchestrator
    │   ├── planner.md                 # Phase 1: Research + create plan
    │   ├── plan-review.md             # Phase 2: Validate plan
    │   ├── coder.md                   # Phase 3: Implement per plan
    │   ├── code-review.md             # Phase 4: Review code
    │   ├── meta-agent.md              # Artifact lifecycle management
    │   ├── project-researcher.md      # Project analysis
    │   ├── db-explorer.md             # Database exploration
    │   ├── review-checklist.md        # Code review checklist reference
    │   └── deps/                      # Shared supporting docs
    │       ├── shared-autonomy.md     # Autonomy patterns (reused by all)
    │       ├── shared-mcp.md          # MCP tool patterns (reused by all)
    │       ├── shared-error-handling.md
    │       ├── shared-beads.md        # Beads issue tracking patterns
    │       ├── workflow-phases.md     # Pipeline phase details
    │       ├── session-recovery.md
    │       ├── planner/               # Planner-specific deps
    │       ├── plan-review/           # Plan-review-specific deps
    │       ├── coder/                 # Coder-specific deps
    │       └── code-review/           # Code-review-specific deps
    ├── templates/
    │   ├── agent.md                   # Template for new agents
    │   ├── command.md                 # Template for new commands
    │   ├── skill.md                   # Template for new skills
    │   ├── rule.md                    # Template for new rules
    │   └── plan-template.md           # Template for implementation plans
    └── scripts/
        └── sync-to-github.sh          # Sync kit to GitHub
```

---

## Architecture Deep-Dive

### Pattern: Pipeline-Orchestration with Progressive Context Loading

The kit implements a **phase-based pipeline architecture** with:

1. **Progressive Context Loading** — agents load only the current phase file, discard it
   after completion, retaining only typed state. Reduces active context by ~60%.

2. **Hook-Based Quality Gates** — deterministic validation runs before/after writes:
   - `PreToolUse[Write]` → `check-artifact-size.sh` (SIZE_GATE)
   - `PostToolUse[Edit]` → `yaml-lint.sh` (YAML_LINT)
   - `PostToolUse[Write]` → `check-references.sh` (REF_CHECK)
   - `Stop` → `verify-phase-completion.sh` (PHASE_CHECK)

3. **Handoff Protocol** — each pipeline phase produces a typed handoff payload for the
   next phase, preventing context loss between steps.

4. **Shared Abstractions** — `deps/shared-*.md` files provide reusable patterns
   (autonomy, error handling, MCP usage, beads integration) included by multiple commands.

### Dependency Flow

```
User invokes slash command
         │
         ▼
   /workflow (orchestrator)
         │
   ┌─────┴──────┬──────────┬──────────┐
   ▼            ▼          ▼          ▼
/planner  /plan-review  /coder  /code-review
   │            │          │          │
   └─────┬──────┴──────────┴──────────┘
         │
         ▼
  deps/shared-*.md  (autonomy, mcp, errors, beads)
         │
         ▼
  MCP Servers: memory | sequential-thinking | context7
```

```
Agents (Task tool invocation):
meta-agent → deps/*.md (24 files, lazy)
project-researcher → phases/N-*.md (9 files, progressive)
db-explorer → deps/queries.md
```

### Artifact Size Limits (enforced by hooks)

| Artifact Type | Recommended | Warning | Critical (BLOCKED) |
|---------------|------------|---------|-------------------|
| command       | 300 lines  | 500     | 800               |
| skill         | 300 lines  | 600     | 700               |
| rule          | 100 lines  | 200     | 400               |
| agent         | 500 lines  | 800     | 1200              |
| agent/deps    | 500 lines  | 800     | 1200              |

---

## Technology Stack

### Primary Format: Markdown/YAML

- **Markup:** GitHub-flavored Markdown with YAML frontmatter
- **Config:** YAML (>80% of artifact content)
- **Scripts:** Bash/Shell (hook validators, 4 files)
- **Data:** JSON (settings.json, MCP config)
- **Convention:** YAML-first (minimal prose, no tables in artifacts)

### MCP Servers (External Integrations)

| Server | Package | Purpose | Priority |
|--------|---------|---------|---------|
| memory | @modelcontextprotocol/server-memory | Persistent agent memory across sessions | Required |
| sequential-thinking | built-in | Structured multi-step reasoning | Required |
| context7 | @upstash/context7-mcp | Library documentation lookup | Required |
| postgres | @anthropic/mcp-postgres | DB schema exploration (db-explorer) | Optional |

**Config location:** `~/.claude/mcp.json` (user-level, not in repo)

### Shell Scripts (Hook Validators)

| Script | Trigger | Purpose |
|--------|---------|---------|
| `check-artifact-size.sh` | PreToolUse[Write] | Block writes exceeding size thresholds |
| `yaml-lint.sh` | PostToolUse[Edit] | Validate YAML structure after edits |
| `check-references.sh` | PostToolUse[Write] | Validate all file references |
| `verify-phase-completion.sh` | Stop | Ensure meta-agent phases completed |

---

## Core Artifact Catalog

### Agents

| Agent | Version | Model | Purpose | Key Features |
|-------|---------|-------|---------|-------------|
| meta-agent | v9.0 | opus | Artifact lifecycle: create/enhance/audit/delete | Constitutional AI eval, ADAS archive, Tree of Thought, agent teams |
| project-researcher | v3.0 | opus | Codebase → PROJECT-KNOWLEDGE.md | AST analysis, 9-phase pipeline, monorepo detection, dep graph |
| db-explorer | - | - | PostgreSQL schema via MCP | Read-only schema + data exploration |

### Commands (Slash Commands)

| Command | Role | Output |
|---------|------|--------|
| `/workflow` | Pipeline orchestrator | Full dev cycle with phase checkpoints |
| `/planner` | Architect-Researcher | `.claude/prompts/{feature}.md` |
| `/plan-review` | Plan Validator | APPROVED/NEEDS_CHANGES/REJECTED verdict |
| `/coder` | Implementer | Working code + passing tests |
| `/code-review` | Reviewer | APPROVED/CHANGES_REQUESTED verdict |
| `/meta-agent` | Artifact Manager | Created/enhanced/audited artifacts |
| `/project-researcher` | Analyst | PROJECT-KNOWLEDGE.md |
| `/db-explorer` | DB Analyst | Schema report |
| `/review-checklist` | Reference | Code review checklist |

### Templates (Scaffolding)

| Template | Creates | Key Sections |
|----------|---------|-------------|
| `agent.md` | New agent | meta, autonomy, workflow, phases, output, fatal_errors |
| `command.md` | New command | description, role, input, pipeline, rules, checklist |
| `skill.md` | New skill | name, description, triggers, rules, examples |
| `rule.md` | New rule | paths, purpose, quick-check |
| `plan-template.md` | Implementation plan | Scope, Architecture Decision, Parts, Tests, Risks |

---

## Key Conventions

### Format: YAML-First

All artifacts must be YAML-first (>80% YAML structure, <10% prose):

```yaml
# CORRECT — YAML structure
role:
  identity: "Orchestrator"
  owns: "Pipeline coordination"
  output_contract: "Implemented code + commit"

# INCORRECT — prose
# This command orchestrates the full development pipeline.
# It coordinates multiple sub-commands...
```

### Progressive Offloading Pattern

Large agents split content into `deps/` files loaded on demand:
- Main file: core workflow, rules, entry points (~500 lines max)
- `deps/` files: detailed specs loaded only when needed (1200 lines max)

### Handoff Protocol

Every pipeline phase produces a typed handoff payload:
```yaml
# planner → plan-review
handoff:
  artifact: ".claude/prompts/{feature}.md"
  complexity: "S|M|L|XL"
  key_decisions: [...]
  known_risks: [...]

# plan-review → coder
handoff:
  verdict: "APPROVED|NEEDS_CHANGES|REJECTED"
  issues_summary: {blocker: 0, major: 0, minor: 0}
  iteration: "N/3"
```

### Naming Conventions

| Artifact | Location | Naming |
|----------|----------|--------|
| Agents | `.claude/agents/{name}/AGENT.md` | kebab-case |
| Commands | `.claude/commands/{name}.md` | kebab-case |
| Skills | `.claude/skills/{name}/SKILL.md` | kebab-case |
| Rules | `.claude/rules/{name}.md` | kebab-case |
| Deps | `{artifact}/deps/{topic}.md` | kebab-case, topic-based |

### Complexity Routing (workflow)

| Complexity | Route | Plan Review |
|-----------|-------|------------|
| S (small) | minimal | skip |
| M (medium) | standard | full |
| L (large) | full | full + Sequential Thinking recommended |
| XL (xlarge) | full | full + Sequential Thinking REQUIRED |

---

## Workflow Pipeline

### Full Pipeline

```
Task Analysis → /planner → /plan-review → /coder → /code-review → commit
     │                ↗ NEEDS_CHANGES ↩                  ↗ CHANGES_REQUESTED ↩
     └── Complexity → route (S/M/L/XL)
```

### Loop Limits
- Max 3 iterations per review cycle (plan-review OR code-review)
- On limit exceeded: STOP, show summary, request user guidance

### Session Recovery
- Checkpoint file: `.claude/workflow-state/{feature}-checkpoint.yaml`
- Resume: `/workflow --from-phase N`
- Auto-detect: check `.claude/prompts/{feature}.md` existence

### Phase Checkpoints

```yaml
# .claude/workflow-state/{feature}-checkpoint.yaml
feature: "{feature-name}"
phase_completed: 2
phase_name: plan-review
iteration: {plan_review: "1/3", code_review: "0/3"}
verdict: APPROVED
complexity: L
route: standard
handoff_payload: {...}
```

---

## Installing Kit in a New Project

```bash
# Copy kit to target project
cp -r .claude/ /path/to/your/project/
cp CLAUDE.md /path/to/your/project/

# Bootstrap for the specific project
/meta-agent onboard          # Customize .claude/ for project
/project-researcher          # Analyze codebase → PROJECT-KNOWLEDGE.md
```

## Creating New Artifacts

```bash
/meta-agent create command <name>    # New slash command from template
/meta-agent create skill <name>      # New reusable skill
/meta-agent create agent <name>      # New agent
/meta-agent enhance command <name>   # Improve existing artifact
/meta-agent audit                    # Quality report for all artifacts
```

---

## Meta-Agent v9.0 Key Features

- **CONSTITUTE**: Constitutional AI evaluation (P1-P5 principles)
- **Tree of Thought**: Design space exploration in PLAN phase
- **ADAS Archive**: Self-improving pattern library from successful operations
- **Phase Contracts**: Typed inter-phase communication
- **Model Routing**: haiku/sonnet/opus per task complexity
- **Observability**: Tracing, metrics, MCP memory logging per run
- **Step Quality**: Per-phase quality checks (Process Reward Model)
- **Self-Improvement**: Lessons + reflections via episodic memory
- **Context Management**: 4-tier lazy loading with budget tracking
- **DRY-RUN Mode**: Preview changes without applying

---

## Project-Researcher v3.0 Key Features

- **10-Phase Workflow**: VALIDATE → DISCOVER → DETECT → ANALYZE → MAP → DATABASE → CRITIQUE → GENERATE → VERIFY → REPORT
- **AST Analysis**: ast-grep patterns for structural code analysis (grep fallback)
- **Monorepo Detection**: DISCOVER phase — detects modules, picks strategy
- **Dependency Graph**: MAP phase — fan-in/fan-out, hub packages, circular deps
- **State Contract**: Typed inter-phase state schema with validation
- **Progressive Loading**: Phase files loaded on-demand, only state persists
- **Confidence Scoring**: Evidence-based confidence per finding

---

## Technical Debt

| Area | Issue | Severity | Recommendation |
|------|-------|----------|----------------|
| meta-agent README | Missing AGENT.md (only README.md in agents/meta-agent/) | LOW | Add AGENT.md or verify README.md serves as agent spec |
| db-explorer | Only deps/queries.md — no AGENT.md or README.md | MEDIUM | Create proper agent spec file |
| settings.json | `PostFileEdit/PostFileWrite` hooks for `gofmt *.go` — no Go files in kit | LOW | Remove unused Go formatting hooks if kit stays Markdown-only |

---

## Metadata

- **Analysis Mode:** AUGMENT (`.claude/` existed, PROJECT-KNOWLEDGE.md missing)
- **Analysis Method:** grep-based (ast-grep unavailable)
- **AST Available:** no
- **Confidence Score:** HIGH (0.95)
- **Low Confidence Areas:** db-explorer agent (minimal files to analyze)
- **Recommended Reviews:** Verify db-explorer AGENT.md exists; check if beads (`bd`) CLI is in use
- **Monorepo:** no
- **Modules Analyzed:** 1 (single project)
- **Git Commits:** 1 (Initial commit: claude-go-kit v1.0)
