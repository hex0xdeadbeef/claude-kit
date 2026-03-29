---
name: review-patterns
description: Common plan issues found in this project and successful patterns observed
type: feedback
---

## Common Plan Issues (watch for these)

**1. Shell script heredoc + set -e interaction**
Plans fixing bash scripts with Python heredocs must use `(python3 << 'PYTHON_EOF' || true)`
subshell pattern to isolate Python failures from `set -euo pipefail`.
**Why:** `set -e` traps non-zero exits from heredoc Python blocks, preventing subsequent bash
commands (like stdout echo) from running.

**2. Hook stdout requirement**
WorktreeCreate (and potentially other) hooks require non-empty stdout to be considered successful
by Claude Code. Minimal `{}` is the correct output — NOT `{"continue": true}` which contaminates
agent metadata (worktreePath gets set to that JSON string).

**3. cwd fallback masking**
Fallback chains for worktree_path resolution must NOT include `cwd` — cwd is always present and
always equals the main repo, masking genuine absence of worktree_path for non-worktree agents.

**4. Code example completeness in Part 1c-style changes**
When a plan says "add always-log block and remove duplicate log from conditional block," the
code example often doesn't show the `sys.exit(0)` placement explicitly. Reviewer should flag
this as MINOR and clarify that the early return must stay inside the conditional, not be moved.

**5. Snippet-only code for shell insertions**
Plans that add short guard blocks to shell scripts often show only the new lines, not surrounding
context. Flag as MINOR when line-number-based insertion is the only guidance — best practice is
to show 2-3 surrounding lines (the line above and the existing guard below) for visual confirmation.
Verified correct in fix-code-reviewer-turn-drain (line numbers matched), but pattern is fragile.

**6. PostToolUse hook stdout — agent-memory amplification**
PostToolUse hooks (yaml-lint, check-references, check-plan-drift) fire on ALL `.claude/**` writes
including agent-memory. Any stdout they produce is shown to the agent and triggers fix attempts.
Fix: script-level guard `if [[ "$FILE_PATH" == *"agent-memory"* ]]; then exit 0; fi` inserted
after FILE_PATH extraction, before the `.claude/` check. Silent exit 0 — no stdout.

## Successful Plan Patterns

- Explicit before/after diff blocks for every change (worktree-hooks plan did this well)
- Spec criteria → plan part mapping (all 4 spec criteria covered)
- Acknowledging protect-files.sh constraint in Testing Plan
- Using `sorted(hook_input.keys())` for deterministic debug log output
- Three-tier turn budget enforcement (self-check / hard abort / memory deadline) — effective
  structure for agent behavioral rules; better than single-line instructions
- Executable test commands in `notes:` section (pipe test JSON through scripts)
