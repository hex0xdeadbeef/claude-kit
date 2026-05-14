#!/usr/bin/env bash
# Part 4: aggregate-pipeline-metrics.sh degrades gracefully when telemetry is unset.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SCRIPT="${REPO_ROOT}/.claude/scripts/aggregate-pipeline-metrics.sh"

unset CLAUDE_CODE_ENABLE_TELEMETRY OTEL_LOGS_EXPORTER CLAUDE_OTEL_LOG_PATH
ec=0
out=$(bash "${SCRIPT}" 2>/dev/null) || ec=$?
test "${ec}" -eq 0 || { echo "FAIL: expected exit 0, got ${ec}" >&2; exit 1; }

src=$(echo "${out}" | jq -r '.agent_correlation_source')
test "${src}" = "absent" || { echo "FAIL: expected agent_correlation_source='absent', got '${src}'" >&2; exit 1; }

breakdown=$(echo "${out}" | jq -r '.per_agent_token_breakdown')
test "${breakdown}" = "null" || { echo "FAIL: expected null breakdown, got '${breakdown}'" >&2; exit 1; }
echo "[test-aggregate-pipeline-metrics-no-otel] PASS"
