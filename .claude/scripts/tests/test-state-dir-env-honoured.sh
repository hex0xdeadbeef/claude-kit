#!/usr/bin/env bash
# test-state-dir-env-honoured.sh
# P5 — verify CLAUDE_WORKFLOW_STATE_DIR is honoured by track-task-lifecycle.sh + prepare-worktree.sh
#
# Convention: exit 0 on success, exit 1 on assertion failure.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SANDBOX="$(mktemp -d -t state-dir-env-XXXXXX)"
trap 'rm -rf "${SANDBOX}"' EXIT

export CLAUDE_WORKFLOW_STATE_DIR="${SANDBOX}"

# ---- Test 1: track-task-lifecycle.sh writes to sandbox, not to .claude/workflow-state/ ----
PROD_BEFORE=""
if [[ -f "${REPO_ROOT}/.claude/workflow-state/task-events.jsonl" ]]; then
  PROD_BEFORE=$(wc -l < "${REPO_ROOT}/.claude/workflow-state/task-events.jsonl" | tr -d ' ')
fi

echo '{"hook_event_name":"SubagentStart","agent_type":"code-researcher","agent_id":"test-1","session_id":"s-1"}' \
  | bash "${REPO_ROOT}/.claude/scripts/track-task-lifecycle.sh" >/dev/null 2>&1 || true

if [[ ! -f "${SANDBOX}/task-events.jsonl" ]]; then
  echo "[test-state-dir-env-honoured] FAIL: track-task-lifecycle.sh did not write to sandbox" >&2
  exit 1
fi

# Confirm production task-events.jsonl was NOT touched
PROD_AFTER=""
if [[ -f "${REPO_ROOT}/.claude/workflow-state/task-events.jsonl" ]]; then
  PROD_AFTER=$(wc -l < "${REPO_ROOT}/.claude/workflow-state/task-events.jsonl" | tr -d ' ')
fi
if [[ "${PROD_BEFORE}" != "${PROD_AFTER}" ]]; then
  echo "[test-state-dir-env-honoured] FAIL: track-task-lifecycle.sh leaked write to production state dir (before=${PROD_BEFORE}, after=${PROD_AFTER})" >&2
  exit 1
fi

# ---- Test 2: prepare-worktree.sh writes to sandbox debug log ----
# Send malformed JSON so the parse-failure path always logs to debug file.
PROD_DBG_BEFORE=""
if [[ -f "${REPO_ROOT}/.claude/workflow-state/worktree-events-debug.jsonl" ]]; then
  PROD_DBG_BEFORE=$(wc -l < "${REPO_ROOT}/.claude/workflow-state/worktree-events-debug.jsonl" | tr -d ' ')
fi

echo 'INVALID-JSON-PAYLOAD' \
  | bash "${REPO_ROOT}/.claude/scripts/prepare-worktree.sh" >/dev/null 2>&1 || true

if [[ ! -f "${SANDBOX}/worktree-events-debug.jsonl" ]]; then
  echo "[test-state-dir-env-honoured] FAIL: prepare-worktree.sh did not write debug log to sandbox" >&2
  exit 1
fi

PROD_DBG_AFTER=""
if [[ -f "${REPO_ROOT}/.claude/workflow-state/worktree-events-debug.jsonl" ]]; then
  PROD_DBG_AFTER=$(wc -l < "${REPO_ROOT}/.claude/workflow-state/worktree-events-debug.jsonl" | tr -d ' ')
fi
if [[ "${PROD_DBG_BEFORE}" != "${PROD_DBG_AFTER}" ]]; then
  echo "[test-state-dir-env-honoured] FAIL: prepare-worktree.sh leaked write to production state dir (before=${PROD_DBG_BEFORE}, after=${PROD_DBG_AFTER})" >&2
  exit 1
fi

echo "[test-state-dir-env-honoured] PASS"
exit 0
