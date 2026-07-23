#!/usr/bin/env bash
# inject-kit-context.sh
# Hook: SessionStart (matcher: empty/always)
# Purpose: in PLUGIN mode the kit's
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
# Plugin mode is detected WITHOUT relying on CLAUDE_PLUGIN_ROOT being exported to the hook process
# env — Claude Code does NOT export it to SessionStart hook processes (anthropics/claude-code#27145,
# #24529); it only substitutes the ${CLAUDE_PLUGIN_ROOT} token into the command-string at config
# level. The script's own bundled root (REPO_ROOT, derived from BASH_SOURCE) is the authoritative
# anchor. Plugin mode <=> CLAUDE_PLUGIN_ROOT set (it IS exported for PreToolUse/PostToolUse) OR the
# bundled root differs from the project root. Project-scoped install / kit's own repo: roots
# coincide -> no-op.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
# _canon canonicalizes in a subshell so the script's cwd is NOT mutated; on a missing path bash
# pwd -P falls back to the raw literal (falls toward emitting, safe) — matches the python
# os.path.realpath path in inject-review-context.sh _bundled_root_directive().
_canon() { ( cd "$1" 2>/dev/null && pwd -P ) || printf '%s' "$1"; }
if [ -z "${CLAUDE_PLUGIN_ROOT:-}" ] && [ "$(_canon "${REPO_ROOT}")" = "$(_canon "${PROJECT_ROOT}")" ]; then
  exit 0
fi

# ── Durable bundled-root marker (B1: BUGREPORT-plugin-mode-2026-06-09) ─────────
# SessionStart additionalContext is NOT re-injected after compaction when the hook fires with
# source=compact (anthropics/claude-code#15174). Persist the bundled root to project STATE so the
# orchestrator/commands and the PostCompact hook can recover it deterministically. Reaching here
# => plugin mode. Best-effort: never blocks session start (exit-0 contract preserved).
_MARKER_DIR="${PROJECT_ROOT}/.claude/workflow-state"
if mkdir -p "${_MARKER_DIR}" 2>/dev/null; then
  printf '%s\n' "${REPO_ROOT}" > "${_MARKER_DIR}/.bundled-kit-root" 2>/dev/null \
    || echo "[inject-kit-context] WARN: failed to write .bundled-kit-root marker" >&2
fi

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
