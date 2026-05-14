#!/usr/bin/env bash
# Part 2: log-tool-failure.sh appends one JSONL line with expected keys when a Bash tool fails.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SCRIPT="${REPO_ROOT}/.claude/scripts/log-tool-failure.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

export CLAUDE_WORKFLOW_STATE_DIR="${TMP}"
export CLAUDE_CODE_SESSION_ID="0123456789abcdef"
export CLAUDE_EFFORT="high"

input='{
  "hook_event_name": "PostToolUseFailure",
  "tool_name": "Bash",
  "tool_input": {"command": "go vet ./does/not/exist"},
  "tool_output": "package not found",
  "effort": {"level": "high"}
}'
echo "${input}" | bash "${SCRIPT}"

JSONL="${TMP}/tool-failures.jsonl"
test -f "${JSONL}" || { echo "[test-log-tool-failure-jsonl] FAIL: ${JSONL} not created" >&2; exit 1; }
lines="$(wc -l < "${JSONL}" | tr -d ' ')"
test "${lines}" = "1" || { echo "[test-log-tool-failure-jsonl] FAIL: expected 1 line got ${lines}" >&2; exit 1; }

line="$(cat "${JSONL}")"
for key in ts session_id tool_name exit_signature effort_level; do
  if ! echo "${line}" | jq -e "has(\"${key}\")" >/dev/null 2>&1; then
    echo "[test-log-tool-failure-jsonl] FAIL: missing key '${key}'" >&2
    echo "Got: ${line}" >&2
    exit 1
  fi
done
echo "[test-log-tool-failure-jsonl] PASS"
