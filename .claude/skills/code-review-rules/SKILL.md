---
name: code-review-rules
description: Code review severity classification, decision matrix, security checklist, and review patterns for code review
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

## References
For detailed checks, read the supporting files in this skill directory:
- [Examples](examples.md) — bad/good code patterns, grep search patterns
- [Security Checklist](security-checklist.md) — OWASP checks (complexity M+, SKIP for S)
- [Checklist](checklist.md) — self-verification at each review phase
- [Troubleshooting](troubleshooting.md) — common review issues, mistakes, and fixes
