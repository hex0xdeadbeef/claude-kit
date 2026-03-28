# Coder Checklist

purpose: "Self-verification checklist for each coder phase"

---

checklist:
  startup:
    - "Plan loaded from .claude/prompts/"
    - "TodoWrite created with Parts"
    - "Feature branch created (if needed)"

  evaluate:
    - "Plan feasibility assessed"
    - "Hidden complexities identified"
    - "Decision made: PROCEED / REVISE / RETURN"

  evaluate_to_implement_gate:
    - "Evaluate decision made (PROCEED/REVISE/RETURN)"
    - "Evaluate output file written (.claude/prompts/{feature}-evaluate.md)"
    - "If PROCEED/REVISE → transition to IMPLEMENT"
    - "No further exploratory research during IMPLEMENT"

  implementation:
    - "Code matches plan"
    - "All Parts implemented (TodoWrite updated)"
    - "Import matrix followed"
    - "Error context pattern followed per project conventions (SEE: PROJECT-KNOWLEDGE.md)"
    - "Sequential Thinking used (if complex logic)"

  verification:
    - "VERIFY passes (adapt commands to project — SEE .claude/PROJECT-KNOWLEDGE.md)"
    - "If config changed → CONFIG_EXAMPLE and CONFIG_DOCS updated"

  review_response:
    condition: "Active on re-entry after CHANGES_REQUESTED"
    checks:
      - "Issues triaged by severity (BLOCKER → MAJOR → MINOR → NIT)"
      - "Each issue verified against codebase before implementing"
      - "Push-backs documented with technical reasoning"
      - "Fixes implemented in severity order, tested individually"
      - "NIT handling follows iteration strategy (1/3: all, 2/3: skip NIT, 3/3: BLOCKER+MAJOR only)"
      - "Handoff includes resolution status per issue"

  completion:
    - "Handoff payload formed for code-reviewer (SEE handoff-protocol.md)"
