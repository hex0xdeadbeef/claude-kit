#!/usr/bin/env bash
# Test (Part 1 / contract-safety guard): the design-critique feature must NOT touch the
# hashed/locked pipeline path. Asserts AC1.8 (SubagentStop matcher unchanged), AC1.9 (no new H2),
# AC1.10 (designer_to_planner has no $handoff_contract in Part 1), and that no new design
# artifact wires save-review-checkpoint.sh (canonical-ID hash path untouched).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"; cd "$ROOT" || { echo "FAIL: cannot cd to repo root"; exit 1; }
SETTINGS=".claude/settings.json"
HC=".claude/skills/workflow-protocols/handoff-contracts.md"
LENS=".claude/skills/design-rules/critique-lenses.md"
TPL=".claude/templates/spec-template.md"
rc=0; fail(){ echo "FAIL: $1"; rc=1; }; pass(){ echo "PASS: $1"; }

# CS-1 (AC1.8): SubagentStop matcher is the expected value, untouched by design-critique
# (post matcher-hardening forward-compat fix: (claude-kit:)?(plan-reviewer|code-reviewer|verdict-recovery))
if grep -q '"(claude-kit:)?(plan-reviewer|code-reviewer|verdict-recovery)"' "$SETTINGS"; then pass "CS-1 SubagentStop matcher intact"; else fail "CS-1 SubagentStop matcher changed"; fi
# CS-1b: no design-critic / design-reviewer agent wired anywhere in settings (Part 1 + GATE-2 excluded Part 3)
if grep -qiE 'design-critic|design-reviewer' "$SETTINGS"; then fail "CS-1b a design critic/reviewer agent leaked into settings.json"; else pass "CS-1b no design critic agent in settings.json"; fi

# CS-2 (AC1.10): designer_to_planner contract has NO $handoff_contract discriminator (Part 1).
# Extract ONLY the designer_to_planner block — stop at the next contract key so we do not
# bleed into planner_to_plan_review (which legitimately carries $handoff_contract).
D2P="$(awk '/^[[:space:]]*designer_to_planner:/{f=1} /^[[:space:]]*planner_to_plan_review:/{f=0} f' "$HC")"
if printf '%s' "$D2P" | grep -q 'handoff_contract'; then fail "CS-2 designer_to_planner gained a \$handoff_contract (Part 1 must not)"; else pass "CS-2 designer_to_planner still non-schema-validated"; fi

# CS-3 (AC1.9): design_critique never introduced as an H2 (caveman-protected H2 set untouched)
if grep -qE '^##[[:space:]]+[Dd]esign.[Cc]ritique' "$TPL"; then fail "CS-3 design_critique is an H2 (caveman risk)"; else pass "CS-3 design_critique is not an H2"; fi

# CS-4: no new design artifact references save-review-checkpoint.sh (canonical-ID hash path)
leak=""
for f in "$LENS" ".claude/commands/designer.md" "$TPL" ".claude/skills/design-rules/SKILL.md" ".claude/skills/design-rules/design-checklist.md" ".claude/skills/design-rules/spec-quality.md"; do
  [[ -f "$f" ]] || continue
  grep -q "save-review-checkpoint" "$f" && leak="$leak $f"
done
if [[ -z "$leak" ]]; then pass "CS-4 no design artifact wires save-review-checkpoint.sh"; else fail "CS-4 save-review-checkpoint referenced by:$leak"; fi

[ "$rc" -eq 0 ] && echo "ALL PASS: test-design-critique-contract-safety" || echo "SOME FAILED: test-design-critique-contract-safety"
exit "$rc"
