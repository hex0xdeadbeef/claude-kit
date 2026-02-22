# Edge Cases & Limitations

**Purpose:** Known limitations and edge cases for project-researcher agent.

**Load when:** Encountering unexpected behavior or low confidence scores.

---

## LIMITATIONS & EDGE CASES

### Known Limitations

| Limitation | Impact | Workaround |
|------------|--------|------------|
| **Small codebases** (<10 files) | Low confidence scores | Manual artifact creation preferred |
| **Multi-language projects** | May select wrong primary | Analyze per language separately |
| **Monorepos** | Analyzes from given path only | Run per module/service |
| **Generated code heavy** | Skews pattern detection | Exclude vendor/ node_modules/ |
| **Legacy inconsistency** | Conflicting patterns found | Use as starting point, manual refinement |
| **No clear entry point** | Can't map application flow | Manual entry point documentation |

### Edge Cases

#### Monorepos
```
project/
├── service-a/ (Go)
├── service-b/ (Python)
└── shared/
```

**Behavior:** Analyzes from given path
**Recommendation:** Run once per service
```bash
project-researcher ./service-a
project-researcher ./service-b
```

#### Multi-Language Projects
```
project/
├── backend/ (Go - 60 files)
└── frontend/ (TypeScript - 65 files)
```

**Behavior:** Selects language with most files (TypeScript)
**Recommendation:** Analyze backend separately if Go is primary
```bash
project-researcher ./backend
```

#### Legacy Codebases
```
Inconsistent patterns:
- Some files use Repository pattern
- Others use direct DB access
- Mixed error handling styles
```

**Behavior:** Low confidence (40-60%), generic artifacts
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

### Confidence Thresholds

| Scenario | Expected Confidence | Action |
|----------|---------------------|--------|
| Well-structured, mature project | 80-95% (HIGH) | Trust artifacts |
| Moderate structure, some inconsistency | 60-79% (MEDIUM) | Review + adjust |
| Legacy, mixed patterns | 40-59% (LOW) | Use as starting point |
| Greenfield, minimal code | <40% (VERY LOW) | Manual setup |

### Unsupported Scenarios

**Agent will FAIL (FATAL) on:**
- Empty directories
- No source files found
- Path doesn't exist
- Unrecognized file types only (.txt, .md, etc.)

**Agent will WARN (proceed with low confidence) on:**
- Mixed frameworks (e.g., both {framework_a} and {framework_b})
- Conflicting architecture patterns
- Small sample size (<10 files)
- No tests found
