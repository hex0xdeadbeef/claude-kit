#!/usr/bin/env bash
# test-plugin-path-awareness.sh — plugin-equivalence path awareness.
# Asserts that PROJECT STATE (workflow-state/) resolves to the user's project
# (${CLAUDE_PROJECT_DIR}) and NOT the plugin cache, while remaining byte-identical in a
# project-scoped install (where CLAUDE_PROJECT_DIR == REPO_ROOT, or is unset and falls back to it).
#   - lib/paths.sh: KIT_PROJECT_ROOT follows CLAUDE_PROJECT_DIR when set, else REPO_ROOT; KIT_ROOT == REPO_ROOT.
#   - the 5 hot-path state-writing hook scripts anchor workflow-state to ${CLAUDE_PROJECT_DIR:-${REPO_ROOT}}.
#   - regression guard: NO script anchors workflow-state to a bare ${REPO_ROOT}/ without the project fallback.
# Run: bash .claude/scripts/tests/test-plugin-path-awareness.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
cd "$REPO_ROOT" || { echo "FAIL: cannot cd to repo root"; exit 1; }

PATHS_LIB=".claude/scripts/lib/paths.sh"
FIVE=(
  ".claude/scripts/caveman-activate.sh"
  ".claude/scripts/log-tool-failure.sh"
  ".claude/scripts/mcp-preload-warn.sh"
  ".claude/scripts/notify-workflow-complete.sh"
  ".claude/scripts/validate-handoff.sh"
)

PASS=0
FAIL=0
ok()  { echo "  PASS: $1"; PASS=$((PASS + 1)); }
bad() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# ── lib/paths.sh exists ───────────────────────────────────────────────────────
[ -f "$PATHS_LIB" ] && ok "exists: $PATHS_LIB" || bad "missing: $PATHS_LIB"

# ── paths.sh functional: KIT_PROJECT_ROOT follows CLAUDE_PROJECT_DIR, else REPO_ROOT ──
if [ -f "$PATHS_LIB" ]; then
    # (a) plugin mode: CLAUDE_PROJECT_DIR set, REPO_ROOT = plugin cache → state root = project
    got_a="$( REPO_ROOT="/fake/plugin-cache" CLAUDE_PROJECT_DIR="/fake/user-project" bash -c 'source "'"$REPO_ROOT"'/'"$PATHS_LIB"'"; echo "$KIT_PROJECT_ROOT"' 2>/dev/null )"
    [ "$got_a" = "/fake/user-project" ] && ok "paths.sh: CLAUDE_PROJECT_DIR set → KIT_PROJECT_ROOT=project (got $got_a)" || bad "paths.sh: expected /fake/user-project, got '$got_a'"
    # (b) project-scoped: CLAUDE_PROJECT_DIR unset → fall back to REPO_ROOT (byte-identical)
    got_b="$( env -u CLAUDE_PROJECT_DIR REPO_ROOT="/fake/repo" bash -c 'source "'"$REPO_ROOT"'/'"$PATHS_LIB"'"; echo "$KIT_PROJECT_ROOT"' 2>/dev/null )"
    [ "$got_b" = "/fake/repo" ] && ok "paths.sh: CLAUDE_PROJECT_DIR unset → KIT_PROJECT_ROOT=REPO_ROOT (got $got_b)" || bad "paths.sh: expected /fake/repo, got '$got_b'"
    # (c) KIT_ROOT (bundled) always == REPO_ROOT (co-located, correct in both modes)
    got_c="$( REPO_ROOT="/fake/repo" CLAUDE_PROJECT_DIR="/fake/user-project" bash -c 'source "'"$REPO_ROOT"'/'"$PATHS_LIB"'"; echo "$KIT_ROOT"' 2>/dev/null )"
    [ "$got_c" = "/fake/repo" ] && ok "paths.sh: KIT_ROOT==REPO_ROOT (bundled co-located, got $got_c)" || bad "paths.sh: KIT_ROOT expected /fake/repo, got '$got_c'"
fi

# ── the 5 hot-path scripts: workflow-state anchored to ${CLAUDE_PROJECT_DIR:-${REPO_ROOT}} ──
NEEDLE='CLAUDE_PROJECT_DIR:-${REPO_ROOT}}/.claude/workflow-state'
for f in "${FIVE[@]}"; do
    if [ -f "$f" ] && grep -qF "$NEEDLE" "$f"; then
        ok "project-anchored state dir: $(basename "$f")"
    else
        bad "NOT project-anchored (expected \${CLAUDE_PROJECT_DIR:-\${REPO_ROOT}}): $(basename "$f")"
    fi
done

# ── Regression guard: no script anchors workflow-state to a BARE ${REPO_ROOT}/ (no project fallback) ──
# Match ${REPO_ROOT}/.claude/workflow-state NOT immediately preceded by 'CLAUDE_PROJECT_DIR:-'.
# Recurse into ALL of .claude/scripts/ (incl. lib/) so a future helper-script leak is caught.
# SCOPE NOTE: only the ${REPO_ROOT}-anchored class is in scope — that was the real bug
# (state would land in the ephemeral plugin cache). The remaining CWD-relative state-writers
# (e.g. "${CLAUDE_WORKFLOW_STATE_DIR:-.claude/workflow-state}") are NOT a leak: Claude Code runs
# hooks with CWD == project root in both modes, so they already resolve into the user's project.
# Making every state-writer EXPLICITLY ${CLAUDE_PROJECT_DIR}-anchored (bash + python forms) is a
# separate robustness hardening, deferred to a follow-up — not part of the in-scope bug-fix class.
leak="$(grep -rnE --include='*.sh' --exclude-dir=tests '\$\{REPO_ROOT\}/\.claude/workflow-state' .claude/scripts/ 2>/dev/null \
        | grep -vF 'CLAUDE_PROJECT_DIR:-${REPO_ROOT}}/.claude/workflow-state' \
        | grep -vE ':[0-9]+:[[:space:]]*#' || true)"
if [ -z "$leak" ]; then
    ok "no bare \${REPO_ROOT}-anchored workflow-state remains (plugin cache leak guard)"
else
    bad "bare \${REPO_ROOT}-anchored workflow-state found (would write to plugin cache): $leak"
fi

# ── B3 (BUGREPORT-plugin-mode-2026-06-09): planner step-2 plan-template Read carries a plugin_path_note ──
PLANNER=".claude/commands/planner.md"
if [ -f "$PLANNER" ] && python3 - "$PLANNER" <<'PY'
import sys
txt = open(sys.argv[1], encoding="utf-8").read()
i = txt.find('file: ".claude/templates/plan-template.md"')
sys.exit(0 if (i != -1 and 'plugin_path_note' in txt[i:i+600]) else 1)
PY
then
    ok "planner step-2 plan-template Read carries a plugin_path_note (B3/Bug A1)"
else
    bad "planner step-2 plan-template Read MISSING plugin_path_note (Bug A1)"
fi

echo ""
echo "Total: PASS=${PASS} FAIL=${FAIL}"
[ "$FAIL" -eq 0 ]
