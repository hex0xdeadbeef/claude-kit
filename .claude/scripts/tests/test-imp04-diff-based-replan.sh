#!/usr/bin/env bash
# IMP-04 — documentation + schema regression tests
#
# Usage: bash .claude/scripts/tests/test-imp04-diff-based-replan.sh
#
# IMP-04 is a documentation + schema change (no new hook/script). Tests verify:
#   AC-1:  workflow.md has pre_delegation STEP 0.5 (manifest build)
#   AC-2:  plan-template.md has diff_vs_prior_iteration block
#   AC-3:  plan-reviewer.md has Part-selective VALIDATE ARCHITECTURE
#   AC-4:  handoff.schema.json has optional parts_validated[] in plan_review_verdict
#   AC-5:  workflow.md has location→Part mapping regex (^Part\s+(\d+)\s*:)
#   AC-6:  plan-reviewer.md has Pipeline Metrics subsection for parts_skipped_unchanged
#   AC-7:  backward compat documented (section absent → full validation)
#   AC-8:  BEHAVIORAL — plan WITHOUT diff section does NOT emit parts_validated[]
#                       (schema: parts_validated is optional / not in required list)
#   AC-9:  IMP-03 integration — regression_ids sourced from checkpoint.issues_history[]
#   AC-10: KD-6 unmappable-location fallback documented
#   AC-11: KD-4 contract-break literal prefix documented in workflow + plan-reviewer
# Regression-1: existing VERDICT_JSON payloads (no parts_validated) still schema-validate
# Regression-2: new VERDICT_JSON payloads WITH parts_validated schema-validate

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SCHEMA="${REPO_ROOT}/.claude/schemas/handoff.schema.json"
WORKFLOW_MD="${REPO_ROOT}/.claude/commands/workflow.md"
PLANNER_MD="${REPO_ROOT}/.claude/commands/planner.md"
REVIEWER_MD="${REPO_ROOT}/.claude/agents/plan-reviewer.md"
TEMPLATE_MD="${REPO_ROOT}/.claude/templates/plan-template.md"
PROTOCOL_MD="${REPO_ROOT}/.claude/skills/workflow-protocols/handoff-protocol.md"

cd "${REPO_ROOT}"

PASS=0
FAIL=0

assert_grep() {
  local name="$1"
  local pattern="$2"
  local file="$3"
  if grep -qE "${pattern}" "${file}" 2>/dev/null; then
    echo "  PASS: ${name}"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: ${name}"
    echo "        pattern: ${pattern}"
    echo "        file:    ${file}"
    FAIL=$((FAIL + 1))
  fi
}

assert_fixed_string() {
  local name="$1"
  local needle="$2"
  local file="$3"
  if grep -qF "${needle}" "${file}" 2>/dev/null; then
    echo "  PASS: ${name}"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: ${name}"
    echo "        needle: ${needle}"
    echo "        file:   ${file}"
    FAIL=$((FAIL + 1))
  fi
}

