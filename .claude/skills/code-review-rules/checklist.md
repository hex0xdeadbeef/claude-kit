# Code Review Checklist

purpose: "Self-verification checklist for each code-review phase"

---

checklist:
  quick_check:
    - "LINT && TEST passes"

  review:
    - "Architecture: imports follow matrix (.claude/PROJECT-KNOWLEDGE.md, if available)"
    - "Code: functions <= 30 lines, errors wrapped, no log+return"
    - "Comments: added/modified comments describe the code, not plan parts, ACs, review ids, phases, or change narrative"
    - "Security: OWASP checklist passed"
    - "Tests: coverage >= 70%"
    - "Project-specific: domain rules per .claude/PROJECT-KNOWLEDGE.md (if available)"
    - "MCP: Sequential Thinking (100+ lines), Context7 (new libraries)"

  verdict:
    - "Issues classified by severity"
    - "Recommendations are concrete and actionable"

  config_changes:
    - "config changed → CONFIG_EXAMPLE updated"
    - "config changed → CONFIG_DOCS updated"

  completion:
    - "Handoff payload formed for workflow orchestrator (SEE handoff-protocol.md)"
