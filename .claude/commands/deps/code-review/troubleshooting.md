# Code Review: Troubleshooting & Common Mistakes

**Purpose**: Known pitfalls and recovery patterns for code-review command.
**Load when**: Reviewer encounters unexpected situation or needs calibration guidance.

---

# ════════════════════════════════════════════════════════════════════════════════
# TROUBLESHOOTING
# ════════════════════════════════════════════════════════════════════════════════
troubleshooting:
  - problem: "APPROVED with blocker issues"
    cause: "Rushed review to meet deadline"
    fix: "NEVER approve with blockers - RULE_2 is absolute. Request changes."
    lesson: "Blocker issues in production cause incidents. No exceptions."

  - problem: "Sequential Thinking skipped on large diff"
    cause: "Changes seemed straightforward at first glance"
    fix: "ALWAYS use Sequential Thinking for 100+ lines, 5+ files, or 3+ architecture layers"
    lesson: "Complex reviews need structured analysis to catch subtle issues"

  - problem: "Security checklist incomplete"
    cause: "Time pressure, assumed code is safe"
    fix: "ALL OWASP checks are mandatory - no shortcuts on security"
    lesson: "Security vulnerabilities in production are expensive to fix"

  - problem: "log AND return pattern not caught"
    cause: "Didn't grep for the pattern, trusted visual review"
    fix: "Use Grep 'log\\.' then verify no adjacent return statements"
    lesson: "Automated checks catch patterns visual review misses"

  - problem: "Import matrix not verified"
    cause: "Trusted implementation, skipped architecture grep commands"
    fix: "ALWAYS run architecture grep checks from PHASE 3: REVIEW"
    lesson: "Architecture violations compound - catch early or refactor later"

---

# ════════════════════════════════════════════════════════════════════════════════
# COMMON MISTAKES
# ════════════════════════════════════════════════════════════════════════════════
common_mistakes:
  - mistake: "Approve with major issues to unblock delivery"
    why_bad: "Major issues become tech debt, harder to fix later"
    fix: "Request changes - major issues must be fixed before merge"
    check: "Count major issues - if > 0, verdict is CHANGES REQUESTED"

  - mistake: "Trust visual review instead of grep patterns"
    why_bad: "Human eyes miss repeated patterns across files"
    fix: "Always run search_patterns checks before verdict"
    check: "Grep results in review notes"

  - mistake: "Skip architecture check on 'small' changes"
    why_bad: "One wrong import creates precedent for more"
    fix: "ALWAYS check import matrix, regardless of change size"
    check: "Architecture check in TodoWrite"

  - mistake: "Mark issues as [nit] to avoid blocking"
    why_bad: "Severity manipulation hides real problems"
    fix: "Use severity guide strictly: security/arch = blocker"
    check: "All security issues marked [blocker]"

---

## SEE ALSO

- `deps/shared-core.md#error-handling` — Common error scenarios (MCP, git, tests)
- `security-checklist.md` — OWASP checks
- `examples.md` — Bad/good code patterns
