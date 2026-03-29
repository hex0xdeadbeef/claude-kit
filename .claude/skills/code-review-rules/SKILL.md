---
name: code-review-rules
description: Review standards for code-reviewer agent. Auto-loaded via agent frontmatter when code-reviewer runs (Phase 4). Covers: severity classification (BLOCKER/MAJOR/MINOR/NIT), decision matrix (APPROVED/APPROVED_WITH_COMMENTS/CHANGES_REQUESTED), auto-escalation rules, grep search patterns for automated checks.
disable-model-invocation: true
---

# Code Review Rules

## Severity Classification
- BLOCKER: Architecture/security violation — blocks approval
- MAJOR: Error handling, logging, significant gaps — blocks approval
- MINOR: Code style, naming, documentation — does not block
- NIT: Stylistic preference — does not block

## Decision Matrix
- APPROVED: 0 BLOCKER, 0 MAJOR (clean merge)
- APPROVED_WITH_COMMENTS: 0 BLOCKER, 0 MAJOR, has MINOR/NIT (merge with notes)
- CHANGES_REQUESTED: 1+ BLOCKER or 1+ MAJOR or 3+ MINOR (return to coder)

## Auto-Escalation
- 5+ MINOR in same file → escalate to MAJOR
- Security issue (any severity) → always BLOCKER
- Import matrix violation → always BLOCKER

## Spec Check Trust
If coder handoff includes spec_check with status=PASS → trust spec compliance, skip plan compliance re-check during REVIEW. Focus REVIEW entirely on code quality (architecture, error handling, security, test coverage).
If spec_check.status=PARTIAL → note documented gaps as MINOR during REVIEW.
If spec_check missing → backward compat: check plan coverage during REVIEW.

## Instructions

### Step 1: Quick Check — lint + test (blocking)
If coder handoff includes verify_status with lint=PASS and test=PASS → trust coder verification, skip re-run.
Otherwise: run `make lint` and `make test`. If EITHER fails → STOP, return to coder.
Do NOT proceed to review if Quick Check fails (whether trusted or re-run).
Also check spec_check from coder handoff. If status=PASS → note compliance trusted. If PARTIAL → note gaps. If missing → plan to check coverage during REVIEW (backward compat).

### Step 2: Get changes and assess scope
Run `git diff $BASE...HEAD` (detect base branch first — see code-reviewer.md process). Assess: files changed, lines changed, layers affected.
If >100 lines or >5 files or 3+ layers → use Sequential Thinking.

### Step 3: Review all concern areas
Check each area using grep search patterns from [Examples](examples.md):
- Architecture: import matrix compliance
- Error handling: no log+return, proper wrapping
- Security: no hardcoded secrets, no token leaks (see [Security Checklist](security-checklist.md))
- Test coverage: new code has tests

### Step 4: Apply Decision Matrix and form verdict
Count issues by severity. Apply Decision Matrix and Auto-Escalation rules above.
CRITICAL: NEVER approve with BLOCKER issues. Form handoff for completion.

## Example

### Log AND return — most common blocker

**Bad:**
```go
if err != nil {
    log.Error("failed", "err", err)
    return err  // duplicate log in error chain
}
```

**Good:**
```go
if err != nil {
    return fmt.Errorf("context: %w", err)
}
```
**Why:** [BLOCKER] Log AND return creates duplicate logs in error chain. Choose one: return with wrap (domain/service) or log (handler).

For more examples (incl. grep search patterns), see [Examples](examples.md).

## Common Issues

### Approved with blocker issues
**Cause:** Rushed review, missed severity classification.
**Fix:** NEVER approve with blockers — RULE is absolute. Re-check all findings against Severity Classification above before verdict.

### Log AND return pattern not caught
**Cause:** Trusted visual review instead of grep.
**Fix:** ALWAYS run `Grep 'log\.(Error|Warn|Info).*\n.*return'` on changed files. Automated checks catch what eyes miss.

### Sequential Thinking skipped on large diff
**Cause:** Changes seemed straightforward at first glance.
**Fix:** ALWAYS use Sequential Thinking for 100+ lines, 5+ files, or 3+ layers. No exceptions.

For all troubleshooting cases, see [Troubleshooting](troubleshooting.md).

## References
For detailed checks, read the supporting files in this skill directory:
- [Examples](examples.md) — bad/good code patterns, grep search patterns
- [Security Checklist](security-checklist.md) — OWASP checks (complexity M+, SKIP for S)
- [Checklist](checklist.md) — self-verification at each review phase
- [Troubleshooting](troubleshooting.md) — common review issues, mistakes, and fixes
