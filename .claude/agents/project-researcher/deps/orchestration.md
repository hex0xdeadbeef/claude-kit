# Orchestration Protocol

**Purpose:** Defines the interaction protocol between the orchestrator (AGENT.md) and subagents. Each subagent is an isolated context invoked via the Task tool.

**Load when:** Orchestrator reads this file during initialization.

---

## SUBAGENT REGISTRY

| Subagent | File | Model | Phases | Parallelizable |
|----------|------|-------|--------|----------------|
| discovery | `subagents/discovery.md` | haiku | VALIDATE + DISCOVER | No (first) |
| detection | `subagents/detection.md` | sonnet | DETECT | Per-module |
| **graph** | **`subagents/graph.md`** | **sonnet** | **GRAPH** | **Per-module** |
| analysis | `subagents/analysis.md` | opus | ANALYZE + MAP + DATABASE | Per-module |
| generation | `subagents/generation.md` | sonnet | GENERATE | No |
| verification | `subagents/verification.md` | sonnet | VERIFY | No |
| report | `subagents/report.md` | haiku | REPORT | No |

**Inline (not a subagent):**
| Phase | File | Model | Note |
|-------|------|-------|------|
| CRITIQUE | `phases/critique.md` | opus | Blocking gate — loaded inline in the orchestrator |

**New in v4.2:** GRAPH subagent builds a symbol graph (symbol table + dependency graph + PageRank repo-map) between DETECTION and ANALYSIS. Uses tree-sitter MCP as the primary tool.

---

## SUBAGENT CALL PROTOCOL

### Calling a subagent via Task tool

```
Task tool call:
  subagent_type: general-purpose
  model: {model_from_registry}
  prompt: |
    # SUBAGENT: {subagent_name}

    Read the subagent instructions:
    Read file: {agent_root}/subagents/{subagent_file}

    ## INPUT STATE
    ```yaml
    {serialized_state — only fields required by this subagent}
    ```

    ## EXECUTION
    Follow the instructions in the subagent file exactly.
    Use tools: Read, Write, Glob, Grep, Bash as needed.

    ## OUTPUT FORMAT
    After completing all steps, output EXACTLY this structure:

    ```yaml
    subagent_result:
      status: "success" | "failure" | "partial"
      state_updates:
        {phase_name}:
          {field}: {value}
          ...
      progress_summary: "{one-line summary}"
      error:  # only if status != "success"
        code: "{ERROR_CODE}"
        message: "{description}"
        recovery: "{suggested action}"
    ```
```

### Receiving the result

Orchestrator:
1. Parses `subagent_result` from the subagent response
2. Validates `state_updates` against the state contract (SEE: deps/state-contract.md)
3. Merges state according to the rules (SEE: State Merging Rules)
4. Logs `progress_summary`
5. On `status: "failure"` → retry or halt

---

## STATE SERIALIZATION

### What to pass to a subagent

Each subagent receives **only the state fields it needs** (defined in the state contract required fields).

**Example for detection subagent:**
```yaml
# Pass only required fields
validate:
  path: "/Users/dev/my-project"
  mode: "CREATE"
  source_file_count: 127
discover:
  analysis_targets: ["."]
  is_monorepo: false
```

**Do NOT pass** fields from other phases that detection does not use.

### What we receive from a subagent

A subagent returns **only its state section** (delta, not the full state).

**Example detection subagent response:**
```yaml
subagent_result:
  status: "success"
  state_updates:
    detect:
      primary_language: "go"
      primary_confidence: 0.92
      frameworks:
        - name: "chi"
          version: "v5.1.0"
          category: "http"
          confidence: 0.95
          detection_method: "manifest"
      build_tools:
        - name: "make"
          config_file: "Makefile"
      test_framework: "testify"
      test_patterns:
        table_driven_count: 45
        mock_count: 12
        test_file_count: 87
      linters: ["golangci-lint"]
      analysis_method: "tree-sitter-mcp"
  progress_summary: "detect.primary_language=go (0.92), frameworks=[chi@v5], analysis_method=tree-sitter-mcp"
```

