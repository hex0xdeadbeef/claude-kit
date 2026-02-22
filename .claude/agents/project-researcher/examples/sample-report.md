# Sample Report Output

Example of final REPORT phase output for a Go Clean Architecture project.

---

## PROJECT RESEARCH REPORT

**Project:** {project_name}
**Path:** `/path/to/{project_name}`
**Mode:** CREATE
**Duration:** 47.3s
**Timestamp:** 2026-01-18 14:23:00 UTC

---

## EXECUTIVE SUMMARY

**Primary Language:** Go ({version})
**Architecture:** Clean Architecture (HIGH confidence: 92%)
**Build System:** Make + Docker
**Database:** {database} ({db_driver} + {codegen_tool})
**Testing:** {test_framework}

**Overall Confidence:** 87% (HIGH)

---

## DETECTION RESULTS

### Language Distribution
| Language | Files | Lines | Percentage |
|----------|-------|-------|------------|
| Go | 127 | 15,432 | 94.2% |
| SQL | 18 | 876 | 5.3% |
| Shell | 3 | 142 | 0.5% |

**Primary:** Go (clear majority)

### Frameworks & Libraries
| Type | Name | Confidence |
|------|------|------------|
| HTTP | {http_framework} | HIGH (95%) |
| Database | {db_driver} | HIGH (98%) |
| Code Gen | {codegen_tool} | HIGH (100%) |
| Testing | {test_framework} | MEDIUM (78%) |
| Logging | {logger} | HIGH (100%) |

### Build Tools
- Make (Makefile found)
- Docker (Dockerfile + docker-compose.yml)
- {linter} (config found)

---

## ARCHITECTURE ANALYSIS

**Pattern:** Clean Architecture
**Confidence:** HIGH (92%)

### Evidence
- ✅ Domain entities in `internal/{domain_layer}/`
- ✅ Interfaces in `internal/{contract_layer}/`
- ✅ Business logic in `internal/{usecase_layer}/`
- ✅ Infrastructure in `internal/{repository_layer}/`
- ✅ HTTP handlers in `internal/{api_layer}/`
- ✅ Background workers in `internal/{worker_layer}/`

### Layer Dependencies
```
cmd/{binary} → internal/{app_pkg}
  ↓
internal/{api_layer} → internal/{usecase_layer}
  ↓
internal/{usecase_layer} → internal/{contract_layer}
  ↓
internal/{repository_layer} → internal/{domain_layer}
```

**Violations:** 0 detected

### Patterns Detected
- Repository pattern (N implementations)
- DTO converters (entity ↔ API)
- Middleware chain (logging, metrics, auth extraction)
- Worker pool (background job processing)
- CQRS-lite (separate query services)

---

## PROJECT MAP

### Entry Points
1. **HTTP API** - `cmd/{binary}/main.go` → `internal/{api_layer}/*`
2. **Worker** - Background job processors in `internal/{worker_layer}/`

### Core Domain (N entities)
- {Entity1}
- {Entity2}
- {Entity3}
- {Entity4}
- {Entity5}
- {Entity6}

### Key Interfaces (N)
- {Entity1}Repository
- {Entity2}Repository
- {Entity3}Repository
- {Entity4}Repository
- {Entity5}Repository
- {Entity1}QueryService (CQRS)

### External Integrations
- {database} database
- {external_service} integration
- {observability_lib} metrics
- MCP Memory (architectural decisions)

---

## DATABASE ANALYSIS

**Schema:** {database}
**Tables:** N
**Confidence:** HIGH (entity-table mapping 100%)

| Entity | Table | Columns | Indexes |
|--------|-------|---------|---------|
| {Entity1} | {table_1} | N | N |
| {Entity2} | {table_2} | N | N |
| {Entity3} | {table_3} | N | N |
| {Entity4} | {table_4} | N | N |

**Alignment:** Perfect (all entities have corresponding tables)

---

## GENERATED ARTIFACTS

### CLAUDE.md
- **Size:** 185 lines ✅ (target: ≤200)
- **Sections:** Role, Tech Stack, Architecture, Commands, Quick Start
- **Commands:** N workflow commands
- **Skills:** N referenced
- **Rules:** N path-triggered rules

### Skills Created (N)
1. `{arch-pattern}` - Layer rules, import matrix
2. `error-handling` - const op, sentinel errors, wrap pattern
3. `database-patterns` - {codegen_tool} + {db_driver} transactions, converters
4. `testing-patterns` - Table-driven tests, mocks
5. `validation-patterns` - Validate at boundary strategy
6. `logging-patterns` - Logging by layer (middleware → repository)
7. `http-api-patterns` - Handlers, middleware, response patterns
8. `concurrency-patterns` - Goroutines, channels, worker pool

