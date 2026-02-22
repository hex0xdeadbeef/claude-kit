# Project Knowledge: claude-go-kit

**Last Updated:** 2026-02-23
**Version:** 1.0.0
**Researcher:** project-researcher agent v2.2.0
**Analysis Mode:** AUGMENT
**Confidence Score:** HIGH

---

## Executive Summary

`claude-go-kit` is a reusable Claude Code configuration kit targeting Go projects.
It is a **meta-project**: its "source code" is YAML/Markdown artifacts that instruct
Claude how to work on downstream Go projects. The kit ships 3 major agents,
9 slash commands, and 5 artifact templates organized around YAML-first conventions.

The kit is designed to be copied into a target Go project (`cp -r .claude/ /path/to/project/`)
and then bootstrapped via `/meta-agent onboard`. The primary value is the **meta-agent**
(v9.0) which manages the entire lifecycle of Claude Code artifacts using a 9-phase
pipeline with constitutional AI evaluation, separated evaluator subagents, and ADAS
archive for self-improvement.

---

## Architecture

### Pattern: Modular 3-Pillar Configuration Kit

```
.claude/
├── agents/          # Autonomous agents (spawned via Task tool)
│   ├── meta-agent/  # Artifact lifecycle manager (v9.0, 560 lines core)
│   ├── project-researcher/  # Project analysis → PROJECT-KNOWLEDGE.md
│   └── db-explorer/ # PostgreSQL schema exploration via MCP
├── commands/        # Slash commands (user-invocable: /command-name)
│   ├── meta-agent.md
│   ├── workflow.md
│   ├── planner.md
│   ├── plan-review.md
│   ├── coder.md
│   ├── code-review.md
│   ├── db-explorer.md
│   ├── review-checklist.md
│   └── project-researcher.md
└── templates/       # Artifact templates for new content creation
    ├── agent.md
    ├── command.md
    ├── skill.md
    ├── rule.md
    └── plan-template.md
```

### Dependency Flow

```
User → /command-name → Claude loads commands/<name>.md
                     → Claude may spawn agents/<name>/AGENT.md via Task tool
                     → Agent loads phases/*.md lazily (4-tier loading)
                     → Agent writes artifacts back to .claude/
```

### Architectural Decisions

| Decision | Rationale | Confidence |
|----------|-----------|------------|
| YAML-first format (>80%) | LLMs parse structured data faster than prose | HIGH |
| Progressive offloading to deps/ | Keeps core files ≤560 lines, loads on demand | HIGH |
| Agents in agents/, commands in commands/ | agents/ = Task-spawnable; commands/ = user-invocable | HIGH |
| 4-tier lazy loading | Context budget control (max 1500 lines total) | HIGH |
| Constitutional AI in CONSTITUTE phase | Systematic quality via 5 principles (P1-P5) | HIGH |
| Separated evaluator subagent | Eliminates sunk-cost bias in quality evaluation | HIGH |

---

## Technology Stack

### Primary: YAML + Markdown
- File count: 77 .md files
- Format: YAML frontmatter + YAML body (>80%), fenced code for examples

### Secondary: Bash Shell
- File count: 6 .sh scripts
- Purpose: Deterministic validation hooks (PreToolUse / PostToolUse / Stop)

### Configuration: JSON
- File count: 3 .json files
- Files: settings.json, mcp.json (template), onboarding/mcp.json

### Runtime: Claude Code (Anthropic)
- Model: Claude Opus 4.6 / Sonnet 4.6 / Haiku 4.5 (per-task routing)
- Interface: Claude Code CLI

---

## Core Components Map

### Agents

| Agent | Version | Location | Purpose | Entry |
|-------|---------|----------|---------|-------|
| meta-agent | v9.0 | agents/meta-agent/ | Artifact lifecycle (create/enhance/audit/delete/rollback/onboard) | commands/meta-agent.md |
| project-researcher | v2.2.0 | agents/project-researcher/ | Deep project analysis → PROJECT-KNOWLEDGE.md | commands/project-researcher.md |
| db-explorer | — | agents/db-explorer/ | PostgreSQL schema via MCP | commands/db-explorer.md |

### Commands (Slash Commands)

| Command | File | Purpose | Mode |
|---------|------|---------|------|
| /meta-agent | commands/meta-agent.md | Artifact lifecycle management | create / enhance / audit / delete / rollback / onboard |
| /workflow | commands/workflow.md | Full dev cycle | task-analysis → planner → plan-review → coder → code-review |
| /planner | commands/planner.md | Codebase research → implementation plan | — |
| /plan-review | commands/plan-review.md | Validate plan before coding | — |
| /coder | commands/coder.md | Implement code per approved plan | — |
| /code-review | commands/code-review.md | Code review before merge | — |
| /db-explorer | commands/db-explorer.md | Database schema exploration | — |
| /review-checklist | commands/review-checklist.md | Code review checklist reference | — |
| /project-researcher | commands/project-researcher.md | Project analysis agent | [path] [--dry-run] |

### Templates

