# Planner Troubleshooting

troubleshooting:
  - problem: "Sequential Thinking skipped for complex plan"
    cause: "Planner thinks plan is simple, but has 5+ parts"
    fix: "ALWAYS use Sequential Thinking if Parts ≥ 5 or alternatives ≥ 3"
    lesson: "Complex plans need structured decision-making"

  - problem: "Memory not checked before planning"
    cause: "Rushed directly to research phase"
    fix: "STARTUP phase is MANDATORY - search_nodes before any research"
    lesson: "Existing solutions save hours of work"

  - problem: "Plan has incomplete code examples (signatures only)"
    cause: "Planner shows function signature without body"
    fix: "RULE_3: FULL examples, not signatures"
    lesson: "Coder needs complete examples to implement"

  - problem: "Import matrix violations in plan"
    cause: "Handler imports Repository directly"
    fix: "Check PROJECT-KNOWLEDGE.md layer imports before writing Parts"
    lesson: "Architecture violations caught early save refactoring"

  - problem: "Config changes but CONFIG_DOCS not updated"
    cause: "Forgot to document config in CONFIG_DOCS"
    fix: "PHASE 3: DESIGN - Config changes require CONFIG_DOCS update"
    lesson: "Undocumented config = production incidents"
