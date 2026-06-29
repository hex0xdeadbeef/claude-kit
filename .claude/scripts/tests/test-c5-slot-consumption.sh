#!/usr/bin/env bash
# test-c5-slot-consumption.sh
#
# Asserts AC-C5.1..AC-C5.16 from .claude/prompts/coder-code-review-generic-analysis.md §8 C5
# Tests Parts 3 (C5a DOMAIN_PROHIBIT) + 4 (C5b ERROR_WRAP+GEN+MOCK+CONFIG+worktree)

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

label() { echo "[${SCRIPT_NAME}] $1: $2" >&2; }
fail() { label "FAIL" "$1"; exit 1; }
pass() { label "PASS" "$1"; }

cd "$PROJECT_ROOT"

# Scope files for slot-consumption checks (consumer side only)
SCOPE_CODER=".claude/commands/coder.md"
SCOPE_CODER_SKILL=".claude/skills/coder-rules/SKILL.md"
SCOPE_REVIEWER=".claude/agents/code-reviewer.md"
SCOPE_REVIEWER_SKILL=".claude/skills/code-review-rules/SKILL.md"
SCOPE_TROUBLESHOOTING=".claude/skills/coder-rules/troubleshooting.md"

# ════════════════════════════════════════════════════════════════════════
# AUTOMATED (CI-runnable grep predicates)
# ════════════════════════════════════════════════════════════════════════

# AC-C5.1: no literal "encoding/json tags" outside slot-referenced/labeled context in Coder/Review surface
# (Allow lines that include both "encoding/json" AND "{DOMAIN_PROHIBIT}" — those are explanatory)
hits=$(grep -F 'encoding/json tags' "$SCOPE_CODER" "$SCOPE_CODER_SKILL" "$SCOPE_REVIEWER" 2>/dev/null | grep -v '{DOMAIN_PROHIBIT}' | grep -v 'kit Go example' || true)
if [[ -n "$hits" ]]; then
  fail "AC-C5.1 — 'encoding/json tags' literal still in Coder/Review surface without slot reference: $hits"
fi
pass "AC-C5.1 — 'encoding/json tags' only in slot-referenced or kit-labeled context"

# AC-C5.2: coder.md RULE_3 + coder-rules/SKILL.md RULE_3 + L87 reference {DOMAIN_PROHIBIT}
grep -q 'NEVER add {DOMAIN_PROHIBIT}' "$SCOPE_CODER" \
  || fail "AC-C5.2a — coder.md RULE_3 does not use {DOMAIN_PROHIBIT} placeholder"
grep -q 'NEVER add {DOMAIN_PROHIBIT}' "$SCOPE_CODER_SKILL" \
  || fail "AC-C5.2b — coder-rules/SKILL.md RULE_3 does not use {DOMAIN_PROHIBIT} placeholder"
grep -q 'No {DOMAIN_PROHIBIT}' "$SCOPE_CODER_SKILL" \
  || fail "AC-C5.2c — coder-rules/SKILL.md L87 'Why' does not use {DOMAIN_PROHIBIT}"
pass "AC-C5.2 — DOMAIN_PROHIBIT slot consistently referenced in Coder + Reviewer"

# AC-C5.3: code-reviewer.md L124 references {ERROR_WRAP}
grep -q 'errors propagate context per {ERROR_WRAP}' "$SCOPE_REVIEWER" \
  || fail "AC-C5.3 — code-reviewer.md L124 does not reference {ERROR_WRAP} slot"
pass "AC-C5.3 — code-reviewer.md ERROR_WRAP slot reference present"

# AC-C5.4: no bare 'fmt.Errorf("context: %w"' in Coder/Review surface outside example/kit-labeled context
# Allow inside language-shape file references (../planner-rules/code-shapes/) and 'kit Go default' labels.
hits=$(grep -F 'fmt.Errorf("context: %w"' "$SCOPE_REVIEWER" "$SCOPE_REVIEWER_SKILL" 2>/dev/null | grep -v 'kit Go default' | grep -v 'Kit Go example' | grep -v 'code-shapes' || true)
if [[ -n "$hits" ]]; then
  fail "AC-C5.4 — bare 'fmt.Errorf %w' still in Coder/Review surface without slot/example label: $hits"
