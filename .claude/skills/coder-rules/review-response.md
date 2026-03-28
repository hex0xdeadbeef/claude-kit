# Review Response Protocol

purpose: "Structured response to review feedback — verify before implementing, push-back protocol, iteration-aware triage"

---

response_protocol:
  trigger: "/coder re-entry after CHANGES_REQUESTED (code-review iteration N/3)"
  iron_law: "VERIFY before implementing. No issue is accepted without checking against codebase reality."

  response_pattern:
    summary: "TRIAGE → VERIFY → EVALUATE → IMPLEMENT → DOCUMENT"

    steps:
      - step: 1
        name: "TRIAGE"
        action: "Parse issues[] from code-reviewer handoff by severity"
        details: |
          Read issues from code-reviewer handoff payload.
          Group by severity: BLOCKER → MAJOR → MINOR → NIT.
          Count totals per severity for iteration-aware handling.

      - step: 2
        name: "VERIFY"
        action: "Check each issue against current codebase state"
        details: |
          For each issue:
            1. Read the file:line referenced in issue.location
            2. Verify the problem described actually exists in current code
            3. Check if the suggested fix is technically correct for THIS codebase
            4. Note: code may have changed since review (auto-fmt, other fixes)

      - step: 3
        name: "EVALUATE"
        action: "Decide per issue: ACCEPT / PUSH_BACK / CLARIFY"
        decisions:
          ACCEPT: "Issue verified, fix is correct → implement"
          PUSH_BACK: "Issue incorrect, breaks existing code, or outside plan scope → document reasoning"
          CLARIFY: "Issue unclear, need more context → note for orchestrator"
        note: "Default to ACCEPT when issue is valid. Push-back requires technical justification."

      - step: 4
        name: "IMPLEMENT"
        action: "Fix accepted issues in severity order, test each"
        order:
          - "BLOCKER issues first (security, crashes, data loss)"
          - "MAJOR issues (logic errors, missing validation)"
          - "MINOR issues (style, naming, minor improvements)"
          - "NIT issues (cosmetic, formatting — subject to iteration strategy)"
        rule: "One fix at a time. Run relevant tests after each BLOCKER/MAJOR fix."

      - step: 5
        name: "DOCUMENT"
        action: "Update handoff payload with resolution status"
        output: |
          For each issue, record in handoff:
            - ACCEPTED issues → added to risks_mitigated
            - PUSH_BACK issues → added to deviations_from_plan with reasoning
            - CLARIFY issues → noted for orchestrator attention

  nit_handling:
    purpose: "Prevent infinite review loops on stylistic disagreements"
    strategy:
      iteration_1: "Fix ALL issues including NIT"
      iteration_2: "Fix BLOCKER + MAJOR + MINOR. Skip NIT — note in handoff."
      iteration_3: "Fix BLOCKER + MAJOR only. Escalate MINOR + NIT to user."
    rationale: "Each iteration should converge. If NIT issues persist across iterations, they indicate subjective disagreement, not code defects."

  forbidden_patterns:
    purpose: "Anti-patterns when handling review feedback"

    patterns:
      - pattern: "Blind acceptance"
        description: "Implementing all issues without verifying against codebase"
        why_bad: "Reviewer may lack full context. Fix may break existing functionality."
        instead: "VERIFY step — check each issue against actual code state"

      - pattern: "Batch implementation"
        description: "Implementing BLOCKER + NIT simultaneously without testing between"
        why_bad: "If tests break, unclear which fix caused the failure"
        instead: "One fix at a time, test after each BLOCKER/MAJOR fix"

      - pattern: "Scope expansion"
        description: "Adding code/features not in the plan because reviewer suggested it"
        why_bad: "Violates RULE_1 (Plan Only). Reviewer suggestions outside plan scope need planner re-visit."
        instead: "YAGNI check — push back with RULE_1 reference"

      - pattern: "Skip verification"
        description: "Implementing fix without re-running VERIFY"
        why_bad: "Fix may introduce regressions or break other parts"
        instead: "Full VERIFY after all fixes applied"

      - pattern: "Silent disagreement"
        description: "Ignoring an issue without documenting why"
        why_bad: "Reviewer will flag it again in next iteration, wasting a cycle"
        instead: "PUSH_BACK with technical reasoning in deviations_from_plan"

  source_handling:
    code_reviewer:
      context: "Primary feedback source — structured issues with severity"
      format: |
        Issues arrive as structured payload (code_review_to_completion contract):
          issues[]:
            - id: "CR-001"
              severity: "BLOCKER|MAJOR|MINOR|NIT"
              category: "architecture|security|error_handling|completeness|style"
              location: "path/file.go:line"
              problem: "description"
              suggestion: "proposed fix"
      handling: |
        1. Parse issues[] — already structured, no interpretation needed
        2. Apply response_pattern (TRIAGE → VERIFY → EVALUATE → IMPLEMENT → DOCUMENT)
        3. Each issue gets explicit resolution status in handoff

    plan_reviewer_notes:
      context: "Secondary — guidance notes from plan-review, NOT fix requests"
      format: |
        Notes arrive as approved_with_notes[] in plan_review_to_coder contract:
          approved_with_notes:
            - "Note about Part N"
      handling: |
        1. These are implementation guidance, not code issues
        2. Integrate during EVALUATE phase (Phase 1.5 on first run)
        3. Do NOT treat as CHANGES_REQUESTED — plan is approved
        4. Document how notes were addressed in evaluate_output

  push_back_protocol:
    when_to_push_back:
      - "Issue contradicts the approved plan (RULE_1)"
      - "Suggested fix breaks existing passing tests"
      - "Reviewer suggests adding feature not in plan scope (YAGNI)"
      - "Fix is technically incorrect for this codebase/stack"
      - "Issue references code that no longer exists (stale review)"

    how_to_push_back:
      step_1: "Verify your pushback is technically grounded — grep/read the relevant code"
      step_2: "Document in handoff deviations_from_plan with technical reasoning"
      step_3: "Reference specific evidence: test names, file:line, plan section"
      format: |
        deviations_from_plan:
          - "CR-{id}: Push-back — {brief reason}. Evidence: {test/code reference}."

    escalation:
      when: "Architectural disagreement (issue category: architecture, BLOCKER severity)"
      action: "Document push-back AND note for orchestrator — do not silently ignore"
      note: "Orchestrator may request user intervention for architectural disputes"

  yagni_check:
    purpose: "Aligned with RULE_1 (Plan Only) — no unplanned additions"
    protocol: |
      IF reviewer suggests adding code, feature, or abstraction:
        CHECK: Is this in the approved plan (.claude/prompts/{feature}.md)?

        IF not in plan:
          → PUSH_BACK: "Outside plan scope per RULE_1. Requires planner re-visit if needed."
          → Add to deviations_from_plan in handoff

        IF in plan but was missed during implementation:
          → ACCEPT: implement the missing piece
          → Note in risks_mitigated: "CR-{id}: Missing implementation — added per plan"

        IF ambiguous (partially in plan, partially new):
          → Implement the part that IS in plan
          → Push back on the part that ISN'T
          → Document the split in deviations_from_plan

  handoff_integration:
    purpose: "Iteration-aware handoff payload for next code-review round"
    note: "iteration field is incremented by orchestrator, not by /coder"

    fields_to_update:
      risks_mitigated:
        content: "Resolved issues from review"
        format: "CR-{id}: {issue summary} — fixed in {file:line}"
      deviations_from_plan:
        content: "Push-backs with reasoning"
        format: "CR-{id}: Push-back — {reason}. Evidence: {reference}."
      verify_status:
        content: "Must re-run full VERIFY after all fixes"
        rule: "VERIFY is mandatory on every iteration, even if only NIT fixes applied"

    example: |
      Handoff → /code-review (iteration 2/3):
        branch: feature/{name}
        parts_implemented: ["Part 1-5 (unchanged)", "Review fixes: CR-001, CR-003, CR-004"]
        evaluate_adjustments: []
        risks_mitigated:
          - "CR-001 (BLOCKER): SQL injection in query builder — parameterized"
          - "CR-003 (MAJOR): Missing nil check — added guard clause"
          - "CR-004 (MINOR): Inconsistent error wrapping — standardized"
        deviations_from_plan:
          - "CR-002: Push-back — suggested adding retry logic not in plan (RULE_1). Existing error propagation is sufficient per plan Part 3."
        verify_status:
          lint: PASS
          test: PASS
          command_used: "go vet ./... && make fmt && make lint && make test"

  examples:
    blind_acceptance:
      bad: |
        Reviewer: "CR-001: Add retry logic to HTTP client"
        Coder: Implements retry logic immediately without checking plan
      good: |
        Reviewer: "CR-001: Add retry logic to HTTP client"
        Coder: Checks plan → retry not in scope → push-back:
          "CR-001: Push-back — retry logic not in plan scope (RULE_1).
           Plan Part 3 specifies error propagation without retry."
      why: "RULE_1 — implement only what's in the plan"

    verified_fix:
      bad: |
        Reviewer: "CR-002: Remove legacy code at handler.go:45"
        Coder: Deletes lines 45-60 without checking
      good: |
        Reviewer: "CR-002: Remove legacy code at handler.go:45"
        Coder: Reads handler.go:45 → finds code IS used by middleware
          → push-back: "CR-002: Push-back — code at handler.go:45 is used by
           auth middleware (grep: middleware.go:23). Removing breaks auth flow."
      why: "VERIFY before implementing — reviewer may lack full context"

    nit_escalation:
      context: "Iteration 3/3 — only BLOCKER + MAJOR"
      bad: |
        Reviewer: "CR-005 (NIT): Rename variable 'svc' to 'service'"
        Coder: Renames variable, spends time on cosmetic change
      good: |
        Reviewer: "CR-005 (NIT): Rename variable 'svc' to 'service'"
        Coder: Notes in handoff: "CR-005 (NIT): Skipped per iteration 3/3 strategy —
          BLOCKER + MAJOR only. Escalated to user."
      why: "Prevent infinite loops on subjective style disagreements"

  common_mistakes:
    - mistake: "Implementing all issues without verification"
      fix: "Run VERIFY step — check each issue against codebase before fixing"
    - mistake: "Accepting scope expansion from reviewer"
      fix: "YAGNI check — is it in the plan? If not, push back per RULE_1"
    - mistake: "Ignoring NIT iteration strategy"
      fix: "Check iteration count — apply nit_handling strategy"
    - mistake: "Silent push-back (ignoring without documenting)"
      fix: "Always document push-backs in deviations_from_plan with reasoning"
    - mistake: "Skipping VERIFY after review fixes"
      fix: "Full VERIFY is mandatory every iteration — no exceptions"
