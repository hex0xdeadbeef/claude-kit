#!/usr/bin/env bash
# test-code-review-to-completion-handoff.sh
# AC-P2.1..AC-P2.7: code_review_to_completion contract closure (IMP-01.2).
set -euo pipefail
SCRIPT_NAME="$(basename "$0")"
PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
label() { echo "[${SCRIPT_NAME}] $1: $2" >&2; }
fail() { label "FAIL" "$1"; exit 1; }
pass() { label "PASS" "$1"; }
cd "$PROJECT_ROOT"

SCHEMA=".claude/schemas/handoff.schema.json"
HANDOFF=".claude/skills/workflow-protocols/handoff-protocol.md"
DELEG=".claude/skills/workflow-protocols/delegation-templates.md"
CODER=".claude/commands/coder.md"
VALIDATOR=".claude/scripts/validate-handoff.sh"

# AC-P2.1: schema contains $def code_review_to_completion with discriminator
grep -q '"code_review_to_completion"' "$SCHEMA" \
  || fail "AC-P2.1a — code_review_to_completion \$def missing from schema"
grep -q '"const": "code_review_to_completion"' "$SCHEMA" \
  || fail "AC-P2.1b — discriminator const missing"
pass "AC-P2.1 — schema \$def + discriminator present"

# AC-P2.2: oneOf has 6 entries
ONEOF_COUNT=$(python3 -c "import json; s=json.load(open('$SCHEMA')); print(len(s['oneOf']))")
[[ "$ONEOF_COUNT" == "6" ]] || fail "AC-P2.2a — oneOf count = $ONEOF_COUNT, expected 6"
VERSION=$(python3 -c "import json; s=json.load(open('$SCHEMA')); print(s['version'])")
[[ "$VERSION" == "1.2.0" ]] || fail "AC-P2.2b — schema version = $VERSION, expected 1.2.0"
pass "AC-P2.2 — oneOf=6 + version=1.2.0"

# AC-P2.3: delegation-templates.md post_delegation step 6.5
grep -q '6.5 (IMP-01.2' "$DELEG" \
  || fail "AC-P2.3a — post_delegation step 6.5 missing"
grep -q '"\$handoff_contract": "code_review_to_completion"' "$DELEG" \
  || fail "AC-P2.3b — discriminator not referenced in step 6.5"
pass "AC-P2.3 — delegation step 6.5 documented"

# AC-P2.4: coder.md Phase 0.5 structured_handoff_read
grep -q 'structured_handoff_read:' "$CODER" \
  || fail "AC-P2.4a — coder Phase 0.5 missing structured_handoff_read"
grep -q 'code_review_to_completion' "$CODER" \
  || fail "AC-P2.4b — coder.md does not reference code_review_to_completion contract"
pass "AC-P2.4 — coder.md Phase 0.5 reads structured handoff"

# AC-P2.5: graceful fallback documented
grep -qE 'Fall back to delegation-prompt-text path|If absent.* Fall back' "$CODER" \
  || fail "AC-P2.5 — fallback path not documented in coder.md"
pass "AC-P2.5 — graceful fallback documented"

# AC-P2.6: validator accepts valid + rejects invalid fixture
FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT
export CLAUDE_WORKFLOW_STATE_DIR="$FIXTURE_DIR"

VALID_FIXTURE="$FIXTURE_DIR/valid-completion.json"
cat > "$VALID_FIXTURE" <<'JSON'
{
  "$handoff_contract": "code_review_to_completion",
  "verdict": "CHANGES_REQUESTED",
  "original_verdict": "NEEDS_CHANGES",
  "issues": [
    {"id": "CR-ab12cd34", "severity": "MAJOR", "category": "error_handling", "problem": "missing nil check in handler"}
  ],
  "iteration": "2/3",
  "narrative_for_coder": "Re-iter focus: handler error path."
}
JSON
bash "$VALIDATOR" "$VALID_FIXTURE" 2>/dev/null \
  || fail "AC-P2.6a — valid code_review_to_completion fixture rejected"
pass "AC-P2.6a — valid fixture accepted"

INVALID_FIXTURE="$FIXTURE_DIR/invalid-completion.json"
cat > "$INVALID_FIXTURE" <<'JSON'
{
  "$handoff_contract": "code_review_to_completion",
  "verdict": "CHANGES_REQUESTED",
  "issues": [],
  "iteration": "5/3"
}
JSON
set +e
CLAUDE_HANDOFF_VALIDATION_MODE=strict bash "$VALIDATOR" "$INVALID_FIXTURE" 2>/dev/null
RC=$?
set -e
[[ $RC -ne 0 ]] || fail "AC-P2.6b — invalid fixture (iteration=5/3) accepted in strict mode"
pass "AC-P2.6b — invalid fixture rejected (iteration pattern violation)"

# AC-P2.7: handoff-protocol.md updated
if grep -qE 'code_review_to_completion → IMP-01\.2|code_review_to_completion → future' "$HANDOFF"; then
  fail "AC-P2.7 — code_review_to_completion still listed as 'not yet covered' in handoff-protocol.md"
fi
grep -q 'code_review_to_completion — written in code_review_delegation.post_delegation step 6.5' "$HANDOFF" \
  || fail "AC-P2.7 — handoff-protocol.md does not document covered contract"
pass "AC-P2.7 — handoff-protocol.md reflects covered contract"

# Existing fixtures remain valid (backward-compat regression guard)
for f in .claude/scripts/tests/fixtures/valid-*.json; do
  bash "$VALIDATOR" "$f" 2>/dev/null \
    || fail "regression — existing fixture $(basename "$f") no longer validates after schema 1.2.0"
done
pass "regression — all existing valid fixtures still pass schema 1.2.0"

label "PASS" "all AC-P2.* assertions passed"
