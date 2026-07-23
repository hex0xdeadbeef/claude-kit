#!/usr/bin/env bash
# test-st-trigger-threshold-alignment.sh
# Audit F4: Sequential-Thinking trigger thresholds must AGREE between the
# planner-author files and the reviewer-grader files. Canonical pair =
# (Architecture layers >= 3, Parts in plan >= 4). The planner-author side is
# canonicalized DOWN to match the reviewer side (which ENFORCES 4/3 as MAJOR)
# and the planner-rules routing table (L = 4-6 Parts / 3+ layers).
# Content-anchored (no line-number addressing).
set -euo pipefail
SCRIPT_NAME="$(basename "$0")"
PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
label() { echo "[${SCRIPT_NAME}] $1: $2" >&2; }
fail() { label "FAIL" "$1"; exit 1; }
pass() { label "PASS" "$1"; }
cd "$PROJECT_ROOT"

PLANNER=".claude/commands/planner.md"
P_SKILL=".claude/skills/planner-rules/SKILL.md"
P_TROUBLE=".claude/skills/planner-rules/troubleshooting.md"
GUIDE=".claude/skills/planner-rules/sequential-thinking-guide.md"
R_SKILL=".claude/skills/plan-review-rules/SKILL.md"

# AC-F4-1: planner.md use_when uses the canonical pair and NO looser trigger remains.
grep -qF "Architecture layers >= 3" "$PLANNER" \
  || fail "AC-F4-1 — planner.md missing canonical 'Architecture layers >= 3'"
grep -qF "Parts in plan >= 4" "$PLANNER" \
  || fail "AC-F4-1 — planner.md missing canonical 'Parts in plan >= 4'"
grep -qF "Architecture layers >= 4" "$PLANNER" \
  && fail "AC-F4-1 — planner.md still has looser 'Architecture layers >= 4' ST trigger"
grep -qF "Parts in plan >= 5" "$PLANNER" \
  && fail "AC-F4-1 — planner.md still has looser 'Parts in plan >= 5' ST trigger"
pass "AC-F4-1 — planner.md use_when uses canonical layers>=3 / Parts>=4 (no looser trigger)"

# AC-F4-2: planner-rules SKILL + troubleshooting have NO residual 5+ Parts threshold or cause prose.
for f in "$P_SKILL" "$P_TROUBLE"; do
  grep -qiE "Parts >= 5|Parts ≥ 5|5\+ parts" "$f" \
    && fail "AC-F4-2 — residual 5-Parts threshold/cause in $f"
done
grep -qE "Parts >= 4" "$P_SKILL" \
  || fail "AC-F4-2 — planner-rules/SKILL.md fix line missing canonical 'Parts >= 4'"
grep -qE "Parts ≥ 4" "$P_TROUBLE" \
  || fail "AC-F4-2 — troubleshooting.md fix line missing canonical 'Parts ≥ 4'"
pass "AC-F4-2 — planner-rules SKILL+troubleshooting aligned to Parts>=4, no residual 5+ tokens"

# AC-F4-3: reviewer-grader side UNCHANGED and still 4/3 — planner-author and reviewer AGREE.
grep -qF "Architecture layers >= 3" "$GUIDE" \
  || fail "AC-F4-3 — sequential-thinking-guide.md drifted off 'layers >= 3'"
grep -qF "Parts in plan >= 4" "$GUIDE" \
  || fail "AC-F4-3 — sequential-thinking-guide.md drifted off 'Parts in plan >= 4'"
grep -qF "4+ Parts, 3+ layers" "$R_SKILL" \
  || fail "AC-F4-3 — plan-review-rules/SKILL.md drifted off '4+ Parts, 3+ layers'"
pass "AC-F4-3 — reviewer-grader side still 4/3; planner-author and reviewer thresholds AGREE"

label "PASS" "test-st-trigger-threshold-alignment.sh — all assertions met"
