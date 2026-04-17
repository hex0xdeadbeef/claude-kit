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
    Runs /simplify on changed files to eliminate NIT/MINOR issues before code-review.
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

  plan_review_delegation:
    agent: "plan-reviewer"
    when: "Phase 2 — after /planner completion"
    skip_when: "S-complexity route"
    context_to_pass:
      - "Artifact path: .claude/prompts/{feature}.md"
      - "Planner handoff narrative (SEE: handoff_protocol)"
      - "Complexity: S/M/L/XL"
      - "Iteration: N/3"
      - "Prior iteration issues: checkpoint.issues_history[] (if iteration > 1)"
    delegation_prompt_template: |
      Review the implementation plan at .claude/prompts/{feature}.md

      [Context from planner]:
      - Planner completed: {task type and complexity}
      - Key decisions: {list from handoff.key_decisions}
      - Known risks: {list from handoff.known_risks}
      - Recommendations: focus on {handoff.areas_needing_attention}

      {if iteration > 1}
      [Prior review iterations]:
      {for each entry in checkpoint.issues_history where phase == 2}
      - Iteration {entry.iteration}/3: {entry.verdict}
        Issues: {entry.issues as comma-separated list}
        {if entry.resolved is not empty}Addressed: {entry.resolved as comma-separated list}{/if}
      {/for}
      Focus: verify prior issues were addressed, check for regressions
      {/if}

      Iteration: {N}/3
    returns: "Verdict (APPROVED/NEEDS_CHANGES/REJECTED) + issues + handoff for coder"
    pre_delegation: |
      STEP 0 (IMP-01): Write planner handoff to .claude/workflow-state/{feature}-handoff.json
      before delegating to plan-reviewer. Hook auto-validates on write.
      Format (must match .claude/schemas/handoff.schema.json, contract planner_to_plan_review):
        {
          "$handoff_contract": "planner_to_plan_review",
          "artifact": ".claude/prompts/{feature}.md",
          "metadata": {
            "task_type": "{task_type}",
            "complexity": "{S|M|L|XL}",
            "sequential_thinking_used": true|false,
            "alternatives_considered": N,
            "spec_referenced": true|false,
            "spec_artifact": "{path or null}"
          },
          "key_decisions": ["{decision + rationale}", ...],
          "known_risks": ["{risk}", ...],
          "areas_needing_attention": ["{Part N: reason}", ...]
        }

      STEP 0.5 (IMP-04 — iteration 2+ only): Build diff manifest for planner.
      This step runs ONLY on iteration >= 2. Skip on iter 1.

      1. Read .claude/workflow-state/review-completions.jsonl — find the most recent
         entry where effective_agent_type == "plan-reviewer" in this session_id.
         Extract canonical_issue_ids[] → prior_issues.
         Read regression_ids from the prior phase-2 entry in
         checkpoint.issues_history[] (populated by IMP-03 post_delegation step 5 —
         this is the canonical source for regression signal, NOT review-completions.jsonl
         directly).

      2. Read prior plan at .claude/prompts/{feature}.md. Extract Part IDs and names
         from "## Part N:" headings or "parts:" YAML block. Build:
            prior_parts = [{id: 1, name: "..."}, {id: 2, name: "..."}, ...]

      3. Location → Part mapping (AC-5):
         For each issue in prior_issues:
           location = issue.location  (string, may be "", "Part N:", "Part N: Sym", or "file:line")
           match = re.match(r'^Part\s+(\d+)\s*:', location)
           if match:
             part_id = int(match.group(1))
             mapped[issue.id] = part_id
           else:
             # KD-6 fallback (AC-10): unmappable location → all Parts NEEDS_UPDATE
             mapped[issue.id] = "ALL"

             # Telemetry signal split (CR-002): distinguish two failure modes
             #   - empty string: legitimate cross-cutting concern (informational, reviewer-correct)
             #   - non-empty but no match: KD-8 non-compliance (actionable, reviewer-bug)
             if location == "":
               record_kind = "imp04_cross_cutting_issue"
               reason_txt = "empty location — plan-wide/cross-cutting concern (informational)"
             else:
               record_kind = "imp04_unmapped_location"
               reason_txt = "location does not match 'Part N:' prefix (IMP-03 KD-8 format)"

             log_record = {
               "ts": now_iso(),
               "record_kind": record_kind,
               "feature": "{feature}",
               "iteration": N,
               "issue_id": issue.id,
               "location": location,
               "reason": reason_txt
             }
             append_jsonl(".claude/workflow-state/handoff-validation.jsonl", log_record)

      4. IMP-03 integration (AC-9):
         prior_canonical_ids = {issue.id for issue in prior_issues}
         regression_ids from prior phase-2 issues_history entry (already computed by
         IMP-03 post_delegation step 5 — do NOT recompute here).

         For each prior_part in prior_parts:
           # issues_on_part is drawn from `mapped`, which is built exclusively from
           # prior_issues — every id here is by construction in prior_canonical_ids,
           # so no secondary filter is needed (CR-003).
           active_issues_on_part = [id for id, p in mapped.items() if p == prior_part.id or p == "ALL"]
           regressed_on_part = [id for id in active_issues_on_part if id in regression_ids]

           if regressed_on_part:
             status = "NEEDS_UPDATE"
             reason = f"regression: {','.join(regressed_on_part)}"
           elif active_issues_on_part:
             status = "NEEDS_UPDATE"
             reason = f"active issues: {','.join(active_issues_on_part)}"
           else:
             status = "UNCHANGED"
             reason = "no active issues"

           diff_manifest.append({"part_id": prior_part.id, "name": prior_part.name,
                                 "status": status, "reason": reason})

         If ANY issue has mapped[id] == "ALL" (KD-6 fallback triggered):
           For each entry in diff_manifest where status == "UNCHANGED":
             entry.status = "NEEDS_UPDATE"
             entry.reason = "KD-6 fallback: unmappable location forces all Parts to NEEDS_UPDATE"

      5. Write manifest to .claude/workflow-state/{feature}-diff-manifest.json —
         runtime artifact, regenerated every iter 2+, not checked in.

      6. Inject manifest reference into the /planner re-invocation prompt
         (see planner_reinvocation_on_iter2plus below).

      Before delegating to plan-reviewer (iteration 2+ only):
      1. Read .claude/workflow-state/review-completions.jsonl for the most recent entry
         where effective_agent_type == "plan-reviewer" in this session_id.
         Extract its canonical_issue_ids[].id list → prior_canonical_ids
      2. Set-diff logic (IMP-03):
         a. current_canonical_ids = (will be populated AFTER this iteration's review —
            left empty in pre-delegation)
         b. resolved_ids = ids present in iter N-1's canonical_issue_ids BUT absent in
            iter N's canonical_issue_ids — populated post-delegation (see step 3 below)
         c. regression_ids = current ∩ union(resolved_ids from ALL prior entries) —
            populated post-delegation
      3. Backward compat (KD-3): populate resolved[] (human-readable, existing field)
         alongside resolved_ids[] (canonical IDs, new field):
         - resolved[] entries: "{canonical_id}: inferred from set-diff (prior iter N-1)"
         - resolved_ids[] entries: raw canonical-ID strings
      4. Write updated checkpoint before delegation
    planner_reinvocation_on_iter2plus: |
      IMP-04 — when orchestrator re-routes to Phase 1 (Planning) after a NEEDS_CHANGES
      verdict, the re-invocation of /planner includes the manifest reference. Concrete
      prompt fragment appended after the standard coder/reviewer feedback block:

        ---
        [IMP-04 — iter {N} diff manifest]
        Prior plan: .claude/prompts/{feature}.md (read for Part bodies)
        Manifest:   .claude/workflow-state/{feature}-diff-manifest.json
        Action:     Execute phase_0.8_prior_review_digest before phase_1_understand.
                    Preserve UNCHANGED Part bodies verbatim.
                    Address NEEDS_UPDATE Parts using issues in manifest.reason.
                    Add NEW Parts via Part-name set-diff (phase_0.8 Step 3).
        ---

      If manifest file missing (first iter 2+ run before STEP 0.5 executed, or KD-6
      triggered with empty mapping) → planner skips phase_0.8, writes plan without
      diff section → plan-reviewer runs full validation (AC-8 path).
    post_delegation: |
      After receiving plan-reviewer output:
      1. Validate output (SEE output_validation)
      2. Extract verdict from VERDICT: header (first line)

      2.5 (IMP-04 — KD-4 contract-break routing): Scan issues for BLOCKER whose
          problem text starts with the exact literal prefix:
            "IMP-04 contract break: Part "

          If found:
            a. Write checkpoint: phase_completed=2, verdict=CHANGES_REQUESTED,
               imp04_contract_break=true (do NOT increment plan_review counter —
               re-plan is a routing step, not a new review iteration).
            b. Log event to .claude/workflow-state/handoff-validation.jsonl:
               {record_kind: "imp04_contract_break_reroute", feature, iteration,
                issue_id, message}
            c. Delete .claude/workflow-state/{feature}-diff-manifest.json so the
               next /planner invocation sees no manifest and writes an iter-1-style
               plan (full re-plan).
            d. Re-route to Phase 1 (/planner) with FULL RE-PLAN instruction.
               Do NOT proceed to standard verdict routing — contract break supersedes.

      3. Read canonical_issue_ids from latest .claude/workflow-state/review-completions.jsonl
         entry (written by save-review-checkpoint.sh via IMP-03 normalization).
         Extract the canonical-ID list: current_canonical_ids = [c.id for c in canonical_issue_ids]
      4. Compute set-diff (iteration 2+ only):
         - Find prior phase-2 issues_history entry → prior_canonical_ids
         - resolved_ids = prior_canonical_ids - current_canonical_ids   (set diff)
         - regression_ids = current_canonical_ids ∩ union(prior.resolved_ids for all prior entries)
      5. Append to checkpoint.issues_history:
           {
             phase: 2,
             iteration: N,
             verdict: {verdict},
             issues: [extracted issues],             # legacy free-form, unchanged
             resolved: [],                           # human-readable, populated on NEXT iter's pre-delegation
             canonical_issue_ids: current_canonical_ids,
             resolved_ids: resolved_ids,             # auto set-diff (IMP-03)
             regression_ids: regression_ids,         # auto intersection (IMP-03)
           }
      6. Write checkpoint: phase_completed=2, verdict={extracted_verdict}
      6.5 (IMP-01): Write reviewer handoff to .claude/workflow-state/{feature}-handoff.json
          Hook auto-validates on write. Format (contract plan_review_to_coder):
            {
              "$handoff_contract": "plan_review_to_coder",
              "artifact": ".claude/prompts/{feature}.md",
              "verdict": "{APPROVED|NEEDS_CHANGES|REJECTED}",
              "issues_summary": {"blocker": N, "major": N, "minor": N},
              "approved_with_notes": ["{note}", ...],
              "iteration": "{N}/3"
            }
      7. If verdict is INCOMPLETE → follow output_validation.on_incomplete_output

  code_review_delegation:
    agent: "code-reviewer"
    when: "Phase 4 — after /coder completion"
    isolation: "worktree — agent sees only committed changes. Ensure git commit before delegating."
    optimization: "Pass verify_status in handoff to allow code-reviewer to skip QUICK CHECK re-run (see FIX-1). Worktree checkout scope controlled by worktree.sparsePaths in settings.json (v2.1.76) — reduces creation time and disk usage in monorepos."
    context_to_pass:
      - "Branch: current branch (code-reviewer runs git diff internally in worktree)"
      - "Coder handoff narrative (SEE: handoff_protocol)"
      - "Complexity: S/M/L/XL"
      - "Iteration: N/3"
      - "Verify status: lint PASS/FAIL, test PASS/FAIL (from coder VERIFY phase)"
      - "Spec check result: status, coverage, issues (from coder Phase 3.5)"
      - "Prior iteration issues: checkpoint.issues_history[] (if iteration > 1)"
      - "Design spec: path + acceptance criteria count (if complexity L/XL and spec exists)"
    delegation_prompt_template: |
      Review code changes on the current branch.

      [Context from coder]:
      - Coder implemented: {N Parts per plan}
      - Evaluate adjustments: {list from handoff.evaluate_adjustments}
      - Deviations from plan: {list from handoff.deviations_from_plan}
      - Mitigated risks: {list from handoff.risks_mitigated}
      - Verify: lint {PASS/FAIL}, test {PASS/FAIL} (command: {verify_command})
      - Spec check: {PASS|PARTIAL|FAIL} (coverage: {pct}%, issues: {N})

      {if complexity in [L, XL] and spec file exists}
      [Design context]:
      - Spec: .claude/prompts/{feature}-spec.md (read for acceptance criteria and design decisions)
      - Acceptance criteria: {N from spec}
      - Note: verify implementation covers spec requirements, especially acceptance criteria
      {/if}

      {if iteration > 1}
      [Prior review iterations]:
      {for each entry in checkpoint.issues_history where phase == 4}
      - Iteration {entry.iteration}/3: {entry.verdict}
        Issues: {entry.issues as comma-separated list}
        {if entry.resolved is not empty}Addressed: {entry.resolved as comma-separated list}{/if}
      {/for}
      Focus: verify prior issues were addressed, check for regressions
      {/if}

      Iteration: {N}/3
    returns: "Verdict (APPROVED/APPROVED_WITH_COMMENTS/CHANGES_REQUESTED) + issues + handoff for completion"
    pre_delegation: |
      Before delegating to code-reviewer (iteration 2+ only):
      1. Read .claude/workflow-state/review-completions.jsonl for the most recent entry
         where effective_agent_type == "code-reviewer" in this session_id.
         Extract its canonical_issue_ids[].id list → prior_canonical_ids
      2. Same set-diff logic as plan_review_delegation.pre_delegation (IMP-03):
         resolved_ids / regression_ids populated post-delegation.
      3. Backward compat (KD-3): populate resolved[] (human-readable) alongside
         resolved_ids[] (canonical). See plan_review_delegation for format.
      4. Write updated checkpoint before delegation
    post_delegation: |
      After receiving code-reviewer output:
      1. Validate output (SEE output_validation)
      2. Extract verdict from VERDICT: header (first line)
      3. Read canonical_issue_ids from latest .claude/workflow-state/review-completions.jsonl
         entry for code-reviewer in this session.
         current_canonical_ids = [c.id for c in canonical_issue_ids]
      4. Compute set-diff (iteration 2+ only) — same logic as plan_review:
         - resolved_ids = prior - current
         - regression_ids = current ∩ union(prior.resolved_ids for all phase-4 prior entries)
      5. Append to checkpoint.issues_history:
           {
             phase: 4,
             iteration: N,
             verdict: {verdict},
             issues: [extracted issues],
             resolved: [],
             canonical_issue_ids: current_canonical_ids,
             resolved_ids: resolved_ids,
             regression_ids: regression_ids,
           }
      6. Write checkpoint: phase_completed=4, verdict={extracted_verdict}
      7. If verdict is INCOMPLETE → follow output_validation.on_incomplete_output

  fallback: "If agent delegation unavailable → fallback: re-read diff/plan in parent context (degraded mode, loss of isolation)"

  output_validation:
    purpose: "Verify agent returned a usable verdict before proceeding"
    when: "Immediately after receiving agent return (plan-reviewer or code-reviewer)"
    severity: CRITICAL
    checks:
      - check: "First line should be VERDICT: followed by one of the verdict values"
        look_for: "VERDICT: (case-insensitive) followed by APPROVED_WITH_COMMENTS, APPROVED, CHANGES_REQUESTED, NEEDS_CHANGES, or REJECTED"
        on_missing: "INCOMPLETE_OUTPUT"
      - check: "Return text contains handoff section"
        pattern: "Handoff"
        on_missing: "INCOMPLETE_OUTPUT — proceed with verdict only if found"

    on_incomplete_output:
      step_0: "IMP-02 structured JSON path — check .claude/workflow-state/review-completions.jsonl for the latest entry. If verdict_source == \"structured_json\", the hook already parsed a VERDICT_JSON fenced block from the agent transcript and validated it against .claude/schemas/handoff.schema.json. Use the verdict + issues + handoff from the marker file directly — zero regex ambiguity, no fallback needed. Proceed to verdict routing immediately."
      step_1: "Check .claude/workflow-state/review-completions.jsonl — save-review-checkpoint.sh extracts verdict via regex on SubagentStop. If verdict found → use it, proceed with minimal handoff (verdict only, no detailed issues)."
      step_2: "If verdict found in review-completions.jsonl → extract it, proceed normally with minimal handoff"
      step_3: "P3-1 direct transcript read — if no verdict in review-completions.jsonl, orchestrator reads agent transcript JSONL directly (agent_transcript_path from review-completions entry or worktree-events-debug.jsonl). Reverse-search role:assistant messages for VERDICT: regex. Defense-in-depth — orchestrator is self-reliant, not solely dependent on hook infrastructure."
      step_4: "If still no verdict → launch verdict-recovery agent (NOT full code-reviewer). verdict-recovery is a lightweight agent (maxTurns: 10, haiku, no memory, no skills, no TodoWrite) that reads the diff and outputs ONLY a verdict + brief handoff. See .claude/agents/verdict-recovery.md."
      step_5: "If verdict-recovery also fails or returns no verdict → WARN user, show what information is available (review-completions.jsonl, agent output summary), ask for manual verdict decision"
      max_retries: 1
      note: "step_0 (IMP-02) is the preferred primary path: structured JSON eliminates regex false-positives and enables schema-validated handoff propagation. steps 1–5 remain as the defense-in-depth fallback chain for agents that emit malformed JSON or skip the VERDICT_JSON block entirely. step_1 leverages save-review-checkpoint.sh which already runs on SubagentStop and extracts verdict via regex as fallback. step_3 (P3-1) makes orchestrator independent of hook success — reads transcript directly. step_4 uses verdict-recovery agent instead of re-launching full code-reviewer — ~30s vs ~5min."

    common_causes:
      - "Agent exhausted maxTurns on memory operations (SEE RULE_5 in agent artifacts)"
      - "Agent got stuck in a long Sequential Thinking chain"
      - "Agent produced output but in unexpected format"

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
    - "handoff → handoff-protocol.md (4 contracts, narrative casting)"

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
    - "PostToolUse → auto-fmt-go.sh [if: **/*.go], yaml-lint.sh [if: Edit(.claude/**)], check-references.sh [if: Write(.claude/**)], check-plan-drift.sh [if: .claude/**]"
    - "SessionEnd → session-analytics.sh"
    - "StopFailure → log-stop-failure.sh (API error logging)"
    - "Notification → notify-user.sh"
    - "ConfigChange → audit-config-change.sh (audit log + blocks project_settings changes during active workflow)"
