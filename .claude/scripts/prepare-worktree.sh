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
# Worktree path resolution (IMP-02 → IMP-11):
#   Delegated to resolve-worktree-path.py (shared utility).
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

# 2. Extract worktree info
# Name and branch from payload (used only for analytics, not by resolver)
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

# Resolve worktree path via shared utility (IMP-11)
# Handles: payload extraction, .git/worktrees/ scan, git worktree list, path validation
resolver = os.path.join(".claude", "scripts", "resolve-worktree-path.py")
worktree_path = None
worktree_resolution = None
try:
    env = os.environ.copy()
    env["_CALLER"] = "prepare-worktree"
    result = subprocess.run(
        ["python3", resolver],
        capture_output=True, text=True, timeout=10,
        env=env
    )
    if result.stderr:
        print(result.stderr.rstrip(), file=sys.stderr)
    if result.stdout.strip():
        resolved = json.loads(result.stdout.strip())
        worktree_path = resolved.get("worktree_path")
        worktree_resolution = resolved.get("resolution")
except Exception as e:
    print(f"prepare-worktree: resolver failed: {e}", file=sys.stderr)

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

# WorktreeCreate stdout protocol (history):
#   Pre-v2.1.84: Claude Code parsed stdout as worktree PATH (not JSON).
#                Empty/no stdout was required — any output became the path string,
#                e.g. "{}" → worktreePath="{}" → tried to create "{}/.claude/" directory.
#   v2.1.84+:    Claude Code parses stdout as JSON. Silent exit = error:
#                "WorktreeCreate hook failed: no successful output".
#                echo "{}" = success signal with no path override (uses default path).
#                echo '{"worktreePath":"/abs/path"}' = success with explicit path override.
#
# REQUIRED: output valid JSON before exit 0.
echo "{}"   # WorktreeCreate protocol: stdout JSON required for success signal.
            # Empty object = use default worktree path, no metadata override.
            # Claude Code ~v2.1.84+: silent exit = "no successful output" error.
exit 0
