# Plan Review Checklist

purpose: "Self-verification checklist для каждой фазы plan-review"
loaded_by: [plan-review]
when: "Read at completion of each phase for self-verification"
source: "Extracted from plan-review.md (lines 377-404) for deferred loading (4.4)"

---

checklist:
  phase_1_startup:
    - item: "TodoWrite created"
    - item: "Memory checked (search_nodes)"
    - item: "Plan loaded from .claude/prompts/"

  phase_2_read_plan:
    - item: "All required sections present"
    - item: "Format matches plan-template.md"

  phase_3_validate_architecture:
    - item: "Package imports verified (SEE: PROJECT-KNOWLEDGE.md#Dependency Matrix)"
    - item: "Models have no extra tags (domain entities pure)"
    - item: "API layer does not import data access directly (uses service/controller layer)"
    - item: "Protected files not edited"
    - item: "Sequential Thinking used (if 4+ Parts)"

  phase_4_validate_completeness:
    - item: "All layers described"
    - item: "Code examples are COMPLETE"
    - item: "Tests planned"
    - item: "Security checklist passed (if API)"

  phase_5_verdict:
    - item: "All issues classified (BLOCKER/MAJOR/MINOR)"
    - item: "Decision matrix applied"
    - item: "Verdict justified"
    - item: "bd sync executed"
