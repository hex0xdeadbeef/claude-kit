# Handoff Protocol

purpose: "Структурированная передача контекста между фазами pipeline"
loaded_by: [workflow]
when: "Read BEFORE forming handoff between phases"
source: "Extracted from workflow.md (lines 262-344) for event-triggered loading (4.3)"

---

handoff_protocol:
  severity: CRITICAL
  rule: "Каждая фаза ОБЯЗАНА создать handoff payload для следующей фазы"

  contract:
    planner_to_plan_review:
      producer: "/planner"
      consumer: "/plan-review"
      payload:
        artifact: ".claude/prompts/{feature}.md"
        metadata:
          task_type: "{new_feature|bug_fix|refactoring|...}"
          complexity: "{S|M|L|XL}"
          sequential_thinking_used: true|false
          alternatives_considered: N
        key_decisions:
          - "Описание ключевого решения + обоснование"
        known_risks:
          - "Описание известного риска"
        areas_needing_attention:
          - "Part N: почему требует внимания"

    plan_review_to_coder:
      producer: "/plan-review"
      consumer: "/coder"
      payload:
        artifact: ".claude/prompts/{feature}.md"
        verdict: "APPROVED|NEEDS_CHANGES|REJECTED"
        issues_summary:
          blocker: 0
          major: 0
          minor: 0
        approved_with_notes:
          - "Note about Part N"
        iteration: "N/3"

    coder_to_code_review:
      producer: "/coder"
      consumer: "/code-review"
      payload:
        branch: "feature/{name}"
        parts_implemented: ["Part 1: DB", "Part 2: Domain"]
        evaluate_adjustments:
          - "Part N: описание adjustment"
        risks_mitigated:
          - "Risk + как решён"
        deviations_from_plan:
          - "Описание + обоснование"

    code_review_to_completion:
      producer: "/code-review"
      consumer: "workflow/completion"
      payload:
        verdict: "APPROVED|APPROVED_WITH_COMMENTS|CHANGES_REQUESTED"
        issues:
          - id: "CR-001"
            severity: "BLOCKER|MAJOR|MINOR|NIT"
            category: "architecture|security|error_handling|completeness|style"
            location: "path/file{EXT}:line"
            problem: "..."
            suggestion: "..."
        iteration: "N/3"

  narrative_casting:
    purpose: "Context handoff to review phases without creation-process bias"
    rule: "Review phases receive narrative context + artifact, NOT creation history"
    template_fields:
      - field: "context_source"
        value: "{agent_name}"
        description: "Which agent produced the artifact"
      - field: "work_performed"
        value: "{brief_description}"
        description: "What the agent did"
      - field: "key_decisions"
        value: "[list]"
        description: "Architectural/design decisions with rationale"
      - field: "known_risks"
        value: "[list]"
        description: "Identified risks and their status"
      - field: "reviewer_recommendations"
        value: "[list]"
        description: "Specific areas for reviewer attention"
