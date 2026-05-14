#!/usr/bin/env bash
# .claude/scripts/lib/otel-parse.sh
# Shared OTEL log parser used by aggregate-pipeline-metrics.sh + audit-skill-loads.sh (AD-2).
# Degrades to "absent" sentinel when CLAUDE_CODE_ENABLE_TELEMETRY is unset.
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/otel-parse.sh"
#   otel_telemetry_enabled         # returns 0 if telemetry env vars set, else 1
#   otel_logs_path                 # prints log file path or empty
#   otel_filter_event <event-name> # streams JSONL of matching events
#   otel_group_by_agent_id         # reads JSONL on stdin, emits grouped JSON map

otel_telemetry_enabled() {
  [[ -n "${CLAUDE_CODE_ENABLE_TELEMETRY:-}" && "${CLAUDE_CODE_ENABLE_TELEMETRY}" != "0" ]] || return 1
  return 0
}

otel_logs_path() {
  if [[ -n "${CLAUDE_OTEL_LOG_PATH:-}" ]]; then
    echo "${CLAUDE_OTEL_LOG_PATH}"
    return 0
  fi
  case "${OTEL_LOGS_EXPORTER:-}" in
    console) echo "${CLAUDE_OTEL_CONSOLE_LOG:-/tmp/claude-otel.log}" ;;
    *)       echo "" ;;
  esac
}

otel_filter_event() {
  local event_name="$1"
  local log_path
  log_path="$(otel_logs_path)"
  if [[ -z "${log_path}" || ! -f "${log_path}" ]]; then
    return 0
  fi
  jq -c "select(.name == \"${event_name}\")" "${log_path}" 2>/dev/null || true
}

otel_group_by_agent_id() {
  jq -s '
    group_by(.attributes.agent_id // "main")
    | map({
        key: ((.[0].attributes.agent_id) // "main"),
        value: {
          input_tokens:  ([.[].attributes.input_tokens  // 0] | add),
          output_tokens: ([.[].attributes.output_tokens // 0] | add),
          duration_ms:   ([.[].attributes.duration_ms   // 0] | add),
          invocations:   length
        }
      })
    | from_entries
  ' 2>/dev/null || echo '{}'
}
