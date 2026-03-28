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
PYTHON_EOF

exit 0
