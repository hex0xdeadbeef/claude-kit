#!/bin/bash
# Hook: SubagentStop (matcher: plan-reviewer|code-reviewer)
# Purpose: Write marker about review agent completion + sync agent memory from worktree
# Blocking: exit 2 if write fails (blocks agent completion)
#
# Worktree path resolution (IMP-04):
#   1. Try SubagentStop payload fields (worktree_path, worktreePath, worktree.path)
#   2. Fallback: scan .git/worktrees/ for most recent worktree (code-reviewer only)
#   3. Log discovery data to worktree-events-debug.jsonl for contract refinement
#
# Agent memory sync (IMP-01 + IMP-05):
#   After resolving worktree_path, delegates to sync-agent-memory.sh (standalone utility).
#   Runs BEFORE worktree cleanup (blocking hook).
#   Memory sync failure is NON_CRITICAL — logged but does not block.
#
# Verdict extraction (IMP-01, 2026-03-30):
#   SubagentStop payload does NOT contain last_assistant_message.
#   Fallback: read transcript_path JSONL → find last assistant entry → regex for VERDICT:.

set -euo pipefail

command -v python3 >/dev/null 2>&1 || {
  echo "ERROR: python3 required for save-review-checkpoint.sh" >&2
  exit 2
}

STATE_DIR=".claude/workflow-state"
mkdir -p "$STATE_DIR"

# Read stdin JSON, parse once, write JSONL marker
INPUT=$(cat)
export _HOOK_INPUT="$INPUT"

python3 << 'PYTHON_EOF'
import json, sys, re, os
from datetime import datetime, timezone

STATE_DIR = ".claude/workflow-state"
DEBUG_FILE = os.path.join(STATE_DIR, "worktree-events-debug.jsonl")

try:
    data = json.loads(os.environ.get("_HOOK_INPUT", "{}"))
except Exception:
    data = {}

# IMP-07: agent_type fallback includes "name" (WorktreeCreate uses "name" field)
agent_type = (
    data.get("agent_type")
    or data.get("agent_name")
    or data.get("name")
    or "unknown"
)
session_id = data.get("session_id", "")
timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

# --- IMP-01: Extract verdict from agent's final response ---
# Strategy 1: Try last_assistant_message from payload (may not exist in current Claude Code versions)
output = data.get("last_assistant_message", "")

# Strategy 2: Read transcript_path JSONL — find last assistant message
# SubagentStop payload includes transcript_path but NOT last_assistant_message.
# The transcript is a JSONL file with the full agent conversation.
transcript_used = False
if not output:
    transcript_path = data.get("transcript_path", "")
    if transcript_path and os.path.isfile(transcript_path):
        try:
            with open(transcript_path) as f:
                lines = f.readlines()
            # Search in reverse for last assistant message
            for line in reversed(lines):
                try:
                    entry = json.loads(line.strip())
                    role = entry.get("role", "")
                    if role == "assistant":
                        content = entry.get("content", "")
                        if isinstance(content, list):
                            # Anthropic message format: [{type: "text", text: "..."}]
                            for block in content:
                                if isinstance(block, dict) and block.get("type") == "text":
                                    text = block.get("text", "")
                                    if text:
                                        output = text
                                        break
                        elif isinstance(content, str):
                            output = content
                        if output:
                            transcript_used = True
                            break
                except (json.JSONDecodeError, KeyError):
                    continue
        except Exception as e:
            print(f"save-review-checkpoint: transcript read failed: {e}", file=sys.stderr)

verdict = "UNKNOWN"
if output:
    match = re.search(
        r'(?i)verdict:\s*(APPROVED_WITH_COMMENTS|APPROVED|CHANGES_REQUESTED|NEEDS_CHANGES|REJECTED)',
        str(output)
    )
    if match:
        verdict = match.group(1).upper()

# --- End IMP-01 ---

# --- IMP-03: ALWAYS log SubagentStop payload for contract discovery ---
try:
    discovery = {
        "timestamp": timestamp,
        "hook": "SubagentStop",
        "agent_type": agent_type,
        "session_id": session_id,
        "received_keys": sorted(data.keys()),
        "verdict_found": verdict != "UNKNOWN",
        "verdict_source": "transcript" if transcript_used else ("payload" if data.get("last_assistant_message") else "none"),
        "transcript_path_present": bool(data.get("transcript_path")),
    }
    # Include raw payload fields (excluding last_assistant_message/transcript content — too large)
    payload_sample = {
        k: str(v)[:200] for k, v in data.items()
        if k not in ("last_assistant_message",)
    }
    discovery["payload_sample"] = payload_sample
    with open(DEBUG_FILE, "a") as f:
        f.write(json.dumps(discovery) + "\n")
