#!/usr/bin/env bash
# test-validate-handoff.sh — smoke tests for validate-handoff.sh
# Usage: bash .claude/scripts/tests/test-validate-handoff.sh
# Covers: AC-3, AC-4, AC-5 + direct/hook dual-mode regression (CR-001)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE="${SCRIPT_DIR}/../validate-handoff.sh"
FIXTURES="${SCRIPT_DIR}/fixtures"

# Temp dir for hook-mode fixtures that need specific filenames (*-handoff.json guard)
TMPDIR_HOOK="$(mktemp -d -t validate-handoff-tests.XXXXXX)"
trap 'rm -rf "${TMPDIR_HOOK}"' EXIT

PASS=0
FAIL=0

# Helper: run direct-mode test (file path as argv)
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

# Helper: run hook-mode test (stdin JSON with tool_input.file_path)
# Args: test_name expected_exit_code mode file_path
run_hook_test() {
  local name="$1"
  local expected_exit="$2"
  local mode="$3"
  local file_path="$4"

  export CLAUDE_HANDOFF_VALIDATION_MODE="${mode}"
  actual_exit=0
  printf '{"tool_input":{"file_path":"%s"}}' "${file_path}" \
    | bash "${VALIDATE}" >/dev/null 2>&1 || actual_exit=$?

  if [[ "${actual_exit}" -eq "${expected_exit}" ]]; then
    echo "  PASS: ${name} (exit=${actual_exit})"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: ${name} (expected exit=${expected_exit}, got exit=${actual_exit})"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== validate-handoff smoke tests ==="

# ─── Direct mode (argv) ─────────────────────────────────────────────────────────

# AC-3: valid planner_to_plan_review → exit 0 in warn mode
run_test \
  "valid planner_to_plan_review (warn, direct)" \
  0 "warn" \
  "${FIXTURES}/valid-planner-to-review.json"

# AC-3 (second contract): valid plan_review_to_coder → exit 0 in warn mode
run_test \
  "valid plan_review_to_coder (warn, direct)" \
  0 "warn" \
  "${FIXTURES}/valid-review-to-coder.json"

# AC-4: invalid missing-required → exit 2 in strict mode
run_test \
  "invalid missing-required (strict, direct)" \
  2 "strict" \
  "${FIXTURES}/invalid-missing-required.json"

# AC-5: invalid missing-required → exit 0 in warn mode (warn does not block)
run_test \
  "invalid missing-required (warn, direct)" \
  0 "warn" \
  "${FIXTURES}/invalid-missing-required.json"

# AC-4 (extra): invalid bad enum value → exit 2 in strict mode
run_test \
  "invalid bad-enum verdict (strict, direct)" \
  2 "strict" \
  "${FIXTURES}/invalid-bad-enum.json"

# ─── Hook mode (stdin JSON) ─────────────────────────────────────────────────────
# CR-001: hook invocation path was previously untested. These two cases cover:
#   (a) the filename guard that skips non-handoff writes (cheap path)
#   (b) the validation path through stdin JSON parsing (full pipeline)

# Fixture with a name that does NOT end in -handoff.json → guard should exit 0
# without attempting validation. Even though the content would fail strict mode,
# strict mode must not trigger because the guard fires first.
run_hook_test \
  "hook guard skips non-handoff filename (strict)" \
  0 "strict" \
  "${FIXTURES}/invalid-missing-required.json"

# Fixture copied to a *-handoff.json filename → guard permits, validation runs.
# Use a valid fixture so we verify the hook path reaches the validator cleanly.
HOOK_VALID_FIXTURE="${TMPDIR_HOOK}/imp-01-test-handoff.json"
cp "${FIXTURES}/valid-planner-to-review.json" "${HOOK_VALID_FIXTURE}"
run_hook_test \
  "hook validates *-handoff.json filename (warn)" \
  0 "warn" \
  "${HOOK_VALID_FIXTURE}"

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
