#!/usr/bin/env bash
# Unit-2 (audit #2): rules/workflow.md split — hook-author maintenance sections moved to a
# path-scoped rule so they stop eager-loading into every session. Runtime command/agent map
# stays global. Contract-neutral: moved sections are not parsed at runtime, not in any handoff/
# VERDICT/canonical-ID surface.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"; cd "${ROOT}"
WF=".claude/rules/workflow.md"
NEW=".claude/rules/kit-authoring-conventions.md"
CR=".claude/agents/meta-agent/scripts/check-references.sh"
rc=0; fail(){ echo "FAIL: $1"; rc=1; }; pass(){ echo "PASS: $1"; }

# AC-1: maintenance sections moved OUT of workflow.md
grep -q "^## Hook stderr Convention" "$WF" && fail "AC-1 stderr section still in workflow.md" || pass "AC-1 stderr section removed from workflow.md"
grep -q "^## Path Conventions" "$WF" && fail "AC-1 path-conv section still in workflow.md" || pass "AC-1 path-conv section removed from workflow.md"
grep -qF "| Label | Meaning |" "$WF" && fail "AC-1 LABEL table still in workflow.md" || pass "AC-1 LABEL table removed from workflow.md"

# AC-2: runtime map kept in workflow.md (regression guard incl. test-workflow-disambiguation-doc.sh)
grep -q "Model Routing" "$WF" && pass "AC-2 Model Routing kept" || fail "AC-2 Model Routing missing"
grep -q "/workflows" "$WF" && pass "AC-2 /workflows disambiguation kept" || fail "AC-2 /workflows note missing"
grep -q "Commands vs Agents" "$WF" && pass "AC-2 Commands-vs-Agents design decision kept" || fail "AC-2 design decision missing"

# AC-3: new scoped rule exists with frontmatter + both sections
if [ -f "$NEW" ]; then pass "AC-3 new rule exists"; else fail "AC-3 new rule missing"; fi
if [ "$(head -1 "$NEW" 2>/dev/null)" = "---" ]; then pass "AC-3 frontmatter present (line 1 ---)"; else fail "AC-3 no frontmatter"; fi
grep -q "^globs:" "$NEW" 2>/dev/null && pass "AC-3 globs scope present" || fail "AC-3 no globs scope"
{ grep -q "Hook stderr Convention" "$NEW" && grep -qF "| Label | Meaning |" "$NEW"; } 2>/dev/null && pass "AC-3 stderr section moved into new rule" || fail "AC-3 stderr section/table not in new rule"
grep -q "Path Conventions" "$NEW" 2>/dev/null && pass "AC-3 path-conv moved into new rule" || fail "AC-3 path-conv not in new rule"

# AC-4: check-references.sh does NOT self-fire on the new file (stdin-JSON contract, file must exist)
if [ -f "$NEW" ]; then
  DEF_OUT="$(printf '{"tool_input":{"file_path":"%s"}}' "$NEW" | bash "$CR" 2>/dev/null || true)"
  if printf '%s' "$DEF_OUT" | grep -q "bare form detected"; then fail "AC-4 default-mode self-fires PK_PATH on new file (exemption missing)"; else pass "AC-4 default-mode no PK_PATH self-fire on new file"; fi
  printf '{"tool_input":{"file_path":"%s"}}' "$NEW" | CLAUDE_PK_PATH_MODE=strict bash "$CR" >/dev/null 2>&1
  src=$?
  if [ "$src" -eq 0 ]; then pass "AC-4 strict-mode exit 0 (exemption works)"; else fail "AC-4 strict-mode exit ${src} (exemption missing → self-fire)"; fi
else
  fail "AC-4 skipped — new rule file absent"
fi

# AC-5: CLAUDE.md Rules list updated
grep -q "kit-authoring-conventions.md" CLAUDE.md && pass "AC-5 CLAUDE.md references new rule" || fail "AC-5 CLAUDE.md missing new rule"

# AC-6: pointer in workflow.md to the new rule
grep -q "kit-authoring-conventions.md" "$WF" && pass "AC-6 workflow.md points to new rule" || fail "AC-6 no pointer in workflow.md"

[ "$rc" -eq 0 ] && echo "ALL PASS: test-rule-workflow-split" || echo "SOME FAILED: test-rule-workflow-split"
exit "$rc"
