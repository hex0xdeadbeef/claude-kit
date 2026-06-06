#!/usr/bin/env bash
# kit-env-defaults.sh — strict-when-plugin defaults for kit-consumed modes (roadmap Part 3 / P1).
#
# The kit's strict contract-validation is normally seeded as env vars in
# .claude/settings.local.json (by install.sh). In PLUGIN mode that seeding cannot happen — a
# plugin's settings.json supports only the `agent` and `subagentStatusLine` keys, so it cannot set
# arbitrary CLAUDE_* env vars. Without a workaround, every CLAUDE_*_MODE would silently fall back to
# its lenient default (warn/off) in plugin mode, downgrading the kit from strict enforcement.
#
# This helper closes that gap with ZERO env-injection dependency and NO next-session lag: when the
# script is running inside a plugin (KIT_PLUGIN_MODE=1 — env-independent detection via lib/paths.sh,
# since Claude Code does NOT export CLAUDE_PLUGIN_ROOT to SessionStart/SubagentStart hooks,
# anthropics/claude-code#27145), the kit-consumed validation modes
# default to `strict`. Outside plugin context the defaults stay at their pre-Part-3 values
# (warn / off), so a project-scoped install is byte-identical to before. An explicit env var ALWAYS
# wins — it remains the OUTER `:-` in each consumer (e.g. "${CLAUDE_HANDOFF_VALIDATION_MODE:-$KIT_DEFAULT_VALIDATION_MODE}").
#
# Usage (bash consumers in .claude/scripts/, source after REPO_ROOT is set):
#   source "${REPO_ROOT}/.claude/scripts/lib/kit-env-defaults.sh"
#   MODE="${CLAUDE_HANDOFF_VALIDATION_MODE:-$KIT_DEFAULT_VALIDATION_MODE}"
#
# Consumers in other locations (e.g. .claude/agents/meta-agent/scripts/) or in embedded python use
# the EQUIVALENT inline form to avoid a cross-dir / cross-process sourcing dependency:
#   bash:   d=warn; [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && d=strict; "${CLAUDE_PK_PATH_MODE:-$d}"
#   python: os.environ.get("CLAUDE_DELTA_REVIEW_MODE") or ("strict" if _kit_plugin_mode() else "off")  # _kit_plugin_mode() mirrors KIT_PLUGIN_MODE (bundled-root detection)

# Resolve plugin mode from the canonical env-independent helper (lib/paths.sh KIT_PLUGIN_MODE).
# REPO_ROOT must be set by the caller before sourcing this file (unchanged precondition). If paths.sh
# cannot be located (REPO_ROOT unset/missing), KIT_PLUGIN_MODE stays unset -> defaults to 0 (warn/off),
# i.e. the safe project-scoped behavior.
if [ -z "${KIT_PLUGIN_MODE:-}" ]; then
  _KED_PATHS="${REPO_ROOT:-}/.claude/scripts/lib/paths.sh"
  # shellcheck source=paths.sh
  [ -f "${_KED_PATHS}" ] && . "${_KED_PATHS}"
  unset _KED_PATHS 2>/dev/null || true
fi

# shellcheck disable=SC2034  # consumed by sourcing scripts
if [ "${KIT_PLUGIN_MODE:-0}" = "1" ]; then
  KIT_DEFAULT_VALIDATION_MODE="strict"    # HANDOFF / VERDICT / ISSUE_ID / PK_PATH validation
  KIT_DEFAULT_DELTA_REVIEW_MODE="strict"  # delta-only reviewer focus on iter >= 2
else
  KIT_DEFAULT_VALIDATION_MODE="warn"
  KIT_DEFAULT_DELTA_REVIEW_MODE="off"
fi
