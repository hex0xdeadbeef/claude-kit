#!/usr/bin/env bash
# Golden-test runner for hook additionalContext rendering (IMP-04/hook-context-consolidation)
# Covers: AC-3, AC-5, AC-7, AC-8, AC-10
# Usage: bash .claude/scripts/tests/test-state-render-golden.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
cd "$REPO_ROOT"

FIXTURE_DIR="${SCRIPT_DIR}/fixtures/state-render"
SCRIPTS_DIR=".claude/scripts"
LIB_DIR="${SCRIPTS_DIR}/lib"

# CR-001 fix: use isolated temp STATE_DIR so tests never touch real .claude/workflow-state/
# All 4 hooks honor CLAUDE_WORKFLOW_STATE_DIR — exporting it makes every hook call hermetic.
TEST_STATE_DIR=$(mktemp -d)
export CLAUDE_WORKFLOW_STATE_DIR="$TEST_STATE_DIR"
STATE_DIR="$TEST_STATE_DIR"
# Cleanup on exit (covers both clean pass and early failure)
trap "rm -rf '$TEST_STATE_DIR'" EXIT

PASS=0
FAIL=0

assert_eq() {
    local desc="$1" actual="$2" expected="$3"
    if [[ "$actual" == "$expected" ]]; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc"
        echo "    Expected: $(echo "$expected" | head -3)"
        echo "    Actual:   $(echo "$actual" | head -3)"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local desc="$1" haystack="$2" needle="$3"
    if echo "$haystack" | grep -qF "$needle"; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc"
        echo "    Missing: $needle"
        FAIL=$((FAIL + 1))
    fi
}

assert_not_contains() {
    local desc="$1" haystack="$2" needle="$3"
    if ! echo "$haystack" | grep -qF "$needle"; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc"
        echo "    Should not contain: $needle"
        FAIL=$((FAIL + 1))
    fi
}

extract_context() {
    python3 -c "
import json, sys
d = json.load(sys.stdin)
hs = d.get('hookSpecificOutput', {})
print(hs.get('additionalContext', '') or d.get('additionalContext', ''), end='')
"
}

