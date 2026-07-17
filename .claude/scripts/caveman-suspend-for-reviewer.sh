#!/usr/bin/env bash
# caveman-suspend-for-reviewer.sh
# Hook: SubagentStart (matcher: (claude-kit:)?(plan-reviewer|code-reviewer|
#                             verdict-recovery|code-researcher) — bare or plugin-namespaced)
# Purpose: Suspend caveman for reviewer/researcher delegations by emitting
#          an exemption marker as additionalContext.
#
# Usage: caveman-suspend-for-reviewer.sh <agent-type>
#          agent-type: passed from settings.json matcher (must be in allowlist)
#
# Exit codes: always 0 (fail-silent — never block subagent start)

set -uo pipefail

AGENT_TYPE="${1:-unknown}"

# Drain stdin (SubagentStart payload — parsed below for type resolution)
_HOOK_INPUT=$(cat 2>/dev/null || true)
: "${_HOOK_INPUT}"

# Type resolution: the SubagentStart payload is preferred when it names an allowlisted type;
# argv (settings args wiring) is the fallback. Rationale: design-critic rides the
# code-researcher entry's matcher, whose hardcoded argv would mislabel it. For all existing
# agents the payload type equals the argv value, so behavior is byte-identical. Payload key
# chain mirrors save-review-checkpoint.sh (agent_type > agent_name > name). When python3 is
# unavailable or the payload lacks a usable key, argv rules — graceful degradation.
if command -v python3 >/dev/null 2>&1; then
  stdin_type=$(printf '%s' "${_HOOK_INPUT}" | python3 -c 'import json,sys
try:
    d = json.load(sys.stdin)
    print(d.get("agent_type") or d.get("agent_name") or d.get("name") or "")
except Exception:
    print("")' 2>/dev/null || echo "")
  stdin_type="${stdin_type##*:}"   # strip plugin namespace prefix if present
  if [[ "${stdin_type}" =~ ^(plan-reviewer|code-reviewer|verdict-recovery|code-researcher|design-critic)$ ]]; then
    AGENT_TYPE="${stdin_type}"
  fi
fi

# Allowlist guard — defensive even though settings.json matcher filters
case "${AGENT_TYPE}" in
  plan-reviewer|code-reviewer|verdict-recovery|code-researcher|design-critic)
    ;;
  *)
    echo "[caveman-suspend-for-reviewer] SKIP: agent_type='${AGENT_TYPE}' not in allowlist" >&2
    exit 0
    ;;
esac

# Compose exemption marker
if command -v python3 >/dev/null 2>&1; then
  python3 - "${AGENT_TYPE}" <<'PYEOF'
import json, sys
agent = sys.argv[1]
msg = (
    "[caveman OFF for this delegation]\n"
    f"You are a review/research agent ({agent}). Standard prose mode applies. "
    "Do NOT use caveman terse style. Your VERDICT_JSON envelope, issue "
    "descriptions, and structured output are contract-bearing and must "
    "remain stable across iterations. Use complete sentences with normal articles."
)
out = {
    "hookSpecificOutput": {
        "hookEventName": "SubagentStart",
        "additionalContext": msg,
    }
}
print(json.dumps(out, ensure_ascii=False))
PYEOF
else
  # Bash fallback — controlled string, escapes minimal
  msg="[caveman OFF for this delegation]\\nYou are a review/research agent (${AGENT_TYPE}). Standard prose mode applies. Do NOT use caveman terse style. Your VERDICT_JSON envelope, issue descriptions, and structured output are contract-bearing and must remain stable across iterations. Use complete sentences with normal articles."
  printf '{"hookSpecificOutput":{"hookEventName":"SubagentStart","additionalContext":"%s"}}\n' "${msg}"
fi

exit 0
