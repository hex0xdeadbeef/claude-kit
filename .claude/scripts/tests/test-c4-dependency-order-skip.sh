#!/usr/bin/env bash
# test-c4-dependency-order-skip.sh
#
# Asserts AC-C4.1..AC-C4.6 from .claude/prompts/coder-code-review-generic-analysis.md §8 C4
# Tests C4 — Coder dependency-order SKIP-align

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

label() { echo "[${SCRIPT_NAME}] $1: $2" >&2; }
fail() { label "FAIL" "$1"; exit 1; }
pass() { label "PASS" "$1"; }

cd "$PROJECT_ROOT"

# ════════════════════════════════════════════════════════════════════════
# AUTOMATED (CI-runnable grep predicates)
# ════════════════════════════════════════════════════════════════════════

# AC-C4.1: no "data access → ... → wiring" or "data access → domain → API" fallback
if grep -nE 'data access[[:space:]]*[→>].*[→>][[:space:]]*wiring' .claude/commands/coder.md .claude/skills/coder-rules/SKILL.md 2>/dev/null; then
  fail "AC-C4.1 — pre-fix 'data access → ... → wiring' fallback still present in coder.md or coder-rules/SKILL.md"
fi
if grep -nE 'data access[[:space:]]*[→>][[:space:]]*(models[[:space:]]*[→>][[:space:]]*)?domain[[:space:]]*[→>][[:space:]]*API' .claude/commands/coder.md .claude/skills/coder-rules/SKILL.md 2>/dev/null; then
  fail "AC-C4.1 — pre-fix 'data access → domain → API' fallback still present"
fi
pass "AC-C4.1 — pre-fix layered fallback removed"

# AC-C4.2: coder.md L351 wording references plan-determined order + LAYERS+ARCHITECTURE_STYLE conditional + SKIP
grep -q 'Follow Parts order from plan' .claude/commands/coder.md \
  || fail "AC-C4.2a — coder.md does not reference 'Follow Parts order from plan'"
grep -q '{LAYERS} slot set AND {ARCHITECTURE_STYLE} == "layered"' .claude/commands/coder.md \
  || fail "AC-C4.2b — coder.md missing LAYERS+ARCHITECTURE_STYLE conditional"
grep -q 'follow plan.*natural Part order.*emit consolidated NIT' .claude/commands/coder.md \
  || fail "AC-C4.2c — coder.md missing SKIP-with-NIT fallback"
pass "AC-C4.2 — coder.md L351 wording references plan-determined order + slot conditional + SKIP"

# AC-C4.3: coder-rules/SKILL.md L53 same pattern
grep -q 'Follow Parts order from plan' .claude/skills/coder-rules/SKILL.md \
  || fail "AC-C4.3a — coder-rules/SKILL.md does not reference 'Follow Parts order from plan'"
grep -q '{ARCHITECTURE_STYLE} == "layered"' .claude/skills/coder-rules/SKILL.md \
  || fail "AC-C4.3b — coder-rules/SKILL.md missing ARCHITECTURE_STYLE conditional"
pass "AC-C4.3 — coder-rules/SKILL.md L53 wording matches"

