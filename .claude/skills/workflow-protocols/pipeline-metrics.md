# Pipeline Metrics

purpose: "Automatic metrics collection for pipeline optimization"
loaded_when: "Completion phase only — after all phases done"

# ─────────────────────────────────────────────────────
# FORMAT
# ─────────────────────────────────────────────────────
pipeline_metrics:
  when: "In workflow completion phase"
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
      actual: "S|M|L|XL (if re-routing occurred)"
    re_routing_occurred: true|false
    issues_found:
      blocker: N
      major: N
      minor: N
      nit: N
    sequential_thinking_used: true|false
    mcp_tools_used: ["memory", "sequential_thinking", "context7", "postgresql"]
    evaluate_decision: "PROCEED|REVISE|RETURN"
    code_researcher_metrics:
      invocations: N
      total_tokens: N
      total_tool_uses: N
      total_duration_ms: N
      background_mode_used: true|false
      note: "Collected from Agent/Task tool return metadata (v2.1.30+). Zero if code-researcher not invoked."

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
        - "Code-researcher: {invocations}x, {total_tokens} tokens, {total_duration_ms}ms (background: {yes|no})"

# ─────────────────────────────────────────────────────
# ANALYSIS
# ─────────────────────────────────────────────────────
  analysis:
    purpose: "Over time enables:"
    benefits:
      - "Evaluate task-analysis accuracy (estimated vs actual complexity)"
      - "Find patterns (which task types generate more issues)"
      - "Optimize pipeline based on data"
      - "Identify bottlenecks (which phase generates more iterations)"

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
      | Avg code-researcher tokens | {N} | {↑↓→} |
      | Code-researcher token share | {N}% of session | {↑↓→} |

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
        - condition: "read_write_ratio > 10 AND session_type != 'project-research' (from session-analytics exploration_metrics)"
          warning: "Possible exploration loop — high read/write ratio (exempt: project-researcher sessions)"
        - condition: "exploration_reads > 30 AND action_writes == 0 AND session_type != 'project-research'"
          warning: "Session appears stuck in exploration (exempt: project-researcher sessions are read-heavy by design)"
        - condition: "code_researcher_metrics.total_tokens > 50% of session total tokens"
          warning: "Code-researcher consuming >50% of token budget — consider narrowing research scope or using inline Grep/Glob"
        - condition: "code_researcher_metrics.invocations > 3 in single pipeline run"
          warning: "Excessive code-researcher invocations — may indicate unclear research questions or scope creep"
      action: "Append warning to completion output + include in next aggregation report"
