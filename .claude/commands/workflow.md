---
name: workflow
description: "Full development cycle: task-analysis → planner → plan-review (agent) → coder → code-review (agent)"
model: opus
---

role:
  identity: "Orchestrator"
  owns: "Coordination of full development cycle: task-analysis → planner → plan-review (agent) → coder → code-review (agent)"
  does_not_own: "Planning, implementation, review — delegates to sub-commands and agents"
  output_contract: "Implemented, tested, and reviewed code with commit + pipeline metrics"
  success_criteria: "All phases completed, handoff contracts fulfilled, checkpoint saved, metrics recorded"
  style: "Sequential phases with user confirmation between each phase"

## TRIGGERS
triggers:
  - if: "Task requires full development cycle (planning + implementation + review)"
    then: "Use /workflow instead of individual commands"

  - if: "Phase verdict is REJECTED, NEEDS_CHANGES, or CHANGES_REQUESTED"
    then: "Return to previous phase, do NOT skip ahead"

  - if: "User says 'stop' or 'pause'"
    then: "Stop immediately, save current state for --from-phase resume"

  - if: "Tests fail 3x consecutively in Phase 3"
    then: "Stop, request manual intervention"

  - if: "Review cycle exceeds 3 iterations (plan-review or code-review)"
    then: "STOP immediately, show iteration summary, request user help"

## INPUT
input:
  arguments:
    - name: task
      required: true
      format: "Text or beads ID"
      example: "Add new functionality"

    - name: --auto
      required: false
      format: flag
      description: "Autonomous mode without confirmations"

    - name: --from-phase
      required: false
      format: "1-4"
      description: "Resume from specified phase (1=Planning, 2=Plan Review, 3=Implementation, 4=Code Review)"

  examples:
    - "/workflow Add new endpoint"
    - "/workflow --auto Implement resource update"
    - "/workflow --from-phase 3"
    - "/workflow beads-abc123"

## OUTPUT
output:
  phases:
    - phase: Planning
      produces: Implementation plan
      location: ".claude/prompts/{feature}.md"

    - phase: Plan Review
      produces: Verdict + issues
      location: Console (via plan-reviewer agent)

    - phase: Implementation
      produces: Working code + tests
      location: Source files

    - phase: Code Review
      produces: Verdict + comments
      location: Console (via code-reviewer agent)

    - phase: Completion
      produces: Git commit + lessons_learned in Memory (if non-trivial)
      location: Repository + Memory MCP

  final_output: "Implemented, tested, and reviewed code with commit."

## AUTONOMY
autonomy:
  modes: "INTERACTIVE (default) | AUTONOMOUS (--auto) | RESUME (--from-phase N)"
  note: "MINIMAL mode (--minimal) is a /planner argument, not a /workflow argument. Use /planner --minimal directly for lightweight planning."
  stop: "REJECTED → stop | NEEDS_CHANGES/CHANGES_REQUESTED → previous phase | Tests 3x → stop | Loop 3x → stop"
  continue: "Phase completed → next | NEEDS_CHANGES → previous phase"
  details: "SEE [autonomy.md] in workflow-protocols skill"

## MCP TOOLS
mcp_tools:
  reference: "SEE [mcp-tools.md] in planner-rules / coder-rules skill"
  workflow_usage: "Sequential Thinking (complex orchestration), Memory (startup search + completion save)"

## STARTUP
startup:
  critical: "On agent startup, IMMEDIATELY execute ALL steps"

  steps:
    - step: 0
      action: "Task Analysis — task classification"
      reference: "For details see [task-analysis.md] in planner-rules skill"
      purpose: "Determine complexity (S/M/L/XL) and route BEFORE planning"
      decisions:
        S: "/planner --minimal → skip Phase 2 → /coder → code-reviewer (agent)"
        M: "standard flow (all phases)"
        L: "full flow + Sequential Thinking recommended"
        XL: "full flow + Sequential Thinking REQUIRED"
      warning: "MANDATORY! Wrong classification = wasted work"

    - step: 0.1
      action: "Load workflow-protocols skill"
      files:
        - ".claude/skills/workflow-protocols/SKILL.md"
      purpose: "Overview of handoff, checkpoint, re-routing, and metrics protocols. Supporting files loaded on-demand per event triggers."

    - step: 1
      action: "TodoWrite — create phase list (based on route from Task Analysis)"
      items:
        - "Phase 0: Get Task (completed — task received)"
        - "Phase 0.5: Task Analysis (completed — already done in step 0)"
        - "Phase 1: Planning (pending)"
        - "Phase 2: Plan Review → plan-reviewer agent (pending — or skip if S-complexity)"
        - "Phase 3: Implementation (pending)"
        - "Phase 4: Code Review → code-reviewer agent (pending)"
        - "Phase 5: Completion — commit + metrics (pending)"

    - step: 2
      action: "mcp__memory__search_nodes — query: '{task keywords}'"
      note: "MANDATORY! Check for similar solutions"

    - step: 3
      action: "Check beads"
      checks:
        - "bd list --status=open → is there a related task?"
        - "bd list --status=in_progress → is there unfinished work?"
      note: "Beads is NON_CRITICAL. If bd unavailable → skip."

    - step: 4
      action: "Check session recovery"
      checks:
        - "Does `.claude/prompts/{feature}.md` exist? → can skip Phase 1"
        - "Is there a beads issue in_progress? → bd show <id>"

