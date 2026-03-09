# Sequential Thinking Guide

purpose: "When and how to use Sequential Thinking MCP tool during planning and plan review"
loaded_when: "complexity L/XL only (SEE: .claude/commands/workflow.md conditional loading matrix)"

# ─────────────────────────────────────────────────────
# WHEN REQUIRED
# ─────────────────────────────────────────────────────
required_when:
  # Common triggers (both planner and reviewer)
  - condition: "Architecture layers >= 3"
    example: "Feature affects domain, usecase, repository, api layers"

  - condition: "New pattern or integration"
    example: "Integrating new external service, plugin system"

  - condition: "Parts in plan >= 4"
    example: "Plan has Database, Domain, Repository, UseCase, API, Tests"

  # Planner-specific triggers
  - condition: "Alternatives >= 3"
    role: planner
    example: "Choosing between REST, GraphQL, gRPC for API"

  - condition: "Trade-offs are non-obvious"
    role: planner
    example: "Performance vs maintainability, simplicity vs extensibility"

  # Reviewer-specific triggers
  - condition: "Plan > 150 lines"
    role: reviewer
    reason: "Large plans have hidden complexity"

# ─────────────────────────────────────────────────────
# MCP CALL FORMAT
# ─────────────────────────────────────────────────────
mcp_call:
  tool: "mcp__sequential-thinking__sequentialthinking"
  format:
    thought: "Analyzing/Validating {task/plan}"
    thoughtNumber: 1
    totalThoughts: "4-5 (minimum for architectural decisions)"
    nextThoughtNeeded: true

# ─────────────────────────────────────────────────────
# ANALYSIS STEPS: PLANNER
# ─────────────────────────────────────────────────────
planner_steps:
  description: "Use when CREATING a plan — choosing approach"
  steps:
    - step: 1
      action: "Identify constraints and requirements"
      output: "List of non-negotiable constraints"

    - step: 2
      action: "List all possible approaches (minimum 3)"
      output: "Table: Approach | Pros | Cons"

    - step: 3
      action: "Analyze trade-offs of each"
      output: "Detailed comparison against constraints"

    - step: 4
      action: "Select optimal with justification"
      output: "Selected approach with rationale"

    - step: 5
      action: "Verify selection against constraints"
      output: "Verification checklist passed"

  output_in_plan: |
    ## Architecture Decision

    **Analyzed via Sequential Thinking**

    **Alternatives considered:**
    1. {Approach 1} — {why rejected}
    2. {Approach 2} — {why rejected}
    3. {Approach 3} — {why rejected}

    **Selected approach:** {Approach} — {rationale}

    **Trade-offs accepted:**
    - {Trade-off 1}: {justification}
    - {Trade-off 2}: {justification}

  if_skipped: |
    Sequential Thinking: NOT USED
    Reason: {why unnecessary, e.g. "Standard repository layer addition, follows existing pattern"}

# ─────────────────────────────────────────────────────
# VALIDATION STEPS: REVIEWER
# ─────────────────────────────────────────────────────
reviewer_steps:
  description: "Use when VALIDATING a plan — checking correctness"
  steps:
    - step: 1
      action: "Verify data flow between layers"
      output: "Identify all layer boundaries crossed"

    - step: 2
      action: "Validate each Part against Clean Architecture"
      output: "List violations or confirm compliance"

    - step: 3
      action: "Check edge cases and error paths"
      output: "Document untested scenarios"

    - step: 4
      action: "Final verdict with justification"
      output: "APPROVED/NEEDS_CHANGES/REJECTED with reasons"

  enforcement:
    if_criteria_met_but_not_used:
      severity: MAJOR
      action: "Add as issue in verdict"
      rationale: "Complex plans need structured analysis to catch violations"

    if_used_when_not_needed:
      severity: MINOR
      action: "Note in verdict"
      rationale: "Over-analysis acceptable, better safe than sorry"

# ─────────────────────────────────────────────────────
# WHEN NOT REQUIRED
# ─────────────────────────────────────────────────────
not_required_when:
  - "Standard CRUD operation"
  - "Single layer affected"
  - "Clear obvious solution with no alternatives"
  - "Trivial changes (< 3 Parts, < 100 lines)"
