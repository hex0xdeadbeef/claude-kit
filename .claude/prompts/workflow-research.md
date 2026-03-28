---
title: "Workflow Artifact Research & Architecture Documentation"
feature: workflow-research
task_type: documentation
complexity: XL
status: pending_review
plan_version: "1.0"
created: "2026-03-29"
---

# Plan: Workflow Architecture Documentation

## Context

Данная директория (`/Users/dmitriym/Desktop/claude-kit/.claude/`) содержит все артефакты Claude Kit — конфигурационного фреймворка для Claude Code. Задача — провести комплексное исследование, отобрать артефакты, относящиеся к Workflow-пайплайну, построить граф взаимодействия и оформить всё в виде детального `.md`-файла.

Research complete (5 parallel code-researcher agents). All artifact data collected.

## Scope

### IN
- Select only workflow-pipeline artifacts (those participating in: task-analysis → /planner → plan-reviewer → /coder → code-reviewer → completion)
- Document purpose of each artifact with context
- Build interaction graph (Mermaid diagrams at multiple levels)
- Write detailed `.md` documentation file

### OUT
- meta-agent command (artifact lifecycle — not part of dev pipeline)
- project-researcher command/agent (onboarding — not part of dev pipeline)
- db-explorer command/agent (on-demand analysis — not pipeline phase)
- Application source code (this project has no Go application code)

## Dependencies

All research data collected from 5 parallel agents:
- Commands: 7 files analyzed (3 workflow-relevant: workflow.md, planner.md, coder.md)
- Agents: 6 agents analyzed (3 workflow-relevant: plan-reviewer, code-reviewer, code-researcher)
- Skills: 6 packages, 36 files analyzed (all workflow-relevant)
- Scripts/Hooks: 17 scripts, 13 hook events analyzed (all workflow-relevant)
- Rules: 8 rule files + CLAUDE.md + PROJECT-KNOWLEDGE.md analyzed

## Architecture Decision

**Output file:** `.claude/docs/workflow-architecture.md`
- Location rationale: `.claude/docs/` is the documentation directory for Claude Kit configuration
- Format: YAML-first metadata header, then Markdown body with Mermaid diagrams
- Language: Russian (task description was in Russian) with technical terms in English

**Diagram strategy:** 3 separate Mermaid diagrams for readability:
1. Core Pipeline Flow (LR flowchart: phases + verdicts + routing)
2. Skill Loading Graph (TD: which commands/agents load which skills)
3. Hooks & State Graph (TD: events → scripts → state files)

## Parts

### Part 1: Document Setup — Header, Artifact Inventory, Excluded Artifacts
**Files:** `.claude/docs/workflow-architecture.md` (create)
**Content:**
- YAML frontmatter (title, version, date)
- Executive summary (what workflow is, 6-phase pipeline overview)
- **Artifact Inventory table** — all workflow-relevant artifacts (50+ items by category)
- **Excluded Artifacts table** — non-workflow artifacts with explanation

### Part 2: Core Pipeline Section
**Files:** `.claude/docs/workflow-architecture.md` (append)
**Content:**
- Phase descriptions (Phase 0.5 through Phase 5)
- **Mermaid Diagram 1: Core Pipeline Flow** — LR flowchart:
  - task input → task-analysis → /planner → plan-reviewer → /coder → code-reviewer → completion
  - Verdict routing: APPROVED/NEEDS_CHANGES/REJECTED/CHANGES_REQUESTED
  - Loop back arrows with max 3 labels
  - S-complexity shortcut (skip plan-review)
  - code-researcher optional tool-assist on Phase 1 and 3
- Complexity routing table (S/M/L/XL → route decisions)
- Loop limits explanation (3 iterations max, counter tracking by orchestrator)

### Part 3: Commands Section
**Files:** `.claude/docs/workflow-architecture.md` (append)
**Content — for each of 3 core commands:**

**workflow.md:**
- Identity, role, owns/does-not-own
- Input arguments (task, --auto, --from-phase)
- Startup sequence (steps 0→3: task-analysis, load protocols, TodoWrite, CronCreate)
- Delegation protocol (plan-review vs code-review delegation templates)
- Output validation (VERDICT recovery via SendMessage)
- Key rules (sequential execution, context isolation, loop limits)

