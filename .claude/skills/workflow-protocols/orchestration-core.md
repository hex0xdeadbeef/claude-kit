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
    SIMP -->|Yes| SMP["/simplify (cleanup-only review)"]
    SIMP -->|No| VRF
    SMP --> VRF[VERIFY\nvet+fmt+lint+test]

    VRF -->|FAIL 3x| STOP_V([STOP])
    VRF -->|PASS| SC[SPEC CHECK\nPhase 3.5]
    SC -->|FAIL max 1x| VRF
    SC -->|PASS/PARTIAL| CR{code-reviewer\nagent\nworktree}

    CR -->|APPROVED\nAPPROVED_WITH_COMMENTS| COMP[Phase 5\nCompletion]
    CR -->|"CHANGES_REQUESTED | NEEDS_CHANGES (alias)\nmax 3x"| COD

    COMP --> GIT([git commit\n+ metrics])

    CR_RES[code-researcher\nhaiku] -.->|tool-assist L/XL| PLN
    CR_RES -.->|tool-assist evaluate| COD
```

**Phase 0.5 — Task Analysis:** Classify (type + S/M/L/XL) → Route. S: skip plan-review. L/XL: Sequential Thinking recommended/required.

**Phase 0.7 — Design (L/XL only):** Execute /designer — invoke it with the Skill tool by name, `designer` (plugin mode: `claude-kit:designer`). Output: `.claude/prompts/{feature}-spec.md`. User approval gate required. SKIP for S/M complexity.
- The orchestrator never performs the design phase itself: no self-written draft, no ad-hoc critic subagents. Phase 3.5 CRITIQUE is 7 in-context lenses inside /designer.
- If user rejects design → iterate within /designer (not a pipeline loop — internal to designer)
- Checkpoint: `phase_completed: 0.7, phase_name: "design"`
- Before Phase 1 starts, the unconditional `pipeline.spec_gate` (workflow.md) must pass: on the L/XL route a missing or unapproved spec is FATAL, not a silent skip.

**Phase 1 — Planning:** Execute /planner. If spec exists → planner references spec. Output: `.claude/prompts/{feature}.md`

**Phase 2 — Plan Review:** Delegate to plan-reviewer agent. APPROVED → Phase 3. NEEDS_CHANGES → Phase 1 (iteration N/3). REJECTED → Stop.

**Phase 3 — Implementation:** Execute /coder. Verify: `VERIFY` (Go default: go vet ./... && make fmt && make lint && make test). PASS → Spec Check (Phase 3.5). FAIL → fix + retry.

**Phase 3.5 — Spec Check:** Inline in /coder. Verifies plan compliance after VERIFY passes. PASS/PARTIAL → Phase 4. FAIL → inline fix (max 1 retry) → re-run VERIFY → re-check.

**Phase 4 — Code Review:** Before delegating, run `git worktree prune 2>/dev/null || true` to clean stale worktree metadata from crashed sessions. Delegate to code-reviewer agent. APPROVED → Done. APPROVED_WITH_COMMENTS → Done (log comments, proceed to completion). CHANGES_REQUESTED OR NEEDS_CHANGES (legacy alias, normalized to CHANGES_REQUESTED) → Phase 3 (iteration N/3). Alias normalization emits `record_kind: "verdict_alias_normalized"` to handoff-validation.jsonl (see re-routing.md → verdict_aliases).

**Phase 2/4 — Incomplete Output Recovery:** If a review agent (plan-reviewer or code-reviewer) returns without a clear verdict, the orchestrator runs an 8-step recovery procedure: filter review-completions.jsonl → direct transcript read (P3-1) → launch lightweight verdict-recovery agent if needed. This scenario is rare (after RULE_5 "Output First" was added to agents) but the recovery path is mandatory when triggered.

→ 8-step procedure + IMP-06 UNKNOWN rules + IMP-02 filter predicates + anti-patterns → SEE [unknown-verdict-recovery.md](unknown-verdict-recovery.md).

**Phase 0 — Get Task (optional):** Parse task from user input. Skip if ad-hoc.

**Phase 5 — Completion:** After code-review APPROVED/APPROVED_WITH_COMMENTS:
1. Create git commit (MANDATORY)
   - Message format: `{type}({scope}): {description}` (types: feat|fix|refactor|test|docs|chore)
   - Body (optional): max 3 lines, include plan path + complexity + review iterations
   - Co-Authored-By: included by default. To strip: `cp .claude/templates/git-hooks/commit-msg .git/hooks/commit-msg && chmod +x .git/hooks/commit-msg` + set `GIT_STRIP_CO_AUTHOR=true` in settings.local.json env.
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
    - trigger: "code-review verdict = NEEDS_CHANGES (legacy alias)"
      action: "code_review_counter += 1 (treated identically to CHANGES_REQUESTED via re-routing.md → verdict_aliases)"
      then: "Normalize verdict to CHANGES_REQUESTED → append issues_history entry (phase=4, verdict=CHANGES_REQUESTED, original_verdict=NEEDS_CHANGES, issues, resolved=[]) → emit `verdict_alias_normalized` telemetry record → Guard check → write checkpoint → re-run /coder"
      telemetry: |
        Append to .claude/workflow-state/handoff-validation.jsonl:
          {
            "ts": "{ISO-8601 UTC}",
            "record_kind": "verdict_alias_normalized",
            "agent": "code-reviewer",
            "original_verdict": "NEEDS_CHANGES",
            "normalized_verdict": "CHANGES_REQUESTED",
            "iteration": "{N}/3",
            "session_id": "{session_id}"
          }

  guard_check:
    when: "BEFORE launching re-loop phase (planner or coder)"
    logic: |
      if counter >= 3:
        STOP → show iteration_summary → request user intervention
      else:
        proceed with iteration {counter}/3
    critical: "Guard runs BEFORE phase launch, not after verdict"
```

→ For `counter_recovery` heuristic (checkpoint missing) and `iteration_summary_on_stop` format template (3/3 loop-limit user-facing STOP message) → SEE [counter-recovery.md](counter-recovery.md).

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

**Warning:** Heuristic fallback loses iteration counters — assume iteration 1/3. (For the inference heuristic itself — see Loop Limits pointer above.)

**Note:** If checkpoint shows `phase_completed: 4` with `verdict: APPROVED` → resume from Phase 5 (Completion).

**Checkpoint format:** `{feature}-checkpoint.yaml` with fields: feature, phase_completed, phase_name, iteration (plan_review N/3, code_review N/3), verdict, timestamp, complexity, route, handoff_payload, issues_history. Full specification: SEE [checkpoint-protocol.md](checkpoint-protocol.md).

---

## Cost Optimization

**Prompt cache TTL for XL sessions** → SEE [CLAUDE.md § Prompt Cache Policy](../../../CLAUDE.md#prompt-cache-policy) for the authoritative reference (platform defaults, opt-in/override env variables, warm-up behavior).
