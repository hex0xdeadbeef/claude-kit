#!/bin/bash
# Hook: SubagentStop (matcher: plan-reviewer|code-reviewer)
# Purpose: Write marker about review agent completion
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
export _HOOK_INPUT="$INPUT"

python3 << 'PYTHON_EOF'
import json, sys, re, os
from datetime import datetime, timezone

try:
    data = json.loads(os.environ.get("_HOOK_INPUT", "{}"))
except Exception:
    data = {}

agent_type = data.get("agent_type", data.get("agent_name", "unknown"))
session_id = data.get("session_id", "")
timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

# Extract verdict from agent's final response (last_assistant_message per SubagentStop contract)
output = data.get("last_assistant_message", "")
verdict = "UNKNOWN"
if output:
    match = re.search(
        r'(?i)verdict:\s*(APPROVED_WITH_COMMENTS|APPROVED|CHANGES_REQUESTED|NEEDS_CHANGES|REJECTED)',
        str(output)
    )
    if match:
        verdict = match.group(1).upper()

marker = {
    "agent": agent_type,
    "completed_at": timestamp,
    "session_id": session_id,
    "verdict": verdict
}

completions_file = ".claude/workflow-state/review-completions.jsonl"
try:
    with open(completions_file, "a") as f:
        f.write(json.dumps(marker) + "\n")
except Exception as e:
    print(f"ERROR: Failed to write review marker: {e}", file=sys.stderr)
    sys.exit(2)
PYTHON_EOF