| Template | File | Use |
|----------|------|-----|
| agent.md | templates/agent.md | New agents via /meta-agent create agent |
| command.md | templates/command.md | New commands via /meta-agent create command |
| skill.md | templates/skill.md | New skills via /meta-agent create skill |
| rule.md | templates/rule.md | New rules via /meta-agent create rule |
| plan-template.md | templates/plan-template.md | Implementation plans via /planner |

---

## meta-agent Deep-Dive (Core Component)

### Workflow (9 phases, MANDATORY)

```
INIT → EXPLORE/RESEARCH → ANALYZE → PLAN(ToT) → CONSTITUTE → DRAFT(+eval+reflect) → APPLY → VERIFY → CLOSE(+archive)
```

### Modes

| Mode | Command | Description |
|------|---------|-------------|
| onboard | /meta-agent onboard [path] | Bootstrap .claude/ for new project |
| create | /meta-agent create <type> <name> | New artifact |
| enhance | /meta-agent enhance <type> <name> | Improve existing artifact |
| audit | /meta-agent audit | Quality report (no modifications) |
| delete | /meta-agent delete <type> <name> | Delete with backup |
| rollback | /meta-agent rollback | Restore from .claude/archive/ |
| list | /meta-agent list | All runs in workspace |
| resume | /meta-agent --resume {run_id} | Resume from checkpoint |

### Key v9.0 Patterns

| Pattern | Source | Purpose |
|---------|--------|---------|
| Constitutional AI | Bai et al. 2022 | 5-principle quality evaluation (P1-P5, threshold 0.85) |
| Reflexion | Shinn et al. 2023 | External reflector → episodic memory → few-shot hints |
| Tree of Thought | Yao et al. NeurIPS 2023 | Design space exploration in PLAN phase |
| ADAS Archive | Hu et al. 2024 | Self-improving pattern library in .meta-agent/archive/ |
| Phase Contracts | MetaGPT 2023 | Typed inter-phase communication |
| MAR Critics | — | 3 separated critics: correctness/clarity/efficiency |

### Artifact Types & Size Limits

| Type | Warning | Critical | Location |
|------|---------|----------|----------|
| command | 400 lines | 500 lines | .claude/commands/ |
| skill | 500 lines | 600 lines | .claude/skills/*/SKILL.md |
| rule | 150 lines | 200 lines | .claude/rules/ |
| agent | 500 lines | 600 lines | .claude/agents/*/AGENT.md |
| CLAUDE.md | 150 lines | 200 lines | .claude/CLAUDE.md (or root) |

### Dependencies (deps/ structure)

```
agents/meta-agent/deps/
├── phases-enhance.md       # ENHANCE mode phase details
├── phases-create.md        # CREATE mode phase details
├── phases-onboard.md       # ONBOARD mode phase details
├── blocking-gates.md       # 8 blocking gates (RESEARCH, EXPLORE, CONSTITUTE, etc.)
├── artifact-constitution.md # 5 constitutional principles P1-P5
├── artifact-archive.md     # ADAS pattern library
├── phase-contracts.md      # Typed inter-phase contracts (8 contracts)
├── plan-exploration.md     # Tree of Thought (3 branches, depth 2)
├── eval-optimizer.md       # MAR critics + Reflexion loop
├── subagents.md            # DAG execution, model routing
├── context-management.md   # Budget tracking, 4-tier loading
├── load-order.md           # When to load/unload per tier
├── self-improvement.md     # Reflexion + episodic memory
├── artifact-archive.md     # ADAS self-improving library
├── observability.md        # Execution tracking
├── progress-tracking.md    # Session persistence (progress.json)
├── activation-layer.md     # False positive prevention
├── agent-teams.md          # Peer-to-peer agent collaboration
├── artifact-quality.md     # Quality criteria + external validation
├── troubleshooting.md      # Common issues + recovery
├── changelog.md            # Version history
└── ...
```

---

## project-researcher Deep-Dive

### Workflow (9 phases)

```
VALIDATE → DETECT → ANALYZE → MAP → [DATABASE] → CRITIQUE → GENERATE → VERIFY → REPORT
```

### Operation Modes

| Mode | Condition | Behavior |
|------|-----------|---------|
| CREATE | No .claude/ | Creates full configuration from scratch |
| AUGMENT | .claude/ exists, no PROJECT-KNOWLEDGE.md | Fills gaps, preserves existing |
| UPDATE | PROJECT-KNOWLEDGE.md + git repo | Incremental update via git diff |

### Output Artifacts

