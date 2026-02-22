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

model_tiers:
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

## Subagent Templates

### Base Template

all_subagents:
  timeout: "30s"
  max_context: "8000 tokens"
  tools_default: ["Read", "Glob", "Grep"]
  output_format: "structured JSON"
  error_handling: "Return partial results + error description"
  model_default: "inherit (from parent session)"

### Predefined Types

codebase_analyzer:
  model: haiku
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
  task: "Load project context and prior knowledge"
  tools: ["Read", "mcp__memory__read_graph"]
  constraints:
    files: ["PROJECT-KNOWLEDGE.md", "CLAUDE.md"]
  output_schema:
    project_context: "string summary"
    prior_knowledge: "array of relevant facts"

dependency_analyzer:
  model: haiku
  task: "Analyze artifact dependencies"
  tools: ["Grep", "Read"]
  constraints:
    search: ["@skill", "SEE:", "deps/"]
  output_schema:
    dependencies: "array of {from, to, type}"
    missing: "array of broken references"

quality_checker:
  model: haiku
  task: "Pre-check quality criteria"
  tools: ["Read"]
  constraints:
    checklist: "artifact-quality.md"
  output_schema:
    passed: "array of check names"
    failed: "array of {check, reason}"

# ── MAR Evaluation Team (v10.0 — replaces single evaluator_agent) ──
# Multi-Agent Reflexion: 3 persona-driven critics run in parallel
# SEE: deps/eval-optimizer.md#mar_evaluation for full architecture

correctness_critic:
  model: opus
  persona: "Senior engineer focused on correctness and edge cases"
  trigger: "DRAFT phase → EVALUATE sub-phase (parallel with other critics)"
  focus: [P1_correctness, P3_robustness]
  max_context: "200 lines (draft + constitution P1+P3)"
  tools: ["Read"]
  input:
    - "Draft artifact content"
    - "Artifact constitution P1 (correctness) + P3 (robustness)"
    - "Adaptive weights for artifact type"
  output:
    scores: "dict {accuracy: float, completeness: float}"
    issues: "list[{severity, location, description, suggestion}]"
  key_constraint: "Does NOT receive generation plan, conversation history, or previous drafts"

clarity_critic:
  model: sonnet
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
  note: "Lead agent aggregates 3 critic outputs"
  aggregate_score: "correctness * 0.40 + clarity * 0.35 + efficiency * 0.25"
  verdict: "PASS (>= 0.85) | FAIL"
  fallback: "If critics unavailable → single evaluator (v9 behavior, opus)"

reflector_agent:
  model: opus
  description: "Episodic learning extraction (Reflexion pattern)"
  trigger: "DRAFT phase → REFLECT sub-phase (after EVALUATE fails)"
  purpose: "Generate linguistic reflection and store in episodic memory"
  max_context: "300 lines (draft + eval results + past reflections)"
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

### Mode: CREATE (v10.0 — Agent Teams)

recommended: "Agent Teams pattern (peer-to-peer)"
details: "SEE: deps/agent-teams.md for full team definition"
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

### Mode: DRAFT (v10.0 — MAR)

draft_phase_dag:
  note: "v10.0: Multi-Agent Reflexion replaces single evaluator"
  dag: "GENERATE → [correctness_critic ∥ clarity_critic ∥ efficiency_critic] → AGGREGATE → [if fail] reflector_agent → OPTIMIZE → [3 critics] → ..."
  max_loops: 3
  parallel_evaluation: true  # 3 critics run concurrently
  critical_tasks: ["correctness_critic"]
  optional_tasks: ["reflector_agent"]
  ref: "SEE: deps/eval-optimizer.md#mar_evaluation"

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
