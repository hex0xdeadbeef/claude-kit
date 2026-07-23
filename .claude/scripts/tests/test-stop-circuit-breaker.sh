#!/usr/bin/env bash
# test-stop-circuit-breaker.sh — P3 fix: per-session circuit breaker for check-uncommitted.sh Stop hook
# Audit ref: .claude/prompts/workflow-hook-loop-audit.md § P3
# Plan ref:  .claude/prompts/p3-stop-circuit-breaker.md
#
# Covers:
#   T1: 5 consecutive blocks with same session_id + same UNCOMMITTED → 1..4 block, 5 WARN + exit 0
#   T2: UNCOMMITTED count change resets counter (next block re-fires as NEW_COUNT=1)
#   T3: counter file content shape `COUNT:UNCOMMITTED` after each block
#   T4: parallel sessions isolated by session_id (no cross-talk)
#   T5: missing/empty session_id falls back to .stop-block-attempts-default
#   T6: contract preservation — decision:block JSON shape byte-identical on attempts 1..4
#   T7: clean git state (UNCOMMITTED=0) → no counter file created
#   T8: session-analytics.sh SessionEnd cleanup deletes all .stop-block-attempts-*

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
HOOK="${KIT_ROOT}/.claude/scripts/check-uncommitted.sh"
SESSION_END_HOOK="${KIT_ROOT}/.claude/scripts/session-analytics.sh"

PASS=0
FAIL=0

assert_pass() {
  local name="$1"; local rc="$2"
  if [[ "$rc" == "0" ]]; then
    echo "  PASS: $name"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $name"; FAIL=$((FAIL + 1))
  fi
}

# Build an isolated git repo with N uncommitted files.
# Returns via globals: REPO_DIR, STATE_DIR
build_repo_with_uncommitted() {
  local n_uncommitted="$1"
  REPO_DIR="$(mktemp -d)"
  STATE_DIR="${REPO_DIR}/.claude/workflow-state"
  mkdir -p "$STATE_DIR"
  cd "$REPO_DIR"
  git init -q
  git config user.email "test@test"
  git config user.name "test"
  # Initial commit so HEAD exists
  echo "init" > .gitkeep
  git add .gitkeep
  git commit -q -m "init" --no-verify
  # Create N untracked files
  for i in $(seq 1 "$n_uncommitted"); do
    echo "x" > "uncommitted-${i}.txt"
  done
  # Add a fresh workflow checkpoint so IS_WORKFLOW=true
  cat > "${STATE_DIR}/test-feature-checkpoint.yaml" <<EOF
feature: "test-feature"
phase_completed: 2
complexity: "L"
EOF
  cd - >/dev/null
}

# Run the Stop hook from inside REPO_DIR with a given session_id (or empty).
# Captures stdout (JSON) and stderr separately.
run_stop_hook() {
  local sid="$1"
  local input
  if [[ -n "$sid" ]]; then
    input="{\"session_id\":\"${sid}\"}"
  else
    input=""
  fi
  cd "$REPO_DIR"
  # CLAUDE_WORKFLOW_STATE_DIR pins the sandbox state dir (stray-.claude fix 2026-07-01:
  # check-uncommitted.sh now anchors STATE_DIR_LOCAL to CLAUDE_PROJECT_DIR/REPO_ROOT when unset).
  STDOUT=$(echo "$input" | CLAUDE_WORKFLOW_STATE_DIR="$STATE_DIR" bash "$HOOK" 2>/tmp/p3-stderr.$$)
  STDERR=$(cat /tmp/p3-stderr.$$)
  rm -f /tmp/p3-stderr.$$
  cd - >/dev/null
}

is_block_json() {
  echo "$1" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    sys.exit(0 if d.get('decision') == 'block' else 1)
except Exception:
    sys.exit(1)
" 2>/dev/null
}

echo "=== test-stop-circuit-breaker.sh ==="

# ============================================================================
# T1: 5 consecutive blocks with same session_id + same UNCOMMITTED count
# ============================================================================
echo "--- T1 (AC-P3.1): 5 consecutive blocks → attempts 1..4 block, 5 WARN + allow ---"
build_repo_with_uncommitted 3
for i in 1 2 3 4; do
  run_stop_hook "session-T1"
  is_block_json "$STDOUT"
  assert_pass "T1.${i} — attempt ${i} → decision:block" "$?"
