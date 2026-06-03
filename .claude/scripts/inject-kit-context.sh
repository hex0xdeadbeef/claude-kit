#!/usr/bin/env bash
# inject-kit-context.sh
# Hook: SessionStart (matcher: empty/always)
# Purpose (roadmap Part 5 / P2): in PLUGIN mode a plugin-root CLAUDE.md is NOT loaded by Claude
#   Code, so the kit's "project context" tier (Language Profile cascade + error handling) would be
#   missing. This hook injects a trimmed context doc as additionalContext — but ONLY when:
#     (1) running as a plugin (CLAUDE_PLUGIN_ROOT set), AND
#     (2) the user's project has no CLAUDE.md of its own (else theirs wins — no duplication).
#   In a project-scoped install (CLAUDE_PLUGIN_ROOT unset) this is a no-op: the native CLAUDE.md
#   is already loaded.
#
# Exit codes: always 0 (fail-silent — never block session start).

set -uo pipefail

# ── GATE 1: plugin mode only ──────────────────────────────────────────────────
# Outside a plugin, the native CLAUDE.md is loaded — nothing to inject.
if [ -z "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
CONTEXT_FILE="${REPO_ROOT}/.claude/docs/plugin-context.md"
MAX_BYTES="${CLAUDE_KIT_CONTEXT_MAX_BYTES:-25600}"   # 25 KB parity with the memory loader cap

# Drain stdin (SessionStart payload — unused)
_HOOK_INPUT=$(cat 2>/dev/null || true)
: "${_HOOK_INPUT}"

# ── GATE 2: skip if the project supplies its own CLAUDE.md (theirs wins) ──────
if [ -f "${PROJECT_ROOT}/CLAUDE.md" ]; then
  exit 0
fi

# ── Read the trimmed context doc (fail-silent if absent) ──────────────────────
[ -f "${CONTEXT_FILE}" ] || exit 0
body="$(head -c "${MAX_BYTES}" "${CONTEXT_FILE}" 2>/dev/null || true)"
[ -n "${body}" ] || exit 0

# ── Emit as additionalContext ─────────────────────────────────────────────────
if command -v python3 >/dev/null 2>&1; then
  BODY="${body}" python3 - <<'PYEOF'
import json, os
body = os.environ["BODY"]
out = {
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": f"[CLAUDE-KIT PLUGIN CONTEXT]\n\n{body}",
    }
}
print(json.dumps(out, ensure_ascii=False))
PYEOF
else
  # Bash JSON-escape fallback (best-effort) if python3 is unavailable.
  esc=$(printf '%s' "${body}" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk 'BEGIN{ORS="\\n"} {print}')
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"[CLAUDE-KIT PLUGIN CONTEXT]\\n\\n%s"}}\n' "${esc}"
fi

exit 0
