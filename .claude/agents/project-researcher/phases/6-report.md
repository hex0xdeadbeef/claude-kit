# PHASE 6: REPORT

**Goal:** Итоговый отчёт с рекомендациями.

---

## Report Format

```markdown
## Project Research Complete: <Project Name>

### Summary

| Metric | Value |
|--------|-------|
| Path | /path/to/project |
| Language | Go |
| Architecture | Clean Architecture |
| Layers | 4 ({layer_1}, {layer_2}, {layer_3}, cmd) |
| Entry points | 3 |
| Core entities | 5 |
| Test coverage style | Table-driven + {test_framework} |

### Analysis Confidence

| Area | Confidence | Notes |
|------|------------|-------|
| Architecture | HIGH | Clear Clean Arch structure |
| Naming conventions | HIGH | Consistent patterns |
| Testing patterns | MEDIUM | Mixed styles detected |
| Error handling | HIGH | Consistent %w wrapping |
| Logging | MEDIUM | Multiple loggers used |

### Generated Artifacts

**CREATE mode:**
| Type | Name | File | Status |
|------|------|------|--------|
| CLAUDE.md | - | .claude/CLAUDE.md | CREATED |
| Skill | arch | .claude/skills/arch/SKILL.md | CREATED |
| Skill | testing | .claude/skills/testing/SKILL.md | CREATED |
| Rule | domain | .claude/rules/domain.md | CREATED |

**AUGMENT mode:**
| Type | Name | File | Status |
|------|------|------|--------|
| CLAUDE.md | - | .claude/CLAUDE.md | PRESERVED |
| Skill | arch | .claude/skills/arch/SKILL.md | PRESERVED |
| Skill | testing | .claude/skills/testing/SKILL.md | PRESERVED |
| Skill | errors | .claude/skills/errors/SKILL.md | CREATED |
| Skill | logging | .claude/skills/logging/SKILL.md | CREATED |
| Rule | domain | .claude/rules/domain.md | PRESERVED |
| Rule | usecase | .claude/rules/usecase.md | CREATED |
| Rule | tests | .claude/rules/tests.md | CREATED |

### Recommendations

| # | Area | Recommendation | Priority |
|---|------|----------------|----------|
| 1 | Testing | Standardize on {test_framework} require | HIGH |
| 2 | Logging | Migrate all to {logger} | MEDIUM |
| 3 | Architecture | Add missing port interfaces | MEDIUM |

### Next Steps

**CREATE/AUGMENT mode:**
1. Review generated CLAUDE.md
2. Customize skills for project-specific patterns
3. Add project-specific commands if needed
4. Run `meta-agent audit` to verify quality
5. Reference PROJECT-KNOWLEDGE.md when working on the project
6. MCP memory loaded automatically for future sessions

**UPDATE mode:**
1. Review updated sections in PROJECT-KNOWLEDGE.md
2. Check recommendations for skill/rule updates
3. Review Change History for impact assessment
4. Validate updated memory.json entities
5. Consider re-running analysis if major architectural changes detected

### Technical Details

<Detailed analysis data for reference>
```

---

## UPDATE Mode Report Format

```markdown
## Project Research Update: <Project Name>

### Update Summary

| Metric | Value |
|--------|-------|
| Last Update | <Previous timestamp> |
| Current Update | <Current timestamp> |
| Commits Analyzed | 47 |
| Files Changed | 23 (15 modified, 5 new, 3 deleted) |
| Sections Updated | 4 |
| New Entities | 2 |
| Pattern Changes | 3 |

### Changes Detected

**Code Changes by Layer:**
- {layer_1}: 3 files (new entities: {Entity1}, {Entity2})
- {layer_2}: 8 files (new usecases: {Usecase1}, {Usecase2})
- {layer_3}: 12 files (new integrations: {integration_1}, {integration_2})

**New Patterns:**
- Error handling: Added custom error types
- Testing: Adopted {mock_tool} for mocking
- Logging: Migrated from {logger} to {logger}

**New Dependencies:**
- {dependency_1} v{version} ({purpose_1})
- {dependency_2} ({purpose_2})
- {dependency_3} ({purpose_3})

### Updated Sections

1. **Core Domain** (UPDATED)
   - Added: {Entity1}, {Entity2} entities
   - Updated: {Entity3} entity (new field)

2. **External Integrations** (UPDATED)
   - Added: {integration_1} integration
   - Added: {integration_2} storage

3. **Testing Patterns** (UPDATED)
   - Added: {mock_tool} usage patterns
   - Updated: Mock generation strategy

4. **Technology Stack** (UPDATED)
   - Added: 3 new dependencies
   - Updated: Go version bump

### Memory Updates

**Entities Updated:**
- Project: Added "{feature} support" observation
- Architecture: Added "{feature} subdomain" observation

**Entities Added:**
- {Entity1} (domain-entity): Core {entity} processing entity
- {integration_1} (external-integration): {integration} gateway

### Recommendations

| # | Area | Recommendation | Priority |
|---|------|----------------|----------|
| 1 | Skills | Update error-handling skill for custom error types | MEDIUM |
| 2 | Skills | Update testing skill for {mock_tool} patterns | MEDIUM |
| 3 | Rules | Consider adding {domain}-domain rule | LOW |

### Confidence

| Area | Previous | Current | Change |
|------|----------|---------|--------|
| Architecture | HIGH | HIGH | No change |
| Testing | MEDIUM | HIGH | Improved (consistent {mock_tool}) |
| Error Handling | HIGH | HIGH | Enhanced (custom types) |

### Next Review

Recommended: When {feature} is complete or 2 weeks from now
```

---

## Confidence Scoring

**SEE:** `reference/scoring.md` для confidence scoring system
