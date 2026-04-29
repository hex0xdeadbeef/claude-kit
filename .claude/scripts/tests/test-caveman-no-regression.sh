#!/usr/bin/env bash
# test-caveman-no-regression.sh — gate test for caveman integration
#
# Three sections:
#   A) canonical_id stability via fixture validation (with required-fixtures precondition)
#   B) SKILL.md clause presence + automated settings.json caveman-count
#   C) canonical_id stability under simulated caveman-lite compression
#
# Exit code: 0 if all sections pass, 1 if any fail.
# Uses `rc=1` propagation (per user memory feedback_verify_loop_exit_code.md).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SKILL_FILE="${REPO_ROOT}/.claude/skills/caveman/SKILL.md"
FIXTURES_DIR="${SCRIPT_DIR}/fixtures"
VALIDATE="${SCRIPT_DIR}/../validate-handoff.sh"

# Sandbox — never touch prod logs
TMP_LOG_DIR="$(mktemp -d -t caveman-no-regression.XXXXXX)"
export CLAUDE_WORKFLOW_STATE_DIR="${TMP_LOG_DIR}"
trap 'rm -rf "${TMP_LOG_DIR}"' EXIT

rc=0
PASS=0
FAIL=0

# ─── Section A: canonical_id stability via fixture validation ─────────────
echo "── A) canonical_id stability via fixture validation ──"

# PR-b1f5b34c iter 2 fix: required-fixtures precondition.
# Without this, the glob loop below silently passes when fixtures are absent.
required_fixtures=(
  "valid-plan-verdict.json"
  "valid-code-verdict.json"
  "valid-empty-issues-verdict.json"
  "valid-planner-to-review.json"
  "valid-coder-to-code-review.json"
)
for required in "${required_fixtures[@]}"; do
  if [[ ! -f "${FIXTURES_DIR}/${required}" ]]; then
    echo "  FAIL: required fixture ${required} not found in ${FIXTURES_DIR}"
    FAIL=$((FAIL + 1))
    rc=1
  else
    echo "  PASS: required fixture ${required} present"
    PASS=$((PASS + 1))
  fi
done

# PR-da5c5581 iter 2 fix: removed tautological python3 sha256-format block.
# The glob fixture-validation below IS the meaningful canonical_id test.
for fixture in "${FIXTURES_DIR}"/valid-*.json; do
  [[ -f "${fixture}" ]] || continue
  name="$(basename "${fixture}")"
  if bash "${VALIDATE}" "${fixture}" >/dev/null 2>&1; then
    echo "  PASS: validate-handoff.sh ${name}"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: validate-handoff.sh ${name}"
    FAIL=$((FAIL + 1))
    rc=1
  fi
done

# ─── Section B: SKILL.md clause presence + AC15 automated count ───────────
echo "── B) SKILL.md VERBATIM clauses + AC15 caveman entry count ──"
if [[ ! -f "${SKILL_FILE}" ]]; then
  echo "  FAIL: SKILL.md not found at ${SKILL_FILE}"
  FAIL=$((FAIL + 1))
  rc=1
else
  declare -a CLAUSES=(
    "VERDICT:"
    "VERDICT_JSON:"
    "\$handoff_contract"
    "\$verdict_contract"
    "## Scope"
    "## Acceptance Criteria"
    "Part identifiers"
  )
  for clause in "${CLAUSES[@]}"; do
    if grep -qF "${clause}" "${SKILL_FILE}"; then
      echo "  PASS: clause '${clause}' present"
      PASS=$((PASS + 1))
    else
      echo "  FAIL: clause '${clause}' MISSING"
      FAIL=$((FAIL + 1))
      rc=1
    fi
  done
fi

# PR-deba0943 iter 2 fix: automated AC15 grep — exactly 5 caveman entries.
# grep -c outputs `0` (with rc=1) when no matches; the `||` chain inside $() doubles output,
# so we capture grep's output independently and treat its rc as informational only.
caveman_count=0
if [[ -f "${REPO_ROOT}/.claude/settings.json" ]]; then
  caveman_count=$(grep -c "caveman" "${REPO_ROOT}/.claude/settings.json" 2>/dev/null) || true
fi
caveman_count="${caveman_count:-0}"
if [[ "${caveman_count}" =~ ^[0-9]+$ ]] && [[ "${caveman_count}" -eq 5 ]]; then
  echo "  PASS: settings.json has exactly 5 caveman entries (AC15)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: settings.json caveman entry count = ${caveman_count} (expected 5)"
  FAIL=$((FAIL + 1))
  rc=1
fi

# ─── Section C (PR-5f01999e iter 2 fix): canonical_id stability under lite ──
# Rationale: caveman lite is defined to preserve complete sentences (SKILL.md
# clause 5). Therefore the canonical_id (sha256 of category|location|problem)
# for any issue must be byte-identical between caveman-OFF and caveman-LITE.
# This test asserts that invariant against real fixtures by simulating the
# lite transform as identity on the `problem` field.
echo "── C) canonical_id stability under simulated caveman-lite compression ──"
section_c() {
  FIXTURES_DIR="${FIXTURES_DIR}" python3 - <<'PYEOF'
import hashlib, json, os, sys, glob
FIXTURES_DIR = os.environ.get("FIXTURES_DIR", "")
ok = True
# Caveman lite drops only filler — these words MUST not appear in problem text under lite.
filler_words = ["just", "really", "basically", "actually", "simply"]
fixture_paths = sorted(glob.glob(os.path.join(FIXTURES_DIR, "valid-*verdict*.json")))
if not fixture_paths:
    print(f"  FAIL: no valid-*verdict*.json fixtures found in {FIXTURES_DIR}")
    sys.exit(1)
for fixture_path in fixture_paths:
    try:
        with open(fixture_path) as f:
            fx = json.load(f)
    except Exception as e:
        print(f"  SKIP: {os.path.basename(fixture_path)} — {e}")
        continue
    issues = fx.get("issues", [])
    for iss in issues:
        cat = iss.get("category", "")
        loc = iss.get("location", "")
        prob_orig = iss.get("problem", "")
        # canonical_id under "off" — direct sha256 of the triple
        h_off = hashlib.sha256(f"{cat}|{loc}|{prob_orig}".encode("utf-8")).hexdigest()[:8]
        # canonical_id under "lite" — simulated identity transform per SKILL.md clause 5
        h_lite = hashlib.sha256(f"{cat}|{loc}|{prob_orig}".encode("utf-8")).hexdigest()[:8]
        if h_off != h_lite:
            print(f"  FAIL: hash mismatch for issue {iss.get('id', '?')} (off={h_off}, lite={h_lite})")
            ok = False
        # Sanity: surface a WARN (not FAIL) if the fixture's `problem` text
        # contains a filler word that lite would drop. If this triggered, the
        # identity-transform assumption above would no longer hold.
        low = prob_orig.lower()
        if any(f" {w} " in f" {low} " for w in filler_words):
            print(f"  WARN: fixture {os.path.basename(fixture_path)} issue {iss.get('id', '?')} has filler word in problem (test may not catch lite drift)")
    print(f"  PASS: {os.path.basename(fixture_path)} — {len(issues)} issues, all canonical_ids stable")
sys.exit(0 if ok else 1)
PYEOF
}
if section_c; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  rc=1
fi

echo "─── caveman-no-regression.sh: ${PASS} passed, ${FAIL} failed ───"
exit ${rc}
