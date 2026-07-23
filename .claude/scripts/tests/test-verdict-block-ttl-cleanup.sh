#!/usr/bin/env bash
# test-verdict-block-ttl-cleanup.sh — .verdict-block-* TTL eviction on hook entry
#
# Coverage:
#   1. .verdict-block-* file older than CLAUDE_VERDICT_BLOCK_TTL_HOURS is evicted on hook entry
#   2. Recent .verdict-block-* (< TTL) is preserved
#   3. CLAUDE_VERDICT_BLOCK_TTL_HOURS=0 disables eviction (preserves all)
#   4. pipeline-metrics.jsonl gets a verdict_blocks_evicted record

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
HOOK="${REPO_ROOT}/.claude/scripts/save-review-checkpoint.sh"

cd "${REPO_ROOT}"

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

# Run hook with empty payload to trigger eviction sweep only.
run_eviction_sweep() {
  local sb="$1"
  local ttl="${2:-6}"
  echo '{}' | CLAUDE_VERDICT_BLOCK_TTL_HOURS="${ttl}" CLAUDE_WORKFLOW_STATE_DIR="${sb}" bash "${HOOK}" >/dev/null 2>&1 || true
}

# Helper: backdate a file's mtime by N hours
backdate_hours() {
  local file="$1" hours="$2"
  local target_epoch=$(( $(date +%s) - hours*3600 ))
  # Try GNU date first, fall back to BSD date
  local stamp
  if stamp=$(date -d "@${target_epoch}" +%Y%m%d%H%M.%S 2>/dev/null); then
    touch -t "${stamp%.*}" "${file}"
  else
    stamp=$(date -r "${target_epoch}" +%Y%m%d%H%M.%S 2>/dev/null)
    touch -t "${stamp%.*}" "${file}"
  fi
}

# --- Scenario 1: stale block (8 h old, TTL=6 h) -> evicted ---
SB_1=$(mktemp -d -t ttl-1.XXXXXX)
touch "${SB_1}/.verdict-block-stale1"
backdate_hours "${SB_1}/.verdict-block-stale1" 8
run_eviction_sweep "${SB_1}" 6
[[ -f "${SB_1}/.verdict-block-stale1" ]] && EVICTED_1="NO" || EVICTED_1="YES"
assert_eq "1: stale block (8h, TTL=6) -> evicted"  "YES" "${EVICTED_1}"
test -d "${SB_1}" && rm -r "${SB_1}"

# --- Scenario 2: fresh block (1 h old, TTL=6 h) -> preserved ---
SB_2=$(mktemp -d -t ttl-2.XXXXXX)
touch "${SB_2}/.verdict-block-fresh2"
backdate_hours "${SB_2}/.verdict-block-fresh2" 1
run_eviction_sweep "${SB_2}" 6
[[ -f "${SB_2}/.verdict-block-fresh2" ]] && PRESERVED_2="YES" || PRESERVED_2="NO"
assert_eq "2: fresh block (1h, TTL=6) -> preserved"  "YES" "${PRESERVED_2}"
test -d "${SB_2}" && rm -r "${SB_2}"

# --- Scenario 3: TTL=0 -> all preserved ---
SB_3=$(mktemp -d -t ttl-3.XXXXXX)
touch "${SB_3}/.verdict-block-old3"
backdate_hours "${SB_3}/.verdict-block-old3" 24
run_eviction_sweep "${SB_3}" 0
[[ -f "${SB_3}/.verdict-block-old3" ]] && PRESERVED_3="YES" || PRESERVED_3="NO"
assert_eq "3: TTL=0 disables eviction" "YES" "${PRESERVED_3}"
test -d "${SB_3}" && rm -r "${SB_3}"

# --- Scenario 4: pipeline-metrics.jsonl gets eviction record ---
SB_4=$(mktemp -d -t ttl-4.XXXXXX)
touch "${SB_4}/.verdict-block-evict4"
backdate_hours "${SB_4}/.verdict-block-evict4" 8
run_eviction_sweep "${SB_4}" 6
if grep -qF 'verdict_blocks_evicted' "${SB_4}/pipeline-metrics.jsonl" 2>/dev/null; then HAS_METRIC="YES"; else HAS_METRIC="NO"; fi
assert_eq "4: pipeline-metrics.jsonl has eviction event" "YES" "${HAS_METRIC}"
test -d "${SB_4}" && rm -r "${SB_4}"

echo
echo "Results: ${PASS} PASS, ${FAIL} FAIL"
[[ "${FAIL}" -gt 0 ]] && exit 1
echo "All tests passed."
exit 0