fi
pass "AC-C5.4 — fmt.Errorf %w only in labeled kit-Go-example or code-shapes references"

# AC-C5.5: code-reviewer.md L142 references {GENERATED_PATTERN}
grep -q 'Generated files (per {GENERATED_PATTERN}' "$SCOPE_REVIEWER" \
  || fail "AC-C5.5 — code-reviewer.md L142 does not reference {GENERATED_PATTERN}"
pass "AC-C5.5 — GENERATED_PATTERN slot reference present"

# AC-C5.6: code-reviewer.md L143 references {MOCK_PATTERN}
grep -q 'Mocks (per {MOCK_PATTERN}' "$SCOPE_REVIEWER" \
  || fail "AC-C5.6 — code-reviewer.md L143 does not reference {MOCK_PATTERN}"
pass "AC-C5.6 — MOCK_PATTERN slot reference present"

# AC-C5.7: coder.md L387-388 reference {CONFIG_EXAMPLE} + {CONFIG_DOCS}, no inline 'Go default' parenthetical
grep -q 'Update {CONFIG_EXAMPLE}' "$SCOPE_CODER" \
  || fail "AC-C5.7a — coder.md does not use {CONFIG_EXAMPLE} placeholder"
grep -q 'Update {CONFIG_DOCS}' "$SCOPE_CODER" \
  || fail "AC-C5.7b — coder.md does not use {CONFIG_DOCS} placeholder"
if grep -F 'Go default: config.yaml.example' "$SCOPE_CODER" 2>/dev/null; then
  fail "AC-C5.7c — coder.md retains 'Go default: config.yaml.example' parenthetical"
fi
pass "AC-C5.7 — CONFIG_EXAMPLE/CONFIG_DOCS slot references; no Go default parenthetical"

# AC-C5.8: code-reviewer.md L329 worktree doc references SOURCE_GLOB+DEPENDENCY_FILE
grep -q 'SOURCE_GLOB.*DEPENDENCY_FILE\|DEPENDENCY_FILE.*SOURCE_GLOB' "$SCOPE_REVIEWER" \
  || fail "AC-C5.8 — code-reviewer.md worktree doc does not reference SOURCE_GLOB+DEPENDENCY_FILE slots"
pass "AC-C5.8 — worktree doc references SOURCE_GLOB+DEPENDENCY_FILE"

# AC-C5.9 (placeholder syntax sweep): all replaced placeholders use {SLOT_NAME} curly-brace form (R8 audit)
# Confirm presence of curly-brace placeholders for each modified slot
for slot in DOMAIN_PROHIBIT ERROR_WRAP GENERATED_PATTERN MOCK_PATTERN CONFIG_EXAMPLE CONFIG_DOCS LAYER_RULE LAYERS ARCHITECTURE_STYLE; do
  if ! grep -q "{${slot}}" "$SCOPE_CODER" "$SCOPE_REVIEWER" "$SCOPE_CODER_SKILL" "$SCOPE_REVIEWER_SKILL" 2>/dev/null; then
    fail "AC-C5.9 — placeholder {${slot}} not found in any scope file (consumer wiring incomplete)"
  fi
done
# Confirm absence of dollar-prefixed form ${SLOT_NAME} (kit convention is curly-brace only per R8)
hits=$(grep -E '\$\{(LAYER_RULE|ARCHITECTURE_STYLE|DOMAIN_PROHIBIT|ERROR_WRAP|GENERATED_PATTERN|MOCK_PATTERN|CONFIG_EXAMPLE|CONFIG_DOCS|LAYERS)\}' "$SCOPE_CODER" "$SCOPE_REVIEWER" "$SCOPE_CODER_SKILL" "$SCOPE_REVIEWER_SKILL" 2>/dev/null || true)
if [[ -n "$hits" ]]; then
  fail "AC-C5.9 — bash-style \${SLOT} placeholders detected (kit convention is {SLOT}): $hits"