| Artifact | Location | Mode |
|----------|----------|------|
| CLAUDE.md | project root or .claude/ | CREATE only |
| PROJECT-KNOWLEDGE.md | .claude/ | CREATE / AUGMENT |
| Skills | .claude/skills/*/SKILL.md | CREATE / AUGMENT |
| Rules | .claude/rules/*.md | CREATE / AUGMENT |
| MCP memory | mcp__memory | All modes |

### Language Support

| Language | Detectors | Architecture Patterns |
|----------|-----------|----------------------|
| Go | go.mod, *.go | Clean Architecture, Hexagonal, Layered |
| Python | pyproject.toml, requirements.txt | MVC, Service layer |
| TypeScript | tsconfig.json, package.json | NestJS, Express |
| Rust | Cargo.toml | Module-based |
| Java | pom.xml, build.gradle | Spring, Layered |

---

## External Integrations (MCP)

| Server | Package | Purpose | Required |
|--------|---------|---------|---------|
| memory | @modelcontextprotocol/server-memory | Persistent agent memory (lessons, reflections, project context) | YES |
| context7 | @upstash/context7-mcp | Library documentation lookup | YES |
| sequential-thinking | — | Structured reasoning for planning | YES |
| postgres | @anthropic/mcp-postgres | DB schema exploration (db-explorer agent) | Optional |

### MCP Configuration

Template location: `agents/meta-agent/templates/onboarding/mcp.json`
Production location: `~/.claude/mcp.json`

---

## Hooks (Deterministic Validation)

| Hook | Trigger | Script | Gate | Action |
|------|---------|--------|------|--------|
| check-artifact-size.sh | PreToolUse (Write) | agents/meta-agent/scripts/ | SIZE_GATE | block |
| yaml-lint.sh | PostToolUse (Edit) | agents/meta-agent/scripts/ | EXTERNAL_VALIDATION (partial) | warn |
| check-references.sh | PostToolUse (Write) | agents/meta-agent/scripts/ | EXTERNAL_VALIDATION (partial) | warn |
| verify-phase-completion.sh | Stop | agents/meta-agent/scripts/ | STEP_QUALITY_GATE | warn |

---

## Conventions Catalog

### File Naming

```
# Artifact files
commands/<name>.md          # kebab-case
agents/<name>/AGENT.md      # SCREAMING for agent spec
agents/<name>/deps/*.md     # kebab-case
agents/<name>/phases/*.md   # N-name.md (numbered)
skills/<name>/SKILL.md      # SCREAMING for skill spec
rules/<name>.md             # kebab-case

# Scripts
scripts/*.sh                # kebab-case
```

### YAML Conventions

```yaml
# Frontmatter (required for commands)
---
description: "Single line description"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Frontmatter (required for agents)
---
name: agent-name
model: opus | sonnet | haiku
description: |
  Multi-line description
tools: [Read, Write, ...]
---
```

### Content Format Rules

```
# DO: YAML lists for steps
steps:
  - "Step 1"
  - "Step 2"

# DO: YAML for examples
examples:
  - bad: "hardcoded snippet"
    good: "grep/glob pattern to find current code"
    why: "code changes, patterns stay valid"

# DON'T: Prose paragraphs
# DON'T: Markdown tables for simple data (use YAML)
# DON'T: Hardcode code snippets (use grep patterns)
```

### Reference Pattern

```
# Internal references (lazy loading)
details: "SEE: deps/filename.md"
phases: "SEE: phases/N-name.md"

# Skill references (cross-artifact)
@skill-name

# MCP tool naming
mcp__memory__add_observations
mcp__postgres__list_tables
```

---

## Model Routing

| Model | Used For |
|-------|---------|
| haiku | codebase_analyzer, artifact_scanner, context_loader, dependency_analyzer, quality_checker |
| sonnet | Content generation, APPLY changes, dynamic subagents, clarity_critic |
| opus | correctness_critic, reflector_agent, PLAN phase (Tree of Thought) |

---

## Known Patterns & Anti-Patterns

### DO

```yaml
# Lazy loading with explicit unload signal
tier_3_phase_file:
  load: "when entering phase"
  unload: "when phase completes"
  max_lines: 400

# Grep patterns instead of hardcoded examples
examples:
  pattern: "Grep '.claude/commands/' for current command structure"
```

### DON'T

```yaml
# Don't exceed size limits (hooks will block)
# Don't reference non-existent deps/ files (check-references.sh warns)
# Don't use prose where YAML works
# Don't hardcode code snippets (use grep/glob patterns)
# Don't skip phases (verify-phase-completion.sh warns)
```

---

## Installation & Bootstrap

```bash
# Copy kit to new project
cp -r .claude/ /path/to/your-go-project/
cp CLAUDE.md /path/to/your-go-project/

# Bootstrap
cd /path/to/your-go-project
/meta-agent onboard

# Analyze codebase
/project-researcher

# Create project-specific artifacts
/meta-agent create skill <name>
/meta-agent audit
```

---

## Technical Debt

| Area | Issue | Severity | Recommendation |
|------|-------|----------|----------------|
| project-researcher | No commands/project-researcher.md (fixed 2026-02-23) | LOW | RESOLVED |
| sync-to-github.sh | Global .gitignore excludes .claude/ (fixed 2026-02-23) | LOW | RESOLVED — use git add -f |
| Root CLAUDE.md | Not present before onboard (fixed 2026-02-23) | LOW | RESOLVED |

---

## Metadata

- **Analysis Mode:** AUGMENT
- **Confidence Score:** HIGH
- **Low Confidence Areas:** none (direct file analysis)
- **Recommended Reviews:** hooks scripts (verify they work correctly in target projects)
