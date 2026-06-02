#!/usr/bin/env bash
# test-dangling-ref-cleanup.sh
# Audit Batch B (F3 + F5 + F7): the /workflow pipeline must contain no dead or
# wrong references — no plugin-namespaced context7 ids, no nonexistent
# test-runner / arch-checker subagent dispatches. Content-anchored assertions.
set -euo pipefail
SCRIPT_NAME="$(basename "$0")"
PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
label() { echo "[${SCRIPT_NAME}] $1: $2" >&2; }
fail() { label "FAIL" "$1"; exit 1; }
pass() { label "PASS" "$1"; }
cd "$PROJECT_ROOT"

PLANNER=".claude/commands/planner.md"
MCP_TOOLS=".claude/skills/coder-rules/mcp-tools.md"
CODER=".claude/commands/coder.md"
ARCH=".claude/skills/plan-review-rules/architecture-checks.md"
PR_TROUBLE=".claude/skills/plan-review-rules/troubleshooting.md"

# ── F3: context7 tool-id correction ──
for f in "$PLANNER" "$MCP_TOOLS"; do
  grep -qF "mcp__plugin_context7" "$f" \
    && fail "AC-F3 — residual plugin-namespaced context7 id in $f"
  grep -qF "mcp__context7__resolve-library-id" "$f" \
    || fail "AC-F3 — $f missing canonical mcp__context7__resolve-library-id"
  grep -qF "mcp__context7__query-docs" "$f" \
    || fail "AC-F3 — $f missing canonical mcp__context7__query-docs"
done
pass "AC-F3 — context7 ids use project-scoped mcp__context7__* in planner.md + mcp-tools.md"

# ── F5: test-runner dangling dispatch replaced with Bash run_in_background ──
grep -qF 'subagent_type: "test-runner"' "$CODER" \
  && fail "AC-F5 — coder.md still dispatches nonexistent test-runner subagent"
grep -qF 'model: "sonnet"' "$CODER" \
  && fail "AC-F5 — coder.md still carries stale model: \"sonnet\""
grep -qF 'test-runner' "$CODER" \
  && fail "AC-F5 — coder.md still references test-runner"
grep -qF '{TEST_CMD}' "$CODER" \
  || fail "AC-F5 — coder.md full_testing should use resolved {TEST_CMD}"
pass "AC-F5 — coder.md full_testing uses Bash run_in_background + {TEST_CMD}, no test-runner/sonnet"

# ── F7: arch-checker dangling dispatch replaced with inline grep guidance ──
for f in "$ARCH" "$PR_TROUBLE"; do
  grep -qF "arch-checker" "$f" \
    && fail "AC-F7 — residual arch-checker reference in $f"
done
grep -qF 'subagent_type: "arch-checker"' "$ARCH" \
  && fail "AC-F7 — architecture-checks.md still dispatches arch-checker subagent"
grep -qiF "Inline Architecture Checks" "$ARCH" \
  || fail "AC-F7 — architecture-checks.md missing the inline-checks section"
pass "AC-F7 — plan-review complex-plan checks are inline grep guidance, no arch-checker dispatch"

label "PASS" "test-dangling-ref-cleanup.sh — all assertions met"
