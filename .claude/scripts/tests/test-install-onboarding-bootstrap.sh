#!/usr/bin/env bash
# test-install-onboarding-bootstrap.sh — tests for install.sh onboarding bootstrap.
# Key-level MERGE (user wins) for settings.local.json + .mcp.json via _merge_json_into,
# plus warn_missing_mcp_runtimes (AG-3) and main() wiring + .gitignore (static greps).
# All tests use SMALL synthetic JSON fixtures (deterministic), not the real .example.
# Usage: bash .claude/scripts/tests/test-install-onboarding-bootstrap.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
INSTALL_SH="${REPO_ROOT}/install.sh"

# shellcheck disable=SC1090
source "${INSTALL_SH}"

TMP_ROOT="$(mktemp -d -t install-onboarding-tests.XXXXXX)"
trap 'chmod -R u+w "${TMP_ROOT}" 2>/dev/null; rm -rf "${TMP_ROOT}"' EXIT

PASS=0
FAIL=0

assert_eq()       { if [ "$2" = "$3" ]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (expected=[$2] actual=[$3])"; FAIL=$((FAIL+1)); fi; }
assert_file_exists() { if [ -e "$2" ]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 ($2 missing)"; FAIL=$((FAIL+1)); fi; }
assert_no_file()  { if [ ! -e "$2" ]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 ($2 unexpectedly present)"; FAIL=$((FAIL+1)); fi; }
assert_grep()     { if grep -Fq -- "$2" "$3" 2>/dev/null; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (pattern [$2] not in $3)"; FAIL=$((FAIL+1)); fi; }
assert_no_grep()  { if grep -Fq -- "$2" "$3" 2>/dev/null; then echo "  FAIL: $1 (pattern [$2] unexpectedly in $3)"; FAIL=$((FAIL+1)); else echo "  PASS: $1"; PASS=$((PASS+1)); fi; }
assert_grep_str() { if printf '%s\n' "$3" | grep -Fq -- "$2"; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (pattern [$2] not in capture)"; FAIL=$((FAIL+1)); fi; }

# ════════════════════════ settings.local.json (bootstrap_settings_local) ═══════════
echo "T1: create-from-absent → full .example copied (incl _ doc keys)"
FIX="${TMP_ROOT}/t1"; mkdir -p "$FIX/.claude"
printf '{"a": 1, "_doc": "x"}\n' > "$FIX/.claude/settings.local.json.example"
out=$(bootstrap_settings_local "$FIX")
assert_eq "T1.result" "result=created" "$out"
assert_file_exists "T1.file" "$FIX/.claude/settings.local.json"
assert_eq "T1.byte-identical-to-example" \
    "$(cat "$FIX/.claude/settings.local.json.example")" \
    "$(cat "$FIX/.claude/settings.local.json")"

echo "T2: merge adds a new active (non-_) key; user value kept"
FIX="${TMP_ROOT}/t2"; mkdir -p "$FIX/.claude"
printf '{"a": 1, "b": 2}\n' > "$FIX/.claude/settings.local.json.example"
printf '{"a": 1}\n'         > "$FIX/.claude/settings.local.json"
out=$(bootstrap_settings_local "$FIX")
assert_eq "T2.result" "result=merged" "$out"
assert_grep "T2.added-b" '"b"' "$FIX/.claude/settings.local.json"

echo "T3: merge — USER WINS on a shared key conflict"
FIX="${TMP_ROOT}/t3"; mkdir -p "$FIX/.claude"
printf '{"a": 1, "new": 7}\n' > "$FIX/.claude/settings.local.json.example"
printf '{"a": 99}\n'          > "$FIX/.claude/settings.local.json"
out=$(bootstrap_settings_local "$FIX")
assert_eq "T3.result" "result=merged" "$out"
assert_grep "T3.user-wins-a99" '99' "$FIX/.claude/settings.local.json"
assert_grep "T3.added-new" '"new"' "$FIX/.claude/settings.local.json"

echo "T4: merge skips example-only _ sibling key; user's own _ key preserved"
FIX="${TMP_ROOT}/t4"; mkdir -p "$FIX/.claude"
printf '{"a": 1, "_doc": "x"}\n'         > "$FIX/.claude/settings.local.json.example"
printf '{"b": 5, "_keep": "mine"}\n'     > "$FIX/.claude/settings.local.json"
out=$(bootstrap_settings_local "$FIX")
assert_eq "T4.result" "result=merged" "$out"
assert_grep    "T4.added-a"     '"a"'     "$FIX/.claude/settings.local.json"
assert_no_grep "T4.skip-_doc"   '_doc'    "$FIX/.claude/settings.local.json"
assert_grep    "T4.keep-_keep"  '_keep'   "$FIX/.claude/settings.local.json"
assert_grep    "T4.keep-b"      '"b"'     "$FIX/.claude/settings.local.json"

echo "T5: merge idempotent — 2nd run unchanged + byte-identical"
# Reuse T2 fixture (already merged → {a,b}); re-run.
before="$(cat "$FIX/.claude/settings.local.json")"  # note: $FIX still t4; switch to a fresh merged file
FIX="${TMP_ROOT}/t5"; mkdir -p "$FIX/.claude"
printf '{"a": 1, "b": 2}\n' > "$FIX/.claude/settings.local.json.example"
printf '{"a": 1}\n'         > "$FIX/.claude/settings.local.json"
bootstrap_settings_local "$FIX" >/dev/null            # 1st merge → writes {a,b}
after1="$(cat "$FIX/.claude/settings.local.json")"
out=$(bootstrap_settings_local "$FIX")                # 2nd run
assert_eq "T5.result-unchanged" "result=unchanged" "$out"
assert_eq "T5.byte-identical" "$after1" "$(cat "$FIX/.claude/settings.local.json")"

echo "T6: superset + non-2-space indent → unchanged AND byte-identical (no reformat, PR-002)"
FIX="${TMP_ROOT}/t6"; mkdir -p "$FIX/.claude"
printf '{"a": 1, "_doc": "d"}\n' > "$FIX/.claude/settings.local.json.example"
# user has ALL non-_ example keys (a) + an extra key, 4-space indent:
printf '{\n    "a": 1,\n    "extra": 9\n}\n' > "$FIX/.claude/settings.local.json"
before="$(cat "$FIX/.claude/settings.local.json")"
out=$(bootstrap_settings_local "$FIX")
assert_eq "T6.result-unchanged" "result=unchanged" "$out"
assert_eq "T6.no-reformat-byte-identical" "$before" "$(cat "$FIX/.claude/settings.local.json")"

echo "T7: malformed user JSON → left untouched + result=skipped (non-destructive)"
FIX="${TMP_ROOT}/t7"; mkdir -p "$FIX/.claude"
printf '{"a": 1, "b": 2}\n'  > "$FIX/.claude/settings.local.json.example"
printf '{invalid json\n'      > "$FIX/.claude/settings.local.json"
before="$(cat "$FIX/.claude/settings.local.json")"
out=$(bootstrap_settings_local "$FIX")
assert_eq "T7.result-skipped" "result=skipped" "$out"
assert_eq "T7.untouched" "$before" "$(cat "$FIX/.claude/settings.local.json")"

echo "T8: no .example → result=no-example; no file created"
FIX="${TMP_ROOT}/t8"; mkdir -p "$FIX/.claude"
out=$(bootstrap_settings_local "$FIX")
assert_eq "T8.result" "result=no-example" "$out"
assert_no_file "T8.no-file" "$FIX/.claude/settings.local.json"

echo "T9: degradation — _merge_json_into unavailable → existing file skipped (untouched)"
# Deterministically exercise the degradation BRANCH by overriding the helper to fail,
# rather than stripping PATH (which would also remove cp/mv). Mirrors python3-absent.
FIX="${TMP_ROOT}/t9"; mkdir -p "$FIX/.claude"
printf '{"a": 1, "b": 2}\n'  > "$FIX/.claude/settings.local.json.example"
printf '{"a": 1}\n'           > "$FIX/.claude/settings.local.json"
before="$(cat "$FIX/.claude/settings.local.json")"
( _merge_json_into() { return 3; }
  out=$(bootstrap_settings_local "$FIX")
  assert_eq "T9.result-skipped" "result=skipped" "$out"
  assert_eq "T9.untouched" "$before" "$(cat "$FIX/.claude/settings.local.json")"
  echo "$PASS $FAIL" > "${TMP_ROOT}/t9.counts" )
read -r PASS FAIL < "${TMP_ROOT}/t9.counts"
# absent file + degraded helper → create path (cp) still works, no merge needed:
FIX="${TMP_ROOT}/t9b"; mkdir -p "$FIX/.claude"
printf '{"a": 1}\n' > "$FIX/.claude/settings.local.json.example"
( _merge_json_into() { return 3; }
  out=$(bootstrap_settings_local "$FIX")
  assert_eq "T9b.created-without-merge" "result=created" "$out"
  echo "$PASS $FAIL" > "${TMP_ROOT}/t9b.counts" )
read -r PASS FAIL < "${TMP_ROOT}/t9b.counts"

echo "T10: write-error → exit 2, target untouched (PR-003)"
if [ "$(id -u)" -eq 0 ]; then
    echo "  SKIP: T10 — running as root (bypasses 0555 perms)"
else
    FIX="${TMP_ROOT}/t10"; mkdir -p "$FIX/rodir"
    printf '{"a": 1, "b": 2}\n' > "${TMP_ROOT}/t10-example.json"
    printf '{"a": 1}\n'          > "$FIX/rodir/target.json"   # user lacks b → merge will try to write
    before="$(cat "$FIX/rodir/target.json")"
    chmod 0555 "$FIX/rodir"
    rc=0
    _merge_json_into "${TMP_ROOT}/t10-example.json" "$FIX/rodir/target.json" >/dev/null 2>&1 || rc=$?
    chmod 0755 "$FIX/rodir"
    assert_eq "T10.exit2" "2" "$rc"
    assert_eq "T10.untouched" "$before" "$(cat "$FIX/rodir/target.json")"
fi

# ════════════════════════ .mcp.json (provision_mcp_config) ═════════════════════════
echo "T11: mcp create-from-absent → example delivered + .mcp.json created"
FIX="${TMP_ROOT}/t11"; mkdir -p "$FIX/src" "$FIX/target"
printf '{"mcpServers": {"s1": {"cmd": "x"}}}\n' > "$FIX/src/.mcp.json.example"
out=$(provision_mcp_config "$FIX/src" "$FIX/target")
assert_eq "T11.result" "example_copied=1 result=created" "$out"
assert_file_exists "T11.example" "$FIX/target/.mcp.json.example"
assert_file_exists "T11.mcp" "$FIX/target/.mcp.json"

echo "T12: mcp merge — NEW server added with its docs; existing server's _ docs skipped; user wins (PR-001)"
FIX="${TMP_ROOT}/t12"; mkdir -p "$FIX/src" "$FIX/target"
printf '{"mcpServers": {"s1": {"cmd": "x", "_note": "d1"}, "s2": {"cmd": "y", "_note": "d2"}}}\n' > "$FIX/src/.mcp.json.example"
printf '{"mcpServers": {"s1": {"cmd": "x", "custom": 1}}}\n' > "$FIX/target/.mcp.json"
out=$(provision_mcp_config "$FIX/src" "$FIX/target")
assert_eq "T12.result" "example_copied=1 result=merged" "$out"
assert_grep    "T12.new-server-s2"        '"s2"'    "$FIX/target/.mcp.json"
assert_grep    "T12.new-server-docs-ride" 'd2'      "$FIX/target/.mcp.json"   # s2._note added (created content)
assert_no_grep "T12.existing-docs-skipped" 'd1'     "$FIX/target/.mcp.json"   # s1._note NOT injected (curated)
assert_grep    "T12.user-server-preserved" 'custom' "$FIX/target/.mcp.json"   # user wins

echo "T13: mcp example refreshed from src every run"
FIX="${TMP_ROOT}/t13"; mkdir -p "$FIX/src" "$FIX/target"
printf '{"mcpServers": {"OLD": {}}}\n' > "$FIX/target/.mcp.json.example"
printf '{"mcpServers": {"NEW": {}}}\n' > "$FIX/src/.mcp.json.example"
printf '{"mcpServers": {"keep": {}}}\n' > "$FIX/target/.mcp.json"   # present → not clobbered
out=$(provision_mcp_config "$FIX/src" "$FIX/target")
assert_grep "T13.example-refreshed" "NEW" "$FIX/target/.mcp.json.example"

# ════════════════════════ AG-3 + wiring ════════════════════════════════════════════
echo "T14: warn_missing_mcp_runtimes — both absent → missing=2 + warns on stderr"
if env -i PATH="/nonexistent" /bin/bash -c 'command -v npx >/dev/null 2>&1 || command -v uvx >/dev/null 2>&1'; then
    echo "  SKIP: T14 — npx/uvx still reachable inside env -i"
else
    t14_out=$(env -i PATH="/nonexistent" /bin/bash -c "source '${INSTALL_SH}'; warn_missing_mcp_runtimes" 2>/dev/null)
    t14_err=$(env -i PATH="/nonexistent" /bin/bash -c "source '${INSTALL_SH}'; warn_missing_mcp_runtimes" 2>&1 >/dev/null)
    assert_eq "T14.missing2" "missing=2" "$t14_out"
    assert_grep_str "T14.warn-npx" "npx" "$t14_err"
    assert_grep_str "T14.warn-uvx" "uvx" "$t14_err"
fi

echo "T15: main() wires bootstrap_settings_local"
assert_grep "T15.wired" 'bootstrap_settings_local "$target_dir"' "$INSTALL_SH"
echo "T16: main() wires provision_mcp_config"
assert_grep "T16.wired" 'provision_mcp_config "$src_dir" "$target_dir"' "$INSTALL_SH"
echo "T17: AG-1 — .mcp.json in managed .gitignore"
assert_grep "T17.gitignore" ".mcp.json" "${REPO_ROOT}/.gitignore"

echo ""
echo "Total: PASS=${PASS} FAIL=${FAIL}"
[ "$FAIL" -eq 0 ]
