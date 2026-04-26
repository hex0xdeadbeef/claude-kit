# Data Flow Analysis

## Purpose

Understand WHERE data comes from and WHERE it goes BEFORE planning.

data_flow_analysis:
  questions:
    - "WHERE does data originate? (HTTP request, worker queue, CLI, migration, scheduled job, event stream)"
    - "WHO/WHAT inputs it? (user, system, external service, scheduled job)"
    - "IN WHAT format? (JSON, struct/object, query params, message envelope)"

  typical_paths:
    note: |
      Layer roles are abstract — resolve concrete names from
      .claude/PROJECT-KNOWLEDGE.md → LAYERS. The patterns below describe
      common data-flow shapes; layer NAMES vary per project.
    request_response: "<INPUT_LAYER> → <BUSINESS_LAYER> → <DATA_ACCESS_LAYER> → <STORAGE>"
    async_processing: "<EVENT_SOURCE> → <WORKER> → <BUSINESS_LAYER> → <DATA_ACCESS_LAYER> → <STORAGE>"
    query: "<INPUT_LAYER> → <BUSINESS_LAYER> → <DATA_ACCESS_LAYER> → <RESPONSE>"

  layer_placement:
    - check: "Data validation needed?"
      if_yes: "<INPUT_LAYER> (request binding + validation)"
    - check: "Business logic with calculations?"
      if_yes: "<BUSINESS_LAYER> (domain logic)"
    - check: "Data persistence needed?"
      if_yes: "<DATA_ACCESS_LAYER>"
    - check: "External service call?"
      if_yes: "Dedicated client/adapter package (typically a sibling of <DATA_ACCESS_LAYER>)"

<!-- EXAMPLE (lang: go) — Clean Architecture for a Go backend
  PROJECT-KNOWLEDGE.md → LAYERS: [models, repository, service, handler]
  Resolution:
    <INPUT_LAYER> = handler
    <BUSINESS_LAYER> = service
    <DATA_ACCESS_LAYER> = repository
  request_response: handler → service → repository → database
-->

<!-- EXAMPLE (lang: python) — Django MTV
  PROJECT-KNOWLEDGE.md → LAYERS: [model, manager, view]
  Resolution:
    <INPUT_LAYER> = view
    <BUSINESS_LAYER> = manager
    <DATA_ACCESS_LAYER> = model (Django ORM)
  request_response: view → manager → model → database
-->

## Output Format

```
## Data Flow Analysis
- Source: HTTP request / CLI / Event / Migration
- Entry point: `{path to entry-point file}`
- Path: <INPUT_LAYER> → <BUSINESS_LAYER> → <DATA_ACCESS_LAYER>
- Exit point: Response / DB record / Event
- Implementation layer: <layer> because <rationale>
```

## Critical Rule

**NEVER skip DATA_FLOW — wrong layer selection = wasted refactoring time.**
