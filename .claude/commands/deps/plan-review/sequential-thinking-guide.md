# Sequential Thinking Guide for Plan Review

purpose: "Detailed criteria for when to use Sequential Thinking during plan validation"

## When Required

```yaml
required_when:
  - criteria: "Parts ≥ 4"
    reason: "Complex multi-part plans need structured analysis"

  - criteria: "Слоёв архитектуры ≥ 3"
    reason: "Cross-layer data flow requires careful validation"

  - criteria: "Новый паттерн/интеграция"
    reason: "Novel approaches need exploration of alternatives"

  - criteria: "План > 150 строк"
    reason: "Large plans have hidden complexity"
```

## When NOT Required

```yaml
not_needed_when:
  - criteria: "Простой план (< 3 Parts, < 100 строк)"
    reason: "Manual checks sufficient for simple changes"

  - criteria: "Standard CRUD operations"
    reason: "Well-established patterns, low risk"

  - criteria: "Single-layer changes (e.g., только DTO)"
    reason: "No cross-layer complexity"
```

## Usage Pattern

```yaml
mcp__sequential-thinking__sequentialthinking:
  thought: "Validating architecture for {plan-name}"
  thoughtNumber: 1
  totalThoughts: 4
  nextThoughtNeeded: true

validation_steps:
  - step: 1
    action: "Проверить data flow между слоями"
    output: "Identify all layer boundaries crossed"

  - step: 2
    action: "Верифицировать каждый Part против Clean Architecture"
    output: "List violations or confirm compliance"

  - step: 3
    action: "Проверить edge cases и error paths"
    output: "Document untested scenarios"

  - step: 4
    action: "Финальный verdict с обоснованием"
    output: "APPROVED/NEEDS_CHANGES/REJECTED with reasons"
```

## Enforcement Rule

```yaml
enforcement:
  if_criteria_met_but_not_used:
    severity: MAJOR
    action: "Add as issue in verdict"
    rationale: "Complex plans need structured analysis to catch violations"

  if_used_when_not_needed:
    severity: MINOR
    action: "Note in verdict"
    rationale: "Over-analysis acceptable, better safe than sorry"
```