---

## STATE MERGING RULES

### Single Project (`strategy: "single"`)

Each subagent writes to its own state section. Merge = direct replacement:

```
state.{phase_name} ← subagent_result.state_updates.{phase_name}
```

### Monorepo (`strategy: "per-module" | "per-module-with-shared-context"`)

When running N subagents for N modules — results are aggregated:

```yaml
# Orchestrator creates per-module state:
detect:
  modules:
    - target: "services/api"
      primary_language: "go"
      primary_confidence: 0.92
      frameworks: [...]
    - target: "services/auth"
      primary_language: "go"
      primary_confidence: 0.88
      frameworks: [...]

# Aggregated summary:
detect:
  primary_language: "go"  # majority across modules
  primary_confidence: 0.90  # average
  frameworks: [unique union across modules]
  analysis_method: "tree-sitter-mcp"  # best available across modules
```

**Merge functions:**
- `primary_language`: majority vote across modules
- `primary_confidence`: weighted average (by source_file_count per module)
- `frameworks`: unique union (deduplicate by name)
- `layers`: concatenate per-module, prefix with module path
- `entry_points`: concatenate per-module
- `dependency_graph`: merge graphs, add inter-module edges

---

## PARALLEL EXECUTION

### Execution Strategies

The parallelization strategy is determined by `state.discover.strategy` and the number of modules.

```
IF state.discover.strategy == "single":
  # Sequential: detection → graph → analysis
  Launch subagent(detection)
  Launch subagent(graph)        # NEW v4.2: symbol extraction + repo-map
  Launch subagent(analysis)     # receives state.graph.repo_map as context

ELSE IF state.discover.strategy IN ("per-module", "per-module-with-shared-context"):
  IF state.discover.modules.length <= 1:
    # Single module fallback — sequential
    Launch subagent(detection)
    Launch subagent(graph)
    Launch subagent(analysis)

  ELSE IF state.discover.modules.length <= 3:
    # Pipeline parallelism: per-module compound subagents
    # Each module goes through DETECTION+GRAPH+ANALYSIS in a single Task call
    SEE: PIPELINE PARALLELISM section below

  ELSE:
    # Batch parallelism (4+ modules): classic approach for concurrency control
    # Batch 1: all DETECTION in parallel → merge
    # Batch 2: all GRAPH in parallel → merge
    # Batch 3: all ANALYSIS in parallel → merge
    FOR EACH target IN state.discover.analysis_targets:
      Launch subagent(detection, module_path=target) IN PARALLEL
    WAIT ALL
    Merge detection results

    FOR EACH target IN state.discover.analysis_targets:
      Launch subagent(graph, module_path=target) IN PARALLEL
    WAIT ALL
    Merge graph results

    FOR EACH target IN state.discover.analysis_targets:
      Launch subagent(analysis, module_path=target) IN PARALLEL
    WAIT ALL
    Merge analysis results
```

### Task tool parallel calls

```
# In the orchestrator — launch multiple Task tool calls in a single message:
# Task 1: detection for services/api
# Task 2: detection for services/auth
# Task 3: detection for pkg/shared
# → all launched in parallel
```

---

## PIPELINE PARALLELISM

### Concept

With batch parallelism (v4.0), all modules go through DETECTION → wait for all → all ANALYSIS → wait for all.
Pipeline parallelism eliminates this barrier: each module goes through the full cycle DETECTION → GRAPH → ANALYSIS
in a single compound subagent call. Modules are launched in parallel, merging happens as results become ready.

