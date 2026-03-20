# Workflow Artifacts Research Report

**Date:** 2026-03-20
**Task:** Exploration Loops Analysis (25 friction events)
**Complexity:** XL
**Scope:** All workflow-related artifacts — commands, agents, skills, scripts, hooks, rules, templates

---

## 1. Artifact Inventory

### 1.1 Complete File Manifest

| Category | Files | Lines | Key Entry Point |
|----------|-------|-------|-----------------|
| Commands | 3 core | 1,068 | `.claude/commands/workflow.md` |
| Agents (standalone) | 3 | 564 | `.claude/agents/plan-reviewer.md` |
| Skills | 5 packages, 27 files | 2,541 | `.claude/skills/workflow-protocols/SKILL.md` |
| Scripts | 10 | ~1,100 | `.claude/scripts/enrich-context.sh` |
| Rules | 8 | ~337 | `.claude/rules/workflow.md` |
| Templates | 6 | ~1,243 | `.claude/templates/plan-template.md` |
| Settings | 1 | 212 | `.claude/settings.json` |
| **Total** | **~58 files** | **~7,065** | |

### 1.2 Detailed Inventory

**Commands (`.claude/commands/`):**
- `workflow.md` (340 lines) — Orchestrator, opus model
- `planner.md` (324 lines) — Architect-Researcher, opus model
- `coder.md` (404 lines) — Senior Developer, sonnet model

**Agents (`.claude/agents/`):**
- `plan-reviewer.md` (192 lines) — Architecture Reviewer, sonnet, maxTurns=40
- `code-reviewer.md` (238 lines) — Senior Reviewer, sonnet, maxTurns=45, worktree isolation
- `code-researcher.md` (134 lines) — Codebase Explorer, haiku, maxTurns=20

**Skills:**
- `workflow-protocols/` (9 files, 724 lines) — orchestration-core, autonomy, beads, checkpoint, handoff, re-routing, metrics, examples
- `planner-rules/` (8 files, 752 lines) — task-analysis, data-flow, sequential-thinking, mcp-tools, checklist, examples
- `coder-rules/` (5 files, 261 lines) — 5 CRITICAL rules, evaluate protocol, mcp-tools, checklist
- `plan-review-rules/` (5 files, 457 lines) — severity classification, architecture checks, required sections
- `code-review-rules/` (5 files, 347 lines) — severity classification, security checklist, examples

**Scripts (`.claude/scripts/`):**
- `protect-files.sh` (117 lines) — PreToolUse: block protected files
- `block-dangerous-commands.sh` (138 lines) — PreToolUse: prevent destructive commands
- `check-artifact-size.sh` — PreToolUse: enforce size limits
- `auto-fmt-go.sh` (108 lines) — PostToolUse: auto-format Go files
- `yaml-lint.sh` — PostToolUse: validate YAML
- `check-references.sh` — PostToolUse: verify file references
- `check-plan-drift.sh` — PostToolUse: detect plan/implementation misalignment
- `enrich-context.sh` (112 lines) — UserPromptSubmit: inject workflow state
- `save-progress-before-compact.sh` (44 lines) — PreCompact: preserve state
- `save-review-checkpoint.sh` (58 lines) — SubagentStop: record verdicts
- `check-uncommitted.sh` (40 lines) — Stop: block if uncommitted
- `session-analytics.sh` (148 lines) — SessionEnd: log metrics
- `notify-user.sh` (101 lines) — Notification: desktop alerts

**Rules (`.claude/rules/`):**
- `architecture.md` — import matrix, domain purity (scope: `internal/**/*.go`)
- `go-conventions.md` — error wrapping, concurrency (scope: `**/*.go`)
- `handler-rules.md` — validation, HTTP codes (scope: `internal/handler/**`)
- `service-rules.md` — business logic, interfaces (scope: `internal/service/**`)
- `repository-rules.md` — parameterized SQL (scope: `internal/repository/**`)
- `models-rules.md` — stdlib-only, no tags (scope: `internal/models/**`)
- `testing.md` — table-driven tests, race detector (scope: `**/*_test.go`)
- `workflow.md` — commands, agents, model routing (scope: global)

