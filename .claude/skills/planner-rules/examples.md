# Planner Examples

purpose: "Illustrate the code-completeness principle. Concrete shapes live in code-shapes/<LANGUAGE>.md and are loaded conditionally by /planner Phase 4."

---

principle:
  bad: "Signature-only stub: `func Get(id string) error` (Go) / `def get(id): ...` (Python) — no body, no error path, not actionable for code review."
  good: "Full function body satisfying all four invariants in code-shapes/INVARIANTS.md."

four_invariants:
  - "1. Full function body (no `...` / no signature-only stubs)"
  - "2. Error context propagation per the project's ERROR_WRAP slot"
  - "3. Explicit return types and values (typed or annotated)"
  - "4. No truncation — every control-flow path returns / raises / panics"

reference_shapes:
  resolved_from: "PROJECT-KNOWLEDGE.md → LANGUAGE"
  selector: |
    - go         → code-shapes/go.md
    - python     → code-shapes/python.md
    - typescript → code-shapes/typescript.md
    - rust       → code-shapes/rust.md
    - java       → code-shapes/java.md
    - any other / unset → code-shapes/_default.md  (pseudocode)
  invariants_anchor: "code-shapes/INVARIANTS.md"

note: "If you add a new supported language, follow code-shapes/INVARIANTS.md → 'Adding a new language' before updating the selector above."
