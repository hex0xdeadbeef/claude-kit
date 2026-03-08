# Code Review Checklist

purpose: "Self-verification checklist для каждой фазы code-review"
loaded_by: [code-review]
when: "Read at completion of each phase for self-verification"
source: "Extracted from code-review.md (lines 380-403) for deferred loading (4.4)"

---

checklist:
  quick_check:
    - "LINT && TEST passes"
    - "Memory checked: search_nodes for past review issues (NON_CRITICAL)"

  review:
    - "Architecture: imports follow matrix (PROJECT-KNOWLEDGE.md, if available)"
    - "Code: functions <= 30 lines, errors wrapped, no log+return"
    - "Security: OWASP checklist passed"
    - "Tests: coverage >= 70%"
    - "Project-specific: domain rules per PROJECT-KNOWLEDGE.md (if available)"
    - "MCP: Sequential Thinking (100+ lines), Context7 (new libraries)"

  verdict:
    - "Issues classified by severity"
    - "Recommendations are concrete and actionable"

  config_changes:
    - "config changed → CONFIG_EXAMPLE updated"
    - "config changed → CONFIG_DOCS updated"

  completion:
    - "bd sync executed (if beads)"
