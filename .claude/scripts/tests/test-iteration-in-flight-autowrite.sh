#!/usr/bin/env bash
# test-iteration-in-flight-autowrite.sh — P5 fix: inject-review-context.sh
# auto-writes .iteration-in-flight for review agents at SubagentStart.
# Audit ref: .claude/prompts/workflow-hook-loop-audit.md § P5
# Plan ref:  .claude/prompts/p5-iif-autowrite.md
#
# Covers:
#   T1: plan-reviewer → .iteration-in-flight created with correct shape
#   T2: code-reviewer → same
#   T3: verdict-recovery → .iteration-in-flight NOT created
#   T4: feature field extracted from mtime-newest checkpoint
#   T5: no-checkpoint fallback — feature="unknown"
#   T6: idempotency — hook overwrites orchestrator-written IIF
#   T7: --sidecar-only invocation also writes IIF (worktree code-reviewer path)
#   T8: write failure → WARN stderr; hook continues with context injection
#   T9: contract-preservation — auto-written IIF triggers PreCompact decision:block

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
HOOK="${KIT_ROOT}/.claude/scripts/inject-review-context.sh"
PRECOMPACT_HOOK="${KIT_ROOT}/.claude/scripts/save-progress-before-compact.sh"

PASS=0
FAIL=0

# Per-test temp dir (cleaned per test).  Outer trap is a safety net.
TMP_OUTER="$(mktemp -d)"
trap '
  # Restore perms in case T8 left a chmod 555 dir
  chmod 755 "$TMP_OUTER" 2>/dev/null || true
  find "$TMP_OUTER" -type d -exec chmod 755 {} + 2>/dev/null || true
  find "$TMP_OUTER" -mindepth 1 -delete 2>/dev/null || true
  rmdir "$TMP_OUTER" 2>/dev/null || true
' EXIT

assert_pass() {
  local name="$1"; local rc="$2"
  if [[ "$rc" == "0" ]]; then
    echo "  PASS: $name"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $name"; FAIL=$((FAIL + 1))
  fi
}

# Build a fresh isolated state dir under TMP_OUTER with a synthetic checkpoint.
# Returns: STATE_DIR (global)
fresh_state_with_checkpoint() {
  local feature="${1:-test-feature}"
  STATE_DIR="$(mktemp -d -p "$TMP_OUTER")"
  cat > "${STATE_DIR}/${feature}-checkpoint.yaml" <<EOF
feature: "${feature}"
phase_completed: 2
complexity: "L"
EOF
}

# Fresh isolated state dir with NO checkpoint.
fresh_state_no_checkpoint() {
  STATE_DIR="$(mktemp -d -p "$TMP_OUTER")"
}

run_hook() {
  local agent_type="$1"; shift
  CLAUDE_WORKFLOW_STATE_DIR="$STATE_DIR" \
    bash "$HOOK" "$agent_type" "$@" < /dev/null > /dev/null 2>&1
}

echo "=== test-iteration-in-flight-autowrite.sh ==="

# ============================================================================
# T1 (AC-P5.1 step 2-3): plan-reviewer → IIF created with correct shape
# ============================================================================
echo "--- T1: plan-reviewer invocation creates IIF with correct shape ---"
fresh_state_with_checkpoint "feat-T1"
run_hook plan-reviewer
[[ -f "${STATE_DIR}/.iteration-in-flight" ]]
assert_pass "T1.a — .iteration-in-flight created" "$?"
python3 -c "
import json
d = json.load(open('${STATE_DIR}/.iteration-in-flight'))
assert d['agent'] == 'plan-reviewer', f'agent={d[\"agent\"]}'
assert d['source'] == 'inject-review-context.sh', f'source={d[\"source\"]}'
assert d['feature'] == 'feat-T1', f'feature={d[\"feature\"]}'
assert 'started_at' in d
"
assert_pass "T1.b — JSON has agent=plan-reviewer, source=inject-review-context.sh, feature=feat-T1" "$?"

