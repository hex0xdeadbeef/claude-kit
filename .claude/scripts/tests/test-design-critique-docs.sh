#!/usr/bin/env bash
# Test (Part 4 / D1): the adversarial-design-critique feature is documented. CLAUDE.md has a
# concise note, the two review-relevant agent-memory catalogs mention it, and the design artifact
# status reflects GATE 2 approval + implementation. Asserts AC4.1, AC4.1b/c/d, AC4.2.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"; cd "$ROOT" || { echo "FAIL: cannot cd to repo root"; exit 1; }
CMD="CLAUDE.md"
PRMEM=".claude/agent-memory/plan-reviewer/MEMORY.md"
CRMEM=".claude/agent-memory/code-researcher/MEMORY.md"
ART=".claude/workflow-feature-2026-06-02.md"
rc=0; fail(){ echo "FAIL: $1"; rc=1; }; pass(){ echo "PASS: $1"; }

# DOC-1 (AC4.1): CLAUDE.md documents the critique sub-phase
if grep -qiE 'Design Critique|Phase 3\.5' "$CMD" && grep -q "design_critique" "$CMD"; then
  pass "DOC-1 CLAUDE.md documents the critique sub-phase"
else
  fail "DOC-1 CLAUDE.md missing critique sub-phase note"
fi

# DOC-2 (AC4.1b): plan-reviewer agent-memory mentions design_critique
if grep -q "design_critique" "$PRMEM"; then pass "DOC-2 plan-reviewer memory mentions design_critique"; else fail "DOC-2 plan-reviewer memory missing design_critique"; fi

# DOC-3 (AC4.1c): code-researcher agent-memory mentions critique-lenses
if grep -q "critique-lenses" "$CRMEM"; then pass "DOC-3 code-researcher memory mentions critique-lenses"; else fail "DOC-3 code-researcher memory missing critique-lenses"; fi

# DOC-4 (AC4.1d / PR-003): design artifact status reflects GATE 2 approval AND implementation
if grep -qE '^\s*gate_2_parts:\s*APPROVED' "$ART" && grep -qE '^\s*status:\s*implemented' "$ART"; then
  pass "DOC-4 design artifact status: implemented + gate_2_parts: APPROVED"
else
  fail "DOC-4 design artifact status/gate_2_parts not updated"
fi

# DOC-5 (AC4.2 / PR-001): CLAUDE.md within the 200-line size budget (path-independent wc -l)
LINES="$(wc -l < "$CMD" | tr -d ' ')"
if [[ "$LINES" -le 200 ]]; then pass "DOC-5 CLAUDE.md within 200-line budget ($LINES)"; else fail "DOC-5 CLAUDE.md exceeds 200-line budget ($LINES)"; fi

[ "$rc" -eq 0 ] && echo "ALL PASS: test-design-critique-docs" || echo "SOME FAILED: test-design-critique-docs"
exit "$rc"
