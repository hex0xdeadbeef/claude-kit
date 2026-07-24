---
name: incomplete-output-recovery
description: "Fallback chain for INCOMPLETE verdict output from plan-reviewer / code-reviewer. Load ONLY when orchestrator detects missing/malformed VERDICT after a review agent completes. Contains: output_validation checks, on_incomplete_output 6-step fallback chain (step_0 IMP-02 structured JSON primary → step_5 manual user), common_causes, IMP-06 UNKNOWN verdict resolution rules (phase_2_recovery / phase_4_recovery), and IMP-02 review-completions.jsonl filter predicates + anti-patterns."
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
    step_0: |
      IMP-02 structured JSON path — check .claude/workflow-state/review-completions.jsonl for the latest entry.
      (a) Semantics: if verdict_source == "structured_json", the hook parsed a VERDICT_JSON fenced block from the agent transcript.
      (b) WARN-MODE CAVEAT (CR-003): in the default CLAUDE_VERDICT_VALIDATION_MODE=warn, the validator exits rc=0 even on JSON Schema failure, so a schema-INVALID payload is recorded under the same verdict_source="structured_json" label.
      (c) STRICT-MODE path: with CLAUDE_VERDICT_VALIDATION_MODE=strict, verdict_source becomes "structured_json_schema_invalid" on failure and the regex fallback (step_1) rescues the run automatically — step_0 is sufficient as-is.
      (d) Cross-reference protocol (warn-mode only): BEFORE trusting the fast path, the orchestrator MUST cross-reference .claude/workflow-state/handoff-validation.jsonl for record_kind: "verdict_schema_invalid" entries that match the same agent_id + iteration as the marker line. If a match is found, treat the marker as INCOMPLETE_OUTPUT and proceed to step_1. If no match is found, proceed to verdict routing using the verdict + issues + handoff from the marker file.
      (e) The cross-reference is the only defense for warn-mode consumers.
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

---

## UNKNOWN verdict resolution rules (IMP-06)

Load trigger: same as this file — an INCOMPLETE verdict from plan-reviewer (Phase 2) or code-reviewer (Phase 4). Apply these rules together with the `output_validation` fallback chain above.

**Terminal step:** after the fallback chain is exhausted (or an INCOMPLETE verdict persists), write checkpoint with `verdict: "INCOMPLETE"` and `recovery_attempted: true`.

