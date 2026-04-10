# Orchestration Core

---

## Pipeline & Phases

```mermaid
flowchart LR
    INPUT([Task]) --> TA[Phase 0.5\nTask Analysis]

    TA -->|S| PLN_MIN[/planner\n--minimal]
    TA -->|M| PLN[/planner]
    TA -->|L/XL| DES[/designer\nPhase 0.7]
    TA -->|M new/integ\noptional| DES

    DES -->|approved spec| PLN
    DES -->|rejected| USR([user])
    USR -->|feedback| DES

    PLN --> PR{plan-reviewer\nagent}
    PLN_MIN -->|S: skip| COD

    PR -->|APPROVED| COD[/coder]
    PR -->|NEEDS_CHANGES\nmax 3x| PLN
    PR -->|REJECTED| STOP_PR([STOP])

    COD --> EVAL{EVALUATE\nPROCEED/REVISE/RETURN}
    EVAL -->|RETURN| PLN
    EVAL -->|PROCEED/REVISE| IMPL[Implement Parts]

    IMPL --> SIMP{Simplify?\nL/XL + parts≥5}
    SIMP -->|Yes| SMP[/simplify]
    SIMP -->|No| VRF
    SMP --> VRF[VERIFY\nvet+fmt+lint+test]

    VRF -->|FAIL 3x| STOP_V([STOP])
    VRF -->|PASS| SC[SPEC CHECK\nPhase 3.5]
    SC -->|FAIL max 1x| VRF
    SC -->|PASS/PARTIAL| CR{code-reviewer\nagent\nworktree}

    CR -->|APPROVED\nAPPROVED_WITH_COMMENTS| COMP[Phase 5\nCompletion]
    CR -->|CHANGES_REQUESTED\nmax 3x| COD

    COMP --> GIT([git commit\n+ metrics])

    CR_RES[code-researcher\nhaiku] -.->|tool-assist L/XL| PLN
    CR_RES -.->|tool-assist evaluate| COD
```

**Phase 0.5 — Task Analysis:** Classify (type + S/M/L/XL) → Route. S: skip plan-review. L/XL: Sequential Thinking recommended/required.

**Phase 0.7 — Design (L/XL only):** Execute /designer. Output: `.claude/prompts/{feature}-spec.md`. User approval gate required. SKIP for S/M complexity.
- If user rejects design → iterate within /designer (not a pipeline loop — internal to designer)
- Checkpoint: `phase_completed: 0.7, phase_name: "design"`

**Phase 1 — Planning:** Execute /planner. If spec exists → planner references spec. Output: `.claude/prompts/{feature}.md`

**Phase 2 — Plan Review:** Delegate to plan-reviewer agent. APPROVED → Phase 3. NEEDS_CHANGES → Phase 1 (iteration N/3). REJECTED → Stop.

**Phase 3 — Implementation:** Execute /coder. Verify: `VERIFY` (Go default: go vet ./... && make fmt && make lint && make test). PASS → Spec Check (Phase 3.5). FAIL → fix + retry.

**Phase 3.5 — Spec Check:** Inline in /coder. Verifies plan compliance after VERIFY passes. PASS/PARTIAL → Phase 4. FAIL → inline fix (max 1 retry) → re-run VERIFY → re-check.

**Phase 4 — Code Review:** Before delegating, run `git worktree prune 2>/dev/null || true` to clean stale worktree metadata from crashed sessions. Delegate to code-reviewer agent. APPROVED → Done. APPROVED_WITH_COMMENTS → Done (log comments, proceed to completion). CHANGES_REQUESTED → Phase 3 (iteration N/3).

**Phase 2/4 — Incomplete Output Recovery:** If a review agent (plan-reviewer or code-reviewer) returns without a clear verdict:

1. Validate return text for verdict keyword (SEE workflow.md → output_validation)
2. If missing → check review-completions.jsonl (save-review-checkpoint.sh extracts verdict on SubagentStop via transcript). **Apply filter rules below** before treating any entry as authoritative.
3. If no matching entry OR verdict is UNKNOWN → **orchestrator direct transcript read** (P3-1): read the agent's transcript JSONL directly (path from review-completions.jsonl `agent_transcript_path` field or `.claude/workflow-state/worktree-events-debug.jsonl`), search for `VERDICT:` regex in last assistant messages. This makes the orchestrator self-reliant — not dependent solely on hook infrastructure.
4. If still no verdict → launch **verdict-recovery** agent (NOT re-launch of full plan-reviewer/code-reviewer). See .claude/agents/verdict-recovery.md — lightweight haiku, ~30s, no memory/skills/checklist.
5. If a matching entry exists but verdict is still UNKNOWN (IMP-H already blocked once and agent still failed) → launch **verdict-recovery** agent — do NOT re-block, do NOT re-launch full review agent.
6. If verdict recovered from checkpoint, direct transcript read, or verdict-recovery → continue pipeline normally.
7. If verdict-recovery also fails → WARN user, show filtered review-completions.jsonl data + agent output summary, request manual verdict.
8. Write checkpoint with `verdict: "INCOMPLETE"` and `recovery_attempted: true`.

