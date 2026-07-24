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
    {if a BUNDLED KIT ROOT directive is present in your (orchestrator) context — plugin mode: paste that directive block here VERBATIM, before the line below (see pre_delegation STEP -3)}
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
    STEP -3 (F3 — redundant BUNDLED KIT ROOT prompt channel):
    If your own orchestrator context contains a "BUNDLED KIT ROOT" directive (injected by
    SessionStart inject-kit-context.sh in plugin mode), copy that directive VERBATIM into the
    head of the delegation_prompt_template above, before the "Review ..." line. The delegation
    prompt always reaches the agent, so this is a third channel (prompt + sidecar + SubagentStart
    hook) — the reviewer can resolve its bundled -rules skill even when the best-effort sidecar is
    absent. In a project-scoped install no such directive is present in your context → omit it
    (the reviewer uses project-relative paths). Source the literal "BUNDLED KIT ROOT:" marker
    from your injected context. If your context lacks the directive (e.g. after a compaction — anthropics/claude-code#15174), read the bundled root from .claude/workflow-state/.bundled-kit-root and synthesize the directive from it.

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

    STATUS: legacy-but-idempotent since the P5 fix. inject-review-context.sh writes the sentinel
    automatically at SubagentStart (and via the STEP -2 `--sidecar-only` invocation for the
    worktree code-reviewer, which calls the same hook). Emitting the manual Write here is permitted
    and harmless (hook overwrites with the same shape); skipping it is now safe. See .claude/prompts/p5-iif-autowrite.md.

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
    SEE .claude/skills/workflow-protocols/diff-manifest.md → "Planner Re-invocation Template (iteration 2+)"
    (also covers the missing-manifest fallback → planner skips phase_0.8, plan-reviewer runs full validation, AC-8 path). Load the file if not already in context.
  post_delegation: |
    After receiving plan-reviewer output:
    1. Validate output (SEE output_validation in incomplete-output-recovery.md —
       load that file if INCOMPLETE verdict detected)
    2. Extract verdict from VERDICT: header (first line)

    2.0 (B4 — reviewer setup-error recovery; NOT a {plan|code} rejection):
        If the extracted verdict == "REJECTED" AND the agent narrative contains the literal
        signature "Rubric unresolvable" (the reviewer could not resolve its -rules rubric from a
        trusted anchor — see plan-reviewer.md / code-reviewer.md STARTUP):
          a. This is an ENVIRONMENT/setup failure, not a {plan|code} defect. Do NOT STOP the
             pipeline and do NOT increment the {plan_review|code_review} iteration counter.
          b. Recover the bundled root: read .claude/workflow-state/.bundled-kit-root (or use the
             BUNDLED KIT ROOT directive already in your context).
          c. Re-dispatch the SAME agent ONCE, inlining the BUNDLED KIT ROOT directive at the head
             of the delegation prompt (STEP -3) AND, for code-reviewer, re-writing the sidecar
             (STEP -2). This is a setup retry, not a review iteration.
          d. Log to .claude/workflow-state/handoff-validation.jsonl:
             {"record_kind": "reviewer_setup_error_recovery", "agent": "{agent}",
              "feature": "{feature}", "signature": "Rubric unresolvable", "session_id": "{session_id}"}
          e. If the re-dispatch ALSO returns REJECTED with "Rubric unresolvable" → genuine
             environment failure → STOP with: "[workflow] FATAL: reviewer rubric unresolvable after
             BUNDLED KIT ROOT re-dispatch — check plugin install / .bundled-kit-root marker."
          f. Otherwise continue normal routing with the re-dispatch verdict as this iteration's result.
        NOTE: the VERDICT enum is unchanged (no new value); this is orchestrator-side routing only.

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
    {if a BUNDLED KIT ROOT directive is present in your (orchestrator) context — plugin mode: paste that directive block here VERBATIM, before the line below (see pre_delegation STEP -3)}
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
    STEP -3 (F3 — redundant BUNDLED KIT ROOT prompt channel):
    If your own orchestrator context contains a "BUNDLED KIT ROOT" directive (injected by
    SessionStart inject-kit-context.sh in plugin mode), copy that directive VERBATIM into the
    head of the delegation_prompt_template above, before the "Review ..." line. The delegation
    prompt always reaches the agent, so this is a third channel (prompt + sidecar + SubagentStart
    hook) — the worktree-isolated reviewer can resolve its bundled -rules skill even when the
    best-effort sidecar is absent. In a project-scoped install no such directive is present in
    your context → omit it (the reviewer uses project-relative paths). Source the literal
    "BUNDLED KIT ROOT:" marker from your injected context. If your context lacks the directive (e.g. after a compaction — anthropics/claude-code#15174), read the bundled root from .claude/workflow-state/.bundled-kit-root and synthesize the directive from it.

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
    Before STEP -1 (.iteration-in-flight write), resolve the bundled kit root (B2 — plugin-safe path) and invoke:
      KIT_ROOT="$(cat .claude/workflow-state/.bundled-kit-root 2>/dev/null)"
      echo '{"session_id": "{session_id}"}' \
        | bash "${KIT_ROOT:-.}/.claude/scripts/inject-review-context.sh" code-reviewer --sidecar-only
    Produces .claude/workflow-state/code-reviewer-INJECTED-CONTEXT.md.
    Native worktree creation copies this file into the worktree via repo-root .worktreeinclude;
    code-reviewer.md startup reads it from .claude/workflow-state/code-reviewer-INJECTED-CONTEXT.md
    as additionalContext-equivalent.
    VERIFY (F4 — do not launch a reviewer that will false-REJECT): after the write, assert the
    sidecar exists and is non-empty:
      test -s .claude/workflow-state/code-reviewer-INJECTED-CONTEXT.md
    In PLUGIN MODE the script ships under BUNDLED KIT ROOT (not the project); the .bundled-kit-root
    marker (written by inject-kit-context.sh) supplies its path, and ${KIT_ROOT:-.} falls back to the
    project-relative path in a project-scoped install (byte-identical to prior behavior). If the
    sidecar is MISSING or EMPTY, the BUNDLED KIT ROOT directive MUST still reach the reviewer via
    STEP -3 (delegation-prompt channel); confirm STEP -3 inlined it (read the .bundled-kit-root marker
    if your context lacks the directive). Prompt + sidecar are two channels — at least one MUST carry
    the directive in plugin mode; if BOTH are absent, STOP with a setup error rather than dispatching
    a reviewer that will REJECT on an unresolvable rubric (see post_delegation step 2.0).
    Best-effort caveat (project-scoped install): a missing sidecar is non-blocking — the reviewer
    falls back to project-relative rubric paths that resolve natively.
    Rationale: SubagentStart fires for worktree agents, but inject-review-context's additionalContext
    does not reliably reach a worktree reviewer — the worktree runs origin/main's hooks
    (worktree.baseRef:"fresh") and the main-repo checkpoint is absent from the worktree. The
    file-sidecar (delivered via .worktreeinclude) is the reliable channel.

    STEP -1 (P0-04): Write .claude/workflow-state/.iteration-in-flight BEFORE delegating.

    STATUS: legacy-but-idempotent since the P5 fix. inject-review-context.sh writes the sentinel
    automatically at SubagentStart (and via the STEP -2 `--sidecar-only` invocation for the
    worktree code-reviewer, which calls the same hook). Emitting the manual Write here is permitted
    and harmless (hook overwrites with the same shape); skipping it is now safe. See .claude/prompts/p5-iif-autowrite.md.

    Use Write tool (auto-allowed). Content (JSON, one file per session):
      {"agent": "code-reviewer", "started_at": "{ISO-8601 UTC timestamp, e.g. 2026-04-23T14:30:00Z}", "feature": "{feature}", "iteration": {N}}
    Lifecycle: created here → auto-deleted by save-review-checkpoint.sh on SubagentStop.
    Purpose: prevents auto-compaction from fragmenting the verdict narrative mid-review.

    STEP 0 (IMP-01.2 — symmetry with plan_review_delegation STEP 0):
      Write coder→code-review handoff to .claude/workflow-state/{feature}-handoff.json
      BEFORE delegating to code-reviewer. Hook auto-validates on write.
      Format (must match .claude/schemas/handoff.schema.json, contract coder_to_code_review):
        {
          "$handoff_contract": "coder_to_code_review",
          "branch": "{branch}",
          "parts_implemented": ["Part 1: ...", "Part 2: ..."],
          "evaluate_adjustments": ["{adj}", ...],   # OPTIONAL
          "risks_mitigated":     ["{risk}", ...],   # OPTIONAL
          "deviations_from_plan": ["{dev}", ...],   # OPTIONAL
          "narrative_for_reviewer": "{narrative}",  # OPTIONAL — MUST be capped at 600 chars
          "high_risk_areas":     ["{area}", ...],   # OPTIONAL
          "verify_status": {
            "lint": "PASS|FAIL|SKIPPED",
            "test": "PASS|FAIL|SKIPPED",
            "command_used": "{resolved VERIFY_CMD}"
          },
          "spec_check": {              # OPTIONAL — present for L/XL complexity
            "status": "PASS|PARTIAL|FAIL",
            "coverage_pct": 100,
            "deviations_confirmed": [],
            "ac_coverage": [],
            "issues": []
          },
          "iteration": "{N}/3"
        }
      Source of fields: extract from coder's emitted handoff narrative.
      Cap rule (P1 schema constraint): truncate `narrative_for_reviewer` at 600 chars
      BEFORE write — schema validation rejects payloads exceeding the cap.
      Telemetry (P-5): when truncation occurs, append record to
      .claude/workflow-state/handoff-validation.jsonl:
          {
            "ts": "{ISO-8601 UTC}",
            "record_kind": "narrative_truncated",
            "agent": "/coder",
            "feature": "{feature}",
            "iteration": "{N}/3",
            "original_length": {pre-trim length, integer},
            "truncated_length": 600,
            "session_id": "{session_id}"
          }
      Rationale: silent truncation hides the loss of high_risk_areas / deviations
      narrative content. Telemetry makes it observable; root-cause fix is
      coder.md narrative_for_reviewer summary-only contract (see coder.md → handoff_output).
      Failure handling: if write fails (disk error) or validation fails in strict mode →
      log WARN and proceed with delegation (graceful degradation; agent still gets the
      narrative via the delegation prompt template).

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

    2.0 (B4 — reviewer setup-error recovery; NOT a {plan|code} rejection):
        If the extracted verdict == "REJECTED" AND the agent narrative contains the literal
        signature "Rubric unresolvable" (the reviewer could not resolve its -rules rubric from a
        trusted anchor — see plan-reviewer.md / code-reviewer.md STARTUP):
          a. This is an ENVIRONMENT/setup failure, not a {plan|code} defect. Do NOT STOP the
             pipeline and do NOT increment the {plan_review|code_review} iteration counter.
          b. Recover the bundled root: read .claude/workflow-state/.bundled-kit-root (or use the
             BUNDLED KIT ROOT directive already in your context).
          c. Re-dispatch the SAME agent ONCE, inlining the BUNDLED KIT ROOT directive at the head
             of the delegation prompt (STEP -3) AND, for code-reviewer, re-writing the sidecar
             (STEP -2). This is a setup retry, not a review iteration.
          d. Log to .claude/workflow-state/handoff-validation.jsonl:
             {"record_kind": "reviewer_setup_error_recovery", "agent": "{agent}",
              "feature": "{feature}", "signature": "Rubric unresolvable", "session_id": "{session_id}"}
          e. If the re-dispatch ALSO returns REJECTED with "Rubric unresolvable" → genuine
             environment failure → STOP with: "[workflow] FATAL: reviewer rubric unresolvable after
             BUNDLED KIT ROOT re-dispatch — check plugin install / .bundled-kit-root marker."
          f. Otherwise continue normal routing with the re-dispatch verdict as this iteration's result.
        NOTE: the VERDICT enum is unchanged (no new value); this is orchestrator-side routing only.
    2.1 (P-1 alias normalization): If extracted verdict == "NEEDS_CHANGES" (code-review legacy alias):
        a. Normalize: routing_verdict = "CHANGES_REQUESTED"
        b. Append record to .claude/workflow-state/handoff-validation.jsonl:
             {
               "ts": "{ISO-8601 UTC now}",
               "record_kind": "verdict_alias_normalized",
               "agent": "code-reviewer",
               "original_verdict": "NEEDS_CHANGES",
               "normalized_verdict": "CHANGES_REQUESTED",
               "iteration": "{N}/3",
               "session_id": "{session_id}"
             }
        c. Use routing_verdict for ALL downstream routing decisions (counter increment, issues_history, re-route).
        d. Preserve original_verdict in checkpoint.issues_history[entry].original_verdict for audit trail.
        e. Reference: re-routing.md → verdict_aliases.
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
    6.5 (IMP-01.2 — symmetry with plan_review_delegation step 6.5):
        Write code-review handoff JSON to .claude/workflow-state/{feature}-handoff.json.
        Hook auto-validates on write. Format (contract code_review_to_completion):
          {
            "$handoff_contract": "code_review_to_completion",
            "verdict": "{normalized verdict}",
            "original_verdict": "{pre-normalization verdict if alias normalised, omit otherwise}",
            "issues": [{ ...canonical-ID issues from latest review-completions.jsonl entry... }],
            "iteration": "{N}/3",
            "narrative_for_coder": "{≤400 char summary, OPTIONAL}"
          }
        Source of fields:
          - verdict, original_verdict: from step 2 + step 2.1 (alias normalization)
          - issues: cross-join two sources by id —
              * id, category, location, problem: from canonical_issue_ids[] in latest review-completions.jsonl entry (IMP-03 normalised IDs; canonical-only fields stored by save-review-checkpoint.sh:365-370)
              * severity, suggestion, reference: from raw extracted issues in checkpoint.issues_history[latest phase=4 entry].issues[] (full per-issue shape including severity/suggestion preserved from VERDICT_JSON parsed.issues at hook extraction time)
              Schema requires {id, severity, category, problem}; severity must come from raw issues — canonical_issue_ids[] does NOT carry severity by design (IMP-03 hashes only category|location|problem for stable IDs).
          - iteration: from checkpoint.iteration.code_review
          - narrative_for_coder: extract from agent's narrative section if ≤400 chars, omit otherwise
        Failure handling: if write fails (disk error) or validation fails in strict mode →
          log WARN to handoff-validation.jsonl (record_kind: "code_review_to_completion_write_failed")
          and proceed with re-route (graceful degradation; coder falls back to delegation-prompt-text path).
        Backwards compat: file is OPTIONAL on coder side — Phase 0.5 reads if present, falls back if absent.
    7. If verdict is INCOMPLETE → Read .claude/skills/workflow-protocols/incomplete-output-recovery.md
       and follow on_incomplete_output fallback chain (step_0..step_5).

## subagent_type normalization (I-04)

SEE [State Layer](state-layer.md) § subagent_type normalization — `save-review-checkpoint.sh` normalizes the SubagentStop payload `agent_type` (defense-in-depth); `agent_type` is NOT part of the canonical issue-ID hash, so this does not affect ID stability.

## Degraded mode

If this file is not found (missing, permission error, or rollout race):
- Orchestrator falls back to minimal delegation: pass artifact path + iteration N/3 only.
- IMP-01 handoff write (STEP 0) is SKIPPED in degraded mode — validate-handoff.sh hook will not fire.
- IMP-04 diff-manifest (STEP 0.5) is SKIPPED — planner runs iter-1 semantics (full plan, no diff digest).
- Pipeline continues. Log WARN to stderr: "[workflow] WARN: delegation-templates.md missing — running in minimal delegation mode (IMP-01 handoff + IMP-04 diff-manifest skipped)"
