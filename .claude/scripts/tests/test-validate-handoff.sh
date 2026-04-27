#!/usr/bin/env bash
# test-validate-handoff.sh — smoke tests for validate-handoff.sh
# Usage: bash .claude/scripts/tests/test-validate-handoff.sh
# Covers: AC-3, AC-4, AC-5 + direct/hook dual-mode regression (CR-001)
#         + AC-P1..AC-P5 (handoff-validation-investigation iter 2)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE="${SCRIPT_DIR}/../validate-handoff.sh"
FIXTURES="${SCRIPT_DIR}/fixtures"
# REPO_ROOT for AC-P1-3 env-unset legacy-fallback test (PR-d1a15e56)
REPO_ROOT_RESOLVED="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Temp dir for hook-mode fixtures that need specific filenames (*-handoff.json guard)
TMPDIR_HOOK="$(mktemp -d -t validate-handoff-tests.XXXXXX)"

# Part 6 / P1 verification: sandbox the log path for ALL tests so prod log is never
# polluted. Replaces ad-hoc per-test cleanup. Without this, the existing 18 tests would
# continue to write to prod .claude/workflow-state/handoff-validation.jsonl.
TMP_LOG_DIR="$(mktemp -d -t validate-handoff-logs.XXXXXX)"
export CLAUDE_WORKFLOW_STATE_DIR="${TMP_LOG_DIR}"

trap 'rm -rf "${TMPDIR_HOOK}" "${TMP_LOG_DIR}"' EXIT

PASS=0
FAIL=0

