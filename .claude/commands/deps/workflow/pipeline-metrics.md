# Pipeline Metrics

purpose: "Автоматический сбор метрик для оптимизации pipeline"
loaded_when: "Completion phase only — after all phases done"
source: "Extracted from workflow.md for context budget optimization"

# ─────────────────────────────────────────────────────
# FORMAT
# ─────────────────────────────────────────────────────
pipeline_metrics:
  when: "В completion-фазе workflow"
  severity: MEDIUM

  format:
    feature: "{feature-name}"
    timestamp: "ISO 8601"
    total_phases_executed: N
    review_iterations:
      plan_review: N
      code_review: N
    complexity:
      estimated: "S|M|L|XL"
      actual: "S|M|L|XL (если re-routing произошёл)"
    re_routing_occurred: true|false
    issues_found:
      blocker: N
      major: N
      minor: N
      nit: N
    sequential_thinking_used: true|false
    mcp_tools_used: ["memory", "sequential_thinking", "context7", "postgresql"]
    evaluate_decision: "PROCEED|REVISE|RETURN"

# ─────────────────────────────────────────────────────
# STORAGE
# ─────────────────────────────────────────────────────
  storage:
    action: "mcp__memory__create_entities"
    entity:
      name: "Pipeline Metrics: {feature}"
      entityType: "pipeline_metrics"
      observations:
        - "Phases: {total}, PR iterations: {N}, CR iterations: {N}"
        - "Complexity: estimated {X} → actual {Y}"
        - "Issues: {blocker}B {major}M {minor}m"
        - "Tools: {list}"

# ─────────────────────────────────────────────────────
# ANALYSIS
# ─────────────────────────────────────────────────────
  analysis:
    purpose: "Со временем позволяет:"
    benefits:
      - "Оценивать точность task-analysis (estimated vs actual complexity)"
      - "Находить паттерны (какие типы задач генерируют больше issues)"
      - "Оптимизировать pipeline на основе данных"
      - "Выявлять bottlenecks (какая фаза генерирует больше итераций)"

# ─────────────────────────────────────────────────────
# AGGREGATION
# ─────────────────────────────────────────────────────
  aggregation:
    query_pattern:
      tool: "mcp__memory__search_nodes"
      query: "Pipeline Metrics"
      note: "Returns all entities with 'Pipeline Metrics' in name. Parse observations to extract structured data."

    triggers:
      - when: "User explicitly asks for pipeline analysis/stats"
        action: "Full aggregation report"
      - when: "Every 5th workflow run (check: search_nodes → count 'Pipeline Metrics' entities)"
        action: "Brief summary appended to completion output"
      - when: "Current run has anomaly (see anomaly_detection)"
        action: "Inline warning in completion output"

    report_format: |
      ## Pipeline Health Report ({N} runs analyzed)
      | Metric | Value | Trend |
      |--------|-------|-------|
      | Avg iterations (plan-review) | {N} | {↑↓→} |
      | Avg iterations (code-review) | {N} | {↑↓→} |
      | Re-routing rate | {N}% | {↑↓→} |
      | Complexity accuracy | {N}% (estimated = actual) | {↑↓→} |
      | Top issue category | {category} ({N} occurrences) | |
      | Avg phases per run | {N} | {↑↓→} |

      **Insights:**
      - {insight 1: e.g. "Plan-review iterations trending up — consider improving planner prompts"}
      - {insight 2: e.g. "70% of re-routings are S→M — task-analysis underestimates small tasks"}

    anomaly_detection:
      rules:
        - condition: "review_iterations.plan_review >= 3 (current run)"
          warning: "Plan-review hit loop limit — task may be poorly scoped"
        - condition: "re_routing occurred AND complexity jumped 2+ levels (e.g. S→L)"
          warning: "Major misclassification — review task-analysis criteria"
        - condition: "issues_found.blocker > 0 AND was APPROVED by plan-review"
          warning: "Blocker found after plan approval — plan-review may need stricter checks"
      action: "Append warning to completion output + include in next aggregation report"
