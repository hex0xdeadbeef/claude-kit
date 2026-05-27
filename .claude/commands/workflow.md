---
name: workflow
description: "Full development cycle: task-analysis → [/designer (L/XL)] → planner → plan-review (agent) → coder → code-review (agent)"
model: opus
effort: max
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
      format: "Text"
      example: "Add new functionality"

    - name: --auto
      required: false
      format: flag
      description: "Autonomous mode without confirmations"

    - name: --from-phase
      required: false
      format: "0.7|1-4"
      description: "Resume from specified phase (0.7=Design, 1=Planning, 2=Plan Review, 3=Implementation, 4=Code Review)"

  examples:
    - "/workflow Add new endpoint"
    - "/workflow --auto Implement resource update"
    - "/workflow --from-phase 3"

## OUTPUT
output:
  phases:
    - phase: Design
      produces: Approved design spec
      location: ".claude/prompts/{feature}-spec.md"
      note: "L/XL only. S/M skip to Planning."

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
      produces: Git commit
      location: Repository

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
  workflow_usage: "Sequential Thinking (complex orchestration)"

## STARTUP
startup:
  critical: "On agent startup, IMMEDIATELY execute ALL steps"

  steps:
    - step: 0.05
      action: "Pre-flight: PROJECT-KNOWLEDGE.md sanity check"
      tool: "Bash (read-only)"
      check: |
        Run: test -f .claude/PROJECT-KNOWLEDGE.md && grep -E '<your-[a-z-]+>' .claude/PROJECT-KNOWLEDGE.md | head -3
      mode_env: "CLAUDE_PROJECT_KNOWLEDGE_MODE (warn|strict, default warn)"
      behavior:
        - if: "PROJECT-KNOWLEDGE.md missing"
          then_warn: "[workflow] WARN: PROJECT-KNOWLEDGE.md not found — slot-driven architecture checks will be SKIPPED. Run /project-researcher or copy .claude/PROJECT-KNOWLEDGE.md.example."
          then_strict: "BLOCK if complexity >= M; emit FATAL message and exit 2"
        - if: "PROJECT-KNOWLEDGE.md exists AND contains placeholder values matching '<your-[a-z-]+>' AND complexity >= M"
          then_warn: "[workflow] WARN: PROJECT-KNOWLEDGE.md has unfilled placeholders for {complexity} task — checks dependent on those slots will be SKIPPED. Fill in the matching slots."
          then_strict: "BLOCK if complexity >= M; emit FATAL message and exit 2"
        - if: "PROJECT-KNOWLEDGE.md exists AND fully populated (zero '<your-[a-z-]+>' matches)"
          then: "PROCEED silently (no message)"
        - if: "Complexity is S"
          then: "PROCEED silently regardless of PK state (S tasks rarely run slot-driven checks)"
      stderr_format: "[workflow] WARN: <message>"
      exit_on_strict: 2
      probe_for_acceptance: |
        Falsifiable predicate: With a fully-filled PROJECT-KNOWLEDGE.md (zero
        '<your-[a-z-]+>' matches), running /workflow at any complexity must
        produce ZERO stderr WARN lines from this step. Verify with:
          test -z "$(grep -E '<your-[a-z-]+>' .claude/PROJECT-KNOWLEDGE.md)" && echo "PASS: filled PK"
      purpose: |
        Prevents silent Go-fallback for non-Go projects. The cascade order
        (PROJECT-KNOWLEDGE.md > CLAUDE.md Language Profile > SKIP) is designed
        to be ZERO-COST when PK is properly populated. The pre-flight WARN is
        the early-warning signal that something is missing. Generic regex
        '<your-[a-z-]+>' is extensible to future PK slot additions without
        grep-pattern updates.

    - step: 0.06
      action: "Pre-flight: native memory freshness check"
      tool: "Bash (read-only)"
      check: |
        Scan both memory paths for file mtime:
          ~/.claude/projects/{slug}/memory/MEMORY.md (auto-memory; main session-owned)
          .claude/agent-memory/{plan-reviewer,code-reviewer,code-researcher}/MEMORY.md
        Count files where mtime > 30 days ago. Track oldest age in days.
      mode_env: "CLAUDE_MEMORY_FRESHNESS_MODE (off|warn|strict, default warn)"
      behavior:
        - if: "Mode is off"
          then: "PROCEED silently"
        - if: "Stale count == 0 (no files >30 days)"
          then: "PROCEED silently"
        - if: "Stale count >= 1 AND mode is warn"
          then: "[workflow] WARN: memory N file(s) stale/expired (oldest: NNNN days)"
        - if: "Stale count >= 1 AND mode is strict AND complexity >= M"
          then: "BLOCK; emit FATAL message [workflow] WARN: memory N file(s) stale/expired (oldest: NNNN days) and exit 2"
        - if: "Memory dirs missing entirely (fresh clone — never bootstrapped)"
          then: "PROCEED silently (treat as not-yet-bootstrapped, not stale)"
      exit_on_strict: 2
      probe_for_acceptance: |
        Falsifiable predicate: Touch a file's mtime to >60 days ago, run
        /workflow with default mode, observe exactly one stderr WARN line
        matching the template above.
      purpose: |
        Surfaces the silent staleness that auto-memory and subagent memory can
        accumulate. Default warn-only is non-blocking; opt-in strict is for
        environments where stale memory must be cleared before XL runs proceed.
        Mirrors the step 0.05 PROJECT-KNOWLEDGE.md pre-flight pattern.

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

    - step: 0.2
      action: "Route through /designer (L/XL only)"
      condition: "complexity L or XL"
      skip_when: "S/M complexity — designer adds overhead for simple tasks"
      optional_when: "M complexity AND task_type is new_feature or integration — ask user"
      note: "For M tasks of type new_feature/integration, ask user: 'This task may benefit from a design phase. Run /designer first?'"

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
        - "Phase 0.7: Design → /designer (pending — or skip if S/M)"
        - "Phase 1: Planning (pending)"
        - "Phase 2: Plan Review → plan-reviewer agent (pending — or skip if S-complexity)"
        - "Phase 3: Implementation (pending)"
        - "Phase 4: Code Review → code-reviewer agent (pending)"
        - "Phase 5: Completion — commit + metrics (pending)"

    - step: 2
      action: "Check session recovery"
      checks:
        - "Does `.claude/prompts/{feature}.md` exist? → can skip Phase 1"

    - step: 3
      action: "CronCreate — auto-save checkpoint (L/XL only)"
      condition: "complexity L or XL"
      skip_when: "S/M complexity — phases complete quickly, phase-end checkpoints are sufficient"
      tool: "CronCreate"
      schedule: "*/10 * * * *"
      prompt: |
        Write incremental checkpoint to .claude/workflow-state/{feature}-checkpoint.yaml.
        Include: current phase, sub-phase, implementation_progress (parts completed/total),
        iteration counters, timestamp. This is a periodic auto-save — do NOT change workflow state.
      cleanup: "CronDelete at Phase 5 completion (SEE orchestration-core.md)"
      fallback: "If CronCreate unavailable → WARN, proceed without auto-save. Phase-end checkpoints still active."
      note: "Cron scheduling (v2.1.71). Auto-save complements phase-end checkpoints — provides mid-phase recovery for XL tasks where a single phase may take 30+ minutes."