**UNKNOWN verdict resolution rules (IMP-06):**

```yaml
phase_2_recovery:  # plan-reviewer
  step_1: "Read review-completions.jsonl → filter by session_id == current AND effective_agent_type == 'plan-reviewer'"
  step_2: "If no matching entry → check prior_failed_attempts in injected context (P1-3)"
  step_2a: "If prior_failed_attempts > 0 → review ran but verdict was lost → try direct transcript read (P3-1) → if still missing, launch verdict-recovery (scope: plan)"
  step_2b: "If prior_failed_attempts == 0 → genuine UNKNOWN, review never ran → launch verdict-recovery (scope: plan)"
  step_3: "If matching entry has verdict != UNKNOWN → use it, proceed"
  step_4: "If matching entry has verdict == UNKNOWN → IMP-H already blocked once; try direct transcript read (P3-1) → if still missing, launch verdict-recovery"
  step_5_direct_read: "P3-1 direct transcript read: locate transcript_path from review-completions.jsonl entry or worktree-events-debug.jsonl → read JSONL → reverse-search role:assistant for VERDICT: regex. Orchestrator-owned, no hook dependency."
  forbidden: "NEVER re-launch plan-reviewer from incomplete-output path. Only loop-limit retries (NEEDS_CHANGES) re-launch planner/plan-reviewer."

phase_4_recovery:  # code-reviewer
  step_1: "Read review-completions.jsonl → filter by session_id == current AND effective_agent_type == 'code-reviewer'"
  step_2: "If no matching entry → check prior_failed_attempts in injected context (P1-3)"
  step_2a: "If prior_failed_attempts > 0 → review ran but verdict was lost → try direct transcript read (P3-1) → if still missing, launch verdict-recovery (scope: code)"
  step_2b: "If prior_failed_attempts == 0 → genuine UNKNOWN, review never ran → launch verdict-recovery (scope: code)"
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

**review-completions.jsonl filter rules (IMP-02):**

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

**Phase 0 — Get Task (optional):** Parse task from user input. Skip if ad-hoc.

**Phase 5 — Completion:** After code-review APPROVED/APPROVED_WITH_COMMENTS:
1. Create git commit (MANDATORY)
   - Message format: `{type}({scope}): {description}` (types: feat|fix|refactor|test|docs|chore)
   - Body (optional): max 3 lines, include plan path + complexity + review iterations
   - Co-Authored-By: included by default (Claude Code system behavior)
   - To strip: `cp .claude/templates/git-hooks/commit-msg .git/hooks/commit-msg && chmod +x .git/hooks/commit-msg` + set `GIT_STRIP_CO_AUTHOR=true` in settings.local.json env
2. Collect pipeline metrics (SEE pipeline-metrics.md):
   a. Standard metrics: phases, iterations, complexity, issues, tools
   b. Code-researcher metrics: extract from Agent/Task tool return metadata (token count, tool uses, duration per invocation). Sum across all invocations in this pipeline run. Include background_mode_used flag.
   c. If code-researcher not invoked → set all code_researcher_metrics to 0
3. CronDelete — remove auto-save cron job (if active, L/XL tasks). Read cron_id from checkpoint, call CronDelete. If CronDelete unavailable → WARN, job will expire with session.
4. Write final checkpoint: `phase_completed: 5, phase_name: "completion"`
5. Clean up session-specific state files (SEE state-layer.md cleanup_protocol):
   - Delete: review-completions.jsonl, task-events.jsonl, worktree-events-debug.jsonl, hook-log.txt
   - Delete LAST: {feature}-checkpoint.yaml (steps 1-4 may still reference it)
   - Preserve: pipeline-metrics.jsonl, session-analytics.jsonl, config-changes.jsonl
   - Failure: NON_CRITICAL — warn but do not block commit

**Note:** Completion is orchestrator-owned (not delegated to agent or sub-command).

---

## Loop Limits

```yaml
plan_review_cycle: max 3 iterations (planner ↔ plan-review)
code_review_cycle: max 3 iterations (coder ↔ code-review)
total_phases: max 12 per /workflow run
on_exceeded: STOP → summary of each iteration → unresolved issues → request user intervention