**Templates (`.claude/templates/`):**
- `plan-template.md` — implementation plan structure (used by /planner)
- `command.md`, `agent.md`, `skill.md`, `rule.md` — meta-agent templates
- `project-config.md` — project configuration template

---

## 2. Artifact Interaction Graph

```
CLAUDE.md (global error handling + language profile)
  │
  ├── Error table: Tests 3x → STOP_AND_WAIT, Loop 3x → STOP
  ├── ⚠️ NO exploration loop limit defined here
  │
  ↓
/workflow (orchestrator, opus) ─── workflow.md
  │
  ├─[startup]─→ workflow-protocols/SKILL.md
  │               ├── orchestration-core.md ──── loop limits (3x), phases, session recovery
  │               ├── autonomy.md ──── INTERACTIVE/AUTONOMOUS/RESUME, stop conditions
  │               ├── beads.md ──── NON_CRITICAL integration
  │               ├── [on-demand] checkpoint-protocol.md ──── 12-field YAML state
  │               ├── [on-demand] handoff-protocol.md ──── 4 contracts + 1 tool contract
  │               ├── [on-demand] re-routing.md ──── 3 triggers: S↔M↔L↔XL
  │               └── [on-demand] pipeline-metrics.md ──── 12-field metrics + anomaly detection
  │
  ├─[Phase 1]─→ /planner (opus) ─── planner.md
  │               ├── planner-rules/SKILL.md
  │               │   ├── task-analysis.md ──── 7 types, S/M/L/XL routing
  │               │   ├── data-flow.md ──── layer selection (skip S)
  │               │   ├── sequential-thinking-guide.md ──── L/XL only
  │               │   ├── mcp-tools.md ──── Memory, ST, Context7, PostgreSQL
  │               │   ├── checklist.md ──── 6-phase self-verification
  │               │   └── examples.md ──── good/bad code examples
  │               ├── templates/plan-template.md
  │               └── [optional, L/XL] code-researcher (Task tool, haiku)
  │                   ⚠️ Planner does direct research for S/M with NO budget
  │
  ├─[Phase 2]─→ plan-reviewer (agent, sonnet, maxTurns=40)
  │               └── plan-review-rules/SKILL.md
  │                   ├── required-sections.md ──── 5 always + 3 conditional sections
  │                   ├── architecture-checks.md ──── 6 manual + 5 auto checks + OWASP
  │                   ├── checklist.md ──── self-verification
  │                   └── troubleshooting.md
  │
  ├─[Phase 3]─→ /coder (sonnet) ─── coder.md
  │               ├── coder-rules/SKILL.md
  │               │   ├── mcp-tools.md ──── shared with planner-rules
  │               │   ├── checklist.md ──── startup/evaluate/implement/verify
  │               │   └── examples.md ──── bad/good patterns
  │               ├── [conditional] tdd-go/SKILL.md ──── if plan has ## TDD
  │               └── [optional, L/XL] code-researcher (Task tool, haiku)
  │                   ⚠️ Coder does direct research for S/M with NO budget
  │
  ├─[Phase 4]─→ code-reviewer (agent, sonnet, maxTurns=45, worktree)
  │               └── code-review-rules/SKILL.md
  │                   ├── examples.md ──── bad/good patterns + grep patterns
  │                   ├── security-checklist.md ──── OWASP (skip S)
  │                   ├── checklist.md ──── self-verification
  │                   └── troubleshooting.md
  │
  └─[Phase 5]─→ completion (orchestrator-owned)
                  ├── git commit (MANDATORY)
                  ├── bd sync (if beads)
                  └── pipeline-metrics.md (collect + save)


HOOKS (settings.json → 14 scripts, 8 events):
  ├── PreToolUse ──→ protect-files.sh, check-artifact-size.sh, block-dangerous-commands.sh
  ├── PostToolUse ─→ auto-fmt-go.sh, yaml-lint.sh, check-references.sh, check-plan-drift.sh
  ├── PreCompact ──→ save-progress-before-compact.sh
  ├── SubagentStop → save-review-checkpoint.sh (matcher: plan-reviewer|code-reviewer)
  ├── UserPromptSubmit → enrich-context.sh
  ├── Stop ─────────→ verify-phase-completion.sh, check-uncommitted.sh
  ├── SessionEnd ──→ session-analytics.sh
  └── Notification → notify-user.sh


RULES (auto-loaded by file scope):
  ├── architecture.md (internal/**/*.go) ──── import matrix + domain purity
  ├── go-conventions.md (**/*.go) ──── error wrapping, concurrency
  ├── handler-rules.md (internal/handler/**) ──── thin layer contract
  ├── service-rules.md (internal/service/**) ──── business logic
  ├── repository-rules.md (internal/repository/**) ──── data access
  ├── models-rules.md (internal/models/**) ──── pure domain
  ├── testing.md (**/*_test.go) ──── table-driven, race detector
  └── workflow.md (global) ──── commands vs agents, model routing
```

