#!/usr/bin/env bash
# check-artifact-size.sh — PreToolUse hook (Write/Edit)
# Deterministic SIZE_GATE: blocks writes exceeding critical thresholds.
#
# Hook contract (PreToolUse — IMP-10):
#   stdin: JSON {"tool_name":"Write","tool_input":{"file_path":"...","content":"..."}}
#   stdout (deny): JSON {"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"..."}}
#   stdout (allow): no output (empty stdout)
#   stdout (warn): JSON {"additionalContext":"..."} — informational, does not block
#   exit 0 always (non-zero = hook ignored by Claude Code)
#
# Thresholds (from blocking-gates.md#SIZE_GATE):
#   command: 300/500/800 [recommended/warning/critical]
#   skill:   300/600/700
#   rule:    100/200/400
#   agent:   500/800/1200 (meta-agent deps)

set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty')

# Only check .claude/ artifact files
if [[ ! "$FILE_PATH" =~ \.claude/ ]]; then
  exit 0
fi

# Count lines
if [[ -n "$CONTENT" ]]; then
  LINE_COUNT=$(echo "$CONTENT" | wc -l)
else
  # Edit tool — check resulting file size (approximate: current + delta)
  if [[ -f "$FILE_PATH" ]]; then
    LINE_COUNT=$(wc -l < "$FILE_PATH")
  else
    exit 0
  fi
fi

# Detect artifact type from path
TYPE=""
if [[ "$FILE_PATH" =~ /commands/ ]]; then
  TYPE="command"
  CRITICAL=800
  WARNING=500
elif [[ "$FILE_PATH" =~ /skills/ ]]; then
  TYPE="skill"
  CRITICAL=700
  WARNING=600
elif [[ "$FILE_PATH" =~ /rules/ ]]; then
  TYPE="rule"
  CRITICAL=400
  WARNING=200
elif [[ "$FILE_PATH" =~ /agents/ ]] && [[ "$FILE_PATH" =~ /deps/ ]]; then
  TYPE="agent_dep"
  CRITICAL=1200
  WARNING=800
elif [[ "$FILE_PATH" =~ /agents/ ]]; then
  TYPE="agent"
  CRITICAL=1200
  WARNING=800
else
  exit 0
fi

# Block on critical — IMP-10: use PreToolUse hookSpecificOutput envelope (not Stop format)
if (( LINE_COUNT > CRITICAL )); then
  DENY_REASON="SIZE_GATE: ${TYPE} artifact is ${LINE_COUNT} lines (critical threshold: ${CRITICAL}). Split via progressive_offloading before writing."
  DENY_REASON="$DENY_REASON" python3 -c "
import json, os
output = {
    'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'permissionDecision': 'deny',
        'permissionDecisionReason': os.environ.get('DENY_REASON', 'Artifact too large')
    }
}
print(json.dumps(output))
"
  exit 0
fi

# Warn on warning threshold (allow but inform via additionalContext)
if (( LINE_COUNT > WARNING )); then
  WARN_MSG="SIZE_GATE warning: ${TYPE} artifact is ${LINE_COUNT} lines (warning threshold: ${WARNING}). Consider splitting."
  WARN_MSG="$WARN_MSG" python3 -c "
import json, os
print(json.dumps({'additionalContext': os.environ.get('WARN_MSG', '')}))
"
  exit 0
fi

# Below thresholds — allow silently (no stdout for PreToolUse allow)
exit 0