## PIPELINE
pipeline:
  mandatory: |
    🔴 MANDATORY: Load skills BEFORE executing any phase:
    - Workflow: workflow-protocols skill (step 0.1) — includes autonomy, beads, orchestration-core
    - Planner: planner-rules skill (step 0) — includes mcp-tools, sequential-thinking-guide
    - Coder: coder-rules skill (step 0) — includes mcp-tools
    NOTE: Plan Review and Code Review → agents/ with skills preloading (plan-review-rules, code-review-rules)
    NOTE: Language profile + error handling → auto-loaded via CLAUDE.md

  flow: "task-analysis → /planner [→ code-researcher*] → plan-reviewer (agent) → /coder [→ code-researcher*] → code-reviewer (agent)"
  flow_note: "* code-researcher is optional tool-assist via Task tool, triggered by planner/coder for L/XL tasks. Not a pipeline phase."

  evaluate_note: |
    /coder runs internal EVALUATE sub-phase (Phase 1.5) before implementing.
    Outcomes:
      PROCEED: plan is implementable → start implementation
      REVISE: minor gaps, inline fixes → proceed with adjustments noted
      RETURN: major gaps → re-route to Phase 1 (counts toward plan_review iteration counter)
    On RETURN: orchestrator increments plan_review counter, writes checkpoint, re-runs /planner with coder feedback.

  load_phases:
    - action: "Read .claude/skills/workflow-protocols/autonomy.md"
      when: "BEFORE starting Phase 0"
      required: true
    - action: "Read .claude/skills/workflow-protocols/beads.md"
      when: "BEFORE starting Phase 0"
      required: true
    - action: "Read .claude/skills/workflow-protocols/orchestration-core.md"
      when: "ALWAYS — contains pipeline phases, loop limits, session recovery"
      required: true
      contains:
        - Pipeline diagram with verdicts and routing
        - Loop limits (max 3 iterations per review cycle, tracking protocol)
        - Session recovery (checkpoint-first, heuristic fallback)

  completion_notes:
    - "Git commit created (MANDATORY)"
    - "bd sync executed (MANDATORY, if beads)"
    - "Save lessons_learned → SEE orchestration-core.md + mcp-tools.md (if non-trivial)"

