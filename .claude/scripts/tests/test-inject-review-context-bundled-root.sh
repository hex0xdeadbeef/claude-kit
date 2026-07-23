#!/usr/bin/env bash
# RED-first test for R1 (reviewer-rule-delivery): inject-review-context.sh must emit the
# BUNDLED KIT ROOT directive in plugin mode (Cases A/B), and both reviewer bodies must carry an
# explicit rules-Read STARTUP step (Case C). Staged in /tmp for the pre-implementation RED demo;
# final copy lands at .claude/scripts/tests/ (ROOT derived from BASH_SOURCE) when the guard opens.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"; cd "$ROOT"
rc=0
pass(){ echo "PASS: $1"; }
fail(){ echo "FAIL: $1"; rc=1; }

# Case A — plugin mode (CLAUDE_PLUGIN_ROOT set) → directive present with abs path
SB=$(mktemp -d -t injbundleA.XXXXXX)
printf 'feature: feat-a\ncomplexity: L\nphase_completed: 4\niteration:\n  plan_review: 1/3\n  code_review: 1/3\n' > "$SB/feat-a-checkpoint.yaml"
OUTA=$(echo '{"session_id":"x"}' | CLAUDE_PLUGIN_ROOT="/fake/plugin" CLAUDE_WORKFLOW_STATE_DIR="$SB" bash .claude/scripts/inject-review-context.sh plan-reviewer 2>/dev/null || true)
rm -rf "$SB"
if echo "$OUTA" | grep -q "BUNDLED KIT ROOT" && echo "$OUTA" | grep -q "/fake/plugin"; then
  pass "A: plugin mode emits BUNDLED KIT ROOT + abs path"
else
  fail "A: plugin mode missing BUNDLED KIT ROOT directive / abs path"
fi

# Case B — project-scoped install (env unset, bundled root == project root) → directive ABSENT (inert).
# CLAUDE_PROJECT_DIR == $ROOT (the script's own bundled root); env -u guarantees no ambient
# CLAUDE_PLUGIN_ROOT masks the inert assertion.
SB=$(mktemp -d -t injbundleB.XXXXXX)
printf 'feature: feat-b\ncomplexity: L\nphase_completed: 4\niteration:\n  plan_review: 1/3\n  code_review: 1/3\n' > "$SB/feat-b-checkpoint.yaml"
OUTB=$(echo '{"session_id":"x"}' | env -u CLAUDE_PLUGIN_ROOT CLAUDE_PROJECT_DIR="$ROOT" CLAUDE_WORKFLOW_STATE_DIR="$SB" bash .claude/scripts/inject-review-context.sh plan-reviewer 2>/dev/null || true)
rm -rf "$SB"
if echo "$OUTB" | grep -q "BUNDLED KIT ROOT"; then
  fail "B: project-scoped (bundled==project) leaked directive"
else
  pass "B: project-scoped (bundled==project) inert (no directive)"
fi

# Case C — both reviewer bodies carry the pinned STARTUP marker 'Load your review rules:' co-located
# with their exact skill path, AND mention BUNDLED KIT ROOT (falsifiable: literal absent today)
check_body(){ # $1=body file  $2=skill path
  local marker_line
  marker_line=$(grep -n "Load your review rules:" "$1" 2>/dev/null || true)
  if [ -n "$marker_line" ] && echo "$marker_line" | grep -qF "$2" && grep -q "BUNDLED KIT ROOT" "$1"; then
    pass "C: $(basename "$1") has 'Load your review rules:' + skill path + bundled-root note"
  else
    fail "C: $(basename "$1") missing pinned STARTUP rules-Read marker"
  fi
}
check_body .claude/agents/plan-reviewer.md ".claude/skills/plan-review-rules/SKILL.md"
check_body .claude/agents/code-reviewer.md ".claude/skills/code-review-rules/SKILL.md"

# Case D — plugin mode + NO checkpoint (early-exit path) still carries the directive
SB=$(mktemp -d -t injbundleD.XXXXXX)   # empty: no *-checkpoint.yaml -> hook hits "No checkpoint found"
OUTD=$(echo '{"session_id":"x"}' | CLAUDE_PLUGIN_ROOT="/fake/plugin" CLAUDE_WORKFLOW_STATE_DIR="$SB" bash .claude/scripts/inject-review-context.sh plan-reviewer 2>/dev/null || true)
rm -rf "$SB"
if echo "$OUTD" | grep -q "BUNDLED KIT ROOT"; then
  pass "D: plugin mode + no checkpoint (early-exit) still emits directive"
else
  fail "D: early-exit path dropped BUNDLED KIT ROOT directive"
fi

# Case E — env-unset plugin mode: Claude Code does NOT export CLAUDE_PLUGIN_ROOT to SubagentStart
# hook processes (anthropics/claude-code#27145), but bundled root != project root → directive present,
# anchored at the bundled root (== $ROOT, the script's own location). FAILS against pre-fix code.
SB=$(mktemp -d -t injbundleE.XXXXXX)
printf 'feature: feat-e\ncomplexity: L\nphase_completed: 4\niteration:\n  plan_review: 1/3\n  code_review: 1/3\n' > "$SB/feat-e-checkpoint.yaml"
OUTE=$(echo '{"session_id":"x"}' | env -u CLAUDE_PLUGIN_ROOT CLAUDE_PROJECT_DIR="$SB" CLAUDE_WORKFLOW_STATE_DIR="$SB" bash .claude/scripts/inject-review-context.sh plan-reviewer 2>/dev/null || true)
rm -rf "$SB"
if echo "$OUTE" | grep -q "BUNDLED KIT ROOT" && echo "$OUTE" | grep -qF "$ROOT"; then
  pass "E: env-unset plugin mode (bundled != project) emits directive + bundled root"
else
  fail "E: env-unset plugin mode dropped BUNDLED KIT ROOT directive"
fi

echo "rc=$rc"
exit $rc
