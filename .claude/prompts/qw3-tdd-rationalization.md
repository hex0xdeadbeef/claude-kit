---
title: "QW-3: Rationalization Tables for TDD"
feature: qw3-tdd-rationalization
task_type: enhance_existing
complexity: XL
status: implemented
plan_version: "1.0"
review_iteration: 1
created: "2026-03-29"
---

# Plan: TDD Rationalization Tables — enhance tdd-go SKILL.md

## Context

From cross-review Superpowers (QW-3): adapt the persuasion engineering layer from `superpowers-main/skills/test-driven-development/SKILL.md` into Claude Kit's `tdd-go` skill. Superpowers TDD skill uses rationalization tables (11 items), red flags (13 items), Iron Law formulation, and "violating the letter is violating the spirit" principle to resist model rationalization.

Claude Kit's tdd-go SKILL.md (153 lines) is a solid technical reference with Go examples, Red-Green-Refactor cycle, integration with coder Parts, and Common Issues. But it lacks the persuasion layer — no explicit rationalization countering, no red flags list, no Iron Law declaration.

**Goal:** Add Iron Law, rationalization table, and red flags sections to `tdd-go/SKILL.md`. Adapt TypeScript examples to Go. Preserve all existing content.

## Scope

### IN

- MODIFY `.claude/skills/tdd-go/SKILL.md` — add 4 new sections
- Adapt Superpowers rationalization table (11 items) to Go context
- Adapt red flags list (13 items) to Go context
- Add Iron Law section with Go-specific enforcement
- Add "violating the letter" principle statement

### OUT

- Changes to `references/patterns.md` or `references/examples.md` (existing, untouched)
- Changes to `/coder`, `/planner`, or other commands
- New files (everything fits in existing SKILL.md)
- Rewriting existing sections (preserve all current content)

## Research (completed)

### Superpowers TDD — key sections to adapt

**Iron Law (lines 31-46):**
```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```
- Write code before test? Delete it. Start over.
- No exceptions: Don't keep as reference, don't adapt, don't look at it, delete means delete

**"Violating the letter" (line 14):**
> Violating the letter of the rules is violating the spirit of the rules.

**Rationalization Table (lines 256-270) — 11 items:**
| Excuse                                 | Reality                                                                 |
| -------------------------------------- | ----------------------------------------------------------------------- |
| "Too simple to test"                   | Simple code breaks. Test takes 30 seconds.                              |
| "I'll test after"                      | Tests passing immediately prove nothing.                                |
| "Tests after achieve same goals"       | Tests-after = "what does this do?" Tests-first = "what should this do?" |
| "Already manually tested"              | Ad-hoc ≠ systematic. No record, can't re-run.                           |
| "Deleting X hours is wasteful"         | Sunk cost fallacy. Keeping unverified code is technical debt.           |
| "Keep as reference, write tests first" | You'll adapt it. That's testing after. Delete means delete.             |
| "Need to explore first"                | Fine. Throw away exploration, start with TDD.                           |
| "Test hard = design unclear"           | Listen to test. Hard to test = hard to use.                             |
| "TDD will slow me down"                | TDD faster than debugging. Pragmatic = test-first.                      |
| "Manual test faster"                   | Manual doesn't prove edge cases. You'll re-test every change.           |
| "Existing code has no tests"           | You're improving it. Add tests for existing code.                       |

**Red Flags (lines 272-288) — 13 items:**
- Code before test
- Test after implementation
- Test passes immediately
- Can't explain why test failed
- Tests added "later"
- Rationalizing "just this once"
- "I already manually tested it"
- "Tests after achieve the same purpose"
- "It's about spirit not ritual"
- "Keep as reference" or "adapt existing code"
- "Already spent X hours, deleting is wasteful"
- "TDD is dogmatic, I'm being pragmatic"
- "This is different because..."
All mean: Delete code. Start over with TDD.

### Claude Kit tdd-go — current structure (153 lines)

1. When to Use (lines 16-21)
2. Red-Green-Refactor Cycle (lines 23-62) — with Go examples
3. Integration with Coder Parts (lines 64-92)
4. Integration with Sequential Thinking and Code Researcher (lines 93-108)
5. Relationship with coder-rules RULE_5 (lines 109-114)
6. Rules (lines 116-126)
7. Common Issues (lines 127-149)
8. Reference links (lines 150-153)

### Adaptation decisions

**Go-specific adaptations needed:**
- Superpowers uses `npm test` → replace with `go test ./path/to/package/...`
- Superpowers TypeScript examples → not needed (existing Go examples in SKILL.md are sufficient)
- Rationalizations are language-agnostic — minimal adaptation needed
- Red flags are language-agnostic — direct transfer
- Iron Law is universal — add Go enforcement context (`go test` must fail first)

**What NOT to duplicate:**
- Superpowers has "Why Order Matters" section (lines 206-254) with expanded prose for 5 rationalizations. Our rationalization table is more concise (YAML-first format). Don't duplicate the prose — the table is sufficient.
- Superpowers has Good/Bad TypeScript examples. We already have Go examples in Red-Green-Refactor.
- Superpowers has "Verification Checklist" and "When Stuck" table. We have "Common Issues" and "Rules" which cover similar ground.

## Architecture Decision

**Insertion strategy:** Add new sections to SKILL.md without modifying any existing sections.

