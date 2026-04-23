# Workflow Examples & Troubleshooting

purpose: "Reference examples, common mistakes, and troubleshooting for /workflow orchestrator"
loaded_when: "On-demand — first run or problem encountered"

# ─────────────────────────────────────────────────────
# EXAMPLES
# ─────────────────────────────────────────────────────
examples:
  sequential_execution_with_confirmations:
    good:
      input: "Add new endpoint"
      steps:
        - phase: 1
          action: "/planner"
          result: "Plan created"
        - checkpoint: "Proceed to Phase 2?"
          answer: "yes"
        - phase: 2
          action: "/plan-review"
          result: "APPROVED"
        - checkpoint: "Proceed to Phase 3?"
          answer: "yes"
        - phase: 3
          action: "/coder"
          result: "Code written, tests pass"
        - checkpoint: "Proceed to Phase 4?"
          answer: "yes"
        - phase: 4
          action: "/code-review"
          result: "APPROVED → feature complete"
    bad:
      input: "Just write code, no planning"
      steps:
        - skip: "Phase 1 and Phase 2"
        - jump_to: "Phase 3 directly"
    why: "Skipping phases leads to low-quality code without architectural review and validation"

  completion_without_autocommit:
    good:
      trigger: "Phase 4: APPROVED"
      steps:
        - action: "Suggest commit command to user"
          command: "git add <specific-files> && git commit -m 'feat: ...'"
          note: "NEVER use git add . — always stage specific files to avoid committing secrets (.env, credentials)"
        - action: "Wait for user to decide when to commit"
    bad:
      trigger: "Phase 4: APPROVED"
      steps:
        - action: "git add && git commit && git push (automatically)"
    why: "Auto-commit without permission violates user control over repository"

# ─────────────────────────────────────────────────────
# TROUBLESHOOTING
# ─────────────────────────────────────────────────────
troubleshooting:
  - problem: "Phase 2 keeps returning NEEDS_CHANGES"
    cause: "Plan missing critical sections (Scope, Architecture Decision, Tests)"
    fix: "Check plan against templates/plan-template.md, ensure all sections filled"

  - problem: "Phase 3 tests fail repeatedly"
    cause: "Plan not detailed enough or missing edge cases"
    fix: "Return to Phase 1, add specific test cases to plan"

  - problem: "Stuck in Phase 1 → Phase 2 loop"
    cause: "Requirements unclear or too broad"
    fix: "Ask user to clarify scope, break task into smaller pieces"

  - problem: "Session interrupted mid-workflow"
    cause: "Connection lost, timeout, or manual stop"
    fix: "Check `.claude/prompts/{feature}.md` for saved plan, use --from-phase to resume"

common_mistakes:
  - mistake: "Skipping Phase 2 (plan-review)"
    why_bad: "Unvalidated plans lead to rework in Phase 3/4"
    fix: "Always run /plan-review even for 'simple' tasks"

  - mistake: "Auto-committing without user consent"
    why_bad: "User loses control over repository state"
    fix: "Always ask before git commit, never auto-push"

  - mistake: "Not saving lessons_learned for complex tasks"
    why_bad: "Knowledge lost, same mistakes repeated"
    fix: "After non-trivial tasks, save insights to MCP memory"

  - mistake: "Polling BashOutput in a loop while a run_in_background Bash is still running (Monitor tool, v2.1.98)"
    why_bad: |
      Each BashOutput call in a while-loop evicts a cache segment. On XL workflows
      with 5-10 background phases, repeated polling costs 30-70% more tokens and
      slows feedback by 2-5x.
    fix: |
      Two correct patterns — neither polls:
      Pattern A (wait-until-done): Bash(command: "...", run_in_background: true) →
        harness auto-notifies on process exit → one BashOutput read AFTER
        completion. A single BashOutput is fine; only repeated polling is the
        anti-pattern.
      Pattern B (streaming progress): add Monitor(command: "tail -f /tmp/log"),
        which emits one notification per stdout line — use when the agent needs
        to react to intermediate output (e.g. first FAIL → stop and diagnose).
      Agent/Task-tool background invocations self-notify; Monitor is for
      Bash-based streaming only.
