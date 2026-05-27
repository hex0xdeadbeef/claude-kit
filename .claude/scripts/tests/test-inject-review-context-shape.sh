#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"; cd "${ROOT}"
SB=$(mktemp -d -t injshape.XXXXXX)
printf 'feature: feat-shape\ncomplexity: L\nphase_completed: 4\niteration:\n  plan_review: 1/3\n  code_review: 1/3\n' > "${SB}/feat-shape-checkpoint.yaml"
OUT=$(echo '{"session_id":"x"}' | CLAUDE_WORKFLOW_STATE_DIR="${SB}" bash .claude/scripts/inject-review-context.sh code-reviewer 2>/dev/null || true)
test -d "${SB}" && rm -r "${SB}"
echo "${OUT}" | python3 -c "
import json,sys
d=json.loads(sys.stdin.read() or '{}'); hso=d.get('hookSpecificOutput',{})
ok=('additionalContext' in hso) and ('additionalContext' not in d)
print('PASS: hookSpecificOutput shape' if ok else 'FAIL: wrong shape'); sys.exit(0 if ok else 1)"
