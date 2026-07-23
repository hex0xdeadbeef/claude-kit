#!/usr/bin/env bash
# audit-skill-loads.sh does NOT flag user-slash or nested-skill
# invocations of disable-model-invocation: true skills (these are legitimate triggers).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SCRIPT="${REPO_ROOT}/.claude/scripts/audit-skill-loads.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

LOG="${TMP}/otel.log"
cat > "${LOG}" <<'JSONL'
{"name":"claude_code.skill_activated","attributes":{"skill.name":"workflow-protocols","invocation_trigger":"user-slash"}}
{"name":"claude_code.skill_activated","attributes":{"skill.name":"planner-rules","invocation_trigger":"nested-skill"}}
JSONL

export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_LOGS_EXPORTER=console
export CLAUDE_OTEL_LOG_PATH="${LOG}"

out="$(bash "${SCRIPT}" 2>/dev/null)"
anomaly_flag=$(echo "${out}" | jq -r '.pipeline_anomaly')
test "${anomaly_flag}" = "false" || { echo "[test-audit-skill-loads-legitimate] FAIL: legitimate triggers must not flag anomaly" >&2; echo "Got: ${out}" >&2; exit 1; }
echo "[test-audit-skill-loads-legitimate] PASS"
