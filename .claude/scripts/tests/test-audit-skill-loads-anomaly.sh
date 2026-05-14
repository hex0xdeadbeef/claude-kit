#!/usr/bin/env bash
# Part 4 / Proposal E: audit-skill-loads.sh flags claude-proactive invocations of
# disable-model-invocation: true skills as pipeline_anomaly: true.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SCRIPT="${REPO_ROOT}/.claude/scripts/audit-skill-loads.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

LOG="${TMP}/otel.log"
# Synthetic event: a disable-model-invocation skill triggered by claude-proactive.
# workflow-protocols is declared disable-model-invocation: true in the kit (verified by grep).
cat > "${LOG}" <<'JSONL'
{"name":"claude_code.skill_activated","attributes":{"skill.name":"workflow-protocols","invocation_trigger":"claude-proactive"}}
JSONL

export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_LOGS_EXPORTER=console
export CLAUDE_OTEL_LOG_PATH="${LOG}"

out="$(bash "${SCRIPT}" 2>/dev/null)"
anomaly_flag=$(echo "${out}" | jq -r '.pipeline_anomaly')
test "${anomaly_flag}" = "true" || { echo "[test-audit-skill-loads-anomaly] FAIL: expected pipeline_anomaly=true" >&2; echo "Got: ${out}" >&2; exit 1; }
echo "[test-audit-skill-loads-anomaly] PASS"
