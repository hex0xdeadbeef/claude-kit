#!/usr/bin/env bash
# log-tool-failure.sh
# Hook: PostToolUseFailure (matcher: Bash)
# Purpose: Append one JSONL line per failed Bash tool invocation for cross-session
# failure pattern detection. Non-blocking: always exits 0.
# Lifecycle: analytics-preserved with CLAUDE_TOOL_FAILURES_MAX_LINES head-trim cap
# (default 1000); see .claude/skills/workflow-protocols/state-layer.md.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORKFLOW_STATE_DIR="${CLAUDE_WORKFLOW_STATE_DIR:-${CLAUDE_PROJECT_DIR:-${REPO_ROOT}}/.claude/workflow-state}"
mkdir -p "${WORKFLOW_STATE_DIR}" 2>/dev/null || true
JSONL="${WORKFLOW_STATE_DIR}/tool-failures.jsonl"
MAX_LINES="${CLAUDE_TOOL_FAILURES_MAX_LINES:-1000}"

# Read stdin (hook JSON); never crash on malformed input
HOOK_INPUT="$(cat 2>/dev/null || echo '{}')"

# Require jq; degrade silently if missing (analytics is best-effort)
if ! command -v jq >/dev/null 2>&1; then
  echo "[log-tool-failure] WARN: jq unavailable — analytics line skipped" >&2
  exit 0
fi

# Extract fields with safe defaults
tool_name="$(echo "${HOOK_INPUT}" | jq -r '.tool_name // "unknown"' 2>/dev/null || echo "unknown")"
cmd_excerpt="$(echo "${HOOK_INPUT}" | jq -r '(.tool_input.command // "") | .[0:200]' 2>/dev/null || echo "")"
output_tail="$(echo "${HOOK_INPUT}" | jq -r '(.tool_output // "") | .[(-200):]' 2>/dev/null || echo "")"
effort_level="$(echo "${HOOK_INPUT}" | jq -r '.effort.level // empty' 2>/dev/null || true)"
if [[ -z "${effort_level}" ]]; then effort_level="${CLAUDE_EFFORT:-unknown}"; fi
session_id="${CLAUDE_CODE_SESSION_ID:-unknown}"
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Build line via jq for safe quoting; on failure, write a fallback minimal record
line="$(jq -nc \
  --arg ts "${ts}" \
  --arg sid "${session_id}" \
  --arg tname "${tool_name}" \
  --arg cmd "${cmd_excerpt}" \
  --arg sig "${output_tail}" \
  --arg eff "${effort_level}" \
  '{ts:$ts, session_id:$sid, tool_name:$tname, command_excerpt:$cmd, exit_signature:$sig, effort_level:$eff}' \
  2>/dev/null || echo "")"
if [[ -z "${line}" ]]; then
  exit 0
fi

# Append + head-trim rotation with flock to defend against parallel-tool-failure races (R4)
{
  if command -v flock >/dev/null 2>&1; then
    exec 9>>"${JSONL}.lock"
    flock 9
  fi
  echo "${line}" >> "${JSONL}"
  cur_lines="$(wc -l < "${JSONL}" 2>/dev/null | tr -d ' ' || echo 0)"
  if [[ "${cur_lines}" -gt "${MAX_LINES}" ]]; then
    tail -n "${MAX_LINES}" "${JSONL}" > "${JSONL}.tmp" 2>/dev/null && mv "${JSONL}.tmp" "${JSONL}"
  fi
} 2>/dev/null

exit 0
