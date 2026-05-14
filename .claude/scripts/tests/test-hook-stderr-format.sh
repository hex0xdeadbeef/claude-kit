#!/usr/bin/env bash
# test-hook-stderr-format.sh — verify hook stderr convention (P1-06, AC-3)
# Usage: bash .claude/scripts/tests/test-hook-stderr-format.sh
# Covers: AC-3 — hook produces known error → first stderr line is structured

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
cd "$REPO_ROOT"
SYNC="${SCRIPT_DIR}/../sync-agent-memory.sh"

PASS=0
FAIL=0

run_test() {
  local name="$1"
  local first_stderr="$2"
  local expected_prefix="$3"

  if echo "$first_stderr" | grep -qE "$expected_prefix"; then
    echo "  PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name"
    echo "    Got:      $first_stderr"
    echo "    Expected: matches [$expected_prefix]"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Hook stderr format tests (P1-06, AC-3) ==="
echo ""

# Test 1: no-args → [sync-agent-memory] ERROR: Usage: ...
# Redirect order: 2>&1 captures stderr into the pipeline (fd 2 → fd 1 before >/dev/null),
# then >/dev/null silences stdout (JSON output) so it doesn't mix with stderr capture.
echo "--- sync-agent-memory: no-args error path ---"
FIRST_LINE=$(bash "$SYNC" 2>&1 >/dev/null | head -1 || true)
run_test \
  "no-args → [sync-agent-memory] ERROR: Usage:" \
  "$FIRST_LINE" \
  "^\[sync-agent-memory\] ERROR: Usage:"

# Test 2: non-existent worktree → [sync-agent-memory] WARN: worktree path does not exist
echo "--- sync-agent-memory: non-existent worktree path ---"
FIRST_LINE=$(bash "$SYNC" "code-reviewer" "/tmp/no-such-worktree-$$" 2>&1 >/dev/null | head -1 || true)
run_test \
  "bad-path → [sync-agent-memory] WARN: worktree path does not exist:" \
  "$FIRST_LINE" \
  "^\[sync-agent-memory\] WARN: worktree path does not exist:"

# Test 3: grep-check yields 0 violations in current tree (AC-2 regression guard)
# Verifies that after all P1-06 fixes are applied, no echo >&2 lines are non-conforming.
echo "--- grep-check: 0 non-conforming >&2 lines in tree ---"
# Two shapes accepted (Part 3 / Proposal J extension):
#   legacy: "[name] LABEL: msg"
#   new:    "[name][session=<sid>][eff=<level>] LABEL: msg"  (from lib/log.sh)
# The trailing "LABEL: msg" predicate is the byte-stable invariant.
VIOLATIONS=$(grep -rn --include='*.sh' --exclude-dir=tests --exclude-dir=lib '>&2[[:space:]]*$' .claude/scripts/ \
  | grep -cvE '\[[a-zA-Z0-9_-]+\](\[[a-zA-Z0-9_=-]+\])*[[:space:]]+(INFO|WARN|ERROR|FATAL|SKIP|PASS|FAIL|BLOCKING):' \
  || true)
if [[ "$VIOLATIONS" -eq 0 ]]; then
  echo "  PASS: grep-check → 0 non-conforming echo >&2 lines"
  PASS=$((PASS + 1))
else
  echo "  FAIL: grep-check → $VIOLATIONS non-conforming >&2 line(s)"
  grep -rn --include='*.sh' --exclude-dir=tests --exclude-dir=lib '>&2[[:space:]]*$' .claude/scripts/ \
    | grep -vE '\[[a-zA-Z0-9_-]+\](\[[a-zA-Z0-9_=-]+\])*[[:space:]]+(INFO|WARN|ERROR|FATAL|SKIP|PASS|FAIL|BLOCKING):' \
    | head -5 | sed 's/^/    /'
  FAIL=$((FAIL + 1))
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
