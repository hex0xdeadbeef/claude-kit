---
name: tdd-go
description: >
  Test-Driven Development workflow for Go backend. Enforces Red-Green-Refactor cycle:
  write failing test first, minimal implementation to pass, then refactor.
  Use when implementing new features with tests, writing test suites, fixing bugs
  with regression tests, or when plan contains "## TDD" section. Covers unit tests,
  table-driven test patterns, benchmark TDD, error path TDD, and integration tests.
  Keywords: TDD, test-first, red-green-refactor, table-driven, Go testing, test-driven
  development, unit tests, failing test, minimal implementation.
---

# TDD Go

## When to Use

This skill is loaded by /coder when:
- Plan contains `## TDD` section (explicit TDD marker in plan file)

When NOT loaded, standard coder workflow applies (implement → test).
Coder checks for `## TDD` heading in `.claude/prompts/{feature}.md` at startup.

## Red-Green-Refactor Cycle

For EACH unit of behavior (one function, one method, one endpoint):

### Step 1: RED — Write a Failing Test
Write ONE test case that describes the expected behavior.
Run `go test ./path/to/package/...` — it MUST FAIL.
If it passes → the test is not testing new behavior. Revise.

```go
// EXAMPLE: RED phase
func TestCreateUser_ValidInput_ReturnsUser(t *testing.T) {
    svc := NewUserService(mockRepo)
    user, err := svc.Create(ctx, CreateUserInput{Name: "Alice", Email: "alice@example.com"})
    require.NoError(t, err)
    assert.Equal(t, "Alice", user.Name)
    assert.NotEmpty(t, user.ID)
}
// This MUST fail — Create() doesn't exist yet or returns wrong result
```

### Step 2: GREEN — Minimal Implementation
Write the MINIMUM code to make the failing test pass. No more.
Run `go test ./path/to/package/...` — it MUST PASS.

Rules for GREEN:
- Do NOT add extra functionality
- Do NOT optimize
- Do NOT refactor
- Hard-coded values are acceptable if they pass the test
- The goal is: test goes from RED to GREEN

### Step 3: REFACTOR — Clean Up
With tests green, improve code quality:
- Remove duplication
- Improve naming
- Extract helpers
- Run `go test ./path/to/package/...` — MUST still PASS

After REFACTOR → return to Step 1 for next behavior.

## Integration with Coder Parts

When TDD skill is active, coder implements each Part differently:

**Standard coder.md order (without TDD):**
```
Part 1: Repository/Data Access
Part 2: Models
Part 3: Domain/Service
Part 4: Handler/API
Part 5: Tests          ← separate Part at the end
Part 6: Wiring
```

**TDD-mode order (with tdd-go skill):**
```
Part 1: Repository — tests woven in [RED → GREEN → REFACTOR] per behavior
Part 2: Models — tests woven in
Part 3: Domain/Service — tests woven in
Part 4: Handler/API — tests woven in
Part 5: Wiring + Integration tests
(No separate "tests" Part — tests are per-Part)
```

Layer dependency order is preserved. What changes: tests are NOT a separate
final Part — they are woven into each Part via RED-GREEN-REFACTOR cycles.

Each Part may contain multiple RED-GREEN-REFACTOR cycles — one per behavior unit.

## Integration with Sequential Thinking and Code Researcher

### Complex Logic in TDD (3+ conditions, state machines)
When a Part contains complex logic:
1. RED: Write failing test that exercises the complex scenario
2. Use Sequential Thinking to design implementation strategy (between RED and GREEN)
3. GREEN: Write minimal implementation per ST analysis
4. REFACTOR: Clean up

ST is used INSIDE the GREEN phase — after test is written but before implementation.

### Codebase Research in TDD
When EVALUATE phase or RED phase encounters unfamiliar patterns:
- Use code-researcher agent (Task tool, haiku) to investigate existing patterns
- Then proceed with RED-GREEN-REFACTOR aligned with findings

## Relationship with coder-rules RULE_5

- **RULE_5** ("Tests Pass"): gate — code NOT ready until tests pass (exit criteria)
- **TDD rule** ("Tests First"): process — write test BEFORE production code (entry criteria)
- These are orthogonal: RULE_5 checks the end state, TDD controls the workflow order
- Both active simultaneously without conflict

## Rules

- NEVER write production code without a failing test (RED must precede GREEN)
- ONE test at a time — do not batch multiple test cases before implementing
- Run tests after EVERY step (RED: must fail, GREEN: must pass, REFACTOR: must pass)
- Table-driven tests: add cases incrementally, not all at once
- Test names: `Test{Function}_{Scenario}_{Expected}` (from rules/testing.md)
- Use testify/assert for assertions, testify/require for fatal checks
- Mock interfaces, not implementations (from rules/testing.md)
- Race detector: use `go test -race ./path/to/package/...` when package has concurrency (goroutines, channels, mutex)

## Common Issues

### Test passes in RED phase (should fail)
**Cause:** Test doesn't cover new behavior, or behavior already exists.
**Fix:** Verify the test exercises the NEW code path. Add assertion for specific new behavior.

### Over-implementation in GREEN phase
**Cause:** Implementing more than the test requires.
**Fix:** Stop. Check: does ANY line of new code lack a test that exercises it? If yes, remove it or add a test first.

### Refactor breaks tests
**Cause:** Refactoring changed behavior, not just structure.
**Fix:** Revert refactor. The rule is: REFACTOR changes structure, not behavior.

### Multiple failing tests at once
**Cause:** Wrote multiple tests before implementing.
**Fix:** Comment out all but one. Implement → pass → uncomment next.

### Table-driven tests: all cases added upfront
**Cause:** Added all test cases before writing code — violates ONE-at-a-time rule.
**Fix:** Add ONE test case, RED → GREEN → REFACTOR. Then add next case.
Use `t.Skip("not yet implemented")` for cases you haven't reached yet.

For detailed patterns and examples, see:
- [TDD Patterns](references/patterns.md) — table-driven TDD, test helpers, benchmark TDD
- [Full Examples](references/examples.md) — handler/service/repository TDD workflows