```
v4.0 (batch):                              v4.2 (pipeline):

  DETECT-A ─┐                                ┌─ DETECT-A → GRAPH-A → ANALYZE-A ─→ ready ─┐
  DETECT-B ─┤→ wait → merge                  ├─ DETECT-B → GRAPH-B → ANALYZE-B ─→ ready ─┤→ merge all
  DETECT-C ─┘                           │    └─ DETECT-C → GRAPH-C → ANALYZE-C ─→ ready ─┘
  ANALYZE-A ─┐                          │
  ANALYZE-B ─┤→ wait → merge            │  Benefit: no barrier between phases.
  ANALYZE-C ─┘                          │  GRAPH runs inline between DETECT and ANALYZE.
                                        │  Bottleneck = the slowest module.
```

### When to use

```
Pipeline parallelism is activated when:
  1. state.discover.strategy IN ("per-module", "per-module-with-shared-context")
  2. state.discover.modules.length >= 2
  3. state.discover.modules.length <= 3  # ≤3 concurrent compound subagents

For 4+ modules, batch parallelism is used (classic v4.0 approach)
for concurrency control and predictable token consumption.
```

### Compound Subagent Protocol

A compound subagent is a single Task call that performs DETECTION + GRAPH + ANALYSIS for one module sequentially.
The orchestrator launches N compound subagents in parallel.

```
Task tool call (compound):
  subagent_type: general-purpose
  model: opus  # highest model in chain determines compound model
  prompt: |
    # COMPOUND SUBAGENT: DETECTION + GRAPH + ANALYSIS for module "{module.path}"

    You will execute THREE phases sequentially for a single module.
    Each phase has its own instruction file.

    ## PHASE 1: DETECTION
    Read {AGENT_ROOT}/subagents/detection.md and execute.
    Project path: {path}
    Module target: {module.path}
    State:
    ```yaml
    {serialize(state.validate, state.discover)}
    ```

    After completing DETECTION, store your detection results internally.

    ## PHASE 2: GRAPH
    Read {AGENT_ROOT}/subagents/graph.md and execute.
    Project path: {path}
    Module target: {module.path}
    Use detection results from Phase 1 as input (analysis_method, primary_language).

    After completing GRAPH, store your graph results (repo_map) internally.

    ## PHASE 3: ANALYSIS
    Read {AGENT_ROOT}/subagents/analysis.md and execute.
    Project path: {path}
    Module target: {module.path}
    Use detection results from Phase 1 AND graph results from Phase 2 as input.
    The repo-map from GRAPH provides pre-ranked symbol context for architecture analysis.
    State (from orchestrator):
    ```yaml
    {serialize(state.validate, state.discover)}
    ```

    ## OUTPUT FORMAT
    Return combined results:

    ```yaml
    subagent_result:
      status: "success" | "failure" | "partial"
      compound: true
      module_target: "{module.path}"
      state_updates:
        detect:
          # module-specific detection results
          primary_language: ...
          frameworks: [...]
          ...
        graph:
          # module-specific graph results
          symbol_table: { total_symbols: ..., by_kind: { ... } }
          dependency_graph: { total_nodes: ..., total_edges: ... }
          repo_map: { content: "...", token_count: ... }
          ...
        analyze:
          # module-specific analysis results
          architecture: ...
          layers: [...]
          ...
        map:
          entry_points: [...]
          core_domain: { ... }
          ...
        database:
          available: bool
          ...
      progress_summary: "module={module.path}: detect=go(0.92), graph={N}symbols, analyze=clean(0.88)"
      error:  # only if status != "success"
        code: "..."
        message: "..."
        phase: "detection" | "graph" | "analysis"  # REQUIRED for compound — identifies which phase failed
        recovery: "..."
    ```
```

### Orchestrator Pipeline Algorithm

