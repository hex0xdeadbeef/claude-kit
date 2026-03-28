---
name: common-plan-issues
description: Recurring structural issues found in plans during review
type: feedback
---

# Recurring Plan Issues

## Issue: Missing structural sections in config/doc plans

Frequency: High (seen in imp-w01-conditional-hooks.md, iteration 1)
Severity when found: MAJOR x3

Plans for config_change or documentation tasks frequently omit:
- Scope (IN/OUT) — required ALWAYS per required-sections.md
- Files Summary — required ALWAYS (inline file mentions per Part don't count)
- Acceptance Criteria — required ALWAYS; verification checklists in a Part don't substitute

**Why:** Planners treat these as optional for "simple" config tasks.
**How to apply:** Always check these three sections first regardless of plan type.

## Issue: Complexity label vs actual content mismatch

Frequency: Seen in imp-w01 (XL label, actual S/M content), imp-w09 (XL label, actual S, self-documented)
Severity: MINOR

User-requested complexity labels can mismatch actual content. When XL is labeled but actual plan
is config-only with no interdependent layers, treat complexity label mismatch as MINOR — suggest
planner correct it or add a note explaining why ST was skipped. Do not BLOCK on this.
When plan self-documents the mismatch ("actual S"), the note is sufficient — no action needed.

## Pattern: Two-handler split for Write|Edit with `if`

This is the CORRECT approach for Claude Code v2.1.85 when applying `if` conditions to
hooks that use `Write|Edit` matcher — because `if` field doesn't support pipe syntax.
Approve this pattern when seen in future plans.

## Pattern: Documentation Part without example prose

Frequency: Seen in imp-w01 iteration 2 (approved with MINOR), imp-w09 Parts 3/4 (approved with MINOR)
Severity: MINOR

When a Part describes a documentation update ("add note about X" or "same as Part N, adapted"),
it should include example prose showing what will be written — not just intent or a reference to
another Part. This is a MINOR issue (does not block approval) but leaves ambiguity for the coder.

**Why:** Coder must infer how to adapt wording for a different agent/context.
**How to apply:** Flag as MINOR when a doc-update Part has no example of the intended content,
especially when the Part defers to "same as Part N, adapted for X" without showing the adapted text.

## Pattern: Scope assumptions in `if` conditions should be verified

Frequency: Seen in imp-w01 Change 2.3 (check-references.sh)
Severity: MINOR

When a plan narrows a hook's scope with an `if` condition and the rationale is an assumption
("only X files contain Y"), the plan should verify or cite evidence for that assumption.

**Why:** If the assumption is wrong, the hook silently skips valid cases.
**How to apply:** Flag as MINOR when an `if` condition's rationale is unverified assertion.

## Pattern: Testing Plan section absent in doc-only plans

Frequency: Seen in imp-w09
Severity: MINOR (does not block)

Doc-only plans sometimes omit the Testing Plan section entirely, even though the plan template
requires it. For pure documentation updates the answer is simple ("manual verification") but
the section should still be present.

**How to apply:** Flag as MINOR when Testing Plan section is absent, even for doc-only plans.
