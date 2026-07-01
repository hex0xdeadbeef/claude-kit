#!/usr/bin/env bash
# test-checkpoint-selection-mtime.sh — P2 fix: checkpoint selectors must use mtime, not alphabetical
# Audit ref: .claude/prompts/workflow-hook-loop-audit.md § P2
# Plan ref:  .claude/prompts/p2-checkpoint-mtime-selector.md
#
# Covers:
#   T1: state_render.latest_checkpoint() picks mtime-newest among divergent-order checkpoints
#   T2: latest_checkpoint() returns None on empty state dir
#   T3: tie-break on identical mtimes is deterministic (alphabetically-larger name wins)
#   T4: check-uncommitted.sh bash one-liner picks mtime-newest
#   T5: save-progress-before-compact.sh picks mtime-newest (via additionalContext feature)
#   T6: enrich-context.sh hash-guard reads mtime-newest (verify via hash differing across selections)
#   T7: verify-state-after-compact.sh picks mtime-newest (PR-003 iter-2)
#   T8: inject-review-context.sh picks mtime-newest (PR-003 iter-2)
#   T9: log-permission-denied.sh inline carve-out picks mtime-newest (PR-001 iter-2)

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

TMP_STATE="$(mktemp -d)"
TMP_PROMPTS="$(mktemp -d)"
trap '
  find "$TMP_STATE" -mindepth 1 -delete 2>/dev/null
  rmdir "$TMP_STATE" 2>/dev/null
  find "$TMP_PROMPTS" -mindepth 1 -delete 2>/dev/null
  rmdir "$TMP_PROMPTS" 2>/dev/null
' EXIT

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

# Helper: write two divergent-order checkpoints into a target state dir.
#   alphabetical-last:  z-old-checkpoint.yaml   (older mtime, alphabetically last)
#   mtime-newest:       a-new-checkpoint.yaml   (newer mtime, alphabetically first)
# Returns paths via globals NEWER_CP / OLDER_CP.
seed_divergent_checkpoints() {
  local target="$1"
  local newer_feature="${2:-a-new}"
  local older_feature="${3:-z-old}"
  local newer_phase="${4:-2}"
  local older_phase="${5:-4}"

  NEWER_CP="${target}/${newer_feature}-checkpoint.yaml"
  OLDER_CP="${target}/${older_feature}-checkpoint.yaml"

  # Both files written with simple checkpoint shape (only fields the readers
  # actually consume — feature is derived from filename in all 6 readers).
  cat > "$NEWER_CP" <<EOF
feature: "${newer_feature}"
phase_completed: ${newer_phase}
phase_name: "test"
complexity: "L"
EOF
  cat > "$OLDER_CP" <<EOF
feature: "${older_feature}"
phase_completed: ${older_phase}
phase_name: "test"
complexity: "L"
EOF

  # Back-date OLDER_CP by 1 hour; keep NEWER_CP at current time.  Using
  # os.utime via inline python3 (portable across timezones — touch -t
  # interprets local time per the P1 iter-1 lesson learned).
  python3 - "$NEWER_CP" "$OLDER_CP" <<'PY'
import os, sys, time
newer, older = sys.argv[1], sys.argv[2]
now = time.time()
os.utime(newer, (now, now))
os.utime(older, (now - 3600, now - 3600))   # 1 hour ago
PY
}

