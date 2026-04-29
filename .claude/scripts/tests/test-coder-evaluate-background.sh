#!/usr/bin/env bash
# test-coder-evaluate-background.sh
# P1 — verify coder.md Phase 1.5 EVALUATE has background_mode subsection
# documenting CLAUDE_PARALLEL_EVALUATE flag and the async_integration_point pattern.
#
# Convention: exit 0 on success, exit 1 on assertion failure.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
FILE="${REPO_ROOT}/.claude/commands/coder.md"

if [[ ! -f "${FILE}" ]]; then
  echo "[test-coder-evaluate-background] FAIL: coder.md not found at ${FILE}" >&2
  exit 1
fi

# ---- Test 1: research_assist anchor still present (Phase 1.5 sub-block context) ----
if ! grep -q -e 'research_assist:' "${FILE}"; then
  echo "[test-coder-evaluate-background] FAIL: research_assist anchor missing" >&2
  exit 1
fi

# ---- Test 2: background_mode subsection present ----
if ! grep -q -e 'background_mode:' "${FILE}"; then
  echo "[test-coder-evaluate-background] FAIL: background_mode subsection missing in coder.md" >&2
  exit 1
fi

# ---- Test 3: env flag CLAUDE_PARALLEL_EVALUATE referenced ----
if ! grep -q -e 'CLAUDE_PARALLEL_EVALUATE=on' "${FILE}"; then
  echo "[test-coder-evaluate-background] FAIL: env flag CLAUDE_PARALLEL_EVALUATE=on mention missing" >&2
  exit 1
fi

# ---- Test 4: block-wait budget documented (5s for L, 10s for XL) ----
if ! grep -q -e '5 s for L' "${FILE}"; then
  echo "[test-coder-evaluate-background] FAIL: L block-wait budget not documented (expected '5 s for L')" >&2
  exit 1
fi
if ! grep -q -e '10 s for XL' "${FILE}"; then
  echo "[test-coder-evaluate-background] FAIL: XL block-wait budget not documented (expected '10 s for XL')" >&2
  exit 1
fi

# ---- Test 5: contract preservation note present ----
if ! grep -q -e 'coder_to_code_review handoff payload byte-identical' "${FILE}"; then
  echo "[test-coder-evaluate-background] FAIL: contract-preservation note missing" >&2
  exit 1
fi

# ---- Test 6: async_integration_point pattern present ----
if ! grep -q -e 'async_integration_point:' "${FILE}"; then
  echo "[test-coder-evaluate-background] FAIL: async_integration_point pattern missing" >&2
  exit 1
fi

# ---- Test 7: run_in_background: true documented in delegation_example ----
if ! grep -q -e 'run_in_background: true' "${FILE}"; then
  echo "[test-coder-evaluate-background] FAIL: run_in_background: true delegation example missing" >&2
  exit 1
fi

echo "[test-coder-evaluate-background] PASS"
exit 0
