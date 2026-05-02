#!/usr/bin/env bash
# test-decision-matrix-consistency.sh
# AC-P1-3: byte-identical CHANGES_REQUESTED MINOR threshold across code-reviewer.md and code-review-rules/SKILL.md
set -euo pipefail
SCRIPT_NAME="$(basename "$0")"
PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
label() { echo "[${SCRIPT_NAME}] $1: $2" >&2; }
fail() { label "FAIL" "$1"; exit 1; }
pass() { label "PASS" "$1"; }
cd "$PROJECT_ROOT"

REVIEWER=".claude/agents/code-reviewer.md"
SKILL=".claude/skills/code-review-rules/SKILL.md"

# AC-P1-3a: SKILL.md uses the per-file 5+ MINOR wording (NOT the legacy '3+ MINOR (return to coder)')
if grep -qE '^\s*-\s+CHANGES_REQUESTED:\s+1\+ BLOCKER or 1\+ MAJOR or 3\+ MINOR ' "$SKILL"; then
  fail "AC-P1-3a — SKILL.md still uses legacy '3+ MINOR' threshold"
fi
grep -qE '^\s*-\s+CHANGES_REQUESTED:\s+1\+ BLOCKER or 1\+ MAJOR or 5\+ MINOR same file' "$SKILL" \
  || fail "AC-P1-3a — SKILL.md does not use canonical '5+ MINOR same file' threshold"
pass "AC-P1-3a — SKILL.md uses canonical 5+ MINOR same file threshold"

# AC-P1-3b: code-reviewer.md uses the same wording
grep -qE '^\s*-\s+CHANGES_REQUESTED:\s+1\+ BLOCKER or 1\+ MAJOR or 5\+ MINOR same file' "$REVIEWER" \
  || fail "AC-P1-3b — code-reviewer.md does not use '5+ MINOR same file' threshold"
pass "AC-P1-3b — code-reviewer.md uses canonical 5+ MINOR same file threshold"

# AC-P1-3c: auto-escalation rule is byte-identical between the two files
ESC_REVIEWER=$(grep -E '5\+ MINOR in same file → escalate to MAJOR' "$REVIEWER" | head -1 | sed 's/^[[:space:]]*-[[:space:]]*//')
ESC_SKILL=$(grep -E '5\+ MINOR in same file → escalate to MAJOR' "$SKILL" | head -1 | sed 's/^[[:space:]]*-[[:space:]]*//')
[[ -n "$ESC_REVIEWER" ]] || fail "AC-P1-3c — auto-escalation rule missing in code-reviewer.md"
[[ -n "$ESC_SKILL" ]]    || fail "AC-P1-3c — auto-escalation rule missing in SKILL.md"
[[ "$ESC_REVIEWER" == "$ESC_SKILL" ]] \
  || fail "AC-P1-3c — auto-escalation rule differs:
  reviewer: $ESC_REVIEWER
  skill:    $ESC_SKILL"
pass "AC-P1-3c — auto-escalation rule byte-identical across both files"

# AC-P1-3d: cross-reference bullet from Edit 1.4 is present in code-reviewer.md as a proper bullet (3-space indent + '- ')
grep -qE '^   - See also `\.claude/skills/code-review-rules/SKILL\.md` § Decision Matrix — the `5\+ MINOR same file` threshold is byte-identical between the two files\.$' "$REVIEWER" \
  || fail "AC-P1-3d — Edit 1.4 cross-reference bullet missing or malformed (must be a sub-bullet '   - See also ...')"
pass "AC-P1-3d — cross-reference bullet present with correct indentation + prefix"

label "PASS" "test-decision-matrix-consistency.sh — all assertions met"
