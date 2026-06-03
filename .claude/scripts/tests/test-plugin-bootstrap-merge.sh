#!/usr/bin/env bash
# test-plugin-bootstrap-merge.sh — Part 6 (P3) of the plugin-equivalence roadmap.
# Asserts bootstrap-project-config.sh idempotently provisions the project's settings.local.json
# from the kit's .default (USER WINS), ONLY in plugin mode AND only when explicitly opted-in, and
# only once (first-run sentinel). No-op otherwise.
# Run: bash .claude/scripts/tests/test-plugin-bootstrap-merge.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
cd "$REPO_ROOT" || { echo "FAIL: cannot cd to repo root"; exit 1; }

HOOK=".claude/scripts/bootstrap-project-config.sh"
DEFAULT=".claude/settings.local.json.default"

PASS=0
FAIL=0
ok()  { echo "  PASS: $1"; PASS=$((PASS + 1)); }
bad() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

command -v python3 >/dev/null 2>&1 || { echo "SKIP: python3 not found"; exit 0; }
[ -f "$HOOK" ] && ok "exists: $HOOK" || bad "missing: $HOOK"
[ -f "$DEFAULT" ] && ok "exists: $DEFAULT (merge source)" || bad "missing: $DEFAULT"

# Run the hook against a fresh temp project. $1=project dir; remaining args = extra env assignments.
run_bootstrap() {  # usage: run_bootstrap <projdir> VAR=val ...
  local proj="$1"; shift
  env "$@" CLAUDE_PROJECT_DIR="$proj" CLAUDE_WORKFLOW_STATE_DIR="$proj/.claude/workflow-state" \
      bash "$HOOK" </dev/null >/dev/null 2>&1 || true
}
OPTIN="CLAUDE_PLUGIN_OPTION_PROVISION_SETTINGS_LOCAL=true"
PLUGIN="CLAUDE_PLUGIN_ROOT=/fake/plugin"

ROOT_TMP="$(mktemp -d)"

# ── Case A: plugin + opt-in + no existing target → CREATE from .default ───────
A="$ROOT_TMP/a"; mkdir -p "$A/.claude"
run_bootstrap "$A" $PLUGIN $OPTIN
if [ -f "$A/.claude/settings.local.json" ] && python3 -c "import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if d.get('env',{}).get('CLAUDE_HANDOFF_VALIDATION_MODE')=='strict' else 1)" "$A/.claude/settings.local.json"; then
  ok "create: settings.local.json provisioned from .default (strict env present)"
else
  bad "create: settings.local.json not provisioned correctly"
fi

# ── Case B: plugin + opt-in + existing target with a user override → MERGE (user wins) ──
B="$ROOT_TMP/b"; mkdir -p "$B/.claude"
printf '{"env":{"CLAUDE_CAVEMAN_MODE":"off","MY_OWN":"keep"}}\n' > "$B/.claude/settings.local.json"
run_bootstrap "$B" $PLUGIN $OPTIN
while IFS='|' read -r st nm; do [ "$st" = "PASS" ] && ok "merge: $nm" || bad "merge: $nm"; done < <(python3 - "$B/.claude/settings.local.json" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1])); env = d.get('env', {})
for name, p in [
  ("user override CLAUDE_CAVEMAN_MODE=off preserved", env.get('CLAUDE_CAVEMAN_MODE')=='off'),
  ("user-only key MY_OWN preserved", env.get('MY_OWN')=='keep'),
  ("default CLAUDE_HANDOFF_VALIDATION_MODE=strict added", env.get('CLAUDE_HANDOFF_VALIDATION_MODE')=='strict'),
]:
    print(f"{'PASS' if p else 'FAIL'}|{name}")
PYEOF
)

# ── Case C: idempotent — second run is a no-op (sentinel) ─────────────────────
C="$ROOT_TMP/c"; mkdir -p "$C/.claude"
run_bootstrap "$C" $PLUGIN $OPTIN              # 1st: creates
printf '{"env":{"INJECTED_AFTER":"x"}}\n' > "$C/.claude/settings.local.json"  # user edits post-bootstrap
run_bootstrap "$C" $PLUGIN $OPTIN              # 2nd: sentinel present → must NOT re-merge
if python3 -c "import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if d.get('env',{}).get('INJECTED_AFTER')=='x' and 'CLAUDE_HANDOFF_VALIDATION_MODE' not in d.get('env',{}) else 1)" "$C/.claude/settings.local.json"; then
  ok "idempotent: second run is a no-op (sentinel respected, user's later edit untouched)"
else
  bad "idempotent: second run re-merged despite sentinel"
fi

# ── Case D: plugin but NO opt-in → no-op ──────────────────────────────────────
D="$ROOT_TMP/d"; mkdir -p "$D/.claude"
run_bootstrap "$D" $PLUGIN                     # opt-in absent
[ ! -f "$D/.claude/settings.local.json" ] && ok "no opt-in → no-op (nothing provisioned)" || bad "no opt-in → unexpectedly provisioned"

# ── Case E: opt-in but NOT plugin mode → no-op ────────────────────────────────
E="$ROOT_TMP/e"; mkdir -p "$E/.claude"
run_bootstrap "$E" $OPTIN                      # CLAUDE_PLUGIN_ROOT unset
[ ! -f "$E/.claude/settings.local.json" ] && ok "no plugin mode → no-op (nothing provisioned)" || bad "no plugin mode → unexpectedly provisioned"

# ── Case F (CR-001): malformed existing target → untouched + NO sentinel (retryable) ──
F="$ROOT_TMP/f"; mkdir -p "$F/.claude"
printf '{ this is NOT valid json !!!' > "$F/.claude/settings.local.json"
before="$(cat "$F/.claude/settings.local.json")"
run_bootstrap "$F" $PLUGIN $OPTIN
after="$(cat "$F/.claude/settings.local.json")"
if [ "$before" = "$after" ] && [ ! -f "$F/.claude/workflow-state/.plugin-bootstrap-done" ]; then
  ok "malformed target → left byte-identical + NO sentinel (retryable next session)"
else
  bad "malformed target → file changed or sentinel written (should be untouched + retryable)"
fi

rm -rf "$ROOT_TMP" 2>/dev/null || true

echo ""
echo "Total: PASS=${PASS} FAIL=${FAIL}"
[ "$FAIL" -eq 0 ]
