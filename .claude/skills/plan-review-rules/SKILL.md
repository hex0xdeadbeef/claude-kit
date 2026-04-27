---
name: plan-review-rules
description: Review standards for plan-reviewer agent. Auto-loaded via agent frontmatter when plan-reviewer runs (Phase 2). Covers: architecture compliance (import matrix, domain purity), required plan sections validation, severity classification (BLOCKER/MAJOR/MINOR/NIT), decision matrix (APPROVED/NEEDS_CHANGES/REJECTED).
disable-model-invocation: true
---

# Plan Review Rules

## Severity Classification
- BLOCKER: Architecture/security violation — blocks approval
- MAJOR: Error handling, logging, significant gaps — blocks approval
- MINOR: Code style, naming, documentation — does not block
- NIT: Stylistic preference — does not block

## Decision Matrix
- APPROVED: 0 BLOCKER, 0 MAJOR (minor/nit noted but don't block)
- NEEDS_CHANGES: 0 BLOCKER, 1+ MAJOR or 3+ MINOR
- REJECTED: 1+ BLOCKER

## Auto-Escalation
- 5+ MINOR in same Part → escalate to MAJOR
- Security issue (any severity) → always BLOCKER
- Layer-dependency violation (when {LAYER_RULE} SET AND {ARCHITECTURE_STYLE} == "layered") → always BLOCKER. SKIP entries (slot unset/non-layered) → consolidated NIT, NOT BLOCKER.

## Instructions

### Step 1: Read plan from scratch
Read `.claude/prompts/{feature}.md` or provided path. NEVER trust cached version.
Read narrative context from planner handoff. Use it to focus review, but verify independently.

### Step 2: Validate structure
Check required sections: Context, Scope (IN/OUT), Dependencies, Parts with code examples, Acceptance criteria, Testing plan.
For section details, see [Required Sections](required-sections.md).

### Step 3: Validate architecture
Check import matrix compliance, domain purity, error handling patterns.
For complex plans (4+ Parts, 3+ layers) → use Sequential Thinking.
For architecture rules, see [Architecture Checks](architecture-checks.md).

### Step 4: Apply Decision Matrix and form verdict
Count issues by severity. Apply Decision Matrix and Auto-Escalation rules above.
CRITICAL: Security issue = ALWAYS BLOCKER. Import violation = ALWAYS BLOCKER.
Form handoff for coder with verdict + issues + notes.

## Example

### Auto-escalation: 5+ MINOR in same Part → MAJOR

**Bad — approve with 6 MINOR issues in Part 3:**
```
Verdict: APPROVED
Issues: 0 BLOCKER, 0 MAJOR, 6 MINOR (all in Part 3)
```

**Good — apply auto-escalation, then decide:**
```
Auto-escalation: 6 MINOR in Part 3 → escalate to MAJOR
Verdict: NEEDS_CHANGES
Issues: 0 BLOCKER, 1 MAJOR (escalated), 1 MINOR
```
**Why:** Many small issues = systemic problem (source: troubleshooting.md). 5+ MINOR in same Part should be escalated to MAJOR via Decision Matrix auto-escalation rules.

For more examples, see [Troubleshooting](troubleshooting.md) and [Architecture Checks](architecture-checks.md).

## Common Issues

### Approved plan with layer-dependency violations
**Cause:** Manual check missed a direct import that violates LAYER_RULE (e.g. an api-layer importing a data-access layer directly, where LAYER_RULE forbids it).
**Fix:** Verify layer-dependency rule per PROJECT-KNOWLEDGE.md → LAYER_RULE — SKIP with consolidated NIT if LAYER_RULE is unset OR ARCHITECTURE_STYLE != "layered" (canonical SKIP, see plan-review-rules/architecture-checks.md § Layer-check predicate). For plans with 4+ Parts when the check runs, use grep to verify imports in code examples. Layer-rule violation = ALWAYS BLOCKER when the check is active.

### Security issue marked as MAJOR instead of BLOCKER
**Cause:** Didn't apply auto-escalation rule.
**Fix:** Security issues are ALWAYS BLOCKER — no exceptions. Re-classify and reject.

### Approved plan without Sequential Thinking check
**Cause:** Didn't verify if plan required structured analysis.
**Fix:** If plan has 4+ Parts, 3+ layers, or 3+ alternatives — it MUST use Sequential Thinking. Missing ST for complex plan = MAJOR issue.

For all troubleshooting cases, see [Troubleshooting](troubleshooting.md).

## References (ON-DEMAND — do NOT read eagerly)
Do NOT read supporting files upfront. This SKILL.md contains all essential rules inline. Load files only when the specific trigger condition is met:
- [Architecture Checks](architecture-checks.md) — **Read when:** plan has 4+ Parts or 3+ layers AND you need detailed import matrix / domain purity rules beyond what's in the agent artifact.
- [Required Sections](required-sections.md) — **Read when:** plan is missing sections and you need to verify which are truly required vs optional.
- [Checklist](checklist.md) — **Read when:** self-verifying before outputting verdict (optional, only if uncertain about coverage).
- [Troubleshooting](troubleshooting.md) — **Read when:** encountering an unexpected issue during review. Do NOT read preemptively.
