#!/usr/bin/env bash
# test-notify-background-tasks-suppress.sh — I-03: notify-workflow-complete.sh must
# suppress the Phase-5 completion notification while background_tasks are pending
# (v2.1.145 Stop payload field), while preserving default-OFF + the allowlisted emit.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="${SCRIPT_DIR}/../notify-workflow-complete.sh"
PASS=0; FAIL=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Phase-5 APPROVED checkpoint in a sandbox state dir
cat > "${TMP}/feat-checkpoint.yaml" <<'EOF'
feature: feat
phase_completed: 5
verdict: APPROVED
EOF

run_on() {  # stdin_json  → runs with notify ENABLED
  CLAUDE_KIT_PHASE_COMPLETION_NOTIFY=on CLAUDE_WORKFLOW_STATE_DIR="$TMP" \
    bash "$HOOK" <<< "$1" 2>/dev/null
}

echo "=== test-notify-background-tasks-suppress.sh ==="

# 1. No background_tasks field → notification emitted
OUT="$(run_on '{"session_id":"s1"}')"
if echo "$OUT" | grep -Fq 'terminalSequence'; then
  echo "  PASS: absent background_tasks → emitted"; PASS=$((PASS+1))
else
  echo "  FAIL: expected emission, got: [$OUT]"; FAIL=$((FAIL+1))
fi

# 2. Empty background_tasks array → notification emitted
OUT="$(run_on '{"session_id":"s1","background_tasks":[]}')"
if echo "$OUT" | grep -Fq 'terminalSequence'; then
  echo "  PASS: background_tasks=[] → emitted"; PASS=$((PASS+1))
else
  echo "  FAIL: expected emission with empty array, got: [$OUT]"; FAIL=$((FAIL+1))
fi

# 3. Non-empty background_tasks → suppressed (no emission)
OUT="$(run_on '{"session_id":"s1","background_tasks":[{"id":"bg1","status":"running"}]}')"
if echo "$OUT" | grep -Fq 'terminalSequence'; then
  echo "  FAIL: expected suppression, but emitted: [$OUT]"; FAIL=$((FAIL+1))
else
  echo "  PASS: pending background_tasks → suppressed"; PASS=$((PASS+1))
fi

# 4. Default-OFF (env unset → defaults to off) → never emits, regardless of payload.
#    Use `env -u` so the assertion is independent of the machine's ambient setting.
OUT="$(env -u CLAUDE_KIT_PHASE_COMPLETION_NOTIFY CLAUDE_WORKFLOW_STATE_DIR="$TMP" bash "$HOOK" <<< '{"session_id":"s1"}' 2>/dev/null)"
if echo "$OUT" | grep -Fq 'terminalSequence'; then
  echo "  FAIL: default-OFF should not emit, got: [$OUT]"; FAIL=$((FAIL+1))
else
  echo "  PASS: default-OFF → no emission"; PASS=$((PASS+1))
fi

echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ "${FAIL}" -eq 0 ]] && exit 0 || exit 1
