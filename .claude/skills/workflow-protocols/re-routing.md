# Re-Routing Protocol

purpose: "Self-correcting pipeline — route change on incorrect classification"

---

re_routing:
  severity: MEDIUM

  triggers:
    - trigger: "plan-review finds the plan too simple for the current route"
      action: "Downgrade route"
      examples:
        - "L→M: plan turned out < 3 Parts, remove mandatory Sequential Thinking"
        - "M→S: only 1 Part, 1 layer — skip plan-review in next iteration"
    - trigger: "plan-review finds the plan too complex for the current route"
      action: "Upgrade route"
      examples:
        - "S→M: cross-layer dependencies discovered — add full plan-review"
        - "M→L: 4+ Parts, 3+ layers — add Sequential Thinking"
    - trigger: "coder evaluate finds hidden complexity"
      action: "Upgrade route or RETURN to planner"
      examples:
        - "M→L: evaluate discovered DB migration needed (not accounted for in plan)"

  tracking:
    when: "Immediately when the re-routing decision is made (before continuing pipeline)"
    action: "Update checkpoint re_routing fields"
    fields:
      occurred: true
      original_route: "{route from task-analysis}"
      new_route: "{new route after re-routing}"
      reason: "{1-sentence: trigger + evidence}"
      phase: "{phase that triggered re-routing}"
    note: "pipeline_metrics reads re_routing data from checkpoint at completion"
  learning: "Re-routing data captured in checkpoint and pipeline-metrics.jsonl for pattern analysis"

  verdict_aliases:
    purpose: "Normalize legacy verdict variants to canonical forms before routing"
    rules:
      - source: "code_review_verdict"
        legacy_alias: "NEEDS_CHANGES"
        canonical: "CHANGES_REQUESTED"
        rationale: |
          Schema 1.1.0+ keeps NEEDS_CHANGES in code_review_verdict.enum for cross-version
          compatibility (legacy review-completions.jsonl entries). Orchestrator MUST treat
          NEEDS_CHANGES from code-reviewer identically to CHANGES_REQUESTED:
          - increment code_review counter
          - append issues_history entry (phase=4)
          - re-route to Phase 3 (/coder) via review-response.md path
        when_emitted: |
          Reviewer agents are instructed to PREFER CHANGES_REQUESTED. NEEDS_CHANGES may still occur via:
          - regex_fallback path in save-review-checkpoint.sh (non-deterministic agent text)
          - verdict-recovery agent on incomplete-output recovery
          - legacy review-completions.jsonl restore on session resume
        telemetry:
          record_kind: "verdict_alias_normalized"
          file: ".claude/workflow-state/handoff-validation.jsonl"
          payload:
            ts: "ISO-8601 UTC"
            agent: "code-reviewer"
            original_verdict: "NEEDS_CHANGES"
            normalized_verdict: "CHANGES_REQUESTED"
            iteration: "{N}/3"
            session_id: "{session_id}"
      - source: "plan_review_verdict"
        note: |
          plan_review_verdict.enum already canonicalises NEEDS_CHANGES (the authoritative
          variant for plan-review). No alias normalisation needed.
