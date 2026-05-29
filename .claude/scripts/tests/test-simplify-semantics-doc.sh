#!/bin/bash
# Test: SIMPLIFY (Phase 2.5) /simplify semantics documented consistently (IMP-2, 2.1.154).
#
# Claude Code 2.1.154 redefined /simplify: it now runs a CLEANUP-ONLY review
# (reuse, simplification, efficiency, altitude) and applies the fixes — NOT the bug-hunting
# /code-review --fix it aliased on 2.1.152. Guards cross-file consistency of the SIMPLIFY wording
# across coder.md, workflow.md, orchestration-core.md, CLAUDE.md after that revert.
#
# CHANGELOG evidence: line 14 ("/simplify now runs a cleanup-only review (reuse, simplification,
# efficiency, altitude) ... instead of running the full /code-review --fix bug-hunting review").
#
# Part of changelog-2153-156-opus48-uplift (IMP-2). Supersedes the 2.1.152 identity assertion
# from changelog-2142-152-core (I-01).

set -uo pipefail
FAIL=0
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT" || { echo "FAIL: cannot cd to repo root"; exit 1; }
err() { echo "FAIL: $1"; FAIL=1; }

CODER=".claude/commands/coder.md"
WF=".claude/commands/workflow.md"
ORCH=".claude/skills/workflow-protocols/orchestration-core.md"

# 1. coder.md describes the 2.1.154 cleanup-only semantics, NOT the stale 2.1.152 identity.
grep -q 'cleanup-only' "$CODER" || err "coder.md missing 2.1.154 'cleanup-only' SIMPLIFY semantics"
if grep -q 'identical to /code-review --fix' "$CODER"; then
  err "coder.md still asserts stale '/simplify identical to /code-review --fix' (reverted in 2.1.154)"
fi
grep -q 'simplify_applied: skipped' "$CODER" || err "coder.md missing graceful-skip (simplify_applied: skipped)"

# 2. workflow.md simplify_note uses cleanup-only framing, not the stale identity.
grep -q 'cleanup-only' "$WF" || err "workflow.md simplify_note missing 'cleanup-only' framing"
if grep -q '= /code-review --fix' "$WF"; then
  err "workflow.md still asserts stale '/simplify = /code-review --fix' identity"
fi

# 3. orchestration-core.md mermaid node uses a cleanup-only label, not the stale identity.
grep -q 'cleanup-only' "$ORCH" || err "orchestration-core.md mermaid SMP node missing 'cleanup-only' label"
if grep -q '/simplify = /code-review --fix' "$ORCH"; then
  err "orchestration-core.md mermaid still shows stale '/simplify = /code-review --fix'"
fi

# 4. CLAUDE.md SIMPLIFY sub-phase note reflects 2.1.154 cleanup-only.
grep -q 'SIMPLIFY sub-phase' CLAUDE.md || err "CLAUDE.md missing SIMPLIFY sub-phase note"
grep -q 'cleanup-only' CLAUDE.md || err "CLAUDE.md SIMPLIFY note missing 2.1.154 'cleanup-only' semantics"

if [[ "$FAIL" -eq 0 ]]; then
  echo "PASS: SIMPLIFY cleanup-only (2.1.154) semantics documented consistently across 4 files"
fi
exit "$FAIL"
