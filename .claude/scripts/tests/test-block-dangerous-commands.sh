#!/usr/bin/env bash
# test-block-dangerous-commands.sh — smoke tests for block-dangerous-commands.sh
# Usage: bash .claude/scripts/tests/test-block-dangerous-commands.sh
# Covers: all 10 categories + exec-wrapper fixtures (P0-01 AC-3)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLOCK="${SCRIPT_DIR}/../block-dangerous-commands.sh"

PASS=0
FAIL=0

# Helper: build a minimal PreToolUse JSON payload for a given command string
make_payload() {
  local cmd="$1"
  python3 -c "import json,sys; print(json.dumps({'tool_name':'Bash','tool_input':{'command':sys.argv[1]}}))" "$cmd"
}

# Run one test.
# Args: name  expected_deny(true|false)  command_string
run_test() {
  local name="$1"
  local expect_deny="$2"
  local cmd="$3"

  # Ensure log dir exists (script writes there)
  mkdir -p .claude/workflow-state 2>/dev/null || true

  local output
  output=$(make_payload "$cmd" | bash "${BLOCK}" 2>/dev/null)

  local got_deny=false
  if echo "$output" | python3 -c "
import json,sys
d=json.load(sys.stdin)
o=d.get('hookSpecificOutput',{})
sys.exit(0 if o.get('permissionDecision')=='deny' else 1)
" 2>/dev/null; then
    got_deny=true
  fi

  if [[ "$got_deny" == "$expect_deny" ]]; then
    echo "  PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name (expected deny=$expect_deny, got deny=$got_deny)"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== test-block-dangerous-commands.sh ==="
echo ""

echo "--- Category 1: Destructive rm ---"
run_test "rm -rf /"            true  "rm -rf /"
run_test "rm -fr /tmp/x"       true  "rm -fr /tmp/x"
run_test "rm -r -f /home"      true  "rm -r -f /home"
run_test "rm specific-file.go" false "rm specific-file.go"
run_test "rm -r dir/"          false "rm -r dir/"

echo ""
echo "--- Category 2: git reset --hard ---"
run_test "git reset --hard HEAD"   true  "git reset --hard HEAD"
run_test "git reset --soft HEAD~1" false "git reset --soft HEAD~1"

echo ""
echo "--- Category 3: git clean -f ---"
run_test "git clean -f"       true  "git clean -f"
run_test "git clean --force"  true  "git clean --force"
run_test "git clean -n"       false "git clean -n"

echo ""
echo "--- Category 4: git push --force ---"
run_test "git push --force origin main"         true  "git push --force origin main"
run_test "git push -f origin main"              true  "git push -f origin main"
run_test "git push --force-with-lease origin"   false "git push --force-with-lease origin main"
run_test "git push origin main"                 false "git push origin main"

echo ""
echo "--- Category 5: git checkout / restore . ---"
run_test "git checkout ."         true  "git checkout ."
run_test "git checkout -- ."      true  "git checkout -- ."
run_test "git restore ."          true  "git restore ."
run_test "git checkout main"      false "git checkout main"
run_test "git checkout -- file"   false "git checkout -- file.go"

echo ""
echo "--- Category 6: file truncation ---"
run_test "truncate -s 0 file.txt"   true  "truncate -s 0 file.txt"
run_test ": > file.txt"             true  ": > file.txt"

echo ""
echo "--- Category 7: dd ---"
run_test "dd if=/dev/zero of=/dev/sdb" true "dd if=/dev/zero of=/dev/sdb"

echo ""
echo "--- Category 8: mkfs ---"
run_test "mkfs.ext4 /dev/sdb" true "mkfs.ext4 /dev/sdb"

echo ""
echo "--- Category 9: unsafe chmod ---"
run_test "chmod 777 /tmp/x"    true  "chmod 777 /tmp/x"
run_test "chmod 0777 /tmp/x"   true  "chmod 0777 /tmp/x"
run_test "chmod a+w /tmp/x"    true  "chmod a+w /tmp/x"
run_test "chmod 644 file.go"   false "chmod 644 file.go"
run_test "chmod 755 dir/"      false "chmod 755 dir/"

echo ""
echo "--- Category 10: sudo ---"
run_test "sudo apt-get install evil"  true  "sudo apt-get install evil"
run_test "sudo rm -rf /"              true  "sudo rm -rf /"

echo ""
echo "--- P0-01: exec-wrapper fixtures ---"
run_test "env X=1 rm -rf /"                          true  "env X=1 rm -rf /"
run_test "watch rm -rf /"                             true  "watch rm -rf /"
run_test "ionice -c3 rm -rf /"                        true  "ionice -c3 rm -rf /"
run_test "setsid rm -rf /tmp/x"                       true  "setsid rm -rf /tmp/x"
run_test "nohup rm -rf /tmp/x"                        true  "nohup rm -rf /tmp/x"
run_test "/usr/bin/env rm -rf /"                      true  "/usr/bin/env rm -rf /"
run_test "env TERM=xterm git reset --hard HEAD"       true  "env TERM=xterm git reset --hard HEAD"
run_test "env PATH=/tmp sudo apt install evil"        true  "env PATH=/tmp sudo apt install evil"

echo ""
echo "--- Allow cases ---"
run_test "find . -name *.go"  false "find . -name '*.go'"
run_test "ls -la"             false "ls -la"
run_test "go test ./..."      false "go test ./..."
run_test "make lint"          false "make lint"

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ "${FAIL}" -eq 0 ]] && exit 0 || exit 1
