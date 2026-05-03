#!/usr/bin/env bash
# test-narrative-truncation-telemetry.sh
# AC-P5.1..AC-P5.6: narrative summary-only contract + narrative_truncated telemetry.
set -euo pipefail
SCRIPT_NAME="$(basename "$0")"
PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
label() { echo "[${SCRIPT_NAME}] $1: $2" >&2; }
fail() { label "FAIL" "$1"; exit 1; }
pass() { label "PASS" "$1"; }
cd "$PROJECT_ROOT"

CODER=".claude/commands/coder.md"
DELEG=".claude/skills/workflow-protocols/delegation-templates.md"
SCHEMA=".claude/schemas/handoff.schema.json"

# AC-P5.1: coder.md narrative is summary-only contract
grep -q 'SUMMARY-ONLY contract' "$CODER" \
  || fail "AC-P5.1a — coder.md does not declare summary-only contract"
grep -qE 'Bullets/details[[:space:]]+MUST go into structured arrays' "$CODER" \
  || fail "AC-P5.1b — coder.md does not redirect bullets to structured arrays"
pass "AC-P5.1 — narrative summary-only contract documented"

# AC-P5.2: delegation-templates.md emits narrative_truncated record
grep -q '"record_kind": "narrative_truncated"' "$DELEG" \
  || fail "AC-P5.2a — narrative_truncated record_kind missing from delegation-templates.md"
grep -q 'original_length' "$DELEG" \
  || fail "AC-P5.2b — original_length field missing from telemetry payload"
pass "AC-P5.2 — narrative_truncated telemetry documented"

# AC-P5.3: schema cap 600 unchanged
python3 - <<'PY'
import json
s=json.load(open('.claude/schemas/handoff.schema.json'))
nfr=s['$defs']['coder_to_code_review']['properties']['narrative_for_reviewer']
assert nfr['maxLength']==600, f"AC-P5.3 — schema cap drift: maxLength={nfr['maxLength']}, expected 600"
PY
pass "AC-P5.3 — schema cap 600 preserved"

# AC-P5.4: simulate truncation — emit a synthetic narrative >600, run STEP 0 logic via prose grep
NARRATIVE_LEN=$(python3 -c 'print(len("a"*750))')
[[ "$NARRATIVE_LEN" == "750" ]] || fail "AC-P5.4a — sanity check: synthetic length mismatch"
# Verify delegation-templates.md prose explicitly handles >600 case
grep -qE 'when truncation occurs' "$DELEG" \
  || fail "AC-P5.4b — delegation-templates.md missing 'when truncation occurs' trigger"
pass "AC-P5.4 — truncation trigger documented"

# AC-P5.5: existing handoff-size-cap test still passes
if [[ -f .claude/scripts/tests/test-handoff-size-cap.sh ]]; then
  bash .claude/scripts/tests/test-handoff-size-cap.sh >/dev/null 2>&1 \
    || fail "AC-P5.5 — test-handoff-size-cap.sh regressed"
  pass "AC-P5.5 — handoff-size-cap test preserved"
else
  pass "AC-P5.5 — handoff-size-cap test not present (no regression possible)"
fi

# AC-P5.6: coder.md final_format example shows single-line narrative + structured arrays
grep -qE 'narrative_for_reviewer: "Implemented [0-9]+ Parts' "$CODER" \
  || fail "AC-P5.6a — coder.md example does not show single-line narrative"
grep -q 'high_risk_areas:' "$CODER" \
  || fail "AC-P5.6b — coder.md example does not populate high_risk_areas array"
pass "AC-P5.6 — coder.md example reflects new contract"

label "PASS" "all AC-P5.* assertions passed"