**planner.md:**
- Identity, role, owns/does-not-own
- 6-phase workflow (Task Analysis → Understand → Data Flow → Research → Design → Document)
- Research budget table (S/M/L/XL file read limits)
- Background mode (code-researcher run_in_background for L/XL)
- RULE_1–4 (No Code, Questions First, Full Examples, Import Matrix)
- Output: plan file + handoff payload

**coder.md:**
- Identity, role, owns/does-not-own
- 5-phase workflow (Read Plan → Evaluate → Implement → Simplify → Verify)
- EVALUATE sub-phase decision matrix (PROCEED/REVISE/RETURN)
- VERIFY resolution chain (PROJECT-KNOWLEDGE.md > Makefile > go.mod)
- RULE_1–5 (Plan Only, Import Matrix, Clean Domain, No Log+Return, Tests Pass)
- TDD integration (conditional on ## TDD section in plan)

### Part 4: Agents Section
**Files:** `.claude/docs/workflow-architecture.md` (append)
**Content — for each of 3 workflow agents:**

**plan-reviewer:**
- Model: sonnet, isolation: none, tools: Read/Grep/Glob/TodoWrite/Write (NO Bash/Edit)
- Input handoff contract (planner → plan-reviewer)
- Review phases (READ PLAN → VALIDATE ARCHITECTURE → VALIDATE COMPLETENESS → VERDICT)
- Severity classification (BLOCKER/MAJOR/MINOR/NIT with auto-escalation rules)
- Output: `VERDICT: {APPROVED|NEEDS_CHANGES|REJECTED}` (FIRST LINE mandatory)
- Output handoff contract (plan-reviewer → coder)
- Memory protocol (save recurring issues, read project context)

**code-reviewer:**
- Model: sonnet, isolation: worktree (git sparse-checkout), tools: Read/Grep/Glob/Bash/TodoWrite/Write
- Input handoff contract (coder → code-reviewer)
- Review phases (QUICK CHECK → GET CHANGES → REVIEW → VERDICT)
- Severity + auto-escalation (5+ MINOR → MAJOR, security → BLOCKER, import violation → BLOCKER)
- Sequential Thinking triggers (>100 lines OR >5 files OR 3+ layers)
- Output: `VERDICT: {APPROVED|APPROVED_WITH_COMMENTS|CHANGES_REQUESTED}` (FIRST LINE mandatory)
- Output handoff contract (code-reviewer → completion)
- Worktree isolation + agent memory sync lifecycle

**code-researcher:**
- Model: haiku, invocation: Agent/Task tool (NOT pipeline phase)
- Invoked by: /planner (Phase 3 Research) and /coder (Phase 1.5 Evaluate)
- Input: research question + focus areas
- Output: structured summary ≤2000 tokens (patterns, files, imports, key snippets)
- Background mode (run_in_background: true for L/XL in planner)
- RULE_1–4 (Read-only, Token budget, Facts only, Key snippets only)
- Memory protocol (codebase topology on startup, new patterns on completion)

### Part 5: Skills Section
**Files:** `.claude/docs/workflow-architecture.md` (append)
**Content:**
- **Mermaid Diagram 2: Skill Loading Graph** — which commands/agents load which skills and when
- For each of 6 skill packages:

**workflow-protocols (8 files):**
- Loaded by: /workflow at startup (step 0.1)
- Files: SKILL.md, autonomy.md, orchestration-core.md, handoff-protocol.md, checkpoint-protocol.md, re-routing.md, pipeline-metrics.md, agent-memory-protocol.md, examples-troubleshooting.md
- Purpose of each file
- Event-driven loading principle (not all upfront)

**planner-rules (7 files):**
- Loaded by: /planner at startup (step 0)
- Files: SKILL.md, task-analysis.md, sequential-thinking-guide.md, mcp-tools.md, data-flow.md, examples.md, checklist.md, troubleshooting.md
- Purpose of each file

**plan-review-rules (5 files):**
- Loaded by: plan-reviewer agent at startup
- Files: SKILL.md, required-sections.md, architecture-checks.md, checklist.md, troubleshooting.md

**coder-rules (5 files):**
- Loaded by: /coder at startup (step 0)
- Files: SKILL.md, mcp-tools.md, examples.md, checklist.md, troubleshooting.md

**code-review-rules (5 files):**
- Loaded by: code-reviewer agent at startup
- Files: SKILL.md, examples.md, security-checklist.md, checklist.md, troubleshooting.md

**tdd-go (3 files):**
- Loaded by: /coder conditionally (if plan has ## TDD section)
- Files: SKILL.md, references/patterns.md, references/examples.md
- RED-GREEN-REFACTOR cycle description

### Part 6: Hooks & Scripts Section
**Files:** `.claude/docs/workflow-architecture.md` (append)
**Content:**
- **Mermaid Diagram 3: Hooks & State Graph** — events → scripts → state files
- Hook events table (13 events with script, blocking status, matcher, conditional if, purpose)
- Conditional `if` fields explanation (v2.1.85 — reduces process spawning)
- Blocking vs non-blocking distinction
- State files table (workflow-state/ — 6 files with format and populated-by)
- Agent Memory lifecycle (seed → execute → sync bidirectional flow)

### Part 7: Rules Section
**Files:** `.claude/docs/workflow-architecture.md` (append)
**Content:**
- Rules activation mechanism (frontmatter glob patterns → PreToolUse hook)
- Rules table (8 rules: file, activation pattern, purpose, key constraints)
- Architecture import matrix (handler → service → repository → models)
- Error handling pattern (fmt.Errorf with %w, no log+return)

### Part 8: State & Config Section
**Files:** `.claude/docs/workflow-architecture.md` (append)
**Content:**
- Workflow state files (detailed: checkpoint YAML 12 fields, review-completions.jsonl schema, task-events.jsonl, session-analytics.jsonl)
- Agent memory structure (agent-memory/plan-reviewer/ and agent-memory/code-reviewer/)
- Config hierarchy: settings.json → CLAUDE.md → PROJECT-KNOWLEDGE.md
- Templates overview (6 templates with purpose)

### Part 9: Design Principles Section
**Files:** `.claude/docs/workflow-architecture.md` (append)
**Content:**
- 10 key design decisions with rationale:
  1. Commands vs Agents split (shared context vs clean context)
  2. Model routing by phase complexity
  3. Event-driven skill loading (not upfront)
  4. Typed handoffs (MetaGPT pattern)
  5. Loop limits (max 3 iterations, orchestrator-owned counters)
  6. Conditional `if` hooks (v2.1.85 — performance optimization)
  7. Bidirectional agent memory (seed → sync lifecycle)
  8. Worktree isolation for code-review
  9. Background code-researcher (parallel execution for L/XL)
  10. EVALUATE sub-phase (plan feasibility before implementation)

## Files Summary

- CREATE `.claude/docs/workflow-architecture.md`

## Acceptance Criteria

- [ ] `.claude/docs/workflow-architecture.md` created and ≥700 lines
- [ ] All 3 Mermaid diagrams present (Pipeline Flow, Skill Loading, Hooks & State)
- [ ] Mermaid syntax is valid (no unclosed brackets, proper node definitions, valid flowchart syntax)
- [ ] YAML frontmatter in output file is well-formed (no syntax errors)
- [ ] All 50+ workflow-relevant artifacts documented with purpose
- [ ] Interaction graph shows all 6 levels of relationships
- [ ] Excluded artifacts listed with rationale
- [ ] Document structure: YAML header → sections → diagrams
- [ ] Design principles section with rationale for each decision
- [ ] All file paths are accurate (verified against actual filesystem)

## Testing Plan

Documentation task — no code tests required.

Verification:

- Read the output file and verify all sections are present
- Verify file paths referenced in document match actual filesystem
- Verify artifact counts match research findings

## Handoff Notes

All research data available in conversation context. Implementation (coder) can use this data directly — no additional filesystem reads needed for most sections. Exception: may need to spot-check specific file line counts or confirm exact skill file lists.
