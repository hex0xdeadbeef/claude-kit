#!/usr/bin/env bash
# test-save-review-checkpoint.sh — smoke tests for save-review-checkpoint.sh IMP-02 extraction
#
# Usage: bash .claude/scripts/tests/test-save-review-checkpoint.sh
#
# Coverage (IMP-02 Part 10):
#   1. structured_json happy path           — valid VERDICT_JSON block parsed and schema-validated
#   2. regex_fallback                       — no VERDICT_JSON block, VERDICT: line rescues
#   3. dual-VERDICT mismatch                — structured JSON APPROVED vs human NEEDS_CHANGES
#   4. structured_json_schema_invalid       — VERDICT_JSON has wrong enum, falls back via regex
#   5. verdict_json_decode_error            — VERDICT_JSON body is malformed JSON
#
# The test script uses CLAUDE_WORKFLOW_STATE_DIR to sandbox each scenario in its own
# temp directory, then asserts on marker-line and handoff-validation.jsonl contents.
# CWD MUST be repo root — the hook invokes validate-handoff.sh via relative path.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
HOOK="${REPO_ROOT}/.claude/scripts/save-review-checkpoint.sh"

cd "${REPO_ROOT}"

PASS=0
FAIL=0

# ─── Helper: build a SubagentStop JSON payload with a given last_assistant_message ─────
# Args: agent_id last_assistant_message
make_payload() {
  local aid="$1"
  local msg="$2"
  python3 -c '
import json, sys
print(json.dumps({
    "agent_type": "plan-reviewer",
    "agent_id": sys.argv[1],
    "session_id": "test-session-imp02",
    "last_assistant_message": sys.argv[2],
}))
' "$aid" "$msg"
}

# ─── Helper: invoke hook with a sandboxed STATE_DIR; echo the sandbox path ──────────────
# Args: payload_json  [verdict_validation_mode: warn|strict — default warn]
run_hook() {
  local payload="$1"
  local mode="${2:-warn}"
  local sandbox
  sandbox="$(mktemp -d -t imp02-chk.XXXXXX)"
  export CLAUDE_WORKFLOW_STATE_DIR="${sandbox}"
  export CLAUDE_VERDICT_VALIDATION_MODE="${mode}"
  # Discard stdout (hook prints "decision: block" JSON only when verdict UNKNOWN; our
  # tests engineer a verdict in every payload so block should never fire).
  echo "${payload}" | bash "${HOOK}" >/dev/null 2>&1 || true
  # CR-002: unset both envs on every run so one test's sandbox/mode cannot leak
  # into the next one's hook invocation. Without this, a test that runs in strict
  # mode would carry the mode forward to subsequent warn-mode scenarios, and the
  # sandbox path from the prior run would be read by the hook even though the
  # caller believes it's been replaced.
  unset CLAUDE_VERDICT_VALIDATION_MODE
  unset CLAUDE_WORKFLOW_STATE_DIR
  echo "${sandbox}"
}

# ─── Helper: read a single field from the latest marker in review-completions.jsonl ────
# Args: sandbox_dir field_name
marker_field() {
  local sb="$1"
  local field="$2"
  python3 -c '
import json, sys
try:
    with open(sys.argv[1]) as f:
        lines = [ln for ln in f if ln.strip()]
    if not lines:
        print("MISSING_FILE")
        sys.exit(0)
    marker = json.loads(lines[-1])
    print(marker.get(sys.argv[2], "MISSING_FIELD"))
except FileNotFoundError:
    print("MISSING_FILE")
except Exception as e:
    print(f"ERR:{e}")
' "${sb}/review-completions.jsonl" "${field}"
}

# ─── Helper: check presence of a record_kind in handoff-validation.jsonl ───────────────
# Args: sandbox_dir record_kind
validation_has_kind() {
  local sb="$1"
  local kind="$2"
  python3 -c '
import json, sys
try:
    with open(sys.argv[1]) as f:
        for ln in f:
            try:
                e = json.loads(ln)
            except Exception:
                continue
            if e.get("record_kind") == sys.argv[2]:
                print("YES")
                sys.exit(0)
    print("NO")
except FileNotFoundError:
    # Absent file means zero records of any kind — equivalent to NO for assertion purposes.
    print("NO")
' "${sb}/handoff-validation.jsonl" "${kind}"
}

