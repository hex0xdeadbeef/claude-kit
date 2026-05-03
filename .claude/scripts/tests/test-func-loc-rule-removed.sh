#!/usr/bin/env bash
# test-func-loc-rule-removed.sh
# AC-P4.1..AC-P4.7: hardcoded "Functions ≤ 30 lines" rule fully removed; linter delegation preserved.
set -euo pipefail
SCRIPT_NAME="$(basename "$0")"
PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
label() { echo "[${SCRIPT_NAME}] $1: $2" >&2; }
fail() { label "FAIL" "$1"; exit 1; }
pass() { label "PASS" "$1"; }
cd "$PROJECT_ROOT"

# AC-P4.1 + AC-P4.2: rule removed from code-reviewer.md AND code-review-rules/
PATTERNS='Functions[[:space:]]*[≤<=]+[[:space:]]*30[[:space:]]*lines|≤[[:space:]]*30[[:space:]]*lines[[:space:]]*\(flag[[:space:]]*if[[:space:]]*exceeded\)|Functions <= 30 lines'

if grep -rE "$PATTERNS" .claude/agents/code-reviewer.md .claude/skills/code-review-rules/ 2>/dev/null; then
  fail "AC-P4.1+P4.2 — function-length 30-line rule still present in reviewer-side files"
fi
pass "AC-P4.1+P4.2 — rule removed from reviewer-side files"

# AC-P4.3: no FUNC_LOC_LIMIT slot reintroduced
if grep -rE 'FUNC_LOC_LIMIT' .claude/PROJECT-KNOWLEDGE.md.example .claude/agents/ .claude/skills/ 2>/dev/null; then
  fail "AC-P4.3 — FUNC_LOC_LIMIT slot reintroduced (cdc0e85 regression)"
fi
pass "AC-P4.3 — no FUNC_LOC_LIMIT slot"

# AC-P4.4: no LANGUAGE-conditional path for function-length
if grep -rE 'LANGUAGE.*function.*length|function.*length.*LANGUAGE' .claude/agents/code-reviewer.md .claude/skills/code-review-rules/ 2>/dev/null; then
  fail "AC-P4.4 — LANGUAGE-conditional function-length path detected"
fi
pass "AC-P4.4 — no LANGUAGE-conditional function-length path"

# AC-P4.5 — covered by AC-P4.1+P4.2 grep (zero matches assertion)
pass "AC-P4.5 — grep assertion satisfied (zero matches)"

# AC-P4.6: coder.md Phase 3 VERIFY references LINT_CMD (linter responsibility preserved)
grep -q '{LINT_CMD}' .claude/commands/coder.md \
  || fail "AC-P4.6 — coder.md Phase 3 VERIFY does not reference LINT_CMD"
pass "AC-P4.6 — LINT_CMD reference preserved in coder.md"

# AC-P4.7: existing decision-matrix consistency test still passes
bash .claude/scripts/tests/test-decision-matrix-consistency.sh >/dev/null 2>&1 \
  || fail "AC-P4.7 — test-decision-matrix-consistency.sh regressed"
pass "AC-P4.7 — decision-matrix-consistency preserved"

label "PASS" "all AC-P4.* assertions passed"