## DELEGATION PROTOCOL
delegation_protocol:
  purpose: "How workflow delegates review phases to native agents/"
  mechanism: "Claude auto-delegates based on agent description. Orchestrator forms delegation prompt with handoff context."
  isolation_guarantee: "Agents run in clean context. CLAUDE.md auto-loaded from project root. Parent conversation history is NOT passed."
  reference: "SEE: pipeline.flow for quick route overview"

  plan_review_delegation:
    agent: "plan-reviewer"
    when: "Phase 2 — after /planner completion"
    skip_when: "S-complexity route"
    context_to_pass:
      - "Artifact path: .claude/prompts/{feature}.md"
      - "Planner handoff narrative (SEE: handoff_protocol)"
      - "Complexity: S/M/L/XL"
      - "Iteration: N/3"
    delegation_prompt_template: |
      Review the implementation plan at .claude/prompts/{feature}.md

      [Context from planner]:
      - Planner completed: {task type and complexity}
      - Key decisions: {list from handoff.key_decisions}
      - Known risks: {list from handoff.known_risks}
      - Recommendations: focus on {handoff.areas_needing_attention}

      Iteration: {N}/3
    returns: "Verdict (APPROVED/NEEDS_CHANGES/REJECTED) + issues + handoff for coder"

  code_review_delegation:
    agent: "code-reviewer"
    when: "Phase 4 — after /coder completion"
    isolation: "worktree — agent sees only committed changes. Ensure git commit before delegating."
    optimization: "Pass verify_status in handoff to allow code-reviewer to skip QUICK CHECK re-run (see FIX-1). Worktree overhead is unavoidable but test overhead is not."
    context_to_pass:
      - "Branch: current branch (code-reviewer runs git diff internally in worktree)"
      - "Coder handoff narrative (SEE: handoff_protocol)"
      - "Complexity: S/M/L/XL"
      - "Iteration: N/3"
      - "Verify status: lint PASS/FAIL, test PASS/FAIL (from coder VERIFY phase)"
    delegation_prompt_template: |
      Review code changes on the current branch.

      [Context from coder]:
      - Coder implemented: {N Parts per plan}
      - Evaluate adjustments: {list from handoff.evaluate_adjustments}
      - Deviations from plan: {list from handoff.deviations_from_plan}
      - Mitigated risks: {list from handoff.risks_mitigated}
      - Verify: lint {PASS/FAIL}, test {PASS/FAIL} (command: {verify_command})

      Iteration: {N}/3
    returns: "Verdict (APPROVED/APPROVED_WITH_COMMENTS/CHANGES_REQUESTED) + issues + handoff for completion"

  fallback: "If agent delegation unavailable → fallback: re-read diff/plan in parent context (degraded mode, loss of isolation)"

  code_researcher_usage:
    agent: "code-researcher"
    mechanism: "Task tool (NOT native agent delegation — code-researcher is tool-assist, not pipeline phase)"
    invoked_by: "planner (Phase 3) and coder (Phase 1.5) — NOT by orchestrator"
    when: "Multi-package codebase research needed, complexity L/XL"
    skip_when: "S/M complexity, --minimal planner mode"
    returns: "Structured summary ≤2000 tokens (patterns, files, imports, key snippets)"
    checkpoint_impact: "None — research is part of Phase 1/3, not a separate phase"
    hook_impact: "None — SubagentStop does NOT fire for Task tool subagents"
    note: "Differs from plan-reviewer/code-reviewer: those are pipeline-phase agents invoked by orchestrator via native delegation. code-researcher is a tool-agent invoked by sub-commands via Task tool."

## RULES
rules:
  - "Sequential execution — phases sequentially, not in parallel"
  - "No skip phases (except Phase 2 for S-complexity)"
  - "Context isolation — review via agents/ (clean context, handoff via delegation)"
  - "Loop limits → SEE orchestration-core.md (max 3 iterations per cycle)"

## ERROR HANDLING
error_handling:
  common: "SEE CLAUDE.md (MCP unavailable, beads, tests 3x fail)"
  workflow_specific:
    - "Loop limit exceeded (3 iterations) → STOP, show summary, request user help"
    - "User says 'stop' → Stop immediately, await instructions"
    - "REJECTED/NEEDS_CHANGES/CHANGES_REQUESTED → return to previous phase (SEE pipeline)"

## SKILL REFERENCES
skill_references:
  workflow-protocols:
    - "session-recovery → orchestration-core.md (auto-detect, decision table)"
    - "checkpoint → checkpoint-protocol.md (12 YAML fields, recovery)"
    - "re-routing → re-routing.md (3 triggers, tracking, learning)"
    - "pipeline-metrics → pipeline-metrics.md (load at completion phase)"
    - "examples → examples-troubleshooting.md (on-demand when issues arise)"
    - "handoff → handoff-protocol.md (4 contracts, narrative casting)"

## HOOKS
hooks:
  note: |
    Configured in .claude/settings.json (authoritative source — 8 event types, 14 scripts).
    This section lists only workflow-specific hooks. For complete list see settings.json.
    Deterministic — fires automatically, no need to remember.

  workflow_specific:
    - event: PreCompact
      script: ".claude/scripts/save-progress-before-compact.sh"
      behavior: "Saves checkpoint + review completions to additionalContext before compaction"
      blocking: false

    - event: SubagentStop
      script: ".claude/scripts/save-review-checkpoint.sh"
      matcher: "plan-reviewer|code-reviewer"
      behavior: "Appends review completion marker to .claude/workflow-state/review-completions.jsonl"
      blocking: true

    - event: Stop
      script: ".claude/scripts/check-uncommitted.sh"
      behavior: "Blocks stop if uncommitted changes exist"
      blocking: true

  also_active_during_workflow:
    - "UserPromptSubmit → enrich-context.sh (context enrichment on every prompt)"
    - "PreToolUse → protect-files.sh, check-artifact-size.sh, block-dangerous-commands.sh"
    - "PostToolUse → auto-fmt-go.sh, yaml-lint.sh, check-references.sh, check-plan-drift.sh"
    - "SessionEnd → session-analytics.sh"
    - "Notification → notify-user.sh"
