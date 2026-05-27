#!/usr/bin/env bash
# test-subagent-type-normalize.sh — I-04: defensive subagent_type normalization in
# save-review-checkpoint.sh. Case/separator variants resolve to the canonical agent name;
# already-canonical inputs keep marker fields byte-identical (agent_type is NOT a
# canonical-ID hash input, so issue-ID stability is unaffected — proven by EX-3).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="${SCRIPT_DIR}/../save-review-checkpoint.sh"
PASS=0; FAIL=0
command -v python3 >/dev/null 2>&1 || { echo "SKIP: python3 required"; exit 0; }

# Run the hook in a sandbox state dir with a plan-reviewer payload (plan-reviewer is NOT a
# worktree agent → no worktree-resolution subprocess). A plain VERDICT line keeps verdict
# != UNKNOWN so the IMP-H verdict-block path is not entered. Prints the marker JSON line.
emit() {  # agent_type  agent_id
  local at="$1" aid="$2" tmp payload out
  tmp="$(mktemp -d)"
  payload="$(python3 -c "import json,sys; print(json.dumps({'agent_type':sys.argv[1],'agent_id':sys.argv[2],'session_id':'s1','last_assistant_message':'VERDICT: APPROVED\n\nReview complete.'}))" "$at" "$aid")"
  CLAUDE_WORKFLOW_STATE_DIR="$tmp" bash "$HOOK" <<< "$payload" >/dev/null 2>&1
  out="$(tail -n1 "$tmp/review-completions.jsonl" 2>/dev/null)"
  rm -rf "$tmp"
  printf '%s' "$out"
}
field() { python3 -c "import json,sys
try: print(json.load(sys.stdin).get(sys.argv[1],''))
except Exception: print('')" "$1"; }

echo "=== test-subagent-type-normalize.sh ==="

# 1-3. Case/separator variants resolve to canonical effective_agent_type
i=0
for variant in "Plan Reviewer" "plan_reviewer" "PLAN-REVIEWER"; do
  i=$((i+1))
  EFF="$(emit "$variant" "id-var-$i" | field effective_agent_type)"
  if [[ "$EFF" == "plan-reviewer" ]]; then
    echo "  PASS: '$variant' → effective_agent_type=plan-reviewer"; PASS=$((PASS+1))
  else
    echo "  FAIL: '$variant' → effective_agent_type='$EFF' (expected plan-reviewer)"; FAIL=$((FAIL+1))
  fi
done

# 4. Canonical input: marker fields byte-stable (agent / agent_raw / effective all canonical)
M="$(emit "plan-reviewer" "id-canon")"
AG="$(printf '%s' "$M" | field agent)"
RAW="$(printf '%s' "$M" | field agent_raw)"
EFF="$(printf '%s' "$M" | field effective_agent_type)"
if [[ "$AG" == "plan-reviewer" && "$RAW" == "plan-reviewer" && "$EFF" == "plan-reviewer" ]]; then
  echo "  PASS: canonical 'plan-reviewer' → agent/agent_raw/effective byte-stable"; PASS=$((PASS+1))
else
  echo "  FAIL: canonical drift — agent='$AG' agent_raw='$RAW' effective='$EFF'"; FAIL=$((FAIL+1))
fi

echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ "${FAIL}" -eq 0 ]] && exit 0 || exit 1
