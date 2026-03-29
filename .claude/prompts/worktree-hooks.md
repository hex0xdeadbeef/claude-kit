# Task: Worktree Hooks Architecture Fix

## Context
WorktreeCreate hook (`prepare-worktree.sh`) fails with "no successful output" when code-reviewer
launches with `isolation: worktree`. Additionally, `save-review-checkpoint.sh` has an incorrect
`cwd` fallback that writes false worktree paths for non-worktree agents.

Spec: `.claude/prompts/worktree-hooks-spec.md` (approved)
Complexity: M (user requested XL but scope is 2 scripts + 1 doc)

## Scope
### IN
- [x] Fix prepare-worktree.sh stdout + Python isolation
- [x] Fix save-review-checkpoint.sh cwd fallback
- [x] Update workflow-architecture.md hook contracts table

### OUT
- Refactor scripts into functions (speculative)
- New hook-contracts.md file (overkill)
- Fix SubagentStop for review-completions.jsonl (separate issue)

## Part 1: prepare-worktree.sh (UPDATE)
**File:** `.claude/scripts/prepare-worktree.sh`

### Changes:

**1a.** Wrap Python heredoc in subshell to isolate from `set -e`:

Replace (line 23-193):
```bash
python3 << 'PYTHON_EOF'
...
PYTHON_EOF
```

With:
```bash
(python3 << 'PYTHON_EOF' || true)
...
PYTHON_EOF
```

This ensures Python failures don't prevent the stdout echo from executing.

**1b.** Add stdout output BEFORE exit 0 (line 195-196):

Replace:
```bash
# ALWAYS exit 0 — never block worktree creation
exit 0
```

With:
```bash
# ALWAYS exit 0 — never block worktree creation
# Claude Code requires non-empty stdout from hooks (observed: "no successful output" error without it)
# Output minimal JSON — avoid semantic content that could contaminate agent metadata
echo '{}'
exit 0
```

**1c.** Inside Python block, ALWAYS log received payload keys to debug file (even when worktree_path found).

After the existing worktree_path extraction (after line 70), add:

```python
# ALWAYS log received keys for contract discovery (regardless of whether worktree_path found)
try:
    with open(DEBUG_FILE, "a") as f:
        f.write(json.dumps({
            "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "hook": "WorktreeCreate",
            "worktree_path_found": bool(worktree_path),
            "received_keys": sorted(hook_input.keys()),
            "raw_input": input_data[:2000],
        }) + "\n")
except Exception:
    pass
```

And remove the duplicate logging inside the `if not worktree_path:` block (lines 72-84) since
it's now covered by the always-log above. Keep the `sys.exit(0)` early return.

## Part 2: save-review-checkpoint.sh (UPDATE)
**File:** `.claude/scripts/save-review-checkpoint.sh`

### Change:

Remove `cwd` from worktree_path fallback chain (line 62-67).

Replace:
```python
worktree_path = (
    data.get("worktree_path")
    or data.get("worktreePath")
    or data.get("cwd")
    or (data.get("worktree", {}) or {}).get("path")
)
```

With:
```python
worktree_path = (
    data.get("worktree_path")
    or data.get("worktreePath")
    or (data.get("worktree", {}) or {}).get("path")
)
```

**Rationale:** `cwd` always exists and always = main repo. This masks missing worktree_path
and creates false entries in review-completions.jsonl for non-worktree agents (plan-reviewer).
After this fix: if worktree_path is genuinely absent, it stays None, and memory sync is correctly skipped.

## Part 3: workflow-architecture.md (UPDATE)
**File:** `.claude/docs/workflow-architecture.md`

### Change:

Add a new section **"Hook Stdout Contracts"** after the "Хуки и скрипты" table (after line 88).

```markdown
### Hook Stdout Contracts

| Event | Script | Stdout Contract | Notes |
|-------|--------|----------------|-------|
| PreToolUse | protect-files.sh, block-dangerous-commands.sh | `{"decision": "block", "reason": "..."}` or nothing (allow) | Blocking hooks |
| PreToolUse | pre-commit-build.sh | `{"decision": "block", "reason": "..."}` or nothing | Conditional |
| UserPromptSubmit | enrich-context.sh | `{"additionalContext": "..."}` | Injects context |
| PreCompact | save-progress-before-compact.sh | `{"additionalContext": "..."}` | Preserves state |
| PostCompact | verify-state-after-compact.sh | `{"additionalContext": "..."}` | Restores state |
| InstructionsLoaded | validate-instructions.sh | `{"additionalContext": "..."}` | Rules validation |
| WorktreeCreate | prepare-worktree.sh | `{}` (minimal JSON) | Required non-empty |
| SubagentStop | save-review-checkpoint.sh | nothing | Writes to JSONL |
| Stop | check-uncommitted.sh | `{"decision": "block", "reason": "..."}` or nothing | Workflow-only |
| All others | various | nothing (stderr only) | Analytics/logging |

**Contract rule:** Claude Code requires non-empty stdout from hooks to consider them successful.
Hooks that don't need to inject context or block should output `{}`.
```

## Files Summary
| File | Action | Description |
|------|--------|-------------|
| `.claude/scripts/prepare-worktree.sh` | UPDATE | Fix stdout + Python isolation + discovery log |
| `.claude/scripts/save-review-checkpoint.sh` | UPDATE | Remove cwd fallback |
| `.claude/docs/workflow-architecture.md` | UPDATE | Add hook stdout contracts table |

## Acceptance Criteria
### Functional
- [ ] code-reviewer agent launches in worktree without "no successful output" error
- [ ] worktree-events-debug.jsonl receives payload discovery entries
- [ ] review-completions.jsonl: plan-reviewer entries have worktree_path = null (not main repo)

### Technical
- [ ] shellcheck -x passes on both scripts (0 warnings)
- [ ] Python block failure doesn't prevent stdout echo (subshell isolation)
- [ ] No regressions: plan-reviewer still writes verdicts to review-completions.jsonl

## Testing Plan
- Verify: `shellcheck -x .claude/scripts/prepare-worktree.sh`
- Verify: `shellcheck -x .claude/scripts/save-review-checkpoint.sh`
- Manual: launch code-reviewer agent with isolation:worktree → confirm no hook error
- NOTE: protect-files.sh blocks agent edits to .claude/scripts/ — changes must be applied by user

## Notes
- protect-files.sh hook blocks edits to `.claude/scripts/` — all script changes will be
  provided as exact diffs for the user to apply manually
- workflow-architecture.md may not exist (was lost in .claude overwrite) — create if missing
