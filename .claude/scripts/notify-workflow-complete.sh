#!/usr/bin/env bash
# .claude/scripts/notify-workflow-complete.sh
# Hook: Stop (matcher: "")
# Default: OFF. Set CLAUDE_KIT_PHASE_COMPLETION_NOTIFY=on to enable (per gate decision).
# Emits desktop notification via OSC 9 in terminalSequence JSON output field
# (v2.1.141+) only when the latest checkpoint shows Phase 5 + APPROVED|APPROVED_WITH_COMMENTS.
# Allowlist: OSC 0/1/2/9/99/777 + BEL. Never emits CSI, OSC 8, OSC 52, OSC 1337.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/log.sh
source "${SCRIPT_DIR}/lib/log.sh"

# Default OFF — gate decision: notification opts-in via env var
if [[ "${CLAUDE_KIT_PHASE_COMPLETION_NOTIFY:-off}" != "on" ]]; then
  exit 0
fi

REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
STATE_DIR="${CLAUDE_WORKFLOW_STATE_DIR:-${CLAUDE_PROJECT_DIR:-${REPO_ROOT}}/.claude/workflow-state}"

# Find latest checkpoint
latest_cp="$(ls -t "${STATE_DIR}"/*-checkpoint.yaml 2>/dev/null | head -n1 || true)"
if [[ -z "${latest_cp}" || ! -f "${latest_cp}" ]]; then
  exit 0
fi

# PR-007 fix: anchor at column 0, strip BOTH spaces AND quotes
phase="$(grep -E '^phase_completed:' "${latest_cp}" | head -n1 | awk -F: '{print $2}' | tr -d ' "')"
verdict="$(grep -E '^verdict:' "${latest_cp}" | head -n1 | awk -F: '{print $2}' | tr -d ' "')"

if [[ "${phase}" != "5" ]]; then exit 0; fi
case "${verdict}" in
  APPROVED|APPROVED_WITH_COMMENTS) ;;
  *) exit 0 ;;
esac

# I-03: read the Stop payload (v2.1.145+ includes background_tasks). Suppress the
# "workflow complete" notification while genuine background work is still running
# (e.g. a backgrounded code-researcher) — firing now would be premature. Placed on the
# emit path only (after the env/phase/verdict gates) per PR-002 review note: the
# default-OFF and non-final-Stop early-exits never need to drain stdin (harmless — each
# Stop hook gets its own stdin copy and exits at once). session_crons is intentionally
# NOT gated on — that is the kit's own auto-checkpoint cron, expected during a run.
STOP_INPUT="$(cat 2>/dev/null || echo "")"
if [[ -n "${STOP_INPUT}" ]] && command -v jq >/dev/null 2>&1; then
  bg_count="$(printf '%s' "${STOP_INPUT}" | jq -r '(.background_tasks // []) | length' 2>/dev/null || echo 0)"
  case "${bg_count}" in ''|*[!0-9]*) bg_count=0 ;; esac
  if [[ "${bg_count}" -gt 0 ]]; then exit 0; fi
fi

# Allowlisted OSC 9 sequence with BEL terminator
seq="$(printf '\033]9;Claude Code: workflow complete\007')"
jq -n --arg s "${seq}" '{hookSpecificOutput: {hookEventName: "Stop", terminalSequence: $s}}'
