# Spec Check Protocol

purpose: "Inline spec compliance self-check in /coder Phase 3.5"
when: "After VERIFY passes, before forming handoff output"

---

## Overview

Verifies "Did we build the right thing?" before code-reviewer checks "Did we build it well?"
Runs ALWAYS after VERIFY. S complexity: lightweight mode. M/L/XL: full checklist.

## Checklist

### 1. Parts Coverage (ALL complexities)
- Count Parts in plan → compare to parts_implemented list
- Each Part maps to at least one changed file
- coverage_pct = parts_covered / parts_in_plan * 100
- FAIL if coverage_pct < 100 (missing Part)

### 2. Scope Boundary (M+ only)
- `git diff --name-only`: all changed files traceable to a plan Part?
- Files outside plan scope → flag as potential gold-plating
- PARTIAL if extra files exist but are justified (auto-generated, imports)

### 3. Deviations Confirmed (M+ only)
- Read evaluate output (`.claude/prompts/{feature}-evaluate.md`)
- Verify listed deviations are still accurate
- Any NEW deviations discovered during implementation? Add to list
- PARTIAL if new deviations found (document, not necessarily bad)

### 4. Acceptance Criteria Spot-Check (L/XL only)
- For each AC in plan: identify code path or test that covers it
- Not running tests (VERIFY already passed) — just traceability
- PARTIAL if any AC cannot be mapped to implementation

### 5. Interface Contracts (L/XL only)
- Public function signatures match plan examples?
- Return types and error handling match?
- PARTIAL if minor differences (document reason)

## Output

spec_check:
  status: "PASS|PARTIAL|FAIL"
  coverage_pct: 100
  deviations_confirmed:
    - "Part N: adjustment description (from evaluate)"
  ac_coverage:
    - "AC 1: covered by TestXxx"
    - "AC 2: covered by code path in service.go:42"
  issues: []

## Inline Fix Protocol

- FAIL (missing Part): implement missing Part → re-run VERIFY → re-run SPEC CHECK
- **Max 1 inline fix retry.** If still FAIL after retry → set status: PARTIAL, proceed
- PARTIAL: document gaps, proceed to handoff. code-reviewer treats gaps as MINOR
- PASS: proceed to handoff

## Lightweight Mode (S complexity)

- Run ONLY check #1 (Parts Coverage)
- Skip checks #2-5
- Fast: single comparison, no git diff analysis

## Common Issues

### Spec check finds missing Part after VERIFY
**Cause:** Part was in plan but not implemented.
**Fix:** Implement inline, re-run VERIFY once. If tests pass → re-run SPEC CHECK.

### Extra files outside plan scope
**Cause:** Auto-generated files, go.sum updates, or gold-plating.
**Fix:** Justified extras (auto-gen, dependency updates) → PASS with note. Unjustified → remove or document as deviation.
