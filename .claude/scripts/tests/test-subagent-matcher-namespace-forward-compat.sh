#!/usr/bin/env bash
# test-subagent-matcher-namespace-forward-compat.sh
#
# Forward-compat guard for Claude Code 2.1.195: hook matchers containing a hyphen
# are evaluated as JavaScript regex and 2.1.195 changed them from unanchored
# substring-match to FULL-match. A bare matcher 'code-reviewer' then full-matches
# ONLY the exact string 'code-reviewer'; if the platform presents the plugin-
# namespaced 'claude-kit:code-reviewer' to the matcher, the bare matcher silently
# stops firing -> inject-review-context.sh, save-review-checkpoint.sh verdict
# capture, caveman suspension, and task tracking all silently die.
#
# This test simulates the 2.1.195 exact-match regime with re.fullmatch and asserts
# that BOTH manifests' SubagentStart + SubagentStop matchers match BOTH the bare
# and the 'claude-kit:'-namespaced agent type, without over-broadening to unrelated
# agents. agent_type is NOT a canonical-ID hash input, so this cannot affect
# issue-ID stability. Matchers are not in the caveman verbatim-preserve list.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
command -v python3 >/dev/null 2>&1 || { echo "SKIP: python3 required"; exit 0; }

echo "=== test-subagent-matcher-namespace-forward-compat.sh ==="

REPO_ROOT="$REPO_ROOT" python3 - <<'PY'
import json, os, re, sys

repo = os.environ["REPO_ROOT"]
manifests = {
    "hooks.json": os.path.join(repo, ".claude", "hooks", "hooks.json"),
    "settings.json": os.path.join(repo, ".claude", "settings.json"),
}

# SubagentStart fires per-agent; SubagentStop covers the review/recovery set.
START_AGENTS = ["code-researcher", "plan-reviewer", "code-reviewer", "verdict-recovery"]
STOP_AGENTS = ["plan-reviewer", "code-reviewer", "verdict-recovery"]
# PR-002: explicitly probe the non-first alternatives namespaced, to catch a
# wrong-precedence regression like '(claude-kit:)?plan-reviewer|code-reviewer|...'
STOP_PRECEDENCE_PROBES = ["claude-kit:code-reviewer", "claude-kit:verdict-recovery"]
UNRELATED = ["general-purpose", "claude-kit:general-purpose"]

passed = 0
failed = 0

def fail(msg):
    global failed
    failed += 1
    print(f"  FAIL: {msg}")

def ok(msg):
    global passed
    passed += 1
    print(f"  PASS: {msg}")

def matchers_for(hooks_obj, event):
    out = []
    for block in hooks_obj.get("hooks", {}).get(event, []):
        m = block.get("matcher", "")
        if m:
            out.append(m)
    return out

def fullmatch_any(matchers, target):
    for m in matchers:
        try:
            if re.fullmatch(m, target):
                return True
        except re.error:
            # An invalid regex matcher is itself a failure surface.
            return False
    return False

for label, path in manifests.items():
    try:
        with open(path) as f:
            obj = json.load(f)
    except Exception as e:
        fail(f"{label}: cannot read/parse ({e})")
        continue

    start_matchers = matchers_for(obj, "SubagentStart")
    stop_matchers = matchers_for(obj, "SubagentStop")

    if not start_matchers:
        fail(f"{label}: no SubagentStart matchers found")
    if not stop_matchers:
        fail(f"{label}: no SubagentStop matchers found")

    # Positive: every SubagentStart agent matched bare AND namespaced.
    for agent in START_AGENTS:
        for tgt in (agent, f"claude-kit:{agent}"):
            if fullmatch_any(start_matchers, tgt):
                ok(f"{label} SubagentStart fullmatch '{tgt}'")
            else:
                fail(f"{label} SubagentStart NO fullmatch for '{tgt}'")

    # Positive: every SubagentStop agent matched bare AND namespaced.
    for agent in STOP_AGENTS:
        for tgt in (agent, f"claude-kit:{agent}"):
            if fullmatch_any(stop_matchers, tgt):
                ok(f"{label} SubagentStop fullmatch '{tgt}'")
            else:
                fail(f"{label} SubagentStop NO fullmatch for '{tgt}'")

    # PR-002: alternation precedence — non-first alternatives must match namespaced.
    for tgt in STOP_PRECEDENCE_PROBES:
        if fullmatch_any(stop_matchers, tgt):
            ok(f"{label} SubagentStop precedence ok for '{tgt}'")
        else:
            fail(f"{label} SubagentStop precedence FAIL for '{tgt}' "
                 f"(optional namespace not applied to all alternatives)")

    # Negative: no over-broadening to unrelated agents.
    for tgt in UNRELATED:
        if fullmatch_any(start_matchers, tgt) or fullmatch_any(stop_matchers, tgt):
            fail(f"{label} over-broadens: '{tgt}' should NOT match any Subagent* matcher")
        else:
            ok(f"{label} no over-broadening for '{tgt}'")

print(f"\n  RESULT: {passed} passed, {failed} failed")
sys.exit(1 if failed else 0)
PY
rc=$?
if [[ $rc -eq 0 ]]; then
  echo "PASS: test-subagent-matcher-namespace-forward-compat"
else
  echo "FAIL: test-subagent-matcher-namespace-forward-compat"
fi
exit $rc
