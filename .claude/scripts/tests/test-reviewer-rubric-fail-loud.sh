#!/usr/bin/env bash
# F1 (CLAUDE_KIT_BUG_code-reviewer-plugin-skill-resolution) — trusted-anchor fail-loud guard.
# Both reviewer bodies MUST forbid a filesystem search for the -rules rubric and instead STOP
# with VERDICT: REJECTED + a setup-error note when the rubric is unresolvable from a trusted
# anchor. Also a regression guard: the Case-C markers consumed by
# test-inject-review-context-bundled-root.sh must remain intact (F1 APPENDS, never replaces).
# Falsifiable: the pinned literals below are absent before Part 1 lands.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"; cd "$ROOT"
rc=0
pass(){ echo "PASS: $1"; }
fail(){ echo "FAIL: $1"; rc=1; }

CR=".claude/agents/code-reviewer.md"
PR=".claude/agents/plan-reviewer.md"

# Case A — fail-loud guard present in both bodies
check_failloud(){ # $1=body  $2=label
  local f="$1" label="$2"
  if grep -qF "Trusted-anchor rule (no filesystem search)" "$f"; then
    pass "$label: trusted-anchor marker present"
  else
    fail "$label: missing 'Trusted-anchor rule (no filesystem search)' marker"
  fi
  if grep -qF "MUST NOT search the filesystem" "$f"; then
    pass "$label: filesystem-search prohibition present"
  else
    fail "$label: missing 'MUST NOT search the filesystem' prohibition"
  fi
  # fail-loud STOP path references the legal REJECTED enum + the setup-error note
  if grep -qF "VERDICT: REJECTED" "$f" && grep -qF "Rubric unresolvable" "$f"; then
    pass "$label: fail-loud REJECTED + setup-error note present"
  else
    fail "$label: missing VERDICT: REJECTED / 'Rubric unresolvable' setup-error path"
  fi
}
check_failloud "$CR" "code-reviewer"
check_failloud "$PR" "plan-reviewer"

# Case B — regression guard: Case-C markers preserved (test-inject-review-context-bundled-root.sh)
check_casec(){ # $1=body  $2=skill-path  $3=label
  local f="$1" skill="$2" label="$3"
  local marker_line
  marker_line=$(grep -n "Load your review rules:" "$f" 2>/dev/null || true)
  if [ -n "$marker_line" ] && echo "$marker_line" | grep -qF "$skill" && grep -q "BUNDLED KIT ROOT" "$f"; then
    pass "$label: Case-C markers preserved (Load your review rules: + skill path + BUNDLED KIT ROOT)"
  else
    fail "$label: Case-C markers broken by F1 edit"
  fi
}
check_casec "$CR" ".claude/skills/code-review-rules/SKILL.md" "code-reviewer"
check_casec "$PR" ".claude/skills/plan-review-rules/SKILL.md" "plan-reviewer"

# Case C — envelope-shape guard (PR-001): exactly ONE column-0 ^VERDICT: line per body
check_verdict_count(){ # $1=body  $2=label
  local n; n=$(grep -c '^VERDICT: ' "$1")
  if [ "$n" -eq 1 ]; then
    pass "$2: exactly 1 column-0 ^VERDICT: line (envelope intact)"
  else
    fail "$2: expected 1 column-0 ^VERDICT: line, found $n (F1 literal leaked to column 0)"
  fi
}
check_verdict_count "$CR" "code-reviewer"
check_verdict_count "$PR" "plan-reviewer"

exit $rc