**Section placement:**
1. **Iron Law** — insert after "When to Use" (line 21), before "Red-Green-Refactor Cycle". Rationale: Iron Law sets the tone for the entire skill — it should appear early, before technical details.
2. **Rationalization Table** — insert after "Common Issues" (line 149), before reference links. Rationale: rationalizations are a reference — grouped with other reference material at the end.
3. **Red Flags** — insert after Rationalization Table. Rationale: red flags follow naturally from rationalizations as the "what to do about it" section.

**"Violating the letter" statement:** Include as opening line in Iron Law section (not a separate section).

**File size estimate:** Current 153 lines + ~60 new lines = ~213 lines. Well within reasonable SKILL.md size.

## Parts

### Part 1: Add Iron Law section to SKILL.md

**File:** `.claude/skills/tdd-go/SKILL.md`

**Insert after line 21** (after "When to Use" section, before "## Red-Green-Refactor Cycle"):

```markdown
## The Iron Law

**Violating the letter of the rules is violating the spirit of the rules.**

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

Write code before the test? Delete it. Start over.

No exceptions:
- Don't keep it as "reference"
- Don't "adapt" it while writing tests
- Don't look at it
- Delete means delete

Implement fresh from `go test` failures. Period.
```

### Part 2: Add Rationalization Table to SKILL.md

**File:** `.claude/skills/tdd-go/SKILL.md`

**Insert after "Common Issues" section** (after line 149, before reference links):

```markdown
## Common Rationalizations

| Excuse                                 | Reality                                                                 |
| -------------------------------------- | ----------------------------------------------------------------------- |
| "Too simple to test"                   | Simple code breaks. Test takes 30 seconds.                              |
| "I'll write tests after"               | Tests passing immediately prove nothing.                                |
| "Tests after achieve same goals"       | Tests-after = "what does this do?" Tests-first = "what should this do?" |
| "Already manually tested"              | Ad-hoc ≠ systematic. No record, can't re-run with `go test`.            |
| "Deleting X hours is wasteful"         | Sunk cost fallacy. Keeping unverified code is technical debt.           |
| "Keep as reference, write tests first" | You'll adapt it. That's testing after. Delete means delete.             |
| "Need to explore first"                | Fine. Throw away exploration, start with TDD.                           |
| "Hard to test = skip test"             | Listen to the test. Hard to test = hard to use. Simplify the interface. |
| "TDD will slow me down"                | TDD faster than debugging. `go test` catches regressions immediately.   |
| "Manual `curl`/`go run` is faster"     | Manual doesn't prove edge cases. You'll re-test every change.           |
| "Existing code has no tests"           | You're improving it. Add tests for the code you're changing.            |
```

**Go-specific adaptations:**
- "Manual test faster" → "Manual `curl`/`go run` is faster" (Go context)
- Added `go test` reference in "TDD will slow me down" reality
- Added `go test` reference in "Already manually tested" reality

### Part 3: Add Red Flags section to SKILL.md

**File:** `.claude/skills/tdd-go/SKILL.md`

**Insert after "Common Rationalizations" section** (immediately after Part 2):

```markdown
## Red Flags — STOP and Start Over

- Code written before test
- Test written after implementation
- Test passes immediately on first run
- Can't explain why test failed
- Tests added "later"
- Rationalizing "just this once"
- "I already manually tested it"
- "Tests after achieve the same purpose"
- "It's about spirit not ritual"
- "Keep as reference" or "adapt existing code"
- "Already spent X hours, deleting is wasteful"
- "TDD is dogmatic, I'm being pragmatic"
- "This is different because..."

**All of these mean: Delete code. Run `go test`. Start over with TDD.**
```

**Go-specific adaptation:**
- Final line: "Run `go test`" added to reinforce the Go toolchain

### Part 4: Move reference links to end

**File:** `.claude/skills/tdd-go/SKILL.md`

Ensure the existing reference links (lines 150-153) remain at the very end of the file, after the new Red Flags section. No content change — just verify placement.

## Files Summary

- MODIFY `.claude/skills/tdd-go/SKILL.md` (add ~60 lines across 3 new sections)

## Acceptance Criteria

- [ ] "Violating the letter" statement included in Iron Law section
- [ ] Iron Law section placed before Red-Green-Refactor Cycle
- [ ] Rationalization table has 11 entries matching Superpowers source
- [ ] Red flags list has 13 items matching Superpowers source
- [ ] Go-specific adaptations applied (go test, curl/go run references)
- [ ] All existing sections preserved unchanged
- [ ] Reference links remain at end of file
- [ ] No TypeScript examples (all examples remain Go)
- [ ] File reads naturally from top to bottom (Iron Law → cycle → patterns → issues → rationalizations → red flags → references)

## Testing Plan

Documentation task — no code tests.

Verification:
- Read SKILL.md, verify all new sections present
- Verify existing sections unchanged (diff should show only insertions)
- Count rationalization table entries (must be 11)
- Count red flags (must be 13)
- Verify Iron Law appears before Red-Green-Refactor
- Verify reference links at end of file

## Handoff Notes

All research completed. Implementer can work directly from this plan.

Key decisions:
- Insert-only changes — no modification of existing content
- Iron Law early (after When to Use), rationalizations + red flags late (after Common Issues)
- Minimal Go adaptations (m- [ ] Iron Law section present with `NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST`
ost content is language-agnostic)
- "Violating the letter" as opening line of Iron Law section, not separate section
- ~60 new lines → total ~213 lines (reasonable for SKILL.md)
