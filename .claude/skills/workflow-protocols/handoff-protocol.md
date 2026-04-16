# Handoff Protocol

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
      payload:
        branch: "feature/{name}"
        parts_implemented: ["Part 1: DB", "Part 2: Domain"]
        evaluate_adjustments:
          - "Part N: adjustment description"
        risks_mitigated:
          - "Risk + how resolved"
        deviations_from_plan:
          - "Description + rationale"
        verify_status:
          lint: "PASS"
          test: "PASS"
          command_used: "go vet ./... && make fmt && make lint && make test"
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

  code_researcher_contract:
    note: "Lightweight contract — code-researcher is a tool-agent, not a pipeline phase. No verdict, no iteration tracking."
    producer: "code-researcher (via Task tool)"
    consumer: "/planner (Phase 3) or /coder (Phase 1.5)"
    request_payload:
      research_question: "Specific question to investigate"
      focus_areas: ["package/pattern 1", "package/pattern 2"]
      context: "Task type + complexity + what caller needs"
    response_payload:
      format: "Structured summary ≤2000 tokens"
      sections:
        existing_patterns: "{name} — {files} — {description}"
        relevant_files: "table (file, role, lines)"
        import_graph: "package_a → package_b (if multi-layer)"
        key_snippets: "max 3, each ≤15 lines"
        summary: "1-3 sentences"
      isolation: "Full — code-researcher runs in clean context via Task tool"

  handoff_artifacts:
    purpose: "Machine-readable handoff artifacts for automated validation (IMP-01)"
    schema: ".claude/schemas/handoff.schema.json"
    artifact_pattern: ".claude/workflow-state/{feature}-handoff.json"
    validation_log: ".claude/workflow-state/handoff-validation.jsonl"
    note: |
      Since IMP-01: after receiving each producer's output, orchestrator writes a
      dedicated JSON file {feature}-handoff.json in workflow-state/. The file is
      auto-validated by .claude/scripts/validate-handoff.sh via PostToolUse hook.
      Schema: JSON Schema draft-2020-12 with oneOf discriminated by $handoff_contract.
      Mode controlled by env CLAUDE_HANDOFF_VALIDATION_MODE (warn|strict, default warn).
    contracts_covered:
      - "planner_to_plan_review — written in plan_review_delegation.pre_delegation step 0"
      - "plan_review_to_coder — written in plan_review_delegation.post_delegation step 4.5"
    contracts_not_yet_covered:
      - "designer_to_planner, coder_to_code_review, code_review_to_completion → IMP-01.2"

  verdict_envelopes:
    purpose: "Structured VERDICT_JSON envelopes emitted by review agents (IMP-02)"
    schema: ".claude/schemas/handoff.schema.json (top-level oneOf includes verdict variants)"
    emitted_by:
      - "plan-reviewer — emits plan_review_verdict envelope (enum: APPROVED, NEEDS_CHANGES, REJECTED)"
      - "code-reviewer — emits code_review_verdict envelope (enum: APPROVED, APPROVED_WITH_COMMENTS, CHANGES_REQUESTED, NEEDS_CHANGES, REJECTED)"
    discriminator: "$verdict_contract (const: plan_review_verdict | code_review_verdict)"
    transport: |
      The envelope is emitted as the LAST content of the agent's assistant message, using the
      sentinel-prefix fenced JSON pattern:

        VERDICT_JSON:
        ```json
        {"$verdict_contract": "...", "verdict": "...", "issues": [...], "handoff": {...}}
        ```

      Rationale for sentinel prefix (dev.to/pockit-tools 2026 best practice): LLM subagents
      cannot invoke native structured-output APIs (Anthropic tool_use with constrained
      decoding) — they emit free text captured via SubagentStop transcript read. The
      sentinel is the only stable anchor the hook regex can pin to, even if the fence is
      malformed. The "validation sandwich" (prompt engineering + post-hoc schema validation)
      is the LEVEL 2 pattern — the best achievable without native structured output.

    consumer: "save-review-checkpoint.sh (SubagentStop hook)"
    consumer_flow: |
      1. Extract agent's last_assistant_message from SubagentStop payload (or reverse-search
         transcript JSONL for role:assistant)
      2. Search for sentinel VERDICT_JSON: followed by fenced ```json ... ``` block
      3. If found: decode JSON → write to tempfile → invoke validate-handoff.sh in direct mode
         (timeout: 5s) → on validation PASS, use verdict from structured source
      4. On any failure (missing fence, JSON decode error, schema invalid, subprocess error):
         fall back to regex extraction from human-readable VERDICT: line
      5. Emit marker line in .claude/workflow-state/review-completions.jsonl with verdict_source
         field: "structured_json" | "regex_fallback" | "none"
    mode_env: "CLAUDE_VERDICT_VALIDATION_MODE (warn|strict, default warn) — mirrors handoff mode. Independent toggle."
    graceful_degradation: |
      IMP-02 is 100% additive: if an agent omits the VERDICT_JSON block entirely, the regex
      fallback on the human-readable VERDICT: line continues to work exactly as before
      IMP-02 landed. Zero-blast rollout — strict mode is opt-in. Fail-closed on ambiguous
      payloads: validate-handoff.sh treats records with neither $handoff_contract nor
      $verdict_contract discriminator as strict if EITHER env is set to strict.

      CR-003 — warn-mode silent-accept semantics: in the default warn mode,
      validate-handoff.sh exits rc=0 on JSON Schema failure (it only logs the
      failure to handoff-validation.jsonl). save-review-checkpoint.sh keys
      verdict_source off the validator's exit code, so in warn mode a
      schema-INVALID VERDICT_JSON block is recorded as verdict_source=
      "structured_json" — not "structured_json_schema_invalid" — and is
      indistinguishable from a schema-VALID block in the marker line alone.
      The canonical signal that something failed is the verdict_schema_invalid
      record in handoff-validation.jsonl; readers that need to detect
      schema-invalid payloads in warn mode MUST cross-reference that log
      instead of relying on verdict_source. verdict_source=
      "structured_json_schema_invalid" is only emitted in strict mode (rc=2),
      where the regex fallback rescues the run. This asymmetry is by-design
      per the Phase-A A5 rollout: warn mode prioritizes agent-output resilience
      (no false rejections during the instruction-adoption period) over strict
      per-record signalling. Flip CLAUDE_VERDICT_VALIDATION_MODE=strict once
      plan-reviewer.md and code-reviewer.md agents demonstrate stable emission
      of schema-valid envelopes.
    fail_modes:
      - code: "structured_json_schema_invalid"
        meaning: "VERDICT_JSON block parsed cleanly but failed JSON Schema validation (e.g., wrong enum, missing required field)"
        action: "Fall back to regex; record schema_failure_reason in marker line"
      - code: "verdict_json_decode_error"
        meaning: "Block found by sentinel but JSON.decode failed (truncation, escaping issue)"
        action: "Fall back to regex; record schema_failure_reason"
      - code: "verdict_json_missing_fence"
        meaning: "Sentinel VERDICT_JSON: not found, or fence not closed before end-of-message"
        action: "Silent fall-back to regex (expected for pre-IMP-02 agents or runtime-aborted agents)"
