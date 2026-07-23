#!/usr/bin/env bash
# paths.sh — canonical KIT path resolution for plugin / project dual-mode.
#
# The kit runs in two distribution modes that put its files in different places:
#   - project-scoped install (install.sh / .claude-copy): everything lives under <project>/.claude/
#   - native plugin (/plugin install): the kit's files live in the plugin CACHE
#     (${CLAUDE_PLUGIN_ROOT}), which is ephemeral and wiped ~7 days after an update.
#
# Two roots must therefore be distinguished:
#
#   KIT_ROOT          — where the kit's BUNDLED files live (scripts/lib, schemas, templates,
#                       skills). Hook scripts resolve this from their OWN location
#                       (SCRIPT_DIR/../.. -> REPO_ROOT), so it is ALREADY correct in both modes
#                       (the script and its sibling bundled files are co-located). Bundled-file
#                       references need NO change for plugin mode.
#
#   KIT_PROJECT_ROOT  — where the user's PROJECT STATE lives (workflow-state/, agent-memory/,
#                       prompts/). This MUST be the user's project, NEVER the plugin cache
#                       (writing state into the ephemeral cache would lose it on update).
#                       Claude Code sets CLAUDE_PROJECT_DIR to the project root in every hook
#                       environment, in BOTH modes; fall back to REPO_ROOT (project-scoped, where
#                       CLAUDE_PROJECT_DIR == REPO_ROOT anyway) or $PWD.
#
# Usage (caller sets REPO_ROOT first, then sources this):
#   source "${REPO_ROOT}/.claude/scripts/lib/paths.sh"
#   STATE_DIR="${CLAUDE_WORKFLOW_STATE_DIR:-${KIT_PROJECT_ROOT}/.claude/workflow-state}"
#
# Hot-path hook scripts that already resolve state inline use the EQUIVALENT inline form to avoid
# adding a runtime sourcing dependency on every hook event:
#   "${CLAUDE_WORKFLOW_STATE_DIR:-${CLAUDE_PROJECT_DIR:-${REPO_ROOT}}/.claude/workflow-state}"
# Both forms are identical: state anchors to CLAUDE_PROJECT_DIR when set, else REPO_ROOT.
#
# Backward compatibility: in a project-scoped install CLAUDE_PROJECT_DIR == REPO_ROOT (or is
# unset and falls back to REPO_ROOT), so resolution is byte-identical to pre-Part-2 behavior.

# shellcheck disable=SC2034  # these are consumed by sourcing scripts
KIT_PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-${REPO_ROOT:-$PWD}}"
KIT_ROOT="${REPO_ROOT:-$PWD}"

# Plugin-mode detection that does NOT depend on CLAUDE_PLUGIN_ROOT being exported to the hook
# process env — Claude Code does NOT export it to SessionStart/SubagentStart hook processes
# (anthropics/claude-code#27145, #24529); it only substitutes the ${CLAUDE_PLUGIN_ROOT} token into
# the command-string at config level. The bundled root (KIT_ROOT, BASH_SOURCE-derived) is the
# authoritative anchor. KIT_PLUGIN_MODE=1 when CLAUDE_PLUGIN_ROOT is set (it IS exported for
# PreToolUse/PostToolUse) OR the canonicalized bundled root differs from the project root. In a
# project-scoped install (or the kit's own repo) the two roots coincide -> KIT_PLUGIN_MODE=0.
# Canonicalize in command-substitution subshells (cd && pwd -P) so cwd is not mutated; missing path
# falls back to the raw literal (falls toward plugin-mode=1, safe — mirrors _canon).
_kit_br="$( cd "${KIT_ROOT:-}" 2>/dev/null && pwd -P || printf '%s' "${KIT_ROOT:-}" )"
_kit_pr="$( cd "${KIT_PROJECT_ROOT:-}" 2>/dev/null && pwd -P || printf '%s' "${KIT_PROJECT_ROOT:-}" )"
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || [ "${_kit_br}" != "${_kit_pr}" ]; then
  KIT_PLUGIN_MODE=1
else
  KIT_PLUGIN_MODE=0
fi
unset _kit_br _kit_pr 2>/dev/null || true

# ── State-write anchoring invariant (stray-.claude fix, 2026-07-01) ──────────────────────────
# Every hook that WRITES workflow-state or agent-memory MUST anchor its dir to the canonical form
# above (CLAUDE_PROJECT_DIR primary, REPO_ROOT fallback) — never a bare relative ".claude/..."
# literal, which resolves against the hook's cwd and scatters stray .claude/ dirs into random
# project subdirs when the hook fires with cwd != project root. Scripts that embed a python heredoc
# export STATE_DIR through the environment so the python side reads it via
# `os.environ.get("STATE_DIR") or os.environ.get("CLAUDE_WORKFLOW_STATE_DIR", ...)`.
# The invariant is locked by .claude/scripts/tests/test-no-relative-claude-state-paths.sh.
# Deferred (NOT anchored): cwd-relative ".claude/prompts" READS — a distinct context-miss concern.
