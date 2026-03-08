# Task: Migration workflow/ → .claude/

## Context
A new workflow with architectural changes has been prepared:
- `commands/deps/` → `skills/` (new skill system with SKILL.md)
- `commands/code-review.md` + `commands/plan-review.md` → `agents/` (native agents with frontmatter)
- New hook scripts + settings.json hooks
- New `rules/architecture.md` (glob-based)
- New `.claude/CLAUDE.md` (project-level Go profile)

## Scope

### IN
- [x] Migration of commands (workflow, planner, coder)
- [x] Migration of code-review/plan-review → agents
- [x] Migration of deps/ → skills/
- [x] Adding new agents (code-researcher, code-reviewer, plan-reviewer)
- [x] Adding rules/architecture.md
- [x] Adding scripts (3 hook scripts)
- [x] Merging settings.json (hooks)
- [x] Adding .claude/CLAUDE.md
- [x] Updating review-checklist.md (references)
- [x] Updating root CLAUDE.md
- [x] Deleting commands/deps/ (entirely)
- [x] Deleting commands/code-review.md and commands/plan-review.md

### OUT
- Agents meta-agent, project-researcher, db-explorer — no changes
- Commands meta-agent.md, db-explorer.md, project-researcher.md — no changes
- templates/ — no changes
- PROJECT-KNOWLEDGE.md — no changes

---

## Part 1: Adding skills/ (new directory)
**Source:** `workflow/.claude/skills/`
**Target:** `.claude/skills/`

Copy 5 directories entirely (32 files):

### 1.1 skills/code-review-rules/ (5 files)
**Files:** `SKILL.md`, `checklist.md`, `examples.md`, `security-checklist.md`, `troubleshooting.md`
- SKILL.md — NEW (severity classification + decision matrix, replaces deps/shared-review.md)
- Remaining 4 files — updated versions from deps/code-review/

### 1.2 skills/coder-rules/ (5 files)
**Files:** `SKILL.md`, `checklist.md`, `examples.md`, `mcp-tools.md`, `troubleshooting.md`
- SKILL.md — NEW (5 CRITICAL rules + evaluate protocol)
- mcp-tools.md — from deps/core/mcp-tools.md (adapted for coder)
- Remaining 3 — updated versions from deps/coder/

### 1.3 skills/plan-review-rules/ (5 files)
**Files:** `SKILL.md`, `architecture-checks.md`, `checklist.md`, `required-sections.md`, `troubleshooting.md`
- SKILL.md — NEW (severity classification + decision matrix)
- Remaining 4 — updated versions from deps/plan-review/

### 1.4 skills/planner-rules/ (8 files)
**Files:** `SKILL.md`, `checklist.md`, `data-flow.md`, `examples.md`, `mcp-tools.md`, `sequential-thinking-guide.md`, `task-analysis.md`, `troubleshooting.md`
- SKILL.md — NEW (task classification overview + routing matrix)
- mcp-tools.md — from deps/core/mcp-tools.md (adapted for planner)
- sequential-thinking-guide.md — from deps/sequential-thinking-guide.md
- Remaining 5 — updated versions from deps/planner/

### 1.5 skills/workflow-protocols/ (9 files)
**Files:** `SKILL.md`, `autonomy.md`, `beads.md`, `checkpoint-protocol.md`, `examples-troubleshooting.md`, `handoff-protocol.md`, `orchestration-core.md`, `pipeline-metrics.md`, `re-routing.md`
- SKILL.md — NEW (protocol overview + event triggers)
- autonomy.md — from deps/core/autonomy.md
- beads.md — from deps/core/beads.md
- Remaining 6 — updated versions from deps/workflow/

---

## Part 2: Adding agents/ (3 new agents)
**Source:** `workflow/.claude/agents/`
**Target:** `.claude/agents/`

### 2.1 agents/code-researcher.md (CREATE)
- model: haiku, tools: Read/Grep/Glob/Bash, maxTurns: 20
- Read-only explorer for codebase research

### 2.2 agents/code-reviewer.md (CREATE)
- model: sonnet, tools: Read/Grep/Glob/Bash/TodoWrite, skills: code-review-rules
- Replaces commands/code-review.md
- Native agent with context isolation via frontmatter

### 2.3 agents/plan-reviewer.md (CREATE)
- model: sonnet, tools: Read/Grep/Glob/TodoWrite, skills: plan-review-rules
- Replaces commands/plan-review.md
- Native agent with context isolation via frontmatter

---

## Part 3: Replacing commands (3 files)
**Source:** `workflow/*.md`
**Target:** `.claude/commands/`

### 3.1 commands/workflow.md (REPLACE)
- New version references skills/ instead of deps/
- Added DELEGATION PROTOCOL (plan for how agents delegate review)
- Added HOOKS section
- Removed direct references to deps/core/

### 3.2 commands/planner.md (REPLACE)
- References: `.claude/skills/planner-rules/` instead of deps/
- Startup loads SKILL.md + mcp-tools.md

### 3.3 commands/coder.md (REPLACE)
- References: `.claude/skills/coder-rules/` instead of deps/
- Startup loads SKILL.md + mcp-tools.md

---

