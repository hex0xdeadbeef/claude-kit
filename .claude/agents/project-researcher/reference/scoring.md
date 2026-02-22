# Confidence Scoring System

Reference guide for confidence scoring in project analysis.

---

## Score Levels

| Score | Meaning | Criteria |
|-------|---------|----------|
| HIGH | Very confident | Multiple clear indicators, consistent patterns |
| MEDIUM | Reasonably confident | Some indicators, minor inconsistencies |
| LOW | Uncertain | Few indicators, mixed patterns |
| UNKNOWN | Can't determine | No clear indicators |

---

## Architecture Confidence

### HIGH Confidence

- Clear directory structure matching known pattern
- Explicit architecture documentation
- Consistent layer separation
- No dependency violations
- Multiple confirming indicators

**Example indicators:**
```
internal/domain/      ← Domain layer
internal/usecase/     ← Application layer
internal/repository/  ← Infrastructure layer
cmd/                  ← Entry points
```

### MEDIUM Confidence

- Some structure matches pattern
- Implicit pattern usage
- Minor inconsistencies
- 1-2 dependency violations

**Example indicators:**
```
service/      ← Unclear if usecase or infrastructure
handler/      ← Presentation layer
model/        ← Could be domain or DTO
```

### LOW Confidence

- No clear structure
- Mixed patterns
- Multiple violations
- Inconsistent organization

---

## Convention Confidence

### Naming Conventions

| Confidence | Criteria |
|------------|----------|
| HIGH | 90%+ consistency in detected patterns |
| MEDIUM | 70-90% consistency |
| LOW | <70% consistency |

**Example calculation:**
```bash
# File naming consistency
SNAKE_CASE=$(find . -name "*_*.go" | wc -l)
KEBAB_CASE=$(find . -name "*-*.go" | wc -l)
CAMEL_CASE=$(find . -name "*[a-z][A-Z]*.go" | wc -l)

TOTAL=$((SNAKE_CASE + KEBAB_CASE + CAMEL_CASE))
DOMINANT=$(max $SNAKE_CASE $KEBAB_CASE $CAMEL_CASE)
CONSISTENCY=$((DOMINANT * 100 / TOTAL))
```

### Testing Conventions

| Confidence | Criteria |
|------------|----------|
| HIGH | Single test framework, consistent patterns |
| MEDIUM | Dominant framework with some variations |
| LOW | Multiple frameworks, inconsistent patterns |

---

## Pattern Detection Confidence

### Design Patterns

| Confidence | Criteria |
|------------|----------|
| HIGH | Explicit pattern implementation, documentation |
| MEDIUM | Implicit pattern usage, recognizable structure |
| LOW | Unclear intent, partial implementation |

### Error Handling

| Confidence | Criteria |
|------------|----------|
| HIGH | Consistent wrapping, sentinel errors, const op |
| MEDIUM | Mostly consistent, some variations |
| LOW | Mixed approaches, inconsistent |

### Logging

| Confidence | Criteria |
|------------|----------|
| HIGH | Single logger, structured, consistent levels |
| MEDIUM | Dominant logger with variations |
| LOW | Multiple loggers, inconsistent formatting |

---

## Area-Specific Scoring

### Technology Stack

| Area | HIGH | MEDIUM | LOW |
|------|------|--------|-----|
| Language | go.mod + *.go | Only *.go | Mixed indicators |
| Framework | Explicit import | Indirect usage | Unclear |
| Database | Driver + schema | Driver only | Config only |

### Code Quality

| Area | HIGH | MEDIUM | LOW |
|------|------|--------|-----|
| Coverage | >80% | 50-80% | <50% |
| Complexity | Low cyclomatic | Moderate | High |
| Documentation | Comprehensive | Partial | Missing |

---

## Aggregate Scoring

### Overall Project Confidence

```
OVERALL = weighted_average(
    Architecture * 3,    # Most important
    Conventions * 2,     # Important
    Testing * 2,         # Important
    Error Handling * 1,  # Standard
    Logging * 1          # Standard
)
```

### Thresholds

| Score | Overall Confidence |
|-------|-------------------|
| 8-10 | HIGH |
| 5-7 | MEDIUM |
| 0-4 | LOW |

---

## Reporting

### Confidence Table Format

```markdown
| Area | Confidence | Notes |
|------|------------|-------|
| Architecture | HIGH | Clear Clean Arch structure |
| Naming conventions | HIGH | Consistent patterns |
| Testing patterns | MEDIUM | Mixed styles detected |
| Error handling | HIGH | Consistent %w wrapping |
| Logging | MEDIUM | Multiple loggers used |
```

### Low Confidence Recommendations

When confidence is LOW or UNKNOWN:
1. List specific areas needing manual review
2. Suggest additional analysis steps
3. Recommend documentation review
4. Flag for human verification

---

## Mode-Specific Scoring

### CREATE Mode

- Score based on initial analysis only
- No baseline for comparison
- All areas evaluated fresh

### AUGMENT Mode

- Score existing + new analysis
- Compare with detected patterns
- Note discrepancies

### UPDATE Mode

- Score changes since last analysis
- Track confidence changes
- Flag degradation

**Confidence Change Tracking:**

```markdown
| Area | Previous | Current | Change |
|------|----------|---------|--------|
| Architecture | HIGH | HIGH | No change |
| Testing | MEDIUM | HIGH | Improved |
| Error Handling | HIGH | MEDIUM | Degraded |
```
