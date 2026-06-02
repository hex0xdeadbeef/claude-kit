#!/usr/bin/env bash
# Test (Part 2 / DE-4): the design critique is carried forward to the planner without changing any
# contract shape. handoff-contracts.md gains an OPTIONAL critique_summary on designer_to_planner;
# designer.md emits it (producer symmetry, PR-001); planner.md phase_4 maps HIGH accepted-risk/
# out-of-scope findings into the EXISTING areas_needing_attention[]; the schema is untouched.
# Asserts AC2.1, AC2.2, AC2.3, AC2.3b, AC2.4.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"; cd "$ROOT" || { echo "FAIL: cannot cd to repo root"; exit 1; }
HC=".claude/skills/workflow-protocols/handoff-contracts.md"
PLN=".claude/commands/planner.md"
DES=".claude/commands/designer.md"
SCHEMA=".claude/schemas/handoff.schema.json"
rc=0; fail(){ echo "FAIL: $1"; rc=1; }; pass(){ echo "PASS: $1"; }

# Scoped extraction of the designer_to_planner block (stop at the next contract — reuse the proven
# pattern from test-design-critique-contract-safety.sh to avoid bleeding into planner_to_plan_review).
D2P="$(awk '/^[[:space:]]*designer_to_planner:/{f=1} /^[[:space:]]*planner_to_plan_review:/{f=0} f' "$HC")"

# CF-1 (AC2.1): designer_to_planner documents an OPTIONAL critique_summary
if printf '%s' "$D2P" | grep -q "critique_summary" && printf '%s' "$D2P" | grep -qiE 'optional'; then
  pass "CF-1 critique_summary documented as optional on designer_to_planner"
else
  fail "CF-1 critique_summary missing or not marked optional"
fi

# CF-2 (AC2.3): designer_to_planner STILL has no \$handoff_contract (non-schema-validated)
if printf '%s' "$D2P" | grep -q 'handoff_contract'; then fail "CF-2 designer_to_planner gained a \$handoff_contract (must stay non-validated)"; else pass "CF-2 designer_to_planner still non-schema-validated"; fi

# Scope to the carryforward block so the assertions are anchored to the new logic, not stray
# occurrences elsewhere in planner.md (code-review hardening note on CF-3).
PLNREGION="$(awk '/design_critique_carryforward:/{f=1} f' "$PLN")"

# CF-3 (AC2.2): the carryforward block references design_critique + areas_needing_attention
if printf '%s' "$PLNREGION" | grep -q "design_critique" && printf '%s' "$PLNREGION" | grep -q "areas_needing_attention"; then
  pass "CF-3 carryforward block maps design_critique into areas_needing_attention"
else
  fail "CF-3 carryforward block missing design_critique -> areas_needing_attention mapping"
fi

# CF-4 (AC2.4): carry-forward is conditional / backward-compatible
if printf '%s' "$PLNREGION" | grep -qiE 'skip_when|back-compat|backward-compat|absent'; then
  pass "CF-4 planner carry-forward is conditional / back-compat"
else
  fail "CF-4 planner carry-forward not gated (no skip_when/back-compat)"
fi

# CF-5 (AC2.3b): schema untouched — no critique key added to handoff.schema.json
if grep -qi 'critique' "$SCHEMA"; then fail "CF-5 handoff.schema.json gained a critique key (schema must be untouched)"; else pass "CF-5 handoff.schema.json untouched (no critique key)"; fi

# CF-6 (PR-001): producer symmetry — designer.md handoff_output emits critique_summary
if grep -q "critique_summary" "$DES"; then pass "CF-6 designer.md producer emits critique_summary"; else fail "CF-6 designer.md handoff_output does not emit critique_summary (producer/contract asymmetry)"; fi

[ "$rc" -eq 0 ] && echo "ALL PASS: test-design-critique-carryforward" || echo "SOME FAILED: test-design-critique-carryforward"
exit "$rc"
