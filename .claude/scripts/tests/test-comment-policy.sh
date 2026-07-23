#!/usr/bin/env bash
# test-comment-policy.sh
#
# Locks the source-code comment policy: it must reach the coder through both
# unconditionally-loaded channels, the exemplars must not demonstrate the
# forbidden style, and the reviewer must carry the corrective check.
#
# Emits CP-1..CP-6. No SKIP branches — every assertion runs unconditionally, so
# a green run means all six were actually evaluated.

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

label() { echo "[${SCRIPT_NAME}] $1: $2" >&2; }
fail() { label "FAIL" "$1"; exit 1; }
pass() { label "PASS" "$1"; }

cd "$PROJECT_ROOT"

CODER_SKILL=".claude/skills/coder-rules/SKILL.md"
CODER_CMD=".claude/commands/coder.md"
TDD_SHAPES_DIR=".claude/skills/tdd-rules/tdd-shapes"
CODE_SHAPES_DIR=".claude/skills/planner-rules/code-shapes"
REVIEW_SKILL=".claude/skills/code-review-rules/SKILL.md"
REVIEW_EXAMPLES=".claude/skills/code-review-rules/examples.md"

SHAPE_LANGS=(go python typescript rust java _default)

# Forbidden comment shapes in an exemplar file, assembled from four parts.
#
# MARKER matches a comment opener at line start or after whitespace, so a
# trailing comment on a code line is caught too. `#[^[` excludes Rust attributes
# such as `#[tokio::test]`; requiring whitespace before `//` excludes URLs,
# where the slashes follow a colon.
FORBIDDEN_MARKER='(^[[:space:]]*|[[:space:]])(//|#[^[])'
# Pipeline status — the shape these exemplar files must never demonstrate.
FORBIDDEN_STATUS='(Run:|MUST FAIL|MUST PASS|FAIL|PASS|All [0-9]+ cycles)'
# Process references — the shape the policy exists to eliminate.
FORBIDDEN_PROCESS='(Part [0-9]|AC-?[0-9]|CR-[0-9]|PR-[0-9]|IMP-[0-9]|Proposal [A-Z]|Phase [0-9]|per plan|per spec|as specified|per review)'
# Change narrative — describing the code against a version the reader cannot see.
FORBIDDEN_NARRATIVE='(previously|no longer|used to |added in this )'
FORBIDDEN_COMMENT_RX="${FORBIDDEN_MARKER}.*(${FORBIDDEN_STATUS}|${FORBIDDEN_PROCESS}|${FORBIDDEN_NARRATIVE})"

# A shape file that mandates an in-code pipeline marker as a required output
# property. Matches a backticked comment-opener plus a failure token, whatever
# noun follows it.
ANNOTATION_MANDATE_RX='`(//|#) *(MUST )?FAIL`'

# ════════════════════════════════════════════════════════════════════════
# AUTOMATED
# ════════════════════════════════════════════════════════════════════════

# CP-1: the policy is present in the skill the coder reads at every startup
[[ -f "$CODER_SKILL" ]] || fail "CP-1 — ${CODER_SKILL} missing"
grep -q '^## Comment Policy' "$CODER_SKILL" \
  || fail "CP-1 — ${CODER_SKILL} missing the '## Comment Policy' section"
grep -q 'RULE_6' "$CODER_SKILL" \
  || fail "CP-1 — ${CODER_SKILL} missing RULE_6 in the CRITICAL rules list"
grep -q '^## 6 CRITICAL Rules' "$CODER_SKILL" \
  || fail "CP-1 — ${CODER_SKILL} heading still claims 5 CRITICAL rules; RULE_6 would be uncounted"
for forbidden in 'plan part' 'acceptance-criteria' 'review issue'; do
  grep -qi "$forbidden" "$CODER_SKILL" \
    || fail "CP-1 — Comment Policy does not name '${forbidden}' as a forbidden comment subject"
done
grep -qi 'change narrative' "$CODER_SKILL" \
  || fail "CP-1 — Comment Policy does not forbid change narrative"
pass "CP-1 — coder-rules/SKILL.md carries the Comment Policy + RULE_6 (6 CRITICAL rules)"

# CP-2: the rule is mirrored into the command body, which is the coder's prompt
[[ -f "$CODER_CMD" ]] || fail "CP-2 — ${CODER_CMD} missing"
grep -q 'id: RULE_6' "$CODER_CMD" \
  || fail "CP-2 — ${CODER_CMD} RULES block has no 'id: RULE_6' entry"
grep -q 'Comment Quality' "$CODER_CMD" \
  || fail "CP-2 — ${CODER_CMD} RULE_6 is not titled 'Comment Quality'"
pass "CP-2 — coder.md RULES block mirrors RULE_6 Comment Quality"