## PIPELINE
pipeline:
  mandatory: |
    🔴 MANDATORY: Load skills BEFORE executing any phase:
    - Workflow: workflow-protocols skill (step 0.1) — includes autonomy, orchestration-core
    - Planner: planner-rules skill (step 0) — includes mcp-tools, sequential-thinking-guide
    - Coder: coder-rules skill (step 0) — includes mcp-tools
    NOTE: Plan Review and Code Review → agents/ with skills preloading (plan-review-rules, code-review-rules)
    NOTE: Language profile + error handling → auto-loaded via CLAUDE.md

  flow: "task-analysis → /designer* → /planner [→ code-researcher*] → plan-reviewer (agent) → /coder [→ code-researcher*] → code-reviewer (agent)"
  flow_note: "* /designer is Phase 0.7, activated for L/XL tasks only. S/M skip to /planner. code-researcher is optional tool-assist."

  evaluate_note: |
    /coder runs internal EVALUATE sub-phase (Phase 1.5) before implementing.
    Outcomes:
      PROCEED: plan is implementable → start implementation
      REVISE: minor gaps, inline fixes → proceed with adjustments noted
      RETURN: major gaps → re-route to Phase 1 (counts toward plan_review iteration counter)
    On RETURN: orchestrator increments plan_review counter, writes checkpoint.
    If spec exists (L/XL path): re-run /planner with coder feedback + original spec.
    If no spec (S/M path): re-run /planner with coder feedback only.

  simplify_note: |
    /coder runs optional SIMPLIFY sub-phase (Phase 2.5) between IMPLEMENT and VERIFY.
    Condition: complexity L/XL AND total_parts >= 5.
    Runs /simplify (= /code-review --fix on Claude Code v2.1.152+) on changed files to apply
    low-risk reuse/simplification/efficiency (and minor correctness) fixes before code-review;
    skips gracefully (simplify_applied: skipped) if /simplify is unavailable (v2.1.147–2.1.151).
    Guard: if simplify changes > 30% of lines touched → revert, proceed with original code.

  load_phases:
    - action: "Read .claude/skills/workflow-protocols/autonomy.md"
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

