#!/usr/bin/env bash
# test-c-stage-genericity-audit.sh
#
# Asserts CG1.1..CG5.4 from .claude/prompts/c-stage-genericity-audit-2026-04-27.md
# Tests 2026-04-27 fresh C-stage audit: 5 Coder + Code-Reviewer genericity gaps
# fixed in coder.md, code-reviewer.md, coder-rules/SKILL.md, settings.local.json.example.
#
# Coverage: 16 ACs automated. Manual: CG1.4, CG2.4, CG4.5, CG5.4 (visual cross-ref).
# Awk active-body extractor uses 3-state machine (PR-001 fix from plan-review iter 1).
# CG3.5 uses jq for structural assertion (PR-002 fix from plan-review iter 1).

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

# CG1.1 — coder.md step 5 condition references LANGUAGE slot
awk '/Conditional: Load TDD skill/,/skip_behavior:|^[[:space:]]+purpose:/' .claude/commands/coder.md \
  | grep -qE 'LANGUAGE[[:space:]]*==[[:space:]]*.go.|PROJECT-KNOWLEDGE\.md → LANGUAGE' \
  || fail "CG1.1 — coder.md TDD-load condition missing LANGUAGE slot reference"
pass "CG1.1 — coder.md TDD-load condition gates on LANGUAGE slot"

# CG1.2 — skip_behavior block present
awk '/Conditional: Load TDD skill/,/^[[:space:]]+purpose:/' .claude/commands/coder.md \
  | grep -q 'skip_behavior:' \
  || fail "CG1.2 — coder.md TDD-load missing skip_behavior block"
pass "CG1.2 — skip_behavior documented for non-Go SKIP path"

# CG1.3 — "kit ships Go-only TDD patterns" rationale present
awk '/Conditional: Load TDD skill/,/^[[:space:]]+purpose:/' .claude/commands/coder.md \
  | grep -qE 'Go-only TDD patterns|Go-only TDD' \
  || fail "CG1.3 — coder.md TDD-load missing Go-only acknowledgment"
pass "CG1.3 — Go-only TDD acknowledgment present in skip rationale"