```
FUNCTION orchestrate_pipeline_parallel(state):
  modules ← state.discover.analysis_targets
  N ← modules.length

  # ── Step 1: Launch N compound subagents in parallel ──
  # A single Task tool message with N parallel Task calls

  compound_results ← []

  FOR EACH module IN modules (all launched IN PARALLEL via single message):
    Call Task tool:
      subagent_type: general-purpose
      model: opus
      prompt: compound_subagent_prompt(module, state)

  # Task tool executes all N calls concurrently, returns when all complete.

  # ── Step 2: Collect and validate results ──

  FOR EACH result IN compound_results:
    IF result.status == "failure":
      IF result.error.phase == "detection":
        # Detection failed — module fully failed
        WARN "Module {result.module_target}: detection failed, excluding from merge"
        Mark module as failed in state
      ELSE IF result.error.phase == "graph":
        # Detection succeeded, graph failed — merge detect, analysis runs without repo-map
        Merge result.state_updates.detect into state.detect.modules[]
        WARN "Module {result.module_target}: graph failed (analysis will lack repo-map)"
        Mark module graph as partial
      ELSE IF result.error.phase == "analysis":
        # Detection + graph succeeded, analysis failed — partial result
        Merge result.state_updates.detect into state.detect.modules[]
        Merge result.state_updates.graph into state.graph.modules[]
        WARN "Module {result.module_target}: analysis failed (partial data)"
        Mark module analysis as partial
    ELSE:
      # Success or partial — merge all state
      Merge result.state_updates.detect into state.detect.modules[]
      Merge result.state_updates.graph into state.graph.modules[]
      Merge result.state_updates.analyze into state.analyze.modules[]
      Merge result.state_updates.map into state.map.modules[]
      Merge result.state_updates.database into state.database.modules[]

  # ── Step 3: Aggregate merged state ──

  Aggregate state.detect (SEE: STATE MERGING RULES)
  Aggregate state.analyze
  Aggregate state.map

  # ── Step 4: Validate merge ──

  IF all modules failed:
    FATAL "All modules failed detection/analysis"
  IF any module partial:
    state.pipeline_partial ← true
    Log: "Pipeline completed with partial results for N modules"

  RETURN state
```

### Partial Failure Handling

```
Compound subagent can fail at three points:

1. Detection failure → entire module excluded from merge
   - Orchestrator logs warning
   - Other modules continue normally
   - If ALL modules fail detection → FATAL

2. Graph failure (detection succeeded) → partial merge
   - Detection results merged normally
   - Graph/repo-map empty for this module
   - Analysis proceeds WITHOUT repo-map context (lower quality, higher token use)
   - CRITIQUE flags missing graph as warning

3. Analysis failure (detection + graph succeeded) → partial merge
   - Detection and graph results merged normally
   - Analysis results empty for this module
   - Downstream phases (CRITIQUE, GENERATION) work with partial data
   - CRITIQUE must flag missing module analysis as issue

4. Compound model fallback:
   - Default model: opus (for analysis quality)
   - If opus unavailable: sonnet (detection + graph quality preserved, analysis degrades)
   - No haiku fallback (analysis requires reasoning depth)
```

### Progress Tracking (Pipeline Mode)

```
[ORCHESTRATOR] Monorepo detected: {N} modules, strategy={strategy}
[ORCHESTRATOR] Pipeline parallelism: launching {N} compound subagents...

# After all complete:
[PIPELINE] Compound results:
  [MODULE] services/api — detect=go(0.92), analyze=clean(0.88) ✅
  [MODULE] services/auth — detect=go(0.88), analyze=layered(0.75) ✅
  [MODULE] pkg/shared — detect=go(0.95), analyze=library(0.90) ✅

[PHASE 2-5/10] DETECTION + GRAPH + ANALYSIS — DONE (pipeline mode, {N} modules)
State: detect.primary=go(0.92 avg), analyze.modules={N}, partial={0}
```

### Pipeline vs Batch: Decision Matrix

| Criteria | Pipeline (≤3 modules) | Batch (4+ modules) |
|----------|----------------------|-------------------|
| Concurrency | N compound subagents | N×3 simple subagents (in 3 waves) |
| Barrier points | 0 (no inter-phase wait) | 2 (DETECT→GRAPH, GRAPH→ANALYSIS) |
| Token overhead | Higher per-call (compound prompt) | Lower per-call |
| Total tokens | ~Same | ~Same |
| Wall-clock time | Faster (no barrier) | Slower (barrier wait) |
| Partial failure | Per-module granularity | Per-phase granularity |
| Max concurrency | 3 (practical limit) | Configurable |
| Debugging | Harder (combined output) | Easier (isolated phases) |

