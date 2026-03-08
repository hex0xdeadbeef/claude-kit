# Plan Review Troubleshooting

purpose: "Типичные ошибки при review планов и их решения"
loaded_by: [plan-review]
when: "Read when encountering issues during plan review"
source: "Extracted from plan-review.md (lines 347-366) for deferred loading (4.4)"

---

troubleshooting:
  - problem: "APPROVED plan with import violations"
    cause: "Manual check missed Handler → Repository import"
    fix: "Use arch-checker agent for complex plans (4+ Parts)"
    lesson: "Automation catches what humans miss"

  - problem: "MINOR issues escalated incorrectly"
    cause: "5+ MINOR in same Part should be MAJOR"
    fix: "Apply auto-escalation rules from Decision Matrix"
    lesson: "Many small issues = systemic problem"

  - problem: "Approved plan without Sequential Thinking check"
    cause: "Didn't verify if plan needed Sequential Thinking"
    fix: "Check sequential_thinking_criteria in PHASE 2"
    lesson: "Complex plans need structured analysis"

  - problem: "Security issue marked as MAJOR"
    cause: "Didn't apply auto-escalation rule"
    fix: "Security issues are ALWAYS BLOCKER"
    lesson: "Security cannot be compromised"