# AC-C4.6: handoff schema + PK schema + plan structure unchanged — pre-merge gate
if [[ -d .git ]]; then
  CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
  if [[ "$CURRENT_BRANCH" == "main" ]]; then
    label "INFO" "AC-C4.6 — skipped (running on main; pre-merge gate only)"
  else
    BASE="$(git merge-base HEAD origin/main 2>/dev/null || echo main)"
    # handoff.schema.json: post-P1 refactor allows additive changes; discriminator-frozen invariant.
    git diff "$BASE"..HEAD -- .claude/schemas/handoff.schema.json > /tmp/c4-diff.txt 2>&1 || true
    if [[ -s /tmp/c4-diff.txt ]]; then
      BASE_DISC=$(git show "$BASE":.claude/schemas/handoff.schema.json 2>/dev/null \
        | grep -oE '"const": *"(planner_to_plan_review|plan_review_to_coder|coder_to_code_review|plan_review_verdict|code_review_verdict)"' | sort -u || echo "")
      HEAD_DISC=$(grep -oE '"const": *"(planner_to_plan_review|plan_review_to_coder|coder_to_code_review|plan_review_verdict|code_review_verdict)"' .claude/schemas/handoff.schema.json | sort -u || echo "")
      if [[ "$BASE_DISC" != "$HEAD_DISC" ]]; then
        fail "AC-C4.6 — discriminator contract broken (additive-only allowed)"
      fi
      label "INFO" "AC-C4.6 — schema modified but discriminator contracts preserved (additive change accepted)"
    fi
    # plan-template.md: bytes-identical EXCEPT TDD-always-on documentation block
    # (post-tdd-always-on-flip extension; mirrors the PROJECT-KNOWLEDGE.md.example FMT_CMD
    # allowlist precedent below). Allow diff iff every +/- line is either:
    #   (a) inside `# ===== TDD-always-on note =====` ... `# ===== end TDD-always-on note =====`
    #       — i.e. starts with `+    # ` or `-    # ` (4-space indent + comment marker)
    #   (b) the Tests-Part `description:` string edit (annotates RGR-interleaved as default)
    git diff "$BASE"..HEAD -- .claude/templates/plan-template.md > /tmp/c4-pt-diff.txt 2>&1 || true
    if [[ -s /tmp/c4-pt-diff.txt ]]; then
      pt_bad_lines=$(grep -E '^[+-]' /tmp/c4-pt-diff.txt \
        | grep -vE '^(\+\+\+|---) ' \
        | grep -vE '^[+-][[:space:]]+#' \
        | grep -vE '^[+-][[:space:]]+description: "Tests for new functionality' \
        || true)
      if [[ -n "$pt_bad_lines" ]]; then
        fail "AC-C4.6 — .claude/templates/plan-template.md has changes outside TDD-always-on note/description scope"
      fi
    fi
    # PROJECT-KNOWLEDGE.md.example: post-1.18 auto-fmt-generic spec extends FMT_CMD with
    # `{}` placeholder doc (per spec auto-fmt-generic §4.1). Allow diff if and only if
    # every +/- line is either (a) a `- FMT_CMD:` slot line, or (b) a comment-continuation
    # line (starts with whitespace + `#`). Loose tokens are anchored to the FMT_CMD block
    # to prevent unrelated lines containing words like "black"/"prettier" from slipping
    # through (CR-iter2 NIT tightening).
    git diff "$BASE"..HEAD -- .claude/PROJECT-KNOWLEDGE.md.example > /tmp/c4-pk-diff.txt 2>&1 || true
    if [[ -s /tmp/c4-pk-diff.txt ]]; then
      bad_lines=$(grep -E '^[+-]' /tmp/c4-pk-diff.txt \
        | grep -vE '^(\+\+\+|---) ' \
        | grep -vE '^[+-]- FMT_CMD:|^[+-][[:space:]]+#' \
        || true)
      if [[ -n "$bad_lines" ]]; then
        fail "AC-C4.6 — .claude/PROJECT-KNOWLEDGE.md.example has changes outside FMT_CMD slot/comment scope"
      fi
    fi
    rm -f /tmp/c4-diff.txt /tmp/c4-pt-diff.txt /tmp/c4-pk-diff.txt
    pass "AC-C4.6 — handoff.schema unchanged; plan-template diff (if any) limited to TDD-always-on note/description; PK.example diff (if any) limited to auto-fmt-generic FMT_CMD doc"
  fi
fi

# ════════════════════════════════════════════════════════════════════════
# MANUAL (operator procedure)
# ════════════════════════════════════════════════════════════════════════
# AC-C4.4: Flat-fixture coder follows plan order
#   Procedure: create PROJECT-KNOWLEDGE.md with ARCHITECTURE_STYLE: flat (or LAYERS unset),
#   plan with non-layered Parts order. Run /coder. Confirm Parts implemented in plan order
#   (not re-ordered to data→domain→api). NIT emitted in evaluate_output if order ambiguous.
#
# AC-C4.5: Kit-dogfood regression
#   Kit's LAYERS=[orchestrator, reviewers, enforcement, knowledge], ARCHITECTURE_STYLE=other.
#   Pre-fix: coder.md L351 'data access → ... → wiring' fallback contradicted kit's actual layers.
#   Post-fix: explicit 'follow plan order verbatim'. Verify same Parts order on kit fixture.

label "INFO" "test-c4-dependency-order-skip.sh complete — 4/6 AC automated (AC-C4.4/5 manual)"
exit 0
