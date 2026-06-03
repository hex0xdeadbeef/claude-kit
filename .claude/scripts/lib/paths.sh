#!/usr/bin/env bash
# paths.sh — canonical KIT path resolution for plugin / project dual-mode (roadmap Part 2 / B2).
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
