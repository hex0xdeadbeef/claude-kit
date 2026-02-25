# Task Analysis

Task classification and routing BEFORE planning begins.

---

## Purpose

Determine task type, complexity, and optimal route BEFORE planner starts research. Goal — trivial tasks should not go through the full 4-phase cycle.

**NEVER skip TASK ANALYSIS — wrong routing = wasted time on over-/under-planning.**

---

## Step 1: Classify Task Type

```yaml
task_types:
  - type: "new_feature"
    keywords: "add, create, implement, new endpoint, new"
    typical_complexity: M-XL

  - type: "bug_fix"
    keywords: "fix, bug, broken, not working"
    typical_complexity: S-M

  - type: "refactoring"
    keywords: "refactor, rewrite, extract, split"
    typical_complexity: M-L

  - type: "config_change"
    keywords: "config, parameter, environment variable"
    typical_complexity: S

  - type: "documentation"
    keywords: "documentation, README, describe, document"
    typical_complexity: S

  - type: "performance"
    keywords: "optimization, slow, performance, N+1, cache"
    typical_complexity: M-L

  - type: "integration"
    keywords: "integration, external service, API call, client"
    typical_complexity: L-XL
```

---

## Step 2: Estimate Complexity

```yaml
complexity_matrix:
  S:
    parts: "1"
    layers: "1"
    files: "1-2"
    examples:
      - "Add field to model"
      - "Fix typo"
      - "Update config"
    indicators:
      - "Changes in single architecture layer"
      - "No new dependencies"
      - "Pattern already exists in project"

  M:
    parts: "2-3"
    layers: "2"
    files: "3-5"
    examples:
      - "Add new field through all layers (model → controller → API)"
      - "Fix error handling bug in multiple places"
    indicators:
      - "Changes in 2 layers"
      - "Follows existing patterns"
      - "No architectural decisions"

  L:
    parts: "4-6"
    layers: "3+"
    files: "6-10"
    examples:
      - "New endpoint with database → domain → API"
      - "Refactor controller by splitting into services"
    indicators:
      - "Affects 3+ architecture layers"
      - "May require architectural decision"
      - "New SQL queries or migrations"

  XL:
    parts: "7+"
    layers: "4+"
    files: "10+"
    examples:
      - "New domain with full stack (DB → models → controller → API → tests)"
      - "Integration with external service"
      - "Plugin architecture"
    indicators:
      - "Cross-domain changes"
      - "New external system integration"
      - "Sequential Thinking needed for approach selection"
```

---

## Step 3: Route Decision

```yaml
routing:
  S:
    planner_mode: "--minimal"
    plan_review: "SKIP (optional)"
    code_review: "standard"
    sequential_thinking: "NOT needed"
    note: "Fast path — don't overload the process for trivial tasks"

  M:
    planner_mode: "standard"
    plan_review: "standard"
    code_review: "standard"
    sequential_thinking: "as needed"
    note: "Main working mode"

  L:
    planner_mode: "standard"
    plan_review: "standard"
    code_review: "standard + parallel agents (if >5 files)"
    sequential_thinking: "RECOMMENDED"
    note: "Full flow with possible review parallelization"

  XL:
    planner_mode: "full research"
    plan_review: "standard + Sequential Thinking REQUIRED"
    code_review: "standard + parallel agents"
    sequential_thinking: "REQUIRED"
    note: "Maximum flow — all checks, all tools"
```

---

## Step 4: Preconditions Check

```yaml
preconditions:
  always:
    - check: "git status clean?"
      fail_action: "WARN: uncommitted changes detected"

  if_beads:
    - check: "bd show <id> → not blocked?"
      fail_action: "STOP: task is blocked. SEE: bd blocked"
    - check: "Dependencies closed?"
      fail_action: "WARN: dependency <dep-id> still open"

  if_database:
    - check: "Schema up to date? (migrations applied)"
      fail_action: "WARN: pending migrations detected"

  if_external_library:
    - check: "Library in go.mod?"
      fail_action: "INFO: will need go get"
```

---

## Output Format

