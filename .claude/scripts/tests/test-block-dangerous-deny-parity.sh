#!/usr/bin/env bash
# test-block-dangerous-deny-parity.sh — Part 4 (2a) of the plugin-equivalence roadmap.
# Asserts block-dangerous-commands.sh blocks the full BASH deny class from settings.json (so the
# protection survives in plugin mode, where settings.json `deny` rules do not transfer), and does
# NOT block safe commands (incl. the safe alternatives like --force-with-lease and plain find).
# Read(.env) is intentionally NOT covered here — it is a Read-tool permission, not a Bash command
# (would need a separate Read-matcher guard for plugin parity).
# Run: bash .claude/scripts/tests/test-block-dangerous-deny-parity.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
HOOK="${REPO_ROOT}/.claude/scripts/block-dangerous-commands.sh"

PASS=0
FAIL=0
ok()  { echo "  PASS: $1"; PASS=$((PASS + 1)); }
bad() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

command -v python3 >/dev/null 2>&1 || { echo "SKIP: python3 not found"; exit 0; }
[ -f "$HOOK" ] || { echo "FAIL: hook not found: $HOOK"; exit 1; }

# Run a command string through the hook; echo "block" if denied, "allow" otherwise.
run_hook() {
  local out
  out="$(python3 -c "import json,sys; print(json.dumps({'tool_input':{'command':sys.argv[1]}}))" "$1" | bash "$HOOK" 2>/dev/null || true)"
  if printf '%s' "$out" | grep -q '"permissionDecision".*"deny"'; then echo block; else echo allow; fi
}

assert() {  # $1=command  $2=expected(block|allow)  $3=label
  local got; got="$(run_hook "$1")"
  [ "$got" = "$2" ] && ok "$3 → $got" || bad "$3 → expected $2, got $got  [cmd: $1]"
}

# ── MUST BLOCK — the BASH deny class (16 settings.json rules) ──────────────────
assert 'rm -rf /tmp/x'                              block 'rm -rf'
assert 'rm -fr /tmp/x'                              block 'rm -fr'
assert 'git reset --hard HEAD'                      block 'git reset --hard'
assert 'git clean -fd'                              block 'git clean -f'
assert 'git push --force origin main'               block 'git push --force'
assert 'git push -f origin main'                    block 'git push -f'
assert 'git checkout .'                             block 'git checkout .'
assert 'git restore .'                              block 'git restore .'
assert 'sudo apt-get install foo'                   block 'sudo'
assert 'chmod 777 file'                             block 'chmod 777'
assert 'chmod 0777 file'                            block 'chmod 0777'
assert 'dd if=/dev/zero of=/tmp/x bs=1M'            block 'dd if='
assert 'mkfs.ext4 /dev/sdz'                         block 'mkfs.'
assert 'truncate -s 0 file.txt'                     block 'truncate'
assert "find . -name '*.tmp' -exec rm {} +"         block 'find -exec (Part 4)'
assert "find . -name '*.tmp' -delete"               block 'find -delete (Part 4)'

# ── MUST ALLOW — safe commands incl. the safe alternatives ─────────────────────
assert 'git status'                                 allow 'git status'
assert 'git push origin main'                       allow 'git push (no force)'
assert 'git push --force-with-lease origin main'    allow 'git push --force-with-lease'
assert 'rm file.txt'                                allow 'rm single file'
assert 'chmod 644 file.txt'                         allow 'chmod 644'
assert "find . -name '*.go' -print"                 allow 'find -print (no -exec/-delete)'
assert "find . -name '*.tmp' -print0 | xargs -0 rm" allow 'find -print0 | xargs (safe alt to -exec)'
assert 'ls -la'                                     allow 'ls -la'

echo ""
echo "Total: PASS=${PASS} FAIL=${FAIL}"
[ "$FAIL" -eq 0 ]
