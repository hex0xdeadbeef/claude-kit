#!/usr/bin/env bash
# F3 (CLAUDE_KIT_BUG_code-reviewer-plugin-skill-resolution) — redundant BUNDLED KIT ROOT
# delegation-prompt channel. The delegation prompt always reaches the agent, so the
# orchestrator copies its own injected BUNDLED KIT ROOT directive into BOTH delegation
# prompts (plan_review + code_review). Reviewer bodies must accept the directive from the
# delegation prompt too. Falsifiable: the pinned markers below are absent before Part 2 lands.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"; cd "$ROOT"
rc=0
pass(){ echo "PASS: $1"; }
fail(){ echo "FAIL: $1"; rc=1; }

DT=".claude/skills/workflow-protocols/delegation-templates.md"
CR=".claude/agents/code-reviewer.md"
PR=".claude/agents/plan-reviewer.md"

# Case A — STEP -3 pre_delegation note present in BOTH delegation blocks (plan_review + code_review)
n_step=$(grep -cF "STEP -3 (F3 — redundant BUNDLED KIT ROOT prompt channel)" "$DT")
if [ "$n_step" -ge 2 ]; then
  pass "delegation-templates: STEP -3 note present in both pre_delegation blocks (count=$n_step)"
else
  fail "delegation-templates: STEP -3 note count=$n_step, expected >=2 (plan_review + code_review)"
fi

# Case B — BUNDLED KIT ROOT prompt-channel line present in BOTH delegation_prompt_template blocks
n_tmpl=$(grep -cF "BUNDLED KIT ROOT directive is present in your (orchestrator) context" "$DT")
if [ "$n_tmpl" -ge 2 ]; then
  pass "delegation-templates: prompt-channel directive in both templates (count=$n_tmpl)"
else
  fail "delegation-templates: prompt-channel directive count=$n_tmpl, expected >=2"
fi

# Case C — both reviewer bodies recognize the delegation prompt as a directive source
for pair in "$CR:code-reviewer" "$PR:plan-reviewer"; do
  f="${pair%%:*}"; label="${pair##*:}"
  if grep -qF "the delegation prompt" "$f"; then
    pass "$label: accepts BUNDLED KIT ROOT directive from the delegation prompt"
  else
    fail "$label: directive-source list missing 'the delegation prompt'"
  fi
done

exit $rc
