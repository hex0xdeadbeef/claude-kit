# Subagents & DAG Task Decomposition

purpose: "Dynamic parallel execution with dependency management"
principle: "Generate specialized sub-agents on-demand, not fixed 3"
research: "TDAG Framework: dynamic subtask modification mid-execution"

## Architecture

### Task Graph (DAG)

structure:
  nodes: "Tasks to execute"
  edges: "Dependencies between tasks"
  properties:
    - "Acyclic: no circular dependencies"
    - "Dynamic: can add/remove nodes mid-execution"
    - "Parallel: independent nodes run concurrently"

example_dag: |
  ┌─────────────────┐
  │   INIT_TASK     │
  └────────┬────────┘
           │
    ┌──────┴──────┐
    ▼             ▼
  ┌─────┐     ┌─────┐
  │ T1  │     │ T2  │  ← parallel (no dependency)
  └──┬──┘     └──┬──┘
     │           │
     └─────┬─────┘
           ▼
       ┌───────┐
       │  T3   │  ← depends on T1 AND T2
       └───────┘

### Dynamic Task Generation

trigger: "Task complexity detected in INIT/EXPLORE"
process:
  1_analyze:
    input: "User request + artifact type"
    output: "Task complexity score (1-5)"

  2_decompose:
    if: "complexity >= 3"
    action: "Generate task DAG"
    output: "tasks[], dependencies[]"

  3_spawn:
    for_each: "task with no unmet dependencies"
    action: "Create specialized subagent"
    parallel: true

  4_await:
    strategy: "await ready tasks, spawn dependents"
    on_complete: "Aggregate results"

## Model Routing

purpose: "Use cheapest model that meets quality requirements per task"
principle: "Haiku for search/validation (90% quality, 2x speed), Sonnet for generation, Opus for judgment"
source: "https://code.claude.com/docs/en/sub-agents — native model: field support"

model_routing:
  haiku:
    use_for: "Read-only exploration, scanning, validation, pattern matching"
    quality: "~90% of Sonnet on agentic tasks"
    cost: "~10x cheaper than Opus"
    agents: [codebase_analyzer, artifact_scanner, context_loader, dependency_analyzer, quality_checker, efficiency_critic]
  sonnet:
    use_for: "Content generation, code writing, applying changes"
    quality: "Standard quality for most tasks"
    cost: "Baseline"
    agents: [dynamic_subagents (default), clarity_critic]
  opus:
    use_for: "Critical evaluation, architectural decisions, constitutional review"
    quality: "Maximum reasoning depth"
    cost: "~10x Haiku"
    agents: [correctness_critic, reflector_agent]

override_policy:
  user_flag: "--model {model}" # Override all subagents
  env_var: "ANTHROPIC_DEFAULT_SONNET_MODEL" # Global Sonnet override
  fallback: "If specified model unavailable → fall back to sonnet"

## Max Turns Guard

purpose: "Prevent runaway subagents from consuming excessive context and time"
research: "Claude Code max_turns parameter; Agent safety literature (2025)"
source: "https://code.claude.com/docs/en/sub-agents — native max_turns support"

max_turns_policy:
  principle: "Every subagent MUST have max_turns set. No unbounded execution."
  by_model_tier:
    haiku: 5       # scanning, validation — fast tasks, tight bound
    sonnet: 10     # generation, analysis — needs room for iteration
    opus: 8        # judgment, reflection — deep but bounded reasoning
  by_role:
    critics: 3     # single evaluation pass — read draft, score, output
    reflector: 5   # analyze + write reflection + store to memory
    predefined: "inherit from model tier"
    dynamic: "inherit from model tier, cap at 10"
  override: "user can set --max-turns=N flag to override all limits"
  enforcement: "Task tool max_turns parameter — hard cutoff, agent stops at limit"
  on_limit_reached:
    action: "Return partial results with truncation warning"
    output_prefix: "⚠️ MAX_TURNS reached ({turns}/{max_turns})"
    handling: "Treat as soft failure — use partial results, log to observability"

## Subagent Templates

### Base Template

all_subagents:
  timeout: "30s"
  max_context: "8000 tokens"
  max_turns: "inherit from max_turns_policy (by model tier or role)"
  tools_default: ["Read", "Glob", "Grep"]
  output_format: "structured JSON"
  error_handling: "Return partial results + error description"
  model_default: "inherit (from parent session)"

### Predefined Types

codebase_analyzer:
  model: haiku
  max_turns: 5
  task: "Find code patterns for {topic}"
  tools: ["Glob", "Grep", "Read"]
  constraints:
    max_files: 10
    focus: ["src/", "internal/", "pkg/", "lib/"]
  output_schema:
    code_examples: "array of {file, lines, pattern}"
    patterns_found: "array of pattern names"

