#!/usr/bin/env bash
# test-precompact-cooldown.sh — smoke tests for P1 PreCompact decision:block cooldown
# Audit ref: .claude/prompts/workflow-hook-loop-audit.md § P1, AC-P1.1..7
# Plan ref:  .claude/prompts/p1-precompact-cooldown.md
#
# Covers:
#   T1 (AC-P1.1): 2 consecutive auto-blocks vs same sentinel → 1 block + 1 cooldown-pass
#   T2 (AC-P1.2): 3rd auto-block after cooldown elapses → block again
#   T3 (AC-P1.4): manual trigger never sees cooldown
#   T4 (AC-P1.5): mid-Part Phase 3 block path obeys cooldown
#   T5 (AC-P1.6): cooldown-stamp write failure → legacy block + WARN
#   T6 (AC-P1.7): hook-log.txt records BLOCKED + COOLDOWN_PASS
#   T7 (bonus):  sentinel-mtime-reset rule (fresh sentinel → block again)
#   T8 (bonus):  CLAUDE_PRECOMPACT_COOLDOWN_S=0 disables cooldown
#   T9 (AC-P1.11): safety floor — CLAUDE_PRECOMPACT_COOLDOWN_S=1 clamped to 30

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="${SCRIPT_DIR}/../save-progress-before-compact.sh"

TMP_STATE="$(mktemp -d)"
trap 'find "$TMP_STATE" -mindepth 1 -delete 2>/dev/null; rmdir "$TMP_STATE" 2>/dev/null' EXIT

ITER_FILE="${TMP_STATE}/.iteration-in-flight"
STAMP_FILE="${TMP_STATE}/.precompact-last-block"
LOG_FILE="${TMP_STATE}/hook-log.txt"

PASS=0
FAIL=0

run_hook() {
  local trigger="${1:-auto}"
  local cooldown="${2:-5}"
  echo "{\"trigger\": \"$trigger\"}" \
    | CLAUDE_WORKFLOW_STATE_DIR="$TMP_STATE" \
      CLAUDE_PRECOMPACT_COOLDOWN_S="$cooldown" \
      bash "$HOOK" 2>/dev/null
}

run_hook_capture_stderr() {
  local trigger="${1:-auto}"
  local cooldown="${2:-5}"
  echo "{\"trigger\": \"$trigger\"}" \
    | CLAUDE_WORKFLOW_STATE_DIR="$TMP_STATE" \
      CLAUDE_PRECOMPACT_COOLDOWN_S="$cooldown" \
      bash "$HOOK" 2>&1 >/dev/null
}

has_decision_block() {
  echo "$1" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    sys.exit(0 if d.get('decision') == 'block' else 1)
except Exception:
    sys.exit(1)
" 2>/dev/null
}

has_additional_context_with() {
  local needle="$2"
  echo "$1" | NEEDLE="$needle" python3 -c "
import json, os, sys
try:
    d = json.load(sys.stdin)
    ac = d.get('additionalContext', '')
    sys.exit(0 if os.environ['NEEDLE'] in ac else 1)
except Exception:
    sys.exit(1)
" 2>/dev/null
}

assert_pass() {
  local name="$1"; local cond_rc="$2"
  if [[ "$cond_rc" == "0" ]]; then
    echo "  PASS: $name"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $name"; FAIL=$((FAIL + 1))
  fi
}

reset_state() {
  find "$TMP_STATE" -mindepth 1 -delete 2>/dev/null || true
}

write_sentinel() {
  echo "{\"agent\": \"${1:-plan-reviewer}\", \"feature\": \"test\", \"iteration\": 1}" > "$ITER_FILE"
}

write_midpart_checkpoint() {
  # Create a checkpoint file with Phase 3 mid-Part state (phase_completed: 2, current_part > 0)
  cat > "${TMP_STATE}/midpart-checkpoint.yaml" <<EOF
feature: "midpart-test"
phase_completed: 2
phase_name: "implementation"
iteration:
  plan_review: "1/3"
  code_review: "0/3"
implementation_progress:
  parts_completed: 1
  parts_total: 3
  current_part: 2
  sub_phase: "implement"
  auto_saved: true
complexity: "L"
EOF
}

echo "=== test-precompact-cooldown.sh ==="
echo ""