done
# 5th attempt: should NOT block; should emit WARN
run_stop_hook "session-T1"
is_block_json "$STDOUT" && r=1 || r=0
assert_pass "T1.5 — attempt 5 → no decision:block" "$r"
echo "$STDERR" | grep -qE '^\[check-uncommitted\] WARN: 5 consecutive blocks for 3 uncommitted file\(s\)'
assert_pass "T1.5 — WARN line follows kit convention with exact count" "$?"
find "$REPO_DIR" -mindepth 1 -delete 2>/dev/null; rmdir "$REPO_DIR" 2>/dev/null || true

# ============================================================================
# T2: UNCOMMITTED count change → counter resets
# ============================================================================
echo "--- T2 (AC-P3.2): count change resets counter ---"
build_repo_with_uncommitted 3
run_stop_hook "session-T2"; run_stop_hook "session-T2"; run_stop_hook "session-T2"
# After 3 blocks with 3 files. Counter file should say "3:3"
cat "${STATE_DIR}/.stop-block-attempts-session-T2" | grep -q "^3:3$"
assert_pass "T2.a — after 3 blocks with 3 files, counter is '3:3'" "$?"
# User makes progress: remove one uncommitted file → now 2 uncommitted
rm -f "${REPO_DIR}/uncommitted-1.txt"
run_stop_hook "session-T2"
# Should block (NEW_COUNT=1 because UNCOMMITTED changed from 3→2)
is_block_json "$STDOUT"; assert_pass "T2.b — after count change → block fires again (not WARN)" "$?"
cat "${STATE_DIR}/.stop-block-attempts-session-T2" | grep -q "^1:2$"
assert_pass "T2.c — counter reset to '1:2' (NEW_COUNT=1, UNCOMMITTED=2)" "$?"
find "$REPO_DIR" -mindepth 1 -delete 2>/dev/null; rmdir "$REPO_DIR" 2>/dev/null || true

# ============================================================================
# T3: counter file content shape after each block
# ============================================================================
echo "--- T3: counter file content shape COUNT:UNCOMMITTED ---"
build_repo_with_uncommitted 3
for i in 1 2 3 4; do
  run_stop_hook "session-T3"
  expected="${i}:3"
  actual=$(cat "${STATE_DIR}/.stop-block-attempts-session-T3" 2>/dev/null)
  [[ "$actual" == "$expected" ]]
  assert_pass "T3.${i} — counter file content '${expected}'" "$?"
done
find "$REPO_DIR" -mindepth 1 -delete 2>/dev/null; rmdir "$REPO_DIR" 2>/dev/null || true

# ============================================================================
# T4: parallel sessions isolated
# ============================================================================
echo "--- T4: parallel sessions isolated by session_id ---"
build_repo_with_uncommitted 3
# Session s1: 3 blocks
for i in 1 2 3; do run_stop_hook "s1"; done
# Session s2: 3 blocks
for i in 1 2 3; do run_stop_hook "s2"; done
# Both should have their own counter file
[[ -f "${STATE_DIR}/.stop-block-attempts-s1" ]]; assert_pass "T4.a — s1 counter exists" "$?"
[[ -f "${STATE_DIR}/.stop-block-attempts-s2" ]]; assert_pass "T4.b — s2 counter exists" "$?"
grep -q "^3:3$" "${STATE_DIR}/.stop-block-attempts-s1"; assert_pass "T4.c — s1 counter is '3:3' (3 blocks, not 6)" "$?"
grep -q "^3:3$" "${STATE_DIR}/.stop-block-attempts-s2"; assert_pass "T4.d — s2 counter is '3:3' (3 blocks, not 6)" "$?"
find "$REPO_DIR" -mindepth 1 -delete 2>/dev/null; rmdir "$REPO_DIR" 2>/dev/null || true

