#!/usr/bin/env bash
# Part 5 / Proposal H + PR-007: env on + NEEDS_CHANGES checkpoint emits NO notification.
# NEEDS_CHANGES is the canonical not-APPROVED workflow checkpoint verdict per
# checkpoint-protocol.md (CHANGES_REQUESTED is code-review-specific, not in workflow
# checkpoint enum). PR-007 fix replaced the iter-1 CHANGES_REQUESTED fixture.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SCRIPT="${REPO_ROOT}/.claude/scripts/notify-workflow-complete.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

export CLAUDE_KIT_PHASE_COMPLETION_NOTIFY=on
export CLAUDE_WORKFLOW_STATE_DIR="${TMP}"

cat > "${TMP}/x-checkpoint.yaml" <<'YAML'
phase_completed: 5
verdict: NEEDS_CHANGES
YAML

ec=0
out=$(bash "${SCRIPT}" 2>/dev/null) || ec=$?
test "${ec}" -eq 0 || { echo "FAIL: expected exit 0, got ${ec}" >&2; exit 1; }

ts=$(echo "${out}" | jq -r '.hookSpecificOutput.terminalSequence // ""' 2>/dev/null || echo "")
test -z "${ts}" || { echo "[test-notify-workflow-complete-needs-changes] FAIL: notification fired on NEEDS_CHANGES" >&2; exit 1; }
echo "[test-notify-workflow-complete-needs-changes] PASS"
