#!/usr/bin/env bash
# Golden-test runner for hook additionalContext rendering (IMP-04/hook-context-consolidation)
# Covers: AC-3, AC-5, AC-7, AC-8, AC-10
# Usage: bash .claude/scripts/tests/test-state-render-golden.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
cd "$REPO_ROOT"

FIXTURE_DIR="${SCRIPT_DIR}/fixtures/state-render"
STATE_DIR=".claude/workflow-state"
SCRIPTS_DIR=".claude/scripts"
LIB_DIR="${SCRIPTS_DIR}/lib"

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

setup_state() {
    local fixture_state="$1"
    mkdir -p "$STATE_DIR"
    rm -f "$STATE_DIR"/*-checkpoint.yaml "$STATE_DIR/.enrich-last-hash"
    cp "$fixture_state" "$STATE_DIR/test-feature-checkpoint.yaml"
}

cleanup_state() {
    rm -f "$STATE_DIR/test-feature-checkpoint.yaml" "$STATE_DIR/.enrich-last-hash"
}

echo "=== state-render golden tests (IMP-hook-consolidation) ==="
echo ""

# -----------------------------------------------------------------------
# AC-8: Golden output — enrich-context.sh
# -----------------------------------------------------------------------
echo "--- AC-8: enrich-context golden output ---"
setup_state "${FIXTURE_DIR}/enrich-context/state.yaml"
EXPECTED=$(cat "${FIXTURE_DIR}/enrich-context/expected.txt")
ACTUAL=$(echo '{}' | bash "${SCRIPTS_DIR}/enrich-context.sh" 2>/dev/null | extract_context)
assert_eq "enrich-context: output matches golden fixture" "$ACTUAL" "$EXPECTED"
cleanup_state

# -----------------------------------------------------------------------
# AC-8: Golden output — save-progress-before-compact.sh (checkpoint_ref section)
# -----------------------------------------------------------------------
echo "--- AC-8: save-progress checkpoint_ref (no full YAML body) ---"
setup_state "${FIXTURE_DIR}/save-progress/state.yaml"
ACTUAL=$(echo '{"trigger":"manual"}' | bash "${SCRIPTS_DIR}/save-progress-before-compact.sh" 2>/dev/null | extract_context)
# AC-6: must contain reference-link, must NOT contain YAML body lines
assert_contains "save-progress: contains Workflow Checkpoint ref" "$ACTUAL" "File: .claude/workflow-state/test-feature-checkpoint.yaml"
assert_contains "save-progress: contains Resume link" "$ACTUAL" "Resume: /workflow --from-phase"
assert_not_contains "save-progress: no full YAML body (phase_name line)" "$ACTUAL" "phase_name: planning"
assert_not_contains "save-progress: no full YAML body (complexity line)" "$ACTUAL" "complexity: XL"
cleanup_state

# -----------------------------------------------------------------------
# AC-8: Golden output — verify-state-after-compact.sh
# -----------------------------------------------------------------------
echo "--- AC-8: verify-state golden output ---"
setup_state "${FIXTURE_DIR}/verify-state/state.yaml"
EXPECTED=$(cat "${FIXTURE_DIR}/verify-state/expected.txt")
ACTUAL=$(bash "${SCRIPTS_DIR}/verify-state-after-compact.sh" 2>/dev/null | extract_context)
assert_eq "verify-state: output matches golden fixture" "$ACTUAL" "$EXPECTED"
cleanup_state

# -----------------------------------------------------------------------
# AC-7: pipeline-metrics gate — iter=1 → NO metrics block
# -----------------------------------------------------------------------
echo "--- AC-7: pipeline-metrics NOT injected on iter=1 ---"
setup_state "${FIXTURE_DIR}/inject-review/state.yaml"
# Create pipeline-metrics.jsonl with >= 3 entries (sufficient history)
mkdir -p "$STATE_DIR"
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
mkdir -p "$STATE_DIR"
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
REAL_STATE_DIR="$STATE_DIR"
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
# Temporarily rename lib to simulate import failure
mv "${LIB_DIR}" "${LIB_DIR}.bak"
STDERR_OUT=$(echo '{}' | bash "${SCRIPTS_DIR}/enrich-context.sh" 2>&1 >/dev/null)
STDOUT_OUT=$(echo '{}' | bash "${SCRIPTS_DIR}/enrich-context.sh" 2>/dev/null)
mv "${LIB_DIR}.bak" "${LIB_DIR}"
assert_contains "enrich-context import failure: stderr WARN" "$STDERR_OUT" "[enrich-context.sh] WARN:"
CONTEXT=$(echo "$STDOUT_OUT" | extract_context)
assert_eq "enrich-context import failure: empty additionalContext" "$CONTEXT" ""
cleanup_state

# -----------------------------------------------------------------------
# AC-5: LRU-5 spillover rotation — 6 files → oldest deleted
# -----------------------------------------------------------------------
echo "--- AC-5: LRU-5 rotation keeps exactly 5 overflow files ---"
mkdir -p "$STATE_DIR"
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
# Summary
# -----------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
