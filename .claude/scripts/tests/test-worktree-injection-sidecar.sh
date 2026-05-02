#!/usr/bin/env bash
# test-worktree-injection-sidecar.sh — Part 4 / P3 (AC-P3.3)
#
# Coverage:
#   1. inject-review-context.sh --sidecar-only writes the sidecar file (atomic)
#   2. Sidecar content includes Feature line from checkpoint
#   3. Re-running --sidecar-only overwrites stale content
#   4. Standard stdout-mode is unaffected (still emits additionalContext JSON)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
HOOK="${REPO_ROOT}/.claude/scripts/inject-review-context.sh"

cd "${REPO_ROOT}"

unset CLAUDE_HANDOFF_VALIDATION_MODE CLAUDE_VERDICT_VALIDATION_MODE CLAUDE_ISSUE_ID_VALIDATION_MODE

PASS=0
FAIL=0

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [[ "${actual}" == "${expected}" ]]; then
    echo "  PASS: ${name}"; PASS=$((PASS + 1))
  else
    echo "  FAIL: ${name}"; echo "    expected: ${expected}"; echo "    actual:   ${actual}"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local name="$1" haystack="$2" needle="$3"
  if echo "${haystack}" | grep -qF "${needle}"; then
    echo "  PASS: ${name}"; PASS=$((PASS + 1))
  else
    echo "  FAIL: ${name} — missing: ${needle}"; FAIL=$((FAIL + 1))
  fi
}

SB=$(mktemp -d -t sidecar.XXXXXX)
export CLAUDE_WORKFLOW_STATE_DIR="${SB}"

# Build a minimum checkpoint so the inject script has something to render
cat > "${SB}/test-sidecar-checkpoint.yaml" <<'EOF'
feature: test-sidecar
complexity: XL
phase_completed: 4
phase_name: code_review
iteration:
  plan_review: 1/3
  code_review: 1/3
EOF

# --- Scenario 1: --sidecar-only writes file ---
OUTPUT_1=$(echo '{"session_id":"sid-sc"}' | bash "${HOOK}" code-reviewer --sidecar-only 2>/dev/null || true)
SIDECAR="${SB}/code-reviewer-INJECTED-CONTEXT.md"
[[ -f "${SIDECAR}" ]] && WRITTEN="YES" || WRITTEN="NO"
assert_eq "1: sidecar file written"  "YES" "${WRITTEN}"
HAS_FEATURE=$(grep -q "Feature: test-sidecar" "${SIDECAR}" && echo "YES" || echo "NO")
assert_eq "1: sidecar has Feature: line" "YES" "${HAS_FEATURE}"
HAS_AC=$(echo "${OUTPUT_1}" | grep -qE '"additionalContext":[ ]*""' && echo "YES" || echo "NO")
assert_eq "1: stdout additionalContext is empty in sidecar mode" "YES" "${HAS_AC}"

# --- Scenario 2: re-run overwrites cleanly ---
echo "STALE CONTENT" > "${SIDECAR}"
echo '{"session_id":"sid-sc"}' | bash "${HOOK}" code-reviewer --sidecar-only 2>/dev/null >/dev/null || true
HAS_STALE=$(grep -F "STALE CONTENT" "${SIDECAR}" >/dev/null 2>&1 && echo "YES" || echo "NO")
assert_eq "2: stale content overwritten" "NO" "${HAS_STALE}"

# --- Scenario 3: no --sidecar-only -> stdout JSON, no sidecar update from this run ---
test -f "${SIDECAR}" && rm "${SIDECAR}"
OUTPUT_3=$(echo '{"session_id":"sid-sc"}' | bash "${HOOK}" code-reviewer 2>/dev/null || true)
[[ -f "${SIDECAR}" ]] && CREATED_3="YES" || CREATED_3="NO"
assert_eq "3: no sidecar file in normal stdout mode" "NO" "${CREATED_3}"
assert_contains "3: stdout has Feature: in additionalContext" "${OUTPUT_3}" "Feature: test-sidecar"

test -d "${SB}" && rm -r "${SB}"
echo
echo "Results: ${PASS} PASS, ${FAIL} FAIL"
[[ "${FAIL}" -gt 0 ]] && exit 1
echo "All tests passed."
exit 0
