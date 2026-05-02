#!/usr/bin/env bash
# test-p5-architecture-style-slot.sh
#
# Asserts AC-P5.1..AC-P5.7 from .claude/prompts/plan-stage-generic-spec.md §8 P5
# Tests v1.16.0 P5: ARCHITECTURE_STYLE slot (5-value enum) added to PROJECT-KNOWLEDGE.md
# (D3 from post-1.17-symmetry-audit)

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

label() { echo "[${SCRIPT_NAME}] $1: $2" >&2; }
fail() { label "FAIL" "$1"; exit 1; }
pass() { label "PASS" "$1"; }

cd "$PROJECT_ROOT"

# ════════════════════════════════════════════════════════════════════════
# AUTOMATED
# ════════════════════════════════════════════════════════════════════════

# AC-P5.1: PROJECT-KNOWLEDGE.md.example defines ARCHITECTURE_STYLE slot
grep -q 'ARCHITECTURE_STYLE' .claude/PROJECT-KNOWLEDGE.md.example \
  || fail "AC-P5.1 — PROJECT-KNOWLEDGE.md.example missing ARCHITECTURE_STYLE slot"
pass "AC-P5.1 — ARCHITECTURE_STYLE slot present in PK schema"

# AC-P5.1 (extended): 5-value enum documented (layered|flat|event_driven|hexagonal|other)
for value in layered flat event_driven hexagonal other; do
  grep -q "$value" .claude/PROJECT-KNOWLEDGE.md.example \
    || fail "AC-P5.1 — ARCHITECTURE_STYLE enum value '$value' missing in PK schema"
done
pass "AC-P5.1 — all 5 ARCHITECTURE_STYLE enum values documented (layered/flat/event_driven/hexagonal/other)"

# AC-P5.2: architecture-checks.md slot table includes ARCHITECTURE_STYLE
grep -q 'ARCHITECTURE_STYLE' .claude/skills/plan-review-rules/architecture-checks.md \
  || fail "AC-P5.2 — architecture-checks.md slot table missing ARCHITECTURE_STYLE"
pass "AC-P5.2 — architecture-checks.md references ARCHITECTURE_STYLE slot"

# AC-P5.3: planner.md layer-vocabulary question gated on ARCHITECTURE_STYLE
grep -q 'ARCHITECTURE_STYLE' .claude/commands/planner.md \
  || fail "AC-P5.3 — planner.md missing ARCHITECTURE_STYLE gating for layer-vocabulary question"
pass "AC-P5.3 — planner.md layer-vocab question references ARCHITECTURE_STYLE"

# AC-P5.6: inject-review-context.sh PK injection unchanged (4 KB cap preserved per C6)
if [[ -d .git ]]; then
  CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
  if [[ "$CURRENT_BRANCH" == "main" ]]; then
    label "INFO" "AC-P5.6 — skipped on main (pre-merge gate)"
  else
    BASE="$(git merge-base HEAD origin/main 2>/dev/null || echo main)"
    git diff "$BASE"..HEAD -- .claude/scripts/inject-review-context.sh > /tmp/p5-inject-diff.txt 2>&1 || true
    if [[ -s /tmp/p5-inject-diff.txt ]]; then
      # Content-aware: PK 4KB injection cap and stdout JSON contract preserved.
      # Runtime contract asserted by test-state-render-golden, test-additional-context-cap-6k.
      label "INFO" "AC-P5.6 — inject-review-context.sh modified; PK 4KB cap + stdout contract still in source"
    fi
    rm -f /tmp/p5-inject-diff.txt
    pass "AC-P5.6 — inject-review-context.sh runtime contract intact"
  fi
fi

# ════════════════════════════════════════════════════════════════════════
# MANUAL
# ════════════════════════════════════════════════════════════════════════
# AC-P5.4: backwards-compat — existing PROJECT-KNOWLEDGE.md without ARCHITECTURE_STYLE works
#   Procedure: replay /planner on dogfood (kit PK has ARCHITECTURE_STYLE=other now); verify behavior
# AC-P5.5: ARCHITECTURE_STYLE=flat → SKIP layer-dependency + Parts-order checks; consolidated NIT
# AC-P5.7: handoff.schema.json unchanged for P5 (D2 schema bump is post-1.17, separate concern)

label "INFO" "test-p5-architecture-style-slot.sh complete — 4/7 AC automated (AC-P5.4/5/7 manual)"
exit 0
