#!/usr/bin/env bash
# test-c1-code-shapes-reuse.sh
#
# Asserts AC-C1.1..AC-C1.6 from .claude/prompts/coder-code-review-generic-analysis.md §8 C1
# Tests Part 2 (C1 — Reuse planner-rules/code-shapes/)

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

label() { echo "[${SCRIPT_NAME}] $1: $2" >&2; }
fail() { label "FAIL" "$1"; exit 1; }
pass() { label "PASS" "$1"; }

cd "$PROJECT_ROOT"

# ════════════════════════════════════════════════════════════════════════
# AUTOMATED (CI-runnable grep predicates)
# ════════════════════════════════════════════════════════════════════════

# AC-C1.1: no inline lang-named EXAMPLE blocks in scope
if grep -lE '<!-- EXAMPLE \(lang:' .claude/skills/coder-rules/examples.md .claude/skills/code-review-rules/examples.md 2>/dev/null; then
  fail "AC-C1.1 — inline lang-named EXAMPLE blocks present in coder-rules/code-review-rules examples.md"
fi
pass "AC-C1.1 — no inline lang-named examples in scope"

# AC-C1.2: examples.md contains 'reference_shapes' selector
grep -q 'reference_shapes' .claude/skills/coder-rules/examples.md || fail "AC-C1.2a — coder-rules/examples.md missing reference_shapes block"
grep -q 'reference_shapes' .claude/skills/code-review-rules/examples.md || fail "AC-C1.2b — code-review-rules/examples.md missing reference_shapes block"
pass "AC-C1.2 — reference_shapes selector present in both examples.md files"

# AC-C1.3: 'UNIVERSAL PATTERNS (apply to any Go project)' header replaced
if grep -F 'UNIVERSAL PATTERNS (apply to any Go project)' .claude/skills/coder-rules/examples.md; then
  fail "AC-C1.3 — Go-only UNIVERSAL header still in coder-rules/examples.md (must be replaced with reuse pattern + kit-dogfood section)"
fi
pass "AC-C1.3 — UNIVERSAL Go header removed/relabeled"

# AC-C1.4: 7 code-shapes/ files exist (provided by 1.16.0; reuse means no duplication)
for lang in go python typescript rust java _default INVARIANTS; do
  [[ -f ".claude/skills/planner-rules/code-shapes/${lang}.md" ]] \
    || fail "AC-C1.4 — code-shapes/${lang}.md missing (reused via reference, MUST exist)"
done
pass "AC-C1.4 — 7 code-shapes/ files present (5 langs + default + INVARIANTS)"

# AC-C1.6: handoff.schema.json + checkpoint format unchanged (constraints C1, C3)
# Pre-merge gate: assert diff between current HEAD and origin/main merge-base.
# On main itself: skip with INFO (post-merge contract changes are caught by /workflow plan-review).
if [[ -d .git ]]; then
  CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
  if [[ "$CURRENT_BRANCH" == "main" ]]; then
    label "INFO" "AC-C1.6 — skipped (running on main; pre-merge gate only — see CR-003)"
  else
    BASE="$(git merge-base HEAD origin/main 2>/dev/null || echo main)"
    git diff "$BASE"..HEAD -- .claude/schemas/handoff.schema.json .claude/skills/workflow-protocols/checkpoint-protocol.md > /tmp/c1-schema-diff.txt 2>&1 || true
    if [[ -s /tmp/c1-schema-diff.txt ]]; then
      fail "AC-C1.6 — handoff.schema.json or checkpoint-protocol.md was modified (forbidden per C1, C3)"
    fi
    rm -f /tmp/c1-schema-diff.txt
    pass "AC-C1.6 — schema/checkpoint contracts unchanged"
  fi
fi

# ════════════════════════════════════════════════════════════════════════
# MANUAL (operator procedure — not CI-automated)
# ════════════════════════════════════════════════════════════════════════
# AC-C1.5: Kit-dogfood byte-equivalent regression on Go fixture
#   Procedure: run /coder on a fixed Go-shaped fixture pre/post change,
#   diff plan output. Expected: byte-identical (modulo header).
#   Not automated — requires /coder agent invocation outside test scope.

label "INFO" "test-c1-code-shapes-reuse.sh complete — 5/6 AC asserted (AC-C1.5 manual)"
exit 0
