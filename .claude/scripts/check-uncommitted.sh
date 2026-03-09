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
  # IMPORTANT: exit 0 + JSON decision:block (NOT exit 2 — that ignores JSON)
  command -v python3 >/dev/null 2>&1 && {
    python3 -c "
import json
print(json.dumps({
    'decision': 'block',
    'reason': '$UNCOMMITTED uncommitted file(s). Run git add + git commit before stopping.'
}))
"
    exit 0
  }
  # Fallback if no python3: exit 2 with stderr
  echo "WARNING: $UNCOMMITTED uncommitted file(s). Commit before stopping." >&2
  exit 2
fi

# All clean — allow stop
exit 0