artifact_scanner:
  model: haiku
  max_turns: 5
  task: "Find similar existing artifacts"
  tools: ["Glob", "Read"]
  constraints:
    target: ".claude/**/*.md"
    max_artifacts: 5
  output_schema:
    similar_artifacts: "array of {name, type, overlap_score}"
    structure_notes: "string"

context_loader:
  model: haiku
  max_turns: 5
  task: "Load project context and prior knowledge"
  tools: ["Read", "mcp__memory__read_graph"]
  constraints:
    files: ["PROJECT-KNOWLEDGE.md", "CLAUDE.md"]
  output_schema:
    project_context: "string summary"
    prior_knowledge: "array of relevant facts"

dependency_analyzer:
  model: haiku
  max_turns: 5
  task: "Analyze artifact dependencies"
  tools: ["Grep", "Read"]
  constraints:
    search: ["@skill", "SEE:", "deps/"]
  output_schema:
    dependencies: "array of {from, to, type}"
    missing: "array of broken references"

quality_checker:
  model: haiku
  max_turns: 5
  task: "Pre-check quality criteria"
  tools: ["Read"]
  constraints:
    checklist: "artifact-quality.md"
  output_schema:
    passed: "array of check names"
    failed: "array of {check, reason}"

# ── MAR Evaluation Team (replaces single evaluator_agent) ──
# Multi-Agent Reflexion: 3 persona-driven critics run in parallel
# → deps/eval-optimizer.md#mar_evaluation — full MAR architecture, scoring, debate rules

correctness_critic:
  model: opus
  max_turns: 3  # single evaluation pass — read, score, output
  persona: "Senior engineer focused on correctness, edge cases, and domain-specific quality"
  trigger: "DRAFT phase → EVALUATE sub-phase (parallel with other critics)"
  focus: [P1_correctness, P3_robustness, P6_domain, P7_domain]
  max_context: "250 lines (draft + constitution P1+P3+P6+P7)"
  tools: ["Read"]
  input:
    - "Draft artifact content"
    - "Artifact constitution P1 (correctness) + P3 (robustness)"
    - "Domain-specific P6 + P7 for artifact_type"
    - "Adaptive weights for artifact type"
  output:
    scores: "dict {accuracy: float, completeness: float, domain_p6: float, domain_p7: float}"
    issues: "list[{severity, location, description, suggestion}]"
  key_constraint: "Does NOT receive generation plan, conversation history, or previous drafts"

clarity_critic:
  model: sonnet
  max_turns: 3  # single evaluation pass — read, score, output
  persona: "Technical writer focused on readability and structure"
  trigger: "DRAFT phase → EVALUATE sub-phase (parallel with other critics)"
  focus: [P2_clarity, P5_maintainability]
  max_context: "200 lines (draft + constitution P2+P5 + existing artifacts for style)"
  tools: ["Read"]
  input:
    - "Draft artifact content"
    - "Artifact constitution P2 (clarity) + P5 (maintainability)"
    - "Existing artifacts for style reference"
  output:
    scores: "dict {clarity: float, integration: float}"
    issues: "list[{severity, location, description, suggestion}]"
  key_constraint: "Does NOT receive generation plan or previous drafts"

efficiency_critic:
  model: haiku
  max_turns: 3  # single evaluation pass — read, score, output
  persona: "Performance engineer focused on size and duplication"
  trigger: "DRAFT phase → EVALUATE sub-phase (parallel with other critics)"
  focus: [P4_efficiency, token_density]
  max_context: "200 lines (draft + SIZE_GATE thresholds + similar artifacts)"
  tools: ["Read"]
  input:
    - "Draft artifact content"
    - "SIZE_GATE thresholds (deps/blocking-gates.md#SIZE_GATE)"
    - "Existing similar artifacts for duplication check"
  output:
    scores: "dict {efficiency: float, duplication: float}"
    issues: "list[{severity, location, description, suggestion}]"
  key_constraint: "Does NOT receive generation plan or previous drafts"

mar_aggregation:
  note: "Lead agent aggregates 3 critic outputs, optionally after debate round"
  aggregate_score: "correctness * 0.40 + clarity * 0.35 + efficiency * 0.25"
  post_debate: "Recalculate with debate-adjusted severities if debate was triggered"
  verdict: "PASS (>= 0.85) | FAIL"
  fallback: "If critics unavailable → single evaluator (v9 behavior, opus)"

# ── DEBATE ROUND ──
# Each critic reviews the other two critics' issues and responds with agree/disagree/escalate/add.
# Runs only when triggered (spread > 0.15 OR score in [0.75, 0.90]).
# → deps/eval-optimizer.md#debate — debate triggering, peer review, consensus adjustment

