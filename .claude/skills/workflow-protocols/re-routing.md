# Re-Routing Protocol

purpose: "Self-correcting pipeline — route change on incorrect classification"

---

re_routing:
  severity: MEDIUM

  triggers:
    - trigger: "plan-review finds the plan is too simple for the current route"
      action: "Downgrade route"
      examples:
        - "L→M: plan turned out < 3 Parts, remove mandatory Sequential Thinking"
        - "M→S: only 1 Part, 1 layer — skip plan-review in next iteration"

    - trigger: "plan-review finds the plan is too complex for the current route"
      action: "Upgrade route"
      examples:
        - "S→M: cross-layer dependencies discovered — add full plan-review"
        - "M→L: 4+ Parts, 3+ layers — add Sequential Thinking"

    - trigger: "coder evaluate finds hidden complexity"
      action: "Upgrade route or RETURN to planner"
      examples:
        - "M→L: evaluate discovered DB migration needed (not accounted for in plan)"

  tracking:
    when: "Immediately when re-routing decision is made (before continuing pipeline)"
    action: "Update checkpoint re_routing fields"
    fields:
      occurred: true
      original_route: "{route from task-analysis}"
      new_route: "{new route after re-routing}"
      reason: "{1-sentence: trigger + evidence}"
      phase: "{phase that triggered re-routing}"
    note: "pipeline_metrics reads re_routing data from checkpoint at completion"
  learning: "Save to MCP Memory: original_route → actual_route + reason for improving heuristics"
