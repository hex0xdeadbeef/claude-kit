#!/usr/bin/env bash
# test-genericity-audit.sh
#
# Asserts G1.1..G5.5 from .claude/prompts/plan-stage-genericity-audit-2026-04-27.md
# Tests 2026-04-27 fresh audit: 5 Plan-stage genericity gaps fixed in
# planner.md, plan-reviewer.md, task-analysis.md.
#
# Coverage: 16/19 ACs automated (manual: G1.4, G2.3, G3.3/3.4, G5.5).
# G4.3 is automated.

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

# G1.1 — planner.md clarifying question: Django (not Go) is the FIRST stack mentioned
FIRST_STACK=$(awk '/Layer vocabulary:/,/Use what your codebase/' .claude/commands/planner.md \
                | grep -oE 'Django:|Go:|Spring:' | head -1)
if [[ "$FIRST_STACK" != "Django:" ]]; then
  fail "G1.1 — planner.md layer-vocab question: first stack is '$FIRST_STACK', expected 'Django:'"
fi
pass "G1.1 — planner.md layer-vocab question reordered alphabetically (Django first)"

# G1.2 — no "for Go Clean Architecture" framing
if grep -F 'for Go Clean Architecture' .claude/commands/planner.md >/dev/null 2>&1; then
  fail "G1.2 — 'for Go Clean Architecture' framing still in planner.md"
fi
pass "G1.2 — Go-Clean-Architecture framing removed"

# G1.3 — all 3 stacks present in question block
for stack in 'Django' 'Go' 'Spring'; do
  awk '/Layer vocabulary:/,/Use what your codebase/' .claude/commands/planner.md \
    | grep -q "$stack" \
    || fail "G1.3 — stack '$stack' missing from layer-vocab question"
done
pass "G1.3 — all 3 stacks (Django, Go, Spring) present"

# G2.1 — no `internal/handler/` in delegation_prompt_example active body
# Note: the awk range (delegation_prompt_example: → Context: Planning) ends BEFORE
# the trailing <!-- EXAMPLE (lang: ...) --> comment blocks, so EXAMPLE markers are
# already excluded by range alone — no <!--filter needed.
if awk '/delegation_prompt_example:/,/Context: Planning/' .claude/commands/planner.md \
     | grep -qE 'internal/handler/'; then
  fail "G2.1 — internal/handler/ found in active body of delegation_prompt_example"
fi
pass "G2.1 — internal/handler/ absent from active body (EXAMPLE comments fall outside range)"

# G2.2 — slot syntax used (<INPUT_LAYER> or {INPUT_LAYER})
grep -qE '<INPUT_LAYER>|\{INPUT_LAYER\}' .claude/commands/planner.md \
  || fail "G2.2 — no <INPUT_LAYER>/{INPUT_LAYER} slot syntax in planner.md"
pass "G2.2 — slot syntax present in delegation example"

# G3.1 — no literal "Wiring" in parts_order block (Go-isolated term)
if awk '/^    parts_order:/{flag=1; print; next} /^    [a-z]/{if (flag) {flag=0; exit}} flag' .claude/commands/planner.md \
     | grep -F 'Wiring' >/dev/null 2>&1; then
  fail "G3.1 — literal 'Wiring' still in parts_order block"
fi
pass "G3.1 — 'Wiring' removed from parts_order"

# G3.2 — slot syntax in parts_order
awk '/^    parts_order:/{flag=1; print; next} /^    [a-z]/{if (flag) {flag=0; exit}} flag' .claude/commands/planner.md \
  | grep -qE '<DATA_ACCESS_LAYER>|\{LAYERS\[' \
  || fail "G3.2 — no slot syntax (<DATA_ACCESS_LAYER> or {LAYERS[) in parts_order"
pass "G3.2 — parts_order uses slot-templated patterns"

# G3.5 — fallback_skip_rule documented
grep -q 'fallback_skip_rule' .claude/commands/planner.md \
  || fail "G3.5 — fallback_skip_rule key missing from parts_order block"
pass "G3.5 — fallback_skip_rule documented"

# G4.1 — no Go-specific path/extension in the EXAMPLE bullets (PREFER/ACCEPT/AVOID lines)
# Note: the "Avoid hardcoding..." advisory may legitimately quote Go tokens as anti-patterns
# inside backticks; we scope the check to the bulleted example list only.
if awk '/Location-stability guidance/,/Iteration 2\+/' .claude/agents/plan-reviewer.md \
     | grep -E '^- (PREFER|ACCEPT|AVOID):' \
     | grep -nE 'internal/|handler\.go|service/user\.go|\.go:' >/dev/null 2>&1; then
  fail "G4.1 — Go-specific path/extension still in location-stability example bullets"
