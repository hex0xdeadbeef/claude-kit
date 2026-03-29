#!/bin/bash
# Hook: Stop
# Purpose: Check that there are no uncommitted changes before stopping
# Blocking: exit 0 + decision:block (NOT exit 2 — otherwise JSON is ignored)

set -euo pipefail

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
  CHECKPOINT=$(ls .claude/workflow-state/*-checkpoint.yaml 2>/dev/null | tail -1)
  if [[ -n "$CHECKPOINT" ]]; then
    # Check 1: phase_completed < 5 (workflow not yet finished)
    PHASE_RAW=$(grep 'phase_completed:' "$CHECKPOINT" 2>/dev/null | sed 's/.*phase_completed:[[:space:]]*//' | tr -d '"'"'" || echo "0")
    PHASE_RAW="${PHASE_RAW:-0}"
    IS_COMPLETE=$(awk -v p="$PHASE_RAW" 'BEGIN { print (p+0 >= 5) ? "1" : "0" }')
    if [[ "$IS_COMPLETE" == "0" ]]; then
      # Check 2: checkpoint mtime within last 4 hours (not stale from previous session)
      if [[ "$(uname)" == "Darwin" ]]; then
        MTIME=$(stat -f %m "$CHECKPOINT" 2>/dev/null || echo "0")
      else
        MTIME=$(stat -c %Y "$CHECKPOINT" 2>/dev/null || echo "0")
      fi
      NOW=$(date +%s)
      AGE=$(( NOW - MTIME ))
      if [[ "$AGE" -lt 14400 ]]; then  # 4 hours = 14400 seconds
        IS_WORKFLOW="true"
      fi
    fi
  fi

  if [[ "$IS_WORKFLOW" == "true" ]]; then
    # Workflow active — BLOCK (must commit before stopping)
    # IMPORTANT: exit 0 + JSON decision:block (NOT exit 2 — that ignores JSON)
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
    echo "WARNING: $UNCOMMITTED uncommitted file(s). Commit before stopping." >&2
    exit 2
  else
    # No active workflow — WARN only (don't block non-workflow sessions)
    echo "WARNING: $UNCOMMITTED uncommitted file(s). Consider committing." >&2
    exit 0
  fi
fi

# All clean — allow stop
exit 0
