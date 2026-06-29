#!/usr/bin/env bash
# test-stop-subagentstop-additional-context.sh
#
# CC 2.1.163: Stop and SubagentStop hooks may return hookSpecificOutput.additionalContext
# on an ALLOW path (no decision:block) to give Claude in-context feedback without being a
# hook error. This test locks two allow-path emissions:
#   Site A — check-uncommitted.sh circuit-breaker branch (Stop): after STOP_BLOCK_MAX
#            consecutive blocks the hook allows stop and now emits additionalContext.
#   Site B — save-review-checkpoint.sh IMP-H second-attempt branch (SubagentStop): when a
#            review agent still has UNKNOWN verdict after one block, the hook allows stop
#            and now emits additionalContext.
# Regression: the decision:block branches (Site A attempts 1..N-1, Site B first attempt)
# stay byte-identical. additionalContext text is free-form orchestrator feedback and is
# NEVER a canonical-ID hash input (sha256(category|location|problem)).

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
STOP_HOOK="${KIT_ROOT}/.claude/scripts/check-uncommitted.sh"
SAVE_HOOK="${KIT_ROOT}/.claude/scripts/save-review-checkpoint.sh"
command -v python3 >/dev/null 2>&1 || { echo "SKIP: python3 required"; exit 0; }

PASS=0; FAIL=0
ok(){ echo "  PASS: $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL: $1"; FAIL=$((FAIL+1)); }
assert(){ if [[ "$2" == "0" ]]; then ok "$1"; else no "$1"; fi; }

echo "=== test-stop-subagentstop-additional-context.sh ==="

# ── Site A helpers (mirror test-stop-circuit-breaker.sh) ──
build_repo() {
  REPO_DIR="$(mktemp -d)"; STATE_DIR="${REPO_DIR}/.claude/workflow-state"; mkdir -p "$STATE_DIR"
  ( cd "$REPO_DIR"
    git init -q; git config user.email t@t; git config user.name t
    echo init > .gitkeep; git add .gitkeep; git commit -q -m init --no-verify
    echo x > uncommitted-1.txt; echo x > uncommitted-2.txt; echo x > uncommitted-3.txt
    printf 'feature: "f"\nphase_completed: 2\ncomplexity: "L"\n' > "${STATE_DIR}/f-checkpoint.yaml" )
}
run_stop() {  # sid -> sets STDOUT/RC
  STDOUT=$(cd "$REPO_DIR" && echo "{\"session_id\":\"$1\"}" | bash "$STOP_HOOK" 2>/dev/null); RC=$?
}
has_decision_block(){ echo "$1" | python3 -c "import json,sys
try: sys.exit(0 if json.load(sys.stdin).get('decision')=='block' else 1)
except Exception: sys.exit(1)"; }
is_addl_ctx(){ # arg1=json arg2=expected hookEventName ; pass iff single object, hookEventName matches, additionalContext non-empty, NO decision
  echo "$1" | python3 -c "
import json,sys
ev=sys.argv[1]
d=json.load(sys.stdin)              # raises on trailing data (PR-002: exactly one object)
h=d.get('hookSpecificOutput',{})
assert 'decision' not in d, 'decision key present on allow path'
assert h.get('hookEventName')==ev, f\"hookEventName={h.get('hookEventName')}\"
assert h.get('additionalContext'), 'additionalContext empty'
" "$2"; }

echo "--- Site A: check-uncommitted circuit-breaker (Stop) ---"
build_repo
run_stop sA   # attempt 1 → decision:block (regression)
has_decision_block "$STDOUT"; assert "A1 attempt 1 emits decision:block (regression byte-stable)" "$?"
# keys byte-identical {decision,reason}
echo "$STDOUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert sorted(d)== ['decision','reason']" 2>/dev/null
assert "A1 block payload keys == {decision,reason}" "$?"
for i in 2 3 4; do run_stop sA; done   # attempts 2..4 block
run_stop sA   # attempt 5 → circuit breaker ALLOW + additionalContext
assert "A5 attempt 5 exits 0" "$([[ "$RC" == 0 ]] && echo 0 || echo 1)"
is_addl_ctx "$STDOUT" Stop; assert "A5 circuit-breaker emits single Stop additionalContext, no decision" "$?"
find "$REPO_DIR" -mindepth 1 -delete 2>/dev/null; rmdir "$REPO_DIR" 2>/dev/null || true

echo "--- Site B: save-review-checkpoint IMP-H second-attempt (SubagentStop) ---"
SB="$(mktemp -d)"   # FIXED sandbox across both calls so the .verdict-block marker persists
PAY="$(python3 -c "import json; print(json.dumps({'agent_type':'plan-reviewer','agent_id':'aid-B','session_id':'sB','last_assistant_message':'Review done. No verdict line here.'}))")"
# Call 1: UNKNOWN verdict, no marker → decision:block (regression) + marker created
OUT1=$(echo "$PAY" | CLAUDE_WORKFLOW_STATE_DIR="$SB" bash "$SAVE_HOOK" 2>/dev/null); RC1=$?
has_decision_block "$OUT1"; assert "B1 first attempt emits decision:block (regression)" "$?"
[[ -f "$SB/.verdict-block-aid-B" ]]; assert "B1 verdict-block marker created" "$?"
# Call 2: marker exists → ALLOW + additionalContext (SubagentStop), single object, marker removed
OUT2=$(echo "$PAY" | CLAUDE_WORKFLOW_STATE_DIR="$SB" bash "$SAVE_HOOK" 2>/dev/null); RC2=$?
assert "B2 second attempt exits 0" "$([[ "$RC2" == 0 ]] && echo 0 || echo 1)"
is_addl_ctx "$OUT2" SubagentStop; assert "B2 emits single SubagentStop additionalContext, no decision (PR-002 one object)" "$?"
[[ ! -f "$SB/.verdict-block-aid-B" ]]; assert "B2 verdict-block marker removed on second attempt" "$?"
rm -rf "$SB"

echo ""
echo "  RESULT: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] && { echo "PASS: test-stop-subagentstop-additional-context"; exit 0; } || { echo "FAIL: test-stop-subagentstop-additional-context"; exit 1; }