### 2.1 Data Flow Between Artifacts

```
User task
  → /workflow [Task Analysis → S/M/L/XL routing]
    → /planner [UNDERSTAND → DATA_FLOW → RESEARCH → DESIGN → DOCUMENT]
      ← handoff: {artifact, metadata, key_decisions, known_risks, areas_needing_attention}
    → plan-reviewer [STARTUP → READ PLAN → VALIDATE ARCH → VALIDATE COMPLETENESS → VERDICT]
      ← handoff: {artifact, verdict, issues_summary, approved_with_notes, iteration}
    → /coder [READ PLAN → EVALUATE → IMPLEMENT PARTS → VERIFY]
      ← handoff: {branch, parts, evaluate_adjustments, deviations, risks_mitigated, verify_status}
    → code-reviewer [STARTUP → QUICK CHECK → GET CHANGES → REVIEW → VERDICT]
      ← handoff: {verdict, issues, iteration, narrative}
    → completion [git commit + metrics + lessons_learned]
```

### 2.2 Hook Triggering Flow

```
UserPromptSubmit ──→ enrich-context.sh ──→ [Workflow State] injected into context
       │
PreToolUse ──→ protect-files.sh ──→ block/allow
             → check-artifact-size.sh ──→ block/allow
             → block-dangerous-commands.sh ──→ block/allow
       │
  [Tool Executes]
       │
PostToolUse ──→ auto-fmt-go.sh ──→ gofmt on .go files
             → yaml-lint.sh ──→ validate YAML
             → check-references.sh ──→ verify file references
             → check-plan-drift.sh ──→ detect implementation drift
       │
SubagentStop ──→ save-review-checkpoint.sh ──→ append to review-completions.jsonl
       │
PreCompact ──→ save-progress-before-compact.sh ──→ preserve state
       │
Stop ──→ verify-phase-completion.sh ──→ confirm phase done
      → check-uncommitted.sh ──→ block if dirty
       │
SessionEnd ──→ session-analytics.sh ──→ log metrics
       │
Notification ──→ notify-user.sh ──→ OS desktop alert
```

---

## 3. Issues Found

### ISSUE-01: No Exploration Loop Detection or Budget (CRITICAL)

**Problem:** The workflow system has loop limits for review cycles (max 3 iterations in orchestration-core.md) and failure thresholds for tests (3x → STOP in CLAUDE.md), but **NO mechanism to detect or limit exploration loops** — when Claude keeps reading files without transitioning to the next action.

**Affected Artifacts:**
- `CLAUDE.md` — error handling table has no exploration entry
- `orchestration-core.md` — loop limits cover review cycles only
- `autonomy.md` — stop conditions cover FATAL/USER/TOOL/FAILURE, not EXPLORATION
- `planner.md` — Phase 3 (RESEARCH) has no turn/file budget
- `coder.md` — Phase 1.5 (EVALUATE) has no turn/file budget

**Evidence:** The 25 friction events suggest Claude gets stuck in Read/Grep/Glob loops during planner RESEARCH and coder EVALUATE phases, never transitioning to DESIGN or IMPLEMENT.

