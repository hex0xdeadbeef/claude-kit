#!/usr/bin/env bash
# test-p2-dependency-file-slot.sh
#
# Asserts AC-P2.1..AC-P2.5 from .claude/prompts/plan-stage-generic-spec.md §8 P2
# Tests v1.16.0 P2: DEPENDENCY_FILE + INSTALL_VERB slots in PROJECT-KNOWLEDGE.md
# (D3 from post-1.17-symmetry-audit)

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

label() { echo "[${SCRIPT_NAME}] $1: $2" >&2; }
fail() { label "FAIL" "$1"; exit 1; }
pass() { label "PASS" "$1"; }

cd "$PROJECT_ROOT"

# ════════════════════════════════════════════════════════════════════════
# AUTOMATED
# ════════════════════════════════════════════════════════════════════════

# AC-P2.1: task-analysis.md does NOT contain literal 'go.mod' (replaced with {DEPENDENCY_FILE})
if grep -F 'go.mod' .claude/skills/planner-rules/task-analysis.md 2>/dev/null; then
  fail "AC-P2.1 — task-analysis.md still contains literal 'go.mod' (should use {DEPENDENCY_FILE})"
fi
pass "AC-P2.1 — task-analysis.md uses slot, not literal go.mod"

# AC-P2.2: task-analysis.md if_external_library uses {DEPENDENCY_FILE} and {INSTALL_VERB} placeholders
grep -q '{DEPENDENCY_FILE}' .claude/skills/planner-rules/task-analysis.md \
  || fail "AC-P2.2a — task-analysis.md missing {DEPENDENCY_FILE} placeholder"
grep -q '{INSTALL_VERB}' .claude/skills/planner-rules/task-analysis.md \
  || fail "AC-P2.2b — task-analysis.md missing {INSTALL_VERB} placeholder"
pass "AC-P2.2 — task-analysis.md uses {DEPENDENCY_FILE} + {INSTALL_VERB} slots"

# AC-P2.3: PROJECT-KNOWLEDGE.md.example defines DEPENDENCY_FILE and INSTALL_VERB slots
grep -q 'DEPENDENCY_FILE' .claude/PROJECT-KNOWLEDGE.md.example \
  || fail "AC-P2.3a — PROJECT-KNOWLEDGE.md.example missing DEPENDENCY_FILE slot"
grep -q 'INSTALL_VERB' .claude/PROJECT-KNOWLEDGE.md.example \
  || fail "AC-P2.3b — PROJECT-KNOWLEDGE.md.example missing INSTALL_VERB slot"
pass "AC-P2.3 — DEPENDENCY_FILE + INSTALL_VERB slots present in PK schema"

# AC-P2.4: skip_if_unset behavior (canonical SKIP) referenced in task-analysis.md
grep -q 'skip_if_unset' .claude/skills/planner-rules/task-analysis.md \
  || fail "AC-P2.4 — task-analysis.md missing skip_if_unset SKIP behavior"
pass "AC-P2.4 — skip_if_unset SKIP rule documented"

# ════════════════════════════════════════════════════════════════════════
# MANUAL
# ════════════════════════════════════════════════════════════════════════
# AC-P2.5: Kit dogfood — kit's PK has DEPENDENCY_FILE/INSTALL_VERB populated correctly
#   Verify manually: PROJECT-KNOWLEDGE.md L46-50 sets these to "" (empty for config-as-code kit)
#   per intentional skip (kit is not Go-source project; ships as plain files).

label "INFO" "test-p2-dependency-file-slot.sh complete — 4/5 AC automated (AC-P2.5 manual)"
exit 0
