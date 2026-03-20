#!/bin/bash
# Hook: PostToolUse (matcher: Write|Edit)
# Purpose: Auto-format Go files after edit/write using gofmt
# Non-blocking: exit 0 on success/skip, exit 2 if python3 missing (PostToolUse cannot block — tool already executed)
#
# Review fixes applied:
#   Fix #3: Check tool_response.success before formatting
#   Fix #4/#11: Use gofmt only (not goimports — avoids removing in-progress imports)
#   Fix #8: python3 is hard requirement (exit 2 if missing)
#   Fix #6: Log actions to .claude/workflow-state/hook-log.txt
#   Fix #1: Debug-log stdin on first run for contract verification

set -euo pipefail

# ── Hard dependency: python3 (consistent with all other hooks) ──
# Fix #8: fail loudly so user knows hook is broken, not silently doing nothing
command -v python3 >/dev/null 2>&1 || {
  echo "auto-fmt-go: python3 required but not found" >&2
  exit 2
}

# ── Read stdin JSON (MUST consume even if unused) ──
INPUT=$(cat)

# ── Log directory ──
LOG_DIR=".claude/workflow-state"
LOG_FILE="$LOG_DIR/hook-log.txt"
mkdir -p "$LOG_DIR"

# ── Fix #1: Debug-log stdin on first run for contract verification ──
DEBUG_MARKER="$LOG_DIR/.auto-fmt-go-verified"
if [[ ! -f "$DEBUG_MARKER" ]]; then
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] auto-fmt-go: FIRST RUN — stdin dump for contract verification:" >> "$LOG_FILE"
  echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.loads(sys.stdin.read())
    safe = {k: (type(v).__name__ if k in ('tool_input','tool_response') else v) for k, v in data.items()}
    safe['tool_input_keys'] = list(data.get('tool_input', {}).keys())
    safe['tool_response_keys'] = list(data.get('tool_response', {}).keys())
    print(json.dumps(safe, indent=2))
except Exception as e:
    print(f'JSON parse error: {e}')
" >> "$LOG_FILE" 2>&1
  touch "$DEBUG_MARKER"
fi

# ── Parse stdin: extract file_path and success status ──
# Pass INPUT via env var to avoid heredoc quoting issues with JSON content
PARSE_RESULT=$(echo "$INPUT" | python3 -c "
import json, sys

try:
    data = json.loads(sys.stdin.read())
except Exception:
    print('|false')
    sys.exit(0)

file_path = data.get('tool_input', {}).get('file_path', '')

# Fix #3: Check tool_response.success — don't format failed operations
tool_resp = data.get('tool_response', {})
success = str(tool_resp.get('success', True))

print(f'{file_path}|{success}')
" 2>/dev/null) || PARSE_RESULT="|false"

FILE_PATH=$(echo "$PARSE_RESULT" | cut -d'|' -f1)
SUCCESS=$(echo "$PARSE_RESULT" | cut -d'|' -f2)

# ── Fix #3: Skip if tool operation failed ──
if [[ "$SUCCESS" == "false" || "$SUCCESS" == "False" ]]; then
  exit 0
fi

# ── Only process .go files ──
if [[ -z "$FILE_PATH" ]] || [[ "$FILE_PATH" != *.go ]]; then
  exit 0
fi

# ── Skip generated files, mocks, vendor ──
if [[ "$FILE_PATH" == *_gen.go ]] || \
   [[ "$FILE_PATH" == */mocks/*.go ]] || \
   [[ "$FILE_PATH" == */vendor/* ]]; then
  exit 0
fi

# ── Skip if file doesn't exist ──
if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

# ── Format with gofmt only ──
# Fix #4/#11: NOT goimports — goimports can remove imports that coder
# hasn't finished using yet (mid-Part editing). goimports runs later
# as part of `make fmt` in VERIFY phase — that's the right place.
if command -v gofmt >/dev/null 2>&1; then
  # FIX-04: Capture gofmt output — log failures instead of silently swallowing
  # Use && || pattern to prevent set -e from exiting on gofmt failure
  FMT_OUTPUT=$(gofmt -w "$FILE_PATH" 2>&1) && FMT_STATUS=0 || FMT_STATUS=$?
  if [[ $FMT_STATUS -eq 0 ]]; then
    # Fix #6: Log successful format (to file, not stdout — avoid noise for Claude)
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] auto-fmt-go: formatted $(basename "$FILE_PATH")" >> "$LOG_FILE"
  else
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] auto-fmt-go: gofmt FAILED on $(basename "$FILE_PATH"): $FMT_OUTPUT" >> "$LOG_FILE"
  fi
else
  # gofmt not found — this means Go SDK is not installed
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] auto-fmt-go: WARNING gofmt not found, skipping" >> "$LOG_FILE"
fi

exit 0
