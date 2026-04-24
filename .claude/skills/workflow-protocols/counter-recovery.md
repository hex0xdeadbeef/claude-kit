---
name: counter-recovery
description: "Heuristic counter recovery when checkpoint is missing + iteration_summary_on_stop format template for 3/3 loop-limit breaks. Load only on heuristic session recovery OR loop-limit hit."
disable-model-invocation: true
---

# Counter Recovery

Load triggers (either is sufficient):
1. **Heuristic session recovery** — `.claude/workflow-state/*-checkpoint.yaml` is missing and the orchestrator must infer iteration counts from other signals.
2. **Loop limit reached (3/3)** — plan-review or code-review cycle hit 3 iterations; orchestrator needs the user-facing summary format.

Referenced from [Orchestration Core](orchestration-core.md) § Loop Limits → `tracking_protocol` sub-fields.

**Provenance:** Previously nested under `tracking_protocol.counter_recovery` / `tracking_protocol.iteration_summary_on_stop` in `orchestration-core.md`; relocated as top-level YAML entries here on 2026-04-24 (IMP-05 lazy-load split). Semantics unchanged — both remain conceptually part of the `tracking_protocol` contract defined in the thin core.

---

## counter_recovery

```yaml
counter_recovery:
  description: "When checkpoint is missing, infer iteration count from available signals"
  strategy:
    step_1: "Check handoff payload in current context → read iteration field"
    step_2: "If no handoff → count issues_history entries for this cycle in context"
    step_3: "If no context → git log --oneline | grep 'plan-review\\|code-review' (count re-runs)"
    step_4: "If nothing found → assume iteration 1/3 (conservative) + WARN user"
  warning: "Heuristic recovery is imprecise. After recovery, ALWAYS write checkpoint immediately."
```

---

## iteration_summary_on_stop

```yaml
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
