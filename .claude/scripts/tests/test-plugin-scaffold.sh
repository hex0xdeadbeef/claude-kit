#!/usr/bin/env bash
# test-plugin-scaffold.sh — Part 1 of the plugin-equivalence roadmap.
# Asserts the native-plugin SCAFFOLD is valid and loadable WITHOUT moving the .claude/ tree:
#   - .claude-plugin/plugin.json   : valid manifest, name=claude-kit, components → ./.claude/... + ./.mcp.json
#   - .claude-plugin/marketplace.json : valid single-repo marketplace listing the plugin (source ./)
#   - .claude/hooks/hooks.json     : converted from settings.json — 16 events, 44 command (all
#                                    ${CLAUDE_PLUGIN_ROOT}-prefixed across both script prefixes) + 2 prompt
#                                    (parsed-equal to settings.json) = 46 entries
#   - git-tracked                  : the 3 plugin files MUST be tracked (global gitignore ignores .claude/)
#   - claude plugin validate --strict exits 0 (skipped gracefully if the claude CLI is absent)
# Run: bash .claude/scripts/tests/test-plugin-scaffold.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
cd "$REPO_ROOT" || { echo "FAIL: cannot cd to repo root"; exit 1; }

MANIFEST=".claude-plugin/plugin.json"
MARKET=".claude-plugin/marketplace.json"
HOOKS=".claude/hooks/hooks.json"
SETTINGS=".claude/settings.json"

PASS=0
FAIL=0
ok()  { echo "  PASS: $1"; PASS=$((PASS + 1)); }
bad() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

command -v python3 >/dev/null 2>&1 || { echo "SKIP: python3 not found (required to parse JSON)"; exit 0; }

# ── Files exist ──────────────────────────────────────────────────────────────
for f in "$MANIFEST" "$MARKET" "$HOOKS"; do
    [ -f "$f" ] && ok "exists: $f" || bad "missing: $f"
done

# ── Valid JSON ───────────────────────────────────────────────────────────────
for f in "$MANIFEST" "$MARKET" "$HOOKS"; do
    if python3 -m json.tool "$f" >/dev/null 2>&1; then ok "valid JSON: $f"; else bad "invalid JSON: $f"; fi
done

# ── Manifest: name + component paths point at the existing ./.claude/ tree ────
while IFS='|' read -r st nm; do
    [ "$st" = "PASS" ] && ok "$nm" || bad "$nm"
done < <(python3 - "$MANIFEST" <<'PYEOF'
import json, sys
m = json.load(open(sys.argv[1]))
chk = []
chk.append(("manifest name==claude-kit", m.get("name") == "claude-kit"))
chk.append(("manifest commands→./.claude/commands/", m.get("commands") == ["./.claude/commands/"]))
chk.append(("manifest agents→./.claude/agents/", m.get("agents") == ["./.claude/agents/"]))
chk.append(("manifest skills→./.claude/skills/", m.get("skills") == "./.claude/skills/"))
chk.append(("manifest hooks→./.claude/hooks/hooks.json", m.get("hooks") == "./.claude/hooks/hooks.json"))
chk.append(("manifest mcpServers→./.mcp.json", m.get("mcpServers") == "./.mcp.json"))
for name, passed in chk:
    print(f"{'PASS' if passed else 'FAIL'}|{name}")
PYEOF
)

# ── Marketplace: required fields + single plugin with source ./ ───────────────
while IFS='|' read -r st nm; do
    [ "$st" = "PASS" ] && ok "$nm" || bad "$nm"
done < <(python3 - "$MARKET" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
chk = []
chk.append(("marketplace has name", bool(d.get("name"))))
chk.append(("marketplace owner.name set", bool(d.get("owner", {}).get("name"))))
plugins = d.get("plugins", [])
chk.append(("marketplace lists exactly 1 plugin", len(plugins) == 1))
p = plugins[0] if plugins else {}
chk.append(("plugin entry name==claude-kit", p.get("name") == "claude-kit"))
chk.append(("plugin entry source==./", p.get("source") == "./"))
for name, passed in chk:
    print(f"{'PASS' if passed else 'FAIL'}|{name}")
PYEOF
)

# ── hooks.json: 16 events / 44 command (all prefixed, both prefixes) / 2 prompt ─
while IFS='|' read -r st nm; do
    [ "$st" = "PASS" ] && ok "$nm" || bad "$nm"