# ============================================================================
# T5: missing session_id → fall back to .stop-block-attempts-default
# ============================================================================
echo "--- T5 (AC-P3.5): missing session_id falls back to 'default' bucket ---"
build_repo_with_uncommitted 3
run_stop_hook ""   # empty stdin → no session_id
run_stop_hook ""
[[ -f "${STATE_DIR}/.stop-block-attempts-default" ]]
assert_pass "T5.a — fallback bucket '.stop-block-attempts-default' created when stdin empty" "$?"
grep -q "^2:3$" "${STATE_DIR}/.stop-block-attempts-default"
assert_pass "T5.b — fallback bucket increments correctly (count=2)" "$?"
# After 3 more in default bucket (total 5) → 5th attempt should WARN+allow
for i in 3 4; do run_stop_hook ""; done
run_stop_hook ""   # 5th
is_block_json "$STDOUT" && r=1 || r=0
assert_pass "T5.c — 5th attempt on default bucket → no decision:block (breaker fires)" "$r"
echo "$STDERR" | grep -qE '^\[check-uncommitted\] WARN: 5 consecutive blocks'
assert_pass "T5.d — default bucket triggers WARN line" "$?"
find "$REPO_DIR" -mindepth 1 -delete 2>/dev/null; rmdir "$REPO_DIR" 2>/dev/null || true

# ============================================================================
# T6: contract preservation — decision:block JSON byte-identical on attempts 1..4
# ============================================================================
echo "--- T6 (AC-P3.10): decision:block JSON shape preserved on attempts 1..4 ---"
build_repo_with_uncommitted 7
run_stop_hook "session-T6"
echo "$STDOUT" | python3 -c "
import json, sys
d = json.load(sys.stdin)
keys = sorted(d.keys())
assert keys == ['decision', 'reason'], f'Unexpected keys: {keys}'
assert d['decision'] == 'block'
assert d['reason'] == '7 uncommitted file(s). Run git add + git commit before stopping.', f'Unexpected reason: {d[\"reason\"]}'
"
assert_pass "T6 — block payload keys={decision,reason}; reason='7 uncommitted file(s). Run git add + git commit before stopping.'" "$?"
find "$REPO_DIR" -mindepth 1 -delete 2>/dev/null; rmdir "$REPO_DIR" 2>/dev/null || true

# ============================================================================
# T7: clean state (UNCOMMITTED=0) → no counter file
# ============================================================================
echo "--- T7: clean git state → no counter file created ---"
# Build repo with NO uncommitted files
REPO_DIR="$(mktemp -d)"
STATE_DIR="${REPO_DIR}/.claude/workflow-state"
mkdir -p "$STATE_DIR"
cd "$REPO_DIR"
git init -q
git config user.email "test@test"
git config user.name "test"
echo "init" > .gitkeep
git add .gitkeep
git commit -q -m "init" --no-verify
cd - >/dev/null
run_stop_hook "session-T7"
# Hook should exit 0 with no output and no counter file
[[ -z "$STDOUT" ]]; assert_pass "T7.a — clean state → no stdout" "$?"
[[ ! -f "${STATE_DIR}/.stop-block-attempts-session-T7" ]]; assert_pass "T7.b — clean state → no counter file" "$?"
find "$REPO_DIR" -mindepth 1 -delete 2>/dev/null; rmdir "$REPO_DIR" 2>/dev/null || true

# ============================================================================
# T7.c: non-git invocation — drain stdin cleanly, exit 0, no counter file
# Pins the invariant that the stdin drain runs BEFORE the git rev-parse
# short-circuit so the harness's piped JSON is always consumed (preventing
# SIGPIPE on the next event).  A future refactor moving the drain below the
# git check would silently break this; this test would catch it.
# ============================================================================
echo "--- T7.c (CR-002): non-git invocation → drain stdin + exit 0 + no counter ---"
NONGIT_DIR="$(mktemp -d)"
# No git init — directory is NOT a git repo
cd "$NONGIT_DIR"
STDOUT_NG=$(echo '{"session_id":"session-T7c","reason":"end"}' | bash "$HOOK" 2>&1)
NG_RC=$?
cd - >/dev/null
[[ "$NG_RC" == "0" ]]; assert_pass "T7.c.a — non-git invocation exits 0" "$?"
[[ -z "$STDOUT_NG" ]]; assert_pass "T7.c.b — non-git invocation emits no stdout/stderr" "$?"
# No counter file should be created anywhere reachable via default STATE_DIR
[[ ! -f "${NONGIT_DIR}/.claude/workflow-state/.stop-block-attempts-session-T7c" ]]
assert_pass "T7.c.c — non-git invocation does NOT create counter file" "$?"
find "$NONGIT_DIR" -mindepth 1 -delete 2>/dev/null; rmdir "$NONGIT_DIR" 2>/dev/null || true

