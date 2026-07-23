#!/usr/bin/env bash
# env on + active checkpoint + .mcp.json without alwaysLoad → WARN

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SCRIPT="${REPO_ROOT}/.claude/scripts/mcp-preload-warn.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

cat > "${TMP}/.mcp.json" <<'JSON'
{"mcpServers":{"sequential-thinking":{"command":"npx"}}}
JSON
# Active workflow checkpoint required by the gate
cat > "${TMP}/fixture-checkpoint.yaml" <<'YAML'
phase_completed: 3
verdict: null
YAML

export CLAUDE_KIT_MCP_PRELOAD=on
export CLAUDE_MCP_CONFIG_PATH="${TMP}/.mcp.json"
export CLAUDE_WORKFLOW_STATE_DIR="${TMP}"

ec=0
err=$(bash "${SCRIPT}" 2>&1 1>/dev/null) || ec=$?
test "${ec}" -eq 0 || { echo "[test-mcp-preload-warn-no-config] FAIL: expected exit 0 got ${ec}" >&2; exit 1; }
if ! echo "${err}" | grep -qE 'WARN:.*alwaysLoad'; then
  echo "[test-mcp-preload-warn-no-config] FAIL: expected WARN about alwaysLoad" >&2
  echo "Got: ${err}" >&2
  exit 1
fi
echo "[test-mcp-preload-warn-no-config] PASS"
