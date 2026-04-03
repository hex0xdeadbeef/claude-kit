#!/bin/bash
# Hook: ConfigChange (matcher: "")
# Purpose: Audit log for configuration changes during session.
#          Blocks project_settings changes during active workflow.
# Non-blocking by default: exit 0. Exit 2 to block.
#
# Output: .claude/workflow-state/config-changes.jsonl

set -euo pipefail

STATE_DIR=".claude/workflow-state"
mkdir -p "$STATE_DIR" 2>/dev/null || true

INPUT=$(cat)
export _HOOK_INPUT="$INPUT"

python3 << 'PYTHON_EOF'
import json, os, sys
from datetime import datetime, timezone

STATE_DIR = ".claude/workflow-state"
LOG_FILE = os.path.join(STATE_DIR, "config-changes.jsonl")

try:
    data = json.loads(os.environ.get("_HOOK_INPUT", "{}"))
except Exception:
    data = {}

source = data.get("source", "unknown")
session_id = data.get("session_id", "")

blocked = False
reason = ""

checkpoint_files = [
    f for f in os.listdir(STATE_DIR)
    if f.endswith("-checkpoint.yaml")
] if os.path.isdir(STATE_DIR) else []

if source == "project_settings" and checkpoint_files:
    blocked = True
    reason = "settings.json change blocked: active workflow in progress (checkpoint: {})".format(
        checkpoint_files[0]
    )

entry = {
    "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "source": source,
    "session_id": session_id,
    "blocked": blocked,
    "reason": reason,
}

with open(LOG_FILE, "a") as f:
    f.write(json.dumps(entry) + "\n")

if blocked:
    print(reason, file=sys.stderr)
    sys.exit(2)
PYTHON_EOF

exit 0
