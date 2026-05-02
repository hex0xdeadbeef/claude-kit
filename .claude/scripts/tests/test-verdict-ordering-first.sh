#!/usr/bin/env bash
# test-verdict-ordering-first.sh — Part 5 / P4 (AC-P4.4)
#
# Coverage:
#   1. Synthetic transcript with VERDICT: + VERDICT_JSON: BEFORE narrative truncation
#      yields verdict_source: structured_json (envelope survives truncation)
#   2. Synthetic transcript with VERDICT: + narrative + (truncated, no VERDICT_JSON)
#      yields verdict_source: regex_fallback (regression scenario for old ordering)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
HOOK="${REPO_ROOT}/.claude/scripts/save-review-checkpoint.sh"

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

marker_field() {
  local sb="$1" field="$2"
  python3 -c '
import json, sys
try:
    with open(sys.argv[1]) as f:
        lines = [ln for ln in f if ln.strip()]
    if not lines: print("MISSING_FILE"); sys.exit(0)
    print(json.loads(lines[-1]).get(sys.argv[2], "MISSING_FIELD"))
except FileNotFoundError:
    print("MISSING_FILE")
' "${sb}/review-completions.jsonl" "${field}"
}

# --- Scenario A: P4 order — VERDICT, VERDICT_JSON, then narrative truncated ---
SB_A=$(mktemp -d -t order-A.XXXXXX)
MSG_A=$(python3 -c '
import json
verdict_json = {
    "$verdict_contract": "code_review_verdict",
    "verdict": "APPROVED_WITH_COMMENTS",
    "issues": [
        {"id": "CR-001", "severity": "MINOR", "category": "style", "location": "Part 1", "problem": "x"}
    ],
    "handoff": {"verdict": "APPROVED_WITH_COMMENTS", "iteration": "1/3"}
}
narrative = "## REVIEW\n" + ("This narrative line was artificially trunc" * 1)
print("VERDICT: APPROVED_WITH_COMMENTS\n\nVERDICT_JSON:\n```json\n" + json.dumps(verdict_json) + "\n```\n\n" + narrative)
')
PAYLOAD_A=$(python3 -c '
import json, sys
print(json.dumps({
    "agent_type": "code-reviewer",
    "agent_id": "aid-order-A",
    "session_id": "sid-A",
    "last_assistant_message": sys.argv[1],
}))
' "${MSG_A}")
echo "${PAYLOAD_A}" | CLAUDE_WORKFLOW_STATE_DIR="${SB_A}" bash "${HOOK}" >/dev/null 2>&1 || true
assert_eq "A: P4 order -> verdict_source structured_json" "structured_json" "$(marker_field "${SB_A}" verdict_source)"
assert_eq "A: verdict APPROVED_WITH_COMMENTS"             "APPROVED_WITH_COMMENTS" "$(marker_field "${SB_A}" verdict)"
test -d "${SB_A}" && rm -r "${SB_A}"

# --- Scenario B: VERDICT only, narrative starts but VERDICT_JSON dropped (truncation) ---
SB_B=$(mktemp -d -t order-B.XXXXXX)
MSG_B=$'VERDICT: CHANGES_REQUESTED\n\n## REVIEW\nMid-narrative truncation simulated; no VERDICT_JSON block follows.'
PAYLOAD_B=$(python3 -c '
import json, sys
print(json.dumps({
    "agent_type": "code-reviewer",
    "agent_id": "aid-order-B",
    "session_id": "sid-B",
    "last_assistant_message": sys.argv[1],
}))
' "${MSG_B}")
echo "${PAYLOAD_B}" | CLAUDE_WORKFLOW_STATE_DIR="${SB_B}" bash "${HOOK}" >/dev/null 2>&1 || true
assert_eq "B: regex rescues -> verdict_source regex_fallback"  "regex_fallback"   "$(marker_field "${SB_B}" verdict_source)"
assert_eq "B: verdict CHANGES_REQUESTED"                       "CHANGES_REQUESTED" "$(marker_field "${SB_B}" verdict)"
test -d "${SB_B}" && rm -r "${SB_B}"

echo
echo "Results: ${PASS} PASS, ${FAIL} FAIL"
[[ "${FAIL}" -gt 0 ]] && exit 1
echo "All tests passed."
exit 0
