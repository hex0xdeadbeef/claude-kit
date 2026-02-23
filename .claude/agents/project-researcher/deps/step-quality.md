# Step Quality (Process Reward)

**Purpose:** Evaluate quality after each phase/subagent, catch errors early.

**Principle:** Early detection prevents cascading failures. In v4.0, quality checks run both inside subagents (self-check) and in orchestrator (validation on merge).

**Load when:** Implementing quality checks or debugging phase failures.

---

## QUALITY CHECK LAYERS (v4.0)

### Layer 1: Subagent Self-Check

Each subagent runs its own quality checks before returning results. Defined in each subagent file under `STEP QUALITY` section.

```yaml
step_quality:
  checks:
    - "Check 1 description"
    - "Check 2 description"
  min_pass: N
```

Output included in subagent response:
```
Quality: {passed}/{total} checks ✅
```

### Layer 2: Orchestrator Validation

Orchestrator validates subagent results after receiving them:

```yaml
orchestrator_validation:
  - "subagent_result.status is success|partial|failure"
  - "state_updates contains expected phase key"
  - "required fields present per state contract"
  - "confidence scores in range [0, 1]"
  - "no unknown fields in state_updates"
```

### Layer 3: Gate Checks

Blocking gates (CRITIQUE, VERIFY) have explicit pass/fail criteria. SEE: `deps/orchestration.md` → BLOCKING GATES.

---

## PER-SUBAGENT QUALITY CHECKS

### Discovery Subagent (haiku)
- [ ] Path exists and contains source files
- [ ] Mode correctly determined (CREATE/AUGMENT/UPDATE)
- [ ] `source_file_count` > 0
- [ ] Monorepo detection attempted
- [ ] Strategy selected (single/per-module/per-module-with-shared-context)
- Min pass: 5/5

### Detection Subagent (sonnet)
- [ ] Primary language detected (≥60% files)
- [ ] `primary_confidence` ≥ 0.5
- [ ] ≥1 framework identified (or explicit "none found")
- [ ] Build tool found (or explicit "none")
- [ ] Analysis method determined (tree-sitter-mcp / ast-grep / grep)
- [ ] Detection method recorded for each framework
- Min pass: 5/6

### Graph Subagent (sonnet) — v4.2
- [ ] Analysis method correctly selected from state.detect.analysis_method
- [ ] Symbol table built: `total_symbols` > 0
- [ ] Exported symbols identified (`exported_count` > 0)
- [ ] Dependency graph constructed: `total_edges` > 0 (or explicit "no deps" for trivial)
- [ ] Hub files identified (≥1 file with fan_in > 0)
- [ ] Circular dependencies checked (empty list or documented cycles)
- [ ] Ranking applied (PageRank or fan-in approximation)
- [ ] Repo-map generated and fits within token_budget
- [ ] Repo-map coverage ≥ 30% of files (or justified why lower)
- [ ] Test files excluded from primary symbol table
- Min pass: 8/10

### Analysis Subagent (opus)
- [ ] Architecture pattern identified with confidence
- [ ] ≥2 layers detected (or explicit reason why fewer)
- [ ] Entry points documented
- [ ] Import/dependency analysis attempted
- [ ] Convention detection with occurrence counts
- [ ] Design patterns identified (or explicit "none")
- Min pass: 5/6

### Critique Phase (inline, opus)
- [ ] All checklist items reviewed (completeness, accuracy, quality, relevance)
- [ ] Adversarial review: all 5 questions answered with specifics
- [ ] Confidence calibration run (overcalibration check)
- [ ] ≥1 issue found OR explicit "none after adversarial review"
- [ ] Plan adjustments documented
- [ ] Size limits verified
- Min pass: 6/6 (blocking gate)

### Generation Subagent (sonnet)
- [ ] CLAUDE.md generated (≤200 lines)
- [ ] PROJECT-KNOWLEDGE.md generated
- [ ] Skills based on ≥3 real code examples each
- [ ] Rules match detected architecture
- [ ] No duplicate information across artifacts
- [ ] Mode-specific behavior (CREATE/AUGMENT/UPDATE)
- Min pass: 5/6

