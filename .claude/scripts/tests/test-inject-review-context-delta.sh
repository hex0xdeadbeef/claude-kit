#!/usr/bin/env bash
# delta-review-mode — documentation + contract regression tests
#
# Usage: bash .claude/scripts/tests/test-inject-review-context-delta.sh
#
# Follows existing IMP-04 test pattern: grep/fixed-string on documentation.
# No hook execution — tests verify static contracts (AC-6, 8 scenarios):
#   Scenario 1:  inject-review-context.sh has emit_delta_focus_block function
#   Scenario 2:  inject-review-context.sh reads CLAUDE_DELTA_REVIEW_MODE env
#   Scenario 3:  inject-review-context.sh has iter_num < 2 early-return guard
#   Scenario 4:  inject-review-context.sh emits [Iter N focus — delta only] phrase
#   Scenario 5:  inject-review-context.sh handles KD-6 fallback string
#   Scenario 6:  inject-review-context.sh has WARN stderr for missing SHA
#   Scenario 7:  delegation-templates.md has STEP SHA + iteration_commit_sha
#   Scenario 8:  plan-reviewer.md + code-reviewer.md have delta interpretation sections

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

INJECT_SH="${REPO_ROOT}/.claude/scripts/inject-review-context.sh"
DELEGATION_MD="${REPO_ROOT}/.claude/skills/workflow-protocols/delegation-templates.md"
PLAN_REVIEWER_MD="${REPO_ROOT}/.claude/agents/plan-reviewer.md"
CODE_REVIEWER_MD="${REPO_ROOT}/.claude/agents/code-reviewer.md"
DIFF_MANIFEST_MD="${REPO_ROOT}/.claude/skills/workflow-protocols/diff-manifest.md"
CLAUDE_MD="${REPO_ROOT}/CLAUDE.md"

cd "${REPO_ROOT}"

PASS=0
FAIL=0

assert_grep() {
  local name="$1"
  local pattern="$2"
  local file="$3"
  if grep -qE "${pattern}" "${file}" 2>/dev/null; then
    echo "  PASS: ${name}"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: ${name}"
    echo "        pattern: ${pattern}"
    echo "        file:    ${file}"
    FAIL=$((FAIL + 1))
  fi
}

assert_fixed_string() {
  local name="$1"
  local needle="$2"
  local file="$3"
  if grep -qF "${needle}" "${file}" 2>/dev/null; then
    echo "  PASS: ${name}"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: ${name}"
    echo "        needle: ${needle}"
    echo "        file:   ${file}"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== delta-review-mode — documentation + contract regression tests ==="
echo

# ─── Scenario 1: emit_delta_focus_block function exists ─────────────────────
echo "Scenario 1: inject-review-context.sh has emit_delta_focus_block function"
assert_fixed_string "function definition" \
  "def emit_delta_focus_block(" "${INJECT_SH}"
echo

# ─── Scenario 2: CLAUDE_DELTA_REVIEW_MODE env read ──────────────────────────
echo "Scenario 2: inject-review-context.sh reads CLAUDE_DELTA_REVIEW_MODE"
assert_fixed_string "env read present" \
  "CLAUDE_DELTA_REVIEW_MODE" "${INJECT_SH}"
assert_fixed_string "off default" \
  '"off"' "${INJECT_SH}"
echo

# ─── Scenario 3: iter_num < 2 early-return guard ────────────────────────────
echo "Scenario 3: iter_num < 2 early-return guard exists"
assert_fixed_string "iter < 2 guard" \
  "if iter_num < 2:" "${INJECT_SH}"
echo

# ─── Scenario 4: [Iter N focus — delta only] phrase emitted ─────────────────
echo "Scenario 4: [Iter N focus — delta only] format string emitted"
assert_grep "focus delta only phrase" \
  'focus.*delta only' "${INJECT_SH}"
echo

# ─── Scenario 5: KD-6 fallback string checked ───────────────────────────────
echo "Scenario 5: KD-6 fallback string check in emit_delta_focus_block"
assert_fixed_string "KD-6 fallback string" \
  "KD-6 fallback" "${INJECT_SH}"
assert_fixed_string "kd6_active variable" \
  "kd6_active" "${INJECT_SH}"
echo

# ─── Scenario 6: WARN stderr for missing iteration_commit_sha ───────────────
echo "Scenario 6: WARN stderr emitted when iteration_commit_sha[N-1] missing"
assert_fixed_string "WARN stderr line present" \
  "iteration_commit_sha[" "${INJECT_SH}"
assert_fixed_string "code delta skipped message" \
  "code delta skipped" "${INJECT_SH}"
echo

# ─── Scenario 7: delegation-templates.md STEP SHA + iteration_commit_sha ────
echo "Scenario 7: delegation-templates.md has STEP SHA and iteration_commit_sha"
assert_fixed_string "STEP SHA label" \
  "STEP SHA" "${DELEGATION_MD}"
assert_fixed_string "iteration_commit_sha field" \
  "iteration_commit_sha" "${DELEGATION_MD}"
assert_fixed_string "git rev-parse HEAD" \
  "git rev-parse HEAD" "${DELEGATION_MD}"
assert_fixed_string "STEP MODE label" \
  "STEP MODE" "${DELEGATION_MD}"
assert_fixed_string "delta_review_mode in delegation" \
  "delta_review_mode" "${DELEGATION_MD}"
echo

# ─── Scenario 8: plan-reviewer.md + code-reviewer.md delta sections ─────────
echo "Scenario 8: plan-reviewer.md + code-reviewer.md have delta interpretation sections"
assert_fixed_string "plan-reviewer delta section heading" \
  "Delta Focus Interpretation (iter 2+)" "${PLAN_REVIEWER_MD}"
assert_fixed_string "plan-reviewer mode: warn" \
  "mode: warn" "${PLAN_REVIEWER_MD}"
assert_fixed_string "plan-reviewer KD-6 fallback" \
  "KD-6 fallback active" "${PLAN_REVIEWER_MD}"
assert_fixed_string "code-reviewer delta section heading" \
  "Delta Focus Interpretation (iter 2+)" "${CODE_REVIEWER_MD}"
assert_fixed_string "code-reviewer ground-truth rule" \
  "ground-truth" "${CODE_REVIEWER_MD}"
assert_fixed_string "code-reviewer prior_sha diff range" \
  "prior_sha}..HEAD" "${CODE_REVIEWER_MD}"
echo

# ─── Extra: CLAUDE.md documents CLAUDE_DELTA_REVIEW_MODE ────────────────────
echo "Extra: CLAUDE.md documents CLAUDE_DELTA_REVIEW_MODE env-flag"
assert_fixed_string "CLAUDE_DELTA_REVIEW_MODE in CLAUDE.md" \
  "CLAUDE_DELTA_REVIEW_MODE" "${CLAUDE_MD}"
assert_fixed_string "diff-manifest.md reviewer consumer section" \
  "Reviewer consumer" "${DIFF_MANIFEST_MD}"
echo

# ─── Summary ─────────────────────────────────────────────────────────────────
TOTAL=$((PASS + FAIL))
echo "=== delta-review-mode test summary ==="
echo "  PASS: ${PASS}/${TOTAL}"
echo "  FAIL: ${FAIL}/${TOTAL}"

if [[ ${FAIL} -gt 0 ]]; then
  exit 1
fi
exit 0
