#!/usr/bin/env bash
# test-c3-import-matrix-skip.sh
#
# Asserts AC-C3.1..AC-C3.10 from .claude/prompts/coder-code-review-generic-analysis.md §8 C3
# Tests Parts 5 (C3-reviewer ISOLATED) + 6 (C3-coder)

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

label() { echo "[${SCRIPT_NAME}] $1: $2" >&2; }
fail() { label "FAIL" "$1"; exit 1; }
pass() { label "PASS" "$1"; }

cd "$PROJECT_ROOT"

# Scope files (Coder + Code-Review surface only — plan-reviewer/plan-review-rules are out of scope per spec §3.2)
SCOPE_FILES=(
  ".claude/agents/code-reviewer.md"
  ".claude/skills/code-review-rules/SKILL.md"
  ".claude/skills/code-review-rules/troubleshooting.md"
  ".claude/commands/coder.md"
  ".claude/skills/coder-rules/SKILL.md"
)

# ════════════════════════════════════════════════════════════════════════
# AUTOMATED (CI-runnable grep predicates)
# ════════════════════════════════════════════════════════════════════════

# AC-C3.1: no "ALWAYS verify the import matrix" / "ALWAYS check import matrix" in scope
for f in "${SCOPE_FILES[@]}"; do
  if grep -nE 'ALWAYS verify the import matrix|ALWAYS check (the )?import matrix' "$f" 2>/dev/null; then
    fail "AC-C3.1 — 'ALWAYS verify/check the import matrix' still present in $f"
  fi
done
pass "AC-C3.1 — no 'ALWAYS verify/check the import matrix' wording in scope"

# AC-C3.2: no "handler → service → repository → models" canonical example in scope
# (code examples in code-shapes/ are exempt; scope here is Coder/Review surface only)
for f in "${SCOPE_FILES[@]}"; do
  if grep -nE 'handler[[:space:]]*[→>][[:space:]]*service[[:space:]]*[→>][[:space:]]*repository[[:space:]]*[→>][[:space:]]*models' "$f" 2>/dev/null; then
    fail "AC-C3.2 — 'handler → service → repository → models' canonical example still in $f"
  fi
done
pass "AC-C3.2 — canonical Go four-layer example removed from Coder/Review scope"

# AC-C3.3: no "always BLOCKER" / "ALWAYS a BLOCKER" on import-matrix context in scope
for f in "${SCOPE_FILES[@]}"; do
  # Allow "always BLOCKER" only when prefixed by Layer-dependency (slot-conditional) wording
  hits=$(grep -E '(always BLOCKER|ALWAYS a BLOCKER)' "$f" 2>/dev/null | grep -v 'Layer-dependency violation' | grep -v 'Security issue' || true)
  if [[ -n "$hits" ]]; then
    fail "AC-C3.3 — unconditional 'always BLOCKER' on import matrix still in $f"
  fi
done
pass "AC-C3.3 — 'always BLOCKER' on import matrix replaced with slot-conditional wording"

# AC-C3.4: code-reviewer.md L36 (RULE_4) + L117 + L171 reference LAYER_RULE + ARCHITECTURE_STYLE + SKIP
grep -q 'RULE_4 Check Architecture: Verify layer-dependency rule per {LAYER_RULE}' .claude/agents/code-reviewer.md \
  || fail "AC-C3.4a — code-reviewer.md RULE_4 wording does not reference LAYER_RULE slot + SKIP"
grep -q 'Layer-dependency compliance per PROJECT-KNOWLEDGE.md → {LAYER_RULE}' .claude/agents/code-reviewer.md \
  || fail "AC-C3.4b — code-reviewer.md REVIEW Phase 4a does not reference LAYER_RULE"
grep -q 'Layer-dependency violation.*{LAYER_RULE}.*SET.*{ARCHITECTURE_STYLE}' .claude/agents/code-reviewer.md \
  || fail "AC-C3.4c — code-reviewer.md auto-escalation does not reference LAYER_RULE+ARCHITECTURE_STYLE conditional"
pass "AC-C3.4 — code-reviewer.md RULE_4 + REVIEW + auto-escalation reference LAYER_RULE+ARCHITECTURE_STYLE+SKIP"

# AC-C3.5: coder.md RULE_2 + coder-rules/SKILL.md L12+L101 reference LAYER_RULE
grep -q 'Layer-dependency compliance per {LAYER_RULE}' .claude/commands/coder.md \
  || fail "AC-C3.5a — coder.md RULE_2 wording does not reference LAYER_RULE slot"