assert_json() {
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

echo "=== IMP-04 diff-based replan — documentation + schema regression tests ==="
echo

# ─── AC-1: workflow.md pre_delegation STEP 0.5 ─────────────────────────────────────────
echo "AC-1: workflow.md has pre_delegation STEP 0.5 (manifest build)"
assert_fixed_string "STEP 0.5 IMP-04 header"          "STEP 0.5 (IMP-04" "${WORKFLOW_MD}"
assert_fixed_string "diff-manifest.json artifact"     "{feature}-diff-manifest.json" "${WORKFLOW_MD}"
echo

# ─── AC-2: plan-template.md diff_vs_prior_iteration ────────────────────────────────────
echo "AC-2: plan-template.md has diff_vs_prior_iteration block"
assert_grep "diff_vs_prior_iteration key"    '^  diff_vs_prior_iteration:' "${TEMPLATE_MD}"
assert_fixed_string "parts_diff array"       "parts_diff:" "${TEMPLATE_MD}"
assert_fixed_string "UNCHANGED | NEEDS_UPDATE | NEW enum" "[UNCHANGED | NEEDS_UPDATE | NEW]" "${TEMPLATE_MD}"
echo

# ─── AC-3: plan-reviewer.md Part-selective VALIDATE ARCHITECTURE ───────────────────────
echo "AC-3: plan-reviewer.md has Part-selective VALIDATE ARCHITECTURE"
assert_fixed_string "IMP-04 Part-selective marker" "IMP-04: Part-selective on iter 2+" "${REVIEWER_MD}"
assert_fixed_string "PART_SELECTIVE scope label"   "PART_SELECTIVE (iter 2+)" "${REVIEWER_MD}"
echo

# ─── AC-4: handoff.schema.json parts_validated optional ────────────────────────────────
echo "AC-4: handoff.schema.json has optional parts_validated[] in plan_review_verdict"
parts_validated_present=$(python3 -c "
import json
with open('${SCHEMA}') as f: s = json.load(f)
pv = s['\$defs']['plan_review_verdict']['properties']
print('yes' if 'parts_validated' in pv else 'no')
")
assert_json "parts_validated field present" "yes" "${parts_validated_present}"

parts_validated_required=$(python3 -c "
import json
with open('${SCHEMA}') as f: s = json.load(f)
req = s['\$defs']['plan_review_verdict'].get('required', [])
print('yes' if 'parts_validated' in req else 'no')
")
assert_json "parts_validated NOT in required (optional)" "no" "${parts_validated_required}"

parts_validated_type=$(python3 -c "
import json
with open('${SCHEMA}') as f: s = json.load(f)
pv = s['\$defs']['plan_review_verdict']['properties']['parts_validated']
print(pv.get('type', 'missing'))
")
assert_json "parts_validated is array type" "array" "${parts_validated_type}"

parts_validated_item_type=$(python3 -c "
import json
with open('${SCHEMA}') as f: s = json.load(f)
pv = s['\$defs']['plan_review_verdict']['properties']['parts_validated']
print(pv.get('items', {}).get('type', 'missing'))
")
assert_json "parts_validated items are integer" "integer" "${parts_validated_item_type}"
echo

# ─── AC-5: workflow.md location→Part mapping regex ─────────────────────────────────────
echo "AC-5: workflow.md has location→Part mapping regex"
assert_fixed_string "location regex pattern" 'Part\s+(\d+)\s*:' "${WORKFLOW_MD}"
echo

# ─── AC-6: plan-reviewer.md Pipeline Metrics subsection ────────────────────────────────
echo "AC-6: plan-reviewer.md has Pipeline Metrics subsection"
assert_fixed_string "Pipeline Metrics heading"          "### Pipeline Metrics (IMP-04)" "${REVIEWER_MD}"
assert_fixed_string "parts_skipped_unchanged metric"    "parts_skipped_unchanged" "${REVIEWER_MD}"
echo

# ─── AC-7: backward compat section-absence documented ──────────────────────────────────
echo "AC-7: backward compat — section-absent path documented"
assert_fixed_string "section-absent runs full validation" "FULL architecture validation" "${REVIEWER_MD}"
assert_fixed_string "backward-compat section-absence signal" "section-absence signal" "${REVIEWER_MD}"
echo

# ─── AC-8: BEHAVIORAL — diff-section-absent plan does NOT require parts_validated ──────
echo "AC-8: BEHAVIORAL — parts_validated optional proves full-validation fallback path"
ac8_iter1_valid=$(python3 -c "
import json
with open('${SCHEMA}') as f: schema = json.load(f)
payload = {
  '\$verdict_contract': 'plan_review_verdict',
  'verdict': 'APPROVED',
  'issues': [],
  'handoff': {
    '\$handoff_contract': 'plan_review_to_coder',
    'artifact': '.claude/prompts/x.md',
    'verdict': 'APPROVED',
    'issues_summary': {'blocker': 0, 'major': 0, 'minor': 0},
    'approved_with_notes': [],
    'iteration': '1/3'
  }
}
req = schema['\$defs']['plan_review_verdict']['required']
missing = [k for k in req if k not in payload]
print('missing:' + ','.join(missing) if missing else 'ok')
")
assert_json "iter-1 payload (no parts_validated) satisfies required set" "ok" "${ac8_iter1_valid}"
assert_fixed_string "reviewer: absent section → FULL scan" "section ABSENT" "${REVIEWER_MD}"
echo

# ─── AC-9: IMP-03 integration — regression_ids from checkpoint.issues_history ──────────
echo "AC-9: IMP-03 integration — regression_ids sourced from issues_history"
assert_fixed_string "regression_ids canonical source" "checkpoint.issues_history[]" "${WORKFLOW_MD}"
assert_fixed_string "IMP-03 post_delegation step 5 reference" "IMP-03 post_delegation step 5" "${WORKFLOW_MD}"
echo

# ─── AC-10: KD-6 unmappable-location fallback ──────────────────────────────────────────
echo "AC-10: KD-6 unmappable-location fallback documented"
assert_fixed_string "imp04_unmapped_location record_kind" "imp04_unmapped_location" "${WORKFLOW_MD}"
assert_fixed_string "KD-6 fallback rule"                  "KD-6 fallback" "${WORKFLOW_MD}"
# CR-002: telemetry signal split — cross-cutting (empty location) vs unmapped (non-empty no-match)
assert_fixed_string "imp04_cross_cutting_issue record_kind"   "imp04_cross_cutting_issue" "${WORKFLOW_MD}"
assert_fixed_string "cross_cutting documented in protocol"    "imp04_cross_cutting_issue" "${PROTOCOL_MD}"
echo

# ─── AC-11: KD-4 contract-break literal prefix ─────────────────────────────────────────
echo "AC-11: KD-4 contract-break literal prefix documented in workflow + plan-reviewer"
assert_fixed_string "workflow.md: literal prefix"         'IMP-04 contract break: Part ' "${WORKFLOW_MD}"
assert_fixed_string "plan-reviewer.md: literal prefix"    'IMP-04 contract break: Part ' "${REVIEWER_MD}"
assert_fixed_string "imp04_contract_break_reroute kind"   "imp04_contract_break_reroute" "${WORKFLOW_MD}"
echo

# ─── Regression 1: existing VERDICT_JSON (no parts_validated) still validates ──────────
echo "Regression-1: existing VERDICT_JSON payload (no parts_validated) still matches schema shape"
reg1=$(python3 -c "
import json
with open('${SCHEMA}') as f: s = json.load(f)
pv = s['\$defs']['plan_review_verdict']
req = set(pv['required'])
expected = {'\$verdict_contract', 'verdict', 'issues', 'handoff'}
print('ok' if req == expected else f'DRIFT:{sorted(req)}')
")
assert_json "required set unchanged pre-IMP-04" "ok" "${reg1}"
echo

# ─── Regression 2: new VERDICT_JSON WITH parts_validated matches declared schema ───────
echo "Regression-2: parts_validated field declaration matches IMP-04 spec"
reg2=$(python3 -c "
import json
with open('${SCHEMA}') as f: s = json.load(f)
pv = s['\$defs']['plan_review_verdict']['properties']['parts_validated']
checks = []
checks.append('type' in pv and pv['type'] == 'array')
checks.append('items' in pv and pv['items'].get('type') == 'integer')
checks.append(pv['items'].get('minimum') == 1)
print('ok' if all(checks) else 'FAIL')
")
assert_json "parts_validated shape correct" "ok" "${reg2}"
echo

# ─── Documentation regression: handoff-protocol.md has diff_based_replan section ───────
echo "Doc-Regression: handoff-protocol.md has diff_based_replan section"
assert_grep "diff_based_replan key"          '^  diff_based_replan:' "${PROTOCOL_MD}"
assert_fixed_string "closes P-04 marker"     "closes:" "${PROTOCOL_MD}"
assert_fixed_string "fail_modes catalog"     "imp04_unmapped_location" "${PROTOCOL_MD}"
echo

# ─── Planner docs: phase_0_8_prior_review_digest ───────────────────────────────────────
echo "Doc: planner.md has phase_0_8_prior_review_digest"
assert_grep "phase_0_8_prior_review_digest key" '^  phase_0_8_prior_review_digest:' "${PLANNER_MD}"
assert_fixed_string "iter 2+ activation gate"   "iteration_counters.plan_review >= 2" "${PLANNER_MD}"
assert_fixed_string "preserve UNCHANGED bytes"  "byte-for-byte" "${PLANNER_MD}"
echo

# ─── JSON schema is still valid JSON ───────────────────────────────────────────────────
echo "Schema validity: handoff.schema.json parses as JSON"
schema_ok=$(python3 -c "
import json
try:
  json.load(open('${SCHEMA}'))
  print('ok')
except Exception as e:
  print(f'ERR:{e}')
")
assert_json "schema parses" "ok" "${schema_ok}"
echo

# ─── Summary ───────────────────────────────────────────────────────────────────────────
TOTAL=$((PASS + FAIL))
echo "=== IMP-04 test summary ==="
echo "  PASS: ${PASS}/${TOTAL}"
echo "  FAIL: ${FAIL}/${TOTAL}"

if [[ ${FAIL} -gt 0 ]]; then
  exit 1
fi
exit 0
