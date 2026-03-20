#!/bin/bash
# Hook: SessionEnd (no matcher — fires on all reasons)
# Purpose: Log session analytics to workflow-state/session-analytics.jsonl
# Non-blocking: exit 0 always (SessionEnd cannot block termination by contract)
# All sections use try-except or || exit 0 to ensure graceful degradation
#
# Metrics collected:
#   - From stdin JSON: session_id, reason
#   - From transcript JSONL: duration, message count, user prompts, tool calls breakdown, errors
#   - From workflow state: checkpoint (feature, phase, complexity, route)
#
# Output: one JSONL line appended to .claude/workflow-state/session-analytics.jsonl
# Privacy: analytics are gitignored (in .claude/workflow-state/). Review before sharing.

set -euo pipefail

# Drain stdin (hook input JSON) — stdin is consumed here, not available to python
INPUT=$(cat)
# Pass to python via env var (proven pattern from protect-files.sh DENY_REASON)
export _HOOK_INPUT="$INPUT"

command -v python3 >/dev/null 2>&1 || exit 0

python3 << 'PYTHON_EOF'
import json, sys, os, glob
from datetime import datetime, timezone

STATE_DIR = ".claude/workflow-state"
ANALYTICS_FILE = os.path.join(STATE_DIR, "session-analytics.jsonl")

# Ensure state dir exists
os.makedirs(STATE_DIR, exist_ok=True)

# 1. Parse hook input from env var (stdin consumed by bash, passed via _HOOK_INPUT)
input_data = os.environ.get("_HOOK_INPUT", "{}")
try:
    hook_input = json.loads(input_data)
except Exception:
    print("session-analytics: failed to parse hook input JSON", file=sys.stderr)
    hook_input = {}

session_id = hook_input.get("session_id", "unknown")
reason = hook_input.get("reason", "unknown")
transcript_path = hook_input.get("transcript_path", "")

# 2. Parse transcript for metrics (all optional — graceful degradation)
duration_seconds = 0
message_count = 0
user_prompts = 0
tool_calls = 0
tool_breakdown = {}
errors = 0
first_ts = None
last_ts = None

if transcript_path and os.path.isfile(transcript_path):
    try:
        with open(transcript_path) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                message_count += 1
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    continue

                # Timestamps
                ts = entry.get("timestamp")
                if ts:
                    if first_ts is None:
                        first_ts = ts
                    last_ts = ts

                # User prompts
                if entry.get("role") == "user" or entry.get("type") == "human":
                    user_prompts += 1

                # Tool calls
                if entry.get("type") == "tool_use":
                    tool_calls += 1
                    tool_name = entry.get("name", entry.get("tool_name", "unknown"))
                    tool_breakdown[tool_name] = tool_breakdown.get(tool_name, 0) + 1

                # Errors
                if entry.get("is_error") or entry.get("type") == "error":
                    errors += 1
    except Exception as e:
        print(f"session-analytics: transcript parse error: {e}", file=sys.stderr)
else:
    if transcript_path:
        print(f"session-analytics: transcript not found: {transcript_path}", file=sys.stderr)

# Calculate duration — stdlib only (datetime.fromisoformat, no dateutil)
if first_ts and last_ts:
    try:
        dt_start = datetime.fromisoformat(first_ts.replace("Z", "+00:00"))
        dt_end = datetime.fromisoformat(last_ts.replace("Z", "+00:00"))
        duration_seconds = int((dt_end - dt_start).total_seconds())
    except Exception as e:
        print(f"session-analytics: timestamp parse failed: {e} (first={first_ts}, last={last_ts})", file=sys.stderr)

# 3. Read checkpoint state (optional — sort by mtime for chronological order)
checkpoint = None
try:
    checkpoint_files = glob.glob(os.path.join(STATE_DIR, "*-checkpoint.yaml"))
    if checkpoint_files:
        latest = max(checkpoint_files, key=os.path.getmtime)
        feature = os.path.basename(latest).replace("-checkpoint.yaml", "")
        cp_data = {}
        with open(latest) as f:
            for line_raw in f:
                stripped = line_raw.strip()
                if ":" in stripped and not stripped.startswith("-") and not stripped.startswith("#"):
                    key, _, val = stripped.partition(":")
                    key = key.strip()
                    val = val.strip().strip('"').strip("'")
                    if key in ("phase_completed", "phase_name", "complexity", "route"):
                        cp_data[key] = val
        cp_data["feature"] = feature
        checkpoint = cp_data
except Exception as e:
    print(f"session-analytics: checkpoint read error: {e}", file=sys.stderr)

# 4. Exploration metrics (derived from tool_breakdown)
exploration_reads = sum(tool_breakdown.get(t, 0) for t in ("Read", "Grep", "Glob"))
action_writes = sum(tool_breakdown.get(t, 0) for t in ("Write", "Edit"))
read_write_ratio = round(exploration_reads / max(action_writes, 1), 1)
exploration_metrics = {
    "exploration_reads": exploration_reads,
    "action_writes": action_writes,
    "read_write_ratio": read_write_ratio,
    "exploration_loop_signal": read_write_ratio > 10,
}

# 5. Build analytics entry (session_id + timestamp always present)
entry = {
    "session_id": session_id,
    "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "reason": reason,
    "duration_seconds": duration_seconds,
    "message_count": message_count,
    "user_prompts": user_prompts,
    "tool_calls": tool_calls,
    "tool_breakdown": tool_breakdown,
    "exploration_metrics": exploration_metrics,
    "errors": errors,
    "checkpoint": checkpoint,
}

# 5. Append to analytics file (ALWAYS write, even with partial data)
try:
    with open(ANALYTICS_FILE, "a") as f:
        f.write(json.dumps(entry) + "\n")
except Exception as e:
    print(f"session-analytics: failed to write analytics: {e}", file=sys.stderr)
PYTHON_EOF
exit 0
