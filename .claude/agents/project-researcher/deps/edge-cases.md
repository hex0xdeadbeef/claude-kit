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
| **ast-grep unavailable** | Falls back to grep (lower confidence) | Install: `npm install -g @ast-grep/cli` |
| **go list unavailable** | Can't build full dependency graph | AST/grep import analysis as fallback |

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

#### ast-grep Unavailable
```
ast-grep / sg command not found
```

**Behavior:** All AST patterns fall back to grep equivalents. Detection method recorded as "grep" in state. Confidence lowered by 0.05-0.15 depending on pattern.
**Impact:** Higher false positive rate, lower confidence scores
**Recommendation:** Install ast-grep for best results: `npm install -g @ast-grep/cli`

#### Dependency Graph Incomplete
```
`go list` not available (no Go toolchain) or not a Go project
```

**Behavior:** Falls back to AST/grep import parsing. Graph may be incomplete.
**Impact:** Fan-in/fan-out metrics approximate, circular dependency detection less reliable
**Recommendation:** Ensure Go toolchain is available for Go projects

### Confidence Thresholds

| Scenario | Expected Confidence | Action |
|----------|---------------------|--------|
| Well-structured + AST available | 85-95% (HIGH) | Trust artifacts |
| Well-structured + grep only | 75-90% (HIGH) | Trust with minor review |
| Moderate structure, some inconsistency | 60-79% (MEDIUM) | Review + adjust |
| Legacy, mixed patterns | 40-59% (LOW) | Use as starting point |
| Greenfield, minimal code | <40% (VERY LOW) | Manual setup |

### AST vs Grep Confidence Impact

| Detection Method | Confidence Modifier |
|-----------------|-------------------|
| AST match | +0.0 (baseline) |
| Manifest match (go.mod, package.json) | +0.0 (baseline) |
| grep match (single pattern) | -0.05 |
| grep match (complex regex) | -0.10 |
| Heuristic (directory name only) | -0.15 |

### Unsupported Scenarios

**Agent will FAIL (FATAL) on:**
- Empty directories
- No source files found
- Path doesn't exist
- Unrecognized file types only (.txt, .md, etc.)
- State validation failure (missing required fields between phases)

**Agent will WARN (proceed with low confidence) on:**
- Mixed frameworks (e.g., both Gin and Echo)
- Conflicting architecture patterns
- Small sample size (<10 files)
- No tests found
- ast-grep unavailable (proceeds with grep)
- Dependency graph incomplete (go list unavailable)
