# Edge Cases & Limitations

**Purpose:** Known limitations and edge cases for project-researcher agent.

**Load when:** Encountering unexpected behavior or low confidence scores.

---

## LIMITATIONS & EDGE CASES

### Known Limitations

| Limitation | Impact | Workaround |
|------------|--------|------------|
| **Small codebases** (<10 files) | Low confidence scores | Manual artifact creation preferred |
| **Multi-language projects** | May select wrong primary | DISCOVER phase picks per-module strategy (v3.0) |
| **Monorepos** | Was: generic analysis. Now: native support | DISCOVER phase detects modules automatically |
| **Generated code heavy** | Skews pattern detection | Exclude vendor/ node_modules/ generated/ |
| **Legacy inconsistency** | Conflicting patterns found | Use as starting point, manual refinement |
| **No clear entry point** | Can't map application flow | Manual entry point documentation |
| **tree-sitter MCP unavailable** | Falls back to ast-grep, then grep | Configure MCP server or install ast-grep |
| **ast-grep unavailable** | Falls back to grep (lower confidence) | Install: `npm install -g @ast-grep/cli` |
| **go list unavailable** | Can't build full dependency graph | tree-sitter/AST/grep import analysis as fallback |

### Edge Cases

#### Monorepos (improved in v3.0)
```
project/
├── services/api/ (Go)
├── services/auth/ (Go)
├── frontend/ (TypeScript)
└── pkg/shared/ (Go)
```

**Behavior (v3.0):** DISCOVER phase detects modules, classifies types, maps inter-module dependencies, selects strategy.
**Strategy:** `per-module-with-shared-context` (same language, ≤5 modules) or `per-module` (different languages)

**Output:**
```yaml
discover:
  is_monorepo: true
  modules:
    - path: "services/api"
      language: "go"
      type: "service"
    - path: "services/auth"
      language: "go"
      type: "service"
    - path: "frontend"
      language: "typescript"
      type: "app"
    - path: "pkg/shared"
      language: "go"
      type: "library"
  strategy: "per-module"
```

#### Multi-Language Projects (improved in v3.0)
```
project/
├── backend/ (Go - 60 files)
└── frontend/ (TypeScript - 65 files)
```

**Behavior (v3.0):** DISCOVER detects two modules, analyzes each with appropriate language patterns.
**Previous workaround:** No longer needed — DISCOVER handles this natively.

#### Legacy Codebases
```
Inconsistent patterns:
- Some files use Repository pattern
- Others use direct DB access
- Mixed error handling styles
```

**Behavior:** Low confidence (40-60%), generic artifacts
**AST impact:** AST analysis may still detect patterns more accurately than grep
**Recommendation:** Use as reference, manually create targeted skills

#### Greenfield Projects (<20 files)
```
Early stage, patterns not established
```

**Behavior:** VERY LOW confidence (<30%)
**Recommendation:** Skip artifact generation, manual setup

#### No Database Access
```
Project has no database layer
```

**Behavior:** DATABASE phase skipped automatically
**Impact:** No entity-table mapping, repository patterns may be generic

#### MCP Unavailable
```
PostgreSQL MCP server not configured
```

**Behavior:** DATABASE phase skipped with warning
**Impact:** No schema analysis, manual database documentation needed

#### tree-sitter MCP Unavailable
```
MCP tree-sitter server not configured or not running
```

**Behavior:** Falls back to ast-grep CLI. If ast-grep also unavailable → grep fallback. Detection method recorded as "ast-grep" or "grep" in state. GRAPH phase uses simplified fan-in ranking instead of full PageRank.
**Impact:** Slightly lower confidence for ast-grep (-0.03), significantly lower for grep (-0.10). Repo-map may be less accurate (no cross-file reference tracking).
**Recommendation:** Configure tree-sitter MCP server for best results.

#### ast-grep Unavailable
```
ast-grep / sg command not found
```