## Part 4: Adding rules/, scripts/, CLAUDE.md
**Source:** `workflow/.claude/`

### 4.1 rules/architecture.md (CREATE)
- Go-specific architecture rules with glob: `internal/**/*.go`
- Import matrix, domain purity

### 4.2 scripts/ (3 files CREATE)
- `check-uncommitted.sh` — Stop hook, blocks if uncommitted changes
- `save-progress-before-compact.sh` — PreCompact hook, saves workflow state
- `save-review-checkpoint.sh` — SubagentStop hook, records review completion
- Existing `sync-to-github.sh` — no changes

### 4.3 .claude/CLAUDE.md (CREATE)
- Go Backend Workflow project profile
- Language profile, architecture import matrix, error handling table
- Hooks documentation

---

## Part 5: Merging settings.json
**File:** `.claude/settings.json`

Add 3 new hook sections to existing ones:

```json
"PreCompact": [
  {
    "matcher": "",
    "hooks": [{
      "type": "command",
      "command": ".claude/scripts/save-progress-before-compact.sh"
    }]
  }
],
"SubagentStop": [
  {
    "matcher": "plan-reviewer|code-reviewer",
    "hooks": [{
      "type": "command",
      "command": ".claude/scripts/save-review-checkpoint.sh"
    }]
  }
]
```

Update existing `Stop` hook — add check-uncommitted.sh:

```json
"Stop": [
  {
    "command": ".claude/agents/meta-agent/scripts/verify-phase-completion.sh",
    "description": "PHASE_CHECK: Ensure all meta-agent phases completed"
  },
  {
    "command": ".claude/scripts/check-uncommitted.sh",
    "description": "UNCOMMITTED_CHECK: Block stop if uncommitted changes"
  }
]
```

Preserve all existing hooks (PreToolUse, PostToolUse, PostFileEdit, PostFileWrite).

---

## Part 6: Deleting old files

### 6.1 Delete commands/deps/ (entire directory — 25 files)
Replaced by skills/:
- `deps/core/autonomy.md` → `skills/workflow-protocols/autonomy.md`
- `deps/core/beads.md` → `skills/workflow-protocols/beads.md`
- `deps/core/context-isolation.md` → REMOVED (agents handle isolation natively)
- `deps/core/error-handling.md` → REMOVED (moved to .claude/CLAUDE.md)
- `deps/core/mcp-tools.md` → SPLIT: `skills/planner-rules/mcp-tools.md` + `skills/coder-rules/mcp-tools.md`
- `deps/core/project-knowledge.md` → REMOVED (inline references)
- `deps/code-review/*` → `skills/code-review-rules/*`
- `deps/coder/*` → `skills/coder-rules/*`
- `deps/plan-review/*` → `skills/plan-review-rules/*`
- `deps/planner/*` → `skills/planner-rules/*`
- `deps/workflow/*` → `skills/workflow-protocols/*`
- `deps/shared-core.md` → REMOVED (already deprecated)
- `deps/shared-review.md` → REMOVED (replaced by SKILL.md in review skills)
- `deps/sequential-thinking-guide.md` → `skills/planner-rules/sequential-thinking-guide.md`

### 6.2 Delete commands/code-review.md
Replaced by `agents/code-reviewer.md`

### 6.3 Delete commands/plan-review.md
Replaced by `agents/plan-reviewer.md`

---

## Part 7: Updating existing files

### 7.1 commands/review-checklist.md (UPDATE)
Line 78: `# SEE: deps/shared-review.md#review-verdict` → delete or update to:
`# SEE: skills/code-review-rules/SKILL.md (severity levels, decision matrix)`

### 7.2 Root CLAUDE.md (UPDATE)
Update the commands section — reflect that plan-review and code-review are now agents:

```
commands:
  - /workflow: Full dev cycle (task-analysis → planner → plan-review (agent) → coder → code-review (agent))
  - /planner: Research codebase → detailed implementation plan
  - /coder: Implement code strictly per approved plan

agents:
  - plan-reviewer: Validates implementation plan (replaces /plan-review command)
  - code-reviewer: Code review of changes (replaces /code-review command)
  - code-researcher: Codebase exploration for planning/implementation
  - meta-agent: Manage Claude Code artifacts
  - project-researcher: Deep project analysis
  - db-explorer: Explore PostgreSQL schema
```

---

## Part 8: Cleanup workflow/ (after migration is complete)
Delete the `workflow/` directory entirely — all files have been moved to `.claude/`.

---

## Acceptance Criteria
- [ ] All 32 skills/ files are in place
- [ ] All 3 agents (code-researcher, code-reviewer, plan-reviewer) added
- [ ] Commands (workflow, planner, coder) updated
- [ ] rules/architecture.md created
- [ ] 3 hook scripts added and chmod +x
- [ ] settings.json contains all hooks (old + new)
- [ ] .claude/CLAUDE.md created
- [ ] commands/deps/ deleted entirely
- [ ] commands/code-review.md deleted
- [ ] commands/plan-review.md deleted
- [ ] review-checklist.md updated
- [ ] Root CLAUDE.md updated
- [ ] workflow/ deleted
- [ ] No broken references to deps/ in remaining files
