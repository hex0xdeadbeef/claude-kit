#!/usr/bin/env bash
# test-claude-md-audit-postcondition.sh
# Asserts CLAUDE.md hard invariants post-audit.
# Convention: exit 0 on success, exit 1 on assertion failure.
# Stderr format: [test-claude-md-audit-postcondition] LABEL: message

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
CLAUDE_MD="${REPO_ROOT}/CLAUDE.md"

if [[ ! -f "${CLAUDE_MD}" ]]; then
  echo "[test-claude-md-audit-postcondition] FAIL: CLAUDE.md not found at ${CLAUDE_MD}" >&2
  exit 1
fi

FAIL=0
fail() { echo "[test-claude-md-audit-postcondition] FAIL: $*" >&2; FAIL=1; }
pass() { echo "[test-claude-md-audit-postcondition] PASS: $*"; }

# ─── Line-count constraint (Claude Code docs: target <200; spec AC3 floor >130) ─
# Floor 131 (strict-greater-than 130) = Balanced tier per spec.approach.
# Ceiling 199 (strict-less-than 200) = Claude Code docs guidance.
LINE_COUNT=$(wc -l < "${CLAUDE_MD}" | tr -d ' ')
if [[ "${LINE_COUNT}" -ge 200 ]]; then
  fail "line count ${LINE_COUNT} >= 200 (Claude Code docs target: under 200)"
fi
if [[ "${LINE_COUNT}" -le 130 ]]; then
  fail "line count ${LINE_COUNT} <= 130 (Balanced tier floor — spec AC3 requires strictly above 130 to preserve load-bearing content)"
fi

# ─── validate-instructions.sh P0-01 + P1-03 hard checks ─────────────────────────
EXPECTED_LITERALS=(
  "2.1.113"                # P0-01: version floor
  "Prompt Cache Policy"    # P1-03: cache policy section heading
)
for s in "${EXPECTED_LITERALS[@]}"; do
  if ! grep -qF -e "${s}" "${CLAUDE_MD}"; then
    fail "missing required literal: ${s} (consumed by validate-instructions.sh)"
  fi
done

# ─── Required H2 headings (load-bearing or referenced by other artifacts) ────────
EXPECTED_H2=(
  "## Language Profile"
  "## Soft Prerequisites"
  "## TDD Policy"
  "## Prompt Cache Policy"
  "## Caveman Token Compression Policy"
  "## Error Handling"
  "## Rules"
  "## Enforcement"
  "## Conventions"
)
for h in "${EXPECTED_H2[@]}"; do
  if ! grep -qF -e "${h}" "${CLAUDE_MD}"; then
    fail "missing required H2 heading: ${h}"
  fi
done

# ─── Cascade vocabulary (consumed by coder.md/workflow.md/code-reviewer.md) ─────
EXPECTED_CASCADE_TERMS=(
  "PROJECT-KNOWLEDGE.md"
  "Language Profile"
)
for t in "${EXPECTED_CASCADE_TERMS[@]}"; do
  if ! grep -qF -e "${t}" "${CLAUDE_MD}"; then
    fail "missing cascade vocabulary term: ${t}"
  fi
done

# ─── Caveman boundary marker (at least one of the verbatim sentinels) ────────────
if ! grep -qE 'VERDICT_JSON|\$handoff_contract|\$verdict_contract' "${CLAUDE_MD}"; then
  fail "Caveman boundaries summary missing — none of VERDICT_JSON / \$handoff_contract / \$verdict_contract found"
fi

# ─── Bare PROJECT-KNOWLEDGE.md path forbidden — defer to canonical hook ─────────
# Avoid bash-regex divergence from canonical Perl lookbehind by invoking
# the canonical .claude/agents/meta-agent/scripts/check-references.sh hook directly.
HOOK_STDIN=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "${CLAUDE_MD}")
HOOK_OUT=$(echo "${HOOK_STDIN}" | bash "${REPO_ROOT}/.claude/agents/meta-agent/scripts/check-references.sh" 2>/dev/null || true)
if echo "${HOOK_OUT}" | grep -q "PK_PATH:"; then
  fail "bare PROJECT-KNOWLEDGE.md reference detected by canonical check-references.sh hook"
  echo "${HOOK_OUT}" | sed 's/^/    /' >&2
fi

if [[ "${FAIL}" -eq 0 ]]; then
  pass "all invariants satisfied (line count ${LINE_COUNT}, headings, literals, cascade, caveman, path)"
  exit 0
fi
exit 1
