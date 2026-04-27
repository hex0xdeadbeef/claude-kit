#!/usr/bin/env bash
# test-c2-verify-cascade.sh
#
# Asserts AC-C2.1..AC-C2.10 from .claude/prompts/coder-code-review-generic-analysis.md §8 C2
# Tests Part 1 (C2 — VERIFY/QUICK CHECK cascade slot-driven)

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

# AC-C2.1 (partial): Go-specific commands appear ONLY inside example/CLAUDE.md fallback context
# The literals are still allowed in:
#   - 'Go example:' / 'Go default:' parenthetical labels (CLAUDE.md fallback path)
#   - kit-dogfood example sections explicitly labeled
# Strict assertion: no bare `go vet` outside contextualized labels.
# Approximation: grep for the unconditional pre-fix patterns (the cascade fallback that bypassed PK)
if grep -F 'Use Go-native: go fmt ./... && go vet ./... && go test ./...' .claude/commands/coder.md 2>/dev/null; then
  fail "AC-C2.1 — pre-fix Go-only fallback ('Use Go-native:') still present in coder.md verify_startup"
fi
if grep -F 'Use make-based: go vet ./... && make fmt && make lint && make test' .claude/commands/coder.md 2>/dev/null; then
  fail "AC-C2.1 — pre-fix Makefile→Go-only branch ('Use make-based:') still present in coder.md verify_startup"
fi
pass "AC-C2.1 — pre-fix Go-only fallback chain replaced with slot-driven cascade"

# AC-C2.2: cascade has 5 expected steps in order
grep -q 'PROJECT-KNOWLEDGE.md exists AND defines VERIFY_CMD' .claude/commands/coder.md \
  || fail "AC-C2.2 — cascade step 1 (PK→VERIFY_CMD) missing in coder.md"
grep -q 'PROJECT-KNOWLEDGE.md exists AND defines individual FMT_CMD/LINT_CMD/TEST_CMD' .claude/commands/coder.md \
  || fail "AC-C2.2 — cascade step 2 (PK→individual slots) missing in coder.md"
grep -q 'CLAUDE.md Language Profile defines VERIFY entry' .claude/commands/coder.md \
  || fail "AC-C2.2 — cascade step 3 (CLAUDE.md fallback) missing in coder.md"
grep -q 'DEPENDENCY_FILE detected.*VERIFY_CMD unset' .claude/commands/coder.md \
  || fail "AC-C2.2 — cascade step 4 (DEPENDENCY_FILE-aware WARN) missing in coder.md"
grep -q 'verify_status: SKIPPED' .claude/commands/coder.md \
  || fail "AC-C2.2 — cascade step 5 (SKIP-with-consolidated-NIT) missing in coder.md"
pass "AC-C2.2 — verify_startup cascade has 5 expected steps"

# AC-C2.3: VET phase removed/parameterized (not present as separate command)
if grep -F 'command: "VET (go vet ./..' .claude/commands/coder.md 2>/dev/null; then
  fail "AC-C2.3 — VET phase still hardcoded as separate Go-specific command"
fi
if grep -F '[x] VET (go vet ./...)' .claude/commands/coder.md 2>/dev/null; then
  fail "AC-C2.3 — output_format still includes literal '[x] VET (go vet ./...)' instead of resolved VERIFY"
fi
pass "AC-C2.3 — VET phase removed/parameterized"

# AC-C2.4: code-review-rules SKILL.md L34 + code-reviewer.md QUICK CHECK use slot references
grep -q '{LINT_CMD}.*{TEST_CMD}\|{LINT_CMD}.*PROJECT-KNOWLEDGE' .claude/skills/code-review-rules/SKILL.md \
  || fail "AC-C2.4a — code-review-rules SKILL.md missing slot references for LINT/TEST"
grep -q '{LINT_CMD}\|{TEST_CMD}' .claude/agents/code-reviewer.md \
  || fail "AC-C2.4b — code-reviewer.md QUICK CHECK missing slot references"
pass "AC-C2.4 — QUICK CHECK uses slot-resolved commands"

# AC-C2.5: coder-rules/SKILL.md uses resolved VERIFY_CMD reference
grep -q 'resolved command\|verify_startup cascade' .claude/skills/coder-rules/SKILL.md \
  || fail "AC-C2.5 — coder-rules/SKILL.md does not reference resolved VERIFY_CMD"
pass "AC-C2.5 — coder-rules/SKILL.md references resolved VERIFY_CMD"

# AC-C2.9: handoff schema unchanged (C1) — pre-merge gate (see CR-003)
if [[ -d .git ]]; then
  CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
  if [[ "$CURRENT_BRANCH" == "main" ]]; then
    label "INFO" "AC-C2.9 — skipped (running on main; pre-merge gate only)"
  else
    BASE="$(git merge-base HEAD origin/main 2>/dev/null || echo main)"
    git diff "$BASE"..HEAD -- .claude/schemas/handoff.schema.json > /tmp/c2-handoff-diff.txt 2>&1 || true
    if [[ -s /tmp/c2-handoff-diff.txt ]]; then
      fail "AC-C2.9 — handoff.schema.json was modified (C1 contract preservation violated)"
    fi
    rm -f /tmp/c2-handoff-diff.txt
    pass "AC-C2.9 — handoff schema unchanged"
  fi
fi

# ════════════════════════════════════════════════════════════════════════
# MANUAL (operator procedure)
# ════════════════════════════════════════════════════════════════════════
# AC-C2.6 (REVISED per PR-002): kit's actual VERIFY_CMD = "bash .claude/scripts/tests/test-*.sh"
#   (NOT the Go literal from spec). Verify resolution at PK step-1 returns kit's value.
#   Procedure: read PROJECT-KNOWLEDGE.md L37, confirm VERIFY_CMD = "bash .claude/scripts/tests/test-*.sh".
#   Run /coder on kit fixture, confirm verify_status.command_used matches PK value.
#
# AC-C2.7: CLAUDE.md fallback path
#   Procedure: temporarily move PROJECT-KNOWLEDGE.md aside, run /coder verify_startup,
#   confirm cascade falls through to CLAUDE.md → kit-default Go command.
#
# AC-C2.8: Hard test on non-Go fixture (Python)
#   Procedure:
#     mkdir /tmp/test-py-fixture && cd /tmp/test-py-fixture
#     touch pyproject.toml
#     # Run /coder verify_startup
#     # Expected: WARN message contains 'pyproject.toml' AND INSTALL_VERB hint, no go-* literal
#
# AC-C2.10: pre-commit-build.sh stays Go-specific (out of scope per spec §3.2 R5)

label "INFO" "test-c2-verify-cascade.sh complete — 6/10 AC automated (AC-C2.6/7/8/10 manual)"
exit 0
