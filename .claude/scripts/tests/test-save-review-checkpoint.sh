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

# ─── Helper: read canonical_issue_ids from the latest marker (IMP-03) ──────────────────
# Args: sandbox_dir  expr (one of: length | first_id | all_ids | first_prefix)
canonical_ids_field() {
  local sb="$1"
  local expr="$2"
  python3 -c '
import json, sys
try:
    with open(sys.argv[1]) as f:
        lines = [ln for ln in f if ln.strip()]
    if not lines:
        print("MISSING_FILE"); sys.exit(0)
    marker = json.loads(lines[-1])
    cids = marker.get("canonical_issue_ids") or []
    expr = sys.argv[2]
    if expr == "length":
        print(len(cids))
    elif expr == "first_id" and cids:
        print(cids[0].get("id", "MISSING"))
    elif expr == "all_ids":
        print(",".join(c.get("id", "?") for c in cids))
    elif expr == "first_prefix" and cids:
        first = cids[0].get("id", "")
        print(first[:3] if first else "EMPTY")
    else:
        print("UNKNOWN_EXPR")
except FileNotFoundError:
    print("MISSING_FILE")
except Exception as e:
    print(f"ERR:{e}")
' "${sb}/review-completions.jsonl" "${expr}"
}

# ─── Helper: make plan-review or code-review payload with issues (IMP-03) ──────────────
# Args: verdict_contract  agent_id  issues_json_array
make_payload_with_issues() {
  local contract="$1"
  local aid="$2"
  local issues_json="$3"
  local agent_type="plan-reviewer"
  if [[ "${contract}" == "code_review_verdict" ]]; then
    agent_type="code-reviewer"
  fi
  python3 -c '
import json, sys
contract = sys.argv[1]
aid = sys.argv[2]
issues = json.loads(sys.argv[3])
agent_type = sys.argv[4]

if contract == "plan_review_verdict":
    handoff = {"$handoff_contract": "plan_review_to_coder",
               "artifact": ".claude/prompts/x.md",
               "verdict": "APPROVED",
               "issues_summary": {"blocker": 0, "major": 0, "minor": len(issues)},
               "approved_with_notes": [],
               "iteration": "1/3"}
else:
    handoff = {"verdict": "APPROVED", "iteration": "1/3"}

verdict_json = {
    "$verdict_contract": contract,
    "verdict": "APPROVED",
    "issues": issues,
    "handoff": handoff,
}
msg = "VERDICT: APPROVED\n\nVERDICT_JSON:\n```json\n" + json.dumps(verdict_json) + "\n```"
payload = {
    "agent_type": agent_type,
    "agent_id": aid,
    "session_id": "test-session-imp03",
    "last_assistant_message": msg,
}
print(json.dumps(payload))
' "${contract}" "${aid}" "${issues_json}" "${agent_type}"
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

# ─── Scenario 6: ID normalization (plan-review, PR- prefix) (IMP-03) ───────────────────
# Advisory id "PR-001" → hook overwrites with canonical PR-<sha256[:8]>.
SCENARIO_6_ISSUES='[{"id":"PR-001","severity":"MINOR","category":"style","location":"Part 3","problem":"missing test for edge case"}]'
SCENARIO_6_SANDBOX=$(run_hook "$(make_payload_with_issues "plan_review_verdict" "aid-s6" "${SCENARIO_6_ISSUES}")")

echo "Scenario 6: ID normalization (plan-review, PR- prefix)"
assert_eq "verdict is APPROVED"                  "APPROVED"           "$(marker_field "${SCENARIO_6_SANDBOX}" verdict)"
assert_eq "verdict_source structured_json"       "structured_json"    "$(marker_field "${SCENARIO_6_SANDBOX}" verdict_source)"
assert_eq "canonical_issue_ids has 1 entry"      "1"                  "$(canonical_ids_field "${SCENARIO_6_SANDBOX}" length)"
assert_eq "canonical id has PR- prefix"          "PR-"                "$(canonical_ids_field "${SCENARIO_6_SANDBOX}" first_prefix)"
# Verify deterministic hash: sha256("style|Part 3|missing test for edge case")[:8]
EXPECTED_HASH_6=$(python3 -c 'import hashlib; print(hashlib.sha256(b"style|Part 3|missing test for edge case").hexdigest()[:8])')
assert_eq "canonical id matches expected hash"   "PR-${EXPECTED_HASH_6}" "$(canonical_ids_field "${SCENARIO_6_SANDBOX}" first_id)"
rm -rf "${SCENARIO_6_SANDBOX}"
echo

# ─── Scenario 7: ID normalization (code-review, CR- prefix) (IMP-03) ───────────────────
SCENARIO_7_ISSUES='[{"id":"CR-999","severity":"MAJOR","category":"error_handling","location":"internal/handler/user.go:Create","problem":"nil pointer not guarded"}]'
SCENARIO_7_SANDBOX=$(run_hook "$(make_payload_with_issues "code_review_verdict" "aid-s7" "${SCENARIO_7_ISSUES}")")

echo "Scenario 7: ID normalization (code-review, CR- prefix)"
assert_eq "canonical_issue_ids has 1 entry"      "1"                  "$(canonical_ids_field "${SCENARIO_7_SANDBOX}" length)"
assert_eq "canonical id has CR- prefix"          "CR-"                "$(canonical_ids_field "${SCENARIO_7_SANDBOX}" first_prefix)"
EXPECTED_HASH_7=$(python3 -c 'import hashlib; print(hashlib.sha256(b"error_handling|internal/handler/user.go:Create|nil pointer not guarded").hexdigest()[:8])')
assert_eq "canonical id matches expected hash"   "CR-${EXPECTED_HASH_7}"  "$(canonical_ids_field "${SCENARIO_7_SANDBOX}" first_id)"
rm -rf "${SCENARIO_7_SANDBOX}"
echo

# ─── Scenario 8: Collision dedup + id_collision record (IMP-03) ────────────────────────
# Three issues with identical category/location/problem → 1 canonical ID, collision logged.
SCENARIO_8_ISSUES='[
  {"id":"CR-001","severity":"MINOR","category":"style","location":"Part 3","problem":"trailing whitespace"},
  {"id":"CR-002","severity":"MINOR","category":"style","location":"Part 3","problem":"trailing whitespace"},
  {"id":"CR-003","severity":"MINOR","category":"style","location":"Part 3","problem":"trailing whitespace"}
]'
SCENARIO_8_SANDBOX=$(run_hook "$(make_payload_with_issues "code_review_verdict" "aid-s8" "${SCENARIO_8_ISSUES}")")

