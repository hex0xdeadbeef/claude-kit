# Checkpoint Protocol

purpose: "Proactive pipeline state saving for instant recovery"

---

checkpoint_protocol:
  severity: HIGH

  when: "After completing EVERY phase (including iteration loops)"
  file: ".claude/workflow-state/{feature}-checkpoint.yaml"

  format:
    feature: "{feature-name}"
    phase_completed: "0.5|1|2|3|4"
    phase_name: "task-analysis|planning|plan-review|implementation|code-review"
    iteration:
      plan_review: "N/3"
      code_review: "N/3"
    verdict: "APPROVED|NEEDS_CHANGES|REJECTED|null"
    timestamp: "ISO 8601"
    complexity: "S|M|L|XL"
    route: "minimal|standard|full"
    re_routing:
      occurred: false
      original_route: "null|minimal|standard|full"
      new_route: "null|minimal|standard|full"
      reason: "null|string"
      phase: "null|plan-review|implementation"
    handoff_payload: "{ ... contents of latest handoff_output ... }"
    issues_history:
      - phase: 2
        iteration: 1
        issues: ["PR-001: MAJOR — missing tests section"]

  recovery:
    action: "Read checkpoint → resume from next phase"
    steps:
      - "Read .claude/workflow-state/{feature}-checkpoint.yaml"
      - "Verify checkpoint integrity (all fields populated)"
      - "Skip all completed phases"
      - "Resume from phase_completed + 1"
      - "Load handoff_payload as input for current phase"
    advantage: "No need to re-evaluate state by indirect signals (plan exists? changes exist?)"

  example:
    file: ".claude/workflow-state/{feature}-checkpoint.yaml"
    fields:
      feature: "{feature-name}"
      phase_completed: 2
      phase_name: "plan-review"
      iteration:
        plan_review: "1/3"
        code_review: "0/3"
      verdict: "APPROVED"
      timestamp: "2026-02-20T14:30:00Z"
      complexity: "L"
      route: "standard"
      re_routing:
        occurred: false
        original_route: null
        new_route: null
        reason: null
        phase: null
      handoff_payload:
        to: "coder"
        artifact: ".claude/prompts/{feature}.md"
        verdict: "APPROVED"
        issues_summary: { blocker: 0, major: 0, minor: 1 }
        approved_with_notes:
          - "Part 3: minor — add error context in helper"
        iteration: "1/3"
