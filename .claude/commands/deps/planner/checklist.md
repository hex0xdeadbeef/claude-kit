# Planner Checklist

purpose: "Self-verification checklist для каждой фазы planner"
loaded_by: [planner]
when: "Read at completion of each phase for self-verification"
source: "Extracted from planner.md (lines 416-453) for deferred loading (4.4)"

---

checklist:
  phase_0_task_analysis:
    - "Task type classified (new_feature/bug_fix/refactoring/...)"
    - "Complexity estimated (S/M/L/XL)"
    - "Route determined (minimal/standard/full)"
    - "Preconditions checked"

  phase_1_understand:
    - "Task type classified"
    - "Clarifying questions asked"
    - "Scope defined (IN/OUT)"

  phase_2_data_flow:
    - "Data source identified (HTTP/Worker/CLI)"
    - "Data path traced through layers"
    - "Implementation layer selected with rationale"
    - "Entry and exit points documented"

  phase_3_research:
    - "Memory checked (search_nodes)"
    - "Code investigated (Grep/Glob or code-searcher)"
    - "External libraries checked (Context7 if needed)"
    - "Imports between packages verified"

  phase_4_design:
    - "Sequential Thinking used (if 3+ alternatives)"
    - "Parts defined in order: DB -> Domain -> Contract -> ..."
    - "Code examples are FULL"

  phase_5_document:
    - "Plan saved to `.claude/prompts/`"
    - "Config changes documented (if any)"

  phase_6_save_to_memory:
    - "Save criteria checked"
    - "If non-trivial decision -> saved to memory"
    - "`bd sync` executed"
    - "If beads in use -> remind about task closure"
