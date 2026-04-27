# TDD-shape Invariants

Every `tdd-shapes/<lang>.md` MUST illustrate these THREE invariants.
TDD-shape files are TRAINING DATA for /coder Phase 2 IMPLEMENT — drift here
propagates into every test suite a non-Go project produces.

## The three invariants

1. **Test first (RED)** — failing test BEFORE implementation code. The test
   must validate it is real (must FAIL on first run, NOT pass).
2. **Descriptive test name** — name explains the behaviour being verified
   (e.g., `TestServiceGetReturnsItemWhenFound`, `test_service_get_raises_when_not_found`).
   `test1` / `TestFoo` are violations.
3. **Assertion completeness** — at least 3 cycles MUST be illustrated:
   happy path (item found), error case (repo error / wrap), and edge case
   (None / nil / null / not-found).

## Adding a new language

1. Copy `_default.md`.
2. Re-implement the SAME scenario (Service.get(itemId) — 3 cycles
   Red-Green-Refactor) in the target language, satisfying the three invariants.
3. Update `examples.md` `reference_shapes` selector to include the new entry.
4. Cross-link from `planner-rules/code-shapes/INVARIANTS.md` → "Adding a new
   language" so both per-language catalogues stay in sync (single update
   procedure for both).
5. Add a CI assertion to `.claude/scripts/tests/test-tdd-shapes-extracted.sh`
   (TD-1 file presence loop) for the new language.

## Maintaining parity

The shape file MUST illustrate the SAME scenario across all languages.
Diverging scenarios (one file shows happy-path-only, another shows 5 edge
cases) makes /coder output inconsistent across language switches and breaks
the parity rule that lets contributors compare languages side-by-side.

## Size budget

Shape files **target ≤3 KB** but may extend to **≤4 KB ceiling** when the
parity-rule scenario (Cycle 1 happy + Cycle 2 not-found + Cycle 3 wrap with
table-driven/parameterised) requires more verbose syntax (e.g., Java,
Rust). When a shape file would exceed 4 KB, extract verbose Cycle 3 GREEN
blocks to `tdd-rules/references/<lang>-extras.md` (T1.7 overflow allowance,
mirrors P1 code-shapes pattern). The parity rule takes precedence over a
strict per-file byte cap — richer per-language training data improves
/coder Phase 2 IMPLEMENT output more than a tight size limit.

## Cross-reference

This INVARIANTS.md mirrors `planner-rules/code-shapes/INVARIANTS.md` (4
invariants for code completeness). The two catalogues are independent
training-data sources; keep their "adding a new language" recipes in sync.
