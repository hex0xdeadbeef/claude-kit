---
name: Hook Stdout Contracts
description: Actual stdout contract formats for claude-kit hooks — PreToolUse uses hookSpecificOutput envelope, not {decision:block}
type: project
---

Claude Code hook stdout contracts vary by event type. This was discovered by diffing workflow-architecture.md documentation against actual script implementations (2026-03-30).

## Verified Contracts

**PreToolUse blocking** (protect-files.sh, block-dangerous-commands.sh, pre-commit-build.sh):
```json
{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "..."}}
```
Allow: no output (exit 0 silently).

**Stop blocking** (check-uncommitted.sh):
```json
{"decision": "block", "reason": "..."}
```
Note: Stop uses a DIFFERENT (simpler) format than PreToolUse.

**WorktreeCreate** (prepare-worktree.sh):
**NO stdout at all** — silent exit 0. Claude Code parses ALL stdout (JSON or plain text) as worktree metadata, creating bogus directories (e.g. `worktreePath="{}"` or `worktreePath="worktree prepared"`).

**UserPromptSubmit / PreCompact / PostCompact / InstructionsLoaded**:
`{"additionalContext": "..."}` — or nothing on success/no-op.

**SubagentStart / SubagentStop / PostToolUse / SessionEnd / StopFailure / Notification**:
No stdout needed (writes go to JSONL files or stderr).

**Why:** PreToolUse in Claude Code v2.x uses the hookSpecificOutput envelope for permission decisions; Stop uses a legacy simpler format. The two should not be conflated.
**How to apply:** When adding a new PreToolUse blocking hook, use the hookSpecificOutput envelope, not {decision:block}.
