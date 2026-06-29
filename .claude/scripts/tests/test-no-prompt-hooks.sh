#!/usr/bin/env bash
# test-no-prompt-hooks.sh
#
# Generic-pipeline invariant: the kit ships NO `type:"prompt"` (LLM-judge) hooks. The pipeline
# enforces policy via deterministic command hooks + the slot-driven review surfaces
# (architecture.md rule, plan-reviewer/code-reviewer RULE_4, coder-rules RULE_2), never via a
# per-edit, language-hardcoded LLM judge. This guard locks that invariant across BOTH manifests
# (.claude/hooks/hooks.json + .claude/settings.json) so a prompt-hook cannot silently reappear.
# (CC docs: prompt-hooks are "best-effort"/non-deterministic and cost tokens per matching edit;
# deterministic policy belongs in command hooks / the permission system.)

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
command -v python3 >/dev/null 2>&1 || { echo "SKIP: python3 required"; exit 0; }

echo "=== test-no-prompt-hooks.sh ==="
REPO_ROOT="$REPO_ROOT" python3 - <<'PY'
import json, os, sys
repo = os.environ["REPO_ROOT"]
manifests = {
    "hooks.json": os.path.join(repo, ".claude", "hooks", "hooks.json"),
    "settings.json": os.path.join(repo, ".claude", "settings.json"),
}
passed = failed = 0
for label, path in manifests.items():
    try:
        obj = json.load(open(path))
    except Exception as e:
        print(f"  FAIL: {label}: cannot read/parse ({e})"); failed += 1; continue
    n = 0
    for ev, arr in obj.get("hooks", {}).items():
        for group in arr:
            for hk in group.get("hooks", []):
                if hk.get("type") == "prompt":
                    n += 1
    if n == 0:
        print(f"  PASS: {label} has 0 type:prompt hooks"); passed += 1
    else:
        print(f"  FAIL: {label} has {n} type:prompt hook(s) (expected 0 — generic-pipeline invariant)"); failed += 1
print(f"\n  RESULT: {passed} passed, {failed} failed")
sys.exit(1 if failed else 0)
PY
rc=$?
[[ $rc -eq 0 ]] && echo "PASS: test-no-prompt-hooks" || echo "FAIL: test-no-prompt-hooks"
exit $rc
