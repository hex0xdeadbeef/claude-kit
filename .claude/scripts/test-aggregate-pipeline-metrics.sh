#!/bin/bash
# Tests for aggregate_pipeline_metrics() in inject-review-context.sh
# Run from repo root: bash .claude/scripts/test-aggregate-pipeline-metrics.sh

set -euo pipefail

PASS=0
FAIL=0
STATE_DIR=".claude/workflow-state"
METRICS_FILE="$STATE_DIR/pipeline-metrics.jsonl"
CHECKPOINT_FILE="$STATE_DIR/_test-checkpoint.yaml"

cleanup() {
  rm -f "$METRICS_FILE" "$CHECKPOINT_FILE"
}
trap cleanup EXIT

# Create minimal checkpoint (required by inject script)
mkdir -p "$STATE_DIR"
cat > "$CHECKPOINT_FILE" << 'EOF'
feature: _test
complexity: M
route: standard
phase_completed: 3
iteration:
  plan_review: 0/3
  code_review: 0/3
EOF

run_inject() {
  local agent_type="${1:-code-reviewer}"
  echo '' | bash .claude/scripts/inject-review-context.sh "$agent_type" 2>/dev/null
}

assert_contains() {
  local desc="$1" output="$2" pattern="$3"
  if echo "$output" | grep -q "$pattern"; then
    PASS=$((PASS + 1))
    echo "  PASS: $desc"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $desc (pattern '$pattern' not found)"
    echo "    output: $output"
  fi
}

assert_not_contains() {
  local desc="$1" output="$2" pattern="$3"
  if echo "$output" | grep -q "$pattern"; then
    FAIL=$((FAIL + 1))
    echo "  FAIL: $desc (pattern '$pattern' found but should not be)"
  else
    PASS=$((PASS + 1))
    echo "  PASS: $desc"
  fi
}

echo "=== Test: No metrics file ==="
rm -f "$METRICS_FILE"
output=$(run_inject)
assert_not_contains "No pipeline history section" "$output" "Pipeline history"

echo "=== Test: < 3 entries (insufficient history) ==="
cat > "$METRICS_FILE" << 'EOF'
{"feature":"f1","complexity":{"estimated":"M"},"review_iterations":{"plan_review":1,"code_review":1},"issues_found":{"blocker":0,"major":1,"minor":2}}
{"feature":"f2","complexity":{"estimated":"M"},"review_iterations":{"plan_review":1,"code_review":2},"issues_found":{"blocker":0,"major":0,"minor":3}}
EOF
output=$(run_inject)
assert_not_contains "Skipped with 2 entries" "$output" "Pipeline history"

echo "=== Test: 3+ entries with matching complexity ==="
cat >> "$METRICS_FILE" << 'EOF'
{"feature":"f3","complexity":{"estimated":"M"},"review_iterations":{"plan_review":2,"code_review":1},"issues_found":{"blocker":1,"major":2,"minor":1}}
EOF
output=$(run_inject)
assert_contains "Pipeline history injected" "$output" "Pipeline history context"
assert_contains "Avg code-review iterations" "$output" "Avg code-review iterations"
assert_contains "Top issue categories" "$output" "Top issue categories"

echo "=== Test: plan-reviewer gets plan-review iterations ==="
output=$(run_inject plan-reviewer)
assert_contains "Avg plan-review iterations" "$output" "Avg plan-review iterations"
assert_not_contains "No code-review label" "$output" "Avg code-review"

echo "=== Test: BLOCKER anomaly detection ==="
cat >> "$METRICS_FILE" << 'EOF'
{"feature":"f4","complexity":{"estimated":"M"},"review_iterations":{"plan_review":1,"code_review":1},"issues_found":{"blocker":1,"major":0,"minor":0}}
EOF
output=$(run_inject)
assert_contains "BLOCKER warning" "$output" "BLOCKER issues"

echo "=== Test: No BLOCKER warning when < 2 recent ==="
rm -f "$METRICS_FILE"
cat > "$METRICS_FILE" << 'EOF'
{"feature":"f1","complexity":{"estimated":"M"},"review_iterations":{"plan_review":1,"code_review":1},"issues_found":{"blocker":0,"major":1,"minor":2}}
{"feature":"f2","complexity":{"estimated":"M"},"review_iterations":{"plan_review":1,"code_review":2},"issues_found":{"blocker":0,"major":0,"minor":3}}
{"feature":"f3","complexity":{"estimated":"M"},"review_iterations":{"plan_review":2,"code_review":1},"issues_found":{"blocker":0,"major":0,"minor":1}}
EOF
output=$(run_inject)
assert_not_contains "No BLOCKER warning with 0 recent blockers" "$output" "BLOCKER issues"

echo "=== Test: Complexity fallback to all runs ==="
rm -f "$METRICS_FILE"
cat > "$METRICS_FILE" << 'EOF'
{"feature":"f1","complexity":{"estimated":"L"},"review_iterations":{"plan_review":1,"code_review":2},"issues_found":{"blocker":0,"major":1,"minor":0}}
{"feature":"f2","complexity":{"estimated":"L"},"review_iterations":{"plan_review":1,"code_review":3},"issues_found":{"blocker":0,"major":0,"minor":1}}
{"feature":"f3","complexity":{"estimated":"L"},"review_iterations":{"plan_review":2,"code_review":1},"issues_found":{"blocker":0,"major":0,"minor":2}}
EOF
output=$(run_inject)
assert_contains "Falls back to all runs when no M match" "$output" "all runs"

echo "=== Test: Malformed JSONL lines skipped ==="
rm -f "$METRICS_FILE"
cat > "$METRICS_FILE" << 'EOF'
{"feature":"f1","complexity":{"estimated":"M"},"review_iterations":{"plan_review":1,"code_review":1},"issues_found":{"blocker":0,"major":1,"minor":2}}
NOT_JSON_LINE
{"feature":"f2","complexity":{"estimated":"M"},"review_iterations":{"plan_review":1,"code_review":2},"issues_found":{"blocker":0,"major":0,"minor":3}}
{"feature":"f3","complexity":{"estimated":"M"},"review_iterations":{"plan_review":2,"code_review":1},"issues_found":{"blocker":0,"major":2,"minor":1}}
EOF
output=$(run_inject)
assert_contains "Handles malformed lines gracefully" "$output" "Pipeline history context"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
