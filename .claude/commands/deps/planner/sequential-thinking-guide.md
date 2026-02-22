# Sequential Thinking Guide for Planner

## Purpose

Sequential Thinking MCP tool should be used for complex architectural decisions in planning phase.

## When Required

```yaml
sequential_thinking_required:
  - condition: "Альтернатив ≥ 3"
    required: true
    example: "Choosing between REST, GraphQL, gRPC for API"

  - condition: "Слоёв архитектуры ≥ 4"
    required: true
    example: "Feature affects domain, usecase, repository, api layers"

  - condition: "Новый паттерн/интеграция"
    required: true
    example: "Integrating new external service, plugin system"

  - condition: "Parts в плане ≥ 5"
    required: true
    example: "Plan has Database, Domain, Contract, Repository, UseCase, API, Tests"

  - condition: "Trade-offs неочевидны"
    required: true
    example: "Performance vs maintainability, simplicity vs extensibility"
```

## Usage Pattern

```yaml
mcp__sequential-thinking__sequentialthinking:
  thought: "Analyzing approach for {task}"
  thoughtNumber: 1
  totalThoughts: 5  # минимум для архитектурных решений
  nextThoughtNeeded: true
```

## Analysis Steps

```yaml
steps:
  - step: 1
    action: "Определить constraints и requirements"
    output: "List of non-negotiable constraints"

  - step: 2
    action: "Перечислить все возможные подходы (минимум 3)"
    output: "Table: Approach | Pros | Cons"

  - step: 3
    action: "Проанализировать trade-offs каждого"
    output: "Detailed comparison against constraints"

  - step: 4
    action: "Выбрать оптимальный с обоснованием"
    output: "Selected approach with rationale"

  - step: 5
    action: "Верифицировать выбор против constraints"
    output: "Verification checklist passed"
```

## Output in Plan

When Sequential Thinking is used, include in plan:

```markdown
## Architecture Decision

**Analyzed via Sequential Thinking**

**Alternatives considered:**
1. {Approach 1} — {why rejected}
2. {Approach 2} — {why rejected}
3. {Approach 3} — {why rejected}

**Selected approach:** {Approach} — {rationale}

**Trade-offs accepted:**
- {Trade-off 1}: {justification}
- {Trade-off 2}: {justification}
```

## When NOT Required

Skip Sequential Thinking if:
- Standard CRUD operation
- Single layer affected
- Clear obvious solution with no alternatives
- Trivial changes (< 3 parts in plan)

**⚠️ If skipped, document why in plan:**
```
Sequential Thinking: NOT USED
Reason: Standard repository layer addition, follows existing pattern
```
