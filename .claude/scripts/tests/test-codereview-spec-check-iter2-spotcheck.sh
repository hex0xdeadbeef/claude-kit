#!/usr/bin/env bash
# test-codereview-spec-check-iter2-spotcheck.sh
# AC-P4-1, AC-P4-2, AC-P4-3, AC-P4-5: iter-2+ spot-check is documented and stable.
set -euo pipefail
SCRIPT_NAME="$(basename "$0")"
PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
label() { echo "[${SCRIPT_NAME}] $1: $2" >&2; }
fail() { label "FAIL" "$1"; exit 1; }
pass() { label "PASS" "$1"; }
cd "$PROJECT_ROOT"

REVIEWER=".claude/agents/code-reviewer.md"
SKILL=".claude/skills/code-review-rules/SKILL.md"
CODER_SKILL=".claude/skills/coder-rules/SKILL.md"

# AC-P4-1a: SKILL.md Spec Check Trust splits by iteration
grep -q '^\*\*Iteration 1:\*\*' "$SKILL" \
  || fail "AC-P4-1a — SKILL.md does not split Spec Check Trust by iteration (Iteration 1 marker missing)"
grep -q '^\*\*Iteration 2+ (CHANGES_REQUESTED loop):\*\*' "$SKILL" \
  || fail "AC-P4-1a — SKILL.md does not split Spec Check Trust by iteration (Iteration 2+ marker missing)"
pass "AC-P4-1a — SKILL.md splits Spec Check Trust by iteration"

# AC-P4-1b: SKILL.md uses git diff --name-only as the spot-check primitive
grep -q 'git diff --name-only \$BASE\.\.\.HEAD' "$SKILL" \
  || fail "AC-P4-1b — SKILL.md does not document git diff --name-only as the spot-check primitive"
pass "AC-P4-1b — spot-check primitive documented"

# AC-P4-1c: stable problem text for MINOR drift finding
grep -q 'Iter ≥2 spot-check: Part .* claimed implemented but no matching changed files' "$SKILL" \
  || fail "AC-P4-1c — stable MINOR problem text not documented in SKILL.md"
pass "AC-P4-1c — stable MINOR problem text present"

# AC-P4-2: iter-1 trust path preserved
grep -q 'iteration == 1' "$REVIEWER" \
  || fail "AC-P4-2 — code-reviewer.md does not preserve iteration==1 trust branch"
grep -q 'TRUST coder spec compliance — skip plan compliance re-check' "$REVIEWER" \
  || fail "AC-P4-2 — code-reviewer.md iter-1 trust message removed"
pass "AC-P4-2 — iter-1 trust path preserved"

# AC-P4-3: output line surfaces which path was taken
grep -q 'Spec compliance: PASS (trusted from coder Phase 3.5)' "$REVIEWER" \
  || fail "AC-P4-3a — iter-1 output line missing"
grep -q 'Spec compliance: PASS (spot-checked iter ≥2)' "$REVIEWER" \
  || fail "AC-P4-3b — iter-2 output line missing"
grep -q 'Spec compliance: PASS (spot-checked iter ≥2 — {N} drift MINOR raised)' "$REVIEWER" \
  || fail "AC-P4-3c — iter-2 with-finding output line missing"
pass "AC-P4-3 — all three output lines documented"

# AC-P4-5: coder-rules informational note added
grep -q 'Reviewer-side note:.*iter-≥2 spot-check on spec_check.status=PASS' "$CODER_SKILL" \
  || fail "AC-P4-5 — coder-rules informational note missing"
pass "AC-P4-5 — coder-rules informational note present"

label "PASS" "test-codereview-spec-check-iter2-spotcheck.sh — all assertions met"
