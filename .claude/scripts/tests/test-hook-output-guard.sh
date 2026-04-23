#!/usr/bin/env bash
# Tests for P1-09 hook output guard
# Covers: save-progress-before-compact.sh guard (AC-1, AC-2, AC-8), session-analytics.sh cleanup (AC-3)
# Run: bash .claude/scripts/tests/test-hook-output-guard.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
cd "$REPO_ROOT"
SAVE_PROGRESS_SCRIPT="${SCRIPT_DIR}/../save-progress-before-compact.sh"
SESSION_ANALYTICS_SCRIPT="${SCRIPT_DIR}/../session-analytics.sh"

PASS=0
FAIL=0

run_test() {
  local name="$1"
  local result="$2"
  if [[ "$result" == "PASS" ]]; then
    echo "PASS: $name"
    (( PASS++ )) || true
  else
    echo "FAIL: $name — $result" >&2
    (( FAIL++ )) || true
  fi
}

# ── Shared setup ──────────────────────────────────────────────────────────────
TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

TMPSTATE="$TMPDIR_TEST/.claude/workflow-state"
mkdir -p "$TMPSTATE"

# ── Test 1: Overflow path — 45K+ output → overflow file written, preview emitted ──
FEATURE="test-overflow"
CHECKPOINT="$TMPSTATE/${FEATURE}-checkpoint.yaml"
cat > "$CHECKPOINT" << EOF
feature: ${FEATURE}
phase_completed: 2
complexity: XL
issues_history:
$(python3 -c "
for i in range(600):
    print(f'  - id: CR-{i:08x}')
    print(f'    problem: Issue number {i:06d} with a long problem description here x{i}')
")
EOF

CHECKPOINT_SIZE=$(wc -c < "$CHECKPOINT" | tr -d ' ')
if [[ "$CHECKPOINT_SIZE" -lt 40000 ]]; then
  run_test "overflow precondition: checkpoint file >= 40K bytes" \
    "FAIL: checkpoint only ${CHECKPOINT_SIZE} bytes — increase issue count"
else
  run_test "overflow precondition: checkpoint file >= 40K bytes" "PASS"

  RESULT=$(echo '{"trigger": "manual"}' | \
    CLAUDE_WORKFLOW_STATE_DIR="$TMPSTATE" bash "$SAVE_PROGRESS_SCRIPT" 2>/dev/null)

  OVERFLOW_COUNT=$(ls "$TMPSTATE"/compact-overflow-*.log 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$OVERFLOW_COUNT" -ge 1 ]]; then
    run_test "overflow: file written to STATE_DIR" "PASS"
  else
    run_test "overflow: file written to STATE_DIR" "FAIL: no compact-overflow-*.log in $TMPSTATE"
  fi

  if echo "$RESULT" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); assert '[Overflow]' in d.get('additionalContext',''), repr(d)"; then
    run_test "overflow: stdout contains [Overflow] marker" "PASS"
  else
    run_test "overflow: stdout contains [Overflow] marker" "FAIL: got: ${RESULT:0:200}"
  fi
fi

# ── Test 2: Normal path — 5K output → no file, stdout is full JSON ──
FEATURE2="test-normal"
TMPSTATE2="$TMPDIR_TEST/.claude/workflow-state-normal"
mkdir -p "$TMPSTATE2"
cat > "$TMPSTATE2/${FEATURE2}-checkpoint.yaml" << EOF
feature: ${FEATURE2}
phase_completed: 2
complexity: M
issues_history:
  - id: CR-00000001
    problem: Small issue
EOF

RESULT2=$(echo '{"trigger": "manual"}' | \
  CLAUDE_WORKFLOW_STATE_DIR="$TMPSTATE2" bash "$SAVE_PROGRESS_SCRIPT" 2>/dev/null)

OVERFLOW_COUNT2=$(ls "$TMPSTATE2"/compact-overflow-*.log 2>/dev/null | wc -l | tr -d ' ')
if [[ "$OVERFLOW_COUNT2" -eq 0 ]]; then
  run_test "normal: no overflow file created" "PASS"
else
  run_test "normal: no overflow file created" "FAIL: found $OVERFLOW_COUNT2 overflow files"
fi

if echo "$RESULT2" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); assert 'additionalContext' in d; assert '[Overflow]' not in d['additionalContext']"; then
  run_test "normal: stdout is plain additionalContext (no overflow)" "PASS"
else
  run_test "normal: stdout is plain additionalContext (no overflow)" "FAIL: got: ${RESULT2:0:200}"
fi

# ── Test 3: Cleanup — old file deleted, new file kept ──
TMPSTATE3="$TMPDIR_TEST/.claude/workflow-state-cleanup"
mkdir -p "$TMPSTATE3"

OLD_FILE="$TMPSTATE3/compact-overflow-old.log"
touch "$OLD_FILE"
python3 -c "
import os, time
os.utime('${OLD_FILE}', (time.time() - 8*24*3600, time.time() - 8*24*3600))
"

NEW_FILE="$TMPSTATE3/compact-overflow-new.log"
touch "$NEW_FILE"

echo '{}' | CLAUDE_WORKFLOW_STATE_DIR="$TMPSTATE3" bash "$SESSION_ANALYTICS_SCRIPT" 2>/dev/null || true

if [[ ! -f "$OLD_FILE" ]]; then
  run_test "cleanup: old overflow file (8 days) deleted" "PASS"
else
  run_test "cleanup: old overflow file (8 days) deleted" "FAIL: file still exists"
fi

if [[ -f "$NEW_FILE" ]]; then
  run_test "cleanup: new overflow file (current) kept" "PASS"
else
  run_test "cleanup: new overflow file (current) kept" "FAIL: new file deleted"
fi

# ── Test 4: Blocking path — decision:block passes through, no overflow file ──
TMPSTATE4="$TMPDIR_TEST/.claude/workflow-state-block"
mkdir -p "$TMPSTATE4"

FEATURE4="test-block"
cat > "$TMPSTATE4/${FEATURE4}-checkpoint.yaml" << EOF
feature: ${FEATURE4}
phase_completed: 1
complexity: M
EOF

cat > "$TMPSTATE4/.iteration-in-flight" << EOF
{"agent": "plan-reviewer", "started_at": "2026-01-01T00:00:00Z", "feature": "${FEATURE4}", "iteration": 1}
EOF

RESULT4=$(echo '{"trigger": "auto"}' | \
  CLAUDE_WORKFLOW_STATE_DIR="$TMPSTATE4" bash "$SAVE_PROGRESS_SCRIPT" 2>/dev/null)

if echo "$RESULT4" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); assert d.get('decision') == 'block', repr(d)"; then
  run_test "blocking: stdout is decision:block JSON" "PASS"
else
  run_test "blocking: stdout is decision:block JSON" "FAIL: got: ${RESULT4:0:200}"
fi

OVERFLOW_COUNT4=$(ls "$TMPSTATE4"/compact-overflow-*.log 2>/dev/null | wc -l | tr -d ' ')
if [[ "$OVERFLOW_COUNT4" -eq 0 ]]; then
  run_test "blocking: no overflow file created (short output)" "PASS"
else
  run_test "blocking: no overflow file created (short output)" "FAIL: found $OVERFLOW_COUNT4 overflow files"
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi