#!/usr/bin/env bash
# test-log-tool-failure-default-path.sh
# Regression: log-tool-failure.sh must write to <repo>/.claude/workflow-state/tool-failures.jsonl
# when CLAUDE_WORKFLOW_STATE_DIR is unset (production hook invocation shape).
# Pre-fix this test FAILS because REPO_ROOT was derived with a single `..`, yielding
# the nested path <repo>/.claude/.claude/workflow-state/tool-failures.jsonl.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
REAL_SCRIPT="${REPO_ROOT}/.claude/scripts/log-tool-failure.sh"

# Skip if jq missing (script degrades silently — coverage moot)
if ! command -v jq >/dev/null 2>&1; then
  echo "[test-log-tool-failure-default-path] SKIP: jq unavailable" >&2
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

# Stage the script in a faux repo layout so BASH_SOURCE-based path derivation works
mkdir -p "${TMP}/.claude/scripts"
cp "${REAL_SCRIPT}" "${TMP}/.claude/scripts/log-tool-failure.sh"
chmod +x "${TMP}/.claude/scripts/log-tool-failure.sh"

# Defensive: caller env may have CLAUDE_WORKFLOW_STATE_DIR set; the whole point of
# this test is to exercise the env-unset fallback path.
unset CLAUDE_WORKFLOW_STATE_DIR
export CLAUDE_CODE_SESSION_ID="test-default-path"
export CLAUDE_EFFORT="low"

payload='{
  "hook_event_name": "PostToolUseFailure",
  "tool_name": "Bash",
  "tool_input": {"command": "false"},
  "tool_output": "non-zero",
  "effort": {"level": "low"}
}'
echo "${payload}" | bash "${TMP}/.claude/scripts/log-tool-failure.sh"

CANONICAL="${TMP}/.claude/workflow-state/tool-failures.jsonl"
NESTED="${TMP}/.claude/.claude/workflow-state/tool-failures.jsonl"

if [[ ! -f "${CANONICAL}" ]]; then
  echo "[test-log-tool-failure-default-path] FAIL: expected canonical path ${CANONICAL} not created" >&2
  [[ -f "${NESTED}" ]] && echo "[test-log-tool-failure-default-path] DIAG: found nested-path artifact at ${NESTED}" >&2
  exit 1
fi

if [[ -d "${TMP}/.claude/.claude" ]]; then
  echo "[test-log-tool-failure-default-path] FAIL: nested .claude/.claude/ directory must not be created" >&2
  exit 1
fi

lines="$(wc -l < "${CANONICAL}" | tr -d ' ')"
test "${lines}" = "1" || { echo "[test-log-tool-failure-default-path] FAIL: expected 1 line in ${CANONICAL}, got ${lines}" >&2; exit 1; }

# Sanity: required JSONL keys present (matches existing test-log-tool-failure-jsonl.sh schema check)
line="$(cat "${CANONICAL}")"
for key in ts session_id tool_name exit_signature effort_level; do
  if ! echo "${line}" | jq -e "has(\"${key}\")" >/dev/null 2>&1; then
    echo "[test-log-tool-failure-default-path] FAIL: missing key '${key}' in ${CANONICAL}" >&2
    echo "Got: ${line}" >&2
    exit 1
  fi
done

echo "[test-log-tool-failure-default-path] PASS"
