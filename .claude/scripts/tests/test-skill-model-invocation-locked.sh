#!/usr/bin/env bash
# test-skill-model-invocation-locked.sh — I-05 (REFRAMED, see deviation note below).
#
# Original plan: add `skillOverrides: name-only` for 8 internal skills to save per-session
# tokens (2.1.129). NEEDS_VALIDATION during implementation revealed this is a FALSE-POSITIVE
# benefit: the 7 internal rule-skills already carry `disable-model-invocation: true` in their
# SKILL.md frontmatter, which removes them from the model's skill listing ENTIRELY (strictly
# stronger than name-only, which only collapses the description while keeping the skill
# model-visible). Applying name-only would be a no-op at best and could UN-HIDE fully-hidden
# skills at worst. So the settings.json change was dropped.
#
# This guard delivers the HONEST benefit: lock the existing optimization. If a future edit
# removes `disable-model-invocation: true` from any internal rule-skill, its description would
# silently re-inject into every session's skill listing — this test catches that regression.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${SCRIPT_DIR}/../../skills"
SETTINGS="${SCRIPT_DIR}/../../settings.json"
PASS=0; FAIL=0
echo "=== test-skill-model-invocation-locked.sh ==="

# Internal rule-skills that MUST stay hidden from model invocation (description not injected).
INTERNAL_SKILLS="workflow-protocols planner-rules coder-rules plan-review-rules code-review-rules design-rules tdd-rules"
for s in $INTERNAL_SKILLS; do
  f="${SKILLS_DIR}/${s}/SKILL.md"
  if [[ ! -f "$f" ]]; then
    echo "  FAIL: ${s}/SKILL.md not found"; FAIL=$((FAIL+1)); continue
  fi
  if grep -Eq '^disable-model-invocation:[[:space:]]*true' "$f"; then
    echo "  PASS: ${s} retains disable-model-invocation: true"; PASS=$((PASS+1))
  else
    echo "  FAIL: ${s} lost disable-model-invocation: true → its description would re-inject into the model skill listing"; FAIL=$((FAIL+1))
  fi
done

# Negative guard: no skill may be mapped to skillOverrides:off (would also hide from `/` and
# break command-driven Skill-tool loading). Absent skillOverrides or name-only is fine.
if command -v jq >/dev/null 2>&1 && [[ -f "$SETTINGS" ]]; then
  offcount="$(jq -r '(.skillOverrides // {}) | to_entries | map(select(.value=="off")) | length' "$SETTINGS" 2>/dev/null || echo 0)"
  case "$offcount" in ''|*[!0-9]*) offcount=0 ;; esac
  if [[ "$offcount" -eq 0 ]]; then
    echo "  PASS: no skill mapped to skillOverrides:off"; PASS=$((PASS+1))
  else
    echo "  FAIL: ${offcount} skill(s) mapped to skillOverrides:off — would break command Skill-tool loading"; FAIL=$((FAIL+1))
  fi
fi

echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ "${FAIL}" -eq 0 ]] && exit 0 || exit 1
