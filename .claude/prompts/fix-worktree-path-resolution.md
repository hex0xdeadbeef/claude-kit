---
feature: fix-worktree-path-resolution
status: approved
complexity: S
task_type: bug_fix
created: 2026-03-30
---

# Fix worktree path resolution in prepare-worktree.sh (IMP-02)

## Context
`prepare-worktree.sh` (WorktreeCreate hook) tries to extract `worktree_path` from the payload.
The WorktreeCreate payload does NOT contain `worktree_path` — only `{session_id, transcript_path, cwd, hook_event_name, name}`.
Result: `worktree_path` is always None → script exits early → no worktree preparation happens.

The same fallback strategies are already proven in `save-review-checkpoint.sh` (IMP-04).

## Part 1: Add fallback strategies to prepare-worktree.sh

**File:** `.claude/scripts/prepare-worktree.sh`

**Change:** After the existing worktree_path extraction block (Strategy 1: payload fields),
add two fallback strategies when `worktree_path` is None.

**Strategy 2: Scan `.git/worktrees/` directory**
1. List entries in `.git/worktrees/`
2. Sort by modification time (most recent first)
3. Read `gitdir` file from most recent entry
4. Extract worktree path from gitdir content (parent of `.git`)
5. Validate path exists

**Strategy 3: `git worktree list --porcelain`**
1. Run `git worktree list --porcelain`
2. Parse "worktree /path" lines
3. Skip main worktree (cwd)
4. Take last entry (most recently added)
5. Validate path exists

**Also:** Log worktree_resolution method to worktree-events-debug.jsonl for observability.

## Acceptance Criteria
- [ ] Worktree path found via fallback when payload field absent
- [ ] Resolution method logged for debugging
- [ ] No regression: payload-based extraction still works if field ever appears
- [ ] Non-blocking: all fallbacks wrapped in try/except, always exit 0
