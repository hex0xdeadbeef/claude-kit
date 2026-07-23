#!/usr/bin/env bash
# aggregate-pipeline-metrics.sh emits per-agent OTEL breakdown
# from a synthetic claude_code.llm_request OTEL log.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SCRIPT="${REPO_ROOT}/.claude/scripts/aggregate-pipeline-metrics.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

LOG="${TMP}/otel.log"
cat > "${LOG}" <<'JSONL'
{"name":"claude_code.llm_request","attributes":{"agent_id":"plan-rev-1","parent_agent_id":"main","input_tokens":100,"output_tokens":50,"duration_ms":1200}}
{"name":"claude_code.llm_request","attributes":{"agent_id":"code-rev-1","parent_agent_id":"main","input_tokens":200,"output_tokens":80,"duration_ms":2100}}
{"name":"claude_code.llm_request","attributes":{"agent_id":"code-res-1","parent_agent_id":"plan-rev-1","input_tokens":150,"output_tokens":40,"duration_ms":800}}
JSONL

export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_LOGS_EXPORTER=console
export CLAUDE_OTEL_LOG_PATH="${LOG}"
export CLAUDE_WORKFLOW_STATE_DIR="${TMP}"

out="$(bash "${SCRIPT}" 2>/dev/null)"
echo "${out}" | jq -e '.agent_correlation_source == "otel"' >/dev/null \
  || { echo "[test-aggregate-pipeline-metrics] FAIL: expected agent_correlation_source='otel'" >&2; echo "Got: ${out}" >&2; exit 1; }

breakdown="$(echo "${out}" | jq -r '.per_agent_token_breakdown')"
for agent in plan-rev-1 code-rev-1 code-res-1; do
  val=$(echo "${breakdown}" | jq -r --arg a "${agent}" '.[$a].input_tokens // empty')
  if [[ -z "${val}" ]]; then
    echo "[test-aggregate-pipeline-metrics] FAIL: missing breakdown for ${agent}" >&2
    exit 1
  fi
done
echo "[test-aggregate-pipeline-metrics] PASS"
