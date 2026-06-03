#!/usr/bin/env bash
# test-plugin-strict-defaults.sh — Part 3 (P1) of the plugin-equivalence roadmap.
# Asserts kit-consumed validation modes default to 'strict' when running as a PLUGIN
# (CLAUDE_PLUGIN_ROOT set) — with NO env-injection dependency and NO next-session lag — while
# staying byte-identical (warn/off) in a project-scoped install. An explicit env var always wins.
#   - lib/kit-env-defaults.sh: KIT_DEFAULT_VALIDATION_MODE / KIT_DEFAULT_DELTA_REVIEW_MODE
#   - validate-handoff.sh (HANDOFF/VERDICT/ISSUE_ID), check-references.sh (PK_PATH),
#     inject-review-context.sh (DELTA): wire the strict-when-plugin default, env override preserved.
#   - functional (gated on check-jsonschema+jq): invalid handoff → strict(plugin) BLOCKS (exit 2),
#     warn(project) passes (exit 0), explicit env=warn wins even under plugin.
# Run: bash .claude/scripts/tests/test-plugin-strict-defaults.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
cd "$REPO_ROOT" || { echo "FAIL: cannot cd to repo root"; exit 1; }

KED=".claude/scripts/lib/kit-env-defaults.sh"
VH=".claude/scripts/validate-handoff.sh"
CR=".claude/agents/meta-agent/scripts/check-references.sh"
IRC=".claude/scripts/inject-review-context.sh"

PASS=0
FAIL=0
ok()  { echo "  PASS: $1"; PASS=$((PASS + 1)); }
bad() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# ── kit-env-defaults.sh functional ────────────────────────────────────────────
[ -f "$KED" ] && ok "exists: $KED" || bad "missing: $KED"
if [ -f "$KED" ]; then
    v_plugin="$( REPO_ROOT="$REPO_ROOT" CLAUDE_PLUGIN_ROOT="/fake/plugin" bash -c '. "'"$KED"'"; echo "$KIT_DEFAULT_VALIDATION_MODE/$KIT_DEFAULT_DELTA_REVIEW_MODE"' 2>/dev/null )"
    [ "$v_plugin" = "strict/strict" ] && ok "plugin mode → validation+delta default strict (got $v_plugin)" || bad "plugin mode expected strict/strict, got '$v_plugin'"
    v_proj="$( env -u CLAUDE_PLUGIN_ROOT bash -c '. "'"$KED"'"; echo "$KIT_DEFAULT_VALIDATION_MODE/$KIT_DEFAULT_DELTA_REVIEW_MODE"' 2>/dev/null )"
    [ "$v_proj" = "warn/off" ] && ok "project mode → validation=warn, delta=off (got $v_proj)" || bad "project mode expected warn/off, got '$v_proj'"
fi

# ── Structural: the 3 consumers wire strict-when-plugin AND keep the explicit-env outer override ──
# validate-handoff.sh: 3 modes resolve via KIT_DEFAULT_VALIDATION_MODE, with CLAUDE_*_MODE as outer :-
for pair in \
  'CLAUDE_HANDOFF_VALIDATION_MODE:-${KIT_DEFAULT_VALIDATION_MODE' \
  'CLAUDE_VERDICT_VALIDATION_MODE:-${KIT_DEFAULT_VALIDATION_MODE' \
  'CLAUDE_ISSUE_ID_VALIDATION_MODE:-${KIT_DEFAULT_VALIDATION_MODE'; do
    grep -qF "$pair" "$VH" && ok "validate-handoff wires: ${pair%%:*} → KIT default" || bad "validate-handoff missing strict-default for ${pair%%:*}"
done
grep -qF '.claude/scripts/lib/kit-env-defaults.sh' "$VH" && ok "validate-handoff sources kit-env-defaults.sh" || bad "validate-handoff does not source kit-env-defaults.sh"

# check-references.sh: PK_PATH default flips to strict when CLAUDE_PLUGIN_ROOT set
grep -qF 'CLAUDE_PLUGIN_ROOT' "$CR" && grep -qF 'CLAUDE_PK_PATH_MODE:-$_pk_default' "$CR" \
  && ok "check-references: PK_PATH strict-when-plugin" || bad "check-references: PK_PATH not plugin-aware"
# no bare ${CLAUDE_PK_PATH_MODE:-warn} left
grep -qF 'CLAUDE_PK_PATH_MODE:-warn' "$CR" && bad "check-references still has bare :-warn PK_PATH default" || ok "check-references: no bare :-warn PK_PATH default"

# inject-review-context.sh: DELTA default flips to strict when CLAUDE_PLUGIN_ROOT set (python)
grep -qF 'CLAUDE_PLUGIN_ROOT' "$IRC" && grep -qE 'CLAUDE_DELTA_REVIEW_MODE"\)' "$IRC" \
  && ok "inject-review-context: DELTA strict-when-plugin (python)" || bad "inject-review-context: DELTA not plugin-aware"

# ── Functional (gated): validate-handoff exit code under plugin/project/explicit-env ──
if command -v check-jsonschema >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
    BAD="$TMP/bad-handoff.json"; STATE="$TMP/state"
    # valid JSON but schema-invalid (planner_to_plan_review missing required fields)
    printf '{"$handoff_contract":"planner_to_plan_review"}\n' > "$BAD"
    # CRITICAL: the kit dogfoods strict mode — its own settings.local.json sets
    # CLAUDE_*_VALIDATION_MODE=strict in the dev session. To exercise the NEW KIT_DEFAULT-driven
    # default (not the session's explicit value) we must `env -u` those vars in the default cases.
    UNSET_MODES=(-u CLAUDE_HANDOFF_VALIDATION_MODE -u CLAUDE_VERDICT_VALIDATION_MODE -u CLAUDE_ISSUE_ID_VALIDATION_MODE)
    # plugin default → strict → BLOCK (exit 2)
    env "${UNSET_MODES[@]}" CLAUDE_PLUGIN_ROOT="/fake/plugin" CLAUDE_WORKFLOW_STATE_DIR="$STATE" bash "$VH" "$BAD" >/dev/null 2>&1; rc_plugin=$?
    [ "$rc_plugin" = "2" ] && ok "functional: plugin default BLOCKS invalid handoff (exit 2)" || bad "functional: plugin default expected exit 2, got $rc_plugin"
    # project default → warn → PASS (exit 0)
    env "${UNSET_MODES[@]}" -u CLAUDE_PLUGIN_ROOT CLAUDE_WORKFLOW_STATE_DIR="$STATE" bash "$VH" "$BAD" >/dev/null 2>&1; rc_proj=$?
    [ "$rc_proj" = "0" ] && ok "functional: project default WARNs invalid handoff (exit 0)" || bad "functional: project default expected exit 0, got $rc_proj"
    # explicit env=warn wins even under plugin (exit 0)
    env "${UNSET_MODES[@]}" CLAUDE_PLUGIN_ROOT="/fake/plugin" CLAUDE_HANDOFF_VALIDATION_MODE="warn" CLAUDE_WORKFLOW_STATE_DIR="$STATE" bash "$VH" "$BAD" >/dev/null 2>&1; rc_envwins=$?
    [ "$rc_envwins" = "0" ] && ok "functional: explicit env=warn wins under plugin (exit 0)" || bad "functional: env-override expected exit 0, got $rc_envwins"
else
    echo "  SKIP: check-jsonschema/jq absent — functional exit-code test skipped"
fi

echo ""
echo "Total: PASS=${PASS} FAIL=${FAIL}"
[ "$FAIL" -eq 0 ]
