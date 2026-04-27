#!/usr/bin/env bash
# test-p4-required-sections-skip.sh
#
# Asserts AC-P4.1..AC-P4.5 from .claude/prompts/plan-stage-generic-spec.md §8 P4
# Tests v1.16.0 P4: required-sections.md "data → business → api" fallback → SKIP per LAYERS
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

# AC-P4.1: no "data → business → api" fallback in required-sections.md
if grep -nE 'data[[:space:]]*[→>][[:space:]]*business[[:space:]]*[→>][[:space:]]*api' .claude/skills/plan-review-rules/required-sections.md 2>/dev/null; then
  fail "AC-P4.1 — 'data → business → api' fallback still in required-sections.md"
fi
pass "AC-P4.1 — no 'data → business → api' fallback in required-sections.md"

# AC-P4.2: no "fallback if LAYERS unset" wording — SKIP-with-NIT used instead
if grep -F 'fallback if LAYERS unset' .claude/skills/plan-review-rules/required-sections.md 2>/dev/null; then
  fail "AC-P4.2 — pre-fix 'fallback if LAYERS unset' wording still present"
fi
pass "AC-P4.2 — pre-fix fallback wording removed"

# AC-P4.3: required-sections.md follows canonical SKIP-with-NIT pattern from architecture-checks.md
grep -q 'SKIP\|skip_if_unset\|consolidated NIT' .claude/skills/plan-review-rules/required-sections.md \
  || fail "AC-P4.3 — required-sections.md missing canonical SKIP semantics"
pass "AC-P4.3 — required-sections.md uses SKIP-with-NIT canonical pattern"

# AC-P4.4: architecture-checks.md L22-33 canonical SKIP rule still defined
grep -q 'If a slot is unset' .claude/skills/plan-review-rules/architecture-checks.md \
  || fail "AC-P4.4 — architecture-checks.md missing canonical SKIP definition"
pass "AC-P4.4 — architecture-checks.md canonical SKIP rule preserved"

# ════════════════════════════════════════════════════════════════════════
# MANUAL
# ════════════════════════════════════════════════════════════════════════
# AC-P4.5: Kit dogfood — LAYERS set, reviewer order check still produces identical output
#   Procedure: replay fixed plan with LAYERS=[orchestrator,reviewers,enforcement,knowledge]
#   Expected: identical reviewer output pre/post P4 fix on kit dogfood.

label "INFO" "test-p4-required-sections-skip.sh complete — 4/5 AC automated (AC-P4.5 manual)"
exit 0
