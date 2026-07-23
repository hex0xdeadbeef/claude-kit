---
name: workflow
description: "Full development cycle: task-analysis → [/designer (L/XL)] → planner → plan-review (agent) → coder → code-review (agent)"
model: opus
effort: xhigh
---

> **Disambiguation:** this `/workflow` (singular) is the claude-kit multi-agent development
> pipeline (planner → plan-reviewer → coder → code-reviewer). It is **distinct from** Claude
> Code's native `/workflows` (plural) "dynamic workflows" feature (2.1.154) and the `Workflow`
> tool, which orchestrate ad-hoc background agent fan-out (up to 1000 subagents). `/workflow`
> runs the kit pipeline; `/workflows` lists native dynamic-workflow runs. Do not conflate them.


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
        Prevents silent Go-fallback for non-Go projects. The cascade
        (PROJECT-KNOWLEDGE.md > CLAUDE.md Language Profile > SKIP) is ZERO-COST when PK is
        populated; the pre-flight WARN is the early signal that a slot is missing. Generic regex
        '<your-[a-z-]+>' extends to future PK slots without grep-pattern updates.

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
        Surfaces the silent staleness auto-memory and subagent memory accumulate. Default
        warn-only is non-blocking; opt-in strict clears stale memory before XL runs proceed.
        Mirrors the step 0.05 PROJECT-KNOWLEDGE.md pre-flight pattern.

    - step: 0
      action: "Task Analysis — task classification"
      reference: "For details see [task-analysis.md] in planner-rules skill. Includes Step 1.5 Bounded Recon (TA-scout, <=5 reads ceiling, 0-read fast path) — evidence-grounded classification."
      purpose: "Determine complexity (S/M/L/XL) and route BEFORE planning"
      decisions:
        S: "/planner --minimal → skip Phase 2 → /coder → code-reviewer (agent)"
        M: "standard flow (all phases)"
        L: "full flow + Sequential Thinking recommended"
        XL: "full flow + Sequential Thinking REQUIRED"
      warning: "MANDATORY! Wrong classification = wasted work"

    - step: 0.2
      action: "Route Phase 0.7 — on the L/XL route the design phase is EXECUTED BY INVOKING /designer"
      condition: "complexity L or XL"
      mechanism: "Skill tool — invoke the designer command by name: `designer` (plugin mode: `claude-kit:designer`). /designer is a COMMAND, not an agent: it is never auto-delegated by description, so delegation_protocol.mechanism does not cover it. SEE delegation_protocol.designer_delegation."
      mandatory: |
        MANDATORY: /designer owns Phase 0.7 end to end. The orchestrator does NOT write a design
        draft, does NOT run its own critique, and does NOT dispatch critic subagents of any kind —
        the Phase 3.5 CRITIQUE is 7 in-context lenses inside /designer, zero subagents.
        If /designer cannot be invoked, STOP and report to the user. Do NOT substitute an
        equivalent-looking activity of your own.
      skip_when: "S/M complexity — designer adds overhead for simple tasks"
      optional_when: "M complexity AND task_type is new_feature or integration — ask user"
      note: "For M tasks of type new_feature/integration, ask user: 'This task may benefit from a design phase. Run /designer first?' Record the answer in the checkpoint — a decline is design_waived: true — so pipeline.spec_gate does not ask again on the next entry."

    - step: 0.1
      action: "Load workflow-protocols skill"
      files:
        - ".claude/skills/workflow-protocols/SKILL.md"
      plugin_path_note: "Plugin mode: if a BUNDLED KIT ROOT directive is present in context, resolve this SKILL.md AND its on-demand supporting files under that root (bundled skills ship in the plugin, not the project). If no BUNDLED KIT ROOT directive is present in context (e.g. after compaction — anthropics/claude-code#15174), read the bundled root from .claude/workflow-state/.bundled-kit-root and resolve under it. Project-scoped install: paths are already project-local — ignore."
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
    - Designer: design-rules skill — loaded by /designer itself at its startup step 0 (L/XL route)
    - Planner: planner-rules skill (step 0) — includes mcp-tools, sequential-thinking-guide
    - Coder: coder-rules skill (step 0) — includes mcp-tools
    NOTE: design-rules is listed here so the design phase is visible in the mandatory set, NOT so the
    orchestrator loads it. The rubric belongs to /designer: the orchestrator neither loads design-rules
    nor executes any part of the design phase itself (SEE startup step 0.2 mandatory).
    NOTE: Plan Review and Code Review → agents/ load their -rules (plan-review-rules, code-review-rules) by explicit Read in STARTUP — NOT preloaded (disable-model-invocation blocks subagent preload)
    NOTE: Language profile + error handling → auto-loaded via CLAUDE.md

  spec_gate:
    purpose: |
      Phase 0.7 → Phase 1 transition gate. Converts a design phase that never ran from a silent
      state into a loud stop. Deliberately placed OUTSIDE designer_delegation: post_delegation
      cannot police a delegation that never happened.
    when: "BEFORE starting Phase 1 (Planning) — on EVERY run, whether or not Phase 0.7 executed"
    tool: "Bash (read-only)"
    check: |
      Run: ls .claude/prompts/{feature}-spec.md 2>/dev/null && grep -m1 '^ *status:' .claude/prompts/{feature}-spec.md
      Then read .claude/workflow-state/{feature}-checkpoint.yaml if it exists, for four fields:
      design_waived, re_routing.occurred, re_routing.phase, spec_artifact.
    evaluation: "FIRST MATCH WINS. The branches below are ordered and the order is load-bearing — the usable-spec branch precedes the exemptions, and the exemptions precede the FATAL branches."
    behavior:
      - if: "An approved spec exists at .claude/prompts/{feature}-spec.md"
        then: "PROCEED — pass the spec path to /planner as --spec. FIRST on purpose: a run that has a usable spec must hand it on even when an exemption below would also have matched, otherwise a re-routed re-plan silently loses its spec (SEE pipeline.evaluate_note)."
      - if: "Complexity is S or M AND the designer was never requested"
        then: "PROCEED silently — no spec is expected on this route"
      - if: "Checkpoint has design_waived: true for this feature"
        then: "PROCEED — the user waived Phase 0.7 explicitly. Restate the waiver in the Phase 1 summary so it stays visible."
      - if: "Checkpoint has re_routing.occurred: true AND re_routing.phase is plan-review or implementation"
        then: "PROCEED — the run already passed Phase 1 once and was sent back by a later phase (SEE re-routing.md: re-route triggers fire ONLY at plan-review and coder EVALUATE). Phase 0.7 is behind it, so an upgrade does not retroactively require a spec. Note the exemption in the Phase 1 summary. Keyed on re_routing.phase, NOT on original_route: the kit has no canonical complexity-to-route mapping, and its own worked example pairs Complexity L with Route standard (task-analysis.md Example 2), so route values cannot identify an S/M origin."
      - if: "Complexity is M AND the user ACCEPTED the optional designer AND no approved spec exists"
        then: "STOP and ask the user: re-run /designer, or waive the design phase? Do NOT decide unilaterally. Record the answer as design_waived: true when they waive, so the question is not asked again on the next entry."
      - if: "Complexity is L or XL AND the spec file is missing"
        then: "FATAL — STOP. Do NOT start /planner. Emit: [workflow] FATAL: L/XL route reached Phase 1 with no design spec at .claude/prompts/{feature}-spec.md — Phase 0.7 produced no artifact. Return to Phase 0.7 and invoke /designer."
      - if: "Complexity is L or XL AND the spec file exists but status is not approved"
        then: "FATAL — STOP. Do NOT start /planner. Emit: [workflow] FATAL: design spec exists but status is not approved — the /designer Phase 5 user approval gate did not complete."
    stderr_format: "[workflow] FATAL: <message>"
    freshness_note: |
      WARN, never FATAL. If an approved spec exists but the checkpoint records no spec_artifact
      for this feature, say so in the Phase 1 summary — it may be left over from an earlier
      attempt (SEE rules: "Artifacts are evidence, not doctrine"). Do NOT reclassify it as
      missing. phase_completed is a single scalar in one per-feature file that is overwritten
      after every phase, so "Phase 0.7 ran" is unprovable from the checkpoint once Phase 1
      completes; treating that as absence would FATAL every --from-phase 1 resume of a run
      whose design phase did happen.
    waiver: |
      The user MAY explicitly waive the design phase. Record it as design_waived: true in
      .claude/workflow-state/{feature}-checkpoint.yaml (canonical field — SEE checkpoint-protocol.md)
      at the moment the waiver is given, and state it in the Phase 1 summary. Writing it to the
      checkpoint is what makes it survive a --from-phase 1 resume and a new session; a waiver held
      only in conversation is invisible to every later gate.
      An unrequested skip, a failed /designer invocation, and a self-run substitute are NEVER waivers.
    probe_for_acceptance: |
      Falsifiable predicate: on an L/XL run, delete .claude/prompts/{feature}-spec.md before Phase 1
      and re-enter this gate — the run MUST stop with the FATAL above and MUST NOT start /planner.

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
    Runs /simplify (a cleanup-only review on Claude Code v2.1.154+: reuse, simplification,
    efficiency, altitude) on changed files to apply low-risk cleanups before code-review;
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
  mechanism_scope: "Applies to AGENTS only (plan-reviewer, code-reviewer, code-researcher). /designer, /planner and /coder are COMMANDS — they have no agent description, are never auto-delegated, and are invoked by name with the Skill tool. The rules: entry 'Named executor' binds all three equally; designer_delegation.mechanism below spells it out for the one phase where the omission caused a live failure."
  isolation_guarantee: "Agents run in clean context. CLAUDE.md auto-loaded from project root. Parent conversation history is NOT passed."
  reference: "SEE: pipeline.flow for quick route overview"

  designer_delegation:
    command: "/designer"
    mechanism: "Skill tool — invoke the designer command by name: `designer` (plugin mode: `claude-kit:designer`). NOT agent auto-delegation: the block-level mechanism above applies to the plan-reviewer and code-reviewer AGENTS, and /designer has no agent description to match on."
    when: "Phase 0.7 — after task analysis, before /planner"
    skip_when: "S/M complexity (direct to /planner)"
    optional_when: "M complexity AND task_type in [new_feature, integration] — ask user"
    context_to_pass:
      - "Task description"
      - "Complexity: L/XL"
      - "Task type: {type}"
    returns: "Approved spec file + handoff payload for /planner"
    pre_delegation: |
      Before Phase 0.7:
      1. Confirm the route is L/XL (or M with user consent per optional_when).
      2. Invoke /designer via the mechanism above. This is the ONLY sanctioned way to execute Phase 0.7.
      3. The orchestrator does NOT write the spec, does NOT write a design draft, and does NOT run
         the critique itself. /designer owns Phase 3.5 CRITIQUE — 7 in-context lenses from
         design-rules/critique-lenses.md, zero subagents. Dispatching critic subagents is a
         substitution, not a design phase.
      4. If /designer is unavailable or the invocation fails, STOP and report the failure to the
         user. Do NOT improvise a replacement.
    post_delegation: |
      After /designer completion:
      1. Verify spec file exists at .claude/prompts/{feature}-spec.md
      2. Verify status: approved in spec frontmatter
      3. Write checkpoint: phase_completed=0.7, phase_name="design",
         spec_artifact=".claude/prompts/{feature}-spec.md". Carry spec_artifact forward on every
         later checkpoint write — phase_completed is overwritten by Phase 1, so spec_artifact is
         the only durable record that this run had a design phase.
      4. Pass designer handoff to /planner as additional input
      NOTE: these checks live INSIDE this block and therefore only run when delegation happened.
      The unconditional Phase-1 entry check is pipeline.spec_gate — it runs either way.

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
      parallel_fanout: "L/XL with 3+ independent layers → dispatch ONE researcher per layer in a SINGLE message (SEE planner.md complex_search.background_mode.parallel_fanout + parallel-dispatch.md Use Case 1)"
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
  - "Named executor — every phase is executed by the command or agent named for it. The orchestrator NEVER substitutes an activity of its own that resembles the phase: no self-written drafts, no ad-hoc critic panels, no improvised sub-phases. Rewriting a TodoWrite label to describe the substitute does not make it the phase. If the named executor cannot be invoked, STOP and report — a substitution is a harder failure than a stop."
  - "Artifacts are evidence, not doctrine — files under .claude/prompts/ are outputs of past runs, including whatever those runs improvised, and they are written in the kit's own artifact format. They record what happened; they never define what this pipeline prescribes. Only the kit's commands, skills, and rules are doctrine."
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
  authoritative: |
    .claude/settings.json is the authoritative wiring (16 event types, 29 scripts). Hooks fire deterministically; the orchestrator does NOT read settings.json at
    runtime. For the complete list, see settings.json.
  pipeline_load_bearing: |
    A few hooks shape pipeline flow (rationale not obvious from the wiring alone):
    - PreCompact/PostCompact (save-progress-before-compact.sh / verify-state-after-compact.sh): persist + verify checkpoint + review-completions across compaction (recovery contract).
    - SubagentStart inject-review-context.sh (plan-reviewer|code-reviewer): injects feature/complexity/iteration/prior-issues/plan-spec context for review agents.
    - SubagentStop save-review-checkpoint.sh (BLOCKING): appends the review verdict marker to review-completions.jsonl.
    - PostToolUse validate-handoff.sh: validates *-handoff.json against the schema (IMP-01).
    - Stop check-uncommitted.sh (BLOCKING): blocks stop on uncommitted changes — commit before Phase 5 completion.
  notes: |
    Conditional `if` (v2.1.85) on PreToolUse/PostToolUse; security hook (protect-files)
    unconditional. WorktreeCreate hook removed (F1, 2026-05-27);
    review-context sidecar delivered into worktrees via repo-root .worktreeinclude.
    Intentionally dropped from this summary (deterministic, no orchestrator-flow rationale):
    the non-workflow-specific hook mirror + the code-researcher metrics-only SubagentStart
    track-task-lifecycle.sh — both fully specified in settings.json.