**Impact on project-researcher:** Project-researcher has its own structured phases with explicit subagent delegation (each with model-specific budgets via Task tool). It does NOT suffer from this issue because every exploration is bounded by the subagent's execution context. However, if the workflow system established a reusable exploration budget pattern, project-researcher subagents could reference it for consistency.

---

### ISSUE-02: Planner Research Phase Has No Turn/File Budget (CRITICAL)

**Problem:** In `planner.md`, Phase 3 (RESEARCH) says:
- "Simple (1-2 files): Grep/Glob directly"
- "Complex (3+ packages): Delegate to code-researcher"

For S/M complexity tasks, planner researches directly with **no limit on file reads or tool calls**. The code-researcher agent has maxTurns=20 and ≤2000 token output budget, but when planner does research inline, there are zero constraints.

**Affected Artifacts:**
- `planner.md` — Phase 3 RESEARCH has no budget
- `planner-rules/SKILL.md` — no mention of exploration budget
- `planner-rules/checklist.md` — Phase 3 checklist has no budget check
- `code-researcher.md` — has budget (maxTurns=20, ≤2000 tokens) but only used for L/XL

**Root Cause:** The complexity routing assumes S/M tasks need little research, so no budget was added. In practice, even S/M tasks can trigger exploration loops when the codebase is unfamiliar.

**Impact on project-researcher:** Project-researcher's discovery subagent (haiku) does similar exploratory work but IS bounded by the Task tool context. The asymmetry means workflow planner has weaker guarantees than project-researcher for the same type of work (codebase exploration).

---

### ISSUE-03: Coder Evaluate Phase Has No Exploration Budget (HIGH)

**Problem:** In `coder.md`, Phase 1.5 (EVALUATE) can trigger code-researcher for gaps, but:
- "Research Assist: Skip: S/M complexity"
- For S/M tasks, coder researches directly with no limit
- Even for L/XL tasks, evaluation research BEFORE delegating to code-researcher has no budget

**Affected Artifacts:**
- `coder.md` — Phase 1.5 EVALUATE has no budget
- `coder-rules/SKILL.md` — evaluate protocol has no budget
- `coder-rules/checklist.md` — evaluate checklist has no budget check

**Impact on project-researcher:** Similar to ISSUE-02. Project-researcher's analysis subagent (opus) does evaluation-like work but is bounded by Task tool context. The coder's unbounded evaluate creates inconsistency.

---

### ISSUE-04: Missing Exploration Budget in Autonomy Stop Conditions (HIGH)

**Problem:** `autonomy.md` defines 4 stop conditions:
1. FATAL_ERROR — plan not found, critical dep missing
2. USER_INTERVENTION — scope unclear, multiple approaches
3. TOOL_UNAVAILABLE — MCP unavailable
4. FAILURE_THRESHOLD — tests/lint fail 3x

**Missing:** No EXPLORATION_THRESHOLD condition. There's nothing that says "if you've read N files or made N tool calls without producing output, STOP."

**Affected Artifacts:**
- `autonomy.md` — missing stop condition
- `orchestration-core.md` — loop limits cover review cycles only
- `CLAUDE.md` — error table has no exploration entry

**Impact on project-researcher:** Project-researcher defines its own stop conditions in AGENT.md (FATAL errors only). If autonomy.md had an EXPLORATION_THRESHOLD, project-researcher could reference it as a standard pattern for its subagents.

---

### ISSUE-05: enrich-context.sh Doesn't Track Research Sub-Phase State (MEDIUM)

**Problem:** `enrich-context.sh` injects workflow state into user prompts:
- Checkpoint: feature, phase, complexity, route, verdict
- Plans: available .md files
- Review completions: last 3 entries
- Git branch

**Missing:** No tracking of current sub-phase within planner or coder. If planner is in Phase 3 (RESEARCH), enrich-context.sh only shows "Phase: planning" — not "Phase: planning/RESEARCH (15 file reads, 0 output)". This makes exploration loops invisible to context enrichment.