debate_round:
  purpose: "Cross-critique to resolve disagreements and catch blind spots"
  trigger: "score_spread > 0.15 OR aggregate_score in [0.75, 0.90]"
  execution: "parallel — all 3 debate reviews run concurrently"

  correctness_critic_debate:
    model: opus
    max_turns: 3
    persona: "Same as correctness_critic — now reviewing peer issues"
    input:
      - "Draft artifact"
      - "Own initial issues"
      - "clarity_critic issues + efficiency_critic issues"
    output:
      reviews: "list[{critic_name, issue_id, action(agree|disagree|escalate), reasoning}]"
      new_issues: "list[{severity, location, description, suggestion}]"
    key_constraint: "Review ISSUES only, not other critics' scores. Focus on correctness lens."

  clarity_critic_debate:
    model: sonnet
    max_turns: 3
    persona: "Same as clarity_critic — now reviewing peer issues"
    input:
      - "Draft artifact"
      - "Own initial issues"
      - "correctness_critic issues + efficiency_critic issues"
    output:
      reviews: "list[{critic_name, issue_id, action(agree|disagree|escalate), reasoning}]"
      new_issues: "list[{severity, location, description, suggestion}]"
    key_constraint: "Review ISSUES only. Focus on clarity implications of proposed fixes."

  efficiency_critic_debate:
    model: haiku
    max_turns: 3
    persona: "Same as efficiency_critic — now reviewing peer issues"
    input:
      - "Draft artifact"
      - "Own initial issues"
      - "correctness_critic issues + clarity_critic issues"
    output:
      reviews: "list[{critic_name, issue_id, action(agree|disagree|escalate), reasoning}]"
      new_issues: "list[{severity, location, description, suggestion}]"
    key_constraint: "Review ISSUES only. Focus on size/efficiency impact of proposed fixes."

reflector_agent:
  model: opus
  max_turns: 5  # analyze + reflect + store to MCP memory
  description: "Episodic learning extraction (Reflexion pattern)"
  trigger: "DRAFT phase → REFLECT sub-phase (after EVALUATE + optional DEBATE fails)"
  purpose: "Generate linguistic reflection and store in episodic memory"
  max_context: "300 lines (draft + eval results + debate results + past reflections)"
  tools: ["Read", "mcp__memory__add_observations"]
  input:
    - "Draft artifact"
    - "Evaluation results (scores + issues)"
    - "Past reflections on same artifact type (max 3 from episodic memory)"
  output:
    what_failed: "string (description of problem)"
    why_failed: "string (root cause)"
    how_to_fix: "list[string] (actionable steps)"
    key_insight: "string (one-line lesson)"
  storage: "mcp__memory entity: meta-agent-reflection-{artifact_type}-{timestamp}"
  success_criterion: "Reflection stored + fixes clear and actionable"
  error_handling: "On timeout/error: skip reflection, proceed to OPTIMIZE with eval issues only"

### Dynamic Type Generation

when: "No predefined type matches task"
process:
  1_describe:
    input: "Task description"
    output: "Subagent specification"

  2_configure:
    template: |
      dynamic_subagent:
        task: "{task_description}"
        model: "{inferred_model}"
        max_turns: "{from max_turns_policy by model tier, cap at 10}"
        tools: [{inferred_tools}]
        constraints:
          max_files: {based_on_scope}
          focus: [{relevant_paths}]
        output_schema:
          {inferred_fields}

  3_validate:
    checks:
      - "Tools are available"
      - "Paths exist"
      - "Output schema is parseable"

## Execution Modes

### Mode: CREATE (Agent Teams)

recommended: "Agent Teams pattern (peer-to-peer)"
details: "deps/agent-teams.md"  # team definition, constraints, peer-to-peer interaction patterns
team:
  lead: meta-agent
  teammates: [researcher (haiku), scanner (haiku), designer (sonnet)]
  evaluator: "subagent (opus) — NOT teammate, needs fresh context"

fallback_dag: |
  # Used when Agent Teams unavailable
  INIT
    ├── codebase_analyzer (parallel)
    ├── artifact_scanner (parallel)
    └── context_loader (parallel)
  AGGREGATE (depends: all above)
    └── PLAN

dynamic_extension:
  if: "artifact_scanner finds >3 similar"
  add_task: "overlap_analyzer"
  depends_on: "artifact_scanner"
  purpose: "Determine merge vs create"

### Mode: ENHANCE

default_dag: |
  INIT
    └── context_loader
  EXPLORE (depends: context_loader)
    ├── pattern_finder (parallel, if skill)
    └── dependency_analyzer (parallel)
  ANALYZE (depends: all above)

### Mode: DRAFT (MAR)

