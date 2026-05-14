#!/usr/bin/env bash
# Part 2 / AD-4: tool-failures.jsonl head-trim rotation at CLAUDE_TOOL_FAILURES_MAX_LINES cap.
# Pre-fills the file with N+1 lines, fires one event, asserts resulting file has exactly N lines.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SCRIPT="${REPO_ROOT}/.claude/scripts/log-tool-failure.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

export CLAUDE_WORKFLOW_STATE_DIR="${TMP}"
# Use small cap for fast test
export CLAUDE_TOOL_FAILURES_MAX_LINES=10

JSONL="${TMP}/tool-failures.jsonl"
for i in $(seq 1 11); do
  echo "{\"ts\":\"x\",\"session_id\":\"s\",\"tool_name\":\"t\",\"line\":${i}}" >> "${JSONL}"
done
test "$(wc -l < "${JSONL}" | tr -d ' ')" = "11" || { echo "FAIL: pre-fill expected 11 lines" >&2; exit 1; }

echo '{"hook_event_name":"PostToolUseFailure","tool_name":"Bash","tool_input":{"command":"x"},"tool_output":"y","effort":{"level":"low"}}' | bash "${SCRIPT}"

lines="$(wc -l < "${JSONL}" | tr -d ' ')"
test "${lines}" = "10" || { echo "[test-log-tool-failure-rotation] FAIL: expected 10 lines after rotation got ${lines}" >&2; exit 1; }
echo "[test-log-tool-failure-rotation] PASS"
