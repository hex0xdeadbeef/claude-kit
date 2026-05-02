---
name: delegation-templates
description: "Full delegation templates for /workflow pipeline. Load ONLY before Phase 2 (plan-review) or Phase 4 (code-review) delegation via explicit directive in workflow.md delegation_protocol.load_trigger. Contains: delegation_prompt_template, pre_delegation (STEP -1/0/0.5/IMP-03), planner_reinvocation_on_iter2plus, post_delegation (steps 1..7 incl. IMP-04 KD-4 contract-break routing) for both plan-review and code-review agents. IMP-01/02/03/04 implementation details live here — not in workflow.md."
disable-model-invocation: true
---

# Delegation Templates

## When to load

MANDATORY: Read this file immediately before Phase 2 (plan-reviewer delegation) or
Phase 4 (code-reviewer delegation). Re-read on loop iterations (NEEDS_CHANGES /
CHANGES_REQUESTED verdict brings orchestrator back to Phase 1 or 3; next delegation
re-enters this file). File is NOT auto-loaded at workflow startup — on-demand only.

MANDATORY: Skipping this Read will bypass IMP-01 handoff validation and IMP-04
diff-manifest — both required for iteration 2+ correctness.

## plan_review_delegation

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
    STEP MODE (delta-review-mode — KD-3, R-3):
    Write delta_review_mode to checkpoint once per pipeline run (idempotent).
    Read CLAUDE_DELTA_REVIEW_MODE env (default "off" if unset).
    If checkpoint already has delta_review_mode field with a non-empty value → SKIP (preserve first-write value).
    Purpose: inject-review-context.sh prefers checkpoint value over live env so that
    flipping the env mid-workflow does not change behavior in-flight (R-3 mitigation).
    Implementation: read checkpoint YAML, check for delta_review_mode field.
    If absent: add line `delta_review_mode: "{env_value}"` and write checkpoint.
    Note: "off" is the default for safe rollout (v1). Flip to "warn" in settings.local.json
    to enable delta-focus hints (see spec §10 rollout plan + CLAUDE.md docs).

    STEP -1 (P0-04): Write .claude/workflow-state/.iteration-in-flight BEFORE delegating.
    Use Write tool (auto-allowed). Content (JSON, one file per session):
      {"agent": "plan-reviewer", "started_at": "{ISO-8601 UTC timestamp, e.g. 2026-04-23T14:30:00Z}", "feature": "{feature}", "iteration": {N}}
    Lifecycle: created here → auto-deleted by save-review-checkpoint.sh on SubagentStop.
    Purpose: prevents auto-compaction from fragmenting the verdict narrative mid-review.

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

    STEP 0.5 (IMP-04 — MANDATORY for iteration.plan_review >= 2, SKIP on iter 1):
      Build diff manifest for planner.
      LOAD .claude/skills/workflow-protocols/diff-manifest.md NOW (Read tool)
      before executing — file contains the full algorithm.
      Output: .claude/workflow-state/{feature}-diff-manifest.json

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
    SEE .claude/skills/workflow-protocols/diff-manifest.md → section:
    "Planner Re-invocation Template (iteration 2+)".
    Load the file if not already in context.
    If manifest file missing (first iter 2+ run before STEP 0.5 executed, or KD-6
    triggered with empty mapping) → planner skips phase_0.8, writes plan without
    diff section → plan-reviewer runs full validation (AC-8 path).
  post_delegation: |
    After receiving plan-reviewer output:
    1. Validate output (SEE output_validation in incomplete-output-recovery.md —
       load that file if INCOMPLETE verdict detected)
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
    7. If verdict is INCOMPLETE → Read .claude/skills/workflow-protocols/incomplete-output-recovery.md
       and follow on_incomplete_output fallback chain (step_0..step_5).

## code_review_delegation

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
    STEP SHA (KD-2 — iteration_commit_sha):
    Record current HEAD SHA in checkpoint before delegating to code-reviewer.
    This SHA represents the coder's committed state for this review iteration.
    inject-review-context.sh reads iteration_commit_sha[N-1] on iter ≥2 to
    compute git diff {prior_sha}..HEAD → file-level delta focus for code-reviewer.

    Steps:
    1. Run: git rev-parse HEAD → current_sha
       On failure (git unavailable, detached HEAD): WARN + skip SHA write (non-blocking).
    2. Determine N = current code_review iteration being started.
       Read checkpoint.iteration.code_review = "{N}/3", parse N as integer.
       (Counter is already incremented to N/3 at pre_delegation time.)
    3. Update checkpoint: add/overwrite iteration_commit_sha[N] = current_sha.
       Format (in checkpoint YAML):
         iteration_commit_sha:
           "1": "{sha}"   # written at iter 1 pre_delegation
           "2": "{sha}"   # written at iter 2 pre_delegation
    4. Hook reading convention: for code-reviewer SubagentStart iter N (N ≥ 2),
       read iteration_commit_sha[N-1] as prior_sha.
       Example: iter 2 → reads sha["1"] → git diff sha["1"]..HEAD.

    Failure handling: if git rev-parse fails or checkpoint write fails →
    log WARN, do NOT block delegation. Hook will detect missing SHA and
    skip code delta emission gracefully (non-blocking, AC-5).

    STEP -2 (P3 — sidecar write for worktree-isolated code-reviewer):
    Before STEP -1 (.iteration-in-flight write), invoke:
      echo '{"session_id": "{session_id}"}' \
        | bash .claude/scripts/inject-review-context.sh code-reviewer --sidecar-only
    Produces .claude/workflow-state/code-reviewer-INJECTED-CONTEXT.md.
    prepare-worktree.sh copies this file into the worktree as INJECTED-CONTEXT.md;
    code-reviewer.md startup reads it as additionalContext-equivalent.
    Best-effort: missing sidecar is non-blocking — code-reviewer falls back to
    its current "no prior context" path.
    Rationale: SubagentStart hook does NOT fire for worktree-isolated code-reviewer
    (3/3 confirmed in corpus 2026-04-29..2026-05-02). Sidecar is the orchestrator-
    written equivalent of the SubagentStart additionalContext injection.

    STEP -1 (P0-04): Write .claude/workflow-state/.iteration-in-flight BEFORE delegating.
    Use Write tool (auto-allowed). Content (JSON, one file per session):
      {"agent": "code-reviewer", "started_at": "{ISO-8601 UTC timestamp, e.g. 2026-04-23T14:30:00Z}", "feature": "{feature}", "iteration": {N}}
    Lifecycle: created here → auto-deleted by save-review-checkpoint.sh on SubagentStop.
    Purpose: prevents auto-compaction from fragmenting the verdict narrative mid-review.

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
    1. Validate output (SEE output_validation in incomplete-output-recovery.md —
       load that file if INCOMPLETE verdict detected)
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
    7. If verdict is INCOMPLETE → Read .claude/skills/workflow-protocols/incomplete-output-recovery.md
       and follow on_incomplete_output fallback chain (step_0..step_5).

## Degraded mode

If this file is not found (missing, permission error, or rollout race):
- Orchestrator falls back to minimal delegation: pass artifact path + iteration N/3 only.
- IMP-01 handoff write (STEP 0) is SKIPPED in degraded mode — validate-handoff.sh hook will not fire.
- IMP-04 diff-manifest (STEP 0.5) is SKIPPED — planner runs iter-1 semantics (full plan, no diff digest).
- Pipeline continues. Log WARN to stderr: "[workflow] WARN: delegation-templates.md missing — running in minimal delegation mode (IMP-01 handoff + IMP-04 diff-manifest skipped)"