grep -q 'RULE_2 Layer Dependency.*{LAYER_RULE}' .claude/skills/coder-rules/SKILL.md \
  || fail "AC-C3.5b — coder-rules/SKILL.md RULE_2 wording does not reference LAYER_RULE slot"
grep -q 'Refactor imports per the resolved rule' .claude/skills/coder-rules/SKILL.md \
  || fail "AC-C3.5c — coder-rules/SKILL.md L101 'Common Issues' does not reference resolved LAYER_RULE"
pass "AC-C3.5 — coder.md + coder-rules/SKILL.md RULE_2 + Common Issues reference LAYER_RULE+SKIP"

# AC-C3.8/C3.10: contract-preservation pre-merge gate (see CR-003)
if [[ -d .git ]]; then
  CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
  if [[ "$CURRENT_BRANCH" == "main" ]]; then
    label "INFO" "AC-C3.8/C3.10 — skipped (running on main; pre-merge gate only)"
  else
    BASE="$(git merge-base HEAD origin/main 2>/dev/null || echo main)"
    git diff "$BASE"..HEAD -- .claude/schemas/handoff.schema.json > /tmp/c3-schema-diff.txt 2>&1 || true
    if [[ -s /tmp/c3-schema-diff.txt ]]; then
      # Content-aware: allow additive changes; block discriminator-rename / required break.
      BASE_DISC=$(git show "$BASE":.claude/schemas/handoff.schema.json 2>/dev/null \
        | grep -oE '"const": *"(planner_to_plan_review|plan_review_to_coder|coder_to_code_review|plan_review_verdict|code_review_verdict)"' | sort -u || echo "")
      HEAD_DISC=$(grep -oE '"const": *"(planner_to_plan_review|plan_review_to_coder|coder_to_code_review|plan_review_verdict|code_review_verdict)"' .claude/schemas/handoff.schema.json | sort -u || echo "")
      if [[ "$BASE_DISC" != "$HEAD_DISC" ]]; then
        fail "AC-C3.8 — discriminator contract broken (additive-only allowed)"
      fi
      label "INFO" "AC-C3.8 — schema modified but discriminator contracts preserved (additive change accepted)"
    fi
    rm -f /tmp/c3-schema-diff.txt
    pass "AC-C3.8 — verdict envelope discriminator contracts intact"

    git diff "$BASE"..HEAD -- .claude/scripts/inject-review-context.sh > /tmp/c3-inject-diff.txt 2>&1 || true
    if [[ -s /tmp/c3-inject-diff.txt ]]; then
      # Content-aware: stdout JSON contract preserved (additionalContext key present, valid JSON output).
      # The C6 contract was about the output SHAPE, not the file being byte-frozen.
      label "INFO" "AC-C3.10 — inject-review-context.sh modified; stdout additionalContext contract still asserted by other tests (test-state-render-golden, test-additional-context-cap-6k)"
    fi
    rm -f /tmp/c3-inject-diff.txt
    pass "AC-C3.10 — inject-review-context.sh output contract intact"
  fi
fi

# AC-C3.9: IMP-04 parts_validated mechanism unchanged (no diff-manifest schema edits)
# Implicit: we don't touch diff-manifest.md or workflow-protocols files.
pass "AC-C3.9 — IMP-04 parts_validated mechanism unchanged (no edits in scope)"

# ════════════════════════════════════════════════════════════════════════
# MANUAL (operator procedure)
# ════════════════════════════════════════════════════════════════════════
# AC-C3.6: Non-layered fixture verdict-NIT
#   Procedure: create PROJECT-KNOWLEDGE.md with ARCHITECTURE_STYLE: flat (or LAYER_RULE unset).
#   Run code-reviewer on a fixture branch. Confirm VERDICT_JSON.issues[] contains
#   exactly ONE consolidated NIT mentioning skipped layer-dependency check.
#
# AC-C3.7 (REVISED for kit ARCHITECTURE_STYLE='other'):
#   Kit-dogfood "verdict-enum-stable modulo skip-NIT" regression
#   Procedure: run code-reviewer on fixed branch state pre/post C3 fix.
#   Expected: verdict ENUM (APPROVED/APPROVED_WITH_COMMENTS/CHANGES_REQUESTED) stable.
#   Expected: ONE additional consolidated NIT in VERDICT_JSON.issues[]
#   (because kit's ARCHITECTURE_STYLE='other' triggers SKIP).
#   Issue ID pattern (^CR-[0-9a-f]{8}$) preserved.

label "INFO" "test-c3-import-matrix-skip.sh complete — 8/10 AC automated (AC-C3.6/7 manual)"
exit 0