```yaml
phase_2_recovery:  # plan-reviewer
  step_1: "Read review-completions.jsonl → filter by session_id == current AND effective_agent_type == 'plan-reviewer'"
  step_2: "If no matching entry → check injected context (P1-3) for line matching 'prior_failed_attempts: N' (where N is an integer)"
  step_2a: "If prior_failed_attempts > 0 → review ran but verdict was lost → try direct transcript read (P3-1) → if still missing, launch verdict-recovery (scope: plan)"
  step_2b: "If prior_failed_attempts == 0 or line absent → genuine UNKNOWN, review never ran → launch verdict-recovery (scope: plan)"
  step_3: "If matching entry has verdict != UNKNOWN → use it, proceed"
  step_4: "If matching entry has verdict == UNKNOWN → IMP-H already blocked once; try direct transcript read (P3-1) → if still missing, launch verdict-recovery"
  step_5_direct_read: "P3-1 direct transcript read: locate transcript_path from review-completions.jsonl entry or worktree-events-debug.jsonl → read JSONL → reverse-search role:assistant for VERDICT: regex. Orchestrator-owned, no hook dependency."
  forbidden: "NEVER re-launch plan-reviewer from incomplete-output path. Only loop-limit retries (NEEDS_CHANGES) re-launch planner/plan-reviewer."

phase_4_recovery:  # code-reviewer
  step_1: "Read review-completions.jsonl → filter by session_id == current AND effective_agent_type == 'code-reviewer'"
  step_2: "If no matching entry → check injected context (P1-3) for line matching 'prior_failed_attempts: N' (where N is an integer)"
  step_2a: "If prior_failed_attempts > 0 → review ran but verdict was lost → try direct transcript read (P3-1) → if still missing, launch verdict-recovery (scope: code)"
  step_2b: "If prior_failed_attempts == 0 or line absent → genuine UNKNOWN, review never ran → launch verdict-recovery (scope: code)"
  step_3: "If matching entry has verdict != UNKNOWN → use it, proceed"
  step_4: "If matching entry has verdict == UNKNOWN → IMP-H already blocked once; try direct transcript read (P3-1) → if still missing, launch verdict-recovery"
  step_5_direct_read: "P3-1 direct transcript read: locate agent_transcript_path from review-completions.jsonl entry or worktree-events-debug.jsonl → read JSONL → reverse-search role:assistant for VERDICT: regex. For code-reviewer (worktree agent), agent_transcript_path is the primary source."
  forbidden: "NEVER re-launch plan-reviewer when Phase 4 is active. NEVER re-launch full code-reviewer from incomplete-output path."

anti_patterns:
  wrong_1:
    symptom: "Orchestrator sees last entry in review-completions.jsonl is {agent:'unknown', verdict:'UNKNOWN'} and re-launches plan-reviewer"
    why_wrong: "Entry is noise (payload with empty agent_type OR stale cross-session record). Must filter by effective_agent_type + session_id first."
    right: "Filter first (IMP-02). If filtered result is empty → verdict-recovery, not plan-reviewer re-launch."
  wrong_2:
    symptom: "During Phase 4 (code review), orchestrator re-launches plan-reviewer because review-completions.jsonl has an UNKNOWN entry"
    why_wrong: "Phase-agent mismatch. Phase 4 UNKNOWN resolution must target code-reviewer's output only."
    right: "Filter by the agent owning the current phase (plan-reviewer for phase 2, code-reviewer for phase 4)."
  wrong_3:
    symptom: "Re-launch full plan-reviewer/code-reviewer (5+ min, memory, skills) on incomplete output"
    why_wrong: "Same agent just failed to output verdict. Re-running won't help and costs 10x verdict-recovery."
    right: "Use verdict-recovery (~30s, haiku, no memory/skills). Full-agent re-launch reserved for NEEDS_CHANGES/CHANGES_REQUESTED loop."

cost_comparison:
  verdict_recovery: "~30s, haiku, maxTurns:10, no memory, no skills — designed for this"
  full_reviewer_relaunch: "~5min, sonnet, maxTurns:60, full memory+skills stack — overkill and likely to fail again for same reason"
```

---

## review-completions.jsonl filter rules (IMP-02)

When reading `review-completions.jsonl` for verdict recovery or prior-iteration context, the orchestrator MUST read from BOTH primary and fallback locations (P3-3), then filter entries:

- Primary: `.claude/workflow-state/review-completions.jsonl`
- Fallback: `/tmp/claude-review-completions-fallback.jsonl` (written by IMP-06 when primary write fails)
- Deduplicate by `(session_id, completed_at, agent)` before filtering

```yaml
filter_predicate:
  session_id: "== current session_id"
  effective_agent_type:
    in: ["plan-reviewer", "code-reviewer"]  # ignore "unknown" — noise
    must_match: "the agent phase just delegated (phase 2 → plan-reviewer, phase 4 → code-reviewer)"
  optional_cross_check:
    agent_id: "present in agent-id-registry.jsonl for current session"
    rationale: "double-guard — only trust entries whose agent_id was registered at SubagentStart"

schema_note: |
  Entries have two fields since IMP-05:
    - "agent"               → raw payload agent_type (may be "unknown" for worktree agents)
    - "effective_agent_type" → post-registry-recovery value (always present, authoritative)
  ALWAYS filter on "effective_agent_type", NEVER on raw "agent".

rationale: |
  Without filtering, an "unknown" entry left over from a prior pipeline run or
  a noise SubagentStop from an unrelated subagent would be mistaken for a
  missing verdict from plan-reviewer, triggering an unnecessary re-launch (RC-4).
```

**Note:** This scenario is rare after RULE_5 (Output First) was added to agents. But validation remains as a safety net.