# CP-3: no exemplar demonstrates a forbidden comment. Demonstration outweighs
# instruction — a contaminated shape file teaches the coder the exact style the
# policy forbids. Both catalogues are scanned: tdd-shapes feeds /coder, and
# code-shapes feeds the `code:` blocks /planner writes for /coder to transcribe.
CP3_FILES=0
for lang in "${SHAPE_LANGS[@]}"; do
  for f in "${TDD_SHAPES_DIR}/${lang}.md" "${CODE_SHAPES_DIR}/${lang}.md"; do
    [[ -f "$f" ]] || fail "CP-3 — ${f} missing (shape catalogue incomplete)"
    CP3_FILES=$((CP3_FILES + 1))
    hits="$(grep -cE "$FORBIDDEN_COMMENT_RX" "$f" || true)"
    if [[ "$hits" -ne 0 ]]; then
      label "FAIL" "CP-3 — ${f} has ${hits} forbidden comment(s):"
      grep -nE "$FORBIDDEN_COMMENT_RX" "$f" >&2 || true
      fail "CP-3 — comments in exemplar code describe the code; cycle status goes in the **RED**/**GREEN** prose"
    fi
  done
done
[[ "$CP3_FILES" -eq 12 ]] \
  || fail "CP-3 — expected to scan 12 shape files, scanned ${CP3_FILES} (loop degenerated)"
pass "CP-3 — 0 forbidden comments across all 12 shape files (tdd-shapes + code-shapes)"

# CP-4: no shape file PRESCRIBES an in-code status annotation.
if grep -rnE "$ANNOTATION_MANDATE_RX" "$TDD_SHAPES_DIR" "$CODE_SHAPES_DIR" >/dev/null 2>&1; then
  label "FAIL" "CP-4 — a shape file still mandates an in-code FAIL marker:"
  grep -rnE "$ANNOTATION_MANDATE_RX" "$TDD_SHAPES_DIR" "$CODE_SHAPES_DIR" >&2 || true
  fail "CP-4 — restate the invariant as 'RED shown first in every cycle' without an in-code marker"
fi
pass "CP-4 — no shape file prescribes an in-code pipeline marker"

# CP-5: both exemplar governance files carry the invariant, so the next language
# added through the documented recipe cannot reintroduce the style.
for inv in "${TDD_SHAPES_DIR}/INVARIANTS.md" "${CODE_SHAPES_DIR}/INVARIANTS.md"; do
  [[ -f "$inv" ]] || fail "CP-5 — ${inv} missing"
  grep -q '^## Comment invariant' "$inv" \
    || fail "CP-5 — ${inv} missing the '## Comment invariant' section"
done
# The tdd-shapes governance file is count-anchored by test-tdd-shapes-extracted.sh,
# which greps for the literal 'three invariants'. The comment invariant is a
# separate non-numbered section precisely so that anchor stays byte-intact.
grep -qE 'three invariants|three TDD invariants|The three invariants' "${TDD_SHAPES_DIR}/INVARIANTS.md" \
  || fail "CP-5 — tdd-shapes/INVARIANTS.md lost its 'three invariants' count anchor"
pass "CP-5 — both INVARIANTS.md carry the comment invariant; count anchor intact"

# CP-6: the reviewer can correct the coder on the next iteration.
[[ -f "$REVIEW_SKILL" ]] || fail "CP-6 — ${REVIEW_SKILL} missing"
grep -q 'Comment hygiene' "$REVIEW_SKILL" \
  || fail "CP-6 — ${REVIEW_SKILL} concern areas do not include comment hygiene"
grep -q '^### Step 3a: Comment hygiene' "$REVIEW_SKILL" \
  || fail "CP-6 — ${REVIEW_SKILL} missing the '### Step 3a: Comment hygiene' instruction"
# The problem string is a canonical-issue-ID hash input. It must be a fixed
# literal — any interpolation rotates the id between review iterations.
grep -qF 'Source comment references the development process rather than the code it documents.' "$REVIEW_SKILL" \
  || fail "CP-6 — ${REVIEW_SKILL} missing the fixed problem string for comment findings"
if grep -n 'Source comment references the development process' "$REVIEW_SKILL" | grep -q '{'; then
  fail "CP-6 — the fixed problem string contains an interpolation placeholder; canonical issue id would drift"
fi
[[ -f "$REVIEW_EXAMPLES" ]] || fail "CP-6 — ${REVIEW_EXAMPLES} missing"
grep -q 'process_referencing_comment:' "$REVIEW_EXAMPLES" \
  || fail "CP-6 — ${REVIEW_EXAMPLES} search_patterns missing process_referencing_comment"
grep -q 'change_narrative_comment:' "$REVIEW_EXAMPLES" \
  || fail "CP-6 — ${REVIEW_EXAMPLES} search_patterns missing change_narrative_comment"
pass "CP-6 — reviewer carries the comment-hygiene check, fixed problem string, and both grep patterns"

label "INFO" "${SCRIPT_NAME} complete — 6/6 checks evaluated (CP-1..CP-6), 0 skipped"
