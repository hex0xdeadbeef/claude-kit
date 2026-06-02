#!/usr/bin/env bash
# test-audit-tail-cleanup.sh
# Audit Batch D: F9 (scope handoff-read off the Phase-2/4 delegation path),
# F8 (remove verdict-recovery dead review-completions.jsonl read), F6 (optional
# designer background researcher). Content-anchored. (F10 = settings.json async,
# deferred to user — not tested here.)
set -euo pipefail
SCRIPT_NAME="$(basename "$0")"
PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
label() { echo "[${SCRIPT_NAME}] $1: $2" >&2; }
fail() { label "FAIL" "$1"; exit 1; }
pass() { label "PASS" "$1"; }
cd "$PROJECT_ROOT"

SKILL=".claude/skills/workflow-protocols/SKILL.md"
HCONTRACTS=".claude/skills/workflow-protocols/handoff-contracts.md"
DTEMPLATES=".claude/skills/workflow-protocols/delegation-templates.md"
VR=".claude/agents/verdict-recovery.md"
DESIGNER=".claude/commands/designer.md"

# ── F9: handoff-read scoped off the Phase-2/4 delegation path ──
grep -qF "OUTSIDE Phase-2/4 delegation" "$SKILL" \
  || fail "AC-F9 — SKILL.md handoff trigger not scoped OUTSIDE Phase-2/4 delegation"
grep -qiF "already inlined in" "$SKILL" \
  || fail "AC-F9 — SKILL.md does not note delegation-templates already inlines the shapes"
pass "AC-F9 — SKILL.md handoff triggers scope the read off the delegation path"

# F9 contract-shape byte-unchanged guard (PR-001): the 3 schema-validated
# discriminators must still be present in BOTH the contracts ref and the inlined
# templates — proves the reword did not alter a contract shape.
for disc in planner_to_plan_review plan_review_to_coder coder_to_code_review; do
  grep -qF "$disc" "$HCONTRACTS" \
    || fail "AC-F9 contract-shape guard — $disc missing from handoff-contracts.md"
  grep -qF "$disc" "$DTEMPLATES" \
    || fail "AC-F9 contract-shape guard — $disc missing from delegation-templates.md"
done
pass "AC-F9 contract-shape guard — all 3 discriminators intact in contracts + templates"

# ── F8: verdict-recovery dead read removed ──
grep -qF "if it exists — check for partial verdict" "$VR" \
  && fail "AC-F8 — verdict-recovery.md still has the direct review-completions.jsonl read"
grep -qiF "launch prompt" "$VR" \
  || fail "AC-F8 — verdict-recovery.md does not state prior context comes from the orchestrator launch prompt"
pass "AC-F8 — verdict-recovery prior-context read removed; sourced from launch prompt"

# ── F6: optional designer background researcher ──
grep -qF "optional_background_research" "$DESIGNER" \
  || fail "AC-F6 — designer.md missing optional_background_research note"
grep -qF "run_in_background" "$DESIGNER" \
  || fail "AC-F6 — designer.md note does not launch a background researcher"
pass "AC-F6 — designer.md Phase 1 has an optional CLARIFY-gated background researcher note"

label "PASS" "test-audit-tail-cleanup.sh — all assertions met"