echo "Scenario 8: Collision dedup"
assert_eq "canonical_issue_ids deduplicated to 1"  "1"     "$(canonical_ids_field "${SCENARIO_8_SANDBOX}" length)"
assert_eq "id_collision record logged"             "YES"   "$(validation_has_kind "${SCENARIO_8_SANDBOX}" id_collision)"
rm -rf "${SCENARIO_8_SANDBOX}"
echo

# ─── Scenario 9: Backward compat — advisory free-form id normalised (IMP-03) ───────────
# Agent emits id "arbitrary-advisory-tag" (non-canonical); hook replaces it with PR-<hash>
# and schema validation passes in warn mode (default).
SCENARIO_9_ISSUES='[{"id":"arbitrary-advisory-tag","severity":"MAJOR","category":"architecture","location":"Part 5","problem":"repository layer imports handler"}]'
SCENARIO_9_SANDBOX=$(run_hook "$(make_payload_with_issues "plan_review_verdict" "aid-s9" "${SCENARIO_9_ISSUES}")")

echo "Scenario 9: Backward compat — free-form advisory id normalised"
assert_eq "verdict still APPROVED"              "APPROVED"          "$(marker_field "${SCENARIO_9_SANDBOX}" verdict)"
assert_eq "verdict_source structured_json"      "structured_json"   "$(marker_field "${SCENARIO_9_SANDBOX}" verdict_source)"
assert_eq "canonical_issue_ids has 1 entry"     "1"                 "$(canonical_ids_field "${SCENARIO_9_SANDBOX}" length)"
assert_eq "canonical id has PR- prefix"         "PR-"               "$(canonical_ids_field "${SCENARIO_9_SANDBOX}" first_prefix)"
# PR-003 strengthening: deterministic hash equality matches scenarios 6/7 pattern
EXPECTED_HASH_9=$(python3 -c 'import hashlib; print(hashlib.sha256(b"architecture|Part 5|repository layer imports handler").hexdigest()[:8])')
assert_eq "canonical id matches expected hash"  "PR-${EXPECTED_HASH_9}" "$(canonical_ids_field "${SCENARIO_9_SANDBOX}" first_id)"
rm -rf "${SCENARIO_9_SANDBOX}"
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
