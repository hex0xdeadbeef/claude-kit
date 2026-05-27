#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"; cd "${ROOT}"; fail=0
python3 -c "import json,sys; sys.exit(1 if 'WorktreeCreate' in json.load(open('.claude/settings.json')).get('hooks',{}) else 0)" \
  && echo "PASS: no WorktreeCreate hook" || { echo "FAIL: WorktreeCreate hook present"; fail=1; }
[[ ! -f .claude/scripts/prepare-worktree.sh ]] && echo "PASS: prepare-worktree.sh absent" || { echo "FAIL: prepare-worktree.sh present"; fail=1; }
grep -q 'code-reviewer-INJECTED-CONTEXT.md' .worktreeinclude && echo "PASS: .worktreeinclude sidecar line" || { echo "FAIL: .worktreeinclude missing sidecar"; fail=1; }
[[ $fail -eq 0 ]] && echo "All passed." || exit 1