# ============================================================================
# T7.d: malicious session_id with path-traversal chars → default bucket
# ============================================================================
echo "--- T7.d (CR-001): session_id with '/' or '..' falls back to default bucket ---"
build_repo_with_uncommitted 3
# Pre-create the attacker-prepped sibling directory
mkdir -p "${STATE_DIR}/.stop-block-attempts-evil"
# Send malicious session_id
cd "$REPO_DIR"
echo '{"session_id":"evil/HIJACK"}' | CLAUDE_WORKFLOW_STATE_DIR="$STATE_DIR" bash "$HOOK" >/dev/null 2>&1
cd - >/dev/null
# Counter should go to .stop-block-attempts-default, NOT into the evil dir
[[ ! -f "${STATE_DIR}/.stop-block-attempts-evil/HIJACK" ]]
assert_pass "T7.d.a — malicious session_id does NOT write inside attacker-prepped dir" "$?"
[[ -f "${STATE_DIR}/.stop-block-attempts-default" ]]
assert_pass "T7.d.b — malicious session_id falls back to .stop-block-attempts-default" "$?"
# Also test '..' and other shell-unsafe chars
echo '{"session_id":"../escape"}' | (cd "$REPO_DIR" && CLAUDE_WORKFLOW_STATE_DIR="$STATE_DIR" bash "$HOOK" >/dev/null 2>&1)
[[ ! -f "${STATE_DIR}/../escape" ]] && [[ ! -f "${REPO_DIR}/.claude/workflow-state/.stop-block-attempts-../escape" ]]
assert_pass "T7.d.c — session_id with '..' falls back to default (no parent-dir escape)" "$?"
find "$REPO_DIR" -mindepth 1 -delete 2>/dev/null; rmdir "$REPO_DIR" 2>/dev/null || true

# ============================================================================
# T8: SessionEnd cleanup deletes .stop-block-attempts-*
# session-analytics.sh is invoked under CLAUDE_WORKFLOW_STATE_DIR=sandbox
# so analytics JSONL append does NOT pollute the real .claude/workflow-state/.
# ============================================================================
echo "--- T8: session-analytics.sh SessionEnd cleanup deletes all .stop-block-attempts-* ---"
TMP_STATE="$(mktemp -d)"
# Seed multiple counter files
touch "${TMP_STATE}/.stop-block-attempts-foo"
touch "${TMP_STATE}/.stop-block-attempts-bar"
touch "${TMP_STATE}/.stop-block-attempts-default"
# Verify they exist
[[ -f "${TMP_STATE}/.stop-block-attempts-foo" ]] && [[ -f "${TMP_STATE}/.stop-block-attempts-bar" ]] && [[ -f "${TMP_STATE}/.stop-block-attempts-default" ]]
assert_pass "T8.a — 3 counter files seeded" "$?"
# Run session-analytics.sh with the temp dir as STATE_DIR (sandbox)
echo '{"session_id":"sess-T8","reason":"end"}' \
  | CLAUDE_WORKFLOW_STATE_DIR="$TMP_STATE" bash "$SESSION_END_HOOK" >/dev/null 2>&1
# All counter files should be gone
[[ ! -f "${TMP_STATE}/.stop-block-attempts-foo" ]] && [[ ! -f "${TMP_STATE}/.stop-block-attempts-bar" ]] && [[ ! -f "${TMP_STATE}/.stop-block-attempts-default" ]]
assert_pass "T8.b — all 3 counter files removed after SessionEnd" "$?"
# Sandbox isolation: session-analytics.jsonl was written to TMP_STATE, not real STATE_DIR
[[ -f "${TMP_STATE}/session-analytics.jsonl" ]]
assert_pass "T8.c — session-analytics.jsonl written to sandbox (PR-002 isolation)" "$?"
find "$TMP_STATE" -mindepth 1 -delete 2>/dev/null; rmdir "$TMP_STATE" 2>/dev/null || true

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
