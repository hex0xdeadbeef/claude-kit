#!/usr/bin/env bash
# test-coder-parallel-debug-dispatch.sh
# P2 — verify coder.md Phase 3 has parallel_debug_dispatch subsection AND that
# parallel-dispatch.md Use Case 2 is flipped from FUTURE PATTERN to ACTIVATION CONDITIONS.
#
# Convention: exit 0 on success, exit 1 on assertion failure.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
CODER="${REPO_ROOT}/.claude/commands/coder.md"
PD="${REPO_ROOT}/.claude/skills/workflow-protocols/parallel-dispatch.md"

if [[ ! -f "${CODER}" || ! -f "${PD}" ]]; then
  echo "[test-coder-parallel-debug-dispatch] FAIL: source files missing" >&2
  exit 1
fi

# ---- Test 1: parallel_debug_dispatch subsection exists in coder.md ----
if ! grep -q -e 'parallel_debug_dispatch:' "${CODER}"; then
  echo "[test-coder-parallel-debug-dispatch] FAIL: parallel_debug_dispatch subsection missing in coder.md" >&2
  exit 1
fi

# ---- Test 2: env flag CLAUDE_PARALLEL_DEBUG_DISPATCH referenced in coder.md ----
if ! grep -q -e 'CLAUDE_PARALLEL_DEBUG_DISPATCH=on' "${CODER}"; then
  echo "[test-coder-parallel-debug-dispatch] FAIL: env flag mention missing in coder.md" >&2
  exit 1
fi

# ---- Test 3: pre-dispatch independence check + post-merge conflict detection cross-references present ----
if ! grep -q -e 'pre_dispatch_independence_check' "${CODER}"; then
  echo "[test-coder-parallel-debug-dispatch] FAIL: pre_dispatch_independence_check missing" >&2
  exit 1
fi
if ! grep -q -e 'post_merge_conflict_detection' "${CODER}"; then
  echo "[test-coder-parallel-debug-dispatch] FAIL: post_merge_conflict_detection missing" >&2
  exit 1
fi

# ---- Test 4: loop-limit accounting documented (k parallel = 1 iteration) ----
if ! grep -q -e 'counts as ONE iteration of the code_review_cycle counter' "${CODER}"; then
  echo "[test-coder-parallel-debug-dispatch] FAIL: loop-limit accounting missing" >&2
  exit 1
fi

# ---- Test 5: contract preservation note present ----
if ! grep -q -e 'coder_to_code_review handoff payload byte-identical' "${CODER}"; then
  echo "[test-coder-parallel-debug-dispatch] FAIL: contract-preservation note missing" >&2
  exit 1
fi

# ---- Test 6: parallel-dispatch.md Use Case 2 header flipped ----
if grep -q -e 'FUTURE PATTERN, NOT IMPLEMENTED' "${PD}"; then
  echo "[test-coder-parallel-debug-dispatch] FAIL: parallel-dispatch.md still says FUTURE PATTERN" >&2
  exit 1
fi
if ! grep -q -e 'ACTIVATION CONDITIONS' "${PD}"; then
  echo "[test-coder-parallel-debug-dispatch] FAIL: parallel-dispatch.md missing ACTIVATION CONDITIONS header" >&2
  exit 1
fi
if ! grep -q -e 'Implemented as of 2026-04-30' "${PD}"; then
  echo "[test-coder-parallel-debug-dispatch] FAIL: parallel-dispatch.md missing implementation date marker" >&2
  exit 1
fi

# ---- Test 7: section-anchor citations used (PR-004 fix) ----
if ! grep -q -e 'parallel-dispatch.md § Use Case 2 → Pre-dispatch checklist (verbatim)' "${CODER}"; then
  echo "[test-coder-parallel-debug-dispatch] FAIL: section-anchor citation missing for Pre-dispatch checklist" >&2
  exit 1
fi
if ! grep -q -e 'parallel-dispatch.md § Use Case 2 → Pattern (verbatim)' "${CODER}"; then
  echo "[test-coder-parallel-debug-dispatch] FAIL: section-anchor citation missing for Pattern" >&2
  exit 1
fi
if ! grep -q -e 'parallel-dispatch.md § Post-Merge Conflict Detection (verbatim)' "${CODER}"; then
  echo "[test-coder-parallel-debug-dispatch] FAIL: section-anchor citation missing for Post-Merge Conflict Detection" >&2
  exit 1
fi

# ---- Test 8: parallel-dispatch.md Use Case 2 body preserved (verbatim source-of-truth) ----
# Spot-check the core anchors that coder.md cites.
for anchor in 'Pre-dispatch checklist (MANDATORY):' 'Post-Merge Conflict Detection' 'Focused prompt template:'; do
  if ! grep -q -e "${anchor}" "${PD}"; then
    echo "[test-coder-parallel-debug-dispatch] FAIL: parallel-dispatch.md anchor '${anchor}' missing — verbatim source-of-truth violated" >&2
    exit 1
  fi
done

echo "[test-coder-parallel-debug-dispatch] PASS"
exit 0