except Exception:
    pass
# --- End IMP-03 ---

# --- IMP-04: Resolve worktree_path for worktree-isolated agents ---
# Agents known to run with isolation: worktree
WORKTREE_AGENTS = {"code-reviewer"}

# Strategy 1: Extract from SubagentStop payload (try multiple field name patterns)
worktree_path = (
    data.get("worktree_path")
    or data.get("worktreePath")
    or (data.get("worktree", {}) or {}).get("path")
)

worktree_resolution = "payload" if worktree_path else None

# Guard: reject non-path values from hook stdout contamination (e.g. "{}" from prepare-worktree.sh)
if worktree_path and (not str(worktree_path).startswith("/") or str(worktree_path).strip() in ("{}", "{", "}")):
    print(f"save-review-checkpoint: rejecting invalid worktree_path: {worktree_path!r}", file=sys.stderr)
    worktree_path = None
    worktree_resolution = None

# Strategy 2: Fallback — scan .git/worktrees/ for most recent worktree
if not worktree_path and agent_type in WORKTREE_AGENTS:
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
            print(f"save-review-checkpoint: worktree fallback scan failed: {e}", file=sys.stderr)

# Strategy 3: Fallback — try `git worktree list --porcelain` for most recent
if not worktree_path and agent_type in WORKTREE_AGENTS:
    try:
        import subprocess
        result = subprocess.run(
            ["git", "worktree", "list", "--porcelain"],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0:
            # Parse porcelain output: "worktree /path/to/worktree\n..."
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

# --- End IMP-04 ---

# --- IMP-01/IMP-05: Sync agent memory via standalone script ---
# Delegates to sync-agent-memory.sh (IMP-05: single-responsibility extraction).
# Memory sync is NON_CRITICAL — failure is logged but does not block.
memory_sync_result = None
memory_files_synced = []

if worktree_path and agent_type in WORKTREE_AGENTS:
    try:
        import subprocess
        # Resolve to absolute path — CWD should be main repo, but be defensive
        script_path = os.path.abspath(os.path.join(".claude", "scripts", "sync-agent-memory.sh"))
        result = subprocess.run(
            [script_path, agent_type, worktree_path],
            capture_output=True, text=True, timeout=30
        )
        # Parse structured JSON output from stdout
        try:
            sync_output = json.loads(result.stdout.strip())
            memory_sync_result = sync_output.get("result", "unknown")
            memory_files_synced = sync_output.get("files", [])
        except (json.JSONDecodeError, ValueError):
            memory_sync_result = f"parse_error: rc={result.returncode}"
        # Forward stderr for logging visibility
        if result.stderr:
            print(result.stderr.rstrip(), file=sys.stderr)
    except Exception as e:
        memory_sync_result = f"error: {e}"
        print(f"save-review-checkpoint: memory sync script failed: {e}", file=sys.stderr)

# Log memory sync result to discovery file
if agent_type in WORKTREE_AGENTS and worktree_path:
    try:
        sync_log = {
            "timestamp": timestamp,
            "hook": "SubagentStop",
            "event": "memory_sync",
            "agent_type": agent_type,
            "session_id": session_id,
            "worktree_path": worktree_path,
            "worktree_resolution": worktree_resolution,
            "memory_sync_result": memory_sync_result,
            "files_synced": memory_files_synced,
        }
        with open(DEBUG_FILE, "a") as f:
            f.write(json.dumps(sync_log) + "\n")
    except Exception:
        pass

# --- End IMP-01/IMP-05 ---

marker = {
    "agent": agent_type,
    "completed_at": timestamp,
    "session_id": session_id,
    "verdict": verdict,
}
# Include verdict source for debugging
if transcript_used:
    marker["verdict_source"] = "transcript"
# Include worktree_path and memory sync status in marker
if worktree_path:
    marker["worktree_path"] = worktree_path
    marker["worktree_resolution"] = worktree_resolution
if memory_sync_result:
    marker["memory_sync"] = memory_sync_result
    marker["memory_files_synced"] = memory_files_synced

completions_file = ".claude/workflow-state/review-completions.jsonl"
try:
    with open(completions_file, "a") as f:
        f.write(json.dumps(marker) + "\n")
except Exception as e:
    print(f"ERROR: Failed to write review marker: {e}", file=sys.stderr)
    sys.exit(2)
PYTHON_EOF
