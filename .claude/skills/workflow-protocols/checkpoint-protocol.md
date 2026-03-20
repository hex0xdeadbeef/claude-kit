# Checkpoint Protocol

purpose: "Proactive pipeline state saving for instant recovery"

---

checkpoint_protocol:
  severity: HIGH

  when: "After completing EVERY phase (including iteration loops)"
  file: ".claude/workflow-state/{feature}-checkpoint.yaml"

  format:
    feature: "{feature-name}"
    phase_completed: "0.5|1|2|3|4|5"
    phase_name: "task-analysis|planning|plan-review|implementation|code-review|completion"
    iteration:
      plan_review: "N/3"
      code_review: "N/3"
    verdict: "APPROVED|NEEDS_CHANGES|REJECTED|null"
    timestamp: "ISO 8601"
    complexity: "S|M|L|XL"
    route: "minimal|standard|full"
    session_type: "workflow|project-research|ad-hoc"
    re_routing:
      occurred: false
      original_route: "null|minimal|standard|full"
      new_route: "null|minimal|standard|full"
      reason: "null|string"
      phase: "null|plan-review|implementation"
    handoff_payload: "{ ... contents of latest handoff_output ... }"
    verify_result:
      status: "PASS|FAIL|null"
      command: "go vet ./... && make fmt && make lint && make test"
      timestamp: "ISO 8601 | null"
    issues_history:
      - phase: 2
        iteration: 1
        issues: ["PR-001: MAJOR — missing tests section"]

  session_type:
    note: "Session classification — used by exploration loop detection to exempt read-heavy sessions"
    values: "workflow|project-research|ad-hoc"
    default: "ad-hoc (if no checkpoint written yet)"
    set_by: "Orchestrator at Phase 0.5 (task-analysis) or project-researcher at startup"

  sub_phase:
    note: "Optional — tracked within planner/coder phases for exploration loop detection"
    fields:
      current: "RESEARCH|DESIGN|DOCUMENT|EVALUATE|IMPLEMENT|VERIFY"
      tool_calls_in_sub_phase: "N (count of tool calls since sub-phase start)"
      file_reads_in_sub_phase: "N (count of Read/Grep/Glob calls since sub-phase start)"
      budget_threshold: "20 reads per sub-phase (see CLAUDE.md error table)"
      on_exceeded: "STOP_AND_TRANSITION to next sub-phase"

  sub_phase_mapping:
    note: |
      Coder-internal tracking concept (NOT a checkpoint format field).
      Maps coder phases to descriptive labels for logging/debugging:
    mapping:
      - sub_phase: "evaluate"
        coder_phase: "1.5"
      - sub_phase: "implementing"
        coder_phase: "2"
      - sub_phase: "verify"
        coder_phase: "3"

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
      session_type: "workflow"
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
      verify_result:
        status: "PASS"
        command: "go vet ./... && make fmt && make lint && make test"
        timestamp: "2026-02-20T14:25:00Z"