# -------------------------------------------------------------------
echo "--- T1 (AC-P1.1): 2 auto-blocks vs same sentinel → 1 block + 1 cooldown-pass ---"
reset_state
write_sentinel "plan-reviewer"
out1="$(run_hook auto 5)"
has_decision_block "$out1"; assert_pass "T1.a — 1st auto invocation → decision:block" "$?"
out2="$(run_hook auto 5)"
has_decision_block "$out2" && r=1 || r=0  # we want NO decision here
assert_pass "T1.b — 2nd auto invocation (within cooldown) → no decision:block" "$r"
has_additional_context_with "$out2" "COOLDOWN"; assert_pass "T1.c — 2nd invocation → additionalContext contains COOLDOWN" "$?"
has_additional_context_with "$out2" "Review iteration in progress"; assert_pass "T1.d — 2nd invocation → original block reason preserved in additionalContext" "$?"

# -------------------------------------------------------------------
echo ""
echo "--- T2 (AC-P1.2): 3rd auto-block after cooldown elapses → block again ---"
# Cooldown floor is 30s. To exercise the elapse path quickly without sleeping 30s,
# back-date stamp and sentinel mtimes via os.utime (portable across timezones —
# touch -t interprets its argument as LOCAL time, which broke the original test
# when combined with date -u UTC formatting on non-UTC hosts).
#
# Constraints:
#   stamp mtime: T-60 (older than cooldown=30 → expect block to fire)
#   sentinel mtime: T-90 (older than stamp so reset rule does NOT trigger,
#                         but YOUNGER than the 30-min staleness window so the
#                         existing auto-delete path does NOT fire and the
#                         block path is exercised)
write_sentinel "plan-reviewer"
run_hook auto 5 >/dev/null  # first call writes stamp
python3 - "$STAMP_FILE" "$ITER_FILE" <<'PY'
import os, sys, time
stamp, sentinel = sys.argv[1], sys.argv[2]
now = time.time()
os.utime(stamp,    (now - 60, now - 60))   # stamp 60s old (elapsed > cooldown=30)
os.utime(sentinel, (now - 90, now - 90))   # sentinel 90s old (older than stamp, <30min)
PY
out3="$(run_hook auto 30)"  # cooldown=30; stamp is 60s old; 60 > 30 → block
has_decision_block "$out3"; assert_pass "T2 — auto after cooldown elapsed → decision:block (re-block)" "$?"

# -------------------------------------------------------------------
echo ""
echo "--- T3 (AC-P1.4): manual trigger never sees cooldown ---"
reset_state
write_sentinel "plan-reviewer"
# Pre-fire one auto block to write the stamp
run_hook auto 5 >/dev/null
# Now manual trigger should NOT block, even with fresh stamp + sentinel
out_m="$(run_hook manual 5)"
has_decision_block "$out_m" && r=1 || r=0
assert_pass "T3 — manual trigger always passes (never blocked)" "$r"

# -------------------------------------------------------------------
echo ""
echo "--- T4 (AC-P1.5): mid-Part Phase 3 block path obeys cooldown ---"
reset_state
write_midpart_checkpoint
# No .iteration-in-flight → first auto fires mid-Part block (block_count 1/3)
out_mp1="$(run_hook auto 5)"
has_decision_block "$out_mp1"; assert_pass "T4.a — mid-Part 1st auto → decision:block" "$?"
# Second auto within cooldown → COOLDOWN_PASS
out_mp2="$(run_hook auto 5)"
has_decision_block "$out_mp2" && r=1 || r=0
assert_pass "T4.b — mid-Part 2nd auto (within cooldown) → no decision:block" "$r"
has_additional_context_with "$out_mp2" "COOLDOWN"; assert_pass "T4.c — mid-Part 2nd auto → COOLDOWN in additionalContext" "$?"

