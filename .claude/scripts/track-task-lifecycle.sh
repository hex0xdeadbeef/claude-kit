#!/bin/bash
# Hook: SubagentStart (matcher: code-researcher)
# Purpose: Log code-researcher invocations for pipeline metrics
# Non-blocking: always exit 0 (logging only)
#
# Output: .claude/workflow-state/task-events.jsonl
# Fields: timestamp, event, agent_type, agent_id, session_id

set -uo pipefail

STATE_DIR=".claude/workflow-state"
mkdir -p "$STATE_DIR" 2>/dev/null || true

INPUT=$(cat)
export _HOOK_INPUT="$INPUT"

python3 << 'PYTHON_EOF' 2>/dev/null || true
import json, os
from datetime import datetime, timezone

STATE_DIR = ".claude/workflow-state"
EVENTS_FILE = os.path.join(STATE_DIR, "task-events.jsonl")

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

with open(EVENTS_FILE, "a") as f:
    f.write(json.dumps(entry) + "\n")

# IMP-01: Agent-ID Registry
REGISTRY_FILE = os.path.join(STATE_DIR, "agent-id-registry.jsonl")
REVIEW_AGENTS = {"plan-reviewer", "code-reviewer"}
if entry["agent_type"] in REVIEW_AGENTS and entry["agent_id"]:
    try:
        with open(REGISTRY_FILE, "a") as f:
            f.write(json.dumps({
                "agent_id": entry["agent_id"],
                "agent_type": entry["agent_type"],
                "session_id": entry["session_id"],
                "registered_at": entry["timestamp"],
            }) + "\n")
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
    with open(DEBUG_FILE, "a") as f:
        f.write(json.dumps(debug_entry) + "\n")
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
        with open(os.path.join(STATE_DIR, "anomalies.jsonl"), "a") as f:
            f.write(json.dumps(anomaly) + "\n")
    except Exception:
        pass  # NON_CRITICAL — diagnostic only


PYTHON_EOF

exit 0
