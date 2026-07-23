#!/usr/bin/env bash
# Test (DE-3): spec-template.md has an additive design_critique YAML block (findings +
# disposition + summary), AND spec-quality.md enforces the critique completeness gate (rationale
# required for non-addressed dispositions). Asserts AC1.3 + AC1.4 (traceability).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"; cd "$ROOT" || { echo "FAIL: cannot cd to repo root"; exit 1; }
TPL=".claude/templates/spec-template.md"
SQ=".claude/skills/design-rules/spec-quality.md"
rc=0; fail(){ echo "FAIL: $1"; rc=1; }; pass(){ echo "PASS: $1"; }

# T-1: design_critique is a YAML key (indented under spec:), NOT an H2 header
if grep -qE '^[[:space:]]+design_critique:' "$TPL"; then pass "T-1 design_critique present as YAML key"; else fail "T-1 design_critique YAML key missing"; fi
if grep -qE '^##[[:space:]]+[Dd]esign.[Cc]ritique' "$TPL"; then fail "T-1b design_critique introduced as an H2 (caveman boundary risk)"; else pass "T-1b design_critique is not an H2 header"; fi

# T-2: findings list with disposition field
TPLREGION="$(awk '/design_critique:/{f=1} f' "$TPL")"
if printf '%s' "$TPLREGION" | grep -q "findings:" && printf '%s' "$TPLREGION" | grep -q "disposition:"; then
  pass "T-2 design_critique has findings[] with disposition"
else
  fail "T-2 design_critique missing findings/disposition"
fi

# T-3: disposition enum documented (all three) within the block
if printf '%s' "$TPLREGION" | grep -q "addressed" && printf '%s' "$TPLREGION" | grep -q "accepted-risk" && printf '%s' "$TPLREGION" | grep -q "out-of-scope"; then
  pass "T-3 disposition enum documented in template"
else
  fail "T-3 disposition enum incomplete in template"
fi

# T-4: summary sub-block present
if printf '%s' "$TPLREGION" | grep -q "summary:" && printf '%s' "$TPLREGION" | grep -qi "unresolved_high"; then
  pass "T-4 summary with unresolved_high present"
else
  fail "T-4 summary/unresolved_high missing"
fi

# T-5: DC-* declared local-ref-only / not canonical (AC1.11 in template)
if printf '%s' "$TPLREGION" | grep -qi "canonical"; then pass "T-5 DC-not-canonical note in template"; else fail "T-5 missing DC-not-canonical note in template"; fi

# T-6 (AC1.4): spec-quality.md requires rationale for non-addressed dispositions
if grep -qi "rationale" "$SQ" && grep -qiE 'disposition|accepted-risk' "$SQ"; then
  pass "T-6 spec-quality enforces rationale for non-addressed dispositions"
else
  fail "T-6 spec-quality missing rationale-required gate"
fi

# T-7: spec-quality states the gate is advisory (designer self-check), not a hook
if grep -qiE 'advisory|self-check|self check' "$SQ"; then pass "T-7 spec-quality marks gate advisory (no hook)"; else fail "T-7 spec-quality does not state gate is advisory"; fi

[ "$rc" -eq 0 ] && echo "ALL PASS: test-design-critique-spec-template" || echo "SOME FAILED: test-design-critique-spec-template"
exit "$rc"
