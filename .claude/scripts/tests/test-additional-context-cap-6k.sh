#!/usr/bin/env bash
# test-additional-context-cap-6k.sh — Part 3 / P5
#
# Coverage:
#   1. Synthetic 5 prior iters x 14 issues -> additionalContext <= 6000 chars
#   2. Canonical IDs preserved (>= 8 unique)
#   3. No 'problem' text from canonical_issue_ids leaks into additionalContext

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
HOOK_INJECT="${REPO_ROOT}/.claude/scripts/inject-review-context.sh"

cd "${REPO_ROOT}"

# Test isolation
unset CLAUDE_HANDOFF_VALIDATION_MODE CLAUDE_VERDICT_VALIDATION_MODE CLAUDE_ISSUE_ID_VALIDATION_MODE

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

assert_le() {
  local name="$1" max="$2" actual="$3"
  if [[ "${actual}" -le "${max}" ]]; then
    echo "  PASS: ${name} (${actual} <= ${max})"; PASS=$((PASS + 1))
  else
    echo "  FAIL: ${name} (${actual} > ${max})"; FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local name="$1" haystack="$2" needle="$3"
  if echo "${haystack}" | grep -qF "${needle}"; then
    echo "  FAIL: ${name} — leaked: ${needle}"; FAIL=$((FAIL + 1))
  else
    echo "  PASS: ${name}"; PASS=$((PASS + 1))
  fi
}

SB=$(mktemp -d -t cap6k.XXXXXX)
export CLAUDE_WORKFLOW_STATE_DIR="${SB}"

# Build a checkpoint
cat > "${SB}/cap6k-feature-checkpoint.yaml" <<'EOF'
feature: cap6k-feature
complexity: XL
phase_completed: 4
phase_name: code_review
iteration:
  plan_review: 1/3
  code_review: 2/3
EOF

# Build review-completions.jsonl with 5 iters x 14 issues each
python3 -c '
import json, hashlib, os
path = os.path.join(os.environ["CLAUDE_WORKFLOW_STATE_DIR"], "review-completions.jsonl")
with open(path, "w") as f:
    for it in range(1, 6):
        cids = []
        for k in range(14):
            cat = "completeness"
            loc = f"Part {k+1} edge case {k+1}"
            prob = f"This is a deliberately wordy problem statement for issue {k+1} in iter {it} of a synthetic stress test"
            src = f"{cat}|{loc}|{prob}"
            h = hashlib.sha256(src.encode()).hexdigest()[:8]
            cids.append({"id": f"CR-{h}", "category": cat, "location": loc, "problem": prob})
        marker = {
            "agent": "code-reviewer",
            "effective_agent_type": "code-reviewer",
            "completed_at": f"2026-05-02T{it:02d}:00:00Z",
            "session_id": "test-session-cap6k",
            "verdict": "CHANGES_REQUESTED",
            "verdict_source": "structured_json",
            "canonical_issue_ids": cids,
        }
        f.write(json.dumps(marker) + "\n")
'

# Invoke inject-review-context.sh
OUTPUT=$(echo '{"session_id": "test-session-cap6k"}' | bash "${HOOK_INJECT}" "code-reviewer" 2>/dev/null || true)

# Extract additionalContext
ADDITIONAL=$(echo "${OUTPUT}" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read() or '{}')
hs = d.get('hookSpecificOutput', {})
print(hs.get('additionalContext', '') or d.get('additionalContext', ''), end='')
")

# AC-P5.3
SIZE=${#ADDITIONAL}
assert_le "additionalContext size <= 6000" "6000" "${SIZE}"

# canonical IDs preserved (>= 8 unique)
ID_COUNT=$(echo "${ADDITIONAL}" | grep -oE 'CR-[0-9a-f]{8}' | sort -u | wc -l | tr -d ' ')
[[ "${ID_COUNT}" -ge 8 ]] && CIDS_OK="YES" || CIDS_OK="NO"
assert_eq "canonical IDs present (>=8 unique)"  "YES" "${CIDS_OK}"

# No 'problem' text leakage — the verbose substring should NOT appear
assert_not_contains "no problem text leakage (deliberately wordy phrase)" "${ADDITIONAL}" "deliberately wordy problem statement"

test -d "${SB}" && rm -r "${SB}"
echo
echo "Results: ${PASS} PASS, ${FAIL} FAIL"
if [[ "${FAIL}" -gt 0 ]]; then exit 1; fi
echo "All tests passed."
exit 0