# CG2.1 — code-reviewer.md GET CHANGES example: no internal/handler/user.go in active body
# Active body = lines BETWEEN the two fences ``` ... ``` following "Block structure (example):"
# 3-state machine: 0=before-header, 1=after-header-before-fence, 2=between-fences (PRINT), 3=after-second-fence
ACTIVE_BLOCK=$(awk '
  /\*\*Block structure \(example\):\*\*/ { seen=1; next }
  seen==1 && /^```$/ { seen=2; next }
  seen==2 && /^```$/ { seen=3; next }
  seen==2 { print }
' .claude/agents/code-reviewer.md)
if [[ -z "$ACTIVE_BLOCK" ]]; then
  fail "CG2.1 — failed to extract active body of GET CHANGES example (predicate broken)"
fi
if echo "$ACTIVE_BLOCK" | grep -qE 'internal/handler/user\.go|internal/service/user\.go'; then
  fail "CG2.1 — internal/handler/user.go or internal/service/user.go still in active body of GET CHANGES example"
fi
pass "CG2.1 — GET CHANGES active body free of hardcoded Go paths"

# CG2.2 — active body uses SOURCE_GLOB slot reference
echo "$ACTIVE_BLOCK" | grep -qE 'SOURCE_GLOB|<files matching|<source-glob' \
  || fail "CG2.2 — GET CHANGES active body missing SOURCE_GLOB or slot-form reference"
pass "CG2.2 — GET CHANGES active body uses slot-form file-list reference"

# CG2.3 — at least 2 EXAMPLE (lang:) comment blocks present in/after the block
EXAMPLE_COUNT=$(awk '/\*\*Block structure \(example\):\*\*/{flag=1} flag' .claude/agents/code-reviewer.md \
                 | grep -cE '<!-- EXAMPLE \(lang:' || true)
if [[ "${EXAMPLE_COUNT:-0}" -lt 2 ]]; then
  fail "CG2.3 — fewer than 2 EXAMPLE (lang:) comment blocks (count: ${EXAMPLE_COUNT:-0})"
fi
pass "CG2.3 — at least 2 EXAMPLE (lang:) blocks present (count: ${EXAMPLE_COUNT})"

# CG3.1 — code-reviewer.md Worktree Optimization section contains MANDATORY + BLOCKER
awk '/^## Worktree Optimization/{flag=1; print; next} /^## /{if (flag) {flag=0; exit}} flag' .claude/agents/code-reviewer.md \
  | grep -qE 'MANDATORY for non-Go|BLOCKER' \
  || fail "CG3.1 — Worktree Optimization section missing MANDATORY/BLOCKER tightened wording"
pass "CG3.1 — Worktree section uses MANDATORY + BLOCKER wording"

# CG3.2 — QUICK CHECK Pre-flight subsection present
awk '/^## Worktree Optimization/{flag=1; print; next} /^## /{if (flag) {flag=0; exit}} flag' .claude/agents/code-reviewer.md \
  | grep -qE '### QUICK CHECK Pre-flight|worktree_sparsepaths_check' \
  || fail "CG3.2 — Worktree section missing QUICK CHECK Pre-flight subsection"
pass "CG3.2 — QUICK CHECK Pre-flight subsection present"

# CG3.3 — advisory issue ID CR-worktree-misconfigured documented
grep -q 'CR-worktree-misconfigured' .claude/agents/code-reviewer.md \
  || fail "CG3.3 — Pre-flight missing CR-worktree-misconfigured advisory ID"
pass "CG3.3 — CR-worktree-misconfigured advisory ID documented"

# CG3.4 — settings.local.json.example contains Python/TypeScript/Rust template hints
for stack in 'python' 'typescript' 'rust'; do
  grep -qiE "_worktree_templates_${stack}" .claude/settings.local.json.example \
    || fail "CG3.4 — settings.local.json.example missing _worktree_templates_${stack} hint"
done
pass "CG3.4 — settings.local.json.example has Python/TypeScript/Rust template hints"

# CG3.5 — settings.json sparsePaths default UNCHANGED (R2 backwards-compat)
# Use jq for structural assertion (settings.json stores sparsePaths as multi-line array;
# grep -q is line-oriented and won't match across newlines).
jq -e '.worktree.sparsePaths == [".claude/", "internal/", "cmd/", "go.mod", "go.sum", "Makefile", "CLAUDE.md"]' \
   .claude/settings.json >/dev/null \
  || fail "CG3.5 — settings.json sparsePaths structure changed (R2 violated)"
pass "CG3.5 — settings.json sparsePaths default unchanged (R2 preserved)"

# CG4.1 — Output Format does not contain literal "path/file.go:line"
if grep -qE '^- Location:.*\.go:line' .claude/agents/code-reviewer.md; then
  fail "CG4.1 — Output Format Location still uses 'path/file.go:line' literal"
fi
pass "CG4.1 — Output Format Location is language-agnostic"

# CG4.2 — VERDICT_JSON example does not contain ".go:" in location field
if grep -qE '"location":[[:space:]]*"[^"]*\.go:' .claude/agents/code-reviewer.md; then
  fail "CG4.2 — VERDICT_JSON example still uses .go: in location field"
fi
pass "CG4.2 — VERDICT_JSON example free of .go: in location field"

# CG4.3 — Location-stability bullets free of Go-specific paths/extensions
# (note: the "Avoid hardcoding..." advisory line legitimately quotes Go tokens in backticks
# as anti-patterns — it's NOT a bullet; predicate scopes only PREFER/ACCEPT/AVOID bullets)
if awk '/Location-stability guidance/,/Iteration 2\+/' .claude/agents/code-reviewer.md \
     | grep -E '^- (PREFER|ACCEPT|AVOID):' \
     | grep -qE 'internal/service/user\.go|handler/auth\.go|user\.go:42|\.go:'; then
  fail "CG4.3 — Location-stability bullets still contain Go-specific path/extension"
fi
pass "CG4.3 — Location-stability bullets are language-agnostic"

# CG4.4 — first PREFER bullet is Part-anchored symbol (mirror G4 PR-001 from P-stage)
FIRST_BULLET=$(awk '/Location-stability guidance/,/Iteration 2\+/' .claude/agents/code-reviewer.md \
                 | grep -E '^- (PREFER|ACCEPT|AVOID):' | head -1)
if ! echo "$FIRST_BULLET" | grep -qE '^- PREFER:.*Part [0-9]+:'; then
  fail "CG4.4 — first bulleted example is not Part-anchored symbol form: $FIRST_BULLET"
fi
pass "CG4.4 — symbol-only PREFER example is first (Part-anchored, mirrors G4 PR-001)"

# CG5.1 — coder-rules/SKILL.md does not contain literal "handler/API layer"
if grep -qF 'handler/API layer' .claude/skills/coder-rules/SKILL.md; then
  fail "CG5.1 — coder-rules/SKILL.md still contains literal 'handler/API layer'"
fi
pass "CG5.1 — 'handler/API layer' removed from coder-rules"

# CG5.2 — RULE_3 wording uses neutral "API/transport layer" or LAYERS slot
grep -qE 'API/transport layer|<INPUT_LAYER>|highest LAYERS entry' .claude/skills/coder-rules/SKILL.md \
  || fail "CG5.2 — RULE_3 missing neutral layer term (API/transport / <INPUT_LAYER> / LAYERS entry)"
pass "CG5.2 — RULE_3 uses neutral layer terminology"

# CG5.3 — both L13 (RULE_3 main) and L91 (Why) reference PROJECT-KNOWLEDGE.md → LAYERS
RULE_3_REFS=$(grep -cE 'PROJECT-KNOWLEDGE\.md → LAYERS' .claude/skills/coder-rules/SKILL.md || true)
if [[ "${RULE_3_REFS:-0}" -lt 2 ]]; then
  fail "CG5.3 — RULE_3 LAYERS pointer missing in one of L13/L91 (count: ${RULE_3_REFS:-0}, expected ≥2)"
fi
pass "CG5.3 — LAYERS slot pointer present in both RULE_3 main and Why"

# ════════════════════════════════════════════════════════════════════════
# MANUAL
# ════════════════════════════════════════════════════════════════════════
# CG1.4 — L367-370 tdd_mode reference consistency (visual cross-reference review)
# CG2.4 — SOURCE_GLOB pointer in active body (covered partly by CG2.2)
# CG4.5 — SOURCE_GLOB note in location-stability section (visual review of footer note)
# CG5.4 — no information loss in RULE_3 wording (intent preservation, visual review)

label "INFO" "test-c-stage-genericity-audit.sh complete — 16/19 ACs automated (manual: CG1.4, CG2.4, CG4.5, CG5.4)"
exit 0
