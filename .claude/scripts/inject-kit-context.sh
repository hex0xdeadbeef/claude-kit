#!/usr/bin/env bash
# inject-kit-context.sh
# Hook: SessionStart (matcher: empty/always)
# Purpose (roadmap Part 5 / P2 + plugin-skill-path-fix 2026-06-04): in PLUGIN mode the kit's
#   bundled files (skills, templates, supporting protocol files) live under the plugin root, NOT
#   the user's project. The kit's reference skills are `disable-model-invocation: true`, so they
#   are loaded by explicit file Read (not by description) — and the commands Read them with
#   PROJECT-RELATIVE paths, which miss in plugin mode. This hook is the ONLY runtime context that
#   holds the bundled root, so it injects, as SessionStart additionalContext:
#     (A) ALWAYS (plugin mode): a "BUNDLED KIT ROOT" path directive telling the model to resolve
#         .claude/skills / .claude/templates / supporting-file reads under the plugin root, while
#         project STATE stays under the project root.
#     (B) ADDITIONALLY, only when the user's project has no CLAUDE.md of its own: the trimmed
#         Language-Profile context doc (a plugin-root CLAUDE.md is not loaded by Claude Code; if
#         the project supplies its own CLAUDE.md, theirs wins — no duplication).
#   In a project-scoped install (CLAUDE_PLUGIN_ROOT unset) this is a no-op: paths are already
#   project-local and the native CLAUDE.md is already loaded.
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

# ── Bundled-root path directive (ALWAYS emitted in plugin mode) ───────────────
# REPO_ROOT is the hook's own canonicalized bundled root (== ${CLAUDE_PLUGIN_ROOT} in a real
# install) and is exactly where CONTEXT_FILE is read from — advertise the SAME anchor so the
# model's read-by-path skill/template loads resolve to where the bundled files actually live.
# The literal "BUNDLED KIT ROOT" marker is pinned (test grep + command resolution notes match it).
directive="BUNDLED KIT ROOT: ${REPO_ROOT}
Resolve every kit .claude/skills, .claude/templates, and supporting protocol file under this BUNDLED KIT ROOT — they ship inside the plugin, not your project. Project STATE (.claude/prompts, .claude/workflow-state, .claude/agent-memory) stays under your project root."

body="${directive}"

# ── Append the Language-Profile context doc ONLY when the project has no own CLAUDE.md ─────────
# (theirs wins for the Language-Profile tier; the path directive above is emitted regardless.)
if [ ! -f "${PROJECT_ROOT}/CLAUDE.md" ] && [ -f "${CONTEXT_FILE}" ]; then
  ctx="$(head -c "${MAX_BYTES}" "${CONTEXT_FILE}" 2>/dev/null || true)"
  [ -n "${ctx}" ] && body="${directive}

${ctx}"
fi

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
