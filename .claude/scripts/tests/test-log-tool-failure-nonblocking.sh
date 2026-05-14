#!/usr/bin/env bash
# Part 2: log-tool-failure.sh must exit 0 on every path (non-blocking analytics hook).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SCRIPT="${REPO_ROOT}/.claude/scripts/log-tool-failure.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

export CLAUDE_WORKFLOW_STATE_DIR="${TMP}"

# Case 1: malformed JSON on stdin
ec=0
echo "not valid json {" | bash "${SCRIPT}" || ec=$?
test "${ec}" -eq 0 || { echo "FAIL: malformed input should not crash, got exit ${ec}" >&2; exit 1; }

# Case 2: empty stdin
ec=0
echo "" | bash "${SCRIPT}" || ec=$?
test "${ec}" -eq 0 || { echo "FAIL: empty input should not crash, got exit ${ec}" >&2; exit 1; }

# Case 3: missing keys
ec=0
echo '{}' | bash "${SCRIPT}" || ec=$?
test "${ec}" -eq 0 || { echo "FAIL: missing keys should not crash, got exit ${ec}" >&2; exit 1; }

echo "[test-log-tool-failure-nonblocking] PASS"
