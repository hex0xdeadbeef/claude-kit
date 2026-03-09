# Orchestration Core

---

## Pipeline & Phases

```
task-analysis → /planner → plan-reviewer (agent) → /coder → code-reviewer (agent)
     ↓              ↓              ↓                  ↓              ↓
  Classify        Plan       Validation             Code         Review
  S → skip PR              ↓ FAIL         ↓ FAIL
                          ← back ←       ← back ←
                          (max 3x)       (max 3x)
```

**Phase 0.5 — Task Analysis:** Classify (type + S/M/L/XL) → Route. S: skip plan-review. L/XL: Sequential Thinking recommended/required.

**Phase 1 — Planning:** Execute /planner. Output: `.claude/prompts/{feature}.md`

**Phase 2 — Plan Review:** Delegate to plan-reviewer agent. APPROVED → Phase 3. NEEDS_CHANGES → Phase 1 (iteration N/3). REJECTED → Stop.

**Phase 3 — Implementation:** Execute /coder. Verify: `VERIFY` (Go default: make fmt && make lint && make test). PASS → Phase 4. FAIL → fix + retry.

**Phase 4 — Code Review:** Delegate to code-reviewer agent. APPROVED → Done. CHANGES_REQUESTED → Phase 3 (iteration N/3).

**Phase 0 — Get Task (optional):** If beads task → `bd show <id>` + `bd update <id> --status=in_progress`. Skip if ad-hoc.

**Completion:** git commit (required) → bd sync (if beads) → remind bd close → save lessons if non-trivial.

**Lessons learned format (if saving):** create_entities with entityType="lessons_learned", observations: ["Problem: X → Solution: Y", "Pattern: Z works well for W"].

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
      then: "Guard check → write checkpoint → re-run /planner"
    - trigger: "code-review verdict = CHANGES_REQUESTED"
      action: "code_review_counter += 1"
      then: "Guard check → write checkpoint → re-run /coder"

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
ls .claude/prompts/                          # Plan?
bd list --status=in_progress                 # Active beads?
git diff master...HEAD --stat                # Code changes?
TEST                                         # Tests pass? (Go default: make test)
```

**Step 1:** Check `.claude/workflow-state/*-checkpoint.yaml`

**Step 2A — Checkpoint found:** Read → verify integrity → resume from `phase_completed + 1` → restore iteration counters.

**Step 2B — No checkpoint (heuristic):**

| Plan exists? | Code changes? | Tests pass? | Resume from |
|-------------|---------------|-------------|-------------|
| No | — | — | Phase 1: Planning |
| Yes | No | — | Phase 3: Implementation |
| Yes | Yes | No | Phase 3: Fix tests |
| Yes | Yes | Yes | Phase 4: Code Review |

**Warning:** Heuristic fallback loses iteration counters — assume iteration 1/3.

**Checkpoint format:** `{feature}-checkpoint.yaml` with fields: feature, phase_completed, phase_name, iteration (plan_review N/3, code_review N/3), verdict, timestamp, complexity, route, handoff_payload, issues_history. Full specification: SEE [checkpoint-protocol.md] in workflow-protocols skill.
