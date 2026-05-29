#!/bin/bash
# Test: agent/command frontmatter effort values are valid on Opus 4.8 (IMP-1).
#
# Claude Code 2.1.154 + Opus 4.8 accept frontmatter `effort` values {low, medium, high, xhigh}
# only. `max` is a session-only /effort value and is NOT honored in frontmatter/settings, so an
# `effort: max` frontmatter silently degrades to the default (`high`). The pipeline intends
# maximum reasoning → the correct frontmatter value is `xhigh`.
#
# CHANGELOG evidence: line 9 (Opus 4.8 defaults high; /effort xhigh top tier),
# line 993 (xhigh added 2.1.111). Authoritative: code.claude.com/docs/en/settings (frontmatter
# effort ∈ low|medium|high|xhigh; max session-only).
#
# Asserts: (1) no agent/command frontmatter line `effort: max`; (2) every frontmatter `effort:`
# value is in the allowed set. Scoped to frontmatter-style lines (`^effort: `) under
# .claude/agents and .claude/commands — prose/template mentions are ignored.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT" || { echo "FAIL: cannot cd to repo root"; exit 1; }

fail=0

# (1) No `effort: max` in frontmatter.
violations="$(grep -rn '^effort: max$' .claude/agents .claude/commands 2>/dev/null || true)"
if [[ -n "$violations" ]]; then
  echo "FAIL: 'effort: max' is invalid in frontmatter on Opus 4.8 — use 'xhigh':"
  echo "$violations"
  fail=1
fi

# (2) Every frontmatter effort value ∈ {low, medium, high, xhigh}.
while IFS= read -r val; do
  [[ -z "$val" ]] && continue
  case "$val" in
    low|medium|high|xhigh) ;;
    *) echo "FAIL: invalid frontmatter effort value: 'effort: $val'"; fail=1 ;;
  esac
done < <(grep -rh '^effort: ' .claude/agents .claude/commands 2>/dev/null | sed 's/^effort: //' || true)

if [[ "$fail" -eq 0 ]]; then
  echo "PASS: all agent/command frontmatter effort values in {low,medium,high,xhigh}"
fi
exit "$fail"
