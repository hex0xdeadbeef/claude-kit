#!/usr/bin/env python3
"""Resolve worktree path from hook payload with fallback strategies.

Called by: prepare-worktree.sh (WorktreeCreate), save-review-checkpoint.sh (SubagentStop)
Input: _HOOK_INPUT env var (JSON payload from hook)
       _CALLER env var (optional — error message prefix, default "resolve-worktree-path")
Output: JSON {"worktree_path": "...", "resolution": "..."} on stdout, or nothing if not found
Exit: 0 always

Resolution strategies (in order):
  1. Payload field extraction (worktree_path, worktreePath, path, worktree.path)
  2. .git/worktrees/ scan — session-aware match (IMP-23), then most recent by mtime
  3. git worktree list --porcelain — last entry (most recently added)

Guards (applied after strategy 1 and as final validation):
  - Must be absolute path (starts with /)
  - No spaces (worktree paths should not contain spaces)
  - No { or } (JSON/stdout contamination from WorktreeCreate hook)
  - Must exist as directory (final validation only)
"""
import json, os, subprocess, sys

CALLER = os.environ.get("_CALLER", "resolve-worktree-path")

try:
    data = json.loads(os.environ.get("_HOOK_INPUT", "{}"))
except Exception:
    data = {}

# Strategy 1: Extract from payload (try multiple field name patterns)
worktree_path = (
    data.get("worktree_path")
    or data.get("worktreePath")
    or data.get("path")
    or (data.get("worktree", {}) or {}).get("path")
)

resolution = "payload" if worktree_path else None

# Guard: reject non-absolute paths, spaces, JSON/stdout contamination
if worktree_path:
    wp = str(worktree_path).strip()
    if not wp.startswith("/") or " " in wp or "{" in wp or "}" in wp:
        print(f"{CALLER}: rejecting invalid worktree_path: {worktree_path!r}", file=sys.stderr)
        worktree_path = None
        resolution = None

# Strategy 2: Scan .git/worktrees/ for matching worktree
if not worktree_path:
    worktrees_dir = os.path.join(".git", "worktrees")
    if os.path.isdir(worktrees_dir):
        try:
            entries = [
                d for d in os.listdir(worktrees_dir)
                if os.path.isdir(os.path.join(worktrees_dir, d))
            ]
            if entries:
                # IMP-23: session-aware matching for parallel workflows
                session_id = data.get("session_id", "")
                matched_entry = None
                match_resolution = "fallback_gitdir"

                if session_id and len(session_id) >= 8:
                    prefix = session_id[:8]
                    for entry in entries:
                        if prefix in entry:
                            matched_entry = entry
                            match_resolution = "fallback_gitdir_session_match"
                            break

                if not matched_entry:
                    # Fallback: most recent by mtime
                    entries.sort(
                        key=lambda d: os.path.getmtime(os.path.join(worktrees_dir, d)),
                        reverse=True
                    )
                    matched_entry = entries[0]

                gitdir_file = os.path.join(worktrees_dir, matched_entry, "gitdir")
                if os.path.isfile(gitdir_file):
                    with open(gitdir_file) as f:
                        gitdir_content = f.read().strip()
                    candidate = gitdir_content.rsplit("/.git", 1)[0]
                    if os.path.isdir(candidate):
                        worktree_path = candidate
                        resolution = match_resolution
        except Exception as e:
            print(f"{CALLER}: worktree fallback scan failed: {e}", file=sys.stderr)

# Strategy 3: git worktree list --porcelain
if not worktree_path:
    try:
        result = subprocess.run(
            ["git", "worktree", "list", "--porcelain"],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0:
            worktrees = []
            for line in result.stdout.splitlines():
                if line.startswith("worktree "):
                    path = line[len("worktree "):]
                    if path != os.getcwd():
                        worktrees.append(path)
            if worktrees:
                candidate = worktrees[-1]
                if os.path.isdir(candidate):
                    worktree_path = candidate
                    resolution = "fallback_git_worktree_list"
    except Exception:
        pass

# Final validation — defense-in-depth
if worktree_path:
    wp = str(worktree_path).strip()
    if not wp.startswith("/") or " " in wp or "{" in wp or "}" in wp or not os.path.isdir(wp):
        print(f"{CALLER}: final validation failed for worktree_path: {worktree_path!r}", file=sys.stderr)
        worktree_path = None
        resolution = None

# Output — JSON if found, nothing if not
if worktree_path:
    print(json.dumps({"worktree_path": worktree_path, "resolution": resolution}))
