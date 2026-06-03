#!/usr/bin/env bash
# test-mcp-tree-sitter-python.sh — assert the tree_sitter MCP server is NOT pinned to an
# exact python minor (python3.11), which forces a managed-CPython download on first launch
# (bug report v1.33.0: opaque "MCP error -32000: Connection closed"). The fix uses a version
# RANGE (>=3.10, matching the package's Requires-Python) + only-system to reuse an installed
# interpreter. Asserts .mcp.json AND .mcp.json.example carry the fix, stay byte-identical for
# tree_sitter, and that the npx servers are untouched (PR-001). Run: bash <this file>.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
MCP="${REPO_ROOT}/.mcp.json"
MCPE="${REPO_ROOT}/.mcp.json.example"

PASS=0
FAIL=0
ok() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
bad() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

command -v python3 >/dev/null 2>&1 || { echo "SKIP: python3 not found (required to parse JSON)"; exit 0; }

# ── Valid JSON ──────────────────────────────────────────────────────────────────
for f in "$MCP" "$MCPE"; do
    if python3 -m json.tool "$f" >/dev/null 2>&1; then ok "valid JSON: $(basename "$f")"; else bad "valid JSON: $(basename "$f")"; fi
done

# ── Per-file tree_sitter + server-set assertions (via python) ─────────────────────
check_file() {
    python3 - "$1" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
srv = d.get("mcpServers", {})
ts = srv.get("tree_sitter", {})
args = ts.get("args", [])
out = []
out.append(("command-uvx", ts.get("command") == "uvx"))
out.append(("args-version-range>=3.10", ">=3.10" in args))
out.append(("args-python-preference-flag", "--python-preference" in args))
out.append(("args-only-system", "only-system" in args))
out.append(("args-server-pkg", "mcp-server-tree-sitter" in args))
out.append(("args-no-python3.11", "python3.11" not in args))
# PR-001: server set unchanged (exactly the 3 kit servers; npx ones untouched)
out.append(("exactly-3-servers", sorted(srv.keys()) == ["context7", "sequential-thinking", "tree_sitter"]))
out.append(("context7-command-npx", srv.get("context7", {}).get("command") == "npx"))
out.append(("sequential-thinking-command-npx", srv.get("sequential-thinking", {}).get("command") == "npx"))
for name, passed in out:
    print(f"{'PASS' if passed else 'FAIL'}|{name}")
PYEOF
}

while IFS='|' read -r st nm; do
    [ "$st" = "PASS" ] && ok ".mcp.json: $nm" || bad ".mcp.json: $nm"
done < <(check_file "$MCP")

while IFS='|' read -r st nm; do
    [ "$st" = "PASS" ] && ok ".mcp.json.example: $nm" || bad ".mcp.json.example: $nm"
done < <(check_file "$MCPE")

# ── tree_sitter args byte-identical between live file and template (drift guard) ──
args_of() { python3 -c "import json,sys; print(json.dumps(json.load(open(sys.argv[1]))['mcpServers']['tree_sitter']['args']))" "$1" 2>/dev/null; }
if [ "$(args_of "$MCP")" = "$(args_of "$MCPE")" ] && [ -n "$(args_of "$MCP")" ]; then
    ok "tree_sitter args byte-identical (.mcp.json == .mcp.json.example)"
else
    bad "tree_sitter args byte-identical (.mcp.json == .mcp.json.example)"
fi

# ── Doc references match the new args (no stale python3.11 in docs) ───────────────
for doc in "${REPO_ROOT}/CLAUDE.md" "${REPO_ROOT}/README.md"; do
    if grep -Fq 'python3.11' "$doc" 2>/dev/null; then bad "no python3.11 ref in $(basename "$doc")"; else ok "no python3.11 ref in $(basename "$doc")"; fi
done

echo ""
echo "Total: PASS=${PASS} FAIL=${FAIL}"
[ "$FAIL" -eq 0 ]
