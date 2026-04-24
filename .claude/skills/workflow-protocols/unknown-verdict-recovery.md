---
name: unknown-verdict-recovery
description: "IMP-06 UNKNOWN verdict resolution rules + IMP-02 review-completions.jsonl filter predicates + anti-patterns + cost comparison. Load only when an INCOMPLETE verdict is detected in Phase 2 (plan-reviewer) or Phase 4 (code-reviewer)."
disable-model-invocation: true
---

# Unknown Verdict Recovery

Load trigger: INCOMPLETE verdict returned from plan-reviewer (Phase 2) or code-reviewer (Phase 4) — referenced from [Orchestration Core](orchestration-core.md) § Phase 2/4 Incomplete Output Recovery.

---

## Phase 2/4 Incomplete Output Recovery

If a review agent (plan-reviewer or code-reviewer) returns without a clear verdict:

1. Validate return text for verdict keyword (SEE incomplete-output-recovery.md → output_validation)
2. If missing → check review-completions.jsonl (save-review-checkpoint.sh extracts verdict on SubagentStop via transcript). **Apply filter rules below** before treating any entry as authoritative.
3. If no matching entry OR verdict is UNKNOWN → **orchestrator direct transcript read** (P3-1): read the agent's transcript JSONL directly (path from review-completions.jsonl `agent_transcript_path` field or `.claude/workflow-state/worktree-events-debug.jsonl`), search for `VERDICT:` regex in last assistant messages. This makes the orchestrator self-reliant — not dependent solely on hook infrastructure.
4. If still no verdict → launch **verdict-recovery** agent (NOT re-launch of full plan-reviewer/code-reviewer). See .claude/agents/verdict-recovery.md — lightweight haiku, ~30s, no memory/skills/checklist.
5. If a matching entry exists but verdict is still UNKNOWN (IMP-H already blocked once and agent still failed) → launch **verdict-recovery** agent — do NOT re-block, do NOT re-launch full review agent.
6. If verdict recovered from checkpoint, direct transcript read, or verdict-recovery → continue pipeline normally.
7. If verdict-recovery also fails → WARN user, show filtered review-completions.jsonl data + agent output summary, request manual verdict.
8. Write checkpoint with `verdict: "INCOMPLETE"` and `recovery_attempted: true`.

---

## UNKNOWN verdict resolution rules (IMP-06)

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
