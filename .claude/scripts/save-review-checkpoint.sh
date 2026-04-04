#!/bin/bash
# Hook: SubagentStop (matcher: plan-reviewer|code-reviewer)
# Purpose: Write marker about review agent completion + sync agent memory from worktree
# Blocking: exit 2 only if BOTH primary and fallback writes fail
# IMP-06: defensive fallback to /tmp when primary write fails — logging should not block agent
# IMP-H: verdict protection — blocks agent stop once if no verdict found (review agents only)
#
# Worktree path resolution (IMP-04 → IMP-11):
#   Delegated to resolve-worktree-path.py (shared utility).
#   Fallback chain: payload fields → .git/worktrees/ scan → git worktree list --porcelain
#
# Agent memory sync (IMP-01 + IMP-05):
#   After resolving worktree_path, delegates to sync-agent-memory.sh (standalone utility).
#   Runs BEFORE worktree cleanup (blocking hook).
#   Memory sync failure is NON_CRITICAL — logged but does not block.
#
# Verdict extraction (IMP-01, 2026-03-30):
#   SubagentStop payload MAY contain last_assistant_message (added in v2.1.47).
#   Transcript fallback provides more reliable extraction regardless.
#   Strategy: try payload first → fallback to transcript_path JSONL → regex for VERDICT:.

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

# --- IMP-H: Verdict protection — block agent stop if no verdict found ---
# Review agents (plan-reviewer, code-reviewer) MUST output a verdict.
# If verdict is UNKNOWN: block stop once to give agent another chance.
# Track attempts via marker file to avoid infinite blocking.
REVIEW_AGENTS = {"plan-reviewer", "code-reviewer"}
agent_id = data.get("agent_id", "")

if verdict == "UNKNOWN" and agent_type in REVIEW_AGENTS and agent_id:
    block_marker = os.path.join(STATE_DIR, f".verdict-block-{agent_id}")
    if not os.path.exists(block_marker):
        # First attempt — block stop, give agent one more chance
        # Guard: only block if marker write succeeds (prevents infinite loop)
        marker_written = False
        try:
            with open(block_marker, "w") as f:
                f.write(timestamp)
            marker_written = True
        except Exception:
            print(f"save-review-checkpoint: block marker write failed, skipping block", file=sys.stderr)
        if marker_written:
            print(json.dumps({
                "decision": "block",
                "reason": (
                    "No verdict found in output. You MUST output your review verdict now. "
                    "Output VERDICT: {APPROVED|NEEDS_CHANGES|CHANGES_REQUESTED|REJECTED} "
                    "followed by a brief handoff section. Skip memory save."
                )
            }))
            sys.exit(0)
    else:
        # Second attempt — allow stop, clean up marker
        try:
            os.remove(block_marker)
        except Exception:
            pass
        print(f"save-review-checkpoint: verdict still UNKNOWN after block, allowing stop", file=sys.stderr)
# --- End IMP-H ---

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

# --- IMP-04 → IMP-11: Resolve worktree_path via shared utility ---
# Agents known to run with isolation: worktree
WORKTREE_AGENTS = {"code-reviewer"}

worktree_path = None
worktree_resolution = None
if agent_type in WORKTREE_AGENTS:
    import subprocess
    resolver = os.path.join(".claude", "scripts", "resolve-worktree-path.py")
    try:
        env = os.environ.copy()
        env["_CALLER"] = "save-review-checkpoint"
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
        print(f"save-review-checkpoint: resolver failed: {e}", file=sys.stderr)

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

# --- IMP-06: Defensive fallback for marker write ---
# Primary write to review-completions.jsonl; on failure, fallback to /tmp.
# Logging failure should not block agent completion — only exit 2 if both fail.
completions_file = ".claude/workflow-state/review-completions.jsonl"
try:
    with open(completions_file, "a") as f:
        f.write(json.dumps(marker) + "\n")
except Exception as e:
    import tempfile
    fallback_file = os.path.join(tempfile.gettempdir(), "claude-review-completions-fallback.jsonl")
    try:
        with open(fallback_file, "a") as f:
            f.write(json.dumps(marker) + "\n")
        print(f"WARN: Primary write failed ({e}), wrote to fallback: {fallback_file}", file=sys.stderr)
    except Exception as e2:
        print(f"ERROR: Both primary and fallback write failed: {e} / {e2}", file=sys.stderr)
        sys.exit(2)
PYTHON_EOF
