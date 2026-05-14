#!/usr/bin/env bash
# Part 6 / Proposal F + PR-008 gate: env on + .mcp.json without alwaysLoad + NO active
# workflow checkpoint → silent (no WARN). Scopes warning to active pipeline contexts.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SCRIPT="${REPO_ROOT}/.claude/scripts/mcp-preload-warn.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

cat > "${TMP}/.mcp.json" <<'JSON'
{"mcpServers":{"sequential-thinking":{"command":"npx"}}}
JSON
# NO checkpoint file → PR-008 gate must close

export CLAUDE_KIT_MCP_PRELOAD=on
export CLAUDE_MCP_CONFIG_PATH="${TMP}/.mcp.json"
export CLAUDE_WORKFLOW_STATE_DIR="${TMP}"

ec=0
err=$(bash "${SCRIPT}" 2>&1 1>/dev/null) || ec=$?
test "${ec}" -eq 0 || { echo "[test-mcp-preload-warn-no-workflow] FAIL: expected exit 0 got ${ec}" >&2; exit 1; }
if echo "${err}" | grep -qE 'WARN:.*alwaysLoad'; then
  echo "[test-mcp-preload-warn-no-workflow] FAIL: WARN emitted despite no active workflow checkpoint (PR-008 gate broken)" >&2
  exit 1
fi
echo "[test-mcp-preload-warn-no-workflow] PASS"
