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
#   - component-path SHAPES match the schemastore manifest schema (agents=./*.md files,
#     not a ./dir/) — the install-time constraint that `claude plugin validate` does NOT enforce
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
chk.append(("manifest agents→4 explicit .md files", m.get("agents") == [
    "./.claude/agents/code-researcher.md",
    "./.claude/agents/code-reviewer.md",
    "./.claude/agents/plan-reviewer.md",
    "./.claude/agents/verdict-recovery.md",
]))
chk.append(("manifest skills→./.claude/skills/", m.get("skills") == "./.claude/skills/"))
chk.append(("manifest hooks→./.claude/hooks/hooks.json", m.get("hooks") == "./.claude/hooks/hooks.json"))
chk.append(("manifest mcpServers→./.mcp.json", m.get("mcpServers") == "./.mcp.json"))
for name, passed in chk:
    print(f"{'PASS' if passed else 'FAIL'}|{name}")
PYEOF
)

# ── Manifest component-path SHAPES match the plugin-manifest JSON Schema ──────
# Regression guard for the v1.35.0 install failure ("agents: Invalid input").
# The schemastore manifest schema requires every `agents` entry to match BOTH
# ^\./.*  AND  .*\.md$ — a directory path like "./.claude/agents/" is REJECTED at
# install time (unlike `commands`, whose schema also accepts a bare ./dir/).
# `claude plugin validate --strict` does NOT enforce these path patterns, so the
# kit's suite encodes them here. Each referenced path must also exist on disk.
while IFS='|' read -r st nm; do
    [ "$st" = "PASS" ] && ok "$nm" || bad "$nm"
done < <(python3 - "$MANIFEST" "$REPO_ROOT" <<'PYEOF'
import json, os, re, sys
m = json.load(open(sys.argv[1]))
root = sys.argv[2]
chk = []

def aslist(v):
    if v is None: return []
    return v if isinstance(v, list) else [v]
def strs(v):
    return [x for x in aslist(v) if isinstance(x, str)]
def exists(rel):
    return os.path.exists(os.path.join(root, rel[2:] if rel.startswith("./") else rel))

REL = re.compile(r"^\./.*")     # schema: ^\.\/.*
MD  = re.compile(r".*\.md$")    # schema: .*\.md$  (agents only)
JSN = re.compile(r".*\.json$")  # schema: .*\.json$ (hooks, mcpServers file form)

# agents: every entry MUST be ./*.md AND exist (the constraint that broke install)
agents = strs(m.get("agents"))
chk.append(("agents is a non-empty list of strings", len(agents) > 0))
for a in agents:
    chk.append((f"agents entry shape ^./*.md: {a}", bool(REL.match(a) and MD.match(a))))
    chk.append((f"agents file exists: {a}", exists(a)))

# commands: ^\./.* (dir OR .md both allowed by schema) AND exist
for c in strs(m.get("commands")):
    chk.append((f"commands entry shape ^./*: {c}", bool(REL.match(c))))
    chk.append((f"commands path exists: {c}", exists(c)))

# skills: ^\./.* AND exist
for s in strs(m.get("skills")):
    chk.append((f"skills entry shape ^./*: {s}", bool(REL.match(s))))
    chk.append((f"skills path exists: {s}", exists(s)))

# hooks (file form): ^\./.* AND .json$ AND exist  (object form is valid too — skip)
for h in strs(m.get("hooks")):
    chk.append((f"hooks entry shape ^./*.json: {h}", bool(REL.match(h) and JSN.match(h))))
    chk.append((f"hooks file exists: {h}", exists(h)))

# mcpServers (local file form): ^\./.* AND .json$ AND exist  (object/URL form valid — skip)
for mc in strs(m.get("mcpServers")):
    if mc.startswith("http"):
        continue
    chk.append((f"mcpServers entry shape ^./*.json: {mc}", bool(REL.match(mc) and JSN.match(mc))))
    chk.append((f"mcpServers file exists: {mc}", exists(mc)))

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
sk, s_cmd, s_prompt, _, s_prompts = collect(sys.argv[2])

# Counts DERIVE from settings.json (no hardcoded numbers) — robust to future hook additions.
# The deep-equal assertion below (after prefix-strip) is the strong structural guarantee.
chk = []
chk.append((f"hooks.json events == settings.json ({len(hk)} vs {len(sk)})", len(hk) == len(sk)))
chk.append((f"hooks.json command count == settings.json ({h_cmd} vs {s_cmd})", h_cmd == s_cmd))
chk.append((f"hooks.json prompt count == settings.json ({h_prompt} vs {s_prompt})", h_prompt == s_prompt))
chk.append((f"all command paths are ${{CLAUDE_PLUGIN_ROOT}}-prefixed (unprefixed: {h_unpref})", len(h_unpref) == 0))
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