# Helper: run direct-mode test (file path as argv)
# Args: test_name expected_exit_code mode fixture_file
run_test() {
  local name="$1"
  local expected_exit="$2"
  local mode="$3"
  local file="$4"

  # Test isolation: unset ALL validation-mode envs to prevent env-leak from
  # settings.local.json (e.g., CLAUDE_ISSUE_ID_VALIDATION_MODE=strict promoting
  # verdict mode → strict via validate-handoff.sh L88).
  unset CLAUDE_HANDOFF_VALIDATION_MODE
  unset CLAUDE_VERDICT_VALIDATION_MODE
  unset CLAUDE_ISSUE_ID_VALIDATION_MODE
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

  # Test isolation: unset ALL validation-mode envs (see run_test rationale).
  unset CLAUDE_HANDOFF_VALIDATION_MODE
  unset CLAUDE_VERDICT_VALIDATION_MODE
  unset CLAUDE_ISSUE_ID_VALIDATION_MODE
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

# D2 (post-1.17-symmetry-audit): coder_to_code_review handoff contract — schema 1.1.0 additive
run_test \
  "valid coder_to_code_review (warn, direct)" \
  0 "warn" \
  "${FIXTURES}/valid-coder-to-code-review.json"

run_test \
  "valid coder_to_code_review (strict, direct)" \
  0 "strict" \
  "${FIXTURES}/valid-coder-to-code-review.json"

run_test \
  "invalid coder_to_code_review missing-required (strict, direct)" \
  2 "strict" \
  "${FIXTURES}/invalid-coder-to-code-review-missing-required.json"

run_test \
  "invalid coder_to_code_review bad-iteration (strict, direct)" \
  2 "strict" \
  "${FIXTURES}/invalid-coder-to-code-review-bad-iteration.json"

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

# ─── Verdict-envelope tests (IMP-02) ────────────────────────────────────────────
# Mirrors run_test pattern but drives CLAUDE_VERDICT_VALIDATION_MODE instead of
# CLAUDE_HANDOFF_VALIDATION_MODE. Unsets handoff mode to prevent env leakage if
# a prior IMP-01 test left CLAUDE_HANDOFF_VALIDATION_MODE=strict.
run_verdict_test() {
  local name="$1"
  local expected_exit="$2"
  local mode="$3"
  local file="$4"

  # Test isolation: unset ALL validation-mode envs (see run_test rationale).
  unset CLAUDE_HANDOFF_VALIDATION_MODE
  unset CLAUDE_VERDICT_VALIDATION_MODE
  unset CLAUDE_ISSUE_ID_VALIDATION_MODE
  export CLAUDE_VERDICT_VALIDATION_MODE="${mode}"
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

echo ""
echo "─── Verdict-envelope tests (IMP-02) ───"

run_verdict_test "valid plan_review_verdict (warn)" \
  0 "warn" "${FIXTURES}/valid-plan-verdict.json"

run_verdict_test "valid code_review_verdict (warn)" \
  0 "warn" "${FIXTURES}/valid-code-verdict.json"

run_verdict_test "valid empty issues APPROVED (strict)" \
  0 "strict" "${FIXTURES}/valid-empty-issues-verdict.json"

run_verdict_test "invalid wrong enum for plan (strict)" \
  2 "strict" "${FIXTURES}/invalid-wrong-enum-for-plan.json"

run_verdict_test "invalid missing \$verdict_contract (strict)" \
  2 "strict" "${FIXTURES}/invalid-missing-verdict-contract.json"

run_verdict_test "invalid malformed fields (strict)" \
  2 "strict" "${FIXTURES}/invalid-malformed-verdict-fields.json"

run_verdict_test "invalid wrong enum (warn mode → non-blocking)" \
  0 "warn" "${FIXTURES}/invalid-wrong-enum-for-plan.json"

# ─── handoff-validation-investigation iter 2: Parts 1-5 regression coverage ───
echo ""
echo "─── Part 1 (P1) — log-path env override ───"

# AC-P1-1: With CLAUDE_WORKFLOW_STATE_DIR set, log file appears in sandbox.
# Iter 2 (PR-ccde5b0a): use INLINE env passing (not export/restore) so test ordering
# is decoupled and the global TMP_LOG_DIR sandbox is never mutated.
ISOLATED_DIR="$(mktemp -d -t handoff-test-isolated.XXXXXX)"
unset CLAUDE_HANDOFF_VALIDATION_MODE CLAUDE_VERDICT_VALIDATION_MODE CLAUDE_ISSUE_ID_VALIDATION_MODE
CLAUDE_WORKFLOW_STATE_DIR="${ISOLATED_DIR}" \
  bash "${VALIDATE}" "${FIXTURES}/valid-planner-to-review.json" >/dev/null 2>&1
if [[ -f "${ISOLATED_DIR}/handoff-validation.jsonl" ]]; then
  echo "  PASS: AC-P1-1 — log written to sandbox path (env-override active)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: AC-P1-1 — log NOT in sandbox: ${ISOLATED_DIR}/handoff-validation.jsonl"
  FAIL=$((FAIL + 1))
fi
rm -rf "${ISOLATED_DIR}"

# AC-P1-3 (PR-d1a15e56): env-UNSET → legacy fallback path resolution.
# Use bash -x trace + non-existent file so the existence guard exits BEFORE the log
# append, giving us ZERO side effects on the prod log while still observing the
# resolved VALIDATION_LOG value in the trace.
EXPECTED_LEGACY_LOG="${REPO_ROOT_RESOLVED}/.claude/workflow-state/handoff-validation.jsonl"
NONEXISTENT_PATH="/tmp/handoff-validation-nonexistent-$$-$(date +%s).json"
TRACE_OUTPUT=$(env -u CLAUDE_WORKFLOW_STATE_DIR \
                   -u CLAUDE_HANDOFF_VALIDATION_MODE \
                   -u CLAUDE_VERDICT_VALIDATION_MODE \
                   -u CLAUDE_ISSUE_ID_VALIDATION_MODE \
                   bash -x "${VALIDATE}" "${NONEXISTENT_PATH}" 2>&1 1>/dev/null \
                | grep -F "VALIDATION_LOG=" \
                | head -1)
if [[ "${TRACE_OUTPUT}" == *"${EXPECTED_LEGACY_LOG}"* ]]; then
  echo "  PASS: AC-P1-3 — env-unset → VALIDATION_LOG resolves to legacy path (no prod-log write)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: AC-P1-3 — expected substring '${EXPECTED_LEGACY_LOG}' in bash -x trace, got: ${TRACE_OUTPUT}"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "─── Part 2 (P2) — log rotation ───"

ROTATE_DIR="$(mktemp -d -t handoff-test-rotate.XXXXXX)"
ROTATE_LOG="${ROTATE_DIR}/handoff-validation.jsonl"
mkdir -p "${ROTATE_DIR}"
# Pre-populate log with 6 synthetic entries
for i in $(seq 1 6); do echo "{\"line\":${i}}"; done > "${ROTATE_LOG}"

# AC-P2-1 + AC-P2-2: With MAX_LINES=5, next validate should rotate (current=6 > 5)
unset CLAUDE_HANDOFF_VALIDATION_MODE CLAUDE_VERDICT_VALIDATION_MODE CLAUDE_ISSUE_ID_VALIDATION_MODE
CLAUDE_WORKFLOW_STATE_DIR="${ROTATE_DIR}" \
  CLAUDE_VALIDATION_LOG_MAX_LINES=5 \
  bash "${VALIDATE}" "${FIXTURES}/valid-planner-to-review.json" >/dev/null 2>&1

if [[ -f "${ROTATE_LOG}.1" ]]; then
  echo "  PASS: AC-P2-1+2 — rotation produced .log.1 archive"
  PASS=$((PASS + 1))
else
  echo "  FAIL: AC-P2-1+2 — no .log.1 archive after over-threshold append"
  FAIL=$((FAIL + 1))
fi

# AC-P2-3: rotation does not block validation if log is read-only
chmod 444 "${ROTATE_LOG}" 2>/dev/null || true
RC_LOCKED=0
CLAUDE_WORKFLOW_STATE_DIR="${ROTATE_DIR}" \
  bash "${VALIDATE}" "${FIXTURES}/valid-planner-to-review.json" >/dev/null 2>&1 || RC_LOCKED=$?
if [[ "${RC_LOCKED}" -eq 0 ]]; then
  echo "  PASS: AC-P2-3 — validation rc=0 even when log read-only"
  PASS=$((PASS + 1))
else
  echo "  FAIL: AC-P2-3 — got rc=${RC_LOCKED}"
  FAIL=$((FAIL + 1))
fi
chmod 644 "${ROTATE_LOG}" 2>/dev/null || true
rm -rf "${ROTATE_DIR}"

echo ""
echo "─── Part 3 (P3) — verbose error visibility ───"

VERBOSE_DIR="$(mktemp -d -t handoff-test-verbose.XXXXXX)"
unset CLAUDE_HANDOFF_VALIDATION_MODE CLAUDE_VERDICT_VALIDATION_MODE CLAUDE_ISSUE_ID_VALIDATION_MODE
CLAUDE_WORKFLOW_STATE_DIR="${VERBOSE_DIR}" \
  CLAUDE_VERDICT_VALIDATION_MODE=strict \
  bash "${VALIDATE}" "${FIXTURES}/invalid-wrong-enum-for-plan.json" >/dev/null 2>&1
DETAIL_FILE="${VERBOSE_DIR}/handoff-validation-detail.log"
# AC-P3-1: primary error must mention APPROVED_WITH_COMMENTS not in enum
if [[ -f "${DETAIL_FILE}" ]] && grep -q "APPROVED_WITH_COMMENTS.*is not one of" "${DETAIL_FILE}" 2>/dev/null; then
  echo "  PASS: AC-P3-1 — primary error visible in detail log"
  PASS=$((PASS + 1))
else
  echo "  FAIL: AC-P3-1 — primary error not visible (--verbose missing or not propagating)"
  FAIL=$((FAIL + 1))
fi
rm -rf "${VERBOSE_DIR}"

echo ""
echo "─── Part 4 (P4) — record_kind shape detection ───"

P4_DIR="$(mktemp -d -t handoff-test-p4.XXXXXX)"
unset CLAUDE_HANDOFF_VALIDATION_MODE CLAUDE_VERDICT_VALIDATION_MODE CLAUDE_ISSUE_ID_VALIDATION_MODE
CLAUDE_WORKFLOW_STATE_DIR="${P4_DIR}" \
  bash "${VALIDATE}" "${FIXTURES}/invalid-missing-verdict-contract.json" >/dev/null 2>&1
LAST_KIND=$(tail -1 "${P4_DIR}/handoff-validation.jsonl" 2>/dev/null \
  | jq -r '.record_kind' 2>/dev/null)
# AC-P4-1: record_kind = verdict_no_discriminator
if [[ "${LAST_KIND}" == "verdict_no_discriminator" ]]; then
  echo "  PASS: AC-P4-1 — verdict-shape misclassified as 'verdict_no_discriminator'"
  PASS=$((PASS + 1))
else
  echo "  FAIL: AC-P4-1 — got record_kind='${LAST_KIND}', expected 'verdict_no_discriminator'"
  FAIL=$((FAIL + 1))
fi

# AC-P4-2: true-unknown shape ({foo: bar}) preserves record_kind=unknown
TRUE_UNK="${P4_DIR}/true-unknown.json"
echo '{"foo":"bar"}' > "${TRUE_UNK}"
CLAUDE_WORKFLOW_STATE_DIR="${P4_DIR}" \
  bash "${VALIDATE}" "${TRUE_UNK}" >/dev/null 2>&1
LAST_KIND_UNK=$(tail -1 "${P4_DIR}/handoff-validation.jsonl" 2>/dev/null \
  | jq -r '.record_kind' 2>/dev/null)
if [[ "${LAST_KIND_UNK}" == "unknown" ]]; then
  echo "  PASS: AC-P4-2 — true-unknown payload preserved as 'unknown'"
  PASS=$((PASS + 1))
else
  echo "  FAIL: AC-P4-2 — got '${LAST_KIND_UNK}', expected 'unknown'"
  FAIL=$((FAIL + 1))
fi
rm -rf "${P4_DIR}"

echo ""
echo "─── Part 5 (P5) — JSONL detail log ───"

P5_DIR="$(mktemp -d -t handoff-test-p5.XXXXXX)"
unset CLAUDE_HANDOFF_VALIDATION_MODE CLAUDE_VERDICT_VALIDATION_MODE CLAUDE_ISSUE_ID_VALIDATION_MODE
CLAUDE_WORKFLOW_STATE_DIR="${P5_DIR}" \
  bash "${VALIDATE}" "${FIXTURES}/invalid-missing-required.json" >/dev/null 2>&1
P5_DETAIL="${P5_DIR}/handoff-validation-detail.log"

# AC-P5-1: every line in NEWLY-CREATED detail.log is valid JSON.
# Iter 2 (PR-41eaff6f): comment clarified — assertion scope is the freshly-created
# sandbox detail.log, NOT the production detail.log. Real prod log may have legacy
# plain-text entries from pre-Part-5 runs (mixed format is acceptable per plan
# § Part 5 backward-compat note). Once P2 rotation archives the legacy entries
# to .log.1, the live .log naturally becomes JSONL-only.
P5_JSON_OK=1
if [[ -f "${P5_DETAIL}" ]]; then
  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    if ! echo "${line}" | jq -e . >/dev/null 2>&1; then
      P5_JSON_OK=0
      break
    fi
  done < "${P5_DETAIL}"
fi
if [[ "${P5_JSON_OK}" -eq 1 && -f "${P5_DETAIL}" ]]; then
  echo "  PASS: AC-P5-1 — every NEW detail.log line is valid JSON"
  PASS=$((PASS + 1))
else
  echo "  FAIL: AC-P5-1 — non-JSON line found in fresh sandbox detail.log"
  FAIL=$((FAIL + 1))
fi

# AC-P5-2: required fields present (timestamp, file, record_kind, rc, error_summary, full_output)
LAST_DETAIL=$(tail -1 "${P5_DETAIL}" 2>/dev/null)
P5_FIELDS_OK=$(echo "${LAST_DETAIL}" | jq -r '
  if (.timestamp and .file and .record_kind and (.rc != null) and .error_summary and .full_output)
  then "yes" else "no" end' 2>/dev/null)
if [[ "${P5_FIELDS_OK}" == "yes" ]]; then
  echo "  PASS: AC-P5-2 — all required fields present"
  PASS=$((PASS + 1))
else
  echo "  FAIL: AC-P5-2 — missing required field(s) in: ${LAST_DETAIL}"
  FAIL=$((FAIL + 1))
fi

# AC-P5-3: jq query on .error_summary returns a non-empty string
P5_SUMMARY=$(echo "${LAST_DETAIL}" | jq -r '.error_summary' 2>/dev/null)
if [[ -n "${P5_SUMMARY}" && "${P5_SUMMARY}" != "null" ]]; then
  echo "  PASS: AC-P5-3 — jq -r .error_summary returns prose"
  PASS=$((PASS + 1))
else
  echo "  FAIL: AC-P5-3 — error_summary empty or null"
  FAIL=$((FAIL + 1))
fi
rm -rf "${P5_DIR}"

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
