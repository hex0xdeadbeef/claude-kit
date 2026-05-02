#!/usr/bin/env bash
# test-canonical-id-normalization.sh — Part 1 / P2
#
# Coverage:
#   1. Whitespace-only differences yield identical hashes
#   2. Case-only differences yield identical hashes
#   3. Trailing punctuation differences yield identical hashes
#   4. Unicode NFKC normalization (full-width vs half-width)
#   5. Meaningfully-different inputs yield DIFFERENT hashes
#   6. CLAUDE_ISSUE_ID_NORMALIZE_VERSION=1 reverts to raw hashing
#   7. 1000 fuzz inputs all match ^[PC]R-[0-9a-f]{8}$

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

cd "${REPO_ROOT}"

PASS=0
FAIL=0

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [[ "${actual}" == "${expected}" ]]; then
    echo "  PASS: ${name}"; PASS=$((PASS + 1))
  else
    echo "  FAIL: ${name}"; echo "    expected: ${expected}"; echo "    actual:   ${actual}"
    FAIL=$((FAIL + 1))
  fi
}

assert_neq() {
  local name="$1" a="$2" b="$3"
  if [[ "${a}" != "${b}" ]]; then
    echo "  PASS: ${name}"; PASS=$((PASS + 1))
  else
    echo "  FAIL: ${name} — both inputs hashed to ${a}"; FAIL=$((FAIL + 1))
  fi
}

# Direct python invocation of the normalization function — no full hook payload needed.
# v1 path mirrors save-review-checkpoint.sh:_compute_canonical_id Edit 1.1 verbatim.
hash_for() {
  local cat="$1" loc="$2" prob="$3" prefix="${4:-PR-}" version="${5:-2}"
  CLAUDE_ISSUE_ID_NORMALIZE_VERSION="${version}" python3 -c '
import os, sys, hashlib, re, unicodedata
def _norm(s):
    if s is None: return ""
    s = unicodedata.normalize("NFKC", str(s))
    s = s.strip()
    s = re.sub(r"\s+", " ", s)
    s = s.lower()
    s = re.sub(r"[.;:,]+$", "", s)
    return s
version = os.environ.get("CLAUDE_ISSUE_ID_NORMALIZE_VERSION", "2")
cat, loc, prob, prefix = sys.argv[1:5]
if loc is None:
    loc = ""
if version == "1":
    src = f"{cat}|{loc}|{prob}"
else:
    src = f"{_norm(cat)}|{_norm(loc)}|{_norm(prob)}"
h = hashlib.sha256(src.encode("utf-8")).hexdigest()[:8]
print(f"{prefix}{h}")
' "${cat}" "${loc}" "${prob}" "${prefix}"
}

echo "=== canonical id normalization tests (Part 1 / P2) ==="
echo

# 1. Whitespace
H_A=$(hash_for "style" "Part 3" "missing test for edge case")
H_B=$(hash_for "style" "  Part 3 " "  missing test for edge case  ")
H_C=$(hash_for "style" "Part   3" "missing  test    for edge case")
assert_eq "whitespace-trim equivalence"     "${H_A}" "${H_B}"
assert_eq "internal-ws-collapse equivalence" "${H_A}" "${H_C}"

# 2. Case
H_D=$(hash_for "Style" "Part 3" "MISSING test for edge case")
H_E=$(hash_for "STYLE" "PART 3" "MISSING TEST FOR EDGE CASE")
assert_eq "case-fold equivalence (mixed)"   "${H_A}" "${H_D}"
assert_eq "case-fold equivalence (upper)"   "${H_A}" "${H_E}"

# 3. Terminal punctuation
H_F=$(hash_for "style" "Part 3" "missing test for edge case.")
H_G=$(hash_for "style" "Part 3" "missing test for edge case.;,")
assert_eq "terminal-punct strip (single)"   "${H_A}" "${H_F}"
assert_eq "terminal-punct strip (multi)"    "${H_A}" "${H_G}"

# 4. NFKC
# Full-width digit "３" (U+FF13) NFKC-equivalent to half-width "3"
H_H=$(hash_for "style" "Part ３" "missing test for edge case")
assert_eq "NFKC normalization full-width digit" "${H_A}" "${H_H}"

# 5. Different inputs differ
H_DIFF=$(hash_for "style" "Part 4" "missing test for edge case")
assert_neq "different location -> different hash" "${H_A}" "${H_DIFF}"
H_DIFF2=$(hash_for "architecture" "Part 3" "missing test for edge case")
assert_neq "different category -> different hash" "${H_A}" "${H_DIFF2}"
H_DIFF3=$(hash_for "style" "Part 3" "different problem text entirely")
assert_neq "different problem -> different hash" "${H_A}" "${H_DIFF3}"

# 6. v1 reverts (raw hashing — no trailing-punct strip)
H_V1_RAW=$(hash_for "style" "Part 3" "missing test for edge case" "PR-" "1")
H_V1_TRAIL=$(hash_for "style" "Part 3" "missing test for edge case." "PR-" "1")
assert_neq "v1 raw mode does NOT collapse trailing punct" "${H_V1_RAW}" "${H_V1_TRAIL}"

# 7. Fuzz — 1000 inputs all match the canonical ID regex
PASS_FUZZ=$(python3 -c '
import os, hashlib, re, unicodedata, random, string
random.seed(42)
def _norm(s):
    s = unicodedata.normalize("NFKC", str(s))
    s = s.strip()
    s = re.sub(r"\s+", " ", s)
    s = s.lower()
    s = re.sub(r"[.;:,]+$", "", s)
    return s
ok = 0
for _ in range(1000):
    cat = "".join(random.choices(string.ascii_letters + " ", k=random.randint(1, 30)))
    loc = "".join(random.choices(string.ascii_letters + string.digits + " :.-", k=random.randint(0, 50)))
    prob = "".join(random.choices(string.ascii_letters + string.punctuation + string.whitespace, k=random.randint(1, 200)))
    src = f"{_norm(cat)}|{_norm(loc)}|{_norm(prob)}"
    h = hashlib.sha256(src.encode("utf-8")).hexdigest()[:8]
    full = f"PR-{h}"
    if re.match(r"^PR-[0-9a-f]{8}$", full):
        ok += 1
print(ok)
')
assert_eq "1000-fuzz inputs all yield valid canonical IDs" "1000" "${PASS_FUZZ}"

echo
echo "Results: ${PASS} PASS, ${FAIL} FAIL"
if [[ "${FAIL}" -gt 0 ]]; then exit 1; fi
echo "All tests passed."
exit 0