done < <(python3 - "$HOOKS" "$SETTINGS" <<'PYEOF'
import json, sys
def collect(path):
    d = json.load(open(path))
    h = d.get("hooks", d)
    cmd, prompt, unprefixed, prompts = 0, 0, [], []
    for ev, groups in h.items():
        for g in groups:
            for x in g.get("hooks", []):
                t = x.get("type")
                if t == "command":
                    cmd += 1
                    if not x.get("command", "").startswith("${CLAUDE_PLUGIN_ROOT}/"):
                        unprefixed.append(x.get("command", ""))
                elif t == "prompt":
                    prompt += 1
                    prompts.append((ev, x))
    return h, cmd, prompt, unprefixed, prompts

hk, h_cmd, h_prompt, h_unpref, h_prompts = collect(sys.argv[1])
sk, _, _, _, s_prompts = collect(sys.argv[2])

chk = []
chk.append((f"hooks.json events==16 (got {len(hk)})", len(hk) == 16))
chk.append((f"hooks.json total entries==46 (got {h_cmd + h_prompt})", h_cmd + h_prompt == 46))
chk.append((f"hooks.json command hooks==44 (got {h_cmd})", h_cmd == 44))
chk.append((f"hooks.json prompt hooks==2 (got {h_prompt})", h_prompt == 2))
chk.append((f"all 44 command paths are ${{CLAUDE_PLUGIN_ROOT}}-prefixed (unprefixed: {h_unpref})", len(h_unpref) == 0))
# both script prefixes represented (.claude/scripts/ AND .claude/agents/meta-agent/scripts/)
allcmds = []
for ev, groups in hk.items():
    for g in groups:
        for x in g.get("hooks", []):
            if x.get("type") == "command":
                allcmds.append(x.get("command", ""))
has_scripts = any("/.claude/scripts/" in c for c in allcmds)
has_meta = any("/.claude/agents/meta-agent/scripts/" in c for c in allcmds)
chk.append(("command paths cover .claude/scripts/ prefix", has_scripts))
chk.append(("command paths cover .claude/agents/meta-agent/scripts/ prefix", has_meta))
# prompt hooks parsed-equal to settings.json (byte-stable contract — IMP / import-matrix enforcer)
chk.append(("2 prompt hooks parsed-equal to settings.json", h_prompts == s_prompts))
for name, passed in chk:
    print(f"{'PASS' if passed else 'FAIL'}|{name}")
PYEOF
)

# ── CR-001: command-hook DEEP fidelity — unprefix hooks.json == settings.json hooks (full structure) ──
# Self-guards future re-syncs: a dropped/reordered hook or altered matcher/if/args on ANY command
# hook is caught, not just count + prefix presence. (Prompt hooks already get full parity above.)
while IFS='|' read -r st nm; do
    [ "$st" = "PASS" ] && ok "$nm" || bad "$nm"
done < <(python3 - "$HOOKS" "$SETTINGS" <<'PYEOF'
import json, sys, copy
hk = json.load(open(sys.argv[1])).get("hooks", {})
sk = json.load(open(sys.argv[2])).get("hooks", {})
PREFIX = "${CLAUDE_PLUGIN_ROOT}/"
stripped = copy.deepcopy(hk)
for ev, groups in stripped.items():
    for g in groups:
        for x in g.get("hooks", []):
            if x.get("type") == "command":
                c = x.get("command", "")
                if c.startswith(PREFIX):
                    x["command"] = c[len(PREFIX):]
equal = stripped == sk
print(f"{'PASS' if equal else 'FAIL'}|hooks.json deep-equal to settings.json after ${{CLAUDE_PLUGIN_ROOT}}-strip (events/matchers/if/args/order all faithful)")
PYEOF
)

# ── Git tracking gate: the 3 plugin files MUST be tracked (global gitignore ignores .claude/) ──
if git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    for f in "$MANIFEST" "$MARKET" "$HOOKS"; do
        if git -C "$REPO_ROOT" ls-files --error-unmatch "$f" >/dev/null 2>&1; then
            ok "git-tracked: $f"
        else
            bad "NOT git-tracked (needs 'git add -f'): $f"
        fi
    done
else
    echo "  SKIP: not a git repo — tracking gate skipped"
fi

# ── claude plugin validate --strict (skipped gracefully if CLI absent) ─────────
if command -v claude >/dev/null 2>&1; then
    if claude plugin validate "$REPO_ROOT" --strict >/dev/null 2>&1; then
        ok "claude plugin validate --strict passes"
    else
        bad "claude plugin validate --strict failed"
    fi
else
    echo "  SKIP: claude CLI not found — plugin validate skipped"
fi

echo ""
echo "Total: PASS=${PASS} FAIL=${FAIL}"
[ "$FAIL" -eq 0 ]
