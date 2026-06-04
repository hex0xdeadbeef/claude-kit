#!/usr/bin/env bash
# R3 (F-P4): hook-count documentation drift guard. Recomputes the authoritative counts from
# settings.json and asserts CLAUDE.md + .claude/commands/workflow.md state them correctly. Fails
# again if hooks change but the docs are not updated — locks the docs to reality.
#
# Counting methodology (pin — do NOT change without updating the docs):
#   event_types  = number of top-level keys in settings.json .hooks
#   scripts      = distinct command-script paths across all hooks (type==command), with a leading
#                  ${CLAUDE_PLUGIN_ROOT}/ stripped so project- and plugin-form paths collapse;
#                  this pools .claude/scripts/* AND .claude/agents/meta-agent/scripts/* by full path.
#   prompt_hooks = number of type==prompt hook entries.
# Sibling parser: .claude/scripts/tests/test-plugin-scaffold.sh also recomputes prompt-hook parity
# from settings.json — keep the prompt-hook definition identical between the two.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"; cd "$ROOT"
command -v python3 >/dev/null 2>&1 || { echo "SKIP: python3 required"; exit 0; }

python3 - <<'PY'
import json, re, sys

s = json.load(open(".claude/settings.json"))
h = s.get("hooks", {})
events = len(h)
scripts = set(); prompts = 0
for ev, arr in h.items():
    for g in arr:
        for hk in g.get("hooks", []):
            t = hk.get("type")
            if t == "command":
                scripts.add(hk["command"].replace("${CLAUDE_PLUGIN_ROOT}/", ""))
            elif t == "prompt":
                prompts += 1
expected = f"{events} event types, {len(scripts)} scripts + {prompts} prompt hooks"
print(f"[computed] {expected}")

def norm(p):
    return re.sub(r"\s+", " ", open(p, encoding="utf-8").read())

fail = 0
for doc in ["CLAUDE.md", ".claude/commands/workflow.md"]:
    if expected in norm(doc):
        print(f"  PASS: {doc} states '{expected}'")
    else:
        print(f"  FAIL: {doc} does NOT state '{expected}' (stale hook-count doc)")
        fail += 1
sys.exit(1 if fail else 0)
PY
