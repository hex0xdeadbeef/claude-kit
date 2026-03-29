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
