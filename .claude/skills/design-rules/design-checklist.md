# Design Checklist

Self-verification at each /designer phase.

## Phase 1: EXPLORE CONTEXT
- [ ] Codebase areas identified (files, packages, patterns)
- [ ] Existing constraints documented
- [ ] .claude/PROJECT-KNOWLEDGE.md checked (if exists)

## Phase 2: CLARIFY REQUIREMENTS
- [ ] Critical questions asked (scope, priorities, constraints)
- [ ] User responded to all critical questions
- [ ] Scope IN/OUT defined
- [ ] Scope confirmed by user

## Phase 3: PROPOSE APPROACHES
- [ ] At least 2 approaches generated
- [ ] Each approach has pros AND cons
- [ ] Sequential Thinking used (if L/XL or >= 3 alternatives)
- [ ] Recommendation includes clear rationale
- [ ] Recommendation references specific constraints

## Phase 3.5: CRITIQUE / RED-TEAM
- [ ] critique-lenses.md loaded
- [ ] All lenses applied (each: concrete finding OR explicit "no finding — reason")
- [ ] Each finding has a disposition (addressed / accepted-risk / out-of-scope)
- [ ] accepted-risk / out-of-scope findings have a rationale
- [ ] No generic/boilerplate findings (each is task-specific)
- [ ] unresolved_high count surfaced for the user gate

## Phase 4: WRITE SPEC
- [ ] All spec-template sections filled
- [ ] Context describes current state, not just goal
- [ ] Key decisions have rationale and impact
- [ ] Risks have severity and mitigation
- [ ] Acceptance criteria are verifiable
- [ ] No implementation details (Parts, code examples)

## Phase 5: USER APPROVAL GATE
- [ ] Spec summary presented to user
- [ ] User explicitly approved (not assumed)
- [ ] Status set to "approved"
- [ ] Handoff payload formed with all required fields
