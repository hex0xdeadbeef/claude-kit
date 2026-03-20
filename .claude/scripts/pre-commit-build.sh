#!/bin/bash
# Hook: PreToolUse (matcher: Bash)
# Purpose: Validate go build before git commit — catches build failures early
# Blocking: YES — deny if build fails (exit 0 + permissionDecision:deny)
# Only fires on git commit commands; skips non-Go projects
#
# Performance: go build ./... adds 2-10s per commit. Acceptable for correctness
# guarantee since commits are infrequent relative to edits.
#
# Scope: Catches Claude-initiated commits only (not manual terminal commits).
# For full coverage, install a git pre-commit hook separately.

set -euo pipefail

# ── Soft dependency: python3 — skip silently if missing ──
command -v python3 >/dev/null 2>&1 || exit 0

# ── Read stdin JSON (MUST consume even if unused) ──
INPUT=$(cat)

# ── Check if this is a git commit command ──
IS_COMMIT=$(echo "$INPUT" | python3 -c "
import json, sys, re
try:
    data = json.loads(sys.stdin.read())
    cmd = data.get('tool_input', {}).get('command', '')
    # Match: git commit with any flags, including in chained commands (git add && git commit)
    # Uses re.search (not re.match) + (\s|$) to avoid false positives on git commit-tree/commit-msg
    if re.search(r'\bgit\s+commit(\s|$)', cmd):
        print('yes')
    else:
        print('no')
except Exception:
    print('no')
" 2>/dev/null) || IS_COMMIT="no"

if [[ "$IS_COMMIT" != "yes" ]]; then
  exit 0
fi

# ── Skip non-Go projects ──
if [[ ! -f "go.mod" ]]; then
  exit 0
fi

# ── Skip if go not available ──
if ! command -v go >/dev/null 2>&1; then
  exit 0
fi

# ── Log directory ──
LOG_DIR=".claude/workflow-state"
LOG_FILE="$LOG_DIR/hook-log.txt"
mkdir -p "$LOG_DIR" 2>/dev/null || true

# ── Run go build — capture output ──
BUILD_OUTPUT=$(go build ./... 2>&1) || {
  # Build failed — deny the commit
  export _BUILD_OUTPUT="${BUILD_OUTPUT:0:500}"
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] pre-commit-build: BLOCKED — go build ./... failed" >> "$LOG_FILE" 2>/dev/null || true

  python3 -c "
import json, os
output = os.environ.get('_BUILD_OUTPUT', '')
print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'permissionDecision': 'deny',
        'permissionDecisionReason': 'go build ./... failed. Fix build errors before committing.\n' + output
    }
}))
"
  exit 0
}

# ── Build passed — log and allow commit ──
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] pre-commit-build: PASS — go build ./..." >> "$LOG_FILE" 2>/dev/null || true
exit 0
