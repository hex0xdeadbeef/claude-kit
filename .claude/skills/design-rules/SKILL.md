---
name: design-rules
description: Design phase rules for /designer command. Load at /designer startup (step 0). Covers spec quality, design checklist, approach evaluation criteria.
disable-model-invocation: true
---

# Design Rules

## Purpose
Guidelines for the /designer command to produce high-quality design specs that reduce plan-review iterations.

## Instructions

### Step 1: Load at /designer startup
Read this SKILL.md for overview. Supporting files loaded on-demand per phase.

### Step 2: Use phase-driven loading
- Phase 3 (PROPOSE) → read [Spec Quality](spec-quality.md) for approach evaluation criteria
- Phase 4 (WRITE SPEC) → read [Design Checklist](design-checklist.md) for self-verification
- Phase 5 (USER GATE) → verify checklist before presenting to user

## Spec Quality Criteria

| Criterion | Required | Check |
|-----------|----------|-------|
| Context describes current state | Yes | Not just "add X" but "currently Y exists, need X because Z" |
| Scope has IN and OUT | Yes | OUT items have explicit reasons |
| At least 2 approaches compared | Yes | With pros/cons for each |
| Selected approach has rationale | Yes | References constraints from requirements |
| Key decisions are numbered | Yes | Each has rationale and impact |
| Risks have severity and mitigation | Yes | HIGH risks must have concrete mitigation |
| Acceptance criteria are verifiable | Yes | Each can be checked as pass/fail |

## Anti-Patterns

| Anti-Pattern | Why Bad | Fix |
|---|---|---|
| "The obvious approach is..." | Skips exploration, may miss better options | Always compare at least 2 |
| Spec without OUT scope | Scope creep during planning | Explicitly list what's excluded |
| Vague acceptance criteria ("works well") | Can't verify | Make criteria concrete and testable |
| No risks identified | Every design has risks | Identify at least 1 per approach |
| Copying task description as context | No analysis | Describe current state, not just goal |

## Common Issues

### Designer skips CLARIFY phase
**Cause:** Task seems clear.
**Fix:** Even "clear" tasks benefit from scope IN/OUT confirmation. At minimum, confirm scope.

### User rejects all approaches
**Cause:** Missing constraint not captured.
**Fix:** Ask: "What constraint am I missing?" — don't generate more approaches without new information.

## References
- [Spec Quality](spec-quality.md) — detailed quality criteria, approach evaluation matrix
- [Design Checklist](design-checklist.md) — phase-by-phase self-verification
