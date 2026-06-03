#!/usr/bin/env bash
# bootstrap-project-config.sh — roadmap Part 6 / P3 (self-provisioning, gated).
#
# In a project-scoped install, install.sh seeds the user's .claude/settings.local.json from the
# kit's opinionated .claude/settings.local.json.default (env defaults: prompt-cache TTL,
# git co-author strip, auto-memory, etc.). A native PLUGIN never runs install.sh, so those
# platform-consumed settings (which P1's lag-free script defaults cannot cover — they are read by
# Claude Code itself at startup, not by kit scripts) would be missing.
#
# This SessionStart hook relocates install.sh's bootstrap_settings_local into the plugin: it
# idempotently MERGES the SAME .default into the user's project settings.local.json (USER WINS),
# mirroring install.sh's _merge_json_into semantics. The defaults CONTENT is shared (.default is
# the single source); only the merge LOGIC is duplicated here, deliberately — install.sh must stay
# self-contained for the bootstrap-before-copy install path.
#
# Heavily gated because it WRITES to the user's project:
#   GATE 1 — plugin mode only (CLAUDE_PLUGIN_ROOT set). Project installs use install.sh.
#   GATE 2 — explicit OPT-IN via the userConfig `provision_settings_local`
#            (exported as CLAUDE_PLUGIN_OPTION_PROVISION_SETTINGS_LOCAL). Default: off.
#   GATE 3 — first-run sentinel: provision once, not every session.
# Effective NEXT session (Claude Code reads settings at startup). fail-silent — never blocks.

set -uo pipefail

# ── GATE 1: plugin mode only ──────────────────────────────────────────────────
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || exit 0
# ── GATE 2: explicit opt-in (userConfig) ──────────────────────────────────────
[ "${CLAUDE_PLUGIN_OPTION_PROVISION_SETTINGS_LOCAL:-}" = "true" ] || exit 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
SOURCE="${REPO_ROOT}/.claude/settings.local.json.default"
TARGET="${PROJECT_ROOT}/.claude/settings.local.json"
STATE_DIR="${CLAUDE_WORKFLOW_STATE_DIR:-${PROJECT_ROOT}/.claude/workflow-state}"
SENTINEL="${STATE_DIR}/.plugin-bootstrap-done"

# Drain stdin (SessionStart payload — unused)
_HOOK_INPUT=$(cat 2>/dev/null || true); : "${_HOOK_INPUT}"

# ── GATE 3: first-run sentinel + preconditions ────────────────────────────────
[ -f "$SENTINEL" ] && exit 0
[ -f "$SOURCE" ]   || exit 0
command -v python3 >/dev/null 2>&1 || exit 0
mkdir -p "$(dirname "$TARGET")" 2>/dev/null || exit 0
mkdir -p "$STATE_DIR" 2>/dev/null || true

# ── Provision: create-from-default if absent, else deep-merge (USER WINS) ─────
if [ ! -f "$TARGET" ]; then
  cp "$SOURCE" "$TARGET" 2>/dev/null && result="created" || result="error"
else
  result="$(SRC="$SOURCE" TGT="$TARGET" python3 - <<'PYEOF'
import json, os, sys, tempfile
def deep_merge(ex, us):
    # USER WINS — same semantics as install.sh _merge_json_into.
    if isinstance(ex, dict) and isinstance(us, dict):
        r = dict(us)
        for k, ev in ex.items():
            if k in us:
                r[k] = deep_merge(ev, us[k])
            elif not (isinstance(k, str) and k.startswith('_')):
                r[k] = ev
        return r
    return us
try:
    ex = json.load(open(os.environ['SRC'], encoding='utf-8'))
    us = json.load(open(os.environ['TGT'], encoding='utf-8'))
except Exception:
    print('error'); sys.exit(0)
m = deep_merge(ex, us)
if m == us:
    print('unchanged'); sys.exit(0)
try:
    d = os.path.dirname(os.environ['TGT']) or '.'
    fd, tmp = tempfile.mkstemp(dir=d, prefix='.merge-', suffix='.json')
    with os.fdopen(fd, 'w', encoding='utf-8') as f:
        json.dump(m, f, indent=2, ensure_ascii=False); f.write('\n')
    os.replace(tmp, os.environ['TGT'])
    print('merged')
except OSError:
    print('error')
PYEOF
)"
fi

# ── Sentinel: provision once — but NOT on a merge ERROR (CR-001), so a fixable
#    malformed settings.local.json gets one more attempt next session. Transcript
#    visibility via stderr only (no additionalContext noise).
case "${result:-}" in
  created)
    printf 'bootstrapped\n' > "$SENTINEL" 2>/dev/null || true
    echo "[bootstrap-project-config] INFO: created ${TARGET} from kit defaults (effective next session)" >&2 ;;
  merged)
    printf 'bootstrapped\n' > "$SENTINEL" 2>/dev/null || true
    echo "[bootstrap-project-config] INFO: merged kit defaults into ${TARGET} (your values kept; effective next session)" >&2 ;;
  unchanged)
    printf 'bootstrapped\n' > "$SENTINEL" 2>/dev/null || true ;;
  error)
    echo "[bootstrap-project-config] WARN: could not merge kit defaults into ${TARGET} (malformed JSON?) — left untouched, no sentinel written; will retry next session" >&2 ;;
esac

exit 0
