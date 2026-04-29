#!/usr/bin/env bash
# jsonl-lock.sh — shared lock helper for JSONL appends (P4)
#
# Sourced by:
#   .claude/scripts/save-review-checkpoint.sh
#   .claude/scripts/track-task-lifecycle.sh
#   .claude/scripts/validate-handoff.sh
#
# Contract:
#   jsonl_append_locked TARGET_PATH JSON_LINE
#     - When CLAUDE_JSONL_APPEND_LOCK=on: acquires an atomic mkdir lock on
#       ${TARGET_PATH}.lockdir; retries up to 50 times with 0.1 s sleep
#       (5 s cumulative budget). Atomic mkdir is POSIX-portable (works on
#       macOS without `flock`, on Linux without `flock`, on BSD).
#       On persistent failure: best-effort append + ANOMALY entry to
#       ${CLAUDE_WORKFLOW_STATE_DIR:-.claude/workflow-state}/anomalies.jsonl.
#     - When CLAUDE_JSONL_APPEND_LOCK is unset OR off: direct append
#       (byte-identical to legacy behaviour — backwards-compat).
#     - Returns 0 ALWAYS — JSONL append is NON_CRITICAL and must never block.
#
# Env:
#   CLAUDE_JSONL_APPEND_LOCK     off (default) | on
#   CLAUDE_WORKFLOW_STATE_DIR    fallback path for anomalies.jsonl
#
# NEVER use `set -e` here — callers source this file; pipefail must remain caller-controlled.

jsonl_append_locked() {
  local target="$1"
  local line="$2"
  local lockdir="${target}.lockdir"
  local state_dir="${CLAUDE_WORKFLOW_STATE_DIR:-.claude/workflow-state}"
  local mode="${CLAUDE_JSONL_APPEND_LOCK:-off}"

  if [[ "${mode}" != "on" ]]; then
    printf '%s\n' "${line}" >> "${target}" 2>/dev/null || true
    return 0
  fi

  local attempts=0
  local max_attempts=50
  while (( attempts < max_attempts )); do
    if mkdir "${lockdir}" 2>/dev/null; then
      printf '%s\n' "${line}" >> "${target}" 2>/dev/null || true
      rmdir "${lockdir}" 2>/dev/null || true
      return 0
    fi
    attempts=$(( attempts + 1 ))
    sleep 0.1
  done

  printf '%s\n' "${line}" >> "${target}" 2>/dev/null || true
  local ts
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  local anomaly
  anomaly=$(printf '{"timestamp":"%s","type":"JSONL_LOCK_TIMEOUT","target":"%s","attempts":%d}' \
    "${ts}" "${target}" "${attempts}")
  printf '%s\n' "${anomaly}" >> "${state_dir}/anomalies.jsonl" 2>/dev/null || true
  return 0
}
