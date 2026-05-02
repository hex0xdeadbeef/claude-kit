---
name: incomplete-output-recovery
description: "Fallback chain for INCOMPLETE verdict output from plan-reviewer / code-reviewer. Load ONLY when orchestrator detects missing/malformed VERDICT after a review agent completes. Contains: output_validation checks, on_incomplete_output 6-step fallback chain (step_0 IMP-02 structured JSON primary → step_5 manual user), common_causes."
disable-model-invocation: true
---

# Incomplete Output Recovery

## When to load

Load this file ONLY when a review agent (plan-reviewer or code-reviewer) returns
without a clear VERDICT line — i.e., output_validation detects INCOMPLETE_OUTPUT.
Do NOT load at workflow startup or before delegation.

## output_validation

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
    step_0: "IMP-02 structured JSON path — check .claude/workflow-state/review-completions.jsonl for the latest entry. If verdict_source == \"structured_json\", the hook parsed a VERDICT_JSON fenced block from the agent transcript. WARN-MODE CAVEAT (CR-003): in the default CLAUDE_VERDICT_VALIDATION_MODE=warn, the validator exits rc=0 even on JSON Schema failure, so a schema-INVALID payload is recorded under the same verdict_source=\"structured_json\" label. BEFORE trusting the fast path, the orchestrator MUST cross-reference .claude/workflow-state/handoff-validation.jsonl for record_kind: \"verdict_schema_invalid\" entries that match the same agent_id + iteration as the marker line; if a match is found, treat the marker as INCOMPLETE_OUTPUT and proceed to step_1. If no match is found OR if CLAUDE_VERDICT_VALIDATION_MODE=strict (in which case verdict_source becomes \"structured_json_schema_invalid\" on failure and the regex fallback rescues the run), proceed to verdict routing using the verdict + issues + handoff from the marker file. The cross-reference is the only defense for warn-mode consumers."
    step_1: "Check .claude/workflow-state/review-completions.jsonl — save-review-checkpoint.sh extracts verdict via regex on SubagentStop. If verdict found → use it, proceed with minimal handoff (verdict only, no detailed issues)."
    step_2: "If verdict found in review-completions.jsonl → extract it, proceed normally with minimal handoff"
    step_3: "P3-1 direct transcript read — if no verdict in review-completions.jsonl, orchestrator reads agent transcript JSONL directly (agent_transcript_path from review-completions entry or worktree-events-debug.jsonl). Reverse-search role:assistant messages for VERDICT: regex. Defense-in-depth — orchestrator is self-reliant, not solely dependent on hook infrastructure."
    step_4: "If still no verdict → launch verdict-recovery agent (NOT full code-reviewer). verdict-recovery is a lightweight agent (maxTurns: 10, haiku, no memory, no skills, no TodoWrite) that reads the diff and outputs ONLY a verdict + brief handoff. See .claude/agents/verdict-recovery.md."
    step_5: "If verdict-recovery also fails or returns no verdict → WARN user, show what information is available (review-completions.jsonl, agent output summary), ask for manual verdict decision"
    max_retries: 1
    note: "step_0 (IMP-02) is the preferred primary path: structured JSON eliminates regex false-positives and enables schema-validated handoff propagation. **Warn-mode users:** step_0's verdict_source==\"structured_json\" check is necessary but not sufficient — always cross-reference handoff-validation.jsonl for record_kind: \"verdict_schema_invalid\" before trusting the marker (see CR-003 in handoff-protocol.md). Strict-mode users: step_0 is sufficient — verdict_source becomes \"structured_json_schema_invalid\" on failure and the regex fallback (step_1) is taken automatically. steps 1–5 remain as the defense-in-depth fallback chain for agents that emit malformed JSON or skip the VERDICT_JSON block entirely. step_1 leverages save-review-checkpoint.sh which already runs on SubagentStop and extracts verdict via regex as fallback. step_3 (P3-1) makes orchestrator independent of hook success — reads transcript directly. step_4 uses verdict-recovery agent instead of re-launching full code-reviewer — ~30s vs ~5min."

  common_causes:
    - "Agent exhausted maxTurns on memory operations (SEE RULE_5 in agent artifacts)"
    - "Agent got stuck in a long Sequential Thinking chain"
    - "Agent produced output but in unexpected format"
