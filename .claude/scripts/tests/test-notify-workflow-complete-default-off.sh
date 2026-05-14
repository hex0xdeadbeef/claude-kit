#!/usr/bin/env bash
# Part 5 / Proposal H: notify-workflow-complete.sh defaults OFF (no env, no notification
# even with an APPROVED checkpoint). Verifies the gate decision.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SCRIPT="${REPO_ROOT}/.claude/scripts/notify-workflow-complete.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

unset CLAUDE_KIT_PHASE_COMPLETION_NOTIFY
export CLAUDE_WORKFLOW_STATE_DIR="${TMP}"
cat > "${TMP}/x-checkpoint.yaml" <<'YAML'
phase_completed: 5
verdict: APPROVED
YAML

ec=0
out=$(bash "${SCRIPT}" 2>/dev/null) || ec=$?
test "${ec}" -eq 0 || { echo "FAIL: expected exit 0, got ${ec}" >&2; exit 1; }

ts=$(echo "${out}" | jq -r '.hookSpecificOutput.terminalSequence // ""' 2>/dev/null || echo "")
test -z "${ts}" || { echo "[test-notify-workflow-complete-default-off] FAIL: emitted terminalSequence when env off" >&2; exit 1; }
echo "[test-notify-workflow-complete-default-off] PASS"
