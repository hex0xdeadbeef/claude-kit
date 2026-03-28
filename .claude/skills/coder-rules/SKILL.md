---
name: coder-rules
description: Implementation rules and patterns for /coder command. Load at /coder startup (step 0) or when /workflow enters Phase 3. Covers: 5 CRITICAL rules (plan-only, import matrix, clean domain, no log+return, tests pass), evaluate protocol (PROCEED/REVISE/RETURN), dependency-ordered implementation.
disable-model-invocation: true
---

# Coder Rules

## 5 CRITICAL Rules

- RULE_1 Plan Only: Implement ONLY what's in the plan. No improvements.
- RULE_2 Import Matrix: NEVER violate the import matrix.
- RULE_3 Clean Domain: NEVER add encoding/json tags to domain entities (tags belong in DTOs).
- RULE_4 No Log+Return: NEVER log AND return error simultaneously.
- RULE_5 Tests Pass: Code NOT ready until tests pass.

## Evaluate Protocol

Before implementation, critically evaluate plan (Phase 1.5):
- PROCEED: Plan is implementable as-is → start implementation
- REVISE: Minor gaps, can fix inline → note adjustments, proceed
- RETURN: Major gaps or feasibility issues → return to /plan-review with feedback

Evaluate checks: feasibility, hidden complexities, edge cases, performance, dependencies.
Output: `.claude/prompts/{feature}-evaluate.md`

Evaluate has an exploration budget (SEE coder.md → evaluate_budget).
When budget is reached, DECIDE with available information.
Prefer PROCEED with notes over endless research.
The planner already researched — evaluate is VALIDATION, not discovery.

## Instructions

### Step 1: Load plan and verify approval
Read `.claude/prompts/{feature}.md`. Verify plan passed plan-review.
If plan not found → ERROR, exit. If not approved → ERROR, exit.

### Step 2: Run Evaluate Protocol
Before writing ANY code, evaluate the plan critically.
Decision: PROCEED / REVISE / RETURN (see Evaluate Protocol above).
Write output to `.claude/prompts/{feature}-evaluate.md`.

### Step 3: Implement parts in dependency order
Follow lower-layers-first: data access → models → domain → API → tests → wiring.
After each Part: PostToolUse hooks auto-format files (gofmt). Run LINT only for import/error checks. Check 5 CRITICAL Rules above continuously.
Do NOT run FMT manually between Parts — hooks handle formatting, VERIFY handles final FMT+LINT.
IMPORTANT: Do NOT run tests (make test, go test) between Parts. Tests run ONCE at Step 4 VERIFY.
Running tests after each Part wastes time — compile errors are caught by LINT, logic errors are caught at VERIFY.
Exception: If plan contains ## TDD section, RED-GREEN-REFACTOR test runs within a Part are allowed (they are implementation, not verification).

### Step 4: Verify and form handoff
Run full VERIFY: `go vet ./... && make fmt && make lint && make test`.
If tests fail 3x → STOP, request help. On success → form handoff payload for code-review.

## Example

### Clean Domain — no json tags in entities (RULE_3)

**Good:**
```go
type Service struct {
    ID string
}
```

**Bad:**
```go
type Service struct {
    ID string `json:"id"`
}
```
**Why:** RULE_3 — Domain entities must be pure. No encoding/json tags. Tags belong in DTOs at the handler/API layer.

For more examples, see [Examples](examples.md).

## Common Issues

### Tests fail 3x in a row — stuck
**Cause:** Bug in implementation logic or wrong approach.
**Fix:** Use Sequential Thinking for root cause analysis. Compare with plan examples. If still stuck → STOP, request manual help.

### Import matrix violation detected
**Cause:** Didn't check architecture rules before implementation.
**Fix:** Review import matrix (handler → service → repository → models). Refactor imports. This is ALWAYS a BLOCKER.

### New library used without Context7
**Cause:** Assumed familiarity with library API.
**Fix:** ALWAYS use Context7 for external dependencies: resolve-library-id → query-docs.

For all troubleshooting cases, see [Troubleshooting](troubleshooting.md).

## Core Deps (loaded at startup)
- [MCP Tools](mcp-tools.md) — Memory, Sequential Thinking, Context7, PostgreSQL patterns and fallbacks

## References
For detailed checks, read the supporting files in this skill directory:
- [Examples](examples.md) — bad/good code patterns, layer import rules
- [Checklist](checklist.md) — self-verification at each coder phase
- [Troubleshooting](troubleshooting.md) — common coder issues and fixes
- [Review Response](review-response.md) — handling CHANGES_REQUESTED feedback from code-reviewer (loaded on re-entry iterations)
- [code-researcher agent](../../agents/code-researcher.md) — available via Task tool for codebase investigation during evaluate phase (L/XL complexity)
