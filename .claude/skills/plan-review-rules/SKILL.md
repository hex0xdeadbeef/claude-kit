---
name: plan-review-rules
description: Architecture compliance checks, required plan sections, severity classification, and decision matrix for plan review
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
- Import matrix violation → always BLOCKER

## References
For detailed checks, read the supporting files in this skill directory:
- [Architecture Checks](architecture-checks.md) — import matrix, domain purity, layer violations, security, design patterns, concurrency
- [Required Sections](required-sections.md) — plan structure validation, section-by-section checks
- [Checklist](checklist.md) — self-verification at each review phase
- [Troubleshooting](troubleshooting.md) — common review issues and fixes