# -------------------------------------------------------------------
echo ""
echo "--- T5 (AC-P1.6): stamp-write failure → legacy block + WARN ---"
reset_state
write_sentinel "plan-reviewer"
# Make the stamp PATH a directory so open(..., 'w') raises OSError
mkdir -p "$STAMP_FILE"
stderr_t5="$(run_hook_capture_stderr auto 5)"
# Stdout should still have decision:block
out_t5="$(echo '{"trigger":"auto"}' | CLAUDE_WORKFLOW_STATE_DIR="$TMP_STATE" CLAUDE_PRECOMPACT_COOLDOWN_S=5 bash "$HOOK" 2>/dev/null)"
has_decision_block "$out_t5"; assert_pass "T5.a — stamp-write failure → block still emitted (fail-open)" "$?"
echo "$stderr_t5" | grep -q '\[save-progress-before-compact\] WARN: cooldown-stamp write failed'
assert_pass "T5.b — stderr WARN follows kit convention '[save-progress-before-compact] WARN: cooldown-stamp write failed:'" "$?"
# Clean up the directory blocker
rmdir "$STAMP_FILE" 2>/dev/null || true

# -------------------------------------------------------------------
echo ""
echo "--- T6 (AC-P1.7): hook-log.txt records BLOCKED + COOLDOWN_PASS ---"
reset_state
write_sentinel "plan-reviewer"
run_hook auto 5 >/dev/null  # block + log "BLOCKED ... cooldown stamp refreshed"
run_hook auto 5 >/dev/null  # cooldown pass + log "COOLDOWN_PASS ..."
grep -q "BLOCKED auto-compact" "$LOG_FILE"; assert_pass "T6.a — hook-log.txt contains 'BLOCKED auto-compact'" "$?"
grep -q "COOLDOWN_PASS auto-compact" "$LOG_FILE"; assert_pass "T6.b — hook-log.txt contains 'COOLDOWN_PASS auto-compact'" "$?"

# -------------------------------------------------------------------
echo ""
echo "--- T7 (bonus): fresh sentinel resets cooldown → block fires again ---"
reset_state
write_sentinel "plan-reviewer"
run_hook auto 5 >/dev/null  # first block writes stamp
# Touch sentinel to bump mtime to a time AFTER the stamp's wall-clock write.
# Even a 1s wait would suffice; use touch with current time to bump deterministically.
sleep 1
touch "$ITER_FILE"
out_t7="$(run_hook auto 90)"  # high cooldown — must still block because sentinel is newer
has_decision_block "$out_t7"; assert_pass "T7 — fresh sentinel mtime > stamp mtime → decision:block re-fires" "$?"

# -------------------------------------------------------------------
echo ""
echo "--- T8 (bonus): CLAUDE_PRECOMPACT_COOLDOWN_S=0 disables cooldown ---"
reset_state
write_sentinel "plan-reviewer"
out_t8a="$(run_hook auto 0)"
has_decision_block "$out_t8a"; assert_pass "T8.a — cooldown=0, 1st auto → decision:block" "$?"
out_t8b="$(run_hook auto 0)"
has_decision_block "$out_t8b"; assert_pass "T8.b — cooldown=0, 2nd auto immediately → still decision:block (legacy)" "$?"
# Verify no stamp file was created in cooldown=0 path
[[ ! -f "$STAMP_FILE" ]]; assert_pass "T8.c — cooldown=0 path does not create stamp file" "$?"
# Verify the legacy log entry is present
grep -q "cooldown disabled via CLAUDE_PRECOMPACT_COOLDOWN_S=0" "$LOG_FILE"
assert_pass "T8.d — hook-log.txt records 'cooldown disabled' marker for legacy path" "$?"

# -------------------------------------------------------------------
echo ""
echo "--- T9 (AC-P1.11): safety floor — cooldown=1 clamped to 30 ---"
reset_state
write_sentinel "plan-reviewer"
out_t9a="$(run_hook auto 1)"  # request 1s, should clamp to 30
has_decision_block "$out_t9a"; assert_pass "T9.a — cooldown=1, 1st auto → decision:block" "$?"
# Wait 2 seconds — if floor were not enforced, cooldown(1s) would have elapsed; block again
sleep 2
# Without bumping sentinel, the second invocation: stamp ~2s old, sentinel older.
# If cooldown were 1s → would block (elapsed > 1). If floor 30s → would COOLDOWN_PASS.
out_t9b="$(run_hook auto 1)"
has_decision_block "$out_t9b" && r=1 || r=0
assert_pass "T9.b — cooldown=1 (clamped to 30), 2s elapsed < 30 → no decision:block (floor enforced)" "$r"

# -------------------------------------------------------------------
echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
