#!/usr/bin/env bash
# Unit-5 (audit #7): coder-rules/spec-check.md is deferred from /coder STARTUP (eager, in the
# immediate_actions prefix) to a just-in-time load at Phase 3.5 (where it is actually consumed),
# mirroring the existing review-response.md condition gate. Contract-neutral: load TIMING moves;
# the spec_check handoff fields / PASS-PARTIAL-FAIL semantics are unchanged.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"; cd "$ROOT"
CODER=".claude/commands/coder.md"
rc=0; fail(){ echo "FAIL: $1"; rc=1; }; pass(){ echo "PASS: $1"; }

# Extract the STARTUP region (## STARTUP -> before ## WORKFLOW) and the Phase-3.5 block
STARTUP="$(awk '/^## STARTUP$/{f=1} /^## WORKFLOW$/{f=0} f' "$CODER")"
P35="$(awk '/^    - phase: 3\.5$/{f=1} /^## RULES$/{f=0} f' "$CODER")"

# SC-1: spec-check.md is NO LONGER loaded in the eager STARTUP immediate_actions region
if printf '%s' "$STARTUP" | grep -q "spec-check.md"; then
  fail "SC-1 spec-check.md still eager-loaded in STARTUP immediate_actions"
else
  pass "SC-1 spec-check.md deferred out of STARTUP"
fi

# SC-2: the Phase-3.5 block loads spec-check.md just-in-time. Two independent greps (a load/JIT
# marker AND the path) — robust to future rewording that splits the directive across lines (PR-001).
if printf '%s' "$P35" | grep -qiE 'load|just-in-time' && printf '%s' "$P35" | grep -q "spec-check.md"; then
  pass "SC-2 Phase 3.5 loads spec-check.md just-in-time"
else
  fail "SC-2 Phase 3.5 has no just-in-time load of spec-check.md"
fi

# SC-3: spec-check.md is still reachable at Phase 3.5 (skill not orphaned)
if printf '%s' "$P35" | grep -q "spec-check.md"; then
  pass "SC-3 spec-check.md still referenced in Phase 3.5"
else
  fail "SC-3 spec-check.md no longer referenced in Phase 3.5"
fi

# SC-4: the mirrored review-response conditional gate in STARTUP is intact (regression)
if printf '%s' "$STARTUP" | grep -q "review-response.md" && printf '%s' "$STARTUP" | grep -q "condition:"; then
  pass "SC-4 review-response conditional gate intact (the deferral pattern we mirror)"
else
  fail "SC-4 review-response conditional gate missing/altered"
fi

[ "$rc" -eq 0 ] && echo "ALL PASS: test-coder-speccheck-deferred" || echo "SOME FAILED: test-coder-speccheck-deferred"
exit "$rc"
