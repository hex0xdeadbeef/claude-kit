#!/usr/bin/env bash
# test-handoff-size-cap.sh — Part 2 / P1
#
# Coverage:
#   1. Every handoff-validation.jsonl row gets a 'bytes' integer field
#   2. WARN stderr fired at >= 8000 B (default warn mode)
#   3. Strict mode rejects oversize narrative_for_reviewer / oversize issues array
#   4. Pre-cap valid handoffs continue to validate

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
HOOK="${REPO_ROOT}/.claude/scripts/validate-handoff.sh"

cd "${REPO_ROOT}"

# Test isolation — unset any strict-mode envs from the user's settings.local.json
# so each scenario controls its own mode explicitly.
unset CLAUDE_HANDOFF_VALIDATION_MODE
unset CLAUDE_VERDICT_VALIDATION_MODE
unset CLAUDE_ISSUE_ID_VALIDATION_MODE

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

mk_sandbox() { mktemp -d -t handoff-size-cap.XXXXXX; }

# --- Scenario 1: small valid handoff -> bytes field present, no WARN ---
SB_1=$(mk_sandbox)
cat > "${SB_1}/feature-handoff.json" <<'EOF'
{
  "$handoff_contract": "coder_to_code_review",
  "branch": "feature/x",
  "parts_implemented": ["Part 1: small"],
  "verify_status": {"lint": "PASS", "test": "PASS", "command_used": "make test"},
  "iteration": "1/3"
}
EOF
STDERR_1=$(CLAUDE_WORKFLOW_STATE_DIR="${SB_1}" bash "${HOOK}" "${SB_1}/feature-handoff.json" 2>&1 >/dev/null || true)
LATEST_1=$(tail -n1 "${SB_1}/handoff-validation.jsonl" 2>/dev/null || echo "{}")
HAS_BYTES_1=$(echo "${LATEST_1}" | python3 -c "import json,sys; print('YES' if 'bytes' in json.loads(sys.stdin.read() or '{}') else 'NO')")
assert_eq "small handoff: bytes field present in JSONL"  "YES"   "${HAS_BYTES_1}"
echo "${STDERR_1}" | grep -q "WARN: handoff size" && SIZE_WARN_1="YES" || SIZE_WARN_1="NO"
assert_eq "small handoff: no size WARN"                  "NO"    "${SIZE_WARN_1}"
test -d "${SB_1}" && rm -r "${SB_1}"

# --- Scenario 2: oversize handoff (>= 8000 B) -> WARN fired, bytes field still present ---
SB_2=$(mk_sandbox)
python3 -c '
import json
big = "x" * 8500
payload = {
  "$handoff_contract": "coder_to_code_review",
  "branch": "feature/x",
  "parts_implemented": ["Part 1: " + ("y" * 200)],
  "verify_status": {"lint": "PASS", "test": "PASS", "command_used": "make test"},
  "iteration": "1/3",
  "narrative_for_reviewer": big
}
print(json.dumps(payload))
' > "${SB_2}/big-handoff.json"
STDERR_2=$(CLAUDE_WORKFLOW_STATE_DIR="${SB_2}" bash "${HOOK}" "${SB_2}/big-handoff.json" 2>&1 >/dev/null || true)
echo "${STDERR_2}" | grep -q "WARN: handoff size" && SIZE_WARN_2="YES" || SIZE_WARN_2="NO"
assert_eq "oversize handoff: WARN fired"                "YES"   "${SIZE_WARN_2}"
LATEST_2=$(tail -n1 "${SB_2}/handoff-validation.jsonl" 2>/dev/null || echo "{}")
BYTES_2=$(echo "${LATEST_2}" | python3 -c "import json,sys; print(json.loads(sys.stdin.read() or '{}').get('bytes', 0))")
[[ "${BYTES_2}" -ge 8000 ]] && BYTES_OK_2="YES" || BYTES_OK_2="NO"
assert_eq "oversize handoff: bytes >= 8000"              "YES"   "${BYTES_OK_2}"
test -d "${SB_2}" && rm -r "${SB_2}"

# --- Scenario 3: strict mode rejects narrative_for_reviewer > 600 chars ---
SB_3=$(mk_sandbox)
python3 -c '
import json
payload = {
  "$handoff_contract": "coder_to_code_review",
  "branch": "feature/x",
  "parts_implemented": ["Part 1"],
  "verify_status": {"lint": "PASS", "test": "PASS", "command_used": "make test"},
  "iteration": "1/3",
  "narrative_for_reviewer": "z" * 700
}
print(json.dumps(payload))
' > "${SB_3}/over-narrative-handoff.json"
RC_3=0
CLAUDE_HANDOFF_VALIDATION_MODE=strict CLAUDE_WORKFLOW_STATE_DIR="${SB_3}" bash "${HOOK}" "${SB_3}/over-narrative-handoff.json" >/dev/null 2>&1 || RC_3=$?
assert_eq "strict mode: narrative > 600 -> rc=2"          "2"     "${RC_3}"
test -d "${SB_3}" && rm -r "${SB_3}"

# --- Scenario 4: warn mode does NOT block oversize fields ---
SB_4=$(mk_sandbox)
python3 -c '
import json
payload = {
  "$handoff_contract": "coder_to_code_review",
  "branch": "feature/x",
  "parts_implemented": ["Part 1"],
  "verify_status": {"lint": "PASS", "test": "PASS", "command_used": "make test"},
  "iteration": "1/3",
  "narrative_for_reviewer": "z" * 700
}
print(json.dumps(payload))
' > "${SB_4}/over-narrative-handoff.json"
RC_4=0
CLAUDE_WORKFLOW_STATE_DIR="${SB_4}" bash "${HOOK}" "${SB_4}/over-narrative-handoff.json" >/dev/null 2>&1 || RC_4=$?
assert_eq "warn mode: narrative > 600 -> rc=0 (warn only)"  "0"   "${RC_4}"
test -d "${SB_4}" && rm -r "${SB_4}"

echo
echo "Results: ${PASS} PASS, ${FAIL} FAIL"
if [[ "${FAIL}" -gt 0 ]]; then exit 1; fi
echo "All tests passed."
exit 0
