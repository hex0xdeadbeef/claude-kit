#!/usr/bin/env bash
# test-needs-changes-alias-routing.sh
# AC-P1.1, AC-P1.2, AC-P1.3, AC-P1.4, AC-P1.5: NEEDS_CHANGES alias from code-reviewer is documented as
# routing-equivalent to CHANGES_REQUESTED + emits verdict_alias_normalized telemetry record.
set -euo pipefail
SCRIPT_NAME="$(basename "$0")"
PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
label() { echo "[${SCRIPT_NAME}] $1: $2" >&2; }
fail() { label "FAIL" "$1"; exit 1; }
pass() { label "PASS" "$1"; }
cd "$PROJECT_ROOT"

REROUT=".claude/skills/workflow-protocols/re-routing.md"
ORCH=".claude/skills/workflow-protocols/orchestration-core.md"
DELEG=".claude/skills/workflow-protocols/delegation-templates.md"

# AC-P1.1: re-routing.md contains verdict_aliases block with NEEDS_CHANGES → CHANGES_REQUESTED rule
grep -q 'verdict_aliases:' "$REROUT" \
  || fail "AC-P1.1a — verdict_aliases block missing from re-routing.md"
grep -q 'legacy_alias: "NEEDS_CHANGES"' "$REROUT" \
  || fail "AC-P1.1b — NEEDS_CHANGES alias entry missing from re-routing.md"
grep -q 'canonical: "CHANGES_REQUESTED"' "$REROUT" \
  || fail "AC-P1.1c — canonical mapping CHANGES_REQUESTED missing from re-routing.md"
pass "AC-P1.1 — re-routing.md contains alias normalization rule"

# AC-P1.2: orchestration-core.md Mermaid edge mentions NEEDS_CHANGES alias
grep -qE 'CR -->\|"?CHANGES_REQUESTED \| NEEDS_CHANGES \(alias\)' "$ORCH" \
  || fail "AC-P1.2 — Mermaid edge does not mention NEEDS_CHANGES (alias)"
pass "AC-P1.2 — Mermaid edge updated"

# AC-P1.3: increment_rules has entry for code-review NEEDS_CHANGES alias
grep -q 'trigger: "code-review verdict = NEEDS_CHANGES (legacy alias)"' "$ORCH" \
  || fail "AC-P1.3 — increment_rules missing entry for code-review NEEDS_CHANGES alias"
pass "AC-P1.3 — increment_rules covers NEEDS_CHANGES alias"

# AC-P1.4: delegation-templates.md post_delegation step 2.1 documents normalization + telemetry write
grep -q '2.1 (P-1 alias normalization)' "$DELEG" \
  || fail "AC-P1.4a — step 2.1 alias normalization missing from delegation-templates.md"
grep -q '"record_kind": "verdict_alias_normalized"' "$DELEG" \
  || fail "AC-P1.4b — verdict_alias_normalized record_kind not documented in delegation-templates.md"
pass "AC-P1.4 — delegation-templates.md documents alias normalization step"

# AC-P1.5: telemetry record_kind 'verdict_alias_normalized' документирован в re-routing.md
grep -q 'record_kind: "verdict_alias_normalized"' "$REROUT" \
  || fail "AC-P1.5 — verdict_alias_normalized record_kind not documented in re-routing.md"
pass "AC-P1.5 — telemetry record_kind documented"

label "PASS" "all AC-P1.* assertions passed"
