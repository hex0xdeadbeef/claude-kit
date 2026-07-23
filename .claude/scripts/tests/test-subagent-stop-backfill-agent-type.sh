#!/usr/bin/env bash
# test-subagent-stop-backfill-agent-type.sh — marker.agent backfill from effective_agent_type
#
# Coverage:
#   1. Empty agent_type with effective_agent_type=code-reviewer (recovered via heuristic)
#      yields marker.agent='code-reviewer' (NOT 'unknown')
#   2. Prior behavior preserved when raw agent_type is non-empty (no promotion)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
HOOK="${REPO_ROOT}/.claude/scripts/save-review-checkpoint.sh"

cd "${REPO_ROOT}"

# Test isolation
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

# --- Scenario A: empty agent_type, agent_transcript_path present (worktree heuristic recovers code-reviewer) ---
SB_A=$(mktemp -d -t backfill-A.XXXXXX)
TRANSCRIPT="${SB_A}/transcript.jsonl"
python3 -c '
import json
content = [{"type":"text","text":"VERDICT: APPROVED\n\nVERDICT_JSON:\n```json\n" + json.dumps({"$verdict_contract":"code_review_verdict","verdict":"APPROVED","issues":[],"handoff":{"verdict":"APPROVED","iteration":"1/3"}}) + "\n```"}]
print(json.dumps({"role":"assistant","content":content}))
' > "${TRANSCRIPT}"
PAYLOAD_A=$(python3 -c '
import json, sys
print(json.dumps({
    "agent_type": "",
    "agent_id": "aid-backfill-A",
    "session_id": "sid-A",
    "agent_transcript_path": sys.argv[1],
}))
' "${TRANSCRIPT}")
echo "${PAYLOAD_A}" | CLAUDE_WORKFLOW_STATE_DIR="${SB_A}" bash "${HOOK}" >/dev/null 2>&1 || true
assert_eq "A: marker.agent promoted to code-reviewer" "code-reviewer" "$(marker_field "${SB_A}" agent)"
# Hook's post-fallback value when payload agent_type is empty is "unknown"; agent_raw captures that
# fallback-resolved value (forensic record of what the hook saw, not the literal payload).
assert_eq "A: marker.agent_raw is unknown (post-fallback)" "unknown"   "$(marker_field "${SB_A}" agent_raw)"
assert_eq "A: effective_agent_type code-reviewer"      "code-reviewer"  "$(marker_field "${SB_A}" effective_agent_type)"
test -d "${SB_A}" && rm -r "${SB_A}"

# --- Scenario B: explicit agent_type, no promotion ---
SB_B=$(mktemp -d -t backfill-B.XXXXXX)
PAYLOAD_B=$(python3 -c '
import json
msg = "VERDICT: APPROVED\n\nVERDICT_JSON:\n```json\n" + json.dumps({
    "$verdict_contract": "plan_review_verdict",
    "verdict": "APPROVED",
    "issues": [],
    "handoff": {"$handoff_contract":"plan_review_to_coder","artifact":".claude/prompts/x.md","verdict":"APPROVED","issues_summary":{"blocker":0,"major":0,"minor":0},"approved_with_notes":[],"iteration":"1/3"}
}) + "\n```"
print(json.dumps({
    "agent_type": "plan-reviewer",
    "agent_id": "aid-backfill-B",
    "session_id": "sid-B",
    "last_assistant_message": msg,
}))
')
echo "${PAYLOAD_B}" | CLAUDE_WORKFLOW_STATE_DIR="${SB_B}" bash "${HOOK}" >/dev/null 2>&1 || true
assert_eq "B: marker.agent stays plan-reviewer (no promotion)" "plan-reviewer" "$(marker_field "${SB_B}" agent)"
assert_eq "B: marker.agent_raw preserved as plan-reviewer"     "plan-reviewer" "$(marker_field "${SB_B}" agent_raw)"
test -d "${SB_B}" && rm -r "${SB_B}"

echo
echo "Results: ${PASS} PASS, ${FAIL} FAIL"
[[ "${FAIL}" -gt 0 ]] && exit 1
echo "All tests passed."
exit 0
