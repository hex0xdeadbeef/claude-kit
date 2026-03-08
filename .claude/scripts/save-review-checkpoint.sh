#!/bin/bash
# Hook: SubagentStop (matcher: plan-reviewer|code-reviewer)
# Purpose: Write completion marker for review agent
# Blocking: exit 2 if write fails (blocks agent completion)

set -euo pipefail

command -v python3 >/dev/null 2>&1 || {
  echo "ERROR: python3 required for save-review-checkpoint.sh" >&2
  exit 2
}

STATE_DIR=".claude/workflow-state"
mkdir -p "$STATE_DIR"

# Read stdin JSON, parse once, write JSONL marker
INPUT=$(cat)

python3 << PYTHON_EOF
import json, sys
from datetime import datetime, timezone

try:
    data = json.loads('''$INPUT''')
except Exception:
    data = {}

agent_type = data.get("agent_type", data.get("agent_name", "unknown"))
session_id = data.get("session_id", "")
timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

marker = {
    "agent": agent_type,
    "completed_at": timestamp,
    "session_id": session_id
}

completions_file = "$STATE_DIR/review-completions.jsonl"
try:
    with open(completions_file, "a") as f:
        f.write(json.dumps(marker) + "\n")
except Exception as e:
    print(f"ERROR: Failed to write review marker: {e}", file=sys.stderr)
    sys.exit(2)
PYTHON_EOF