# ============================================================================
# T2 (AC-P5.1 step 4): code-reviewer → same
# ============================================================================
echo "--- T2: code-reviewer invocation creates IIF ---"
fresh_state_with_checkpoint "feat-T2"
run_hook code-reviewer
[[ -f "${STATE_DIR}/.iteration-in-flight" ]]
assert_pass "T2.a — .iteration-in-flight created" "$?"
python3 -c "
import json
d = json.load(open('${STATE_DIR}/.iteration-in-flight'))
assert d['agent'] == 'code-reviewer', f'agent={d[\"agent\"]}'
assert d['source'] == 'inject-review-context.sh'
"
assert_pass "T2.b — JSON has agent=code-reviewer" "$?"

# ============================================================================
# T3 (AC-P5.1 step 5): verdict-recovery → IIF NOT created
# ============================================================================
echo "--- T3: verdict-recovery invocation does NOT create IIF ---"
fresh_state_with_checkpoint "feat-T3"
run_hook verdict-recovery
[[ ! -f "${STATE_DIR}/.iteration-in-flight" ]]
assert_pass "T3 — .iteration-in-flight NOT created for verdict-recovery" "$?"

# ============================================================================
# T4: feature field extracted from mtime-newest checkpoint (P2 convention)
# ============================================================================
echo "--- T4: feature field extracted from mtime-newest checkpoint ---"
fresh_state_no_checkpoint
# Create two checkpoints; older alphabetically-last, newer alphabetically-first
cat > "${STATE_DIR}/a-newer-feat-checkpoint.yaml" <<EOF
feature: "a-newer-feat"
EOF
cat > "${STATE_DIR}/z-older-feat-checkpoint.yaml" <<EOF
feature: "z-older-feat"
EOF
# Back-date the alphabetically-last one to 1 hour ago via os.utime
python3 - "${STATE_DIR}/z-older-feat-checkpoint.yaml" <<'PY'
import os, sys, time
os.utime(sys.argv[1], (time.time() - 3600, time.time() - 3600))
PY
run_hook plan-reviewer
python3 -c "
import json
d = json.load(open('${STATE_DIR}/.iteration-in-flight'))
assert d['feature'] == 'a-newer-feat', f'feature={d[\"feature\"]} (expected a-newer-feat, the mtime-newer one)'
"
assert_pass "T4 — feature extracted from mtime-newest checkpoint (not alphabetical-last)" "$?"

# ============================================================================
# T5: no-checkpoint fallback — feature="unknown"
# ============================================================================
echo "--- T5: no-checkpoint fallback yields feature=unknown ---"
fresh_state_no_checkpoint
run_hook plan-reviewer
[[ -f "${STATE_DIR}/.iteration-in-flight" ]]
assert_pass "T5.a — IIF still created when no checkpoint exists" "$?"
python3 -c "
import json
d = json.load(open('${STATE_DIR}/.iteration-in-flight'))
assert d['feature'] == 'unknown', f'feature={d[\"feature\"]}'
assert d['agent'] == 'plan-reviewer'
"
assert_pass "T5.b — feature='unknown' fallback applied" "$?"

# ============================================================================
# T6: idempotency — hook overwrites orchestrator-written IIF
# ============================================================================
echo "--- T6: hook overwrites orchestrator-written IIF (idempotent) ---"
fresh_state_with_checkpoint "feat-T6"
# Simulate orchestrator writing an IIF with the legacy shape (includes iteration)
cat > "${STATE_DIR}/.iteration-in-flight" <<'EOF'
{"agent":"plan-reviewer","started_at":"2026-04-23T14:30:00Z","feature":"feat-T6","iteration":1}
EOF
run_hook plan-reviewer
# After the hook fires, the file should now have the new shape (with source field)
python3 -c "
import json
d = json.load(open('${STATE_DIR}/.iteration-in-flight'))
assert d['agent'] == 'plan-reviewer'
assert d['source'] == 'inject-review-context.sh', 'expected source field after hook overwrite'
# legacy 'iteration' field should be absent (hook does not emit it)
assert 'iteration' not in d, 'hook should not preserve legacy iteration field'
"
assert_pass "T6 — hook overwrite produces the new shape (source field present, iteration field absent)" "$?"

