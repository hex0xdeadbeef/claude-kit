#!/usr/bin/env bash
# test-caveman-honest-claim.sh — guards against asserting an unmeasured savings
# figure for caveman `lite`.
#
# Grounds (verified in upstream juliusbrussee/caveman @ 0d95a81):
#   - src/hooks/caveman-stats.js:19    -> const COMPRESSION = { 'full': 0.65 };
#   - src/hooks/caveman-stats.js:16-17 -> "Only 'full' has measured data; lite / ultra /
#                                          wenyan modes show no estimate until benchmarked."
#   - No `lite` arm exists in upstream evals/ or benchmarks/.
# Therefore ANY numeric savings figure for `lite` is fabricated, in this repo or upstream.
#
# Design note (why the pattern is broad): CLAIM_RE keeps its prefix group OPTIONAL on
# purpose, so it matches ANY `N%` inside the scanned regions. A required prefix would match
# `>=20%` and `~30-40%` but would still MISS a bare "lite saves 30%" — the exact shape being
# guarded. The cost is that the scanned regions may contain NO percent figures at all; the
# prose is written accordingly ("the 0.65 output-only ratio", "a hypothetical one-fifth
# output saving"). Invariant: the caveman policy section contains zero percent figures.
#
# Exit code: 0 all pass, 1 any fail. Uses rc=1 propagation.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
CLAUDE_MD="${REPO_ROOT}/CLAUDE.md"

rc=0
PASS=0
FAIL=0

if [[ ! -f "${CLAUDE_MD}" ]]; then
  echo "[test-caveman-honest-claim] FAIL: CLAUDE.md not found at ${CLAUDE_MD}"
  exit 1
fi

# Matches: ">=20%", "≥20%", "~30-40%", "about 25 %", and bare "30%".
CLAIM_RE='(≥|>=|~|approx\.?|about)?[[:space:]]*[0-9]+([[:space:]]*[-–][[:space:]]*[0-9]+)?[[:space:]]*%'

# Scope to the caveman policy section — a whole-file %-grep would false-positive on the
# Prompt Cache Policy (~50% cache-miss) and Conventions (>80% YAML) sections.
section=$(awk '/^## Caveman Token Compression Policy/,/^## Error Handling/' "${CLAUDE_MD}")
if [[ -z "${section}" ]]; then
  echo "  FAIL: '## Caveman Token Compression Policy' section not found"
  exit 1
fi
echo "  PASS: caveman policy section present"
PASS=$((PASS + 1))

echo "── A) no numeric savings claim in the CLAUDE.md caveman section ──"
if echo "${section}" | grep -qE "${CLAIM_RE}"; then
  echo "  FAIL: caveman policy section carries a numeric claim (lite is unbenchmarked)"
  echo "${section}" | grep -nE "${CLAIM_RE}" | head -3
  FAIL=$((FAIL + 1))
  rc=1
else
  echo "  PASS: zero percent figures in the caveman policy section"
  PASS=$((PASS + 1))
fi

echo "── B) no numeric savings claim in the README lite rows ──"
# Scoped to the `lite` intensity row: a whole-file sweep would false-positive on unrelated
# README figures. Both rows match this anchor (README.md:677, README.ru.md:679).
for rme in "${REPO_ROOT}/README.md" "${REPO_ROOT}/README.ru.md"; do
  base="$(basename "${rme}")"
  if [[ ! -f "${rme}" ]]; then
    echo "  FAIL: ${base} not found — expected a lite intensity row to guard"
    FAIL=$((FAIL + 1)); rc=1; continue
  fi
  row=$(grep -nE '^\| `lite`' "${rme}" || true)
  if [[ -z "${row}" ]]; then
    echo "  FAIL: ${base} — no lite intensity row found (anchor drifted; guard would silently skip)"
    FAIL=$((FAIL + 1)); rc=1; continue
  fi
  if echo "${row}" | grep -qE "${CLAIM_RE}"; then
    echo "  FAIL: ${base} lite row asserts a numeric savings claim:"
    echo "${row}" | head -1
    FAIL=$((FAIL + 1)); rc=1
  else
    echo "  PASS: ${base} lite row carries no numeric savings claim"
    PASS=$((PASS + 1))
  fi
done

echo "── C) honesty markers present in the caveman policy section ──"
for marker in "unbenchmarked|not benchmarked|no .*benchmark" "A/B"; do
  if echo "${section}" | grep -qiE "${marker}"; then
    echo "  PASS: marker present — ${marker}"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: marker missing — ${marker}"
    FAIL=$((FAIL + 1)); rc=1
  fi
done

echo "── D) H2 heading preserved (test-claude-md-audit-postcondition contract) ──"
if grep -qF '## Caveman Token Compression Policy' "${CLAUDE_MD}"; then
  echo "  PASS: H2 heading intact"
  PASS=$((PASS + 1))
else
  echo "  FAIL: H2 heading missing"
  FAIL=$((FAIL + 1)); rc=1
fi

echo "── E) no unsubstituted measurement placeholders shipped ──"
# The plan writes {MEASURED}/{BREAKEVEN} as placeholders, substituted from the POST-change
# measurement. Without this guard a literal placeholder passes A-D undetected.
ph_fail=0
for ph in '{MEASURED}' '{BREAKEVEN}'; do
  if grep -qF -- "${ph}" "${CLAUDE_MD}"; then
    echo "  FAIL: literal placeholder ${ph} shipped — substitute the measured value"
    ph_fail=1
  fi
done
if [[ "${ph_fail}" -eq 0 ]]; then
  echo "  PASS: no literal {MEASURED}/{BREAKEVEN} in CLAUDE.md"
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1)); rc=1
fi

echo "─── caveman-honest-claim: ${PASS} passed, ${FAIL} failed ───"
exit ${rc}
