#!/usr/bin/env bash
# Part 2 / PR-004 fix: strict-mode validate-handoff.sh must exit 2 on malformed handoff.
# Verifies the continueOnBlock-only stdout JSON path does NOT mask the strict-mode block.

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
  "metadata": {"task_type": "INVALID", "complexity": "XL"},
  "key_decisions": ["test"],
  "known_risks": ["test"],
  "areas_needing_attention": []
}
JSON

export CLAUDE_HANDOFF_VALIDATION_MODE=strict
ec=0
out=$(bash "${SCRIPT}" "${TMP}/bad-handoff.json" 2>/dev/null) || ec=$?

if [[ "${ec}" -ne 2 ]]; then
  echo "[test-validate-handoff-strict-mode] FAIL: strict mode must exit 2 on malformed handoff, got ${ec}" >&2
  echo "Stdout was: ${out}" >&2
  exit 1
fi
echo "[test-validate-handoff-strict-mode] PASS"
