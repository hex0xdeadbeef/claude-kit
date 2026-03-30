# Workflow Architecture

## Hook Stdout Contracts

Claude Code requires non-empty stdout from hooks to consider them successful.
Hooks that don't need to inject context or block should output nothing (exit 0 silently).
**CRITICAL:** Do NOT output ANYTHING to stdout from WorktreeCreate hooks — Claude Code parses ALL stdout (JSON or plain text) as worktree metadata (e.g. `worktreePath="worktree prepared"`).

| Event | Script | Stdout Contract | Notes |
|-------|--------|----------------|-------|
| PreToolUse | protect-files.sh, block-dangerous-commands.sh | `{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "..."}}` or nothing (allow) | Blocking hooks |
| PreToolUse | pre-commit-build.sh | `{"hookSpecificOutput": {..., "permissionDecision": "deny", ...}}` or nothing | Conditional |
| PreToolUse | check-artifact-size.sh | `{"hookSpecificOutput": {..., "permissionDecision": "deny", ...}}` or nothing | Conditional |
| UserPromptSubmit | enrich-context.sh | `{"additionalContext": "..."}` | Injects context |
| PreCompact | save-progress-before-compact.sh | `{"additionalContext": "..."}` | Preserves state |
| PostCompact | verify-state-after-compact.sh | `{"additionalContext": "..."}` | Restores state |
| InstructionsLoaded | validate-instructions.sh | `{"additionalContext": "..."}` | Rules validation |
| WorktreeCreate | prepare-worktree.sh | **nothing** (silent exit 0) | ANY stdout parsed as worktree metadata — causes bogus directories |
| SubagentStart | track-task-lifecycle.sh | nothing | Writes to JSONL |
| SubagentStop | save-review-checkpoint.sh | nothing | Writes to JSONL |
| Stop | check-uncommitted.sh | `{"decision": "block", "reason": "..."}` or nothing | Workflow-only |
| PostToolUse | auto-fmt-go.sh | nothing | Auto-format |
| PostToolUse | yaml-lint.sh | nothing | Lint YAML |
| PostToolUse | check-references.sh | nothing | Reference check |
| PostToolUse | check-plan-drift.sh | nothing | Plan drift |
| SessionEnd | session-analytics.sh | nothing | Analytics |
| StopFailure | log-stop-failure.sh | nothing | Error logging |
| Notification | notify-user.sh | nothing | Desktop alerts |
