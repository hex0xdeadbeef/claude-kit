#!/usr/bin/env bash
# Part 2 / PR-004 fix: validate-handoff.sh in warn mode must emit structured JSON
# with decision="block" when validation fails AND exit 0 (continueOnBlock contract).
# Uses canonical ec=0 idiom (not 2>/dev/null || true mask).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SCRIPT="${REPO_ROOT}/.claude/scripts/validate-handoff.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

cat > "${TMP}/bad-handoff.json" <<'JSON'
{
  "$handoff_contract": "planner_to_plan_review",
  "artifact": ".claude/prompts/x.md",
  "metadata": {"task_type": "new_feature", "complexity": "ABSURD"},
  "key_decisions": ["test"],
  "known_risks": ["test"],
  "areas_needing_attention": []
}
JSON

unset CLAUDE_HANDOFF_VALIDATION_MODE
ec=0
out=$(bash "${SCRIPT}" "${TMP}/bad-handoff.json" 2>/dev/null) || ec=$?

if [[ "${ec}" -ne 0 ]]; then
  echo "[test-validate-handoff-continueOnBlock] FAIL: warn mode must exit 0, got ${ec}" >&2
  exit 1
fi

if ! echo "${out}" | jq -e '.decision == "block"' >/dev/null 2>&1; then
  echo "[test-validate-handoff-continueOnBlock] FAIL: expected stdout JSON with decision='block'" >&2
  echo "Got: ${out}" >&2
  exit 1
fi
echo "[test-validate-handoff-continueOnBlock] PASS"
