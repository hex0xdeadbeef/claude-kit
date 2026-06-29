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

# Drain stdin (SubagentStart payload — not consumed by this hook)
_HOOK_INPUT=$(cat 2>/dev/null || true)
: "${_HOOK_INPUT}"

# Allowlist guard — defensive even though settings.json matcher filters
case "${AGENT_TYPE}" in
  plan-reviewer|code-reviewer|verdict-recovery|code-researcher)
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
