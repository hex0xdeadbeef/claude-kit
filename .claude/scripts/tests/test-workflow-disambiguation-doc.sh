#!/bin/bash
# Test: kit /workflow vs native /workflows disambiguation documented (IMP-7).
#
# Claude Code 2.1.154 shipped native "dynamic workflows" (the /workflows command + Workflow tool,
# orchestrating ad-hoc background agent fan-out). The kit's /workflow (singular) is a different
# thing — the multi-agent dev pipeline. Without a disambiguation note, a user or the orchestrator
# can conflate them. Asserts both the command and the workflow rule reference native /workflows
# and that the command explicitly distinguishes the two.
#
# CHANGELOG evidence: line 10 ("Introducing dynamic workflows ... Run `/workflows` to view your runs").
#
# Part of changelog-2153-156-opus48-uplift (IMP-7).

set -uo pipefail
FAIL=0
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT" || { echo "FAIL: cannot cd to repo root"; exit 1; }
err() { echo "FAIL: $1"; FAIL=1; }

for f in .claude/commands/workflow.md .claude/rules/workflow.md; do
  grep -q '/workflows' "$f" || err "$f missing native /workflows disambiguation reference"
done

grep -qiE 'distinct from|not conflate|differs from|do not conflate' .claude/commands/workflow.md \
  || err "commands/workflow.md missing explicit distinction wording vs native /workflows"

if [[ "$FAIL" -eq 0 ]]; then
  echo "PASS: kit /workflow vs native /workflows disambiguation documented"
fi
exit "$FAIL"
