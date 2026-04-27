# TDD Rules — Coder Integration Details

Overflow content from `tdd-rules/SKILL.md` per T1.7 size-budget allowance (PR-00000001 plan-review note). Loaded on-demand; not part of the SKILL.md eager load.

## Common rationalisations

| Excuse | Reality |
|--------|---------|
| "Too simple to test" | Simple code breaks. Test takes 30 seconds. |
| "I'll write tests after" | Tests passing immediately prove nothing. |
| "Tests-after achieve same goals" | Tests-after = "what does this do?" Tests-first = "what should this do?" |
| "Already manually tested" | Ad-hoc ≠ systematic. No record, can't re-run with the project test command. |
| "Deleting X hours is wasteful" | Sunk cost fallacy. Keeping unverified code is technical debt. |
| "Hard to test = skip test" | Listen to the test. Hard to test = hard to use. Simplify the interface. |
| "Need to explore first" | Fine. Throw away exploration, start with TDD. |
| "TDD will slow me down" | TDD faster than debugging. Project test command catches regressions immediately. |
| "Manual `curl`/`run` is faster" | Manual doesn't prove edge cases. You'll re-test every change. |
| "Existing code has no tests" | You're improving it. Add tests for the code you're changing. |
| "I'll write test after confirming fix works" | Untested fixes don't stick. Test first proves it. |
| "Keep as reference, write tests first" | You'll adapt it. That's testing after. Delete means delete. |

## Red flags — STOP and start over

- Code written before test
- Test written after implementation
- Test passes immediately on first run
- Can't explain why test failed
- Tests added "later"
- Rationalising "just this once"
- "I already manually tested it"
- "Tests-after achieve the same purpose"
- "It's about spirit not ritual"
- "Keep as reference" or "adapt existing code"
- "Already spent X hours, deleting is wasteful"
- "TDD is dogmatic, I'm being pragmatic"
- "This is different because..."

**All of these mean: delete code, run the project test command, start over with TDD.**

## Integration with Sequential Thinking

When a Part contains complex logic (3+ conditions, state machines):

1. **RED** — write failing test exercising the complex scenario
2. Use Sequential Thinking to design implementation strategy (between RED and GREEN)
3. **GREEN** — minimal implementation per ST analysis
4. **REFACTOR** — clean up

Sequential Thinking is used INSIDE the GREEN phase — after the test is written, before the implementation.

## Integration with code-researcher

When EVALUATE phase or RED phase encounters unfamiliar patterns:

- Use code-researcher agent (Task tool, haiku) to investigate existing patterns
- Then proceed with RED-GREEN-REFACTOR aligned with findings

## Relationship with coder-rules RULE_5

- **RULE_5** ("Tests Pass") — gate: code NOT ready until tests pass (exit criterion)
- **TDD rule** ("Tests First") — process: write test BEFORE production code (entry criterion)
- These are orthogonal. RULE_5 checks the end state; TDD controls the workflow order. Both active simultaneously without conflict.

## When to expand this file

Add to this file (rather than to `SKILL.md`) when:
- New per-language extras are too large for the per-shape file (e.g., benchmark TDD patterns specific to one language)
- New rationalisations / red flags emerge from real review iterations
- Cross-skill integration patterns (e.g., systematic-debugging × tdd-rules) need documentation

Do NOT add canonical Red-Green-Refactor examples here — those live in `tdd-shapes/<lang>.md`.
