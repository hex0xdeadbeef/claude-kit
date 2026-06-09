#!/usr/bin/env bash
# test-hook-scripts-executable.sh — guard against the v1.40.0 plugin-install EACCES bug.
#
# Root cause (bug-reports/2026-06-09-plugin-eacces-posix-spawn.md): hooks are wired exec-form
# (`command: "<script>"`, `args: []`), so Claude Code posix_spawn's the script DIRECTLY — no
# shell. A script tracked git-mode 100644 (no +x) cannot be exec'd in the plugin cache →
# "EACCES: permission denied, posix_spawn" at SessionStart/SubagentStart. The three plugin-mode
# scripts inject-kit-context.sh / bootstrap-project-config.sh / inject-review-context.sh shipped
# 100644 in v1.40.0.
#
# Both hook manifests are validated, because each drives a real spawn path:
#   - .claude/settings.json     — project-scoped install; relative ".claude/..." command paths.
#   - .claude/hooks/hooks.json  — PLUGIN manifest (plugin.json `hooks` field); paths are
#                                 "${CLAUDE_PLUGIN_ROOT}/.claude/...". THIS is the manifest the
#                                 customer hits on plugin install. A settings.json-only check
#                                 would not prove the plugin path is safe.
#
# Invariant locked here: EVERY hook `command:` script referenced by EITHER manifest MUST be
# git-tracked with mode 100755. The set is DERIVED from the manifests (not hardcoded) so a
# future 644 hook script fails this test the moment it is wired into either manifest.
#
# Acceptance criteria:
#   AC-1  Both manifests parse and expose a hooks block.
#   AC-2  Each manifest yields >=1 command-script path (sanity — derivation works).
#   AC-3  Manifest parity: settings.json and hooks.json wire the IDENTICAL normalized script
#         set (no project/plugin drift — a hook added to one but not the other is a bug).
#   AC-4  Every command-script (union of both manifests) is git-tracked.
#   AC-5  Every command-script has git mode 100755 (the EACCES guard). [core]
#   AC-6  Every command-script exists on disk and starts with a shebang.
#
# Run: bash .claude/scripts/tests/test-hook-scripts-executable.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
cd "$REPO_ROOT" || { echo "[test-hook-scripts-executable] FAIL: cannot cd to repo root"; exit 1; }

SETTINGS=".claude/settings.json"
HOOKS_JSON=".claude/hooks/hooks.json"

PASS=0
FAIL=0
ok()  { echo "  PASS: $1"; PASS=$((PASS + 1)); }
bad() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

command -v python3 >/dev/null 2>&1 || { echo "[test-hook-scripts-executable] SKIP: python3 not found"; exit 0; }
command -v git     >/dev/null 2>&1 || { echo "[test-hook-scripts-executable] SKIP: git not found"; exit 0; }
[ -f "$SETTINGS" ]   || { echo "[test-hook-scripts-executable] FAIL: missing $SETTINGS"; exit 1; }
[ -f "$HOOKS_JSON" ] || { echo "[test-hook-scripts-executable] FAIL: missing $HOOKS_JSON"; exit 1; }

# extract_scripts <manifest> → prints normalized ".claude/..." command-script paths, one per line.
# Normalizes "${CLAUDE_PLUGIN_ROOT}/.claude/..." and "./.claude/..." down to ".claude/...".
# On parse failure prints a single "__PARSE_ERROR__:<msg>" line (and nothing else).
extract_scripts() {
  python3 - "$1" <<'PYEOF'
import json, sys
try:
    d = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception as e:  # noqa: BLE001 — surface parse failure to the caller as a sentinel line
    print("__PARSE_ERROR__:%s" % e)
    sys.exit(0)

def norm(c):
    # Strip a leading ${CLAUDE_PLUGIN_ROOT}/ (plugin manifest) and any ./ prefix, then anchor
    # at the first ".claude/" segment so both manifests collapse to the same repo-relative form.
    i = c.find(".claude/")
    return c[i:] if i != -1 else c

seen = set()
def walk(o):
    if isinstance(o, dict):
        if o.get("type") == "command" and isinstance(o.get("command"), str):
            c = o["command"]
            if c.endswith(".sh") and ".claude/" in c:
                seen.add(norm(c))
        for v in o.values():
            walk(v)
    elif isinstance(o, list):
        for v in o:
            walk(v)
walk(d.get("hooks", d))
for c in sorted(seen):
    print(c)
PYEOF
}

mapfile -t SET_SETTINGS < <(extract_scripts "$SETTINGS")
mapfile -t SET_HOOKS    < <(extract_scripts "$HOOKS_JSON")

parse_ok=1
for label in SETTINGS HOOKS; do
  declare -n arr="SET_${label}"
  if [ "${#arr[@]}" -ge 1 ] && [[ "${arr[0]}" != __PARSE_ERROR__* ]]; then
    ok "parsed manifest ($label): ${#arr[@]} command-script(s)"
  else
    bad "manifest parse failed ($label): ${arr[*]:-<empty>}"
    parse_ok=0
  fi
done

# AC-3 — manifest parity (normalized sets identical)
if [ "$parse_ok" -eq 1 ]; then
  settings_sorted="$(printf '%s\n' "${SET_SETTINGS[@]}" | sort -u)"
  hooks_sorted="$(printf '%s\n' "${SET_HOOKS[@]}" | sort -u)"
  if [ "$settings_sorted" = "$hooks_sorted" ]; then
    ok "manifest parity: settings.json and hooks.json wire the identical script set"
  else
    bad "manifest DRIFT between settings.json and hooks.json:"
    diff <(printf '%s\n' "$settings_sorted") <(printf '%s\n' "$hooks_sorted") | sed 's/^/      /'
  fi
fi

# Union of both manifests = the full spawn surface to validate.
mapfile -t UNION < <(printf '%s\n' "${SET_SETTINGS[@]}" "${SET_HOOKS[@]}" | grep -v '^__PARSE_ERROR__' | sort -u)

# Build the git index mode map for EXACTLY the discovered scripts (no glob under-reach).
# Guard the empty case (parse failure already FAILed above) to stay safe under set -u and to
# avoid a bare `git ls-files --` listing every tracked file.
declare -A GIT_MODE
if [ "${#UNION[@]}" -ge 1 ]; then
  while read -r mode _sha _stage path; do
    [ -n "$path" ] && GIT_MODE["$path"]="$mode"
  done < <(git ls-files -s -- "${UNION[@]}" 2>/dev/null)
fi

# AC-4 / AC-5 / AC-6 — per-script checks over the union
for sc in "${UNION[@]}"; do
  mode="${GIT_MODE[$sc]:-}"

  # AC-4 — tracked
  if [ -n "$mode" ]; then
    ok "tracked: $sc"
  else
    bad "NOT git-tracked (cannot ship +x via plugin): $sc"
    continue
  fi

  # AC-5 — git mode 100755 (core EACCES guard)
  if [ "$mode" = "100755" ]; then
    ok "git mode 100755 (executable): $sc"
  else
    bad "git mode $mode (NOT executable → EACCES posix_spawn in plugin): $sc — fix: git update-index --chmod=+x $sc"
  fi

  # AC-6 — exists + shebang
  if [ -f "$sc" ] && head -1 "$sc" | grep -q '^#!'; then
    ok "exists + shebang: $sc"
  else
    bad "missing file or no shebang (direct exec would fail): $sc"
  fi
done

echo
echo "[test-hook-scripts-executable] ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
