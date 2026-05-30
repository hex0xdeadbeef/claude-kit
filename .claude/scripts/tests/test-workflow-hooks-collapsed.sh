#!/usr/bin/env bash
# Unit-4 (audit #3): commands/workflow.md ## HOOKS section collapsed to a settings.json pointer +
# the pipeline-load-bearing hook rationale. settings.json stays the authoritative wiring; the
# orchestrator never reads it at runtime. Contract-neutral: descriptive prose, no hook re-wired.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"; cd "$ROOT"
WF=".claude/commands/workflow.md"
SETTINGS=".claude/settings.json"
rc=0; fail(){ echo "FAIL: $1"; rc=1; }; pass(){ echo "PASS: $1"; }

# ## HOOKS is the last section — extract heading -> EOF
SEC="$(awk '/^## HOOKS$/{f=1} f' "$WF")"
SECLINES="$(printf '%s\n' "$SEC" | wc -l | tr -d ' ')"

# HK-1: pure-duplication mirror dropped
if printf '%s' "$SEC" | grep -q "also_active_during_workflow"; then fail "HK-1 also_active_during_workflow block still present"; else pass "HK-1 also_active_during_workflow mirror dropped"; fi

# HK-2: materially smaller (was 63 lines)
if [ "${SECLINES:-0}" -lt 25 ]; then pass "HK-2 HOOKS section ${SECLINES} lines (<25; was 63)"; else fail "HK-2 HOOKS section ${SECLINES} lines (>=25, not collapsed)"; fi

# HK-3: pointer to the authoritative source
if printf '%s' "$SEC" | grep -q "settings.json"; then pass "HK-3 names settings.json as authoritative"; else fail "HK-3 no settings.json pointer"; fi

# HK-4: every hook the collapse references (+ the intentionally-dropped track-task-lifecycle) is
# STILL wired in settings.json — proves the collapse loses no real wiring.
for h in save-progress-before-compact.sh verify-state-after-compact.sh inject-review-context.sh save-review-checkpoint.sh check-uncommitted.sh validate-handoff.sh track-task-lifecycle.sh; do
  grep -q "$h" "$SETTINGS" && pass "HK-4 $h wired in settings.json" || fail "HK-4 $h MISSING from settings.json"
done

# HK-5: load-bearing rationale kept
printf '%s' "$SEC" | grep -qi "compact" && pass "HK-5 compaction checkpoint rationale kept" || fail "HK-5 compaction rationale dropped"
printf '%s' "$SEC" | grep -q "check-uncommitted" && pass "HK-5 Stop check-uncommitted (BLOCKING) kept" || fail "HK-5 check-uncommitted dropped"

[ "$rc" -eq 0 ] && echo "ALL PASS: test-workflow-hooks-collapsed" || echo "SOME FAILED: test-workflow-hooks-collapsed"
exit "$rc"
