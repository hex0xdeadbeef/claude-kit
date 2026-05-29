#!/bin/bash
# Test: code-researcher read-only defense-in-depth via disallowedTools frontmatter (IMP-5).
#
# code-researcher is a read-only tool-agent (output contract: summary ≤2000 tokens, no file
# writes). Its write-prohibition previously rested only on the prompt. Agent frontmatter supports
# disallowedTools (CHANGELOG line 1708: "effort, maxTurns, and disallowedTools frontmatter
# support" — camelCase, matching the existing maxTurns key in this agent), giving a platform-level
# guarantee it cannot mutate files.
#
# Reviewers (plan-reviewer, code-reviewer) MUST still be able to Write (agent-memory sync). The
# regression guard asserts they do NOT disallow Write/Edit — it does NOT assert absence of a
# disallowedTools key (plan-reviewer.md legitimately disallows Bash while keeping Write).
#
# Part of changelog-2153-156-opus48-uplift (IMP-5).

set -uo pipefail
FAIL=0
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT" || { echo "FAIL: cannot cd to repo root"; exit 1; }
err() { echo "FAIL: $1"; FAIL=1; }

_frontmatter() { awk 'NR==1&&/^---/{f=1;next} f&&/^---/{exit} f' "$1"; }

CR=".claude/agents/code-researcher.md"
fm="$(_frontmatter "$CR")"
echo "$fm" | grep -qE '^disallowedTools:' || err "code-researcher.md frontmatter missing disallowedTools"
for t in Write Edit NotebookEdit; do
  echo "$fm" | grep -q "$t" || err "code-researcher.md disallowedTools missing $t"
done

# Regression guard: reviewers must still ALLOW Write (memory-sync). Assert their disallowedTools,
# if present, does NOT list Write or Edit. Absence of the key is fine (default = all tools);
# disallowing other tools (e.g. plan-reviewer.md disallows Bash) is also fine.
for r in .claude/agents/code-reviewer.md .claude/agents/plan-reviewer.md; do
  rfm="$(_frontmatter "$r")"
  # Collect the disallowedTools block: the header line plus any subsequent YAML list items,
  # up to the next top-level key. Covers both inline ([Bash]) and block (- Bash) forms.
  dblock="$(echo "$rfm" | awk '
    /^disallowedTools:/ {cap=1; print; next}
    cap && /^[[:space:]]*-/ {print; next}
    cap && /^[^[:space:]]/ {cap=0}
  ')"
  if [[ -n "$dblock" ]]; then
    echo "$dblock" | grep -qw 'Write' && err "$(basename "$r") disallows Write — breaks agent-memory sync"
    echo "$dblock" | grep -qw 'Edit'  && err "$(basename "$r") disallows Edit — breaks agent-memory sync"
  fi
done

if [[ "$FAIL" -eq 0 ]]; then
  echo "PASS: code-researcher read-only via disallowedTools; reviewers retain Write"
fi
exit "$FAIL"