## DELEGATION PROTOCOL
delegation_protocol:
  purpose: "How workflow delegates review phases to native agents/"
  mechanism: "Claude auto-delegates based on agent description. Orchestrator forms delegation prompt with handoff context."
  isolation_guarantee: "Agents run in clean context. CLAUDE.md auto-loaded from project root. Parent conversation history is NOT passed."
  reference: "SEE: pipeline.flow for quick route overview"

  designer_delegation:
    command: "/designer"
    when: "Phase 0.7 — after task analysis, before /planner"
    skip_when: "S/M complexity (direct to /planner)"
    optional_when: "M complexity AND task_type in [new_feature, integration] — ask user"
    context_to_pass:
      - "Task description"
      - "Complexity: L/XL"
      - "Task type: {type}"
    returns: "Approved spec file + handoff payload for /planner"
    post_delegation: |
      After /designer completion:
      1. Verify spec file exists at .claude/prompts/{feature}-spec.md
      2. Verify status: approved in spec frontmatter
      3. Write checkpoint: phase_completed=0.7, phase_name="design"
      4. Pass designer handoff to /planner as additional input

  load_trigger: |
    MANDATORY: BEFORE delegating to plan-reviewer (Phase 2) OR code-reviewer (Phase 4):
    Read .claude/skills/workflow-protocols/delegation-templates.md if not already in context.
    File contains: delegation_prompt_template, pre_delegation (STEP -1/0/0.5/IMP-03),
    planner_reinvocation_on_iter2plus, post_delegation (steps 1..7 incl. IMP-04 KD-4)
    for both plan-review and code-review agents.
    Re-read on loop iterations (NEEDS_CHANGES / CHANGES_REQUESTED).
    MANDATORY: Skipping this Read will bypass IMP-01 handoff validation and IMP-04
    diff-manifest — both required for iteration 2+ correctness.

  plan_review_delegation:
    agent: "plan-reviewer"
    when: "Phase 2 — after /planner completion"
    skip_when: "S-complexity route"
    reference: "SEE .claude/skills/workflow-protocols/delegation-templates.md § plan_review_delegation"

  code_review_delegation:
    agent: "code-reviewer"
    when: "Phase 4 — after /coder completion"
    isolation: "worktree — agent sees only committed changes. Ensure git commit before delegating."
    optimization: "Pass verify_status in handoff to allow code-reviewer to skip QUICK CHECK re-run. Worktree sparsePaths controlled by settings.json (v2.1.76)."
    reference: "SEE .claude/skills/workflow-protocols/delegation-templates.md § code_review_delegation"

  fallback: "If agent delegation unavailable → fallback: re-read diff/plan in parent context (degraded mode, loss of isolation)"

  output_validation:
    purpose: "Verify agent returned a usable verdict before proceeding"
    when_to_load: "ONLY on INCOMPLETE verdict (missing/malformed VERDICT line after review agent completes)"
    reference: "Read .claude/skills/workflow-protocols/incomplete-output-recovery.md — contains checks, on_incomplete_output step_0..step_5 fallback chain (IMP-02 structured JSON primary → regex → direct transcript → verdict-recovery → manual), common_causes."
    degraded_fallback: "If file missing → extract VERDICT: regex from agent output directly (minimal recovery, IMP-02 structured JSON path skipped)"

  code_researcher_usage:
    agent: "code-researcher"
    mechanism: "Agent tool (run_in_background supported) or Task tool — code-researcher is tool-assist, not pipeline phase"
    invoked_by: "planner (Phase 3) and coder (Phase 1.5) — NOT by orchestrator"
    when: "Multi-package codebase research needed, complexity L/XL"
    skip_when: "S/M complexity, --minimal planner mode"
    returns: "Structured summary ≤2000 tokens (patterns, files, imports, key snippets)"
    background_mode:
      when: "L/XL complexity in planner Phase 3 — large research scope"
      mechanism: "Agent tool with run_in_background: true"
      benefit: "Planner proceeds to DESIGN with direct research findings while code-researcher runs in parallel"
      integration: "Results checked at async_integration_point in planner DESIGN phase"
      revision: "If late findings contradict design decisions → inline revision (≤1 part) or re-evaluate (>1 part)"
      reference: "SEE planner.md complex_search.background_mode + phase_4_design.async_integration_point"
    checkpoint_impact: "None — research is part of Phase 1/3, not a separate phase"
    hook_impact: "None — SubagentStop does NOT fire for Task/Agent tool subagents"
    note: "Differs from plan-reviewer/code-reviewer: those are pipeline-phase agents invoked by orchestrator via native delegation. code-researcher is a tool-agent invoked by sub-commands via Agent/Task tool."

