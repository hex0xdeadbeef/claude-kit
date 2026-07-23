#!/usr/bin/env bash
# test-no-operation-override-hook.sh — contract guard for Option B (audit
# workflow-audit-2026-06-04-operation-blocking.md): the kit ships NO deny-emitting operation hook
# that overrides the user's configured permissions (memory feedback_no_override_user_permissions).
# Asserts: (a) no block-dangerous PreToolUse command hook wired in settings.json NOR hooks.json;
# (b) the script file is absent; (c) settings.json permissions.deny baseline is intact (user-owned,
# governable layer); (d) ZERO `block-dangerous` references remain in shipped files.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"; cd "$ROOT" || { echo "FAIL: cannot cd to repo root"; exit 1; }
SELF="$(basename "${BASH_SOURCE[0]}")"
command -v python3 >/dev/null 2>&1 || { echo "SKIP: python3 required"; exit 0; }
PASS=0; FAIL=0
ok(){ echo "  PASS: $1"; PASS=$((PASS+1)); }
bad(){ echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

echo "=== test-no-operation-override-hook.sh ==="

# (a) no block-dangerous PreToolUse command hook in settings.json NOR hooks.json
WIRED="$(python3 - <<'PY'
import json
hit=0
for f in (".claude/settings.json", ".claude/hooks/hooks.json"):
    try: d=json.load(open(f))
    except Exception: continue
    for grp in d.get("hooks",{}).get("PreToolUse",[]):
        for h in grp.get("hooks",[]):
            if h.get("type")=="command" and "block-dangerous" in h.get("command",""):
                hit=1
print(hit)
PY
)"
[ "$WIRED" = "0" ] && ok "(a) no block-dangerous PreToolUse hook wired (settings.json + hooks.json)" \
                    || bad "(a) block-dangerous still wired as a PreToolUse hook"

# (b) script file absent
[ ! -f .claude/scripts/block-dangerous-commands.sh ] \
  && ok "(b) block-dangerous-commands.sh deleted" \
  || bad "(b) block-dangerous-commands.sh still present"

# (c) settings.json permissions.deny baseline intact (user-owned governable layer)
DENYOK="$(python3 - <<'PY'
import json
d=json.load(open(".claude/settings.json"))
deny=set(d.get("permissions",{}).get("deny",[]))
need={"Bash(rm -rf *)","Bash(sudo *)","Bash(git push --force *)"}
print(1 if need.issubset(deny) else 0)
PY
)"
[ "$DENYOK" = "1" ] && ok "(c) settings.json permissions.deny baseline intact" \
                     || bad "(c) settings.json permissions.deny baseline missing rules"

# (d) ZERO `block-dangerous` references in shipped files (excl. prompts/, workflow-state/, .git/,
#     the audit artifact, and THIS test file — its grep pattern contains the token)
# Hermetic: scope to TRACKED files via git ls-files — auto-excludes .git/, gitignored
# nested .claude/worktrees/ checkouts, and workflow-state/. Then drop prompts/, the audit artifact,
# scripts/tests/ (allowlists/guards legitimately reference removed artifacts, e.g. the c5
# settings-diff allowlist), the audit artifact, and THIS test file.
HITS="$(git ls-files 2>/dev/null \
  | grep -vE "(^|/)\.claude/(prompts|scripts/tests)/|workflow-audit-2026-06-04-operation-blocking\.md|${SELF}\$" \
  | tr '\n' '\0' | xargs -0 grep -Il "block-dangerous" 2>/dev/null \
  || true)"
if [ -z "$HITS" ]; then
  ok "(d) zero block-dangerous references in shipped files"
else
  bad "(d) stale block-dangerous references remain:"; printf '%s\n' "$HITS" | sed 's/^/      /'
fi

echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
