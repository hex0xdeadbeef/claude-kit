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

## Pattern: Skill file inventory errors in research/documentation plans

Frequency: Seen in workflow-research.md (2026-03-29, iterations 1 and 2)
Severity: MINOR

Plans that enumerate skill package file lists frequently contain errors vs actual filesystem:

- Incorrect file count in heading vs actual list (off-by-one) — persists across iterations even
  when file names are corrected (seen in workflow-research iteration 2: workflow-protocols says
  "(8 files)" for 9 actual; planner-rules says "(7 files)" for 8 actual)
- Wrong file names (e.g., `evaluate-protocol.md` listed but file is actually `checklist.md`)
- Files that exist in one skill package attributed to another

**Why:** Research agents may transpose file names or counts across skill packages.
Iteration fixes tend to correct file names but miss heading counts.
**How to apply:** Flag as MINOR; always check BOTH file names AND heading counts vs filesystem.
Advise coder to spot-check all skill file lists against filesystem at the start of Part 5.

## Pattern: Vague acceptance criteria for documentation tasks

Frequency: Seen in workflow-research.md (2026-03-29)
Severity: NIT after Mermaid/YAML criteria added (was MINOR before iteration 2 fix)

Documentation plans sometimes use undefined metrics in acceptance criteria ("shows all N levels
of relationships") without defining what those N levels are. After iteration 2 fix, technical
criteria (Mermaid syntax, YAML frontmatter) were added — the remaining vagueness is NIT-level.

**Why:** Planners focus on content coverage and skip structural correctness checks.
**How to apply:** Flag residual undefined counts as NIT if technical criteria are present;
flag as MINOR if technical criteria are also absent.

## Pattern: Aspirational/future patterns not labeled as such in documentation plans

Frequency: Seen in qw5-parallel-dispatch.md (2026-03-29, iterations 1 and 2)
Severity: MAJOR (iteration 1); resolved by iteration 2

When a plan documents multiple use cases and some are aspirational (not yet implemented behavior),
the plan MUST explicitly label those sections as "future pattern" or "planned behavior."

Failure to label produces documentation that implies non-existent behavior is current. Planner
handoffs often correctly identify this as a known risk — reviewer must verify the plan body
actually implements the labeling, not just acknowledges it in handoff notes.

Resolution pattern (qw5 iteration 2): blockquote callout at top of future section + "NOTE" in
research section + "FUTURE PATTERN" in Use Case heading. This is the accepted resolution form.

**Why:** Documentation shipped without "future" labels misleads implementers and readers about
actual system capabilities.
**How to apply:** MAJOR when plan body presents aspirational behavior symmetrically with existing
behavior, with no distinguishing label. The coder cannot make this judgment call — it requires a
planner revision. Accept "future pattern" callout block, `status: future` field, or equivalent
explicit marker in the section.

## Pattern: Nested code fences in plan content examples

Frequency: Seen in qw3-tdd-rationalization.md (2026-03-29, iteration 1, APPROVED)
Severity: MINOR

When a plan wraps a content example in an outer markdown fence, and that content itself contains
inner fences (e.g., for code banners like NO PRODUCTION CODE), the inner fence terminates the
outer fence when rendered. The coder sees a broken block and may misinterpret what to insert.

**Why:** Planners write nested fences without accounting for Markdown rendering rules.
**How to apply:** Flag as MINOR. Coder can recover intent from Research section context.
Suggest using 4-space indentation or a 4-backtick outer fence to disambiguate.
For content with inner fences, also accept describing the inner fence in prose rather than
showing it literally in the example block.