---

## ERROR HANDLING & RETRY

### Severity Levels

| Status | Meaning | Action |
|--------|---------|--------|
| `success` | Phase completed | Merge state, continue |
| `partial` | Completed with warnings | Merge state, log warnings, continue |
| `failure` | Phase failed | Retry or halt |

### Retry Logic

```
MAX_RETRIES = 1

IF subagent_result.status == "failure":
  IF retry_count < MAX_RETRIES:
    # Retry with reduced scope
    retry_count += 1
    reduced_input = reduce_scope(original_input)
    result = call_subagent(subagent, reduced_input)
  ELSE:
    # Halt
    IF subagent.is_blocking_gate:
      FATAL "Gate failed: {subagent_name}. {error.message}"
    ELSE:
      WARN "Subagent {subagent_name} failed after retry. Continuing with partial state."
      state.{phase_name}.partial = true
```

### Scope Reduction

On retry:
- `detection`: exclude secondary languages, focus on primary
- `analysis`: exclude violation detection, focus on architecture + layers
- `generation`: reduce the number of artifacts (only CLAUDE.md + PROJECT-KNOWLEDGE.md)

---

## BLOCKING GATES

### CRITIQUE Gate (inline in orchestrator)

```
# Orchestrator loads critique.md and executes inline:
1. Read phases/critique.md
2. Execute with full accumulated state
3. Check: state.critique.gate_passed == true
4. IF false:
   - Log critique.issues
   - Determine fix: re-run analysis subagent OR adjust state
   - Re-run critique after fixes
   - MAX 2 critique attempts
5. IF still false after 2 attempts:
   FATAL "Critique gate failed. Manual review required."
```

### VERIFY Gate (via verification subagent)

```
# Orchestrator calls the verification subagent:
1. Call verification subagent
2. Check: state.verify.gate_passed == true
3. IF false:
   - Read state.verify.issues
   - Re-run generation subagent with fix instructions
   - Re-run verification
   - MAX 2 verify attempts
4. IF still false:
   FATAL "Verification gate failed. Issues: {issues}"
```

---

## PROGRESS TRACKING

### Format

Orchestrator outputs progress after each subagent call:

```
[ORCHESTRATOR] Calling subagent: discovery (model: haiku)
[PHASE 1/10] DISCOVERY — DONE
State: validate.mode=CREATE, discover.strategy=single, targets=[.]

[ORCHESTRATOR] Calling subagent: detection (model: sonnet)
[PHASE 2/10] DETECTION — DONE
State: detect.primary_language=go (0.92), frameworks=[chi@v5, pgx@v5], analysis_method=tree-sitter-mcp

[ORCHESTRATOR] Calling subagent: graph (model: sonnet)
[PHASE 3/10] GRAPH — DONE
State: graph.symbols=245, graph.edges=89, graph.repo_map=3200/4000 tokens, PageRank top=internal/domain/repository.go

[ORCHESTRATOR] Calling subagent: analysis (model: opus)
[PHASE 4-5/10] ANALYSIS — DONE
State: analyze.architecture=clean (0.88), layers=3, map.entry_points=3, dep_graph.packages=34

[ORCHESTRATOR] Executing inline: CRITIQUE (model: opus)
[PHASE 6/10] CRITIQUE — DONE (gate: PASSED)
State: critique.gate_passed=true, issues=1, calibration_adjustments=1

[ORCHESTRATOR] Calling subagent: generation (model: sonnet)
[PHASE 7/10] GENERATION — DONE
State: generate.artifacts=5, created=5, preserved=0

[ORCHESTRATOR] Calling subagent: verification (model: sonnet)
[PHASE 8/10] VERIFICATION — DONE (gate: PASSED)
State: verify.gate_passed=true, yaml=✅, refs=✅, size=✅

[ORCHESTRATOR] Calling subagent: report (model: haiku)
[PHASE 9/10] REPORT — DONE
```

