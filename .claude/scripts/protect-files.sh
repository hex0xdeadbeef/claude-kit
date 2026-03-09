#!/bin/bash
# Hook: PreToolUse (matcher: Write|Edit — regex on tool_name)
# Purpose: Block editing of protected files (generated, mocks, vendor, secrets, git, workflow infra)
# Blocking: exit 0 + permissionDecision:"deny" for protected files
# Non-blocking: exit 0 (no output) for allowed files
#
# Review fixes applied:
#   Fix BLOCKER-1: Exclude .env.example/.template/.sample from protection
#   Fix BLOCKER-2: Use env var instead of heredoc triple-quote for DENY_REASON
#   Fix MAJOR-1: Use regex for .claude/scripts/ (catches subdirectories)
#   Fix MINOR-1: Error handling for mkdir
#   Fix MINOR-2: Log empty/failed path parsing
#   Fix MINOR-6: Log JSON parse failures
#
# Protected categories:
#   - *_gen.go: generated code (use go generate)
#   - */mocks/*.go: generated mocks (regenerate)
#   - */vendor/*: vendored deps (use go mod vendor)
#   - *.env / *.env.* (excl. .example/.template/.sample): secrets
#   - .git/*: git internals (use git commands)
#   - .claude/settings.json: hook config (user-only changes)
#   - .claude/scripts/: hook scripts (user-only changes)

set -euo pipefail

# ── Hard dependency: python3 ──
command -v python3 >/dev/null 2>&1 || {
  echo "protect-files: python3 required but not found" >&2
  exit 2
}

# ── Read stdin JSON ──
INPUT=$(cat)

# ── Log directory (Fix MINOR-1: error handling for mkdir) ──
LOG_DIR=".claude/workflow-state"
LOG_FILE="$LOG_DIR/hook-log.txt"
mkdir -p "$LOG_DIR" 2>/dev/null || {
  echo "protect-files: cannot create log directory $LOG_DIR" >&2
  exit 2
}

# ── Parse file_path from stdin (Fix MINOR-6: log parse failures) ──
FILE_PATH=$(echo "$INPUT" | python3 -c "
import json, sys
try:
    data = json.loads(sys.stdin.read())
    print(data.get('tool_input', {}).get('file_path', ''))
except Exception as e:
    print('')
    print(f'JSON parse error: {e}', file=sys.stderr)
" 2>>"$LOG_FILE") || FILE_PATH=""

# ── Empty path — allow (Fix MINOR-2: log empty path for debugging) ──
if [[ -z "$FILE_PATH" ]]; then
  if [[ -n "$INPUT" ]]; then
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] protect-files: empty file_path (malformed input?)" >> "$LOG_FILE"
  fi
  exit 0
fi

# ── Check protected patterns ──
# Note: bash [[ == PATTERN ]] glob — * matches any chars INCLUDING /
# So *_gen.go matches both relative and absolute paths correctly
DENY_REASON=""

if [[ "$FILE_PATH" == *_gen.go ]]; then
  DENY_REASON="Generated file (*_gen.go). Do NOT edit manually — use go generate ./... to regenerate."

elif [[ "$FILE_PATH" == */mocks/*.go ]]; then
  DENY_REASON="Generated mock file (mocks/*.go). Do NOT edit manually — update the interface, then regenerate mocks."

elif [[ "$FILE_PATH" == */vendor/* ]] || [[ "$FILE_PATH" == vendor/* ]]; then
  DENY_REASON="Vendored dependency (vendor/). Do NOT edit — modify go.mod, then run go mod vendor."

elif [[ "$FILE_PATH" == *.env ]] || [[ "$FILE_PATH" == *.env.* ]] || [[ "$FILE_PATH" == */.env ]]; then
  # Fix BLOCKER-1: Exclude .env.example, .env.template, .env.sample — these are documentation, not secrets
  if [[ "$FILE_PATH" != *.example ]] && [[ "$FILE_PATH" != *.template ]] && [[ "$FILE_PATH" != *.sample ]]; then
    DENY_REASON="Secrets file (.env). Do NOT write secrets — update config.yaml.example and README instead."
  fi

elif [[ "$FILE_PATH" == */.git/* ]] || [[ "$FILE_PATH" == .git/* ]]; then
  DENY_REASON="Git internal file (.git/). Do NOT modify directly — use git commands."

# Note: settings.local.json is intentionally NOT protected — personal dev overrides
elif [[ "$FILE_PATH" =~ \.claude/settings\.json$ ]]; then
  DENY_REASON="Workflow config (.claude/settings.json). Changes must be made by user, not by agent."

elif [[ "$FILE_PATH" =~ \.claude/scripts/ ]]; then
  # Fix MAJOR-1: regex catches any file under .claude/scripts/ including subdirectories
  DENY_REASON="Hook script (.claude/scripts/). Changes must be made by user, not by agent."
fi

# ── If protected — deny with explanation ──
if [[ -n "$DENY_REASON" ]]; then
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] protect-files: BLOCKED $(basename "$FILE_PATH") — $DENY_REASON" >> "$LOG_FILE"

  # Fix BLOCKER-2: Use env var instead of heredoc triple-quote (safe for any DENY_REASON content)
  export DENY_REASON
  python3 -c "
import json, os
output = {
    'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'permissionDecision': 'deny',
        'permissionDecisionReason': os.environ.get('DENY_REASON', 'Protected file')
    }
}
print(json.dumps(output))
"
  exit 0
fi

# ── Not protected — allow (no output = proceed) ──
# Note: if hook outputs invalid JSON, Claude ignores output and proceeds (fail-open by contract)
exit 0