### Verification Subagent (sonnet, blocking gate)
- [ ] YAML syntax valid in all artifacts
- [ ] All cross-references resolve (file paths, skill names)
- [ ] Sizes within limits (CLAUDE.md ≤200, skills ≤600, rules ≤200)
- [ ] No orphan references
- [ ] Structure complete (all expected artifacts present)
- [ ] No contradictions between CLAUDE.md and PROJECT-KNOWLEDGE.md
- Min pass: 6/6 (blocking gate)

### Compound Subagent (opus) — pipeline parallelism (v4.2)
- [ ] DETECTION phase executed: primary_language detected, confidence ≥ 0.5
- [ ] GRAPH phase executed: symbol_table.total_symbols > 0, repo_map generated
- [ ] ANALYSIS phase executed: architecture identified, ≥2 layers (or explained why fewer)
- [ ] All three sections (`detect`, `graph`, `analyze`) present in `state_updates`
- [ ] `compound: true` flag set in output
- [ ] `module_target` matches assigned module path
- [ ] If any phase failed: `error.phase` correctly identifies "detection", "graph", or "analysis"
- [ ] If detection failed: no graph/analyze/map/database sections in output (clean failure)
- [ ] If graph failed: detect section still valid; analyze runs without repo-map (lower quality OK)
- [ ] If analysis failed: detect and graph sections still valid and complete
- Min pass: 6/10 (all three phase core checks + structural correctness)

### Report Subagent (haiku)
- [ ] Summary includes all phases
- [ ] Confidence scores reported
- [ ] Recommendations present (if applicable)
- [ ] Mode-appropriate format used
- Min pass: 4/4

---

## ORCHESTRATOR-LEVEL QUALITY

### State Merge Validation
- [ ] Subagent returned expected phase key in `state_updates`
- [ ] All required fields present per `deps/state-contract.md`
- [ ] No type mismatches (string where array expected, etc.)
- [ ] Confidence values in [0, 1] range

### Monorepo Merge Validation
- [ ] All module results received (or partial failures logged)
- [ ] Aggregated `primary_language` consistent
- [ ] Framework union contains no duplicates
- [ ] Dependency graph has no orphan nodes after merge

### Pipeline Parallelism Validation (v4.2)
- [ ] Execution mode correctly selected (pipeline ≤3 / batch 4+ / sequential single)
- [ ] Compound subagents: `compound: true` flag present in results
- [ ] Compound subagents: `module_target` matches expected module path
- [ ] Compound subagents: all three sections (`detect`, `graph`, `analyze`) present (or `error.phase` explains absence)
- [ ] Per-module status tracked: `state.detect.modules[].status` populated for each module
- [ ] Graph results present per module (or `error.phase="graph"` explains absence)
- [ ] Partial failures: failed modules excluded from aggregation, not silently dropped
- [ ] Merge validation: `merge_viable == true` (at least one module succeeded)
- [ ] Merge validation: `total_modules_merged` logged, matches expected count or documented why not
- [ ] No cross-contamination: module A's detection/graph data not mixed with module B's

### Pipeline Integrity
- [ ] Each subagent called in correct order (DISCOVER → DETECT → GRAPH → ANALYZE → CRITIQUE → GENERATE → VERIFY → REPORT)
- [ ] Blocking gates enforced (no generation before critique passes)
- [ ] Parallel subagents (if monorepo) all completed before merge
- [ ] Final artifact set matches planned artifact set
- [ ] Pipeline mode: no inter-phase barrier between detection, graph, and analysis (compound call)
- [ ] Batch mode: 3 waves (DETECT → merge → GRAPH → merge → ANALYZE → merge)

---

## BENEFITS

- **Early failure detection**: Subagent self-checks catch issues before orchestrator merge
- **Layered validation**: Orchestrator catches what subagents miss (cross-subagent consistency)
- **Quality metrics**: Track per-subagent quality over time
- **Debugging**: Isolate which subagent/phase failed and why
- **Gate enforcement**: Blocking gates prevent bad artifacts from being generated/delivered

**SEE:** meta-agent v7.0 STEP_QUALITY for full specification
