#!/usr/bin/env bash
# test-precompact-iteration-block.sh — smoke tests for iteration-in-flight blocking
# Usage: bash .claude/scripts/tests/test-precompact-iteration-block.sh
# Covers: AC-1 (dirty → block), AC-2 (clean → proceed), AC-3 (stale → proceed + delete),
#         AC-4 (S-route simulation → never blocks), + BONUS (manual trigger pass-through)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLOCK="${SCRIPT_DIR}/../save-progress-before-compact.sh"

PASS=0
FAIL=0

# Isolated temp state dir — avoids touching real .claude/workflow-state/
TEMP_STATE_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_STATE_DIR"' EXIT

ITER_FILE="${TEMP_STATE_DIR}/.iteration-in-flight"

# Helper: run the PreCompact hook script with a given trigger.
# Uses CLAUDE_WORKFLOW_STATE_DIR env to isolate from real state.
run_hook() {
  local trigger="${1:-auto}"
  echo "{\"trigger\": \"$trigger\"}" \
    | CLAUDE_WORKFLOW_STATE_DIR="$TEMP_STATE_DIR" bash "${BLOCK}" 2>/dev/null
}

# Helper: check if output JSON contains decision:block
is_blocked() {
  local output="$1"
  echo "$output" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    sys.exit(0 if d.get('decision') == 'block' else 1)
except Exception:
    sys.exit(1)
" 2>/dev/null
}

run_test() {
  local name="$1"
  local expect_block="$2"   # true | false
  local output="$3"

  local got_block=false
  if is_blocked "$output"; then
    got_block=true
  fi

  if [[ "$got_block" == "$expect_block" ]]; then
    echo "  PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name (expected block=$expect_block, got block=$got_block)"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== test-precompact-iteration-block.sh ==="
echo ""

echo "--- AC-1: fresh .iteration-in-flight → auto trigger → BLOCK ---"
echo '{"agent": "plan-reviewer", "started_at": "2026-04-23T14:00:00Z", "feature": "test", "iteration": 1}' \
  > "$ITER_FILE"
output=$(run_hook "auto")
run_test "dirty state (plan-reviewer) → block" true "$output"

# Verify block reason mentions the agent name
if echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
reason = d.get('reason', '')
sys.exit(0 if 'plan-reviewer' in reason else 1)
" 2>/dev/null; then
  echo "  PASS: block reason mentions agent name (plan-reviewer)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: block reason missing agent name"
  FAIL=$((FAIL + 1))
fi

rm -f "$ITER_FILE"

echo ""
echo "--- AC-1 (variant): code-reviewer in-flight → auto trigger → BLOCK ---"
echo '{"agent": "code-reviewer", "started_at": "2026-04-23T14:00:00Z", "feature": "test", "iteration": 1}' \
  > "$ITER_FILE"
output=$(run_hook "auto")
run_test "dirty state (code-reviewer) → block" true "$output"
rm -f "$ITER_FILE"

echo ""
echo "--- AC-2: no .iteration-in-flight → auto trigger → proceed ---"
rm -f "$ITER_FILE"
output=$(run_hook "auto")
run_test "clean state → no block" false "$output"

echo ""
echo "--- AC-3: stale .iteration-in-flight (mtime > 30 min) → proceed + file deleted ---"
echo '{"agent": "plan-reviewer"}' > "$ITER_FILE"
# Set mtime to 2024-01-01 00:00 (macOS touch -t format: [[CC]YY]MMDDhhmm[.SS])
touch -t 202401010000 "$ITER_FILE"
output=$(run_hook "auto")
run_test "stale file → no block" false "$output"

if [[ ! -f "$ITER_FILE" ]]; then
  echo "  PASS: stale file was deleted"
  PASS=$((PASS + 1))
else
  echo "  FAIL: stale file still exists after stale check"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "--- AC-4: S-complexity (no file created by orchestrator) → never blocks ---"
rm -f "$ITER_FILE"
output=$(run_hook "auto")
run_test "S-route (no file) → no block" false "$output"

echo ""
echo "--- BONUS: fresh .iteration-in-flight → manual trigger → ALWAYS proceeds ---"
echo '{"agent": "plan-reviewer"}' > "$ITER_FILE"
output=$(run_hook "manual")
run_test "manual trigger + dirty state → never blocked" false "$output"
rm -f "$ITER_FILE"

echo ""
echo "--- BONUS: malformed .iteration-in-flight JSON → still blocks (graceful fallback) ---"
echo 'NOT VALID JSON' > "$ITER_FILE"
output=$(run_hook "auto")
run_test "malformed file → still blocks (fallback to 'review agent')" true "$output"

if echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
reason = d.get('reason', '')
sys.exit(0 if 'review agent' in reason else 1)
" 2>/dev/null; then
  echo "  PASS: malformed file → fallback agent name 'review agent'"
  PASS=$((PASS + 1))
else
  echo "  FAIL: malformed file → unexpected reason text"
  FAIL=$((FAIL + 1))
fi
rm -f "$ITER_FILE"

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ "${FAIL}" -eq 0 ]] && exit 0 || exit 1
