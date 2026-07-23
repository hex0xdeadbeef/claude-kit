#!/usr/bin/env bash
# test-readme-info-preservation.sh
# Asserts ZERO information loss in README.md across the readme-refactor.
#
# Snapshot captured at evaluate time (2026-04-30) from README.md before rewrite.
# Any future intentional additions/removals (new env var, new URL, new section)
# require a deliberate update to the EXPECTED arrays below — that's the contract.
#
# Convention: exit 0 on success, exit 1 on assertion failure.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
README="${REPO_ROOT}/README.md"

if [[ ! -f "${README}" ]]; then
  echo "[test-readme-info-preservation] FAIL: README.md not found at ${README}" >&2
  exit 1
fi

FAIL=0
fail() { echo "[test-readme-info-preservation] FAIL: $*" >&2; FAIL=1; }

# ─── Expected H2 headers (10) — verbatim, emoji-prefix included ───────────────
EXPECTED_H2=(
  "## 📑 Table of Contents"
  "## ⚡ Quick Start"
  "## ⚙️ Configuration Files"
  "## 🔧 Commands"
  "## 🏗 Architecture"
  "## 🪨 Token Optimization (Caveman)"
  "## 🔌 MCP Servers"
  "## 📂 Project Structure"
  "## 🪝 Hooks"
  "## 📐 Conventions"
)
for h in "${EXPECTED_H2[@]}"; do
  if ! grep -qF -e "${h}" "${README}"; then
    fail "missing H2 header: ${h}"
  fi
done

# ─── Expected env-var names (13) — must all appear somewhere in README ────────
EXPECTED_ENV=(
  "CLAUDE_CAVEMAN_MODE"
  "CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING"
  "CLAUDE_DELTA_REVIEW_MODE"
  "CLAUDE_HANDOFF_VALIDATION_MODE"
  "CLAUDE_ISSUE_ID_VALIDATION_MODE"
  "CLAUDE_PK_PATH_MODE"
  "CLAUDE_PROJECT_KNOWLEDGE_MODE"
  "CLAUDE_VERDICT_VALIDATION_MODE"
  "ENABLE_PROMPT_CACHING_1H"
  "FORCE_PROMPT_CACHING_5M"
  "GIT_STRIP_CO_AUTHOR"
  "INSTALL_DIR"
  "KIT_VERSION"
)
for v in "${EXPECTED_ENV[@]}"; do
  if ! grep -qF -e "${v}" "${README}"; then
    fail "missing env-var name: ${v}"
  fi
done

# ─── Expected external URLs (6) — verbatim ────────────────────────────────────
EXPECTED_URLS=(
  "https://astral.sh/uv/install.sh"
  "https://docs.anthropic.com/en/docs/claude-code"
  "https://github.com/hex0xdeadbeef/claude-kit.git"
  "https://github.com/juliusbrussee/caveman"
  "https://img.shields.io/badge/Claude_Code-config_kit-5A45FF?style=flat-square"
  "https://raw.githubusercontent.com/hex0xdeadbeef/claude-kit/main/install.sh"
)
for u in "${EXPECTED_URLS[@]}"; do
  if ! grep -qF -e "${u}" "${README}"; then
    fail "missing external URL: ${u}"
  fi
done

# ─── Mermaid block count (4) ───────────────────────────────────────────────────
MERMAID_COUNT=$(grep -c '^```mermaid' "${README}")
if [[ "${MERMAID_COUNT}" -ne 4 ]]; then
  fail "expected 4 mermaid blocks, got ${MERMAID_COUNT}"
fi

# ─── Expected internal anchor refs (10) — captured pre-refactor ───────────────
# Regex \(#[^)]+\) tolerates an emoji prefix;
# explicit list below acts as defence-in-depth.
EXPECTED_ANCHORS=(
  "(#-architecture)"
  "(#-commands)"
  "(#️-configuration-files)"
  "(#-conventions)"
  "(#-hooks)"
  "(#-mcp-servers)"
  "(#-project-structure)"
  "(#-quick-start)"
  "(#-token-optimization-caveman)"
  "(#mcpjsonexample--mcp-server-endpoints)"
)
for a in "${EXPECTED_ANCHORS[@]}"; do
  if ! grep -qF -e "${a}" "${README}"; then
    fail "missing internal anchor reference: ${a}"
  fi
done

# ─── File-path references must include all canonical paths ─────────────────────
EXPECTED_PATHS=(
  ".claude/settings.json"
  ".claude/settings.local.json"
  ".claude/settings.local.json.example"
  ".mcp.json"
  ".mcp.json.example"
  ".claude/PROJECT-KNOWLEDGE.md"
  ".claude/.kit-version"
  "CLAUDE.md"
  ".claude/schemas/handoff.schema.json"
)
for p in "${EXPECTED_PATHS[@]}"; do
  if ! grep -qF -e "${p}" "${README}"; then
    fail "missing file-path reference: ${p}"
  fi
done

# ─── Required terms / sentinels that encode contract vocabulary ────────────────
EXPECTED_TERMS=(
  "VERDICT_JSON"
  "PROJECT-KNOWLEDGE.md"
  "Sequential Thinking"
  "code-researcher"
  "plan-reviewer"
  "code-reviewer"
  "verdict-recovery"
  "/workflow"
  "/planner"
  "/coder"
  "/designer"
  "/meta-agent"
  "/project-researcher"
  "/review-checklist"
  "tree_sitter"
  "context7"
  "sequential-thinking"
  "worktree"
  "sparsePaths"
  "IMP-01"
  "IMP-02"
  "IMP-03"
  "IMP-04"
  "IMP-05"
  "IMP-06"
)
for t in "${EXPECTED_TERMS[@]}"; do
  if ! grep -qF -e "${t}" "${README}"; then
    fail "missing required term: ${t}"
  fi
done

# ─── Detail blocks must remain syntactically balanced ──────────────────────────
DET_OPEN=$(grep -c '^<details>' "${README}")
DET_CLOSE=$(grep -c '^</details>' "${README}")
if [[ "${DET_OPEN}" -ne "${DET_CLOSE}" ]]; then
  fail "<details> blocks unbalanced: ${DET_OPEN} open vs ${DET_CLOSE} close"
fi
if [[ "${DET_OPEN}" -lt 5 ]]; then
  fail "expected at least 5 <details> blocks, got ${DET_OPEN}"
fi

if [[ "${FAIL}" -eq 0 ]]; then
  echo "[test-readme-info-preservation] PASS"
  exit 0
fi
exit 1
