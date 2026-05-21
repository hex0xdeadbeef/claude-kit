#!/bin/bash
# Hook: Stop
# Purpose: Check that there are no uncommitted changes before stopping
# Blocking: exit 0 + decision:block (NOT exit 2 — otherwise JSON is ignored)
# P3: per-session circuit breaker prevents infinite Stop-block loops when
# the commit precondition cannot be satisfied (e.g. pre-commit-build.sh
# keeps denying git commit).  After STOP_BLOCK_MAX consecutive identical
# blocks the hook emits a WARN and allows stop.

set -euo pipefail

# P3: hard-coded breaker threshold (no env var per user direction 2026-05-22).
# To tune, edit this line and `git revert` later — there is no per-machine knob.
STOP_BLOCK_MAX=5

# Drain stdin (Stop event JSON payload).  Read BEFORE the git short-circuit
# so the harness's piped JSON is consumed cleanly even when we exit early.
# Best-effort: missing/empty stdin falls back to a shared "default" session
# bucket per AC-P3.5.
STOP_INPUT=$(cat 2>/dev/null || echo "")

# Skip if not in git repo
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

# Check git status (let errors surface, don't suppress with 2>/dev/null)
GIT_OUTPUT=$(git status --porcelain 2>&1) || {
  # git command failed — allow stop, don't block on git errors
  exit 0
}

UNCOMMITTED=$(echo "$GIT_OUTPUT" | grep -c "." || true)

