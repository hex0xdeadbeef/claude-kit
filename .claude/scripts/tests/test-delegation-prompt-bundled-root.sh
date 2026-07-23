#!/usr/bin/env bash
# F3 (CLAUDE_KIT_BUG_code-reviewer-plugin-skill-resolution) — redundant BUNDLED KIT ROOT
# delegation-prompt channel. The delegation prompt always reaches the agent, so the
# orchestrator copies its own injected BUNDLED KIT ROOT directive into BOTH delegation
# prompts (plan_review + code_review). Reviewer bodies must accept the directive from the
# delegation prompt too. Falsifiable: the pinned markers below are absent before the change lands.
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

# ── B2 (BUGREPORT-plugin-mode-2026-06-09): plugin-safe sidecar path + F4 verify ──

# Case D — STEP -2 resolves the sidecar script under the .bundled-kit-root marker
if grep -qF '.bundled-kit-root' "$DT"; then
  pass "delegation-templates: STEP -2 resolves bundled script via .bundled-kit-root marker"
else
  fail "delegation-templates: STEP -2 missing .bundled-kit-root marker resolution"
fi

# Case E (PR-003) — no bare project-relative pipe-prefixed sidecar invocation remains.
# Scope the negative assertion to the EXECUTABLE pipe form, not prose mentions of the script name,
# so the STATUS-block rationale that references inject-review-context.sh does not trip it.
if grep -qF '| bash .claude/scripts/inject-review-context.sh' "$DT"; then
  fail "delegation-templates: bare project-relative '| bash .claude/scripts/inject-review-context.sh' invocation still present (breaks plugin mode)"
else
  pass "delegation-templates: no bare project-relative sidecar invocation remains (PR-003 scope)"
fi

# Case F — STEP -2 carries the F4 non-empty-sidecar verify gate
if grep -qF 'test -s .claude/workflow-state/code-reviewer-INJECTED-CONTEXT.md' "$DT"; then
  pass "delegation-templates: STEP -2 F4 non-empty-sidecar verify gate present"
else
  fail "delegation-templates: STEP -2 F4 verify gate missing"
fi

exit $rc
