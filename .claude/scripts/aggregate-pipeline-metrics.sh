#!/usr/bin/env bash
# .claude/scripts/aggregate-pipeline-metrics.sh
# Invoked from Phase 5 completion (NON_CRITICAL). Emits per-agent OTEL breakdown
# to stdout as JSON; gracefully reports "absent" when telemetry is disabled.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/log.sh
source "${SCRIPT_DIR}/lib/log.sh"
# shellcheck source=lib/otel-parse.sh
source "${SCRIPT_DIR}/lib/otel-parse.sh"

if ! otel_telemetry_enabled; then
  echo '{"per_agent_token_breakdown": null, "per_agent_duration_ms": null, "agent_correlation_source": "absent"}'
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  log_stderr WARN "jq unavailable; skipping aggregation"
  echo '{"per_agent_token_breakdown": null, "per_agent_duration_ms": null, "agent_correlation_source": "absent"}'
  exit 0
fi

breakdown="$(otel_filter_event "claude_code.llm_request" | otel_group_by_agent_id)"
if [[ -z "${breakdown}" || "${breakdown}" = "{}" || "${breakdown}" = "null" ]]; then
  echo '{"per_agent_token_breakdown": null, "per_agent_duration_ms": null, "agent_correlation_source": "otel-empty"}'
  exit 0
fi

token_view="$(echo "${breakdown}" | jq 'with_entries(.value |= {input_tokens, output_tokens, invocations})')"
dur_view="$(echo "${breakdown}" | jq 'with_entries(.value |= .duration_ms)')"
jq -n --argjson tb "${token_view}" --argjson db "${dur_view}" \
  '{per_agent_token_breakdown:$tb, per_agent_duration_ms:$db, agent_correlation_source:"otel"}'
