#!/usr/bin/env bash
# test-caveman-upstream-parity.sh — guards the level-agnostic rules vendored from
# upstream juliusbrussee/caveman (fork base b6a7a3f 2026-04-11 -> HEAD 0d95a81 2026-07-03).
#
# Rationale: these rules are RE-PHRASED for kit-safety, NOT copy-pasted, because upstream's
# wording collides with two kit invariants — CLAUDE.md mandates English for artifact specs,
# and the kit depends on informational tables that upstream's no-decorative-tables rule would
# suppress. A textual diff against upstream would therefore false-positive. Guard on the
# decisive CONCEPT markers instead.
#
# Also enforces the lite-only invariant and the AC-8 token budget: the body is injected at
# every SessionStart, so unbounded growth is self-defeating for a token-efficiency skill.
#
# Exit code: 0 all pass, 1 any fail. Uses rc=1 propagation (never `|| break`, which swallows
# exit codes).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SKILL_FILE="${REPO_ROOT}/.claude/skills/caveman/SKILL.md"

rc=0
PASS=0
FAIL=0
SKIPPED=0

if [[ ! -f "${SKILL_FILE}" ]]; then
  echo "[test-caveman-upstream-parity] FAIL: SKILL.md not found at ${SKILL_FILE}"
  exit 1
fi

# Markers are matched against a WHITESPACE-FLATTENED copy of the body, so a line
# wrap that splits a marker phrase across two lines cannot silently break the guard.
SKILL_FLAT="$(tr '\n' ' ' < "${SKILL_FILE}" | tr -s ' ')"

check() {
  local label="$1" pattern="$2"
  if printf '%s' "${SKILL_FLAT}" | grep -qiE -- "${pattern}"; then
    echo "  PASS: ${label}"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: ${label} — pattern not found: ${pattern}"
    FAIL=$((FAIL + 1))
    rc=1
  fi
}

echo "── A) upstream rules vendored (concept markers) ──"
# GAP-1 (upstream f06348c) — language preservation, SCOPED to conversational prose.
check "GAP-1 language preservation"          "dominant language"
check "GAP-1 scoped to conversational prose" "conversational prose"
check "GAP-1 artifacts excluded"             "stay English"
# GAP-2 (upstream f06348c) — no self-reference / no dual output.
check "GAP-2 no self-reference"              "self-reference"
check "GAP-2 no dual output recap"           "recap"
# GAP-5 (upstream f06348c) — output hygiene, kit-scoped.
check "GAP-5a no tool-call narration"        "tool-call narration"
check "GAP-5b no decorative tables/emoji"    "decorative table"
check "GAP-5b informational-table carve-out" "informational table"
check "GAP-5c shortest decisive error line"  "shortest decisive"
# GAP-3 (upstream dc95e91) — measured-zero-saving anti-patterns.
check "GAP-3 no invented abbreviations"      "abbreviation"
check "GAP-3 no causal arrows"               "arrow"
# GAP-4 (upstream 31d804e) — Auto-Clarity expansion.
check "GAP-4 ambiguity trigger"              "ambiguity"
check "GAP-4 omitted conjunctions"           "omitted conjunction"

echo "── B) lite-only invariant intact ──"
# Non-lite levels permit sentence fragments inside hash-bound text fields, which would
# corrupt the canonical issue ID sha256(category|location|problem)[:8] across iterations.
if grep -qE '^\| \*\*(full|ultra|wenyan)' "${SKILL_FILE}"; then
  echo "  FAIL: a non-lite intensity row is present — lite-only invariant broken"
  FAIL=$((FAIL + 1))
  rc=1
else
  echo "  PASS: no non-lite intensity rows"
  PASS=$((PASS + 1))
fi

if grep -qF 'disable-model-invocation: true' "${SKILL_FILE}"; then
  echo "  PASS: disable-model-invocation retained (SessionStart injection only)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: disable-model-invocation missing"
  FAIL=$((FAIL + 1))
  rc=1
fi

echo "── C) KD-5: at least one worked lite example retained ──"
# Upstream caveman-activate.js:39-42 records that a bare summary was too weak and models
# drifted back to verbose mid-conversation. Examples are load-bearing anchors, not decoration.
if grep -qE '^- lite: ' "${SKILL_FILE}"; then
  echo "  PASS: worked lite example present"
  PASS=$((PASS + 1))
else
  echo "  FAIL: no worked lite example (KD-5 — examples anchor behavior)"
  FAIL=$((FAIL + 1))
  rc=1
fi

echo "── D) AC-8 token budget (<= 1000; pre-change baseline was 956) ──"
# This check is the ONLY enforcement of the injected-body cost cap. If it is skipped
# it MUST NOT read as success — a guard that reports "0 failed" while enforcing nothing is
# worse than no guard, because it manufactures false confidence. Per the kit's soft-prereq
# convention the skip stays non-blocking (rc unchanged), but it is counted and surfaced in
# the summary line so "budget NOT enforced" is impossible to miss.
tok=""
if command -v uv >/dev/null 2>&1; then
  tok=$(SKILL_FILE="${SKILL_FILE}" uv run --quiet --with tiktoken python - <<'PYEOF' 2>/dev/null || echo ""
import os, tiktoken
src = open(os.environ["SKILL_FILE"]).read()
body = "---".join(src.split("---")[2:])
print(len(tiktoken.get_encoding("o200k_base").encode(body)))
PYEOF
  )
fi

if [[ ! "${tok}" =~ ^[0-9]+$ ]]; then
  echo "  SKIP: uv/tiktoken unavailable — AC-8 TOKEN BUDGET NOT ENFORCED THIS RUN"
  echo "        Install uv to enforce it: https://astral.sh/uv"
  SKIPPED=$((SKIPPED + 1))
elif [[ "${tok}" -le 1000 ]]; then
  echo "  PASS: injected body ${tok} tokens (<= 1000, headroom $((1000 - tok)))"
  PASS=$((PASS + 1))
else
  echo "  FAIL: injected body ${tok} tokens exceeds the AC-8 budget of 1000 (over by $((tok - 1000)))"
  echo "        The body is injected at EVERY SessionStart, so growth is a recurring cost."
  echo "        FIX BY TIGHTENING PROSE OR RECLAIMING DUPLICATION — do not raise the cap."
  echo "        Prose duplicated in the always-loaded CLAUDE.md is the cheapest reclaim."
  FAIL=$((FAIL + 1))
  rc=1
fi

summary="─── caveman-upstream-parity: ${PASS} passed, ${FAIL} failed"
if [[ "${SKIPPED}" -gt 0 ]]; then
  summary="${summary}, ${SKIPPED} SKIPPED (token budget NOT enforced)"
fi
echo "${summary} ───"
exit ${rc}
