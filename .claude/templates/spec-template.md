meta:
  type: "spec-template"
  purpose: "Design spec template — output of /designer, input to /planner and validated by plan-reviewer"
  usage: "Fill placeholders → save as {feature}-spec.md → pass to /planner"

spec:
  title: "{Feature Name}"
  status: "pending_approval"  # Set by /designer — do not manually edit. Values: pending_approval | approved

  context:
    current_state: "{What exists now}"
    motivation: "{Why this change is needed}"
    business_value: "{Expected outcome}"

  requirements:
    in_scope:
      - "{Requirement 1}"
      - "{Requirement 2}"
    out_of_scope:
      - item: "{What is excluded}"
        reason: "{Why excluded}"
    constraints:
      - "{Non-negotiable constraint 1}"
      - "{Non-negotiable constraint 2}"

  approach:
    selected:
      name: "{Approach name}"
      description: "{How it works}"
      rationale: "{Why this approach}"
    alternatives:
      - option: "{Alternative 1}"
        pros: ["{pro1}", "{pro2}"]
        cons: ["{con1}", "{con2}"]
        rejected_because: "{Why not chosen}"
      - option: "{Alternative 2}"
        pros: ["{pro1}"]
        cons: ["{con1}"]
        rejected_because: "{Why not chosen}"

  key_decisions:
    - decision: "{Decision 1}"
      rationale: "{Why}"
      impact: "{What this affects}"
    - decision: "{Decision 2}"
      rationale: "{Why}"
      impact: "{What this affects}"

  risks:
    - risk: "{Risk description}"
      severity: "HIGH|MEDIUM|LOW"
      mitigation: "{How to mitigate}"
    - risk: "{Risk description}"
      severity: "HIGH|MEDIUM|LOW"
      mitigation: "{How to mitigate}"

  acceptance_criteria:
    - "{Criterion 1 — verifiable}"
    - "{Criterion 2 — verifiable}"

  notes: "{Additional context, edge cases, open questions resolved}"
