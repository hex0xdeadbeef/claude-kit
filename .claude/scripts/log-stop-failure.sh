#!/bin/bash
# Hook: StopFailure (no matcher — fires on all API errors)
# Purpose: Log API errors (rate limits, auth failures, network) to session-analytics.jsonl
# Non-blocking: exit 0 always (analytics must not block error recovery)
#
# Input JSON fields (from stdin):
#   - session_id: current session identifier
#   - error_type: type of failure (rate_limit, auth, network, etc.)
#   - error_message: human-readable error description
#   - model: model that was being used when failure occurred
#
# Output: one JSONL line appended to .claude/workflow-state/session-analytics.jsonl
#   with type="stop_failure" to distinguish from SessionEnd entries

set -euo pipefail

# Drain stdin (hook input JSON)
INPUT=$(cat)
export _HOOK_INPUT="$INPUT"

command -v python3 >/dev/null 2>&1 || exit 0

python3 << 'PYTHON_EOF'
import json, sys, os
from datetime import datetime, timezone

STATE_DIR = ".claude/workflow-state"
ANALYTICS_FILE = os.path.join(STATE_DIR, "session-analytics.jsonl")

# Ensure state dir exists
os.makedirs(STATE_DIR, exist_ok=True)

# Parse hook input from env var
input_data = os.environ.get("_HOOK_INPUT", "{}")
try:
    hook_input = json.loads(input_data)
except Exception:
    print("log-stop-failure: failed to parse hook input JSON", file=sys.stderr)
    hook_input = {}

# Build analytics entry
entry = {
    "type": "stop_failure",
    "session_id": hook_input.get("session_id", "unknown"),
    "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "error_type": hook_input.get("error_type", "unknown"),
    "error_message": hook_input.get("error_message", ""),
    "model": hook_input.get("model", "unknown"),
}

# Append to analytics file
try:
    with open(ANALYTICS_FILE, "a") as f:
        f.write(json.dumps(entry) + "\n")
except Exception as e:
    print(f"log-stop-failure: failed to write analytics: {e}", file=sys.stderr)
PYTHON_EOF
exit 0
