#!/usr/bin/env bash
# test-bundled-root-durable.sh — B1 (BUGREPORT-plugin-mode-2026-06-09).
# Durable BUNDLED KIT ROOT delivery that survives compaction (routes around
# anthropics/claude-code#15174 where SessionStart+compact additionalContext is dropped):
#   1. inject-kit-context.sh writes .claude/workflow-state/.bundled-kit-root in plugin mode.
#   2. project-scoped install (roots coincide, no CLAUDE_PLUGIN_ROOT) -> NO marker (no-op preserved).
#   3. verify-state-after-compact.sh (PostCompact) re-injects the directive from the marker.
#   4. no marker -> no directive leaked.
#   5. directive lands at the HEAD of output (within first 1000 chars = the CAP PREVIEW window).
# Run: bash .claude/scripts/tests/test-bundled-root-durable.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
cd "$REPO_ROOT" || { echo "FAIL: cannot cd to repo root"; exit 1; }

PASS=0; FAIL=0
ok()  { echo "  PASS: $1"; PASS=$((PASS + 1)); }
bad() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

command -v python3 >/dev/null 2>&1 || { echo "SKIP: python3 not found"; exit 0; }

INJECT="$REPO_ROOT/.claude/scripts/inject-kit-context.sh"
POSTCOMPACT="$REPO_ROOT/.claude/scripts/verify-state-after-compact.sh"
[ -f "$INJECT" ]     || { echo "FAIL: missing $INJECT"; exit 1; }
[ -f "$POSTCOMPACT" ] || { echo "FAIL: missing $POSTCOMPACT"; exit 1; }

TMP="$(mktemp -d -t blroot.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

DIRECTIVE_MARK="BUNDLED KIT ROOT:"

# Case 1: plugin mode (CLAUDE_PLUGIN_ROOT set, project != bundled) writes the marker
mkdir -p "$TMP/proj/.claude"
echo '{}' | CLAUDE_PLUGIN_ROOT="$REPO_ROOT" CLAUDE_PROJECT_DIR="$TMP/proj" \
  bash "$INJECT" >/dev/null 2>&1 || true
MK="$TMP/proj/.claude/workflow-state/.bundled-kit-root"
if [ -s "$MK" ] && grep -qF "$REPO_ROOT" "$MK"; then
  ok "case1: marker written in plugin mode (content=bundled root)"
else
  bad "case1: marker NOT written in plugin mode (expected $MK to contain $REPO_ROOT)"
fi

# Case 2: project-scoped (roots coincide, no CLAUDE_PLUGIN_ROOT) -> no marker (no-op)
STATE_REAL="$REPO_ROOT/.claude/workflow-state/.bundled-kit-root"
PRE_EXISTS="NO"; [ -e "$STATE_REAL" ] && PRE_EXISTS="YES"
echo '{}' | env -u CLAUDE_PLUGIN_ROOT CLAUDE_PROJECT_DIR="$REPO_ROOT" \
  bash "$INJECT" >/dev/null 2>&1 || true
if [ "$PRE_EXISTS" = "NO" ] && [ -e "$STATE_REAL" ]; then
  bad "case2: marker leaked into repo in project mode"
  rm -f "$STATE_REAL"
else
  ok "case2: no marker written in project mode (no-op preserved)"
fi

# Case 3: PostCompact re-injects directive from marker
SB="$(mktemp -d -t blpc.XXXXXX)"
printf '%s\n' "/fake/plugin/root" > "$SB/.bundled-kit-root"
OUT3="$(CLAUDE_WORKFLOW_STATE_DIR="$SB" bash "$POSTCOMPACT" </dev/null 2>/dev/null || true)"
if echo "$OUT3" | grep -qF "${DIRECTIVE_MARK} /fake/plugin/root"; then
  ok "case3: PostCompact re-injects directive from marker"
else
  bad "case3: PostCompact missing directive (out=${OUT3:0:120})"
fi
rm -rf "$SB"

# Case 4: no marker -> no directive leaked
SB2="$(mktemp -d -t blpc2.XXXXXX)"
OUT4="$(CLAUDE_WORKFLOW_STATE_DIR="$SB2" bash "$POSTCOMPACT" </dev/null 2>/dev/null || true)"
if echo "$OUT4" | grep -qF "$DIRECTIVE_MARK"; then
  bad "case4: directive leaked without marker"
else
  ok "case4: no directive without marker"
fi
rm -rf "$SB2"

# Case 5: directive at HEAD - within the first 1000 chars even with a checkpoint present
SB3="$(mktemp -d -t blpc3.XXXXXX)"
printf '%s\n' "/fake/plugin/root" > "$SB3/.bundled-kit-root"
cat > "$SB3/big-checkpoint.yaml" <<'EOF'
feature: big
complexity: XL
phase_completed: 4
phase_name: code_review
iteration:
  plan_review: 3/3
  code_review: 2/3
issues_history:
  - phase: 4
    iteration: 1
    verdict: CHANGES_REQUESTED
  - phase: 4
    iteration: 2
    verdict: APPROVED_WITH_COMMENTS
EOF
OUT5="$(CLAUDE_WORKFLOW_STATE_DIR="$SB3" bash "$POSTCOMPACT" </dev/null 2>/dev/null || true)"
HEAD5="$(printf '%s' "$OUT5" | head -c 1000)"
if printf '%s' "$HEAD5" | grep -qF "$DIRECTIVE_MARK"; then
  ok "case5: directive within first 1000 chars (survives CAP->PREVIEW)"
else
  bad "case5: directive NOT in first 1000 chars (CAP could drop it)"
fi
rm -rf "$SB3"

echo ""
echo "Total: PASS=${PASS} FAIL=${FAIL}"
[ "$FAIL" -eq 0 ]
