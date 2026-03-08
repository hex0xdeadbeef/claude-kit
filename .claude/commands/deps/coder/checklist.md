# Coder Checklist

purpose: "Self-verification checklist для каждой фазы coder"
loaded_by: [coder]
when: "Read at completion of each phase for self-verification"
source: "Extracted from coder.md (lines 442-467) for deferred loading (4.4)"

---

checklist:
  startup:
    - "Plan loaded from .claude/prompts/"
    - "TodoWrite created with Parts"
    - "Memory checked: search_nodes for lessons/decisions (NON_CRITICAL)"
    - "Feature branch created (if needed)"
    - "If beads used → status updated to in_progress"

  evaluate:
    - "Plan feasibility assessed"
    - "Hidden complexities identified"
    - "Decision made: PROCEED / REVISE / RETURN"

  implementation:
    - "Code matches plan"
    - "All Parts implemented (TodoWrite updated)"
    - "Import matrix followed"
    - "Error context pattern followed per project conventions (SEE: PROJECT-KNOWLEDGE.md)"
    - "Sequential Thinking used (if complex logic)"

  verification:
    - "VERIFY passes (adapt commands to project — SEE .claude/PROJECT-KNOWLEDGE.md)"
    - "If config changed → CONFIG_EXAMPLE and CONFIG_DOCS updated"

  completion:
    - "bd sync completed"
