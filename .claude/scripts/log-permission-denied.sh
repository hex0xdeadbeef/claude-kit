#!/bin/bash
# Hook: PermissionDenied (matcher: "" — fires on classifier denials for any tool)
# Purpose:
#   1. Log classifier-denied tool calls to hook-log.txt for diagnostic visibility
#   2. During Phase 3 (Implementation), emit retry:true so the model may try alternatives
#
# Platform: Claude Code v2.1.89+ (hookSpecificOutput.retry on PermissionDenied).
# Firing: auto-mode classifier denials only — NOT deny-rule matches, NOT PreToolUse blocks,
#         NOT manual denial dialogs.
# Contract: ALWAYS exit 0. retry:true is a hint — the denial itself is not reversed.

set -euo pipefail

# Drain stdin — hook contract sends JSON
INPUT=$(cat)

# Graceful degradation
command -v python3 >/dev/null 2>&1 || exit 0

LOG_DIR=".claude/workflow-state"
mkdir -p "$LOG_DIR" 2>/dev/null || exit 0

# Pass INPUT via env var (heredoc consumes python's stdin — can't read from there)
export HOOK_INPUT="$INPUT"

python3 << 'PYTHON_EOF'
import json, os, glob
from datetime import datetime, timezone

STATE_DIR = ".claude/workflow-state"
LOG_FILE = os.path.join(STATE_DIR, "hook-log.txt")

# Parse payload
try:
    data = json.loads(os.environ.get("HOOK_INPUT", "") or "{}")
except Exception:
    data = {}

tool_name = data.get("tool_name", "?")
reason = (data.get("reason") or "?").replace("\n", " ")
tool_input = data.get("tool_input") or {}
if tool_name == "Bash":
    short_input = (tool_input.get("command") or "")[:100]
else:
    try:
        short_input = json.dumps(tool_input)[:100]
    except Exception:
        short_input = "?"

# Log (best-effort — never fail the hook on I/O)
try:
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with open(LOG_FILE, "a") as f:
        f.write(f"[{ts}] permission-denied: {tool_name} | {short_input} | reason: {reason}\n")
except Exception:
    pass

# Decide whether to emit retry:true
# Condition: active workflow AND phase_completed == 2 (Phase 3 Implementation in progress)
emit_retry = False
try:
    checkpoints = sorted(glob.glob(os.path.join(STATE_DIR, "*-checkpoint.yaml")))
    if checkpoints:
        with open(checkpoints[-1]) as f:
            for raw_line in f:
                s = raw_line.strip()
                if s.startswith("phase_completed:"):
                    val = s.split(":", 1)[1].strip().strip('"').strip("'")
                    try:
                        if int(float(val)) == 2:
                            emit_retry = True
                    except (ValueError, TypeError):
                        pass
                    break
except Exception:
    pass

if emit_retry:
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PermissionDenied",
            "retry": True,
        }
    }))

PYTHON_EOF

exit 0
