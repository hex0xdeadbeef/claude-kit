# TDD Examples — selector

principle:
  bad: "Implement code first, write tests afterward (or skip them). Tests are brittle, miss error paths."
  good: "Write a failing test first (RED). Implement minimal code (GREEN). Refactor (REFACTOR). Tests cover happy + error + edge cases."

three_invariants:
  - "1. Test first (RED phase precedes implementation)"
  - "2. Descriptive test name (explains the verified behaviour, not 'test1')"
  - "3. Assertion completeness (happy path + error case + edge case)"

reference_shapes:
  resolved_from: "PROJECT-KNOWLEDGE.md → LANGUAGE"
  selector: |
    - go         → tdd-shapes/go.md
    - python     → tdd-shapes/python.md
    - typescript → tdd-shapes/typescript.md
    - rust       → tdd-shapes/rust.md
    - java       → tdd-shapes/java.md
    - any other / unset → tdd-shapes/_default.md  (pseudocode)
  fallback_kit_dogfood: |
    If PROJECT-KNOWLEDGE.md is missing entirely AND LANGUAGE is unset, the
    cascade falls back to CLAUDE.md Language Profile (kit-default = Go) →
    tdd-shapes/go.md. Preserves C5 byte-equivalent kit-dogfood behaviour
    documented in v1.16 P1 audit.
  invariants_anchor: "tdd-shapes/INVARIANTS.md"

note: |
  When you add a new supported language, follow tdd-shapes/INVARIANTS.md →
  "Adding a new language" BEFORE updating the selector above. The shape
  file MUST illustrate the same Service.get scenario as the other 5 langs
  (parity rule).