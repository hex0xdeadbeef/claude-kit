# Shared Review

purpose: "Review verdict, severity classification, decision matrix — review agents only"
loaded_by: [plan-review, code-review]
referenced_from: [review-checklist.md]
source: "Extracted from shared-core.md for selective loading"

---

## Review Verdict

**Single source of truth for severity classification, decision matrix, and auto-escalation rules.**
**Used by:** plan-review, code-review. **Referenced from:** review-checklist.md.

severity_classification:
  levels:
    - level: "[blocker]"
      meaning: "Architecture / security violation"
      blocks: true
    - level: "[major]"
      meaning: "Error handling, logging, significant gaps"
      blocks: true
    - level: "[minor]"
      meaning: "Code style, naming, documentation"
      blocks: false
    - level: "[nit]"
      meaning: "Stylistic preference"
      blocks: false

decision_matrix:
  - verdict: APPROVED
    condition: "0 BLOCKER, 0 MAJOR"
    note: "Minor/nit issues may be noted but don't block"

  - verdict: NEEDS_CHANGES
    condition: "0 BLOCKER, 1+ MAJOR or 3+ MINOR"
    note: "Return to author for fixes"

  - verdict: REJECTED
    condition: "1+ BLOCKER"
    note: "Fundamental issues — requires re-work"

auto_escalation:
  - rule: "5+ MINOR issues in same Part/file"
    action: "Escalate to MAJOR"
    reason: "Many small issues = systemic problem"

  - rule: "Security issue (any severity)"
    action: "Always BLOCKER"
    reason: "Security cannot be compromised"

  - rule: "Import matrix violation"
    action: "Always BLOCKER"
    reason: "Architecture violations cause long-term maintainability issues"
