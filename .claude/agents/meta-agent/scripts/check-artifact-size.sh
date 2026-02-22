#!/usr/bin/env bash
# check-artifact-size.sh — PreToolUse hook (Write/Edit)
# Deterministic SIZE_GATE: blocks writes exceeding critical thresholds.
#
# Hook contract:
#   stdin: JSON {"tool_name":"Write","tool_input":{"file_path":"...","content":"..."}}
#   stdout: JSON {"decision":"block","reason":"..."} or {"decision":"approve"}
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
  echo '{"decision":"approve"}'
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
    echo '{"decision":"approve"}'
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
  echo '{"decision":"approve"}'
  exit 0
fi

# Block on critical
if (( LINE_COUNT > CRITICAL )); then
  echo "{\"decision\":\"block\",\"reason\":\"SIZE_GATE: ${TYPE} artifact is ${LINE_COUNT} lines (critical threshold: ${CRITICAL}). Split via progressive_offloading before writing. SEE: deps/artifact-quality.md#progressive_offloading\"}"
  exit 0
fi

# Warn on warning threshold (approve but inform)
if (( LINE_COUNT > WARNING )); then
  echo "{\"decision\":\"approve\",\"reason\":\"SIZE_GATE warning: ${TYPE} artifact is ${LINE_COUNT} lines (warning threshold: ${WARNING}). Consider splitting.\"}"
  exit 0
fi

echo '{"decision":"approve"}'
