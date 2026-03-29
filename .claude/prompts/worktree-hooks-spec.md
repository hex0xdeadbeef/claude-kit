spec:
  title: "Worktree Hooks Architecture Fix"
  status: "approved"

  context:
    current_state: |
      WorktreeCreate hook (prepare-worktree.sh) failed on first real worktree usage:
        "WorktreeCreate hook failed: no successful output"
      User added echo '{"continue": true}' as workaround (later lost on .claude overwrite).
      Side effect observed: worktreePath in agent metadata = '{"continue": true}'.
    issues:
      - id: I-1
        severity: HIGH
        title: "prepare-worktree.sh outputs nothing to stdout"
        detail: "Claude Code requires non-empty stdout from hooks. Script outputs nothing -> error."
      - id: I-2
        severity: MEDIUM
        title: "worktree-events.jsonl always empty"
        detail: "Python block can't find worktree_path in payload -> sys.exit(0) before writing."
      - id: I-3
        severity: LOW
        title: "save-review-checkpoint.sh cwd fallback incorrect"
        detail: "Falls back to cwd for worktree_path -> plan-reviewer gets main repo path."

  approach:
    selected: "Option B — Targeted multi-fix"

  acceptance_criteria:
    - "code-reviewer launches with isolation:worktree without hook error"
    - "worktree-events-debug.jsonl logs real payload fields"
    - "save-review-checkpoint.sh does not write false worktree_path for plan-reviewer"
    - "shellcheck -x on both scripts: 0 warnings"
