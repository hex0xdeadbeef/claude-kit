#!/bin/bash
# Hook: WorktreeCreate (no matcher — fires on all worktree creations)
# Purpose: Prepare worktree environment for code-reviewer (env vars, deps, memory pre-seed, analytics)
# Non-blocking: ALWAYS exit 0 (never block worktree creation)
# Performance: go mod download may take up to 30s (timeout enforced in Python subprocess)
#
# Stdin JSON (WorktreeCreate event): structure not fully documented in CHANGELOG v2.1.50.
# Expected fields (best-guess from worktree field in v2.1.69 status-line hooks):
#   worktree_path, worktree_name, worktree_branch, original_repo_dir
# On parse failure: raw stdin is logged to worktree-events-debug.jsonl for contract discovery.
#
# Worktree path resolution (IMP-02, 2026-03-30):
#   WorktreeCreate payload does NOT contain worktree_path.
#   Fallback chain: payload fields → .git/worktrees/ scan → git worktree list --porcelain

set -euo pipefail

# Drain stdin — hook contract sends JSON on stdin
INPUT=$(cat)

# Graceful degradation: no python3 → skip
command -v python3 >/dev/null 2>&1 || exit 0

# Pass stdin to python via env var (proven pattern from session-analytics.sh)
export _HOOK_INPUT="$INPUT"

(python3 << 'PYTHON_EOF' || true)
import json, os, shutil, subprocess, sys
from datetime import datetime, timezone

STATE_DIR = ".claude/workflow-state"
EVENTS_FILE = os.path.join(STATE_DIR, "worktree-events.jsonl")
DEBUG_FILE = os.path.join(STATE_DIR, "worktree-events-debug.jsonl")

# Ensure state dir exists
os.makedirs(STATE_DIR, exist_ok=True)

# 1. Parse hook input
input_data = os.environ.get("_HOOK_INPUT", "{}")
try:
    hook_input = json.loads(input_data)
except Exception:
    # Log raw input for contract discovery
    try:
        with open(DEBUG_FILE, "a") as f:
            f.write(json.dumps({
                "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                "error": "JSON parse failure",
                "raw_input": input_data[:2000],
            }) + "\n")
    except Exception:
        pass
    sys.exit(0)

# 2. Extract worktree info (field names are best-guess — log on missing for discovery)
# Strategy 1: Try multiple possible field name patterns from payload
worktree_path = (
    hook_input.get("worktree_path")
    or hook_input.get("worktreePath")
    or hook_input.get("path")
    or (hook_input.get("worktree", {}) or {}).get("path")
)
worktree_name = (
    hook_input.get("worktree_name")
    or hook_input.get("worktreeName")
    or hook_input.get("name")
    or (hook_input.get("worktree", {}) or {}).get("name")
)
worktree_branch = (
    hook_input.get("worktree_branch")
    or hook_input.get("worktreeBranch")
    or hook_input.get("branch")
    or (hook_input.get("worktree", {}) or {}).get("branch")
)

worktree_resolution = "payload" if worktree_path else None

# Guard: reject non-absolute paths and paths containing JSON/stdout contamination
# Claude Code parses WorktreeCreate hook stdout as worktree metadata, so ANY stdout
# (JSON or plain text) gets captured as worktreePath. This guard catches all such cases.
if worktree_path:
    wp = str(worktree_path).strip()
    if not wp.startswith("/") or " " in wp or "{" in wp or "}" in wp:
        print(f"prepare-worktree: rejecting invalid worktree_path: {worktree_path!r}", file=sys.stderr)
        worktree_path = None
        worktree_resolution = None

# --- IMP-02: Fallback strategies when worktree_path not in payload ---

# Strategy 2: Scan .git/worktrees/ for most recent worktree
if not worktree_path:
    worktrees_dir = os.path.join(".git", "worktrees")
    if os.path.isdir(worktrees_dir):
        try:
            entries = [
                d for d in os.listdir(worktrees_dir)
                if os.path.isdir(os.path.join(worktrees_dir, d))
            ]
            if entries:
                # Sort by modification time, most recent first
                entries.sort(
                    key=lambda d: os.path.getmtime(os.path.join(worktrees_dir, d)),
                    reverse=True
                )
                # Read gitdir file to find worktree path
                gitdir_file = os.path.join(worktrees_dir, entries[0], "gitdir")
                if os.path.isfile(gitdir_file):
                    with open(gitdir_file) as f:
                        gitdir_content = f.read().strip()
                    # gitdir contains path to worktree/.git — extract parent
                    candidate = gitdir_content.rsplit("/.git", 1)[0]
                    if os.path.isdir(candidate):
                        worktree_path = candidate
                        worktree_resolution = "fallback_gitdir"
        except Exception as e:
            print(f"prepare-worktree: worktree fallback scan failed: {e}", file=sys.stderr)

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
                    # Skip the main worktree (cwd)
                    if path != os.getcwd():
                        worktrees.append(path)
            if worktrees:
                # Take the last one (most recently added)
                candidate = worktrees[-1]
                if os.path.isdir(candidate):
                    worktree_path = candidate
                    worktree_resolution = "fallback_git_worktree_list"
    except Exception:
        pass

# --- End IMP-02 ---

# ALWAYS log received keys for contract discovery (regardless of whether worktree_path found)
try:
    with open(DEBUG_FILE, "a") as f:
        f.write(json.dumps({
            "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "hook": "WorktreeCreate",
            "worktree_path_found": bool(worktree_path),
            "worktree_resolution": worktree_resolution,
            "received_keys": sorted(hook_input.keys()),
            "raw_input": input_data[:2000],
        }) + "\n")
