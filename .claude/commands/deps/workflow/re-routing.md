# Re-Routing Protocol

purpose: "Самокорректирующийся pipeline — изменение route при неверной классификации"
loaded_by: [workflow]
when: "Read when re-routing event detected (plan-review or coder signals complexity mismatch)"
source: "Extracted from workflow.md (lines 447-479) for event-triggered loading (4.3)"

---

re_routing:
  severity: MEDIUM

  triggers:
    - trigger: "plan-review находит что план слишком простой для текущего route"
      action: "Downgrade route"
      examples:
        - "L→M: план оказался < 3 Parts, убрать обязательный Sequential Thinking"
        - "M→S: только 1 Part, 1 layer — skip plan-review в следующей итерации"

    - trigger: "plan-review находит что план слишком сложный для текущего route"
      action: "Upgrade route"
      examples:
        - "S→M: обнаружены cross-layer зависимости — добавить full plan-review"
        - "M→L: 4+ Parts, 3+ layers — добавить Sequential Thinking"

    - trigger: "coder evaluate находит hidden complexity"
      action: "Upgrade route или RETURN to planner"
      examples:
        - "M→L: evaluate обнаружил что нужна миграция БД (не учтена в плане)"

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
  learning: "Сохранить в MCP Memory: original_route → actual_route + причина для улучшения heuristics"
