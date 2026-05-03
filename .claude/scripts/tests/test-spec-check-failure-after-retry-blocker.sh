#!/usr/bin/env bash
# test-spec-check-failure-after-retry-blocker.sh
# AC-P3.1..AC-P3.6: failure_after_retry flag in coder_to_code_review.spec_check raises BLOCKER.
set -euo pipefail
SCRIPT_NAME="$(basename "$0")"
PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
label() { echo "[${SCRIPT_NAME}] $1: $2" >&2; }
fail() { label "FAIL" "$1"; exit 1; }
pass() { label "PASS" "$1"; }
cd "$PROJECT_ROOT"

SCHEMA=".claude/schemas/handoff.schema.json"
SPEC_CHECK=".claude/skills/coder-rules/spec-check.md"
CR=".claude/agents/code-reviewer.md"
VALIDATOR=".claude/scripts/validate-handoff.sh"

# AC-P3.1: schema includes optional failure_after_retry bool
python3 - <<'PY'
import json,sys
with open('.claude/schemas/handoff.schema.json') as f: s=json.load(f)
defs=s['$defs']['coder_to_code_review']
sc=defs['properties']['spec_check']['properties']
assert 'failure_after_retry' in sc, "AC-P3.1a — failure_after_retry not in spec_check.properties"
assert sc['failure_after_retry']['type']=='boolean', "AC-P3.1b — failure_after_retry not bool type"
required=defs.get('required',[])
assert 'failure_after_retry' not in required, "AC-P3.1c — failure_after_retry must be OPTIONAL not required"
PY
pass "AC-P3.1 — schema field optional bool"

# AC-P3.2: spec-check.md updated retry semantics
grep -q 'failure_after_retry: true' "$SPEC_CHECK" \
  || fail "AC-P3.2a — spec-check.md does not set failure_after_retry on retry exhaustion"
grep -q 'PARTIAL with `failure_after_retry: true`' "$SPEC_CHECK" \
  || fail "AC-P3.2b — spec-check.md does not document escalation path"
pass "AC-P3.2 — spec-check.md retry semantics updated"

# AC-P3.3: code-reviewer.md raises BLOCKER on flag
grep -qE 'spec_check.failure_after_retry == true' "$CR" \
  || fail "AC-P3.3a — code-reviewer.md does not check failure_after_retry"
grep -qE 'Raise BLOCKER issue' "$CR" \
  || fail "AC-P3.3b — code-reviewer.md does not raise BLOCKER on the flag"
pass "AC-P3.3 — code-reviewer.md BLOCKER rule"

# AC-P3.4: decision matrix consistency preserved
bash .claude/scripts/tests/test-decision-matrix-consistency.sh >/dev/null 2>&1 \
  || fail "AC-P3.4 — test-decision-matrix-consistency.sh regressed"
pass "AC-P3.4 — decision matrix consistency preserved"

# AC-P3.5: existing PARTIAL semantics unchanged
grep -q 'factor into REVIEW as MINOR' "$CR" \
  || fail "AC-P3.5 — existing PARTIAL→MINOR fallback removed (regression)"
pass "AC-P3.5 — existing PARTIAL→MINOR fallback preserved for non-failure cases"

# AC-P3.6: fixtures (valid with flag, invalid bad-type, valid without flag)
FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

cat > "$FIXTURE_DIR/with-flag.json" <<'JSON'
{
  "$handoff_contract": "coder_to_code_review",
  "branch": "feature/test",
  "parts_implemented": ["Part 1: stub"],
  "verify_status": {"lint":"PASS","test":"PASS","command_used":"bash test"},
  "spec_check": {
    "status": "PARTIAL",
    "coverage_pct": 80,
    "failure_after_retry": true
  },
  "iteration": "1/3"
}
JSON
bash "$VALIDATOR" "$FIXTURE_DIR/with-flag.json" 2>/dev/null \
  || fail "AC-P3.6a — fixture with failure_after_retry=true rejected"
pass "AC-P3.6a — failure_after_retry=true accepted"

cat > "$FIXTURE_DIR/no-flag.json" <<'JSON'
{
  "$handoff_contract": "coder_to_code_review",
  "branch": "feature/test",
  "parts_implemented": ["Part 1: stub"],
  "verify_status": {"lint":"PASS","test":"PASS","command_used":"bash test"},
  "spec_check": {"status": "PARTIAL", "coverage_pct": 80},
  "iteration": "1/3"
}
JSON
bash "$VALIDATOR" "$FIXTURE_DIR/no-flag.json" 2>/dev/null \
  || fail "AC-P3.6b — fixture without flag (additive backward-compat) rejected"
pass "AC-P3.6b — fixture without flag accepted (backward compat)"

cat > "$FIXTURE_DIR/bad-type.json" <<'JSON'
{
  "$handoff_contract": "coder_to_code_review",
  "branch": "feature/test",
  "parts_implemented": ["Part 1: stub"],
  "verify_status": {"lint":"PASS","test":"PASS","command_used":"bash test"},
  "spec_check": {"status": "PARTIAL", "failure_after_retry": "yes"},
  "iteration": "1/3"
}
JSON
set +e
CLAUDE_HANDOFF_VALIDATION_MODE=strict bash "$VALIDATOR" "$FIXTURE_DIR/bad-type.json" 2>/dev/null
RC=$?
set -e
[[ $RC -ne 0 ]] || fail "AC-P3.6c — fixture with bad-type failure_after_retry accepted in strict mode"
pass "AC-P3.6c — bad-type rejected"

label "PASS" "all AC-P3.* assertions passed"
