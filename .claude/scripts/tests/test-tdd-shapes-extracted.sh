#!/usr/bin/env bash
# test-tdd-shapes-extracted.sh
#
# Asserts TD-1..TD-5 from .claude/prompts/tdd-skill-generic-spec.md §5.5
# Tests T1+T3: tdd-rules skill structure and tdd-shapes/<LANGUAGE>.md catalogue.
# Mirror of test-p1-code-shapes-extracted.sh (P1 reference pattern).
#
# Coverage: 5 automated ACs (TD-1 file presence, TD-2 invariants ref, TD-3 selector,
# TD-4 coder integration, TD-5 cross-refs cleanup).

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

# TD-1: tdd-rules skill exists with 7 tdd-shapes files (5 langs + _default + INVARIANTS)
[[ -f .claude/skills/tdd-rules/SKILL.md ]] \
  || fail "TD-1 — .claude/skills/tdd-rules/SKILL.md missing (T1.1, T1.2)"
[[ -f .claude/skills/tdd-rules/examples.md ]] \
  || fail "TD-1 — .claude/skills/tdd-rules/examples.md missing (T3.1)"
for shape in go.md python.md typescript.md rust.md java.md _default.md INVARIANTS.md; do
  [[ -f .claude/skills/tdd-rules/tdd-shapes/${shape} ]] \
    || fail "TD-1 — tdd-shapes/${shape} missing (T1.3 ships 5 langs + _default + INVARIANTS)"
done
pass "TD-1 — tdd-rules skeleton present (SKILL.md + examples.md + 7 tdd-shapes files)"

# TD-2: each tdd-shapes/<LANGUAGE>.md illustrates Red-Green-Refactor cycle
# Predicate: each file references RED-GREEN-REFACTOR keywords + scenario marker
for lang in go python typescript rust java _default; do
  f=".claude/skills/tdd-rules/tdd-shapes/${lang}.md"
  if ! grep -qE 'RED|Red.*Green.*Refactor|Cycle 1' "$f" 2>/dev/null; then
    fail "TD-2 — tdd-shapes/${lang}.md missing Red-Green-Refactor cycle markers (T1.5 invariant 1)"
  fi
done
# INVARIANTS.md must declare the 3 invariants and the adding-a-language recipe
grep -qE 'three invariants|three TDD invariants|The three invariants' \
     .claude/skills/tdd-rules/tdd-shapes/INVARIANTS.md \
  || fail "TD-2 — INVARIANTS.md missing 'three invariants' anchor (T1.5)"
grep -q 'Adding a new language' .claude/skills/tdd-rules/tdd-shapes/INVARIANTS.md \
  || fail "TD-2 — INVARIANTS.md missing 'Adding a new language' recipe (T1.5)"
pass "TD-2 — all 6 tdd-shapes/<lang>.md illustrate Red-Green-Refactor + INVARIANTS recipe present"

# TD-3: examples.md declares reference_shapes selector (T3.1)
grep -q 'reference_shapes:' .claude/skills/tdd-rules/examples.md \
  || fail "TD-3 — examples.md missing reference_shapes selector block (T3.1)"
# Selector must enumerate all 5 supported langs + _default fallback
for entry in 'go         → tdd-shapes/go.md' \
             'python     → tdd-shapes/python.md' \
             'typescript → tdd-shapes/typescript.md' \
             'rust       → tdd-shapes/rust.md' \
             'java       → tdd-shapes/java.md'; do
  grep -qF "$entry" .claude/skills/tdd-rules/examples.md \
    || fail "TD-3 — examples.md selector missing entry: ${entry}"
done
grep -qE 'any other / unset → tdd-shapes/_default\.md' .claude/skills/tdd-rules/examples.md \
  || fail "TD-3 — examples.md selector missing _default.md fallback entry (T3.4)"
pass "TD-3 — reference_shapes selector enumerates 5 langs + _default fallback"

# TD-4: coder.md integrates tdd-rules + references tdd-shapes/<LANGUAGE>.md
grep -q '\.claude/skills/tdd-rules/SKILL\.md' .claude/commands/coder.md \
  || fail "TD-4 — coder.md missing tdd-rules/SKILL.md reference (T2.1)"
grep -qE 'tdd-shapes/<LANGUAGE>\.md|tdd-shapes/[a-z_]+\.md' .claude/commands/coder.md \
  || fail "TD-4 — coder.md missing tdd-shapes path reference (T2.1)"
# Cascade block present (T3.6 single source of truth: coder.md mirrors tdd-rules/SKILL.md cascade)
awk '/Load TDD skill \(unconditional\)/,/^[[:space:]]+purpose:/' .claude/commands/coder.md \
  | grep -q 'cascade:' \
  || fail "TD-4 — coder.md TDD-load missing cascade block (T3.6)"
pass "TD-4 — coder.md integrates tdd-rules + cascade documented"

# TD-5: zero remaining 'tdd-go' references in CONSUMER active scope
# Predicate: grep for path-form ('tdd-go/' as directory reference) — catches stale skill loaders
# and cross-skill recommendations. Excludes:
#   - workflow-state/   — runtime state (historical)
#   - prompts/          — archived analyses (historical snapshots)
#   - tests/            — test scripts legitimately reference 'tdd-go' as anti-pattern
#                         (their grep predicates assert NONE exists)
# Path-form catches: references to 'tdd-go/SKILL.md', '.claude/skills/tdd-go/', etc.
# Bare-string is too noisy (matches grep patterns inside test scripts themselves).
STALE_REFS=$(grep -rln 'tdd-go/' .claude/ \
              --exclude-dir=workflow-state \
              --exclude-dir=prompts \
              --exclude-dir=tests 2>/dev/null || true)
if [[ -n "$STALE_REFS" ]]; then
  fail "TD-5 — stale 'tdd-go/' path references remain in active scope:\n${STALE_REFS}"
fi
# Also check root-level docs
if grep -lE 'tdd-go/?' README.md CLAUDE.md 2>/dev/null | head -1 | grep -q .; then
  fail "TD-5 — stale 'tdd-go' reference in README.md or CLAUDE.md"
fi
pass "TD-5 — no stale 'tdd-go/' path references in .claude/ active scope or root docs (T4.4)"

# ════════════════════════════════════════════════════════════════════════
# Negative-control note (manual / CI-runnable but destructive)
# ════════════════════════════════════════════════════════════════════════
# T5.4 — Negative-control verification:
#   Procedure: temporarily move tdd-shapes/python.md aside; this script MUST FAIL TD-1.
#     trap 'mv /tmp/python.md.bak .claude/skills/tdd-rules/tdd-shapes/python.md 2>/dev/null || true' EXIT
#     mv .claude/skills/tdd-rules/tdd-shapes/python.md /tmp/python.md.bak
#     bash .claude/scripts/tests/test-tdd-shapes-extracted.sh   # exits non-zero on TD-1
#     # restore happens automatically via trap
#   Verifies the test catches what it claims to catch.

label "INFO" "test-tdd-shapes-extracted.sh complete — 5/5 ACs automated (TD-1..TD-5)"
exit 0