**Behavior:** Falls back to grep equivalents. Detection method recorded as "grep" in state. Confidence lowered by 0.05-0.15 depending on pattern.
**Impact:** Higher false positive rate, lower confidence scores
**Recommendation:** Install ast-grep: `npm install -g @ast-grep/cli`. Or configure tree-sitter MCP (preferred).

#### GRAPH Phase: Empty Symbol Table
```
tree-sitter MCP returned 0 symbols for project
```

**Behavior:** GRAPH outputs `total_symbols: 0`, repo-map is empty. ANALYSIS proceeds without repo-map context (falls back to direct AST/grep analysis).
**Impact:** ANALYSIS may be slower and less accurate. CRITIQUE flags missing graph data.
**Recommendation:** Check if project language is supported by tree-sitter. Verify file exclusion rules aren't too aggressive.

#### GRAPH Phase: PageRank Fails to Converge
```
Max iterations reached without convergence
```

**Behavior:** Falls back to fan-in approximation ranking. `pagerank.convergence = false`.
**Impact:** Symbol ranking may be suboptimal. Repo-map still generated but less well-ordered.
**Recommendation:** Increase max_iterations or check for unusual graph structures (very dense, many cycles).

#### Dependency Graph Incomplete
```
`go list` not available (no Go toolchain) or not a Go project
```

**Behavior:** Falls back to tree-sitter/AST/grep import parsing. Graph may be incomplete.
**Impact:** Fan-in/fan-out metrics approximate, circular dependency detection less reliable
**Recommendation:** Ensure Go toolchain is available for Go projects. tree-sitter MCP provides better coverage than grep.

### Confidence Thresholds

| Scenario | Expected Confidence | Action |
|----------|---------------------|--------|
| Well-structured + AST available | 85-95% (HIGH) | Trust artifacts |
| Well-structured + grep only | 75-90% (HIGH) | Trust with minor review |
| Moderate structure, some inconsistency | 60-79% (MEDIUM) | Review + adjust |
| Legacy, mixed patterns | 40-59% (LOW) | Use as starting point |
| Greenfield, minimal code | <40% (VERY LOW) | Manual setup |

### Analysis Method Confidence Impact

| Analysis Method | Confidence Modifier | Notes |
|----------------|-------------------| ----- |
| tree-sitter MCP (symbols + queries) | +0.0 (baseline) | Full AST, typed captures |
| tree-sitter MCP (analyze_project) | +0.02 | Cross-file analysis |
| ast-grep match | -0.03 | Pattern-only, no cross-file |
| Manifest match (go.mod, package.json) | +0.0 (baseline) | Version/dep source of truth |
| grep match (single pattern) | -0.05 | False positives possible |
| grep match (complex regex) | -0.10 | Higher false positive rate |
| Heuristic (directory name only) | -0.15 | Weakest signal |

### Orchestration Edge Cases (v4.0)

#### Subagent Timeout / Failure

| Scenario | Behavior | Recovery |
|----------|----------|----------|
| Subagent returns `status: "failure"` | Retry once with reduced scope | If retry fails: WARN + continue (non-gate) or FATAL (gate) |
| Subagent returns malformed YAML | Treat as failure | Same retry logic |
| Subagent hangs (Task tool timeout) | Task tool handles timeout | Orchestrator receives error, applies retry |
| Subagent returns `status: "partial"` | Merge partial state, log warnings | Continue pipeline with degraded data |

#### Monorepo Parallel Merge Edge Cases

| Scenario | Behavior | Recovery |
|----------|----------|----------|
| **Conflicting primary_language** | Modules disagree on language | Majority vote; tie → largest module wins |
| **One module fails, others succeed** | Partial merge | Include succeeded modules, mark failed as `partial: true` |
| **Framework version conflict** | Same framework, different versions across modules | Use highest version, log warning |
| **Shared module has no language files** | Detection returns empty | Exclude from aggregation, treat as config/docs module |
| **>5 modules detected** | Many parallel subagents | Strategy auto-switches to `per-module` (no shared context) |
| **Inter-module circular dependency** | Graph merge creates cycle | Log warning, mark cycle edges in dep graph |