**Affected Artifacts:**
- `enrich-context.sh` — collects checkpoint data but not sub-phase data
- `save-progress-before-compact.sh` — same limitation
- `checkpoint-protocol.md` — checkpoint format has no sub-phase fields

**Impact on project-researcher:** Project-researcher uses its own progress tracking (`[PHASE N/10] NAME — DONE`). The workflow's lack of sub-phase tracking means there's no shared infrastructure for detecting within-phase stalls.

---

### ISSUE-06: Asymmetry Between code-researcher Budget and Direct Research (MEDIUM)

**Problem:** When exploration is delegated to code-researcher:
- maxTurns=20
- Output ≤2000 tokens
- Max 3 snippets, each ≤15 lines
- Strict output format
- Clear termination conditions

When planner/coder do research directly (S/M complexity):
- No turn limit
- No output budget
- No format constraint
- No termination signal

This creates a perverse incentive: for S/M tasks, research runs unbounded because it's "too simple" to delegate. But it's precisely these unbounded inline research sessions that cause exploration loops.

**Affected Artifacts:**
- `code-researcher.md` — well-budgeted
- `planner.md` — unbudgeted direct research
- `coder.md` — unbudgeted direct research
- `planner-rules/SKILL.md` — no budget for direct research
- `coder-rules/SKILL.md` — no budget for direct research

**Impact on project-researcher:** Project-researcher consistently delegates ALL exploration to subagents (never does inline exploration). This is the correct pattern. The workflow should follow it.

---

### ISSUE-07: No Graduated Exploration Budget by Complexity (MEDIUM)

**Problem:** Even if we add an exploration budget, it should vary by complexity:
- S tasks: very tight (5-8 file reads, 10-15 tool calls)
- M tasks: moderate (10-15 file reads, 20-25 tool calls)
- L tasks: larger (15-25 file reads, 30-40 tool calls) with code-researcher delegation
- XL tasks: extensive (25+ file reads) with mandatory code-researcher delegation

Currently, the complexity routing only determines:
- Whether to skip plan-review (S)
- Whether Sequential Thinking is recommended/required (L/XL)
- Whether to delegate to code-researcher (L/XL)

It does NOT determine exploration budgets.

**Affected Artifacts:**
- `planner-rules/task-analysis.md` — complexity matrix has no budget column
- `planner.md` — Phase 3 has no budget
- `coder.md` — Phase 1.5 has no budget
- `orchestration-core.md` — no per-phase budgets

**Impact on project-researcher:** Project-researcher doesn't have complexity routing (it's always "full analysis"). But its subagent model selection (haiku/sonnet/opus) implicitly provides graduated budgets via model capabilities and turn limits. The workflow should make this explicit.

---

### ISSUE-08: No "Research → Action" Transition Checkpoint (MEDIUM)

**Problem:** The workflow has clear checkpoints between phases (Phase 1 → Phase 2 → etc.) via checkpoint-protocol.md. But within planner and coder, the transitions from internal research sub-phases to action sub-phases have NO checkpoints:
- Planner: RESEARCH → DESIGN has no checkpoint
- Coder: EVALUATE → IMPLEMENT has no checkpoint

These internal transitions are exactly where exploration loops happen — Claude keeps researching instead of transitioning to design/implement.

**Affected Artifacts:**
- `checkpoint-protocol.md` — checkpoints only between pipeline phases
- `planner.md` — no internal checkpoint between RESEARCH and DESIGN
- `coder.md` — no internal checkpoint between EVALUATE and IMPLEMENT
- `planner-rules/checklist.md` — checklist exists but has no transition enforcement

**Impact on project-researcher:** Project-researcher has explicit state validation between EVERY subagent call (Rule 8: "Validate state contract between every subagent call"). Each sub-phase writes to state and the orchestrator validates it before proceeding. This pattern could be adapted for workflow internal transitions.

---

### ISSUE-09: session-analytics.sh Doesn't Track Exploration Metrics (LOW)

**Problem:** `session-analytics.sh` tracks:
- duration, message count, user prompts, tool calls, errors
- tool breakdown: {"Read": N, "Write": N, "Bash": N}
- checkpoint state