# ─── Helper: assert equality; track PASS/FAIL ──────────────────────────────────────────
assert_eq() {
  local name="$1"
  local expected="$2"
  local actual="$3"
  if [[ "${actual}" == "${expected}" ]]; then
    echo "  PASS: ${name}"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: ${name}"
    echo "        expected: ${expected}"
    echo "        actual:   ${actual}"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== save-review-checkpoint IMP-02 smoke tests ==="
echo

# ─── Scenario 1: structured_json happy path ────────────────────────────────────────────
SCENARIO_1_MSG=$'VERDICT: APPROVED\n\nPlan looks good.\n\nVERDICT_JSON:\n```json\n{"$verdict_contract":"plan_review_verdict","verdict":"APPROVED","issues":[],"handoff":{"$handoff_contract":"plan_review_to_coder","artifact":".claude/prompts/x.md","verdict":"APPROVED","issues_summary":{"blocker":0,"major":0,"minor":0},"approved_with_notes":[],"iteration":"1/3"}}\n```'
SCENARIO_1_SANDBOX=$(run_hook "$(make_payload "aid-s1" "${SCENARIO_1_MSG}")")

echo "Scenario 1: structured_json happy path"
assert_eq "verdict is APPROVED"            "APPROVED"         "$(marker_field "${SCENARIO_1_SANDBOX}" verdict)"
assert_eq "verdict_source is structured"   "structured_json"  "$(marker_field "${SCENARIO_1_SANDBOX}" verdict_source)"
assert_eq "no verdict_mismatch logged"     "NO"               "$(validation_has_kind "${SCENARIO_1_SANDBOX}" verdict_mismatch)"
assert_eq "no schema_invalid logged"       "NO"               "$(validation_has_kind "${SCENARIO_1_SANDBOX}" verdict_schema_invalid)"
rm -rf "${SCENARIO_1_SANDBOX}"
echo

# ─── Scenario 2: regex_fallback (no VERDICT_JSON block) ────────────────────────────────
SCENARIO_2_MSG=$'VERDICT: NEEDS_CHANGES\n\n### Plan Review\nIssues: 0 BLOCKER, 1 MAJOR, 0 MINOR\n\n(no structured block)'
SCENARIO_2_SANDBOX=$(run_hook "$(make_payload "aid-s2" "${SCENARIO_2_MSG}")")

echo "Scenario 2: regex_fallback (no VERDICT_JSON block)"
assert_eq "verdict is NEEDS_CHANGES"       "NEEDS_CHANGES"    "$(marker_field "${SCENARIO_2_SANDBOX}" verdict)"
assert_eq "verdict_source is regex"        "regex_fallback"   "$(marker_field "${SCENARIO_2_SANDBOX}" verdict_source)"
rm -rf "${SCENARIO_2_SANDBOX}"
echo

# ─── Scenario 3: dual-VERDICT mismatch ─────────────────────────────────────────────────
# Structured JSON says APPROVED, human text says NEEDS_CHANGES. JSON wins.
SCENARIO_3_MSG=$'VERDICT: NEEDS_CHANGES\n\nBody mentions issues.\n\nVERDICT_JSON:\n```json\n{"$verdict_contract":"plan_review_verdict","verdict":"APPROVED","issues":[],"handoff":{"$handoff_contract":"plan_review_to_coder","artifact":".claude/prompts/x.md","verdict":"APPROVED","issues_summary":{"blocker":0,"major":0,"minor":0},"approved_with_notes":[],"iteration":"1/3"}}\n```'
SCENARIO_3_SANDBOX=$(run_hook "$(make_payload "aid-s3" "${SCENARIO_3_MSG}")")

echo "Scenario 3: dual-VERDICT mismatch (JSON wins)"
assert_eq "verdict is APPROVED (from JSON)" "APPROVED"        "$(marker_field "${SCENARIO_3_SANDBOX}" verdict)"
assert_eq "verdict_source is structured"   "structured_json"  "$(marker_field "${SCENARIO_3_SANDBOX}" verdict_source)"
assert_eq "verdict_mismatch logged"        "YES"              "$(validation_has_kind "${SCENARIO_3_SANDBOX}" verdict_mismatch)"
rm -rf "${SCENARIO_3_SANDBOX}"
echo

# ─── Scenario 4: structured_json_schema_invalid ────────────────────────────────────────
# VERDICT_JSON present but verdict enum is wrong for plan_review_verdict.
# APPROVED_WITH_COMMENTS is valid for code_review_verdict only — plan-reviewer schema
# rejects it, validator exits 2. Regex line below rescues to NEEDS_CHANGES.
SCENARIO_4_MSG=$'VERDICT: NEEDS_CHANGES\n\nVERDICT_JSON:\n```json\n{"$verdict_contract":"plan_review_verdict","verdict":"APPROVED_WITH_COMMENTS","issues":[],"handoff":{"$handoff_contract":"plan_review_to_coder","artifact":".claude/prompts/x.md","verdict":"APPROVED","issues_summary":{"blocker":0,"major":0,"minor":0},"approved_with_notes":[],"iteration":"1/3"}}\n```'
# Scenario 4 requires strict mode — warn-mode validator exits rc=0 even on schema FAIL,
# which would mask the schema violation and allow the invalid verdict through.
# Per spec A5 (Phase-A rollout): verdict_source=structured_json_schema_invalid only
# surfaces in strict mode. By-design.
SCENARIO_4_SANDBOX=$(run_hook "$(make_payload "aid-s4" "${SCENARIO_4_MSG}")" "strict")

echo "Scenario 4: structured_json_schema_invalid (enum wrong → regex rescue)"
assert_eq "verdict is NEEDS_CHANGES (regex)"  "NEEDS_CHANGES"                      "$(marker_field "${SCENARIO_4_SANDBOX}" verdict)"
assert_eq "verdict_source preserved"          "structured_json_schema_invalid"     "$(marker_field "${SCENARIO_4_SANDBOX}" verdict_source)"
assert_eq "verdict_schema_invalid logged"     "YES"                                "$(validation_has_kind "${SCENARIO_4_SANDBOX}" verdict_schema_invalid)"
rm -rf "${SCENARIO_4_SANDBOX}"
echo

# ─── Scenario 5: verdict_json_decode_error ─────────────────────────────────────────────
# Sentinel + fence present, but JSON body is malformed (trailing comma, no closing brace).
# parsed=None AND raw_json set → logs verdict_json_decode_error; verdict_source stays
# "none" until regex rescues it to "regex_fallback".
SCENARIO_5_MSG=$'VERDICT: REJECTED\n\nVERDICT_JSON:\n```json\n{"$verdict_contract":"plan_review_verdict","verdict":"REJECTED",\n```'
SCENARIO_5_SANDBOX=$(run_hook "$(make_payload "aid-s5" "${SCENARIO_5_MSG}")")

echo "Scenario 5: verdict_json_decode_error (malformed JSON → regex rescue)"
assert_eq "verdict is REJECTED (regex)"       "REJECTED"                       "$(marker_field "${SCENARIO_5_SANDBOX}" verdict)"
assert_eq "verdict_source is regex_fallback"  "regex_fallback"                 "$(marker_field "${SCENARIO_5_SANDBOX}" verdict_source)"
assert_eq "verdict_json_decode_error logged"  "YES"                            "$(validation_has_kind "${SCENARIO_5_SANDBOX}" verdict_json_decode_error)"
rm -rf "${SCENARIO_5_SANDBOX}"
echo

# ─── Summary ───────────────────────────────────────────────────────────────────────────
echo "Results: ${PASS} PASS, ${FAIL} FAIL"
echo

if [[ "${FAIL}" -gt 0 ]]; then
  echo "FAIL: ${FAIL} test(s) did not pass." >&2
  exit 1
fi
echo "All tests passed."
exit 0