# ============================================================================
# T7 (AC-P5.3): --sidecar-only invocation also writes IIF
# ============================================================================
echo "--- T7: --sidecar-only invocation writes IIF (worktree path) ---"
fresh_state_with_checkpoint "feat-T7"
run_hook code-reviewer --sidecar-only --sidecar-name=code-reviewer
[[ -f "${STATE_DIR}/.iteration-in-flight" ]]
assert_pass "T7.a — IIF created under --sidecar-only invocation" "$?"
python3 -c "
import json
d = json.load(open('${STATE_DIR}/.iteration-in-flight'))
assert d['agent'] == 'code-reviewer'
assert d['source'] == 'inject-review-context.sh'
"
assert_pass "T7.b — sidecar-mode JSON has agent=code-reviewer + source field" "$?"

# ============================================================================
# T8 (AC-P5.4): write failure → WARN stderr; hook continues
# ============================================================================
echo "--- T8: write failure (chmod 555) → WARN stderr + hook continues ---"
fresh_state_with_checkpoint "feat-T8"
# Make state dir non-writable AFTER seeding the checkpoint (so reads still work)
chmod 555 "$STATE_DIR"
# Capture stderr from the hook invocation
stderr_t8=$(echo '{"agent_type":"plan-reviewer","session_id":"sess-T8"}' \
  | CLAUDE_WORKFLOW_STATE_DIR="$STATE_DIR" \
    bash "$HOOK" plan-reviewer 2>&1 >/dev/null)
# Restore perms for cleanup
chmod 755 "$STATE_DIR"
# IIF should NOT exist (write failed); hook should have logged WARN
[[ ! -f "${STATE_DIR}/.iteration-in-flight" ]]
assert_pass "T8.a — IIF not created when state dir is non-writable" "$?"
echo "$stderr_t8" | grep -qE '^\[inject-review-context\] WARN: failed to write \.iteration-in-flight'
assert_pass "T8.b — WARN line follows kit convention '[inject-review-context] WARN: failed to write .iteration-in-flight'" "$?"

# ============================================================================
# T9 (AC-P5.7 load-bearing): auto-written IIF triggers PreCompact decision:block
# Demonstrates the consumer contract is preserved — auto-written IIF is
# functionally equivalent to orchestrator-written one.
# ============================================================================
echo "--- T9: auto-written IIF triggers PreCompact decision:block (contract preservation) ---"
fresh_state_with_checkpoint "feat-T9"
# Step 1: invoke the hook to create the IIF via the new auto-write path
run_hook plan-reviewer
[[ -f "${STATE_DIR}/.iteration-in-flight" ]]
assert_pass "T9.a — auto-written IIF present after hook fires" "$?"
# Step 2: invoke PreCompact with trigger=auto and assert decision:block
precompact_out=$(echo '{"trigger":"auto"}' \
  | CLAUDE_WORKFLOW_STATE_DIR="$STATE_DIR" CLAUDE_PRECOMPACT_COOLDOWN_S=0 \
    bash "$PRECOMPACT_HOOK" 2>/dev/null)
echo "$precompact_out" | python3 -c "
import json, sys
d = json.load(sys.stdin)
sys.exit(0 if d.get('decision') == 'block' else 1)
" 2>/dev/null
assert_pass "T9.b — PreCompact emits decision:block consuming the auto-written IIF" "$?"
# Step 3: assert the block reason mentions the agent extracted from IIF
echo "$precompact_out" | python3 -c "
import json, sys
d = json.load(sys.stdin)
reason = d.get('reason', '')
sys.exit(0 if 'plan-reviewer' in reason else 1)
" 2>/dev/null
assert_pass "T9.c — block reason mentions 'plan-reviewer' (agent field consumed correctly)" "$?"

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
