#!/usr/bin/env bash
# test-plugin-context-injection.sh — plugin-equivalence SessionStart context injection
#   + bundled-root path directive (plugin-skill-path-fix, 2026-06-04).
# Asserts inject-kit-context.sh, in plugin mode (CLAUDE_PLUGIN_ROOT set), ALWAYS injects a
# "BUNDLED KIT ROOT" path directive (so the model resolves read-by-path skills/templates under the
# plugin root), and ADDITIONALLY appends the trimmed Language-Profile context doc only when the
# project has no CLAUDE.md of its own. Project mode (no CLAUDE_PLUGIN_ROOT) → no-op. Plus: the
# context doc exists and is within the 25 KB size bound.
# Run: bash .claude/scripts/tests/test-plugin-context-injection.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
cd "$REPO_ROOT" || { echo "FAIL: cannot cd to repo root"; exit 1; }

HOOK=".claude/scripts/inject-kit-context.sh"
CTX=".claude/docs/plugin-context.md"

PASS=0
FAIL=0
ok()  { echo "  PASS: $1"; PASS=$((PASS + 1)); }
bad() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

command -v python3 >/dev/null 2>&1 || { echo "SKIP: python3 not found"; exit 0; }
[ -f "$HOOK" ] && ok "exists: $HOOK" || bad "missing: $HOOK"

# ── Context doc exists + within size bound (25 KB) ────────────────────────────
if [ -f "$CTX" ]; then
    ok "exists: $CTX"
    bytes=$(wc -c < "$CTX" | tr -d ' ')
    [ "$bytes" -le 25600 ] && ok "context doc within 25 KB bound (${bytes} bytes)" || bad "context doc exceeds 25 KB (${bytes} bytes)"
else
    bad "missing: $CTX"
fi

# ── Functional: temp projects with / without their own CLAUDE.md ──────────────
TMP="$(mktemp -d)"
MARKER='BUNDLED KIT ROOT'   # pinned directive substring — hook output ↔ this test ↔ command notes
# helper: assert the output is empty (no-op)
assert_empty() { [ -z "$1" ] && ok "$2 → no-op (empty)" || bad "$2 → expected empty, got: $(printf '%s' "$1" | head -c 80)"; }

# Case A: plugin mode + no project CLAUDE.md → directive (marker + abs bundled root) AND Language Profile
outA="$(CLAUDE_PLUGIN_ROOT="/fake/plugin" CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK" </dev/null 2>/dev/null || true)"
if printf '%s' "$outA" | grep -q '"hookEventName": *"SessionStart"' \
   && printf '%s' "$outA" | grep -q 'additionalContext' \
   && printf '%s' "$outA" | grep -q "$MARKER" \
   && printf '%s' "$outA" | grep -qF "$REPO_ROOT" \
   && printf '%s' "$outA" | grep -q 'Language Profile'; then
    ok "plugin + no project CLAUDE.md → directive (${MARKER} + abs bundled root) AND Language Profile"
else
    bad "plugin no-CLAUDE.md injection missing markers: $(printf '%s' "$outA" | head -c 160)"
fi

# Case B: project-scoped install (env unset, bundled root == project root) → no-op.
# CLAUDE_PROJECT_DIR == $REPO_ROOT (the script's own bundled root) is the faithful project-scoped
# scenario; env -u guarantees no ambient CLAUDE_PLUGIN_ROOT masks the no-op assertion.
outB="$(env -u CLAUDE_PLUGIN_ROOT CLAUDE_PROJECT_DIR="$REPO_ROOT" bash "$HOOK" </dev/null 2>/dev/null || true)"
assert_empty "$outB" "project-scoped (bundled root == project root, env unset)"

# Case D: env-unset plugin mode — Claude Code does NOT export CLAUDE_PLUGIN_ROOT to SessionStart hook
# processes (anthropics/claude-code#27145), but the bundled root != project root → directive MUST
# still be emitted. $TMP has no CLAUDE.md yet (Case C writes one below), so the Language Profile is
# appended too. This case FAILS against pre-fix code (old GATE 1 bails on unset env var).
outD="$(env -u CLAUDE_PLUGIN_ROOT CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK" </dev/null 2>/dev/null || true)"
if printf '%s' "$outD" | grep -q "$MARKER" \
   && printf '%s' "$outD" | grep -qF "$REPO_ROOT" \
   && printf '%s' "$outD" | grep -q 'Language Profile'; then
    ok "env-unset plugin mode (bundled != project) → directive present + Language Profile"
else
    bad "env-unset plugin mode dropped directive: $(printf '%s' "$outD" | head -c 160)"
fi

# Case C: plugin mode + project HAS its own CLAUDE.md → directive STILL injected, Language Profile DROPPED.
# (The path directive is orthogonal to the Language-Profile tier; only the latter yields to the project's CLAUDE.md.)
printf '# Project CLAUDE.md\n' > "$TMP/CLAUDE.md"
outC="$(CLAUDE_PLUGIN_ROOT="/fake/plugin" CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK" </dev/null 2>/dev/null || true)"
if printf '%s' "$outC" | grep -q "$MARKER" \
   && printf '%s' "$outC" | grep -qF "$REPO_ROOT" \
   && ! printf '%s' "$outC" | grep -q 'Language Profile'; then
    ok "plugin + project has own CLAUDE.md → bundled-root directive present, Language Profile absent"
else
    bad "plugin with-CLAUDE.md should emit directive WITHOUT Language Profile: $(printf '%s' "$outC" | head -c 160)"
fi

# Case E (B1): plugin mode writes the durable .bundled-kit-root marker to project workflow-state.
# Cases A/D ran with CLAUDE_PROJECT_DIR="$TMP" (plugin mode) → marker must exist + contain bundled root.
MARKER_FILE="$TMP/.claude/workflow-state/.bundled-kit-root"
if [ -s "$MARKER_FILE" ] && grep -qF "$REPO_ROOT" "$MARKER_FILE"; then
    ok "B1: durable .bundled-kit-root marker written in plugin mode"
else
    bad "B1: .bundled-kit-root marker missing/empty in plugin mode"
fi

# ── cleanup ───────────────────────────────────────────────────────────────────
rm -rf "$TMP" 2>/dev/null || true

echo ""
echo "Total: PASS=${PASS} FAIL=${FAIL}"
[ "$FAIL" -eq 0 ]
