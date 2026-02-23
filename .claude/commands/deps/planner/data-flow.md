# Data Flow Analysis

## Purpose

Understand WHERE data comes from and WHERE it goes BEFORE planning.

data_flow_analysis:
  questions:
    - "WHERE does data originate? (HTTP request, worker queue, CLI, migration)"
    - "WHO/WHAT inputs it? (user, system, external service, scheduled job)"
    - "IN WHAT format? (JSON, struct, query params)"

  typical_paths:
    note: "Adapt to your project's architecture. Common patterns:"
    request_response: "Entrypoint → Handler → Service/UseCase → Repository → Database"
    async_processing: "Queue/Event → Worker → Service → Repository → Database"
    query: "Entrypoint → Handler → Service → Repository → Response"

  layer_placement:
    - check: "Data validation needed?"
      if_yes: "Entrypoint/Handler layer (request binding + validation)"
    - check: "Business logic with calculations?"
      if_yes: "Service/UseCase layer (domain logic)"
    - check: "Data persistence needed?"
      if_yes: "Repository/Data access layer"
    - check: "External service call?"
      if_yes: "Dedicated client/adapter package"

## Output Format

```
## Data Flow Analysis
- Source: HTTP request / CLI / Event / Migration
- Entry point: `{path to handler/entrypoint}`
- Path: Handler → Service → Repository
- Exit point: Response / DB record / Event
- Implementation layer: [layer] because [rationale]
```

## Critical Rule

**NEVER skip DATA_FLOW — wrong layer selection = wasted refactoring time.**
