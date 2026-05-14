#!/usr/bin/env bash
# Part 3 / Proposal G: inject-review-context.sh must read $CLAUDE_EFFORT and surface it
# in the additionalContext payload. When env unset, the effort line is omitted (not "").

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SCRIPT="${REPO_ROOT}/.claude/scripts/inject-review-context.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
export CLAUDE_WORKFLOW_STATE_DIR="${TMP}"

# Minimal checkpoint fixture so inject-review-context.sh proceeds past the
# "No checkpoint found" early-exit at line ~299. The effort logic runs in the
# main code path AFTER checkpoint loading.
cat > "${TMP}/fixture-checkpoint.yaml" <<'YAML'
feature: fixture
phase_completed: 1
phase_name: planning
complexity: M
iteration:
  plan_review: 0
  code_review: 0
YAML

input='{"session_id":"abcd1234","tool_name":"Agent"}'

# Case 1: CLAUDE_EFFORT set → expect "Effort: high" text inside additionalContext
out_with=$(echo "${input}" | CLAUDE_EFFORT="high" bash "${SCRIPT}" plan-reviewer 2>/dev/null || true)
ac_with=$(echo "${out_with}" | jq -r '.additionalContext // ""' 2>/dev/null || echo "")
if ! echo "${ac_with}" | grep -qE 'Effort:[ ]*high'; then
  echo "[test-inject-review-effort-context] FAIL: with-env expected 'Effort: high' in additionalContext" >&2
  echo "Got: ${ac_with}" >&2
  exit 1
fi

# Case 2: env unset → effort line absent
out_without=$(echo "${input}" | env -u CLAUDE_EFFORT bash "${SCRIPT}" plan-reviewer 2>/dev/null || true)
ac_without=$(echo "${out_without}" | jq -r '.additionalContext // ""' 2>/dev/null || echo "")
if echo "${ac_without}" | grep -qE 'Effort:[ ]*(unknown|\$)'; then
  echo "[test-inject-review-effort-context] FAIL: env-unset must omit Effort line (not emit empty placeholder)" >&2
  exit 1
fi

echo "[test-inject-review-effort-context] PASS"