### Monorepo Progress — Pipeline Mode (≤3 modules)

```
[ORCHESTRATOR] Monorepo detected: 3 modules, strategy=per-module
[ORCHESTRATOR] Pipeline parallelism: launching 3 compound subagents (DETECT+GRAPH+ANALYZE)...

[PIPELINE] Compound results:
  [MODULE] services/api — detect=go(0.92), graph=145sym/52edges, analyze=clean(0.88) ✅
  [MODULE] services/auth — detect=go(0.88), graph=98sym/34edges, analyze=layered(0.75) ✅
  [MODULE] pkg/shared — detect=go(0.95), graph=67sym/28edges, analyze=library(0.90) ✅

[PHASE 2-5/10] DETECTION + GRAPH + ANALYSIS — DONE (pipeline mode, 3 modules)
State: detect.primary=go(0.92 avg), graph.total_symbols=310, analyze.modules=3, partial=0
```

### Monorepo Progress — Batch Mode (4+ modules)

```
[ORCHESTRATOR] Monorepo detected: 5 modules, strategy=per-module
[ORCHESTRATOR] Batch parallelism: launching 5 detection subagents...
  [DETECT] services/api — DONE (go, 0.92)
  [DETECT] services/auth — DONE (go, 0.88)
  [DETECT] services/billing — DONE (go, 0.85)
  [DETECT] services/notifications — DONE (go, 0.90)
  [DETECT] pkg/shared — DONE (go, 0.95)
[ORCHESTRATOR] Detection merged: primary=go (0.90 avg)

[PHASE 2/10] DETECTION — DONE (5 modules, batch)

[ORCHESTRATOR] Launching 5 graph subagents in parallel...
  [GRAPH] services/api — DONE (145 symbols, 52 edges)
  [GRAPH] services/auth — DONE (98 symbols, 34 edges)
  [GRAPH] services/billing — DONE (112 symbols, 41 edges)
  [GRAPH] services/notifications — DONE (76 symbols, 29 edges)
  [GRAPH] pkg/shared — DONE (67 symbols, 28 edges)
[ORCHESTRATOR] Graph merged: 498 total symbols, 184 edges

[PHASE 3/10] GRAPH — DONE (5 modules, batch)

[ORCHESTRATOR] Launching 5 analysis subagents in parallel...
  [ANALYZE] services/api — DONE (clean, 0.88)
  [ANALYZE] services/auth — DONE (layered, 0.75)
  [ANALYZE] services/billing — DONE (clean, 0.82)
  [ANALYZE] services/notifications — DONE (layered, 0.70)
  [ANALYZE] pkg/shared — DONE (library, 0.90)
[ORCHESTRATOR] Analysis merged: 5 modules analyzed

[PHASE 4-5/10] ANALYSIS — DONE (5 modules, batch)
```

---

## MODEL COST OPTIMIZATION

| Subagent | Model | ~Tokens | Reason |
|----------|-------|---------|--------|
| discovery | haiku | 3-5k | Filesystem checks, manifest scanning |
| detection | sonnet | 8-15k | Pattern matching, tree-sitter/AST |
| **graph** | **sonnet** | **10-20k** | **Symbol extraction, PageRank, repo-map** |
| analysis | opus | 20-40k | Deep reasoning, architecture inference (uses repo-map) |
| **compound** (detect+graph+analyze) | **opus** | **38-75k** | Pipeline mode: single call per module |
| CRITIQUE | opus | 15-25k | Adversarial review, calibration |
| generation | sonnet | 15-25k | Template-based artifact creation |
| verification | sonnet | 5-10k | Validation logic |
| report | haiku | 5-8k | Formatting, summary |

**Estimated savings vs monolithic opus:**
- Single project: ~40% token reduction (haiku/sonnet for light phases)
- Monorepo (3 modules): ~30% reduction + 2-3x faster (parallel analysis)
