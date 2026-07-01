#!/usr/bin/env bash
# R2 (F-P3): agent_type namespace strip in save-review-checkpoint.sh + track-task-lifecycle.sh.
# A plugin-namespaced 'claude-kit:plan-reviewer' must normalize to bare 'plan-reviewer' so the
# exact-match membership tests (REVIEW_AGENTS, agent-id registry) fire. Identity on bare inputs.
# agent_type is NOT a canonical-ID hash input, so this cannot affect issue-ID stability.
# Harness mirrors test-subagent-type-normalize.sh (emit_save). Both hooks now anchor STATE_DIR to
# CLAUDE_PROJECT_DIR (stray-.claude fix 2026-07-01), so case A sets CLAUDE_PROJECT_DIR="$tmp".
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SAVE_HOOK="${SRC_DIR}/save-review-checkpoint.sh"
TRACK_HOOK="${SRC_DIR}/track-task-lifecycle.sh"
PASS=0; FAIL=0
command -v python3 >/dev/null 2>&1 || { echo "SKIP: python3 required"; exit 0; }

field() { python3 -c "import json,sys
try: print(json.load(sys.stdin).get(sys.argv[1],''))
except Exception: print('')" "$1"; }

emit_save() {  # agent_type agent_id  -> prints last review-completions marker (honors env state dir)
  local at="$1" aid="$2" tmp payload out
  tmp="$(mktemp -d)"
  payload="$(python3 -c "import json,sys; print(json.dumps({'agent_type':sys.argv[1],'agent_id':sys.argv[2],'session_id':'s1','last_assistant_message':'VERDICT: APPROVED\n\nReview complete.'}))" "$at" "$aid")"
  CLAUDE_WORKFLOW_STATE_DIR="$tmp" bash "$SAVE_HOOK" <<< "$payload" >/dev/null 2>&1
  out="$(tail -n1 "$tmp/review-completions.jsonl" 2>/dev/null)"
  rm -rf "$tmp"
  printf '%s' "$out"
}

emit_track_registry_type() {  # agent_type agent_id -> prints agent-id-registry entry's agent_type
  local at="$1" aid="$2" tmp payload out
  tmp="$(mktemp -d)"; mkdir -p "$tmp/.claude/workflow-state"
  payload="$(python3 -c "import json,sys; print(json.dumps({'agent_type':sys.argv[1],'agent_id':sys.argv[2],'session_id':'s1','hook_event_name':'SubagentStart'}))" "$at" "$aid")"
  ( cd "$tmp" && CLAUDE_PROJECT_DIR="$tmp" bash "$TRACK_HOOK" <<< "$payload" >/dev/null 2>&1 )
  out="$(tail -n1 "$tmp/.claude/workflow-state/agent-id-registry.jsonl" 2>/dev/null)"
  rm -rf "$tmp"
  printf '%s' "$out" | field agent_type
}

echo "=== test-agent-type-namespace-strip.sh ==="

# Case A — track-task-lifecycle: namespaced -> registry records bare type
A="$(emit_track_registry_type "claude-kit:plan-reviewer" "ns-a")"
if [[ "$A" == "plan-reviewer" ]]; then
  echo "  PASS: A track-task-lifecycle 'claude-kit:plan-reviewer' -> registry agent_type=plan-reviewer"; PASS=$((PASS+1))
else
  echo "  FAIL: A registry agent_type='$A' (expected plan-reviewer)"; FAIL=$((FAIL+1))
fi

# Case B — save-review-checkpoint: namespaced -> marker effective_agent_type bare
B="$(emit_save "claude-kit:plan-reviewer" "ns-b" | field effective_agent_type)"
if [[ "$B" == "plan-reviewer" ]]; then
  echo "  PASS: B save-review-checkpoint 'claude-kit:plan-reviewer' -> effective_agent_type=plan-reviewer"; PASS=$((PASS+1))
else
  echo "  FAIL: B effective_agent_type='$B' (expected plan-reviewer)"; FAIL=$((FAIL+1))
fi

# Case C — identity on bare inputs (no regression) in BOTH hooks
C1="$(emit_track_registry_type "plan-reviewer" "id-c1")"
C2="$(emit_save "plan-reviewer" "id-c2" | field effective_agent_type)"
if [[ "$C1" == "plan-reviewer" && "$C2" == "plan-reviewer" ]]; then
  echo "  PASS: C identity — bare 'plan-reviewer' unchanged in both hooks"; PASS=$((PASS+1))
else
  echo "  FAIL: C identity drift — track='$C1' save='$C2'"; FAIL=$((FAIL+1))
fi

echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ "${FAIL}" -eq 0 ]] && exit 0 || exit 1