if [ "$UNCOMMITTED" -gt 0 ]; then
  # ── FIX-06: Check if workflow is active before blocking ──
  # Only block during active workflows (checkpoint exists, not completed, not stale).
  # Non-workflow sessions get a warning only — don't block ad-hoc work.
  IS_WORKFLOW="false"
  # P2: mtime-newest selection (was alphabetical `ls | tail -1` — latent bug
  # when feature naming and write order diverge).  Matches the established
  # mtime-correct pattern at notify-workflow-complete.sh:24.
  CHECKPOINT=$(ls -t .claude/workflow-state/*-checkpoint.yaml 2>/dev/null | head -n1)
  if [[ -n "$CHECKPOINT" ]]; then
    # Check 1: phase_completed < 5 (workflow not yet finished)
    PHASE_RAW=$(grep 'phase_completed:' "$CHECKPOINT" 2>/dev/null | sed 's/.*phase_completed:[[:space:]]*//' | tr -d '"'"'" || echo "0")
    PHASE_RAW="${PHASE_RAW:-0}"
    IS_COMPLETE=$(awk -v p="$PHASE_RAW" 'BEGIN { print (p+0 >= 5) ? "1" : "0" }')
    if [[ "$IS_COMPLETE" == "0" ]]; then
      # IMP-13: Complexity-aware staleness window (S/M: 4h, L: 8h, XL: 12h)
      COMPLEXITY=$(grep 'complexity:' "$CHECKPOINT" 2>/dev/null | sed 's/.*complexity:[[:space:]]*//' | tr -d '"'"'" | tr '[:lower:]' '[:upper:]' || echo "")
      case "$COMPLEXITY" in
        XL) STALENESS_WINDOW=43200 ;;  # 12 hours
        L)  STALENESS_WINDOW=28800 ;;  # 8 hours
        *)  STALENESS_WINDOW=14400 ;;  # 4 hours (S/M/unknown)
      esac
      # Check 2: checkpoint mtime within staleness window (not stale from previous session)
      if [[ "$(uname)" == "Darwin" ]]; then
        MTIME=$(stat -f %m "$CHECKPOINT" 2>/dev/null || echo "0")
      else
        MTIME=$(stat -c %Y "$CHECKPOINT" 2>/dev/null || echo "0")
      fi
      NOW=$(date +%s)
      AGE=$(( NOW - MTIME ))
      if [[ "$AGE" -lt "$STALENESS_WINDOW" ]]; then
        IS_WORKFLOW="true"
      fi
    fi
  fi

  if [[ "$IS_WORKFLOW" == "true" ]]; then
    # P3 circuit breaker: track consecutive blocks per session in
    # .claude/workflow-state/.stop-block-attempts-{session_id}.  Reset when
    # UNCOMMITTED count changes (user is making progress).  On NEW_COUNT
    # >= STOP_BLOCK_MAX, emit WARN and exit 0 (allow stop) instead of
    # re-emitting decision:block.  Counter file cleaned up at SessionEnd
    # by session-analytics.sh glob delete.
    STATE_DIR_LOCAL="${CLAUDE_WORKFLOW_STATE_DIR:-.claude/workflow-state}"
    SESSION_ID="default"
    if [[ -n "$STOP_INPUT" ]] && command -v python3 >/dev/null 2>&1; then
      SESSION_ID=$(echo "$STOP_INPUT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    sid = d.get('session_id') or 'default'
    print(sid if sid else 'default')
except Exception:
    print('default')
" 2>/dev/null || echo "default")
    fi
    BLOCK_LOG="${STATE_DIR_LOCAL}/.stop-block-attempts-${SESSION_ID}"

    PRIOR_COUNT=0
    PRIOR_UNCOMMITTED=""
    if [[ -f "$BLOCK_LOG" ]]; then
      PRIOR_LINE=$(head -n1 "$BLOCK_LOG" 2>/dev/null || echo "")
      PRIOR_COUNT=$(echo "$PRIOR_LINE" | awk -F: '{print $1}' 2>/dev/null || echo "0")
      PRIOR_UNCOMMITTED=$(echo "$PRIOR_LINE" | awk -F: '{print $2}' 2>/dev/null || echo "")
      # Numeric guard against corrupt counter content
      case "$PRIOR_COUNT" in
        ''|*[!0-9]*) PRIOR_COUNT=0 ;;
      esac
    fi
    if [[ "$UNCOMMITTED" != "$PRIOR_UNCOMMITTED" ]]; then
      PRIOR_COUNT=0   # uncommitted count changed → user made progress → reset
    fi
    NEW_COUNT=$((PRIOR_COUNT + 1))
    mkdir -p "$STATE_DIR_LOCAL" 2>/dev/null || true
    echo "${NEW_COUNT}:${UNCOMMITTED}" > "$BLOCK_LOG" 2>/dev/null || true

    if [[ "$NEW_COUNT" -ge "$STOP_BLOCK_MAX" ]]; then
      # Circuit breaker — allow stop with a loud WARN per kit convention
      echo "[check-uncommitted] WARN: ${NEW_COUNT} consecutive blocks for ${UNCOMMITTED} uncommitted file(s); allowing stop (circuit breaker — STOP_BLOCK_MAX=${STOP_BLOCK_MAX}). To re-arm: rm ${BLOCK_LOG}; to disable: edit STOP_BLOCK_MAX at top of check-uncommitted.sh." >&2
      exit 0
    fi

    # Workflow active — BLOCK (must commit before stopping)
    # IMPORTANT: exit 0 + JSON decision:block (NOT exit 2 — that ignores JSON)
    # Block-payload byte stability (AC-P3.10): the python3 heredoc below is
    # UNCHANGED from pre-P3 — only WHEN it fires changes (the breaker above
    # short-circuits attempts >= STOP_BLOCK_MAX).
    command -v python3 >/dev/null 2>&1 && {
      _UNCOMMITTED_COUNT="$UNCOMMITTED" python3 -c "
import json, os
count = os.environ.get('_UNCOMMITTED_COUNT', '?')
print(json.dumps({
    'decision': 'block',
    'reason': f'{count} uncommitted file(s). Run git add + git commit before stopping.'
}))
"
      exit 0
    }
    # Fallback if no python3: exit 2 with stderr
    echo "[check-uncommitted] ERROR: $UNCOMMITTED uncommitted file(s). Commit before stopping." >&2
    exit 2
  else
    # No active workflow — WARN only (don't block non-workflow sessions)
    echo "[check-uncommitted] WARN: $UNCOMMITTED uncommitted file(s). Consider committing." >&2
    exit 0
  fi
fi

# All clean — allow stop
exit 0
