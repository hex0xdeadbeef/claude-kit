#!/usr/bin/env bash
# test-plugin-context-injection.sh — Part 5 (P2) of the plugin-equivalence roadmap.
# Asserts inject-kit-context.sh injects the trimmed Language-Profile / context doc as
# SessionStart additionalContext ONLY in plugin mode (CLAUDE_PLUGIN_ROOT set) AND only when the
# user's project has no CLAUDE.md of its own; no-op otherwise. Plus: the context doc exists and is
# within the 25 KB size bound.
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

# ── Functional: a temp project WITHOUT its own CLAUDE.md ──────────────────────
TMP="$(mktemp -d)"
# helper: assert the output is empty (no-op)
assert_empty() { [ -z "$1" ] && ok "$2 → no-op (empty)" || bad "$2 → expected empty, got: $(printf '%s' "$1" | head -c 80)"; }

# Case A: plugin mode + no project CLAUDE.md → INJECT additionalContext
outA="$(CLAUDE_PLUGIN_ROOT="/fake/plugin" CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK" </dev/null 2>/dev/null || true)"
if printf '%s' "$outA" | grep -q '"hookEventName": *"SessionStart"' \
   && printf '%s' "$outA" | grep -q 'additionalContext' \
   && printf '%s' "$outA" | grep -q 'Language Profile'; then
    ok "plugin mode + no project CLAUDE.md → injects Language Profile additionalContext"
else
    bad "plugin mode injection missing expected markers: $(printf '%s' "$outA" | head -c 120)"
fi

# Case B: project mode (no CLAUDE_PLUGIN_ROOT) → no-op
outB="$(env -u CLAUDE_PLUGIN_ROOT CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK" </dev/null 2>/dev/null || true)"
assert_empty "$outB" "project mode (no CLAUDE_PLUGIN_ROOT)"

# Case C: plugin mode BUT project has its own CLAUDE.md → skip (theirs wins)
printf '# Project CLAUDE.md\n' > "$TMP/CLAUDE.md"
outC="$(CLAUDE_PLUGIN_ROOT="/fake/plugin" CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK" </dev/null 2>/dev/null || true)"
assert_empty "$outC" "plugin mode + project has own CLAUDE.md"

# ── cleanup ───────────────────────────────────────────────────────────────────
rm -rf "$TMP" 2>/dev/null || true

echo ""
echo "Total: PASS=${PASS} FAIL=${FAIL}"
[ "$FAIL" -eq 0 ]
