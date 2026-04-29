#!/usr/bin/env bash
# test-code-reviewer-batched-greps.sh
# P3 — verify code-reviewer.md has Concurrent gather mode subsection AND that the
# byte-sensitive blocks (## REVIEW ✓ format + VERDICT_JSON sentinel) remain unchanged.
#
# Convention: exit 0 on success, exit 1 on assertion failure.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
FILE="${REPO_ROOT}/.claude/agents/code-reviewer.md"

if [[ ! -f "${FILE}" ]]; then
  echo "[test-code-reviewer-batched-greps] FAIL: code-reviewer.md not found at ${FILE}" >&2
  exit 1
fi

# ---- Test 1: P3 subsection present, mentions env flag ----
if ! grep -q "Concurrent gather mode (opt-in, P3)" "${FILE}"; then
  echo "[test-code-reviewer-batched-greps] FAIL: P3 subsection missing in code-reviewer.md" >&2
  exit 1
fi
if ! grep -q "CLAUDE_PARALLEL_REVIEW_CONCERNS=on" "${FILE}"; then
  echo "[test-code-reviewer-batched-greps] FAIL: env flag mention missing" >&2
  exit 1
fi

# ---- Test 2: ## REVIEW ✓ block format byte-identical ----
# Required lines (verbatim) — fixed order matters.
EXPECTED_LINES=(
  "## REVIEW ✓"
  "- Architecture: [PASS/FAIL]"
  "- Error Handling: [PASS/FAIL]"
  "- Security: [PASS/FAIL]"
  "- Test Coverage: [PASS/FAIL]"
  "- Project-Specific: [PASS/FAIL/N/A]"
)
for line in "${EXPECTED_LINES[@]}"; do
  if ! grep -qF -e "${line}" "${FILE}"; then
    echo "[test-code-reviewer-batched-greps] FAIL: missing canonical REVIEW line: ${line}" >&2
    exit 1
  fi
done

# Verify ordering — extract the relevant lines (allow leading indent inside code fence)
# and compare to expected sequence after stripping leading whitespace.
ACTUAL=$(grep -E '^[[:space:]]*## REVIEW ✓$|^[[:space:]]*- (Architecture|Error Handling|Security|Test Coverage|Project-Specific):' "${FILE}" \
  | sed -E 's/^[[:space:]]+//' \
  | head -n6 \
  | tr '\n' '|')
EXPECTED_ORDER="## REVIEW ✓|- Architecture: [PASS/FAIL]|- Error Handling: [PASS/FAIL]|- Security: [PASS/FAIL]|- Test Coverage: [PASS/FAIL]|- Project-Specific: [PASS/FAIL/N/A]|"
if [[ "${ACTUAL}" != "${EXPECTED_ORDER}" ]]; then
  echo "[test-code-reviewer-batched-greps] FAIL: REVIEW block ordering drift" >&2
  echo "  expected: ${EXPECTED_ORDER}" >&2
  echo "  actual:   ${ACTUAL}" >&2
  exit 1
fi

# ---- Test 3: VERDICT_JSON sentinel block anchors unchanged ----
SENTINELS=(
  'VERDICT_JSON:'
  '"$verdict_contract"'
  '"code_review_verdict"'
  '"verdict":'
  '"issues":'
)
for s in "${SENTINELS[@]}"; do
  if ! grep -qF -e "${s}" "${FILE}"; then
    echo "[test-code-reviewer-batched-greps] FAIL: missing VERDICT_JSON sentinel/anchor: ${s}" >&2
    exit 1
  fi
done

# ---- Test 4: VERDICT enum values unchanged (caveman boundary 1) ----
for v in APPROVED APPROVED_WITH_COMMENTS CHANGES_REQUESTED REJECTED; do
  if ! grep -qF -e "${v}" "${FILE}"; then
    echo "[test-code-reviewer-batched-greps] FAIL: missing VERDICT enum value: ${v}" >&2
    exit 1
  fi
done

echo "[test-code-reviewer-batched-greps] PASS"
exit 0
