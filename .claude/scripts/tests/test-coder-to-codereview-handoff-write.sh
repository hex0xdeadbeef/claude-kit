#!/usr/bin/env bash
# test-coder-to-codereview-handoff-write.sh
# AC-P2-1, AC-P2-2, AC-P2-4, AC-P2-7: Validate STEP 0 produces a schema-compliant payload.
set -euo pipefail
SCRIPT_NAME="$(basename "$0")"
PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
label() { echo "[${SCRIPT_NAME}] $1: $2" >&2; }
fail() { label "FAIL" "$1"; exit 1; }
pass() { label "PASS" "$1"; }
cd "$PROJECT_ROOT"

DELEG=".claude/skills/workflow-protocols/delegation-templates.md"
SCHEMA=".claude/schemas/handoff.schema.json"
VALIDATOR=".claude/scripts/validate-handoff.sh"

# AC-P2-1a: STEP 0 prose present in delegation-templates.md → code_review_delegation.pre_delegation
grep -q 'STEP 0 (IMP-01.2 — symmetry with plan_review_delegation STEP 0)' "$DELEG" \
  || fail "AC-P2-1a — STEP 0 block missing from code_review_delegation.pre_delegation"
pass "AC-P2-1a — STEP 0 prose present"

# AC-P2-1b: STEP 0 references the coder_to_code_review schema discriminator
grep -q '"\$handoff_contract": "coder_to_code_review"' "$DELEG" \
  || fail "AC-P2-1b — STEP 0 does not reference coder_to_code_review discriminator"
pass "AC-P2-1b — STEP 0 references coder_to_code_review"

# AC-P2-4: 600-char narrative cap is documented (split into 2 independent assertions for robustness — PR-e7711e45)
# Extract STEP 0 block first via awk for precise scoping (avoids regex distance fragility).
# Range start: 'STEP 0 (IMP-01.2'; range end: next 'Before delegating' header (start of iter-2+ block).
STEP0_BLOCK=$(awk '/STEP 0 \(IMP-01\.2/{flag=1} flag{print} /^    Before delegating to code-reviewer/{if(flag){flag=0}}' "$DELEG" 2>/dev/null || true)
[[ -n "$STEP0_BLOCK" ]] \
  || fail "AC-P2-4 — STEP 0 block not extractable from delegation-templates.md"
echo "$STEP0_BLOCK" | grep -q 'narrative_for_reviewer' \
  || fail "AC-P2-4a — narrative_for_reviewer not mentioned within STEP 0 block"
echo "$STEP0_BLOCK" | grep -qE '600[[:space:]]*chars?|capped at 600' \
  || fail "AC-P2-4b — 600-char cap not mentioned within STEP 0 block"
pass "AC-P2-4 — narrative_for_reviewer + 600-char cap both documented within STEP 0 block"

# AC-P2-2: Build a fixture and run validate-handoff.sh on it
FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT
export CLAUDE_WORKFLOW_STATE_DIR="$FIXTURE_DIR"
VALID_FIXTURE="$FIXTURE_DIR/valid-handoff.json"
cat > "$VALID_FIXTURE" <<'JSON'
{
  "$handoff_contract": "coder_to_code_review",
  "branch": "feature/test",
  "parts_implemented": ["Part 1: example"],
  "verify_status": {
    "lint": "PASS",
    "test": "PASS",
    "command_used": "bash .claude/scripts/tests/test-*.sh"
  },
  "iteration": "1/3"
}
JSON
# Direct-mode validation (script supports both hook and direct modes)
if ! bash "$VALIDATOR" "$VALID_FIXTURE" 2>/dev/null; then
  fail "AC-P2-2a — valid coder_to_code_review fixture rejected by validate-handoff.sh"
fi
pass "AC-P2-2a — valid fixture accepted"

# AC-P2-2b: invalid fixture — missing required verify_status.command_used
INVALID_FIXTURE="$FIXTURE_DIR/invalid-handoff.json"
cat > "$INVALID_FIXTURE" <<'JSON'
{
  "$handoff_contract": "coder_to_code_review",
  "branch": "feature/test",
  "parts_implemented": ["Part 1: example"],
  "verify_status": {
    "lint": "PASS",
    "test": "PASS"
  },
  "iteration": "1/3"
}
JSON
# Strict mode: should block (exit 2)
set +e
CLAUDE_HANDOFF_VALIDATION_MODE=strict bash "$VALIDATOR" "$INVALID_FIXTURE" 2>/dev/null
RC=$?
set -e
[[ $RC -ne 0 ]] || fail "AC-P2-2b — invalid fixture accepted in strict mode (rc=$RC)"
pass "AC-P2-2b — invalid fixture blocked in strict mode (rc=$RC)"

# AC-P2-7: handoff-protocol.md contracts_covered list updated
grep -q 'coder_to_code_review — written in code_review_delegation.pre_delegation STEP 0' \
  .claude/skills/workflow-protocols/handoff-protocol.md \
  || fail "AC-P2-7 — contracts_covered list does not list coder_to_code_review"
pass "AC-P2-7 — contracts_covered list updated"

label "PASS" "test-coder-to-codereview-handoff-write.sh — all assertions met"
