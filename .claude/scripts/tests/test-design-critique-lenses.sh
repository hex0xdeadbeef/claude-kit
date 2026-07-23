#!/usr/bin/env bash
# Test (DE-2): critique-lenses.md exists and defines the adversarial design-critique
# lens set, the anti-theater forcing function, the disposition enum, and the DC-not-canonical note.
# Asserts AC1.2 + AC1.11 (DC-* local-ref-only) from .claude/prompts/adversarial-design-critique-part1.md.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"; cd "$ROOT" || { echo "FAIL: cannot cd to repo root"; exit 1; }
LENS=".claude/skills/design-rules/critique-lenses.md"
rc=0; fail(){ echo "FAIL: $1"; rc=1; }; pass(){ echo "PASS: $1"; }

# L-1: file exists
if [[ -f "$LENS" ]]; then pass "L-1 critique-lenses.md exists"; else fail "L-1 critique-lenses.md missing"; exit "$rc"; fi

# L-2: defines the lens set (all 7 named lenses present, case-insensitive)
missing=""
for lens in "failure-mode" "assumption" "boundary" "misuse" "operability" "contract" "cost"; do
  grep -qi "$lens" "$LENS" || missing="$missing $lens"
done
if [[ -z "$missing" ]]; then pass "L-2 all lenses present"; else fail "L-2 missing lenses:$missing"; fi

# L-3: anti-theater forcing function — "no finding" explicit-skip rule present
if grep -qi "no finding" "$LENS"; then pass "L-3 forcing function (no-finding skip) present"; else fail "L-3 no forcing function (no-finding) text"; fi

# L-4: disposition enum present (all three values)
if grep -q "addressed" "$LENS" && grep -q "accepted-risk" "$LENS" && grep -q "out-of-scope" "$LENS"; then
  pass "L-4 disposition enum present"
else
  fail "L-4 disposition enum incomplete (need addressed/accepted-risk/out-of-scope)"
fi

# L-5: DC-* declared local-ref-only and NOT the canonical ID (AC1.11)
if grep -qi "canonical" "$LENS" && grep -qiE "DC-|local" "$LENS"; then
  pass "L-5 DC-* local-ref-only / not-canonical note present"
else
  fail "L-5 missing DC-not-canonical note"
fi

# L-6: contract-safety — lens file must NOT wire any hook (no save-review-checkpoint reference)
if grep -q "save-review-checkpoint" "$LENS"; then fail "L-6 lens file references save-review-checkpoint (must not)"; else pass "L-6 no hook reference in lens file"; fi

[ "$rc" -eq 0 ] && echo "ALL PASS: test-design-critique-lenses" || echo "SOME FAILED: test-design-critique-lenses"
exit "$rc"
