#!/usr/bin/env bash
# test-parallel-dispatch-wired.sh
# Audit F1: the EXISTING-but-dormant parallel-dispatch.md Use Case 1 (N-way
# concurrent code-researcher dispatch) must be WIRED into planner.md Phase 3
# background_mode, with the single-bundled-researcher path preserved as fallback.
# Content-anchored assertions.
set -euo pipefail
SCRIPT_NAME="$(basename "$0")"
PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
label() { echo "[${SCRIPT_NAME}] $1: $2" >&2; }
fail() { label "FAIL" "$1"; exit 1; }
pass() { label "PASS" "$1"; }
cd "$PROJECT_ROOT"

PLANNER=".claude/commands/planner.md"
PD=".claude/skills/workflow-protocols/parallel-dispatch.md"

# AC-F1-1: planner.md now references parallel-dispatch.md (closes the GT2 discoverability gap)
grep -qF "parallel-dispatch.md" "$PLANNER" \
  || fail "AC-F1-1 — planner.md does not reference parallel-dispatch.md"
pass "AC-F1-1 — planner.md references parallel-dispatch.md (gap closed)"

# AC-F1-2: background_mode has a parallel_fanout block dispatching one researcher per layer in a single message
grep -qF "parallel_fanout" "$PLANNER" \
  || fail "AC-F1-2 — planner.md missing parallel_fanout block"
grep -qF "PER independent layer in a SINGLE message" "$PLANNER" \
  || fail "AC-F1-2 — parallel_fanout missing the per-layer single-message dispatch instruction"
pass "AC-F1-2 — parallel_fanout block instructs N-way per-layer single-message dispatch"

# AC-F1-4: the existing single-bundled-researcher path is preserved (no regression)
grep -qF "fall back to blocking Task delegation" "$PLANNER" \
  || fail "AC-F1-4 — single-researcher fallback line removed (regression)"
grep -qF 'subagent_type: "code-researcher"' "$PLANNER" \
  || fail "AC-F1-4 — single-researcher delegation_example removed (regression)"
pass "AC-F1-4 — single-bundled-researcher fallback path preserved"

# AC-F1-3: parallel-dispatch.md Use Case 1 label reflects wired status (not bare EXISTING)
grep -qF "(WIRED" "$PD" \
  || fail "AC-F1-3 — Use Case 1 label not updated to WIRED status"
grep -qF "/planner Phase 3 (EXISTING)" "$PD" \
  && fail "AC-F1-3 — Use Case 1 still carries the stale bare (EXISTING) label"
pass "AC-F1-3 — parallel-dispatch.md Use Case 1 relabelled to WIRED"

label "PASS" "test-parallel-dispatch-wired.sh — all assertions met"
