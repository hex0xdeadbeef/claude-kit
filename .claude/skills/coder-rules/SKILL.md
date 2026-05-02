---
name: coder-rules
description: Implementation rules and patterns for /coder command. Load at /coder startup (step 0) or when /workflow enters Phase 3. Covers: 5 CRITICAL rules (plan-only, import matrix, clean domain, no log+return, tests pass), evaluate protocol (PROCEED/REVISE/RETURN), dependency-ordered implementation.
disable-model-invocation: true
---

# Coder Rules

## 5 CRITICAL Rules

- RULE_1 Plan Only: Implement ONLY what's in the plan. No improvements.
- RULE_2 Layer Dependency: NEVER violate {LAYER_RULE} (resolved from PROJECT-KNOWLEDGE.md; CLAUDE.md fallback). SKIP if slot unset OR {ARCHITECTURE_STYLE} != "layered".
- RULE_3 Clean Domain: NEVER add {DOMAIN_PROHIBIT} (resolved from PROJECT-KNOWLEDGE.md → DOMAIN_PROHIBIT; CLAUDE.md fallback) to domain entities. Tags belong in DTOs at the API/transport layer (your project's highest LAYERS entry per PROJECT-KNOWLEDGE.md → LAYERS). SKIP if slot unset.
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

## Spec Check Protocol

After VERIFY passes, run spec compliance self-check (Phase 3.5):
- PASS: all Parts covered, scope respected, AC traceable → proceed to handoff
- PARTIAL: minor gaps documented → proceed with gaps noted in handoff
- FAIL: missing Part → inline fix (max 1 retry) → re-run VERIFY → re-check

Full checklist: [Spec Check](spec-check.md)

> **Reviewer-side note:** since release v1.21.x, code-reviewer applies an iter-≥2 spot-check on spec_check.status=PASS to guard against silent regressions. The coder is unaffected; the spot-check is performed entirely on the reviewer side via `git diff --name-only`.

## Instructions

### Step 1: Load plan and verify approval
Read `.claude/prompts/{feature}.md`. Verify plan passed plan-review.
If plan not found → ERROR, exit. If not approved → ERROR, exit.

### Step 2: Run Evaluate Protocol
Before writing ANY code, evaluate the plan critically.
Decision: PROCEED / REVISE / RETURN (see Evaluate Protocol above).
Write output to `.claude/prompts/{feature}-evaluate.md`.

### Step 3: Implement parts in dependency order
Follow Parts order from plan. The plan's Parts list is the source of truth.
If plan unordered: use {LAYERS} slot dependency direction when {ARCHITECTURE_STYLE} == "layered";
otherwise follow plan order verbatim and emit consolidated NIT if ambiguous.
After each Part: PostToolUse hooks auto-format files (slot-driven via `auto-fmt.sh`: reads `FMT_CMD` and `LANG_EXT` from PROJECT-KNOWLEDGE.md cascade; supports `{}` placeholder for per-file mode). Run resolved {LINT_CMD} only for import/error checks. Check 5 CRITICAL Rules above continuously.
Do NOT run FMT manually between Parts — hooks handle formatting, VERIFY handles final FMT+LINT.
IMPORTANT: Do NOT run the FULL test suite (resolved {TEST_CMD}) between Parts — full verification runs ONCE at Step 4 VERIFY.
Compile errors are caught by LINT; logic errors are caught at VERIFY.
Targeted RED-GREEN-REFACTOR single-test runs within a Part are part of implementation (not verification) and are expected on every Part by default — see `.claude/skills/tdd-rules/SKILL.md` for the full cycle.

### Step 4: Verify
Run full VERIFY using the resolved command from coder.md `verify_startup` cascade
(PROJECT-KNOWLEDGE.md → VERIFY_CMD; CLAUDE.md fallback; DEPENDENCY_FILE-aware WARN; SKIP-with-NIT).
Kit-default for Go projects (legacy CLAUDE.md fallback): `go vet ./... && make fmt && make lint && make test`.
If tests fail 3x → load systematic-debugging skill, run Phase 1 root cause investigation.
On success → proceed to Step 5.

### Step 5: Spec Check and form handoff
Run SPEC CHECK (see [Spec Check](spec-check.md)). S complexity: lightweight (coverage only).
If FAIL: inline fix → re-run VERIFY → re-check (max 1 retry).
On PASS/PARTIAL → form handoff payload for code-review, including spec_check.

## Example

### Clean Domain — no {DOMAIN_PROHIBIT} in entities (RULE_3)

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
**Why:** RULE_3 — Domain entities must be pure. No {DOMAIN_PROHIBIT} (resolved from PROJECT-KNOWLEDGE.md). Tags belong in DTOs at the API/transport layer (highest LAYERS entry per PROJECT-KNOWLEDGE.md → LAYERS).

For more examples, see [Examples](examples.md).

## Common Issues

### Tests fail 3x in a row — stuck
**Cause:** Bug in implementation logic or wrong approach.
**Fix:** Load systematic-debugging skill. Run Phase 1 (Root Cause Investigation) with
`go test -v -count=1 ./...` output as evidence. Trace data flow to find root cause.
If root cause found → implement single fix + VERIFY. If still stuck → STOP, request manual help.

### Layer-dependency violation detected
**Cause:** Didn't check architecture rules before implementation.
**Fix:** Review layer-dependency rule per resolved {LAYER_RULE}. Refactor imports per the resolved rule. BLOCKER when slot is set AND {ARCHITECTURE_STYLE} == "layered"; SKIP-with-consolidated-NIT when unset/non-layered (canonical SKIP).

### New library used without Context7
**Cause:** Assumed familiarity with library API.
**Fix:** ALWAYS use Context7 for external dependencies: resolve-library-id → query-docs.

For all troubleshooting cases, see [Troubleshooting](troubleshooting.md).

## Core Deps (loaded at startup)
- [MCP Tools](mcp-tools.md) — Memory, Sequential Thinking, Context7 patterns and fallbacks

## References
For detailed checks, read the supporting files in this skill directory:
- [Examples](examples.md) — bad/good code patterns, layer import rules
- [Checklist](checklist.md) — self-verification at each coder phase
- [Troubleshooting](troubleshooting.md) — common coder issues and fixes
- [Review Response](review-response.md) — handling CHANGES_REQUESTED feedback from code-reviewer (loaded on re-entry iterations)
- [Spec Check](spec-check.md) — spec compliance self-check protocol (Phase 3.5, after VERIFY)
- [code-researcher agent](../../agents/code-researcher.md) — available via Task tool for codebase investigation during evaluate phase (L/XL complexity)
