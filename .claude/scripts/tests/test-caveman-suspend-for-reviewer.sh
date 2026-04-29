#!/usr/bin/env bash
# test-caveman-suspend-for-reviewer.sh — smoke tests for caveman-suspend-for-reviewer.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="${SCRIPT_DIR}/../caveman-suspend-for-reviewer.sh"

PASS=0
FAIL=0

run_match_test() {
  local agent="$1"
  local out
  out=$(echo '' | bash "${HOOK}" "${agent}" 2>/dev/null || true)
  if echo "${out}" | grep -q '"hookSpecificOutput"' \
     && echo "${out}" | grep -q '\[caveman OFF for this delegation\]' \
     && echo "${out}" | grep -q "${agent}"; then
    echo "  PASS: matched agent '${agent}' emits exemption marker"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: agent '${agent}' (got: '${out:0:120}')"
    FAIL=$((FAIL + 1))
  fi
}

run_skip_test() {
  local agent="$1"
  local stdout stderr exit_code
  stdout=$(echo '' | bash "${HOOK}" "${agent}" 2>/dev/null)
  exit_code=$?
  stderr=$(echo '' | bash "${HOOK}" "${agent}" 2>&1 1>/dev/null)
  if [[ -z "${stdout}" ]] && echo "${stderr}" | grep -qE '^\[caveman-suspend-for-reviewer\] SKIP:' && [[ "${exit_code}" -eq 0 ]]; then
    echo "  PASS: unmatched agent '${agent}' SKIPs cleanly"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: SKIP for '${agent}' (stdout='${stdout}', stderr='${stderr}', rc=${exit_code})"
    FAIL=$((FAIL + 1))
  fi
}

# ─── Allowed agents (4) ─────────────────────────────────────────────────────
run_match_test "plan-reviewer"
run_match_test "code-reviewer"
run_match_test "verdict-recovery"
run_match_test "code-researcher"

# ─── Unknown agent → SKIP ───────────────────────────────────────────────────
run_skip_test "future-agent"

echo "─── caveman-suspend-for-reviewer.sh: ${PASS} passed, ${FAIL} failed ───"
[[ "${FAIL}" -eq 0 ]]
