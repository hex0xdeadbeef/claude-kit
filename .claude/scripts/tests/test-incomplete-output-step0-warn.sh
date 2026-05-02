#!/usr/bin/env bash
# test-incomplete-output-step0-warn.sh
# AC-P3-1, AC-P3-2, AC-P3-3: warn-mode caveat + cross-reference language documented in step_0.
set -euo pipefail
SCRIPT_NAME="$(basename "$0")"
PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
label() { echo "[${SCRIPT_NAME}] $1: $2" >&2; }
fail() { label "FAIL" "$1"; exit 1; }
pass() { label "PASS" "$1"; }
cd "$PROJECT_ROOT"

RECOVERY=".claude/skills/workflow-protocols/incomplete-output-recovery.md"

# AC-P3-1: step_0 prose mentions the warn-mode caveat
grep -q 'WARN-MODE CAVEAT (CR-003)' "$RECOVERY" \
  || fail "AC-P3-1 — step_0 prose does not contain the WARN-MODE CAVEAT marker"
pass "AC-P3-1 — warn-mode caveat present in step_0"

# AC-P3-2a: step_0 prose instructs cross-reference of handoff-validation.jsonl
grep -q 'handoff-validation.jsonl' "$RECOVERY" \
  || fail "AC-P3-2a — step_0 prose does not instruct cross-reference of handoff-validation.jsonl"
pass "AC-P3-2a — cross-reference target documented"

# AC-P3-2b: step_0 prose names the record_kind to look for
grep -qE 'record_kind:[[:space:]]*"verdict_schema_invalid"|record_kind=verdict_schema_invalid|record_kind:[[:space:]]*\\"verdict_schema_invalid\\"' "$RECOVERY" \
  || fail "AC-P3-2b — step_0 prose does not name record_kind verdict_schema_invalid"
pass "AC-P3-2b — record_kind to look for is named"

# AC-P3-3: note field has the warn-mode-users sentence
grep -qE 'Warn-mode users:.{0,200}cross-reference handoff-validation\.jsonl' "$RECOVERY" \
  || fail "AC-P3-3 — note field does not contain the warn-mode-users cross-reference instruction"
pass "AC-P3-3 — note field updated with warn-mode user instruction"

label "PASS" "test-incomplete-output-step0-warn.sh — all assertions met"
