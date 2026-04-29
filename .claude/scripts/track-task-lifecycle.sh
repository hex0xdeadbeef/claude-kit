#!/bin/bash
# Hook: SubagentStart (matcher: code-researcher|plan-reviewer|code-reviewer per consolidated entry, P5)
# Purpose: Log review/researcher agent invocations for pipeline metrics
# Non-blocking: always exit 0 (logging only)
#
# Output: ${CLAUDE_WORKFLOW_STATE_DIR:-.claude/workflow-state}/task-events.jsonl  (P5)
# Fields: timestamp, event, agent_type, agent_id, session_id

set -uo pipefail

# P5: honour CLAUDE_WORKFLOW_STATE_DIR for sandbox isolation (mirrors save-review-checkpoint.sh:43).
STATE_DIR="${CLAUDE_WORKFLOW_STATE_DIR:-.claude/workflow-state}"
mkdir -p "$STATE_DIR" 2>/dev/null || true

# P4: source shared JSONL flock helper. Fire-and-forget; CLAUDE_JSONL_APPEND_LOCK=on enables flock.
_SCRIPT_DIR_TT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${_SCRIPT_DIR_TT}/lib/jsonl-lock.sh"
export _JSONL_LOCK_LIB_DIR="${_SCRIPT_DIR_TT}/lib"

INPUT=$(cat)
export _HOOK_INPUT="$INPUT"

python3 << 'PYTHON_EOF' 2>/dev/null || true
import json, os, sys
from datetime import datetime, timezone

# P5: honour CLAUDE_WORKFLOW_STATE_DIR for sandbox isolation.
STATE_DIR = os.environ.get("CLAUDE_WORKFLOW_STATE_DIR", ".claude/workflow-state")
EVENTS_FILE = os.path.join(STATE_DIR, "task-events.jsonl")

# P4: import shared JSONL flock helper.
sys.path.insert(0, os.environ.get("_JSONL_LOCK_LIB_DIR", ".claude/scripts/lib"))
try:
    import jsonl_lock as _jl
except Exception:
    _jl = None

def _append_jsonl(path, obj):
    line = obj if isinstance(obj, str) else json.dumps(obj)
    if _jl is not None:
        _jl.jsonl_append_locked(path, line)
        return
    try:
        with open(path, "a") as f:
            f.write(line if line.endswith("\n") else line + "\n")
    except Exception:
        pass

try:
    data = json.loads(os.environ.get("_HOOK_INPUT", "{}"))
except Exception:
    data = {}

entry = {
    "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "event": data.get("hook_event_name", "SubagentStart"),
    "agent_type": data.get("agent_type", data.get("agent_name", "unknown")),
    "agent_id": data.get("agent_id", ""),
    "session_id": data.get("session_id", ""),
}

_append_jsonl(EVENTS_FILE, entry)

# IMP-01: Agent-ID Registry
REGISTRY_FILE = os.path.join(STATE_DIR, "agent-id-registry.jsonl")
REVIEW_AGENTS = {"plan-reviewer", "code-reviewer"}
if entry["agent_type"] in REVIEW_AGENTS and entry["agent_id"]:
    try:
        _append_jsonl(REGISTRY_FILE, {
            "agent_id": entry["agent_id"],
            "agent_type": entry["agent_type"],
            "session_id": entry["session_id"],
            "registered_at": entry["timestamp"],
        })
    except Exception:
        pass  # NON_CRITICAL


# IMP-18: Debug logging for contract discovery (mirrors IMP-03 pattern in save-review-checkpoint.sh)
DEBUG_FILE = os.path.join(STATE_DIR, "worktree-events-debug.jsonl")
try:
    debug_entry = {
        "timestamp": entry["timestamp"],
        "hook": "SubagentStart",
        "agent_type": entry["agent_type"],
        "agent_id": entry["agent_id"],
        "session_id": entry["session_id"],
        "received_keys": sorted(data.keys()),
        "payload_sample": {k: str(v)[:200] for k, v in data.items()
                          if k not in ("last_assistant_message",)},
    }
    _append_jsonl(DEBUG_FILE, debug_entry)
except Exception:
    pass


# IMP-5: Positive probe — log when SubagentStart fires for code-reviewer with
# correctly-resolved agent_type. Pairs with P2-2 negative probe in
# save-review-checkpoint.sh (MISSING_SUBAGENT_START).
# Decision gate: if anomalies.jsonl accumulates SUBAGENT_START_FIRED entries for
# code-reviewer across multiple /workflow runs AND zero MISSING_SUBAGENT_START,
# the P0-2 worktree heuristic can be removed. Until then, P0-2 stays.
if entry["agent_type"] == "code-reviewer" and entry["agent_id"]:
    try:
        anomaly = {
            "timestamp": entry["timestamp"],
            "type": "SUBAGENT_START_FIRED",
            "agent_id": entry["agent_id"],
            "agent_type": "code-reviewer",
            "session_id": entry["session_id"],
            "message": "SubagentStart fired for code-reviewer — P0-2 worktree heuristic may be obsolete",
        }
        _append_jsonl(os.path.join(STATE_DIR, "anomalies.jsonl"), anomaly)
    except Exception:
        pass  # NON_CRITICAL — diagnostic only


PYTHON_EOF

exit 0