**Total:** N lines

### Rules Created (N)
Path-triggered rules for each layer:
- `{domain_layer}.md` - `internal/{domain_layer}/**/*.go`
- `{api_layer}-converter.md` - `internal/{api_layer}/converter/**/*.go`
- `{infra_layer}.md` - `internal/{infra_layer}/**/*.go`
- `validation.md` - `internal/{api_layer}/handler/**/*.go`
- `{usecase_layer}.md` - `internal/{usecase_layer}/**/*.go`
- `{repository_layer}.md` - `internal/{repository_layer}/**/*.go`
- `{worker_layer}.md` - `internal/{worker_layer}/**/*.go`
- `testing.md` - `**/*_test.go`
- ... (N more)

**Total:** N lines

### PROJECT-KNOWLEDGE.md
- **Size:** N lines
- **Sections:** Project Overview, Tech Stack, Architecture, Layers, Patterns, Database Schema, Testing Strategy

---

## QUALITY METRICS

### Phase Results
| Phase | Duration | Status | Quality Score |
|-------|----------|--------|---------------|
| VALIDATE | 0.2s | ✅ PASS | 4/4 |
| DETECT | 3.1s | ✅ PASS | 5/5 |
| ANALYZE | 8.7s | ✅ PASS | 6/6 |
| MAP | 12.4s | ✅ PASS | 4/4 |
| DATABASE | 5.2s | ✅ PASS | 3/3 |
| CRITIQUE | 2.8s | ✅ PASS | 4/4 |
| GENERATE | 11.6s | ✅ PASS | N/A |
| VERIFY | 3.3s | ✅ PASS | 5/5 |

### External Validation
| Check | Result |
|-------|--------|
| YAML Syntax | ✅ All valid |
| References | ✅ All exist (N refs checked) |
| Sizes | ✅ All within limits |
| Structure | ✅ All required sections present |
| Duplicates | ✅ No duplicates found |

### Confidence Breakdown
| Category | Score | Level |
|----------|-------|-------|
| Language Detection | 98% | HIGH |
| Framework Detection | 91% | HIGH |
| Architecture Pattern | 92% | HIGH |
| Layer Mapping | 89% | HIGH |
| Database Alignment | 100% | HIGH |
| **Overall** | **87%** | **HIGH** |

---

## RECOMMENDATIONS

### Immediate Actions
1. ✅ Generated artifacts ready to use
2. ✅ All validations passed
3. ✅ No manual adjustments needed

### Optional Enhancements
1. **Add more examples** to skills (currently 2-3 per skill)
2. **Document plugin system** in more detail (only basic coverage)
3. **Add E2E testing guide** (detected but not fully documented)
4. **Create troubleshooting guide** for common operational issues

### Maintenance
- Re-run in UPDATE mode after significant architecture changes
- Update PROJECT-KNOWLEDGE.md when adding new layers/patterns
- Regenerate skills if adding new frameworks

---

## ISSUES FOUND

None - all phases completed successfully with HIGH confidence.

---

## NEXT STEPS

1. Review generated `.claude/CLAUDE.md`
2. Test commands: `/planner`, `/coder`, `/workflow`
3. Verify path rules trigger correctly
4. Adjust skills if needed for project-specific nuances
5. Run `bd prime` to load beads context (if applicable)

---

✅ **PROJECT RESEARCH COMPLETE**

**Artifacts Location:** `.claude/`
**Total Files Created:** N
**Total Lines:** N
**Quality:** HIGH (87% confidence)

---

## APPENDIX: FILE MANIFEST

```
.claude/
├── CLAUDE.md (N lines)
├── PROJECT-KNOWLEDGE.md (N lines)
├── memory.json (MCP persistent context)
├── skills/
│   ├── {arch-pattern}/SKILL.md (N lines)
│   ├── error-handling/SKILL.md (N lines)
│   ├── database-patterns/SKILL.md (N lines)
│   ├── testing-patterns/SKILL.md (N lines)
│   ├── validation-patterns/SKILL.md (N lines)
│   ├── logging-patterns/SKILL.md (N lines)
│   ├── http-api-patterns/SKILL.md (N lines)
│   └── concurrency-patterns/SKILL.md (N lines)
├── rules/
│   ├── {domain_layer}.md (N lines)
│   ├── {api_layer}-converter.md (N lines)
│   ├── {infra_layer}.md (N lines)
│   ├── validation.md (N lines)
│   ├── {usecase_layer}.md (N lines)
│   ├── {repository_layer}.md (N lines)
│   ├── {worker_layer}.md (N lines)
│   ├── testing.md (N lines)
│   └── ... (N more)
└── commands/
    └── (none generated - using project defaults)
```
