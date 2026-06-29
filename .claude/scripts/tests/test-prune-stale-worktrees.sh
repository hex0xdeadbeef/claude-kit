#!/usr/bin/env bash
# test-prune-stale-worktrees.sh
#
# Guards prune-stale-worktrees.sh: a safe, age-guarded helper that reaps leaked
# .claude/worktrees/agent-* registrations left by killed worktree-isolated reviewers
# (CC < 2.1.187 has no platform auto-clean). All operations run in an ISOLATED temp git
# repo — never the live repo. Age is measured by the .git/worktrees/<name> metadata-dir
# mtime (the same signal resolve-worktree-path.py Strategy 2 trusts).
#
# Cases:
#   OLD          — locked, agent-*, metadata backdated > threshold  -> REMOVED
#   GONE         — locked, agent-*, checkout dir deleted, backdated  -> REMOVED (PR-004)
#   NEW          — locked, agent-*, fresh mtime                      -> SURVIVES (age guard)
#   OTHER        — locked, NOT under agent-*, backdated old          -> SURVIVES (scope guard)
#   main         — the repo root                                     -> SURVIVES (never touched)
#   non-git dir  — invocation outside a git work tree                -> SKIP, exit 0

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
HELPER="${KIT_ROOT}/.claude/scripts/prune-stale-worktrees.sh"
command -v python3 >/dev/null 2>&1 || { echo "SKIP: python3 required"; exit 0; }
command -v git >/dev/null 2>&1 || { echo "SKIP: git required"; exit 0; }

PASS=0; FAIL=0
ok(){ echo "  PASS: $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL: $1"; FAIL=$((FAIL+1)); }
assert(){ if [[ "$2" == "0" ]]; then ok "$1"; else no "$1"; fi; }

echo "=== test-prune-stale-worktrees.sh ==="

REPO="$(mktemp -d)"; REPO="$(cd "$REPO" && pwd -P)"   # canonicalize (macOS /var -> /private/var)
(
  cd "$REPO" || exit 1
  git init -q; git config user.email t@t; git config user.name t
  echo x > f; git add f; git commit -q -m init --no-verify
  mkdir -p .claude/worktrees
  git worktree add --lock .claude/worktrees/agent-OLD  -b br-OLD  HEAD >/dev/null 2>&1
  git worktree add --lock .claude/worktrees/agent-NEW  -b br-NEW  HEAD >/dev/null 2>&1
  git worktree add --lock .claude/worktrees/agent-GONE -b br-GONE HEAD >/dev/null 2>&1
  git worktree add --lock other-wt                     -b br-OTHER HEAD >/dev/null 2>&1
  rm -rf .claude/worktrees/agent-GONE   # dir-missing + locked orphan shape
) >/dev/null 2>&1

COMMON="$(cd "$REPO" && git rev-parse --git-common-dir)"; COMMON="$(cd "$REPO" && cd "$COMMON" && pwd)"
# Backdate OLD, GONE, OTHER metadata mtimes to 10h ago; leave NEW fresh.
python3 -c "
import os,time
old=time.time()-10*3600
for n in ('agent-OLD','agent-GONE','other-wt'):
    m=os.path.join('$COMMON','worktrees',n)
    if os.path.exists(m): os.utime(m,(old,old))
"

# Run the helper with a 1h threshold from inside the repo.
( cd "$REPO" && bash "$HELPER" 1 ) >/dev/null 2>&1
RC=$?
assert "helper exits 0" "$([[ "$RC" == 0 ]] && echo 0 || echo 1)"

LIST="$(cd "$REPO" && git worktree list --porcelain 2>/dev/null)"
if echo "$LIST" | grep -q 'agent-OLD'; then no "OLD (locked, stale) should be removed"; else ok "OLD (locked, stale) removed"; fi
if echo "$LIST" | grep -q 'agent-GONE'; then no "GONE (locked, dir-missing) should be removed"; else ok "GONE (locked, dir-missing) removed"; fi
if echo "$LIST" | grep -q 'agent-NEW'; then ok "NEW (fresh) survives (age guard)"; else no "NEW should survive"; fi
if echo "$LIST" | grep -q 'other-wt'; then ok "OTHER (out-of-scope, old) survives (scope guard)"; else no "OTHER should survive"; fi
if echo "$LIST" | grep -q "worktree ${REPO}$"; then ok "main worktree survives"; else no "main worktree must survive"; fi

# Non-git invocation → SKIP, exit 0
NONGIT="$(mktemp -d)"
( cd "$NONGIT" && bash "$HELPER" 1 ) >/dev/null 2>&1
assert "non-git invocation exits 0 (SKIP no-op)" "$?"
rm -rf "$NONGIT"

# Cleanup temp repo (force-remove any surviving worktrees first)
( cd "$REPO" && git worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2}' | while read -r w; do
    [[ "$w" == "$REPO" ]] || git worktree remove --force "$w" 2>/dev/null || true; done ) >/dev/null 2>&1
rm -rf "$REPO"

echo ""
echo "  RESULT: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] && { echo "PASS: test-prune-stale-worktrees"; exit 0; } || { echo "FAIL: test-prune-stale-worktrees"; exit 1; }