# ============================================================================
# T1: state_render.latest_checkpoint() shared helper
# ============================================================================
echo "--- T1: latest_checkpoint() picks mtime-newest among divergent-order checkpoints ---"
seed_divergent_checkpoints "$TMP_STATE"
result=$(LIB_DIR="${KIT_ROOT}/.claude/scripts/lib" TMP="$TMP_STATE" python3 -c "
import sys, os
sys.path.insert(0, os.environ['LIB_DIR'])
import state_render
print(state_render.latest_checkpoint(os.environ['TMP']))
")
[[ "$result" == "$NEWER_CP" ]]; assert_pass "T1 — latest_checkpoint returns mtime-newest (a-new), NOT alphabetical-last (z-old)" "$?"

# ============================================================================
# T2: empty state dir → None
# ============================================================================
echo "--- T2: latest_checkpoint() returns None on empty state dir ---"
empty_dir="$(mktemp -d)"
result=$(LIB_DIR="${KIT_ROOT}/.claude/scripts/lib" TMP="$empty_dir" python3 -c "
import sys, os
sys.path.insert(0, os.environ['LIB_DIR'])
import state_render
r = state_render.latest_checkpoint(os.environ['TMP'])
print('None' if r is None else r)
")
[[ "$result" == "None" ]]; assert_pass "T2 — latest_checkpoint returns None when no checkpoints exist" "$?"
rmdir "$empty_dir"

# ============================================================================
# T3: tie-break on identical mtimes → alphabetically-larger name wins
# ============================================================================
echo "--- T3: tie-break on identical mtimes is deterministic (z > a wins) ---"
tie_dir="$(mktemp -d)"
echo "feature: a" > "${tie_dir}/a-tie-checkpoint.yaml"
echo "feature: z" > "${tie_dir}/z-tie-checkpoint.yaml"
python3 - "${tie_dir}" <<'PY'
import os, sys
import time
d = sys.argv[1]
fixed = time.time()
for name in ("a-tie-checkpoint.yaml", "z-tie-checkpoint.yaml"):
    os.utime(os.path.join(d, name), (fixed, fixed))
PY
result=$(LIB_DIR="${KIT_ROOT}/.claude/scripts/lib" TMP="$tie_dir" python3 -c "
import sys, os
sys.path.insert(0, os.environ['LIB_DIR'])
import state_render
print(state_render.latest_checkpoint(os.environ['TMP']))
")
[[ "$result" == "${tie_dir}/z-tie-checkpoint.yaml" ]]; assert_pass "T3 — equal mtimes → alphabetically-larger wins (z over a)" "$?"
find "$tie_dir" -mindepth 1 -delete; rmdir "$tie_dir"

# ============================================================================
# T4: check-uncommitted.sh bash one-liner
# ============================================================================
echo "--- T4: check-uncommitted.sh:26 (bash) picks mtime-newest ---"
# Run from inside TMP_STATE so the script's relative `ls .claude/workflow-state/...`
# resolves into our isolated fixture.  Build the expected dir structure.
T4_DIR="$(mktemp -d)"
mkdir -p "${T4_DIR}/.claude/workflow-state"
seed_divergent_checkpoints "${T4_DIR}/.claude/workflow-state"
# The script's selector line is the FIRST executable use of $CHECKPOINT.
# Extract the resolved value by sourcing only the variable assignment in a
# subshell with the test dir as cwd.
selected=$(cd "$T4_DIR" && bash -c '
  CHECKPOINT=$(ls -t .claude/workflow-state/*-checkpoint.yaml 2>/dev/null | head -n1)
  echo "$CHECKPOINT"
')
[[ "$selected" == ".claude/workflow-state/a-new-checkpoint.yaml" ]]
assert_pass "T4 — check-uncommitted.sh selector resolves to mtime-newest (a-new)" "$?"
# Belt-and-braces: also verify the actual script's bash source line matches the corrected form
grep -q 'ls -t .claude/workflow-state/\*-checkpoint.yaml.*head -n1' "${KIT_ROOT}/.claude/scripts/check-uncommitted.sh"
assert_pass "T4 — check-uncommitted.sh source line uses ls -t … | head -n1 (no residual tail -1)" "$?"
find "$T4_DIR" -mindepth 1 -delete; rmdir "$T4_DIR"

# ============================================================================
# T5: save-progress-before-compact.sh picks mtime-newest
# ============================================================================
echo "--- T5: save-progress-before-compact.sh additionalContext reflects mtime-newest ---"
seed_divergent_checkpoints "$TMP_STATE"
out=$(echo '{"trigger":"manual"}' \
  | CLAUDE_WORKFLOW_STATE_DIR="$TMP_STATE" CLAUDE_PRECOMPACT_COOLDOWN_S=0 \
    bash "${KIT_ROOT}/.claude/scripts/save-progress-before-compact.sh" 2>/dev/null)
# Manual trigger always emits additionalContext.  Look for the newer feature
# name in the rendered output.  Use python to parse JSON safely.
echo "$out" | NEWER_FEATURE="a-new" OLDER_FEATURE="z-old" python3 -c "
import json, os, sys
d = json.load(sys.stdin)
ac = d.get('additionalContext', '')
newer = os.environ['NEWER_FEATURE']
older = os.environ['OLDER_FEATURE']
# additionalContext must mention the mtime-newer feature, not the alphabetical-last
sys.exit(0 if (newer in ac and older not in ac) else 1)
"
assert_pass "T5 — save-progress-before-compact.sh selects a-new (mtime-newer), not z-old (alphabetical-last)" "$?"

# ============================================================================
# T6: enrich-context.sh hash-guard reads mtime-newest
# ============================================================================
echo "--- T6: enrich-context.sh hash-guard sees mtime-newest checkpoint content ---"
seed_divergent_checkpoints "$TMP_STATE"
# Clear hash file so the first run writes a fresh hash from whichever
# checkpoint the selector picks.
rm -f "${TMP_STATE}/.enrich-last-hash"
echo '{"prompt": "test"}' \
  | CLAUDE_WORKFLOW_STATE_DIR="$TMP_STATE" \
    bash "${KIT_ROOT}/.claude/scripts/enrich-context.sh" >/dev/null 2>&1
written_hash=$(cat "${TMP_STATE}/.enrich-last-hash" 2>/dev/null || echo "")
# Compute the expected hash from each checkpoint independently in python
expected_newer=$(NEWER_CP="$NEWER_CP" python3 -c "
import hashlib, os
print(hashlib.sha256(open(os.environ['NEWER_CP'], 'rb').read()).hexdigest())
")
expected_older=$(OLDER_CP="$OLDER_CP" python3 -c "
import hashlib, os
print(hashlib.sha256(open(os.environ['OLDER_CP'], 'rb').read()).hexdigest())
")
[[ "$written_hash" == "$expected_newer" ]]
assert_pass "T6.a — enrich-context.sh wrote hash of mtime-newer checkpoint (a-new)" "$?"
[[ "$written_hash" != "$expected_older" ]]
assert_pass "T6.b — enrich-context.sh did NOT write hash of alphabetical-last (z-old)" "$?"

# ============================================================================
# T7: verify-state-after-compact.sh picks mtime-newest (PR-003 iter-2)
# ============================================================================
echo "--- T7: verify-state-after-compact.sh additionalContext reflects mtime-newest ---"
seed_divergent_checkpoints "$TMP_STATE"
out=$(echo '{}' \
  | CLAUDE_WORKFLOW_STATE_DIR="$TMP_STATE" \
    bash "${KIT_ROOT}/.claude/scripts/verify-state-after-compact.sh" 2>/dev/null)
echo "$out" | NEWER_FEATURE="a-new" OLDER_FEATURE="z-old" python3 -c "
import json, os, sys
d = json.load(sys.stdin)
ac = d.get('additionalContext', '')
newer = os.environ['NEWER_FEATURE']
older = os.environ['OLDER_FEATURE']
sys.exit(0 if (newer in ac and older not in ac) else 1)
"
assert_pass "T7 — verify-state-after-compact.sh selects a-new (mtime-newer)" "$?"

# ============================================================================
# T8: inject-review-context.sh picks mtime-newest (PR-003 iter-2)
# ============================================================================
echo "--- T8: inject-review-context.sh additionalContext reflects mtime-newest ---"
seed_divergent_checkpoints "$TMP_STATE"
# inject-review-context.sh expects $1 = agent-type and reads payload from stdin
out=$(echo '{"agent_type":"plan-reviewer","session_id":"test-session"}' \
  | CLAUDE_WORKFLOW_STATE_DIR="$TMP_STATE" \
    bash "${KIT_ROOT}/.claude/scripts/inject-review-context.sh" plan-reviewer 2>/dev/null)
echo "$out" | NEWER_FEATURE="a-new" OLDER_FEATURE="z-old" python3 -c "
import json, os, sys
d = json.load(sys.stdin)
# inject-review-context may emit nested hookSpecificOutput.additionalContext
ac = d.get('additionalContext') or d.get('hookSpecificOutput', {}).get('additionalContext') or ''
newer = os.environ['NEWER_FEATURE']
older = os.environ['OLDER_FEATURE']
sys.exit(0 if (newer in ac and older not in ac) else 1)
"
assert_pass "T8 — inject-review-context.sh selects a-new (mtime-newer)" "$?"

# ============================================================================
# T9: log-permission-denied.sh inline carve-out picks mtime-newest (PR-001 iter-2)
# ============================================================================
echo "--- T9: log-permission-denied.sh inline carve-out picks mtime-newest ---"
# log-permission-denied emits retry:true ONLY when the selected checkpoint
# has phase_completed == 2.  We seed two checkpoints with DIFFERENT phase
# values so retry:true emission unambiguously tracks the selection.
T9_STATE="$(mktemp -d)"
# Newer checkpoint at phase_completed: 2 (retry should fire) — alphabetical-FIRST
# Older checkpoint at phase_completed: 4 (retry should NOT fire) — alphabetical-LAST
seed_divergent_checkpoints "$T9_STATE" "a-new" "z-old" 2 4
# log-permission-denied.sh now anchors STATE_DIR to CLAUDE_PROJECT_DIR/REPO_ROOT and
# honours CLAUDE_WORKFLOW_STATE_DIR (stray-.claude fix 2026-07-01), so pin it to the
# seeded sandbox dir explicitly rather than relying on a cwd-relative read.
mkdir -p "${T9_STATE}/.claude/workflow-state"
# Reseed inside the kit-relative path
seed_divergent_checkpoints "${T9_STATE}/.claude/workflow-state" "a-new" "z-old" 2 4
out=$(cd "$T9_STATE" && echo '{"tool_name":"Bash","tool_input":{"command":"echo test"},"reason":"classifier-denied"}' \
  | CLAUDE_WORKFLOW_STATE_DIR="${T9_STATE}/.claude/workflow-state" bash "${KIT_ROOT}/.claude/scripts/log-permission-denied.sh" 2>/dev/null)
# Expected: retry:true (because newer-mtime checkpoint has phase_completed:2)
echo "$out" | python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    retry = d.get('hookSpecificOutput', {}).get('retry')
    sys.exit(0 if retry is True else 1)
except Exception:
    sys.exit(1)
"
assert_pass "T9.a — retry:true emitted (mtime-newer checkpoint has phase=2, alphabetical-last has phase=4)" "$?"
# Belt-and-braces: flip the phases.  Now alphabetical-last has phase=2,
# mtime-newer has phase=4.  With the inline carve-out reading mtime-newer,
# retry should NOT fire.
find "${T9_STATE}/.claude/workflow-state" -mindepth 1 -delete
seed_divergent_checkpoints "${T9_STATE}/.claude/workflow-state" "a-new" "z-old" 4 2
out=$(cd "$T9_STATE" && echo '{"tool_name":"Bash","tool_input":{"command":"echo test"},"reason":"classifier-denied"}' \
  | CLAUDE_WORKFLOW_STATE_DIR="${T9_STATE}/.claude/workflow-state" bash "${KIT_ROOT}/.claude/scripts/log-permission-denied.sh" 2>/dev/null)
# Expected: NO retry emission (output should be empty, since the script
# only prints when emit_retry is True).
if [[ -z "$(echo "$out" | tr -d '[:space:]')" ]]; then
  echo "  PASS: T9.b — retry NOT emitted (mtime-newer checkpoint has phase=4; alphabetical-last has phase=2 — old buggy selector would have emitted retry)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: T9.b — got output: $out"
  FAIL=$((FAIL + 1))
fi
find "$T9_STATE" -mindepth 1 -delete; rmdir "$T9_STATE"

# ============================================================================
echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
