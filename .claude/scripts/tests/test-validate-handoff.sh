#!/usr/bin/env bash
# test-validate-handoff.sh — smoke tests for validate-handoff.sh
# Usage: bash .claude/scripts/tests/test-validate-handoff.sh
# Covers: AC-3, AC-4, AC-5 (and two additional coverage cases)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE="${SCRIPT_DIR}/../validate-handoff.sh"
FIXTURES="${SCRIPT_DIR}/fixtures"

PASS=0
FAIL=0

# Helper: run one test case
# Args: test_name expected_exit_code mode fixture_file
run_test() {
  local name="$1"
  local expected_exit="$2"
  local mode="$3"
  local file="$4"

  export CLAUDE_HANDOFF_VALIDATION_MODE="${mode}"
  actual_exit=0
  bash "${VALIDATE}" "${file}" >/dev/null 2>&1 || actual_exit=$?

  if [[ "${actual_exit}" -eq "${expected_exit}" ]]; then
    echo "  PASS: ${name} (exit=${actual_exit})"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: ${name} (expected exit=${expected_exit}, got exit=${actual_exit})"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== validate-handoff smoke tests ==="

# AC-3: valid planner_to_plan_review → exit 0 in warn mode
run_test \
  "valid planner_to_plan_review (warn)" \
  0 "warn" \
  "${FIXTURES}/valid-planner-to-review.json"

# AC-3 (second contract): valid plan_review_to_coder → exit 0 in warn mode
run_test \
  "valid plan_review_to_coder (warn)" \
  0 "warn" \
  "${FIXTURES}/valid-review-to-coder.json"

# AC-4: invalid missing-required → exit 2 in strict mode
run_test \
  "invalid missing-required (strict)" \
  2 "strict" \
  "${FIXTURES}/invalid-missing-required.json"

# AC-5: invalid missing-required → exit 0 in warn mode (warn does not block)
run_test \
  "invalid missing-required (warn)" \
  0 "warn" \
  "${FIXTURES}/invalid-missing-required.json"

# AC-4 (extra): invalid bad enum value → exit 2 in strict mode
run_test \
  "invalid bad-enum verdict (strict)" \
  2 "strict" \
  "${FIXTURES}/invalid-bad-enum.json"

# Summary
echo ""
echo "Results: ${PASS} PASS, ${FAIL} FAIL"
echo ""

if [[ "${FAIL}" -gt 0 ]]; then
  echo "FAIL: ${FAIL} test(s) did not pass." >&2
  exit 1
fi
echo "All tests passed."
exit 0