# CR-001 fix: setup_state writes to isolated TEST_STATE_DIR, not real workflow-state.
# Pre-seeds review-completions.jsonl with 3 deterministic entries so all hooks that
# read completions produce stable output regardless of the host machine's state.
setup_state() {
    local fixture_state="$1"
    rm -f "$STATE_DIR"/*  # clear all files from previous test
    cp "$fixture_state" "$STATE_DIR/test-feature-checkpoint.yaml"
    # Pre-seed 3 deterministic review completions (hermeticity — Recent reviews section)
    printf '{"agent":"plan-reviewer","completed_at":"2026-01-01T00:00:00Z","verdict":"NEEDS_CHANGES"}\n' > "$STATE_DIR/review-completions.jsonl"
    printf '{"agent":"plan-reviewer","completed_at":"2026-01-01T01:00:00Z","verdict":"NEEDS_CHANGES"}\n' >> "$STATE_DIR/review-completions.jsonl"
    printf '{"agent":"plan-reviewer","completed_at":"2026-01-01T02:00:00Z","verdict":"APPROVED"}\n' >> "$STATE_DIR/review-completions.jsonl"
}

cleanup_state() {
    rm -f "$STATE_DIR"/*  # clear all files including .enrich-last-hash
}

echo "=== state-render golden tests (IMP-hook-consolidation) ==="
echo ""

# -----------------------------------------------------------------------
# AC-8: Golden output — enrich-context.sh
# CR-001 fix: use assert_contains for stable parts instead of assert_eq.
# Plans section varies by machine (.claude/prompts/ is gitignored + not seeded here).
# Recent reviews uses assert_contains "Recent reviews:" (content is deterministic
# from seeded completions but timestamps appear in hook-specific format).
# -----------------------------------------------------------------------
echo "--- AC-8: enrich-context stable-output assertions ---"
setup_state "${FIXTURE_DIR}/enrich-context/state.yaml"
ACTUAL=$(echo '{}' | bash "${SCRIPTS_DIR}/enrich-context.sh" 2>/dev/null | extract_context)
assert_contains "enrich-context: workflow state header" "$ACTUAL" "[Workflow State]"
assert_contains "enrich-context: checkpoint oneliner present" "$ACTUAL" "Checkpoint: test-feature | Phase: planning (1/5)"
assert_contains "enrich-context: complexity in oneliner" "$ACTUAL" "Complexity: XL"
assert_contains "enrich-context: recent reviews present (seeded completions)" "$ACTUAL" "Recent reviews:"
assert_contains "enrich-context: branch line present" "$ACTUAL" "Branch:"
cleanup_state

# -----------------------------------------------------------------------
# AC-8: Golden output — save-progress-before-compact.sh (checkpoint_ref section)
# -----------------------------------------------------------------------
echo "--- AC-8: save-progress checkpoint_ref (no full YAML body) ---"
setup_state "${FIXTURE_DIR}/save-progress/state.yaml"
ACTUAL=$(echo '{"trigger":"manual"}' | bash "${SCRIPTS_DIR}/save-progress-before-compact.sh" 2>/dev/null | extract_context)
# AC-6: must contain reference-link, must NOT contain YAML body lines
assert_contains "save-progress: contains Workflow Checkpoint ref" "$ACTUAL" "File: ${STATE_DIR}/test-feature-checkpoint.yaml"
assert_contains "save-progress: contains Resume link" "$ACTUAL" "Resume: /workflow --from-phase"
assert_not_contains "save-progress: no full YAML body (phase_name line)" "$ACTUAL" "phase_name: planning"
assert_not_contains "save-progress: no full YAML body (complexity line)" "$ACTUAL" "complexity: XL"
cleanup_state

# -----------------------------------------------------------------------
# AC-8: Golden output — verify-state-after-compact.sh
# assert_eq works here: output depends only on checkpoint content (from fixture)
# and review-completions.jsonl (seeded with 3 entries by setup_state).
# -----------------------------------------------------------------------
echo "--- AC-8: verify-state golden output ---"
setup_state "${FIXTURE_DIR}/verify-state/state.yaml"
EXPECTED=$(cat "${FIXTURE_DIR}/verify-state/expected.txt")
ACTUAL_RAW=$(bash "${SCRIPTS_DIR}/verify-state-after-compact.sh" 2>/dev/null | extract_context)
# CR-001 fix: normalize temp STATE_DIR path → placeholder before golden compare
ACTUAL=$(echo "$ACTUAL_RAW" | sed "s|${STATE_DIR}|STATE_DIR|g")
assert_eq "verify-state: output matches golden fixture" "$ACTUAL" "$EXPECTED"
cleanup_state

# -----------------------------------------------------------------------
# AC-7: pipeline-metrics gate — iter=1 → NO metrics block
# -----------------------------------------------------------------------
echo "--- AC-7: pipeline-metrics NOT injected on iter=1 ---"
setup_state "${FIXTURE_DIR}/inject-review/state.yaml"
# Create pipeline-metrics.jsonl with >= 3 entries (sufficient history)
printf '{"complexity":{"estimated":"XL"},"review_iterations":{"plan_review":2},"issues_found":{}}\n%.0s' {1..5} > "${STATE_DIR}/pipeline-metrics.jsonl"
ACTUAL=$(echo '{"session_id":"test-session"}' | bash "${SCRIPTS_DIR}/inject-review-context.sh" "plan-reviewer" 2>/dev/null | extract_context)
assert_not_contains "inject-review iter=1: no pipeline history block" "$ACTUAL" "[Pipeline history context]:"
rm -f "${STATE_DIR}/pipeline-metrics.jsonl"
cleanup_state

# -----------------------------------------------------------------------
# AC-7: pipeline-metrics gate — iter=2 + < 3 completions → NO metrics
# -----------------------------------------------------------------------
echo "--- AC-7: pipeline-metrics NOT injected iter=2 + <3 completions ---"
# Create checkpoint with plan_review: 2/3
sed 's/plan_review: 0\/3/plan_review: 2\/3/' "${FIXTURE_DIR}/inject-review/state.yaml" > "${STATE_DIR}/test-feature-checkpoint.yaml"
printf '{"complexity":{"estimated":"XL"},"review_iterations":{"plan_review":2},"issues_found":{}}\n%.0s' {1..5} > "${STATE_DIR}/pipeline-metrics.jsonl"
# Only 2 review completions for this session
printf '{"session_id":"test-session","agent":"plan-reviewer","completed_at":"2026-01-01T00:00:00Z","verdict":"NEEDS_CHANGES","effective_agent_type":"plan-reviewer"}\n' > "${STATE_DIR}/review-completions.jsonl"
printf '{"session_id":"test-session","agent":"plan-reviewer","completed_at":"2026-01-01T01:00:00Z","verdict":"NEEDS_CHANGES","effective_agent_type":"plan-reviewer"}\n' >> "${STATE_DIR}/review-completions.jsonl"
ACTUAL=$(echo '{"session_id":"test-session"}' | bash "${SCRIPTS_DIR}/inject-review-context.sh" "plan-reviewer" 2>/dev/null | extract_context)
assert_not_contains "inject-review iter=2 <3 completions: no pipeline metrics" "$ACTUAL" "[Pipeline history context]:"
rm -f "${STATE_DIR}/pipeline-metrics.jsonl" "${STATE_DIR}/review-completions.jsonl"
rm -f "${STATE_DIR}/test-feature-checkpoint.yaml"

# -----------------------------------------------------------------------
# AC-10: hash-guard non-regression — second call returns empty stdout
# -----------------------------------------------------------------------
echo "--- AC-10: hash-guard — second call exits with no output ---"
setup_state "${FIXTURE_DIR}/enrich-context/state.yaml"
echo '{}' | bash "${SCRIPTS_DIR}/enrich-context.sh" 2>/dev/null > /dev/null  # first call writes hash
SECOND_OUTPUT=$(echo '{}' | bash "${SCRIPTS_DIR}/enrich-context.sh" 2>/dev/null)
assert_eq "enrich-context: second call (hash match) → empty stdout" "$SECOND_OUTPUT" ""
cleanup_state

# -----------------------------------------------------------------------
# AC-13: no checkpoint → empty context + exit 0, NO WARN on stderr
# -----------------------------------------------------------------------
echo "--- AC-13: no checkpoint → empty context, clean stderr ---"
EMPTY_STATE_DIR=$(mktemp -d)
# Run all 4 hooks against empty state dir; assert stderr is empty (no WARN)
for hook in "enrich-context.sh" "save-progress-before-compact.sh" "verify-state-after-compact.sh"; do
    STDERR_13=$(echo '{}' | CLAUDE_WORKFLOW_STATE_DIR="$EMPTY_STATE_DIR" bash "${SCRIPTS_DIR}/${hook}" 2>&1 >/dev/null || true)
    STDOUT_13=$(echo '{}' | CLAUDE_WORKFLOW_STATE_DIR="$EMPTY_STATE_DIR" bash "${SCRIPTS_DIR}/${hook}" 2>/dev/null || true)
    assert_eq "AC-13 ${hook}: stderr empty on no-checkpoint" "$STDERR_13" ""
    # Stdout must be valid JSON (not crash)
    echo "$STDOUT_13" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null \
        && { echo "  PASS: AC-13 ${hook}: stdout is valid JSON"; PASS=$((PASS + 1)); } \
        || { echo "  FAIL: AC-13 ${hook}: stdout is not valid JSON"; FAIL=$((FAIL + 1)); }
done
# inject-review-context.sh with no checkpoint emits informational additionalContext (not WARN)
STDERR_13=$(echo '{}' | CLAUDE_WORKFLOW_STATE_DIR="$EMPTY_STATE_DIR" bash "${SCRIPTS_DIR}/inject-review-context.sh" "plan-reviewer" 2>&1 >/dev/null || true)
assert_eq "AC-13 inject-review-context: no WARN stderr on no-checkpoint" "$STDERR_13" ""
rm -rf "$EMPTY_STATE_DIR"

# -----------------------------------------------------------------------
# AC-3: import failure → empty additionalContext + WARN on stderr
# -----------------------------------------------------------------------
echo "--- AC-3: import failure → uniform fallback ---"
setup_state "${FIXTURE_DIR}/enrich-context/state.yaml"
# CR-a3c01bfe fix: nest trap so a kill between mv calls restores real lib.
# Outer EXIT trap already cleans TEST_STATE_DIR; extend it to also restore lib.
trap "mv '${LIB_DIR}.bak' '${LIB_DIR}' 2>/dev/null; rm -rf '$TEST_STATE_DIR'" EXIT
mv "${LIB_DIR}" "${LIB_DIR}.bak"
STDERR_OUT=$(echo '{}' | bash "${SCRIPTS_DIR}/enrich-context.sh" 2>&1 >/dev/null)
STDOUT_OUT=$(echo '{}' | bash "${SCRIPTS_DIR}/enrich-context.sh" 2>/dev/null)
mv "${LIB_DIR}.bak" "${LIB_DIR}"
# Restore original trap (lib is back; only state dir cleanup remains)
trap "rm -rf '$TEST_STATE_DIR'" EXIT
assert_contains "enrich-context import failure: stderr WARN" "$STDERR_OUT" "[enrich-context] WARN:"
CONTEXT=$(echo "$STDOUT_OUT" | extract_context)
assert_eq "enrich-context import failure: empty additionalContext" "$CONTEXT" ""
cleanup_state

# -----------------------------------------------------------------------
# AC-5: LRU-5 spillover rotation — 6 files → oldest deleted
# -----------------------------------------------------------------------
echo "--- AC-5: LRU-5 rotation keeps exactly 5 overflow files ---"
for i in $(seq 1 6); do
    touch "${STATE_DIR}/compact-overflow-100${i}-$$.log"
done
python3 -c "
import sys, os; sys.path.insert(0, '${LIB_DIR}')
import state_render; state_render.rotate_spillover_files('${STATE_DIR}')
"
COUNT=$(ls "${STATE_DIR}"/compact-overflow-*.log 2>/dev/null | wc -l | tr -d ' ')
assert_eq "LRU-5: exactly 5 overflow files remain" "$COUNT" "5"
OLDEST=$(ls "${STATE_DIR}"/compact-overflow-*.log 2>/dev/null | sort | head -1)
assert_not_contains "LRU-5: oldest file deleted" "$OLDEST" "compact-overflow-1001"
rm -f "${STATE_DIR}"/compact-overflow-*.log

# -----------------------------------------------------------------------
# CR-004: CAP sync guard — all 4 bash hooks must have CAP=8192
# Prevents CONTEXT_SIZE_CAP drift between state_render.py and bash scripts.
# -----------------------------------------------------------------------
echo "--- CR-004: CAP=6000 sync across all hooks (P5) ---"
for hook in "enrich-context.sh" "inject-review-context.sh" "save-progress-before-compact.sh" "verify-state-after-compact.sh"; do
    if grep -q "CAP=6000" "${SCRIPTS_DIR}/${hook}"; then
        echo "  PASS: ${hook}: CAP=6000 present"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: ${hook}: CAP=6000 missing (drift from state_render.CONTEXT_SIZE_CAP)"
        FAIL=$((FAIL + 1))
    fi
done

# -----------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