fi
pass "AC-C5.9 — all 9 slots use {SLOT_NAME} curly-brace placeholder convention"

# AC-C5.13/14/15/16: contract-preservation pre-merge gate (see CR-003)
if [[ -d .git ]]; then
  CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
  if [[ "$CURRENT_BRANCH" == "main" ]]; then
    label "INFO" "AC-C5.13/14/15/16 — skipped (running on main; pre-merge gate only)"
  else
    BASE="$(git merge-base HEAD origin/main 2>/dev/null || echo main)"

    git diff "$BASE"..HEAD -- .claude/settings.json > /tmp/c5-settings-diff.txt 2>&1 || true
    if [[ -s /tmp/c5-settings-diff.txt ]]; then
      # post-1.18 auto-fmt-generic spec replaces 2 auto-fmt-go.sh if-clause hook entries
      # with 1 single auto-fmt.sh entry. Allow diff if and only if every +/- line is
      # either (a) a "command" key referencing auto-fmt(-go).sh OR caveman-{activate,
      # suspend-for-reviewer}.sh (the four allowlisted reviewer/researcher matcher
      # bindings), (b) an "if" key matching the dropped Go-specific filter, (c) a
      # "type": "command" line accompanying a new entry, (d) a structural-brace/comma
      # JSON line including bracket variants for new arrays, (e) a "matcher" key
      # for the new "verdict-recovery" SubagentStart entry or empty-matcher
      # SessionStart entry, (f) a "hooks": [ array-open line, or (g) a "SessionStart": [
      # top-level key line. Allowlist tokens are anchored to specific JSON-key shapes
      # to prevent unrelated lines from slipping through (CR-iter2 NIT tightening,
      # caveman-skill-integration extension). Also allows the WorktreeCreate-hook
      # removal (fix/worktree-create-contract): the prepare-worktree.sh "command" line,
      # the "WorktreeCreate": [ event-key line, and the empty "args": [] array line.
      # Also allows the plugin-equivalence Part 5 (P2) SessionStart context-injection hook:
      # the inject-kit-context.sh "command" line (plugin-mode-only, no-op in project mode).
      # Also allows the Option-B removal of block-dangerous-commands.sh (audit
      # operation-blocking-native-permissions): its PreToolUse Bash group's "command" line
      # and the "matcher": "Bash" line (the kit no longer ships a deny-emitting operation hook).
      # Also allows the matcher forward-compat hardening (CC 2.1.195): SubagentStart/SubagentStop
      # "matcher" lines in bare OR (claude-kit:)?-namespaced form, incl. the SubagentStop alternation.
      # Also allows the removal of the two Go import-matrix type:prompt PreToolUse hooks
      # (non-generic outlier — see .claude/workflow-feature-2026-06-29.md): the "matcher":"Write|Edit"
      # group line, the "type":"prompt" / "prompt":"You are a Go architecture import matrix enforcer..."
      # / "if":"(Write|Edit)(internal/**/*.go)" / "timeout":N lines. The test-no-prompt-hooks.sh guard
      # forbids any type:prompt hook from reappearing, so allowlisting these removal lines is safe.
      bad_lines=$(grep -E '^[+-]' /tmp/c5-settings-diff.txt \
        | grep -vE '^(\+\+\+|---) ' \
        | grep -vE '^[+-][[:space:]]+"command":[[:space:]]+"\.claude/scripts/auto-fmt(-go)?\.sh",?$|^[+-][[:space:]]+"if":[[:space:]]+"(Write|Edit)\(\*\*/\*\.go\)"$|^[+-][[:space:]]+"type":[[:space:]]+"command",?$|^[+-][[:space:]]*[][}{,]+[[:space:]]*$|^[+-][[:space:]]+"command":[[:space:]]+"\.claude/scripts/caveman-(activate\.sh|suspend-for-reviewer\.sh (code-researcher|plan-reviewer|code-reviewer|verdict-recovery))",?$|^[+-][[:space:]]+"matcher":[[:space:]]+"",?$|^[+-][[:space:]]+"matcher":[[:space:]]+"verdict-recovery",?$|^[+-][[:space:]]+"hooks":[[:space:]]+\[$|^[+-][[:space:]]+"SessionStart":[[:space:]]+\[$|^[+-][[:space:]]+"WorktreeCreate":[[:space:]]+\[$|^[+-][[:space:]]+"command":[[:space:]]+"\.claude/scripts/prepare-worktree\.sh",?$|^[+-][[:space:]]+"command":[[:space:]]+"\.claude/scripts/inject-kit-context\.sh",?$|^[+-][[:space:]]+"command":[[:space:]]+"\.claude/scripts/bootstrap-project-config\.sh",?$|^[+-][[:space:]]+"args":[[:space:]]+\[\],?$|^[+-][[:space:]]+"command":[[:space:]]+"\.claude/scripts/block-dangerous-commands\.sh",?$|^[+-][[:space:]]+"matcher":[[:space:]]+"Bash",?$|^[+-][[:space:]]+"matcher":[[:space:]]+"(\(claude-kit:\)\?)?(code-researcher|plan-reviewer|code-reviewer|verdict-recovery)",?$|^[+-][[:space:]]+"matcher":[[:space:]]+"(\(claude-kit:\)\?\()?plan-reviewer\|code-reviewer\|verdict-recovery\)?",?$|^[+-][[:space:]]+"matcher":[[:space:]]+"Write\|Edit",?$|^[+-][[:space:]]+"type":[[:space:]]+"prompt",?$|^[+-][[:space:]]+"prompt":[[:space:]]+"You are a Go architecture import matrix enforcer.*$|^[+-][[:space:]]+"if":[[:space:]]+"(Write|Edit)\(internal/\*\*/\*\.go\)",?$|^[+-][[:space:]]+"timeout":[[:space:]]+[0-9]+,?$' \
        || true)
      if [[ -n "$bad_lines" ]]; then
        fail "AC-C5.13 — .claude/settings.json has changes outside the allowlist (auto-fmt-generic consolidation OR caveman-skill-integration hook entries OR WorktreeCreate-hook removal OR block-dangerous-commands.sh removal)"
      fi
    fi
    rm -f /tmp/c5-settings-diff.txt
    pass "AC-C5.13 — settings.json diff (if any) limited to allowlist (auto-fmt-generic + caveman-skill-integration + WorktreeCreate-removal + block-dangerous-removal entries)"

    # handoff.schema.json: post-P1 refactor allows additive changes; discriminator-frozen invariant.
    git diff "$BASE"..HEAD -- .claude/schemas/handoff.schema.json > /tmp/c5-schema-diff.txt 2>&1 || true
    if [[ -s /tmp/c5-schema-diff.txt ]]; then
      BASE_DISC=$(git show "$BASE":.claude/schemas/handoff.schema.json 2>/dev/null \
        | grep -oE '"const": *"(planner_to_plan_review|plan_review_to_coder|coder_to_code_review|plan_review_verdict|code_review_verdict)"' | sort -u || echo "")
      HEAD_DISC=$(grep -oE '"const": *"(planner_to_plan_review|plan_review_to_coder|coder_to_code_review|plan_review_verdict|code_review_verdict)"' .claude/schemas/handoff.schema.json | sort -u || echo "")
      if [[ "$BASE_DISC" != "$HEAD_DISC" ]]; then
        fail "AC-C5.14 — discriminator contract broken (additive-only allowed)"
      fi
      label "INFO" "AC-C5.14 — schema modified but discriminator contracts preserved (additive change accepted)"
    fi
    rm -f /tmp/c5-schema-diff.txt
    # PROJECT-KNOWLEDGE.md.example: same auto-fmt-generic FMT_CMD doc-extension allowance as AC-C4.6
    # PK.example: anchored auto-fmt-generic FMT_CMD doc-extension allowance (matches AC-C4.6;
    # CR-iter2 NIT tightening — restrict to slot line + comment-continuation only).
    git diff "$BASE"..HEAD -- .claude/PROJECT-KNOWLEDGE.md.example > /tmp/c5-pk-diff.txt 2>&1 || true
    if [[ -s /tmp/c5-pk-diff.txt ]]; then
      bad_lines=$(grep -E '^[+-]' /tmp/c5-pk-diff.txt \
        | grep -vE '^(\+\+\+|---) ' \
        | grep -vE '^[+-]- FMT_CMD:|^[+-][[:space:]]+#' \
        || true)
      if [[ -n "$bad_lines" ]]; then
        fail "AC-C5.15 — .claude/PROJECT-KNOWLEDGE.md.example has changes outside FMT_CMD slot/comment scope"
      fi
    fi
    rm -f /tmp/c5-pk-diff.txt
    pass "AC-C5.14/15 — handoff schema unchanged; PK.example diff (if any) limited to auto-fmt-generic FMT_CMD doc"

    git diff "$BASE"..HEAD -- .claude/scripts/inject-review-context.sh > /tmp/c5-inject-diff.txt 2>&1 || true
    if [[ -s /tmp/c5-inject-diff.txt ]]; then
      # Content-aware: stdout JSON contract preserved (additionalContext key present).
      # The C6 contract was the output SHAPE + PK injection 4KB cap — runtime tests assert these.
      label "INFO" "AC-C5.16 — inject-review-context.sh modified; runtime contracts asserted by test-state-render-golden, test-additional-context-cap-6k, test-worktree-injection-sidecar"
    fi
    rm -f /tmp/c5-inject-diff.txt
    pass "AC-C5.16 — inject-review-context.sh output contract intact"
  fi
