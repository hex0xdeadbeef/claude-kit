#!/usr/bin/env bash
# test-from-phase-resume-hint.sh
# Audit F2 (Option B): state_render._render_checkpoint_ref must NOT emit an
# out-of-range `--from-phase 5` resume hint for a COMPLETED run (phase_completed=5
# / phase_name=completion) — the run is finished, nothing to resume, and README +
# workflow.md both mark Phase 5 as not independently resumable. The Resume hint
# MUST be preserved verbatim for resumable phases (regression guard). Docs are
# intentionally left unchanged (they already agree). Content-anchored.
set -euo pipefail
SCRIPT_NAME="$(basename "$0")"
PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
label() { echo "[${SCRIPT_NAME}] $1: $2" >&2; }
fail() { label "FAIL" "$1"; exit 1; }
pass() { label "PASS" "$1"; }
cd "$PROJECT_ROOT"

LIB_DIR="${PROJECT_ROOT}/.claude/scripts/lib"

render_checkpoint_ref() {
  # $1 = phase_completed, $2 = phase_name
  LIB_DIR="$LIB_DIR" _PC="$1" _PN="$2" python3 -c "
import os, sys
sys.path.insert(0, os.environ['LIB_DIR'])
import state_render
state = {'feature': 'demo', 'state_dir': '.claude/workflow-state',
         'phase_completed': os.environ['_PC'], 'phase_name': os.environ['_PN']}
print(state_render.render(state, ['checkpoint_ref']))
"
}

# AC-F2-1: completion checkpoint emits NO out-of-range hint + a completion marker.
OUT_DONE=$(render_checkpoint_ref "5" "completion")
echo "$OUT_DONE" | grep -qF -- "--from-phase 5" \
  && fail "AC-F2-1 — completion checkpoint still emits out-of-range '--from-phase 5'"
echo "$OUT_DONE" | grep -qiE "complete|nothing to resume" \
  || fail "AC-F2-1 — completion checkpoint missing a completion/no-resume marker (got: $OUT_DONE)"
pass "AC-F2-1 — completion checkpoint suppresses --from-phase 5, emits completion marker"

# AC-F2-2: regression — a resumable mid-phase checkpoint STILL emits the Resume hint.
OUT_MID=$(render_checkpoint_ref "2" "plan-review")
echo "$OUT_MID" | grep -qF -- "Resume: /workflow --from-phase 2" \
  || fail "AC-F2-2 — non-completion checkpoint lost its Resume hint (got: $OUT_MID)"
pass "AC-F2-2 — non-completion checkpoint preserves 'Resume: /workflow --from-phase 2'"

# AC-F2-3: docs intentionally UNCHANGED — workflow.md range + README Phase 5 row still agree.
grep -qF 'format: "0.7|1-4"' .claude/commands/workflow.md \
  || fail "AC-F2-3 — workflow.md --from-phase range was changed (should stay 0.7|1-4)"
grep -qE '^\| 5 \| 5 \| Completion \| .*—' README.md \
  || fail "AC-F2-3 — README.md Phase 5 row no longer marks --from-phase as not-resumable (—)"
pass "AC-F2-3 — workflow.md range and README Phase 5 row unchanged and consistent"

label "PASS" "test-from-phase-resume-hint.sh — all assertions met"