fi
pass "G4.1 — location-stability example bullets are language-agnostic"

# G4.2 — at least 2 examples in the bulleted list
EXAMPLE_COUNT=$(awk '/Location-stability guidance/,/Iteration 2\+/' .claude/agents/plan-reviewer.md \
                 | grep -cE '^- (PREFER|ACCEPT|AVOID):' || true)
if [[ "$EXAMPLE_COUNT" -lt 2 ]]; then
  fail "G4.2 — fewer than 2 examples ($EXAMPLE_COUNT) in location-stability bulleted list"
fi
pass "G4.2 — at least 2 examples present (count: $EXAMPLE_COUNT)"

# G4.3 — first PREFER/ACCEPT/AVOID bullet is Part-anchored symbol-only form
FIRST_BULLET=$(awk '/Location-stability guidance/,/Iteration 2\+/' .claude/agents/plan-reviewer.md \
                 | grep -E '^- (PREFER|ACCEPT|AVOID):' | head -1)
if ! echo "$FIRST_BULLET" | grep -qE '^- PREFER:.*Part [0-9]+:'; then
  fail "G4.3 — first bulleted example is not Part-anchored symbol-only form: $FIRST_BULLET"
fi
pass "G4.3 — symbol-only PREFER example is first (Part-anchored)"

# G4.4 — SOURCE_GLOB slot pointer added
awk '/Location-stability guidance/,/Iteration 2\+/' .claude/agents/plan-reviewer.md \
  | grep -q 'SOURCE_GLOB' \
  || fail "G4.4 — SOURCE_GLOB slot pointer not added to location-stability guidance"
pass "G4.4 — SOURCE_GLOB slot pointer present"

# G5.1 — task-analysis L complexity examples have no "controller" / "service" outside EXAMPLE
if awk '/^  L:/,/^  XL:/' .claude/skills/planner-rules/task-analysis.md \
     | grep -nE '\bcontroller\b|\bRefactor controller\b' \
     | grep -vE '^[0-9]+:[[:space:]]*<!--' >/dev/null 2>&1; then
  fail "G5.1 — controller still in L complexity examples active body"
fi
pass "G5.1 — L complexity examples free of controller"

# G5.2 — XL complexity examples have no "controller" outside EXAMPLE
if awk '/^  XL:/,/^```$/' .claude/skills/planner-rules/task-analysis.md \
     | grep -nE '\bcontroller\b' \
     | grep -vE '^[0-9]+:[[:space:]]*<!--' >/dev/null 2>&1; then
  fail "G5.2 — controller still in XL complexity examples active body"
fi
pass "G5.2 — XL complexity examples free of controller"

# G5.3 — Example 2 rationale doesn't have BOTH "controller" AND "handler"
EX2_LINE=$(awk '/Example 2:/,/Example 3:/' .claude/skills/planner-rules/task-analysis.md \
            | grep 'Complexity: L (5 Parts:' || echo '')
if echo "$EX2_LINE" | grep -q 'controller' && echo "$EX2_LINE" | grep -q 'handler'; then
  fail "G5.3 — Example 2 rationale still has BOTH 'controller' AND 'handler' (MVC duality)"
fi
pass "G5.3 — Example 2 rationale free of controller+handler duality"

# G5.4 — LAYERS note added to L or XL block
if ! awk '/^  L:/,/^  XL:/' .claude/skills/planner-rules/task-analysis.md \
       | grep -q 'PROJECT-KNOWLEDGE.md.*LAYERS'; then
  if ! awk '/^  XL:/,/^```$/' .claude/skills/planner-rules/task-analysis.md \
         | grep -q 'PROJECT-KNOWLEDGE.md.*LAYERS'; then
    fail "G5.4 — no PROJECT-KNOWLEDGE.md → LAYERS note in L/XL complexity blocks"
  fi
fi
pass "G5.4 — LAYERS slot pointer present in complexity examples"

# ════════════════════════════════════════════════════════════════════════
# MANUAL
# ════════════════════════════════════════════════════════════════════════
# G1.4 — imperative "Provide a comma-separated list" preserved (visual review)
# G2.3 — resolution rule documented (visual review of the EXAMPLE comment list)
# G2.4 — concrete Go example preserved in EXAMPLE block (visual review)
# G3.3, G3.4 — Tests/Setup/Docs preserved + PK reference (visual review)
# G5.5 — replacement terminology drawn from architecture-neutral set (visual review)

label "INFO" "test-genericity-audit.sh complete — 16/19 ACs automated (manual: G1.4, G2.3-4, G3.3-4, G5.5)"
exit 0