**Missing:** No ratio analysis. A session where Read=30, Grep=20, Write=0 is clearly an exploration loop, but session-analytics.sh doesn't flag this pattern. No "Read/Write ratio" or "exploration vs action" metric.

**Affected Artifacts:**
- `session-analytics.sh` — collects raw metrics but no derived insights
- `pipeline-metrics.md` — anomaly detection rules don't cover exploration patterns

**Impact on project-researcher:** Project-researcher doesn't use session analytics. But if analytics could detect exploration loops post-hoc, it would help improve both workflow and project-researcher iteration.

---

### ISSUE-10: Inconsistent Loop Limit Terminology Across Artifacts (LOW)

**Problem:** Different artifacts use different terminology and thresholds for similar concepts:
- `CLAUDE.md`: "Tests fail 3x → STOP_AND_WAIT" / "Loop limit exceeded (3x) → STOP"
- `orchestration-core.md`: "plan_review_cycle: max 3" / "code_review_cycle: max 3"
- `autonomy.md`: "FAILURE_THRESHOLD (tests/lint fail 3x)"
- `workflow.md` (command): "Review cycle exceeds 3 iterations"
- Agents: "If 30+ tool calls → skip to VERDICT" (plan-reviewer) / "If 35+ tool calls → skip to VERDICT" (code-reviewer)

The agent tool-call thresholds (30/35) are a form of exploration budget but are framed as "output protection" (RULE_5) rather than "exploration budget." This inconsistency means there's no unified vocabulary for budgets.

**Affected Artifacts:**
- All artifacts listed above
- No shared glossary or terminology document

**Impact on project-researcher:** Project-researcher doesn't use the workflow's loop limit terminology at all. It has its own concepts (blocking gates, max_retries). A unified vocabulary would help cross-pollination between systems.

---

## 4. Summary of Findings

### 4.1 Issue Severity Distribution

| Severity | Count | Issues |
|----------|-------|--------|
| CRITICAL | 2 | ISSUE-01, ISSUE-02 |
| HIGH | 2 | ISSUE-03, ISSUE-04 |
| MEDIUM | 4 | ISSUE-05, ISSUE-06, ISSUE-07, ISSUE-08 |
| LOW | 2 | ISSUE-09, ISSUE-10 |

### 4.2 Root Cause Analysis

All 10 issues trace back to a single root cause: **the workflow system was designed with inter-phase governance (loop limits between phases, handoff contracts, checkpoint protocol) but lacks intra-phase governance (budgets within research sub-phases, transition signals within planner/coder).**

The review agents (plan-reviewer, code-reviewer) have implicit intra-phase budgets via maxTurns and RULE_5 (tool-call thresholds). But the commands (planner, coder) run in the orchestrator context with no such limits.

The code-researcher agent demonstrates the correct pattern: explicit budgets (maxTurns=20, ≤2000 tokens, max 3 snippets). The fix is to propagate this pattern to direct research in planner/coder.

### 4.3 Impact on project-researcher

| Issue | Impact Level | Nature |
|-------|-------------|--------|
| ISSUE-01 | Low | PR has own phase structure; no shared exploration budget pattern to reference |
| ISSUE-02 | Low | PR delegates all exploration to subagents (correct pattern) |
| ISSUE-03 | Low | Same as ISSUE-02 |
| ISSUE-04 | Medium | PR could benefit from shared EXPLORATION_THRESHOLD in autonomy vocabulary |
| ISSUE-05 | Low | PR has own progress tracking |
| ISSUE-06 | Medium | PR's consistent delegation pattern IS the solution; workflow should adopt it |
| ISSUE-07 | Low | PR uses model routing instead of explicit budgets |
| ISSUE-08 | Medium | PR's state validation between subagents IS the solution model |
| ISSUE-09 | Low | PR doesn't use session analytics |
| ISSUE-10 | Low | Unified terminology would help cross-system consistency |

**Key insight:** project-researcher already solves the exploration loop problem through consistent subagent delegation with bounded contexts. The workflow system should adopt similar patterns rather than relying on unbounded inline research.
