#!/usr/bin/env bash
# test-permission-defaults.sh — validate the shipped recommended permissions baseline.
#
# Covers the recommended permissions.allow / permissions.deny defaults shipped in
# settings.local.json.default (install source) and mirrored in settings.local.json.example
# (documented reference). Convention + semantics per code.claude.com/docs/en/permissions
# (deny -> ask -> allow; space-form rule strings).
#
# Acceptance criteria:
#   AC-1  Both files are valid JSON with NON-EMPTY permissions.allow AND permissions.deny.
#   AC-2  Mirror parity: .default and .example active allow/deny sets are identical.
#   AC-3  deny contains the catastrophic + secret core (rm -rf, git reset --hard, sudo, .env).
#   AC-4  allow contains the language-agnostic core and NO over-broad bare Bash / Bash(*).
#   AC-5  Granular-secrets invariant: Read(.env) present, broad Read(.env.*) ABSENT so
#         .env.example / .env.sample stay readable.
#   AC-6  Space-form convention: no broken mid-pattern ":* " inside any Bash rule.
#   AC-7  .default is a lean install source: no top-level "_"-prefixed doc keys
#         (they would be copied verbatim into a fresh user file by install.sh).
#
# Run: bash .claude/scripts/tests/test-permission-defaults.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
cd "$REPO_ROOT" || { echo "[test-permission-defaults] FAIL: cannot cd to repo root"; exit 1; }

DEFAULT=".claude/settings.local.json.default"
EXAMPLE=".claude/settings.local.json.example"

PASS=0
FAIL=0
ok()  { echo "  PASS: $1"; PASS=$((PASS + 1)); }
bad() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

command -v python3 >/dev/null 2>&1 || { echo "[test-permission-defaults] SKIP: python3 not found"; exit 0; }
[ -f "$DEFAULT" ] && ok "exists: $DEFAULT" || { bad "missing: $DEFAULT"; }
[ -f "$EXAMPLE" ] && ok "exists: $EXAMPLE" || { bad "missing: $EXAMPLE"; }

if [ ! -f "$DEFAULT" ] || [ ! -f "$EXAMPLE" ]; then
  echo "[test-permission-defaults] ${PASS} passed, ${FAIL} failed"
  exit 1
fi

while IFS='|' read -r st nm; do
  [ "$st" = "PASS" ] && ok "$nm" || bad "$nm"
done < <(python3 - "$DEFAULT" "$EXAMPLE" <<'PYEOF'
import json, sys

def emit(cond, name):
    print(("PASS" if cond else "FAIL") + "|" + name)

def load(path):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f), True
    except Exception as e:  # noqa: BLE001 — surface any parse failure as a FAIL line
        print("FAIL|valid JSON: %s (%s)" % (path, e))
        return None, False

dflt_path, ex_path = sys.argv[1], sys.argv[2]
d, ok_d = load(dflt_path)
e, ok_e = load(ex_path)
if not (ok_d and ok_e):
    sys.exit(0)
emit(True, "valid JSON: both files parse")

dperm = d.get("permissions", {})
eperm = e.get("permissions", {})
da, dd = dperm.get("allow", []), dperm.get("deny", [])
ea, ed = eperm.get("allow", []), eperm.get("deny", [])

# AC-1 — non-empty allow + deny in BOTH files
emit(len(da) > 0, ".default permissions.allow non-empty")
emit(len(dd) > 0, ".default permissions.deny non-empty")
emit(len(ea) > 0, ".example permissions.allow non-empty")
emit(len(ed) > 0, ".example permissions.deny non-empty")

# AC-2 — mirror parity (order-insensitive)
emit(sorted(da) == sorted(ea), ".default/.example allow sets identical")
emit(sorted(dd) == sorted(ed), ".default/.example deny sets identical")

# AC-3 — deny catastrophic + secret core
for r in ["Bash(rm -rf *)", "Bash(git reset --hard *)", "Bash(sudo *)", "Read(.env)"]:
    emit(r in dd, "deny contains %s" % r)