except Exception:
    pass

if not worktree_path:
    sys.exit(0)

# Final validation: worktree_path must be absolute, contain no spaces, and exist as directory
# This is defense-in-depth against stdout contamination (e.g. "worktree prepared", "{}", etc.)
wp = str(worktree_path).strip()
if not wp.startswith("/") or " " in wp or "{" in wp or "}" in wp or not os.path.isdir(wp):
    print(f"prepare-worktree: final validation failed for worktree_path: {worktree_path!r}", file=sys.stderr)
    sys.exit(0)

# 2b. Resolve original_repo_dir (main repo that worktree was created from)
# Strategy 1: from hook payload
original_repo_dir = (
    hook_input.get("original_repo_dir")
    or hook_input.get("originalRepoDir")
    or hook_input.get("cwd")
    or (hook_input.get("worktree", {}) or {}).get("original_repo_dir")
)
# Strategy 2: cwd — hook runs in the main repo directory
if not original_repo_dir:
    original_repo_dir = os.getcwd()

# 3. Prepare worktree environment
setup_actions = []

# 3a. Copy .env.example → .env (if template exists and .env missing)
try:
    env_example = os.path.join(worktree_path, ".env.example")
    env_target = os.path.join(worktree_path, ".env")
    if os.path.isfile(env_example) and not os.path.isfile(env_target):
        shutil.copy2(env_example, env_target)
        setup_actions.append("env_copied")
except Exception as e:
    print(f"prepare-worktree: .env copy failed: {e}", file=sys.stderr)

# 3b. Language-specific dependency install
# Go: go mod download (if go.mod exists)
try:
    go_mod = os.path.join(worktree_path, "go.mod")
    if os.path.isfile(go_mod):
        result = subprocess.run(
            ["go", "mod", "download"],
            cwd=worktree_path,
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode == 0:
            setup_actions.append("go_mod_download")
        else:
            setup_actions.append(f"go_mod_download_failed:{result.returncode}")
            print(f"prepare-worktree: go mod download failed: {result.stderr[:200]}", file=sys.stderr)
except subprocess.TimeoutExpired:
    setup_actions.append("go_mod_download_timeout")
    print("prepare-worktree: go mod download timed out (30s)", file=sys.stderr)
except FileNotFoundError:
    # go binary not found — skip
    setup_actions.append("go_not_found")
except Exception as e:
    print(f"prepare-worktree: go mod download error: {e}", file=sys.stderr)

# 3c. Pre-seed agent memory into worktree (IMP-09)
# Copies .claude/agent-memory/ from main repo so the agent starts with accumulated memory.
# Paired with sync-agent-memory.sh (IMP-01/IMP-05) which copies memory BACK after agent completes.
try:
    agent_memory_src = os.path.join(original_repo_dir, ".claude", "agent-memory")
    agent_memory_dst = os.path.join(worktree_path, ".claude", "agent-memory")
    if os.path.isdir(agent_memory_src):
        import sys
        if sys.version_info >= (3, 8):
            shutil.copytree(agent_memory_src, agent_memory_dst, dirs_exist_ok=True)
        elif not os.path.exists(agent_memory_dst):
            shutil.copytree(agent_memory_src, agent_memory_dst)
        # Count files seeded for analytics
        seeded_count = sum(
            len(files) for _, _, files in os.walk(agent_memory_dst)
        )
        setup_actions.append(f"agent_memory_seeded:{seeded_count}")
    else:
        setup_actions.append("agent_memory_no_src")
except Exception as e:
    setup_actions.append("agent_memory_seed_failed")
    print(f"prepare-worktree: memory pre-seed failed: {e}", file=sys.stderr)

# Node: npm ci (if package-lock.json exists) — uncomment for Node projects
# try:
#     package_lock = os.path.join(worktree_path, "package-lock.json")
#     if os.path.isfile(package_lock):
#         subprocess.run(["npm", "ci"], cwd=worktree_path, capture_output=True, timeout=60)
#         setup_actions.append("npm_ci")
# except Exception:
#     pass

# Python: pip install (if requirements.txt exists) — uncomment for Python projects
# try:
#     requirements = os.path.join(worktree_path, "requirements.txt")
#     if os.path.isfile(requirements):
#         subprocess.run(["pip", "install", "-r", "requirements.txt"], cwd=worktree_path, capture_output=True, timeout=60)
#         setup_actions.append("pip_install")
# except Exception:
#     pass

# 4. Log worktree creation event (analytics)
try:
    event = {
        "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "action": "create",
        "worktree_name": worktree_name or "unknown",
        "worktree_path": worktree_path,
        "worktree_branch": worktree_branch or "unknown",
        "worktree_resolution": worktree_resolution,
        "setup_actions": setup_actions,
    }
    with open(EVENTS_FILE, "a") as f:
        f.write(json.dumps(event) + "\n")
except Exception as e:
    print(f"prepare-worktree: analytics write failed: {e}", file=sys.stderr)

PYTHON_EOF

# ALWAYS exit 0 — never block worktree creation
# CRITICAL: Do NOT output ANYTHING to stdout from WorktreeCreate hooks.
# Claude Code parses ALL WorktreeCreate hook stdout as worktree metadata:
#   - "{}" → worktreePath="{}" → creates "{}/.claude/agent-memory/" directory
#   - "worktree prepared" → worktreePath="worktree prepared" → creates "worktree prepared/.claude/agent-memory/"
# The ONLY safe option is silent exit (no stdout at all).
exit 0