draft_phase_dag:
  note: "MAR with conditional debate round"
  dag: |
    GENERATE
      → [correctness_critic ∥ clarity_critic ∥ efficiency_critic] (parallel, max_turns:3 each)
      → PRE-AGGREGATE (compute spread + initial score)
      → DEBATE GATE (spread > 0.15 OR score in [0.75, 0.90]?)
        → YES: [correctness_debate ∥ clarity_debate ∥ efficiency_debate] (parallel, max_turns:3 each)
               → POST-DEBATE SCORING (consensus adjustments)
        → NO: skip debate
      → AGGREGATE
      → score < 0.85?
        → YES: reflector_agent (max_turns:5) → OPTIMIZE → loop back to EVALUATE
        → NO: → APPLY
  max_loops: 3
  parallel_evaluation: true  # 3 critics run concurrently
  parallel_debate: true      # 3 debate reviews run concurrently (if triggered)
  critical_tasks: ["correctness_critic"]
  optional_tasks: ["reflector_agent", "debate_round"]
  ref: "deps/eval-optimizer.md"  # MAR evaluation, debate rules, aggregation logic

### Mode: AUDIT

default_dag: |
  INIT
    ├── artifact_scanner (all types, parallel)
    ├── quality_checker (parallel)
    └── dependency_analyzer (parallel)
  AGGREGATE
    └── REPORT

## Parallel Execution

### Constraints

max_concurrent: 7
reason: "Claude Code supports up to 7 parallel subagents"

### Scheduling

algorithm: "Ready-first with priority"
steps:
  1: "Identify tasks with all dependencies met"
  2: "Sort by priority (critical path first)"
  3: "Spawn up to max_concurrent"
  4: "On completion, check newly ready tasks"
  5: "Repeat until DAG complete"

### Priority Calculation

factors:
  - critical_path: "Tasks on longest path get priority"
  - blocking_count: "Tasks blocking many others get priority"
  - estimated_duration: "Shorter tasks may run first (SJF optional)"

## Aggregation

### Merge Strategy

sequential_merge:
  order: "Topological sort of completed tasks"
  conflict_resolution: "Later task overwrites earlier"

weighted_merge:
  when: "Multiple sources for same field"
  strategy: "Keep highest confidence / most detailed"

### Output Format

research_summary: |
  ## Research Summary (DAG execution)

  ### Execution Graph
  Tasks: {total_tasks}
  Parallel batches: {batch_count}
  Duration: {total_time}s

  ### Code Examples ({N} found)
  [from codebase_analyzer]

  ### Similar Artifacts ({N} found)
  [from artifact_scanner]
  Overlap analysis: [from overlap_analyzer, if exists]

  ### Dependencies
  [from dependency_analyzer]

  ### Project Context
  [from context_loader]

  ### Quality Pre-Check
  [from quality_checker, if exists]

## Error Handling

### Per-Task Errors

on_timeout:
  action: "Mark task failed, continue with dependents if possible"
  fallback: "Use partial results"
  output: "⚠️ Task {name} timed out, proceeding with available data"

on_error:
  action: "Log error, attempt recovery"
  recovery_strategies:
    - "Retry once with reduced scope"
    - "Skip and mark as missing"
    - "Use cached results if available"

### Cascade Prevention

rule: "Single task failure should not fail entire DAG"
implementation:
  - "Mark dependent tasks as 'degraded' not 'failed'"
  - "Aggregate available results"
  - "Report gaps in final summary"

### Critical Task Failure

critical_tasks: ["context_loader", "artifact_scanner"]
on_critical_fail:
  action: "Stop DAG, report to user"
  output: |
    ❌ CRITICAL TASK FAILED
    Task: {task_name}
    Error: {error}
    Impact: Cannot proceed without {missing_data}
    Options: [Retry / Manual input / Abort]

## Observability

### DAG Trace

capture:
  - task_graph: "Nodes and edges"
  - execution_order: "Actual execution sequence"
  - timing: "Start/end per task"
  - results: "Output summaries"
  - errors: "Any failures or retries"

output: |
  ### DAG Execution Trace
  ```
  T0 INIT ──────────────────── 0.5s ✅
  T1 codebase_analyzer ─────── 2.1s ✅ (parallel)
  T2 artifact_scanner ──────── 1.8s ✅ (parallel)
  T3 context_loader ────────── 1.2s ✅ (parallel)
  T4 AGGREGATE ─────────────── 0.3s ✅ (depends: T1,T2,T3)
  Total: 3.1s (vs 5.9s sequential)
  Speedup: 1.9x
  ```

## Fallback

when: "Subagent system unavailable or disabled"
action: "Sequential execution in main context"
steps:
  - "Execute tasks in topological order"
  - "No parallelism"
  - "Same aggregation logic"
note: "Slower but produces identical results"