# AC-4 — allow language-agnostic core + no over-broad rule
for r in ["Edit", "Write", "TodoWrite", "Bash(git add *)", "Bash(git commit *)", "Bash(git worktree *)"]:
    emit(r in da, "allow contains %s" % r)
emit("Bash" not in da and "Bash(*)" not in da, "allow has NO over-broad bare Bash / Bash(*)")

# AC-5 — granular-secrets invariant: keep .env.example readable
emit("Read(.env)" in dd, "deny protects Read(.env)")
emit("Read(.env.*)" not in dd, "deny avoids broad Read(.env.*) (keeps .env.example/.sample readable)")

# AC-6 — space-form convention: no broken mid-pattern ':* ' in any rule
def has_broken_colon(rules):
    return any(":* " in r for r in rules)
emit(not has_broken_colon(da) and not has_broken_colon(dd),
     "no broken mid-pattern ':* ' (space-form convention)")

# AC-7 — .default is a lean install source (no top-level '_'-prefixed doc keys)
emit(not any(isinstance(k, str) and k.startswith("_") for k in d.keys()),
     ".default has no top-level '_' doc keys (lean install source)")

# AC-8 — allow additions (language-agnostic, fewer prompts in long /workflow runs)
for r in ["Bash(jq *)", "Bash(git fetch *)", "Bash(chmod +x *)"]:
    emit(r in da, "allow contains %s" % r)

# AC-9 — deny network-fetch tools (defense-in-depth; also blocks curl|bash / wget|sh)
for r in ["Bash(curl *)", "Bash(wget *)"]:
    emit(r in dd, "deny contains %s" % r)

# AC-10 — deny git force-delete branch (prevents silent loss of unmerged commits)
emit("Bash(git branch -D *)" in dd, "deny contains Bash(git branch -D *)")

# AC-11 — deny .env writes (granular; user-governable successor to the protect-files hard-deny)
for r in ["Edit(.env)", "Write(.env)", "Edit(.env.local)", "Write(.env.local)"]:
    emit(r in dd, "deny contains %s" % r)

# AC-12 — write-granularity invariant: NO broad Edit/Write(.env.*) so .env.example/.sample stay editable
emit("Edit(.env.*)" not in dd and "Write(.env.*)" not in dd,
     "deny avoids broad Edit/Write(.env.*) (keeps .env.example/.sample editable)")

# AC-13 — doc-content guard (PR-003): .example _permissions_comment documents the new deny rules
pc = " ".join(e.get("_permissions_comment", []))
emit("git branch -D" in pc and "curl" in pc,
     ".example _permissions_comment documents the new deny rules (git branch -D, curl)")

# AC-14 — permission default mode: acceptEdits shipped (value-parity in both files)
emit(dperm.get("defaultMode") == "acceptEdits", ".default permissions.defaultMode == acceptEdits")
emit(eperm.get("defaultMode") == "acceptEdits", ".example permissions.defaultMode == acceptEdits")

# AC-15 — doc-content guard: _permissions_comment documents the acceptEdits default mode
emit("acceptEdits" in pc,
     ".example _permissions_comment documents the acceptEdits default mode")
PYEOF
)

# AC-13 (README mirror) — README permissions baseline mentions the new deny rules
README="README.md"
if [ -f "$README" ]; then
  if grep -q 'git branch -D' "$README" && grep -q 'curl' "$README"; then
    ok "README permissions baseline documents the new deny rules (git branch -D, curl)"
  else
    bad "README permissions baseline missing new deny rule names (git branch -D, curl)"
  fi
else
  bad "README.md not found for doc-content guard"
fi

# AC-15 (README mirror) — README documents the acceptEdits default mode
if [ -f "$README" ]; then
  if grep -q 'acceptEdits' "$README"; then
    ok "README documents the acceptEdits default mode"
  else
    bad "README missing acceptEdits default-mode documentation"
  fi
fi

echo
echo "[test-permission-defaults] ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
