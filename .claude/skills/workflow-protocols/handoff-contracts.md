---
name: handoff-contracts
description: "Core pipeline handoff contracts (5 contracts). Lightweight alternative to full handoff-protocol.md for common-path handoff formation. For IMP-02/03/04 details load full handoff-protocol.md."
disable-model-invocation: true
---

# Handoff Contracts

purpose: "Structured context transfer between pipeline phases"

---

handoff_protocol:
  severity: CRITICAL
  rule: "Every phase MUST create a handoff payload for the next phase"

  contract:
    designer_to_planner:
      producer: "/designer"
      consumer: "/planner"
      payload:
        spec_artifact: ".claude/prompts/{feature}-spec.md"
        metadata:
          task_type: "{new_feature|integration|...}"
          complexity: "{L|XL}"
          approaches_considered: N
          sequential_thinking_used: true|false
        key_decisions:
          - "Key decision description + rationale"
        known_risks:
          - "Risk description + severity"
        acceptance_criteria_count: N
        critique_summary:                # OPTIONAL (DE-4). Present when the spec has a design_critique block (Phase 3.5). Consumer SKIPs if absent. designer_to_planner stays non-schema-validated (carries no contract discriminator) — additive, no schema change.
          total: N
          addressed: N
          accepted_risk: N
          out_of_scope: N
          unresolved_high:               # HIGH findings not addressed — /planner carries these into areas_needing_attention[]
            - "Complete sentence describing the unresolved HIGH design finding."

    planner_to_plan_review:
      producer: "/planner"
      consumer: "plan-reviewer (agent)"
      payload:
        "$handoff_contract": "planner_to_plan_review"  # IMP-01: discriminator for schema validation. Quote the $ key in YAML.
        artifact: ".claude/prompts/{feature}.md"
        metadata:
          task_type: "{new_feature|bug_fix|refactoring|...}"
          complexity: "{S|M|L|XL}"
          sequential_thinking_used: true|false
          alternatives_considered: N
          spec_referenced: true|false
          spec_artifact: ".claude/prompts/{feature}-spec.md"  # if applicable, null otherwise
        key_decisions:
          - "Key decision description + rationale"
        known_risks:
          - "Known risk description"
        areas_needing_attention:
          - "Part N: why it needs attention"

    plan_review_to_coder:
      producer: "plan-reviewer (agent)"
      consumer: "/coder"
      payload:
        "$handoff_contract": "plan_review_to_coder"  # IMP-01: discriminator for schema validation. Quote the $ key in YAML.
        artifact: ".claude/prompts/{feature}.md"
        verdict: "APPROVED|NEEDS_CHANGES|REJECTED"
        issues_summary:
          blocker: 0
          major: 0
          minor: 0
        approved_with_notes:
          - "Note about Part N"
        iteration: "N/3"

    coder_to_code_review:
      producer: "/coder"
      consumer: "code-reviewer (agent)"
      schema_validated: "yes — schema $defs.coder_to_code_review (handoff.schema.json 1.1.0+, D2 from post-1.17-symmetry-audit)"
      payload:
        "$handoff_contract": "coder_to_code_review"  # IMP-01: discriminator. Quote the $ key in YAML.
        branch: "feature/{name}"
        parts_implemented: ["Part 1: DB", "Part 2: Domain"]
        evaluate_adjustments:
          - "Part N: adjustment description"
        risks_mitigated:
          - "Risk + how resolved"
        deviations_from_plan:
          - "Description + rationale"
        verify_status:
          lint: "PASS|FAIL|SKIPPED"
          test: "PASS|FAIL|SKIPPED"
          command_used: "{resolved VERIFY_CMD per PROJECT-KNOWLEDGE.md > CLAUDE.md fallback}"
        spec_check:
          status: "PASS|PARTIAL|FAIL"
          coverage_pct: 100
          deviations_confirmed:
            - "Part N: adjustment description"
          ac_coverage:
            - "AC N: covered by TestXxx"
          issues: []
        iteration: "N/3"

    code_review_to_completion:
      producer: "code-reviewer (agent)"
      consumer: "workflow/completion"
      payload:
        verdict: "APPROVED|APPROVED_WITH_COMMENTS|CHANGES_REQUESTED"
        issues:
          - id: "CR-001"
            severity: "BLOCKER|MAJOR|MINOR|NIT"
            category: "architecture|security|error_handling|completeness|style"
            location: "path/file{EXT}:line"
            problem: "..."
            suggestion: "..."
        iteration: "N/3"

  narrative_casting:
    purpose: "Context handoff to review phases without creation-process bias"
    rule: "Review phases receive narrative context + artifact, NOT creation history"
    template_fields:
      - field: "context_source"
        value: "{agent_name}"
        description: "Which agent produced the artifact (planner | designer | coder)"
      - field: "work_performed"
        value: "{brief_description}"
        description: "What the agent did"
      - field: "key_decisions"
        value: "[list]"
        description: "Architectural/design decisions with rationale"
      - field: "known_risks"
        value: "[list]"
        description: "Identified risks and their status"
      - field: "reviewer_recommendations"
        value: "[list]"
        description: "Specific areas for reviewer attention"

  handoff_artifacts:
    purpose: "Machine-readable handoff artifacts for automated validation (IMP-01)"
    schema: ".claude/schemas/handoff.schema.json"
    artifact_pattern: ".claude/workflow-state/{feature}-handoff.json"
    validation_log: ".claude/workflow-state/handoff-validation.jsonl"
    note: "Orchestrator writes {feature}-handoff.json after each producer's output; auto-validated by validate-handoff.sh via PostToolUse hook."

  for_imp_details:
    imp_02_verdict_envelope:  "When writing VERDICT_JSON → load full handoff-protocol.md § verdict_envelopes"
    imp_03_id_normalization:  "When emitting issues[].id → load full handoff-protocol.md § id_normalization"
    imp_04_diff_replan:       "On iter >= 2 handoff formation → load .claude/skills/workflow-protocols/diff-manifest.md (or handoff-protocol.md § diff_based_replan)"
    full_reference:           "For complete IMP-01..IMP-04 protocol text: .claude/skills/workflow-protocols/handoff-protocol.md"
