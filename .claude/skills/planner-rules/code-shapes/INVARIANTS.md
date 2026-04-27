# Code-shape Invariants

Every `code-shapes/<lang>.md` MUST illustrate these four invariants. Code-shape
files are TRAINING DATA for /planner Phase 4 — drift here propagates into every
plan a non-Go/non-Python project produces.

## The four invariants

1. **Full function body** — no `...` placeholders, no signature-only stubs.
2. **Error context propagation** — error wrapping per the language's ERROR_WRAP
   idiom (the slot value in PROJECT-KNOWLEDGE.md is the project's pinned form).
3. **Explicit return types and values** — typed (Go/TS/Rust/Java) or annotated
   (Python). Implicit `any`/`interface{}`/`Object` is a violation.
4. **No truncation** — every control-flow path returns a value, raises, or
   panics. No silent drop-through.

## Adding a new language

1. Copy `_default.md`.
2. Re-implement the same scenario (`Service.Get` returning a domain item) in the
   target language, satisfying the four invariants.
3. Update `examples.md` selector if the new language is not in the
   PROJECT-KNOWLEDGE.md.example LANGUAGE enumeration.

## Maintaining parity

The shape file MUST illustrate the same scenario across languages. Diverging
scenarios (one file shows fetch, another shows save) makes /planner output
inconsistent across language switches.
