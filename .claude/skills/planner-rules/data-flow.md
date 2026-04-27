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

<!-- LAYER RESOLUTION — language-agnostic
  Layer roles are abstract slots: <INPUT_LAYER>, <BUSINESS_LAYER>, <DATA_ACCESS_LAYER>.
  Concrete layer NAMES come from PROJECT-KNOWLEDGE.md → LAYERS (ordered low-to-high).

  Resolution rule:
    <DATA_ACCESS_LAYER> = LAYERS[0]   (lowest layer — talks to storage)
    <BUSINESS_LAYER>    = LAYERS[1..N-1]  (middle layers)
    <INPUT_LAYER>       = LAYERS[N]   (highest layer — talks to outside world)

  If LAYERS is unset OR ARCHITECTURE_STYLE != layered, the data-flow path is
  computed without naming concrete layers — the planner uses abstract slot
  names verbatim and emits a NEEDS_VALIDATION marker on layer-allocation Parts.

  Per-language concrete examples are in .claude/skills/planner-rules/code-shapes/.
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
