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
PYTHON_EOF

exit 0
