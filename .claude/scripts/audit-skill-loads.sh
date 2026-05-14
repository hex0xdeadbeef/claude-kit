#!/usr/bin/env bash
# .claude/scripts/audit-skill-loads.sh
# Invoked from Phase 5 completion AFTER aggregate-pipeline-metrics.sh (NON_CRITICAL).
# Reads claude_code.skill_activated events; flags claude-proactive invocations of
# disable-model-invocation: true skills as pipeline_anomaly: true.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=lib/log.sh
source "${SCRIPT_DIR}/lib/log.sh"
# shellcheck source=lib/otel-parse.sh
source "${SCRIPT_DIR}/lib/otel-parse.sh"

if ! otel_telemetry_enabled; then
  echo '{"skill_load_attribution": null, "anomalies": [], "pipeline_anomaly": false, "audit_source": "absent"}'
  exit 0
fi
if ! command -v jq >/dev/null 2>&1; then
  echo '{"skill_load_attribution": null, "anomalies": [], "pipeline_anomaly": false, "audit_source": "no-jq"}'
  exit 0
fi

# Build the list of disable-model-invocation: true skills via grep
disabled_names_raw="$(grep -lE '^disable-model-invocation: true' "${REPO_ROOT}/.claude/skills/"*/SKILL.md 2>/dev/null \
  | xargs -n1 dirname 2>/dev/null \
  | xargs -n1 basename 2>/dev/null \
  || true)"
if [[ -z "${disabled_names_raw}" ]]; then
  disabled_skills='[]'
else
  disabled_skills="$(echo "${disabled_names_raw}" | jq -R . | jq -cs .)"
fi

events="$(otel_filter_event "claude_code.skill_activated" | jq -cs . 2>/dev/null)"
if [[ -z "${events}" || "${events}" = "null" ]]; then events='[]'; fi

jq -n --argjson disabled "${disabled_skills}" --argjson events "${events}" '
  ($events | map({skill: (.attributes["skill.name"] // ""), trigger: (.attributes.invocation_trigger // "")})) as $attrib
  | {
      skill_load_attribution: $attrib,
      anomalies: ([$attrib[] | select(.trigger == "claude-proactive") | select(.skill as $s | $disabled | index($s))]),
      audit_source: "otel"
    }
  | .pipeline_anomaly = ((.anomalies | length) > 0)
'