## RULES
rules:
  - "Sequential execution — phases sequentially, not in parallel"
  - "No skip phases (except Phase 2 for S-complexity)"
  - "Context isolation — review via agents/ (clean context, handoff via delegation)"
  - "Loop limits → SEE orchestration-core.md (max 3 iterations per cycle)"

## ERROR HANDLING
error_handling:
  common: "SEE CLAUDE.md (MCP unavailable, tests 3x fail)"
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
    - "handoff (common path) → handoff-contracts.md (5 contracts, lightweight); IMP-02/03/04 details → handoff-protocol.md"

## HOOKS
hooks:
  note: |
    Configured in .claude/settings.json (authoritative source — 12 event types, 18 scripts + 2 prompt hooks).
    This section lists only workflow-specific hooks. For complete list see settings.json.
    Deterministic — fires automatically, no need to remember.
    Conditional `if` (v2.1.85): PreToolUse/PostToolUse hooks use `if` field with permission rule
    syntax to reduce process spawning. Security hooks (protect-files, block-dangerous) remain unconditional.

  workflow_specific:
    - event: PreCompact
      script: ".claude/scripts/save-progress-before-compact.sh"
      behavior: "Saves checkpoint + review completions to additionalContext before compaction"
      blocking: false

    - event: PostCompact
      script: ".claude/scripts/verify-state-after-compact.sh"
      behavior: "Verifies checkpoint + review completions integrity, re-injects state summary"
      blocking: false

    - event: SubagentStart
      script: ".claude/scripts/track-task-lifecycle.sh"
      matcher: "code-researcher"
      behavior: "Logs code-researcher invocation to .claude/workflow-state/task-events.jsonl for pipeline metrics"
      blocking: false

    - event: SubagentStart
      script: ".claude/scripts/inject-review-context.sh <agent-type>"
      matcher: "plan-reviewer (arg: plan-reviewer), code-reviewer (arg: code-reviewer)"
      behavior: "Injects workflow context (feature, complexity, iteration, prior issues, plan/spec paths) as additionalContext for review agents"
      blocking: false
      note: "Split into two separate matcher entries in settings.json to pass agent type as $1"

    - event: SubagentStop
      script: ".claude/scripts/save-review-checkpoint.sh"
      matcher: "plan-reviewer|code-reviewer"
      behavior: "Appends review completion marker to .claude/workflow-state/review-completions.jsonl"
      blocking: true

    - event: PostToolUse
      script: ".claude/scripts/validate-handoff.sh"
      if: "Write(.claude/workflow-state/*-handoff.json) | Edit(.claude/workflow-state/*-handoff.json)"
      behavior: "Validates handoff JSON against .claude/schemas/handoff.schema.json (IMP-01). Non-blocking by default; set CLAUDE_HANDOFF_VALIDATION_MODE=strict to block on failure."
      blocking: false

    - event: WorktreeCreate
      script: ".claude/scripts/prepare-worktree.sh"
      behavior: "Prepares worktree environment (env vars, Go deps, analytics logging)"
      blocking: false

    - event: Stop
      script: ".claude/scripts/check-uncommitted.sh"
      behavior: "Blocks stop if uncommitted changes exist"
      blocking: true

  also_active_during_workflow:
    - "InstructionsLoaded → validate-instructions.sh (rules validation)"
    - "UserPromptSubmit → enrich-context.sh (context enrichment + exploration budget visualization)"
    - "PreToolUse → protect-files.sh, check-artifact-size.sh [if: Write(.claude/**)], import-matrix prompt hook [if: internal/**/*.go], block-dangerous-commands.sh, pre-commit-build.sh [if: Bash(git commit*)]"
    - "PostToolUse → auto-fmt.sh [matcher: Write|Edit; slot-driven via FMT_CMD/LANG_EXT], yaml-lint.sh [if: Edit(.claude/**)], check-references.sh [if: Write(.claude/**)], check-plan-drift.sh [if: .claude/**]"
    - "SessionEnd → session-analytics.sh"
    - "StopFailure → log-stop-failure.sh (API error logging)"
    - "Notification → notify-user.sh"
    - "ConfigChange → audit-config-change.sh (audit log + blocks project_settings changes during active workflow)"
