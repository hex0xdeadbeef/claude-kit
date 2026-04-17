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

      post_normalization_example: |
        Agent emits (advisory IDs):
          {"id": "PR-001", "category": "error_handling", "location": "Part 3",
           "problem": "nil pointer not guarded in UserHandler.Create"}

        Hook normalises before schema validation:
          PREFIX = "PR-" (from $verdict_contract=plan_review_verdict)
          sha256("error_handling|Part 3|nil pointer not guarded in UserHandler.Create")[:8]
            = e.g. "ab12cd34"
          canonical_id = "PR-ab12cd34"

        Schema pattern ^PR-[0-9a-f]{8}$ validates "PR-ab12cd34" → PASS.
        review-completions.jsonl canonical_issue_ids contains the canonical form;
        agent's original "PR-001" is discarded.

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

  id_normalization:
    purpose: "Canonical issue ID normalization via hook-side SHA-256 (IMP-03)"
    formula: |
      canonical_id = PREFIX + sha256(category + "|" + (location or "") + "|" + problem)[0:8]
      PREFIX = "PR-" for plan_review_verdict
      PREFIX = "CR-" for code_review_verdict
    computed_by: "save-review-checkpoint.sh — runs BEFORE schema validation"
    schema_pattern: "^[PC]R-[0-9a-f]{8}$ (enforced in plan_review_verdict + code_review_verdict $defs)"
    rationale: |
      Agent-emitted IDs (e.g. "PR-001") are advisory — they reference a POSITION in the
      review's issue list, not the ISSUE itself. Hook-side sha256 normalization produces
      a deterministic content-addressed ID: same category|location|problem across
      iterations → same canonical ID, enabling automatic resolved/regression detection
      at the orchestrator layer.

      LLM constraint: review agents cannot compute sha256 reliably (>50% error rate
      on tested Claude models). Python in the hook runs it deterministically.

    storage: |
      canonical_issue_ids field in review-completions.jsonl marker:
        [{"id": "PR-ab12cd34", "category": "error_handling",
          "location": "Part 3", "problem": "nil pointer not guarded"}, ...]
      Dedup applied — collisions logged as record_kind="id_collision" in handoff-validation.jsonl.

    consumer_flow: |
      1. save-review-checkpoint.sh computes canonical_id per issue, overwrites issues[].id
         in parsed VERDICT_JSON, re-serialises raw_json, invokes validate-handoff.sh.
      2. validate-handoff.sh validates the normalised payload against the pattern constraint.
      3. Marker appended to review-completions.jsonl with canonical_issue_ids array.
      4. Orchestrator (post_delegation) reads canonical_issue_ids, computes:
         resolved_ids = prior - current   (set-diff)
         regression_ids = current ∩ union(prior.resolved_ids)   (intersection)
      5. inject-review-context.sh on iteration 2+ passes canonical IDs + regression
         alerts into additionalContext for the next review.

    mode_env: "CLAUDE_ISSUE_ID_VALIDATION_MODE (warn|strict, default warn) — independent toggle. Strict boosts MODE_VERDICT to strict for verdict records."

    stability_guidance:
      - "category is a schema-enum — always stable (high confidence)"
      - "location should be function/symbol name, not bare line number (KD-8 mitigation)"
      - "problem should be a concise invariant statement (≤15 words, imperative voice)"

    fail_modes:
      - code: "id_collision"
        meaning: "Two issues produce the same canonical_id after normalization (same category + location + problem text)"
        action: "First entry kept in canonical_issue_ids; collision logged to handoff-validation.jsonl. parsed['issues'] / raw_json retain both entries (schema allows duplicate IDs)."
      - code: "prefix_unknown"
        meaning: "$verdict_contract is neither plan_review_verdict nor code_review_verdict"
        action: "Prefix falls back to 'XX-', schema pattern FAIL, warn-mode logs + regex fallback. Strict mode blocks."

  diff_based_replan:
    purpose: "Part-selective plan re-validation on iter 2+ (IMP-04)"
    closes: "P-04 — planner rewrite-from-scratch on iter 2+ wastes file-read budget and invites regressions"
    approach: "Approach D — Issue-Addressed Diff via IMP-03 canonical_issue_ids"
    depends_on:
      - "IMP-03: canonical_issue_ids + location format 'Part N: Symbol' (KD-8)"
      - "IMP-02: VERDICT_JSON envelope (parts_validated[] rides as optional field)"
      - "IMP-01: handoff-validation.jsonl (imp04_unmapped_location, imp04_cross_cutting_issue, imp04_contract_break_reroute record kinds)"

    flow: |
      Iter N (N >= 2) pipeline steps:
        1. Orchestrator pre_delegation STEP 0.5 — build diff-manifest.json:
           - Read prior review's canonical_issue_ids from review-completions.jsonl
           - Read prior plan's Part headings (.claude/prompts/{feature}.md)
           - Map each unresolved issue to a Part via regex '^Part (\d+):'
           - For each prior Part: NEEDS_UPDATE if mapped issues exist, else UNCHANGED
           - KD-6 fallback: if ANY issue's location is unmappable (no 'Part N:' prefix),
             flip ALL UNCHANGED entries to NEEDS_UPDATE (conservative) and log record_kind=
             imp04_unmapped_location to handoff-validation.jsonl
           - Write .claude/workflow-state/{feature}-diff-manifest.json (gitignored runtime artifact)
        2. Orchestrator re-invokes /planner with manifest reference prompt fragment
        3. Planner phase_0_8_prior_review_digest:
           - Reads prior plan + diff manifest (budget: 2 reads, 4 tool_calls)
           - Computes NEW Parts via Part-name set-diff
           - Preserves UNCHANGED Part bodies verbatim (byte-for-byte)
           - Addresses NEEDS_UPDATE Parts using manifest.reason active_issues
           - Emits '## Diff vs prior iteration' block at top of plan (MANDATORY iter 2+)
        4. Plan-reviewer step 3 (VALIDATE ARCHITECTURE):
           - Parses diff section; runs FULL validation only on NEEDS_UPDATE + NEW Parts
           - SKIPS architecture scan on UNCHANGED Parts (byte-for-byte integrity check only)
           - Emits parts_validated[] in VERDICT_JSON (IDs with full validation)
        5. Plan-reviewer step 3.5 (CONTRACT-BREAK GUARD):
           - Detects cross-Part signature changes (NEEDS_UPDATE Part signature flipped,
             UNCHANGED Part imports broken)
           - Emits BLOCKER with literal prefix 'IMP-04 contract break: Part '
        6. Orchestrator post_delegation step 2.5 — BLOCKER reroute:
           - Scan issues for BLOCKER with literal prefix 'IMP-04 contract break: Part '
           - On match: delete diff-manifest.json, log imp04_contract_break_reroute,
             re-route to Phase 1 with FULL RE-PLAN (iter counter NOT incremented —
             contract break is a routing step, not a new review iteration)
        7. Orchestrator appends pipeline-metrics.jsonl record with parts_total,
           parts_validated, parts_skipped_unchanged

    artifacts:
      diff_manifest:
        path: ".claude/workflow-state/{feature}-diff-manifest.json"
        lifetime: "runtime — regenerated every iter ≥2, deleted on contract-break reroute, gitignored"
        shape: |
          [
            {"part_id": int, "name": str, "status": "UNCHANGED"|"NEEDS_UPDATE"|"NEW", "reason": str},
            ...
          ]
      plan_diff_section:
        path: ".claude/prompts/{feature}.md (## Diff vs prior iteration block)"
        template: ".claude/templates/plan-template.md → diff_vs_prior_iteration"
        format: "YAML under diff_vs_prior_iteration key with prior_plan_ref + parts_diff[]"
      verdict_field:
        field: "parts_validated"
        schema: ".claude/schemas/handoff.schema.json → plan_review_verdict.properties.parts_validated"
        shape: "array of integers (Part IDs); optional; absent on iter 1 (section-absence signal)"
      metrics_record:
        path: ".claude/workflow-state/pipeline-metrics.jsonl"
        emitted_by: "orchestrator post_delegation on iter ≥2"
        fields: ["ts", "feature", "phase", "iteration", "parts_total", "parts_validated", "parts_skipped_unchanged", "verdict"]

    backward_compat:
      principle: "Section-absence signal — no env gate needed (KD-9)"
      iter_1_path: "No diff section in plan → plan-reviewer runs FULL architecture validation (AC-8). parts_validated[] absent from VERDICT_JSON."
      missing_manifest_path: "If {feature}-diff-manifest.json missing on iter 2+ (e.g. first run after feature rollout, or contract-break reroute), planner SKIPS phase_0.8 and writes iter-1-style plan → plan-reviewer runs FULL validation."
      schema_compat: "parts_validated[] is OPTIONAL in plan_review_verdict schema — prior VERDICT_JSON payloads continue to validate unchanged."

    fail_modes:
      - code: "imp04_unmapped_location"
        meaning: "Prior issue's location is NON-EMPTY but does not match '^Part (\\d+):' regex — reviewer-side KD-8 non-compliance (actionable)"
        action: "KD-6 conservative fallback: flip ALL UNCHANGED entries in manifest to NEEDS_UPDATE. Record written to handoff-validation.jsonl. Trend watch: high rate signals IMP-03 KD-8 location-format drift."
      - code: "imp04_cross_cutting_issue"
        meaning: "Prior issue has an EMPTY location — legitimate plan-wide/cross-cutting concern (informational, reviewer-correct)"
        action: "Same KD-6 fallback effect (all Parts → NEEDS_UPDATE), but record split from imp04_unmapped_location so telemetry can distinguish reviewer-bug from reviewer-correct-but-cross-cutting emissions. Informational only — no action required on elevated rate."
      - code: "imp04_contract_break_reroute"
        meaning: "Plan-reviewer step 3.5 detected cross-Part contract break; BLOCKER with literal prefix 'IMP-04 contract break: Part ' triggers orchestrator reroute"
        action: "Delete diff-manifest.json, re-route to Phase 1 with FULL RE-PLAN. iter counter NOT incremented (routing step, not review iteration). Log to handoff-validation.jsonl."
      - code: "missing_diff_section_iter2plus"
        meaning: "Iter ≥2 plan missing '## Diff vs prior iteration' section despite manifest presence"
        action: "Plan-reviewer runs FULL architecture validation (AC-8 backward-compat path). parts_validated[] absent from VERDICT_JSON. Planner plan-drift hook may log warning."

    metrics_guidance:
      - "parts_skipped_unchanged / parts_total — target: 50–70% on stable iter 2+ cycles (matches P-04 budget-savings estimate)"
      - "imp04_unmapped_location rate — target: <10% of iter-2 invocations (signals IMP-03 KD-8 compliance — reviewer-side actionable)"
      - "imp04_cross_cutting_issue rate — informational only (no target; legitimate plan-wide concerns)"
      - "imp04_contract_break_reroute rate — target: <5% of iter-2 invocations (high rate signals planner phase_0.8 correctness bug)"
