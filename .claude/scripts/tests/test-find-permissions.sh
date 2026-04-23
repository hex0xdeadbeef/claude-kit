#!/usr/bin/env bash
# test-find-permissions.sh — validate narrow find allow/deny rules in settings.json
# Usage: bash .claude/scripts/tests/test-find-permissions.sh
# Covers: AC-1 (delete blocked), AC-2 (safe name-search auto-allowed), AC-3 (exec blocked)

set -uo pipefail

SETTINGS=".claude/settings.json"

PASS=0
FAIL=0

if [[ ! -f "$SETTINGS" ]]; then
  echo "SKIP: $SETTINGS not found"
  exit 0
fi

# Simulate Claude Code Bash(pattern) glob matching via Python fnmatch.
# Returns 0 if command matches pattern, 1 otherwise.
_matches_pattern() {
  python3 -c "
import fnmatch, sys
pattern = sys.argv[1]
cmd = sys.argv[2]
if pattern.startswith('Bash(') and pattern.endswith(')'):
    pattern = pattern[5:-1]
sys.exit(0 if fnmatch.fnmatch(cmd, pattern) else 1)
" "$1" "$2"
}

# Returns 'allow' | 'deny' | 'prompt' for a given command string.
# deny > allow > prompt — mirrors Claude Code precedence.
_effective_permission() {
  local cmd="$1"

  local deny_rules allow_rules
  deny_rules=$(python3 -c "
import json
with open('$SETTINGS') as f:
    d = json.load(f)
for p in d.get('permissions', {}).get('deny', []):
    print(p)
" 2>/dev/null)

  allow_rules=$(python3 -c "
import json
with open('$SETTINGS') as f:
    d = json.load(f)
for p in d.get('permissions', {}).get('allow', []):
    if p.startswith('Bash('):
        print(p)
" 2>/dev/null)

  while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    if _matches_pattern "$p" "$cmd" 2>/dev/null; then
      echo "deny"; return
    fi
  done <<< "$deny_rules"

  while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    if _matches_pattern "$p" "$cmd" 2>/dev/null; then
      echo "allow"; return
    fi
  done <<< "$allow_rules"

  echo "prompt"
}

# run_test name expected_permission command_string
run_test() {
  local name="$1"
  local expected="$2"   # allow | deny | prompt
  local cmd="$3"

  local got
  got=$(_effective_permission "$cmd")

  if [[ "$got" == "$expected" ]]; then
    echo "  PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name (expected=$expected, got=$got)"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== test-find-permissions.sh ==="
echo ""

echo "--- Structural: broad rule removed ---"
if python3 -c "
import json, sys
with open('$SETTINGS') as f:
    d = json.load(f)
rules = d.get('permissions', {}).get('allow', [])
sys.exit(0 if 'Bash(find *)' not in rules else 1)
" 2>/dev/null; then
  echo "  PASS: Bash(find *) absent from allow list"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Bash(find *) still in allow list"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "--- Structural: narrow allow rules present ---"
for rule in 'Bash(find . -name *)' 'Bash(find . -type *)' 'Bash(find . -maxdepth *)'; do
  if python3 -c "
import json, sys
with open('$SETTINGS') as f:
    d = json.load(f)
rules = d.get('permissions', {}).get('allow', [])
sys.exit(0 if sys.argv[1] in rules else 1)
" "$rule" 2>/dev/null; then
    echo "  PASS: $rule present"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $rule missing"
    FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "--- Structural: deny rules present ---"
for rule in 'Bash(find * -exec *)' 'Bash(find * -delete)'; do
  if python3 -c "
import json, sys
with open('$SETTINGS') as f:
    d = json.load(f)
rules = d.get('permissions', {}).get('deny', [])
sys.exit(0 if sys.argv[1] in rules else 1)
" "$rule" 2>/dev/null; then
    echo "  PASS: $rule present"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $rule missing"
    FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "--- AC-2: safe patterns (allow) ---"
run_test "find . -name *.go"              allow  "find . -name '*.go'"
run_test "find . -name *.go | wc -l"      allow  "find . -name '*.go' | wc -l"
run_test "find . -type f"                 allow  "find . -type f"
run_test "find . -type d"                 allow  "find . -type d"
run_test "find . -maxdepth 2"             allow  "find . -maxdepth 2"
run_test "find . -maxdepth 2 -name *.md"  allow  "find . -maxdepth 2 -name '*.md'"

echo ""
echo "--- AC-1: find -delete (deny) ---"
run_test "find /tmp -name *.tmp -delete"  deny  "find /tmp -name '*.tmp' -delete"
run_test "find . -name *.tmp -delete"     deny  "find . -name '*.tmp' -delete"
run_test "find / -delete"                 deny  "find / -delete"

echo ""
echo "--- AC-3: find -exec (deny) ---"
run_test "find . -exec grep foo"          deny  "find . -exec grep foo {} \;"
run_test "find /tmp -exec rm -f"          deny  "find /tmp -exec rm -f {} \;"
run_test "find . -exec sh -c evil"        deny  "find . -exec sh -c 'evil' {} \;"
run_test "find . -name *.java -exec grep" deny  "find . -name '*.java' -exec grep -l main {} \;"

echo ""
echo "--- deny-over-allow precedence ---"
run_test "find . -name * -exec (deny wins)"  deny  "find . -name '*.go' -exec grep foo {} \;"

echo ""
echo "--- fall-through (absolute/var paths → prompt) ---"
run_test "find /tmp -name test"         prompt  "find /tmp -name test"
run_test "find /Users/foo -type f"      prompt  "find /Users/foo -type f"
run_test "find \$PROJECT -name *.go"    prompt  "find \$PROJECT -name '*.go'"

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ "${FAIL}" -eq 0 ]] && exit 0 || exit 1
