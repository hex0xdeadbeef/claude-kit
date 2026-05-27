#!/usr/bin/env bash
# test-simplify-semantics-doc.sh — I-01: Phase 2.5 SIMPLIFY ↔ /code-review --fix doc consistency.
# Asserts the four docs that reference /simplify agree on the v2.1.147→v2.1.152 semantics:
#   - coder.md Phase 2.5 step_2 has a graceful-skip branch + simplify_applied: skipped
#   - coder.md / workflow.md / orchestration-core.md reference the /code-review --fix identity
#   - CLAUDE.md Soft Prerequisites name >= 2.1.152 for native SIMPLIFY
# RED before the I-01 edits; GREEN after.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
PASS=0; FAIL=0

chk() {  # name  file  fixed-string
  local name="$1" file="$2" needle="$3"
  if grep -Fq -- "$needle" "${ROOT}/${file}" 2>/dev/null; then
    echo "  PASS: $name"; PASS=$((PASS+1))
  else
    echo "  FAIL: $name (missing in ${file}: '${needle}')"; FAIL=$((FAIL+1))
  fi
}

echo "=== test-simplify-semantics-doc.sh ==="
chk "coder.md references /code-review --fix"        ".claude/commands/coder.md"                              "/code-review --fix"
chk "coder.md graceful-skip simplify_applied"       ".claude/commands/coder.md"                              "simplify_applied: skipped"
chk "workflow.md references /code-review --fix"     ".claude/commands/workflow.md"                           "/code-review --fix"
chk "orchestration-core.md mermaid identity"        ".claude/skills/workflow-protocols/orchestration-core.md" "/code-review --fix"
chk "CLAUDE.md names >= 2.1.152 floor for SIMPLIFY" "CLAUDE.md"                                              "2.1.152"
chk "CLAUDE.md ties note to SIMPLIFY sub-phase"     "CLAUDE.md"                                              "SIMPLIFY"

echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ "${FAIL}" -eq 0 ]] && exit 0 || exit 1