tracking_protocol:
  owner: "workflow orchestrator (NOT review agents)"
  storage:
    primary: "checkpoint yaml → iteration.plan_review / iteration.code_review"
    transport: "handoff payload → iteration field"

  increment_rules:
    - trigger: "plan-review verdict = NEEDS_CHANGES"
      action: "plan_review_counter += 1"
      then: "Append issues_history entry (phase=2, verdict, issues, resolved=[]) → Guard check → write checkpoint → re-run /planner"
      resolved_population: "pre_delegation step (before next plan-reviewer launch) populates resolved[] in previous entry from planner handoff"
    - trigger: "code-review verdict = CHANGES_REQUESTED"
      action: "code_review_counter += 1"
      then: "Append issues_history entry (phase=4, verdict, issues, resolved=[]) → Guard check → write checkpoint → re-run /coder"
      resolved_population: "pre_delegation step (before next code-reviewer launch) populates resolved[] in previous entry from coder handoff"

  guard_check:
    when: "BEFORE launching re-loop phase (planner or coder)"
    logic: |
      if counter >= 3:
        STOP → show iteration_summary → request user intervention
      else:
        proceed with iteration {counter}/3
    critical: "Guard runs BEFORE phase launch, not after verdict"

  counter_recovery:
    description: "When checkpoint is missing, infer iteration count from available signals"
    strategy:
      step_1: "Check handoff payload in current context → read iteration field"
      step_2: "If no handoff → count issues_history entries for this cycle in context"
      step_3: "If no context → git log --oneline | grep 'plan-review\\|code-review' (count re-runs)"
      step_4: "If nothing found → assume iteration 1/3 (conservative) + WARN user"
    warning: "Heuristic recovery is imprecise. After recovery, ALWAYS write checkpoint immediately."

  iteration_summary_on_stop:
    format: |
      ## Loop Limit Reached ({cycle_name}: {N}/3)
      | Iteration | Verdict | Key Issues |
      |-----------|---------|------------|
      | 1/3 | NEEDS_CHANGES | {issues from iteration 1} |
      | 2/3 | NEEDS_CHANGES | {issues from iteration 2} |
      | 3/3 | NEEDS_CHANGES | {unresolved issues} |
      **Unresolved:** {list of persisting issues across all iterations}
      **Recommendation:** {simplify scope | provide specific guidance | split task}
```

---

## Session Recovery

**Strategy:** Checkpoint-first, heuristic fallback.

**Quick check commands:**
```
ls .claude/workflow-state/*-checkpoint.yaml  # Checkpoint?
ls .claude/prompts/*-spec.md                  # Spec?
ls .claude/prompts/                          # Plan?
ls .claude/prompts/*-evaluate.md              # Evaluate output?
git diff $(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || echo main)...HEAD --stat  # Code changes?
TEST                                         # Tests pass? (Go default: make test)
```

**Step 1:** Check `.claude/workflow-state/*-checkpoint.yaml`

**Step 2A — Checkpoint found:** Read → verify integrity → check for mid-phase progress → resume.
- If `implementation_progress.auto_saved=true`: resume Phase 3 from Part `parts_completed + 1` (skip completed Parts). Re-create cron auto-save (startup step 3).
- Otherwise: standard resume from `phase_completed + 1` → restore iteration counters.

**Step 2B — No checkpoint (heuristic):**

**Pre-planning recovery:**

| Spec exists? | Plan exists? | Resume from |
|---|---|---|
| No | No | Phase 0.7: Design (if L/XL) or Phase 1: Planning (S/M) |
| Yes (approved) | No | Phase 1: Planning (spec done, skip design) |

**Post-planning recovery:**

| Plan exists? | Evaluate exists? | Code changes? | Tests pass? | Resume from                                          |
| ------------ | ---------------- | ------------- | ----------- | ---------------------------------------------------- |
| No           | —                | —             | —           | Phase 1: Planning                                    |
| Yes          | No               | No            | —           | Phase 3: Implementation (start with evaluate)        |
| Yes          | Yes              | No            | —           | Phase 3: Implementation (evaluate done, start coding)|
| Yes          | Yes              | Yes           | No          | Phase 3: Fix tests                                   |
| Yes          | Yes              | Yes           | Yes         | Phase 4: Code Review                                 |

**Warning:** Heuristic fallback loses iteration counters — assume iteration 1/3.

**Note:** If checkpoint shows `phase_completed: 4` with `verdict: APPROVED` → resume from Phase 5 (Completion).

**Checkpoint format:** `{feature}-checkpoint.yaml` with fields: feature, phase_completed, phase_name, iteration (plan_review N/3, code_review N/3), verdict, timestamp, complexity, route, handoff_payload, issues_history. Full specification: SEE [checkpoint-protocol.md] in workflow-protocols skill.