#### Pipeline Parallelism Edge Cases (v4.1)

| Scenario | Behavior | Recovery |
|----------|----------|----------|
| **Compound subagent: detection fails** | `error.phase="detection"`, entire module excluded | Other modules continue; FATAL only if all fail |
| **Compound subagent: graph fails** | `error.phase="graph"`, detection results merged, analysis runs without repo-map | Partial state; CRITIQUE flags missing graph |
| **Compound subagent: analysis fails** | `error.phase="analysis"`, detection+graph results still merged | Partial state; CRITIQUE flags missing analysis |
| **Compound subagent: timeout** | Task tool returns error for that module | Module excluded from merge; others unaffected |
| **All compound subagents fail** | No modules merged | FATAL "All modules failed detection/analysis" |
| **Mixed success: 2/3 succeed** | Partial merge with 2 modules | WARN + continue; CRITIQUE evaluates partial data quality |
| **Module count crosses threshold (exactly 3)** | Pipeline mode selected | Pipeline mode (≤3 boundary inclusive) |
| **Module count = 4** | Batch mode selected | Batch mode (>3 boundary) |
| **Compound model unavailable (opus)** | Fallback to sonnet for compound | Analysis quality degrades; detection unaffected |
| **Compound output too large** | Single Task call returns truncated YAML | Treat as failure for that module; retry with reduced scope |
| **Modules have vastly different sizes** | One compound takes 5x longer than others | All wait for slowest (inherent to parallel-wait-all pattern) |

#### State Contract Violations

| Scenario | Behavior | Recovery |
|----------|----------|----------|
| Subagent returns extra fields | Ignored (orchestrator only reads expected fields) | None needed |
| Subagent omits required output fields | State merge fails validation | Retry with explicit field requirements |
| Confidence scores out of range [0,1] | Clamp to valid range | Log warning |
| Duplicate entries in merged arrays | Deduplicate by key field | Automatic |

#### Gate Failures

| Gate | Max Attempts | On Final Failure |
|------|-------------|-----------------|
| CRITIQUE (inline) | 2 | FATAL — manual review required |
| VERIFY (subagent) | 2 (re-generate + re-verify) | FATAL — artifacts may be invalid |

**Critique gate loop:**
```
CRITIQUE fails → fix issues (re-run analysis if needed) → re-CRITIQUE → still fails → FATAL
```

**Verify gate loop:**
```
VERIFY fails → re-run generation with fix instructions → re-VERIFY → still fails → FATAL
```

#### Model Unavailability

| Scenario | Behavior |
|----------|----------|
| Opus unavailable | Analysis/critique quality degrades; no automatic fallback (user must reconfigure) |
| Haiku unavailable | Discovery/report use sonnet (higher cost, same quality) |
| All models available | Normal tiered execution |

---

### Unsupported Scenarios

**Agent will FAIL (FATAL) on:**
- Empty directories
- No source files found
- Path doesn't exist
- Unrecognized file types only (.txt, .md, etc.)
- State validation failure (missing required fields between phases)
- Both blocking gates fail after max retries

**Agent will WARN (proceed with low confidence) on:**
- Mixed frameworks (e.g., both Gin and Echo)
- Conflicting architecture patterns
- Small sample size (<10 files)
- No tests found
- tree-sitter MCP unavailable (falls back to ast-grep or grep)
- ast-grep unavailable (proceeds with grep)
- GRAPH phase: empty symbol table or PageRank non-convergence
- Dependency graph incomplete (go list unavailable)
- One or more monorepo modules failed detection/graph/analysis (partial merge)
- Subagent returned partial results