fi

# Bonus: troubleshooting.md GENERATED/MOCKS slot reference
grep -q '{GENERATED_PATTERN}/{MOCK_PATTERN}' "$SCOPE_TROUBLESHOOTING" \
  || fail "AC-C5 (bonus) — coder-rules/troubleshooting.md does not reference GENERATED_PATTERN/MOCK_PATTERN slots"
pass "AC-C5 (bonus) — troubleshooting.md references GENERATED/MOCKS slots"

# ════════════════════════════════════════════════════════════════════════
# MANUAL (operator procedure)
# ════════════════════════════════════════════════════════════════════════
# AC-C5.10: PK > CLAUDE.md fallback resolution behavior
#   Procedure: configure PROJECT-KNOWLEDGE.md with DOMAIN_PROHIBIT slot,
#   confirm consumer (coder/reviewer) reads PK value, not CLAUDE.md fallback.
#   Then unset slot, confirm CLAUDE.md fallback used.
#
# AC-C5.11: PK+CLAUDE.md missing → SKIP-with-consolidated-NIT
#   Procedure: remove both PK and CLAUDE.md slot definitions for any C5 slot,
#   confirm consumer emits ONE consolidated NIT in VERDICT_JSON, no false BLOCKER.
#
# AC-C5.12: Kit-dogfood verdict-enum-stable regression
#   Kit has DOMAIN_PROHIBIT/ERROR_WRAP/GENERATED/MOCK/CONFIG_* all populated in PK
#   (or CLAUDE.md fallback). Verify code-reviewer verdict ENUM stable on kit fixture.
#   Note: C5 alone does NOT trigger new NITs on kit; only C3+C4 do (kit ARCHITECTURE_STYLE='other').

label "INFO" "test-c5-slot-consumption.sh complete — 13/16 AC automated (AC-C5.10/11/12 manual)"
exit 0
