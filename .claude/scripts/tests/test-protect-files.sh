#!/usr/bin/env bash
# test-protect-files.sh — regression tests for protect-files.sh
# Usage: bash .claude/scripts/tests/test-protect-files.sh
#
# Primary regression: commit 7b0c03a left the protected-pattern if-chain without
# a closing `fi` (the `.claude/scripts/` branch + its `fi` were commented out),
# producing `line N: syntax error: unexpected end of file`. Because PreToolUse
# hooks fail-closed, that broke EVERY Write/Edit in the repo. TEST 1 below
# (`bash -n`) is the guard that would have caught it.
#
# The `.claude/scripts/` protection is intentionally toggleable. This test derives
# the expected decision for that category from the script SOURCE (whether the elif
# is active), so it stays correct whether protection is on or off.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROTECT="${SCRIPT_DIR}/../protect-files.sh"

PASS=0
FAIL=0

make_payload() {
  local fpath="$1"
  python3 -c "import json,sys; print(json.dumps({'tool_name':'Write','tool_input':{'file_path':sys.argv[1]}}))" "$fpath"
}

# run_test NAME EXPECT_DENY(true|false) FILE_PATH
run_test() {
  local name="$1" expect_deny="$2" fpath="$3"
  mkdir -p .claude/workflow-state 2>/dev/null || true

  local output got_deny=false
  output=$(make_payload "$fpath" | bash "${PROTECT}" 2>/dev/null)
  if echo "$output" | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
except Exception:
    sys.exit(1)
sys.exit(0 if d.get('hookSpecificOutput',{}).get('permissionDecision')=='deny' else 1)
" 2>/dev/null; then
    got_deny=true
  fi

  if [[ "$got_deny" == "$expect_deny" ]]; then
    echo "  PASS: $name"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $name (expected deny=$expect_deny, got deny=$got_deny)"; FAIL=$((FAIL + 1))
  fi
}

echo "=== test-protect-files.sh ==="
echo ""

echo "--- TEST 1: syntax parse guard (the 7b0c03a regression) ---"
if bash -n "${PROTECT}" 2>/dev/null; then
  echo "  PASS: bash -n clean (script parses)"; PASS=$((PASS + 1))
else
  echo "  FAIL: bash -n reported a syntax error — protect-files.sh will fail-closed and block ALL writes" >&2
  FAIL=$((FAIL + 1))
fi

echo ""
echo "--- TEST 2: always-protected categories must DENY ---"
run_test "generated *_gen.go"          true "internal/repo/user_gen.go"
run_test "mock */mocks/*.go"            true "internal/service/mocks/user.go"
run_test "vendor/ dependency"           true "vendor/github.com/x/y.go"
run_test ".env secrets"                 true ".env"
run_test ".env.production secrets"      true "config/.env.production"
run_test ".git/ internals"             true ".git/config"
run_test ".claude/settings.json config" true ".claude/settings.json"

echo ""
echo "--- TEST 3: unprotected paths must ALLOW ---"
run_test ".claude/prompts/ (research)"  false ".claude/prompts/changelog-2121-2152-workflow-analysis.md"
run_test "normal source .go"            false "internal/handler/user.go"
run_test ".env.example (docs, BLOCKER-1)" false ".env.example"
run_test ".env.template (docs)"         false ".env.template"
run_test "settings.local.json (dev)"    false ".claude/settings.local.json"

echo ""
echo "--- TEST 4: .claude/scripts/ decision matches SOURCE policy (toggle-robust) ---"
# Active protection = an UNCOMMENTED DENY_REASON line for the scripts category.
if grep -qE '^[[:space:]]+DENY_REASON="Hook script \(\.claude/scripts/\)' "${PROTECT}"; then
  scripts_expect=true;  echo "  (source: .claude/scripts/ protection ACTIVE)"
else
  scripts_expect=false; echo "  (source: .claude/scripts/ protection DISABLED)"
fi
run_test ".claude/scripts/ matches source policy" "$scripts_expect" ".claude/scripts/foo.sh"
run_test ".claude/scripts/tests/ matches source policy" "$scripts_expect" ".claude/scripts/tests/x.sh"

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ "${FAIL}" -eq 0 ]] && exit 0 || exit 1
