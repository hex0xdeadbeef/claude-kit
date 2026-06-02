# Spec Quality

## Approach Evaluation Matrix

When comparing approaches, evaluate each against:

| Criterion | Weight | How to Assess |
|-----------|--------|---------------|
| Feasibility | HIGH | Can it be implemented with current codebase/deps? |
| Complexity | HIGH | How many Parts/layers will /planner need? |
| Maintainability | MEDIUM | Will future changes be easy? |
| Risk | MEDIUM | What can go wrong? How bad? |
| Performance | LOW (unless explicit) | Only if task mentions performance |

## Spec Completeness Checklist

Before writing spec to file:
- [ ] Context section describes CURRENT state (not just desired state)
- [ ] Requirements have concrete IN/OUT scope
- [ ] At least 2 approaches with honest pros/cons
- [ ] Selected approach references specific constraints
- [ ] Key decisions explain WHY, not just WHAT
- [ ] Risks have severity (HIGH/MEDIUM/LOW) and mitigation strategy
- [ ] Acceptance criteria are pass/fail verifiable
- [ ] No implementation details (that's /planner's job)

## Quality Gates

| Gate | Trigger | Action |
|------|---------|--------|
| Spec < 30 lines | Too brief | Add missing sections |
| 0 risks identified | Unrealistic | Find at least 1 risk per approach |
| Acceptance criteria use vague words ("good", "proper", "clean") | Unverifiable | Rewrite as concrete checks |
| Selected approach has no rejected alternatives | No exploration | Add at least 1 alternative |
| design_critique block missing | No adversarial pass | Run Phase 3.5 critique before writing the spec |
| Finding with disposition not `addressed` and no rationale | Unjustified risk | Add a rationale or change the disposition |
| Lens skipped without "no finding — reason" | Incomplete critique | Apply the lens or state an explicit skip reason |
| Generic / boilerplate finding (not task-specific) | Theater | Replace with a concrete, task-bound finding or mark the lens skipped |

## Design Critique Completeness

The Phase 3.5 critique (see [Critique Lenses](critique-lenses.md)) writes the `design_critique`
block into the spec. Completeness rules:

- Every lens is applied — each yields a concrete task-bound finding OR an explicit `no finding — reason`.
- Every finding carries a disposition: `addressed`, `accepted-risk`, or `out-of-scope`.
- `accepted-risk` and `out-of-scope` findings REQUIRE a rationale.
- `unresolved_high` (HIGH findings not `addressed`) is surfaced at the user-approval gate.

This gate is a designer-agent self-check (advisory), not a blocking hook — consistent with the
contract-safety decision to keep the critique entirely in /designer command context (no
SubagentStop hook, no canonical-ID hash involvement).
