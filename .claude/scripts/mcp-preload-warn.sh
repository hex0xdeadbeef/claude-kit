#!/usr/bin/env bash
# .claude/scripts/mcp-preload-warn.sh
# Hook: SessionStart (matcher: "")
# Default: silent. Emits a WARN line iff:
#   CLAUDE_KIT_MCP_PRELOAD=on AND
#   an active workflow checkpoint exists AND
#   .mcp.json lacks alwaysLoad: true on sequential-thinking.
# Never blocks (always exits 0).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/log.sh
source "${SCRIPT_DIR}/lib/log.sh"

if [[ "${CLAUDE_KIT_MCP_PRELOAD:-off}" != "on" ]]; then exit 0; fi

REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
STATE_DIR="${CLAUDE_WORKFLOW_STATE_DIR:-${CLAUDE_PROJECT_DIR:-${REPO_ROOT}}/.claude/workflow-state}"

# Gate: only warn in active workflow contexts (presence of any *-checkpoint.yaml)
has_active_workflow="$(ls "${STATE_DIR}"/*-checkpoint.yaml 2>/dev/null | head -n1 || true)"
if [[ -z "${has_active_workflow}" ]]; then
  exit 0
fi

MCP_CONFIG="${CLAUDE_MCP_CONFIG_PATH:-${REPO_ROOT}/.mcp.json}"
if [[ ! -f "${MCP_CONFIG}" ]]; then exit 0; fi
if ! command -v jq >/dev/null 2>&1; then exit 0; fi

always_load="$(jq -r '.mcpServers["sequential-thinking"].alwaysLoad // empty' "${MCP_CONFIG}" 2>/dev/null)"
if [[ "${always_load}" != "true" ]]; then
  log_stderr WARN "CLAUDE_KIT_MCP_PRELOAD=on but .mcp.json does not declare sequential-thinking.alwaysLoad. Add it via the overlay in .mcp.json.example."
fi
exit 0
