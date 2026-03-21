# Orchestration Core

---

## Pipeline & Phases

```
task-analysis → /planner → plan-reviewer (agent) → /coder → code-reviewer (agent) → completion
     ↓              ↓              ↓                  ↓              ↓                    ↓
  Classify        Plan       Validation             Code         Review              Commit+Metrics
  S → skip PR              ↓ FAIL         ↓ FAIL
                          ← back ←       ← back ←
                          (max 3x)       (max 3x)
```

**Phase 0.5 — Task Analysis:** Classify (type + S/M/L/XL) → Route. S: skip plan-review. L/XL: Sequential Thinking recommended/required.

**Phase 1 — Planning:** Execute /planner. Output: `.claude/prompts/{feature}.md`

**Phase 2 — Plan Review:** Delegate to plan-reviewer agent. APPROVED → Phase 3. NEEDS_CHANGES → Phase 1 (iteration N/3). REJECTED → Stop.

**Phase 3 — Implementation:** Execute /coder. Verify: `VERIFY` (Go default: go vet ./... && make fmt && make lint && make test). PASS → Phase 4. FAIL → fix + retry.

**Phase 4 — Code Review:** Delegate to code-reviewer agent. APPROVED → Done. APPROVED_WITH_COMMENTS → Done (log comments, proceed to completion). CHANGES_REQUESTED → Phase 3 (iteration N/3).

**Phase 2/4 — Incomplete Output Recovery:** If a review agent (plan-reviewer or code-reviewer) returns without a clear verdict:

1. Validate return text for verdict keyword (SEE workflow.md → output_validation)
2. If missing → SendMessage to the same agent requesting verdict only (1 retry, use agentId)
3. If verdict recovered → continue pipeline normally
4. If unrecoverable → WARN user with available agent summary, request manual verdict decision
5. Write checkpoint with `verdict: "INCOMPLETE"` and `recovery_attempted: true`

**Note:** This scenario is rare after RULE_5 (Output First) was added to agents. But validation remains as a safety net.

**Phase 0 — Get Task (optional):** If beads task → `bd show <id>` + `bd update <id> --status=in_progress`. Skip if ad-hoc.

**Phase 5 — Completion:** After code-review APPROVED/APPROVED_WITH_COMMENTS:
1. Create git commit (MANDATORY)
   - Message format: `{type}({scope}): {description}` (types: feat|fix|refactor|test|docs|chore)
   - Body (optional): max 3 lines, include plan path + complexity + review iterations
   - Co-Authored-By: included by default (Claude Code system behavior)
   - To strip: `cp .claude/templates/git-hooks/commit-msg .git/hooks/commit-msg && chmod +x .git/hooks/commit-msg` + set `GIT_STRIP_CO_AUTHOR=true` in settings.local.json env
2. Run `bd sync` (if beads active)
3. Remind user to run `bd close <id>` (do NOT auto-close)
4. Collect pipeline metrics (SEE pipeline-metrics.md):
   a. Standard metrics: phases, iterations, complexity, issues, tools
   b. Code-researcher metrics: extract from Agent/Task tool return metadata (token count, tool uses, duration per invocation). Sum across all invocations in this pipeline run. Include background_mode_used flag.
   c. If code-researcher not invoked → set all code_researcher_metrics to 0
5. CronDelete — remove auto-save cron job (if active, L/XL tasks). Read cron_id from checkpoint, call CronDelete. If CronDelete unavailable → WARN, job will expire with session.
6. Save lessons_learned to Memory (if non-trivial — SEE mcp-tools.md entity templates)
7. Write final checkpoint: `phase_completed: 5, phase_name: "completion"`

**Note:** Completion is orchestrator-owned (not delegated to agent or sub-command).

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
ls .claude/prompts/*-evaluate.md              # Evaluate output?
bd list --status=in_progress                 # Active beads?
git diff $(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || echo main)...HEAD --stat  # Code changes?
TEST                                         # Tests pass? (Go default: make test)
```

**Step 1:** Check `.claude/workflow-state/*-checkpoint.yaml`

**Step 2A — Checkpoint found:** Read → verify integrity → check for mid-phase progress → resume.
- If `implementation_progress.auto_saved=true`: resume Phase 3 from Part `parts_completed + 1` (skip completed Parts). Re-create cron auto-save (startup step 5).
- Otherwise: standard resume from `phase_completed + 1` → restore iteration counters.

**Step 2B — No checkpoint (heuristic):**

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
