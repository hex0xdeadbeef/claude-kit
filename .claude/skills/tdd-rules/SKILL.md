---
name: tdd-rules
description: Test-Driven Development workflow for any language. Enforces Red-Green-Refactor cycle (failing test first, minimal implementation, then refactor). Loaded by /coder when plan contains "## TDD" heading. Per-language test idioms live in tdd-shapes/<LANGUAGE>.md (resolved from PROJECT-KNOWLEDGE.md → LANGUAGE; falls back to tdd-shapes/_default.md).
disable-model-invocation: true
---

# TDD Rules

## When loaded

`/coder` loads this skill when the plan file `.claude/prompts/{feature}.md` contains a `## TDD` heading. When NOT loaded, standard implement→test order applies.

## The Iron Law

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

Wrote code before the test? Delete it. Implement fresh from a failing test run.

## Red-Green-Refactor cycle

For EACH unit of behaviour:

1. **RED** — write ONE failing test. Run the project test command (`{TEST_CMD}`). MUST FAIL. If it passes, the test does not exercise new behaviour — revise.
2. **GREEN** — minimum code to make that one test pass. No extras, no optimisation, no refactor. Hard-coded values acceptable.
3. **REFACTOR** — improve structure (naming, duplication, helpers) WITHOUT changing behaviour. Tests stay green.

Return to RED for the next behaviour.

## Reference shapes — per-language test idioms

Concrete syntax for each step lives in `tdd-shapes/<LANGUAGE>.md`:

| LANGUAGE | File | Idiom |
|----------|------|-------|
| go | `tdd-shapes/go.md` | `*testing.T`, table-driven `t.Run`, testify |
| python | `tdd-shapes/python.md` | pytest, `@pytest.mark.parametrize`, fixtures |
| typescript | `tdd-shapes/typescript.md` | Jest/Vitest `describe/it`, `it.each` |
| rust | `tdd-shapes/rust.md` | `#[test]`, `assert_eq!`, `rstest` |
| java | `tdd-shapes/java.md` | JUnit 5 `@Test`, `assertEquals`, `@ParameterizedTest` |
| any other / unset | `tdd-shapes/_default.md` | pseudocode (no language commitment) |

Selector lives in `examples.md` (`reference_shapes` block, mirrors `planner-rules/examples.md`).

## Cascade resolution (single source of truth)

Resolution order — highest precedence first:

1. `PROJECT-KNOWLEDGE.md → LANGUAGE` matches one of `{go, python, typescript, rust, java}` → load matching `tdd-shapes/<LANGUAGE>.md`.
2. `LANGUAGE` slot is unset/empty (PROJECT-KNOWLEDGE.md missing OR slot empty) → fall back to `CLAUDE.md` Language Profile (kit-default = Go) → load `tdd-shapes/go.md`. **Kit-dogfood C5 constraint preserved.**
3. `LANGUAGE` is set but does NOT match the 5-language enum (e.g., `ruby`, `kotlin`, kit's own `"config-as-code"`) → load `tdd-shapes/_default.md` silently AND emit a consolidated NIT in coder handoff `deviations_from_plan` array (mirrors CG1 SKIP idiom).

`/coder` startup step "Conditional: Load TDD skill" duplicates this cascade — the two narratives MUST stay in sync (T3.6 single source of truth).

## Integration with /coder Parts

When `tdd-rules` is loaded, `/coder` implements each Part with **interleaved tests** (RED → GREEN → REFACTOR per behaviour) instead of writing tests as a final separate Part:

- Standard order (no `## TDD`): `Part N: Tests` is a separate final Part.
- TDD-mode order: tests are woven into each Part via Red-Green-Refactor cycles. Tests are NOT a separate Part.

Layer dependency order is preserved either way.

## Rules

- NEVER write production code without a failing test (RED must precede GREEN)
- ONE test at a time — do NOT batch multiple test cases before implementing
- Run tests after EVERY step (RED: must fail, GREEN: must pass, REFACTOR: must pass)
- Table-driven / parameterised tests: add cases incrementally, not all at once
- Test names: descriptive — explain the behaviour being verified, not just `test1` / `TestFoo`
- Mock interfaces, not implementations
- Race-detection: use the project's race-detector flag when the package has concurrency primitives

See `tdd-shapes/<LANGUAGE>.md` + `tdd-shapes/INVARIANTS.md` for patterns; `references/coder-integration.md` for rationalisations + red flags.