```yaml
## Task Analysis Result

Type: {new_feature | bug_fix | refactoring | config_change | documentation | performance | integration}
Complexity: {S | M | L | XL}
Route: {minimal | standard | full}
Sequential Thinking: {required | recommended | not_needed}
Plan Review: {skip | standard}
Preconditions: {all_clear | warnings_list}

Rationale: "{1-2 sentences explaining chosen complexity and route}"
```

---

## Examples

### Example 1: Simple Config Change

```
Input: "Add timeout parameter to HTTP server config"

Task Analysis:
  Type: config_change
  Complexity: S (1 Part, 1 layer — config only)
  Route: minimal
  Sequential Thinking: not_needed
  Plan Review: skip
  Rationale: "Standard config parameter addition, pattern already exists"
```

### Example 2: New API Endpoint

```
Input: "Add endpoint GET /api/v1/{resource}/:id"

Task Analysis:
  Type: new_feature
  Complexity: L (5 Parts: DB query + model + controller + handler + tests)
  Route: standard
  Sequential Thinking: recommended
  Plan Review: standard
  Rationale: "New endpoint through all layers, but follows existing pattern for this resource"
```

### Example 3: Plugin Architecture

```
Input: "Implement plugin system for worker"

Task Analysis:
  Type: new_feature
  Complexity: XL (new pattern, cross-domain, 10+ files)
  Route: full
  Sequential Thinking: required
  Plan Review: standard
  Rationale: "Architectural decision with 3+ alternatives, affects multiple domains"
```

---

## Re-Routing Mechanism

```yaml
re_routing:
  purpose: "Route correction if initial complexity estimate was inaccurate"
  severity: MEDIUM

  triggers:
    downgrade:
      - trigger: "plan-review: plan is simpler than expected"
        condition: "Parts < expected for route OR layers < expected"
        actions:
          L_to_M: "Remove mandatory Sequential Thinking, standard checks"
          M_to_S: "Skip plan-review in next iteration"
        example: "Classified as L (5 Parts), plan-review sees 2 Parts → downgrade to M"

      - trigger: "coder evaluate: plan is trivial"
        condition: "PROCEED without adjustments, 1-2 files"
        actions:
          M_to_S: "Simplified code-review (no parallel agents)"

    upgrade:
      - trigger: "plan-review: plan is more complex than expected"
        condition: "Parts > expected OR cross-domain dependencies found"
        actions:
          S_to_M: "Add full plan-review (was skipped)"
          M_to_L: "Add Sequential Thinking requirement"
        example: "Classified as S, but plan-review sees 4 Parts + 3 layers → upgrade to L"

      - trigger: "coder evaluate: hidden complexity"
        condition: "REVISE with 3+ adjustments OR RETURN"
        actions:
          M_to_L: "Add Sequential Thinking, return to planner"
          L_to_XL: "Mandatory Sequential Thinking, full research"
        example: "Classified as M, coder finds DB migration + new service needed → upgrade to L"

  tracking:
    - "Record re-routing in checkpoint: original_route → new_route + reason"
    - "Save to MCP Memory to improve task-analysis heuristics"
    - "Format: 'Re-routing: {task_type}/{original} → {new} because {reason}'"
```

---

## Anti-Patterns

**DON'T skip task analysis for "obvious" tasks**
```
# BAD: Jump straight to planning
/planner "add field to model"
→ Full research, full plan, full review for a 5-line change
```

**DO classify first, then route appropriately**
```
# GOOD: Classify → route → execute
Task Analysis: S complexity → /planner --minimal → skip plan-review → /coder
```

**DON'T ignore re-routing signals**
```
# BAD: plan-review finds 4 Parts but route stays S
Plan classified as S → plan-review finds cross-domain dependencies → continues with S route
```

**DO re-route when evidence contradicts classification**
```
# GOOD: re-route based on evidence
Plan classified as S → plan-review finds 4 Parts + 3 layers → upgrade to M/L
```

---

## SEE ALSO

- `shared-core.md` — Autonomy modes, pipeline phases, error handling
- `planner.md` — Receives classification as input context
