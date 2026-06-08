#!/usr/bin/env bash
# test-reviewer-setup-error-recovery.sh — B4 (BUGREPORT-plugin-mode-2026-06-09).
# An unresolvable-rubric REJECTED is a SETUP error, not a code/plan rejection. The orchestrator
# re-dispatches the reviewer once with the BUNDLED KIT ROOT directive instead of STOPping the
# pipeline, WITHOUT consuming a review iteration. Contract-safe: NO new VERDICT enum value.
# Run: bash .claude/scripts/tests/test-reviewer-setup-error-recovery.sh
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"; cd "$ROOT"; rc=0
pass(){ echo "PASS: $1"; }
fail(){ echo "FAIL: $1"; rc=1; }

DT=".claude/skills/workflow-protocols/delegation-templates.md"

# 1. Recovery step present in BOTH post_delegation blocks (plan_review + code_review)
n_rec=$(grep -cF "B4 — reviewer setup-error recovery" "$DT")
if [ "$n_rec" -ge 2 ]; then pass "recovery step present in both post_delegation blocks (n=$n_rec)"; else fail "recovery step n=$n_rec, expected >=2"; fi

# 2. Matches the EXACT setup-error signature emitted by the reviewer bodies
grep -qF "Rubric unresolvable" "$DT" && pass "setup-error signature 'Rubric unresolvable' present" || fail "signature 'Rubric unresolvable' missing"

# 3. B4-specific telemetry record_kind (distinguishes from the pre-existing 'do NOT increment' prose)
grep -qF "reviewer_setup_error_recovery" "$DT" && pass "telemetry record_kind reviewer_setup_error_recovery present" || fail "telemetry record_kind missing"

# 4. Contract-safe: NO new VERDICT enum value introduced
if grep -qE 'BLOCKED_SETUP|ABSTAIN' "$DT"; then fail "new verdict enum leaked (BLOCKED_SETUP/ABSTAIN)"; else pass "no new verdict enum value introduced"; fi

# 5. Signature stays byte-identical to BOTH reviewer bodies (cross-file invariant)
for rb in .claude/agents/code-reviewer.md .claude/agents/plan-reviewer.md; do
  grep -qF "Rubric unresolvable" "$rb" && pass "$(basename "$rb"): emits 'Rubric unresolvable' (signature source)" || fail "$(basename "$rb"): signature drift"
done

exit $rc
