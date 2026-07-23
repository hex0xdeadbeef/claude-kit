#!/usr/bin/env bash
# F5 (CLAUDE_KIT_BUG_code-reviewer-plugin-skill-resolution) — rubric provenance observability.
# Both reviewers MUST report the absolute path they loaded the -rules skill from and WARN when
# that path is outside the active BUNDLED KIT ROOT (turns a silent wrong-source load into a
# visible one). Envelope guard: F5 is output-line-only — it must NOT add a column-0
# ^VERDICT: line. Falsifiable: the pinned markers below are absent before the change lands.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"; cd "$ROOT"
rc=0
pass(){ echo "PASS: $1"; }
fail(){ echo "FAIL: $1"; rc=1; }

CR=".claude/agents/code-reviewer.md"
PR=".claude/agents/plan-reviewer.md"

check_provenance(){ # $1=body  $2=label
  local f="$1" label="$2"
  if grep -qF "Rubric loaded from:" "$f"; then
    pass "$label: 'Rubric loaded from:' provenance line present"
  else
    fail "$label: missing 'Rubric loaded from:' provenance line"
  fi
  if grep -qF "rubric loaded from outside the active BUNDLED KIT ROOT" "$f"; then
    pass "$label: off-root drift WARN present"
  else
    fail "$label: missing off-root 'outside the active BUNDLED KIT ROOT' WARN"
  fi
  # envelope guard: F5 must not introduce a column-0 ^VERDICT: line
  local n; n=$(grep -c '^VERDICT: ' "$f")
  if [ "$n" -eq 1 ]; then
    pass "$label: exactly 1 column-0 ^VERDICT: line (F5 envelope intact)"
  else
    fail "$label: expected 1 column-0 ^VERDICT: line, found $n"
  fi
}
check_provenance "$CR" "code-reviewer"
check_provenance "$PR" "plan-reviewer"

exit $rc
