spec:
  title: "SA-2: Two-Stage Review (Spec Compliance + Quality)"
  status: "approved"

  context:
    current_state: |
      /coder pipeline: EVALUATE → IMPLEMENT PARTS → SIMPLIFY (L/XL, parts≥5) → VERIFY → handoff to code-reviewer.
      code-reviewer pipeline: QUICK CHECK → GET CHANGES → REVIEW (architecture, error handling, security, test coverage) → VERDICT.
      Single-pass review mixes "did we build the right thing?" (spec compliance) with "did we build it well?" (quality).
      No explicit spec compliance check exists anywhere in the pipeline.
    motivation: |
      Cross-review with Superpowers v5.0.6 identified that separating "correctly built?" and "well built?"
      catches different categories of defects. Currently, a "wrong feature built" defect surfaces only in code-review
      CHANGES_REQUESTED, consuming a full code-review iteration. An earlier inline check would catch it
      before the agent review cycle, reducing CHANGES_REQUESTED iterations.
      Superpowers v5.0.6 validated the inline (not subagent) approach: they removed subagent spec review
      for ~25min savings with comparable defect rate.
    business_value: |
      Fewer CHANGES_REQUESTED iterations due to spec/compliance gaps. /coder self-validates plan coverage
      before delegating. code-reviewer focuses on quality, not re-checking compliance.

  requirements:
    in_scope:
      - "Add Phase 3.5 SPEC CHECK inline in /coder (after VERIFY, before handoff)"
      - "New supporting file .claude/skills/coder-rules/spec-check.md with checklist + protocol"
      - "Enrich coder→code-reviewer handoff with spec_check_result field"
      - "Update code-reviewer QUICK CHECK to read spec_check.status from handoff"
      - "Update code-review-rules/SKILL.md: trust spec_check, focus REVIEW on quality"
      - "Update orchestration-core.md pipeline diagram (add SPEC CHECK step)"
      - "Update workflow.md delegation template (pass spec_check summary)"
      - "Update workflow-architecture.md docs (coder phases table)"
    out_of_scope:
      - item: "New spec-reviewer agent"
        reason: "Subagent overhead ~25min not justified; Superpowers v5.0.6 validated inline approach"
      - item: "New loop limit counter for spec check"
        reason: "Inline inline fix within /coder context; existing code_review_cycle counter unchanged"
      - item: "Spec check for S-complexity plans"
        reason: "S plans have 1 Part, SIMPLIFY skipped; SPEC CHECK runs but in lightweight mode (coverage only)"
      - item: "plan-reviewer changes"
        reason: "Plan review is unaffected; spec compliance is a post-implementation concern"
    constraints:
      - "Backward compatible: if spec_check missing from handoff → code-reviewer falls back to implicit compliance check"
      - "spec-check.md must stay compact (< 120 lines) to minimize context load in /coder"
      - "No changes to loop limits (plan_review_cycle and code_review_cycle remain max 3)"
      - "Follows existing pattern: coder.md has phase stub, coder-rules/ has supporting detail"

  approach:
    selected:
      name: "Inline SPEC CHECK in /coder (Phase 3.5)"
      description: |
        After VERIFY passes, /coder runs a structured self-check:
        1. Parts coverage: all plan Parts present in parts_implemented list?
        2. Scope boundary: no changes outside plan scope (git diff --name-only vs plan files)?
        3. Deviations confirmed: evaluate_output deviations still accurate, any new ones?
        4. AC spot-check: each acceptance criterion maps to a code path or test?
        5. Interface contracts: public signatures match plan examples? (M+ only)

        Output: spec_check_result with status PASS|PARTIAL|FAIL + details.
        If FAIL: inline fix → re-run VERIFY (capped at 1 retry). If still FAIL → proceed as PARTIAL.
        Result included in handoff → code-reviewer QUICK CHECK notes compliance status.
      rationale: |
        /coder already has plan context loaded → no reload cost. Superpowers v5.0.6 validated
        this trade-off. Mechanical checklist minimizes rationalization bias. No new agent/loop/worktree.

    alternatives:
      - option: "Split code-reviewer into spec-reviewer + quality-reviewer agents"
        pros:
          - "True independence — no self-review bias"
          - "Can tune each reviewer's focus independently"
        cons:
          - "~25min overhead per run (2 worktrees, 2 agent startups)"
          - "Superpowers removed this exact approach in v5.0.6 for overhead reasons"
          - "Loop limit complexity: shared vs separate counters"
          - "More orchestration changes"
        rejected_because: "Overhead not justified. Superpowers empirical data: comparable defect rate at much lower cost."

      - option: "Add plan compliance as category 4f in code-reviewer REVIEW"
        pros:
          - "Minimal changes (existing agent, new category)"
          - "No new phase, no new files"
        cons:
          - "Spec compliance + quality review in same pass — defeats two-stage purpose"
          - "code-reviewer must load plan file (available in worktree but adds complexity)"
          - "No reduction in CHANGES_REQUESTED iterations (issues still surface at same stage)"
        rejected_because: "Doesn't achieve two-stage separation. Issues still found at code-review stage."

  key_decisions:
    - decision: "Phase 3.5 (after VERIFY) not 2.6 (before VERIFY)"
      rationale: |
        Spec check after VERIFY ensures code compiles and tests pass before compliance check.
        If spec check runs before VERIFY and finds deviations → coder fixes → re-runs VERIFY anyway.
        Running spec check after VERIFY is strictly more efficient.
      impact: "Pipeline order: IMPLEMENT → SIMPLIFY → VERIFY → SPEC CHECK → handoff"

    - decision: "spec_check_result added to coder→code-reviewer handoff"
      rationale: |
        Explicit field prevents code-reviewer from duplicating compliance work. Enables QUICK CHECK
        to note spec status before starting quality review. Backward compatible (field is optional).
      impact: "handoff-protocol.md coder_to_code_review contract updated"

    - decision: "code-reviewer trusts spec_check.status=PASS, skips compliance re-check"
      rationale: |
        Avoids duplicate work. /coder has better plan context (plan already loaded in context).
        code-reviewer focuses entirely on quality when compliance is confirmed.
        If spec_check missing → fallback to implicit compliance (backward compat).
      impact: "code-reviewer QUICK CHECK phase updated; code-review-rules/SKILL.md updated"

    - decision: "Inline fix cap: 1 retry within Phase 3.5"
      rationale: |
        Prevents infinite loop within /coder. If spec check finds issues → 1 inline fix + VERIFY re-run.
        If still PARTIAL → proceed with documented PARTIAL status. code-reviewer then treats gaps as MINOR.
      impact: "spec-check.md protocol defines retry cap explicitly"

    - decision: "New supporting file spec-check.md (not inline in coder.md)"
      rationale: |
        Follows existing pattern: coder.md has phase stubs, coder-rules/ has detailed protocols.
        Keeps coder.md concise. spec-check.md can be updated independently.
        Load condition: always at /coder startup (compact file, low overhead).
      impact: ".claude/skills/coder-rules/spec-check.md (NEW, < 120 lines)"

    - decision: "S-complexity: lightweight spec check (coverage only, no AC spot-check)"
      rationale: |
        S plans have 1 Part, fast implementation. Full spec check overhead not justified.
        Coverage check (Part 1 implemented?) is sufficient for S.
      impact: "spec-check.md has lightweight mode for S complexity"

    - decision: "No new loop limits"
      rationale: |
        Spec check is inline within /coder — it doesn't create a new review cycle.
        Existing code_review_cycle counter (max 3) unchanged.
        Spec check reduces code-review iterations; it doesn't add new ones.
      impact: "orchestration-core.md loop_limits section unchanged"

    - decision: "workflow-architecture.md updated as documentation Part"
      rationale: |
        Architecture docs must stay in sync with runtime artifacts.
        Coder phases table and pipeline diagram need updating.
        Lower priority than runtime files; separate Part in plan.
      impact: ".claude/docs/workflow-architecture.md Part updated"

  risks:
    - risk: "Context bloat in /coder — adding spec-check.md to startup load"
      severity: "LOW"
      mitigation: "spec-check.md capped at < 120 lines. Minimal runtime token cost."

    - risk: "Duplication: spec check and code-reviewer both check compliance"
      severity: "MEDIUM"
      mitigation: |
        code-reviewer explicitly trusts spec_check.status=PASS from handoff.
        code-review-rules/SKILL.md documents: 'Trust spec_check from handoff. REVIEW focuses on quality.'
        Backward compat: if spec_check missing → code-reviewer runs implicit compliance check.

    - risk: "Self-review bias — /coder rationalizes compliance"
      severity: "MEDIUM"
      mitigation: |
        Mechanical checklist (Parts coverage %, file list vs plan scope, AC mapping).
        Not subjective evaluation but structural verification.
        code-reviewer still has full diff → any major missed Parts visible in REVIEW.

    - risk: "Inline fix → VERIFY re-run → time cost"
      severity: "LOW"
      mitigation: |
        Capped at 1 retry. Most spec deviations are documentation gaps (already in evaluate_output),
        not missing code. VERIFY re-run is fast for minor additions.

    - risk: "Backward compatibility — existing handoffs without spec_check field"
      severity: "LOW"
      mitigation: "spec_check field optional in contract. code-reviewer treats missing as 'not checked'."

  acceptance_criteria:
    - "/coder pipeline has Phase 3.5 SPEC CHECK section after VERIFY, before handoff output"
    - "spec-check.md exists at .claude/skills/coder-rules/spec-check.md with Parts coverage + AC spot-check checklist"
    - "coder→code-reviewer handoff-protocol.md includes spec_check field with status/coverage_pct/issues"
    - "code-reviewer.md QUICK CHECK reads spec_check.status from handoff — PASS → trust, FAIL → flag"
    - "code-review-rules/SKILL.md includes note: spec_check from handoff, REVIEW focuses on quality"
    - "orchestration-core.md pipeline diagram shows VERIFY → SPEC CHECK → handoff step"
    - "workflow.md code-review delegation_template includes spec_check_result summary line"
    - "S-complexity: spec-check.md defines lightweight mode (coverage only, no AC spot-check)"
    - "No changes to loop limits (plan_review_cycle, code_review_cycle remain max 3)"
    - "workflow-architecture.md coder phases table updated (Phase 3.5 added)"

  notes: |
    Superpowers v5.0.6 reference: subagent spec review removed in v5.0.6 because overhead ~25min with
    comparable defect rate vs inline self-review. This validates our Approach A selection.

    The two-stage separation:
    - Stage 1 (/coder Phase 3.5): "Did we build the right thing?" → spec compliance
    - Stage 2 (code-reviewer): "Did we build it well?" → architecture, security, quality

    spec_check_result payload (in handoff):
    ```yaml
    spec_check:
      status: "PASS|PARTIAL|FAIL"
      coverage_pct: 100        # Parts covered / Parts in plan * 100
      deviations_confirmed: [] # deviations from evaluate_output still accurate
      ac_coverage: []          # AC N: covered by TestXxx / code path
      issues: []               # only populated if PARTIAL or FAIL
    ```

    File change summary (8 files, 1 new):
    1. .claude/commands/coder.md — Phase 3.5 stub
    2. .claude/skills/coder-rules/SKILL.md — RULE_6 + spec-check.md reference
    3. .claude/skills/coder-rules/spec-check.md — NEW: full protocol + checklist
    4. .claude/agents/code-reviewer.md — QUICK CHECK spec_check awareness
    5. .claude/skills/code-review-rules/SKILL.md — spec_check trust note
    6. .claude/skills/workflow-protocols/handoff-protocol.md — spec_check field in coder_to_code_review
    7. .claude/skills/workflow-protocols/orchestration-core.md — pipeline diagram update
    8. .claude/commands/workflow.md — delegation template update
    9. .claude/docs/workflow-architecture.md — coder phases table + pipeline diagram
