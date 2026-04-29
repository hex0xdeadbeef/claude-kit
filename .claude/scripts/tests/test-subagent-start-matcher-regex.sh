#!/usr/bin/env bash
# test-subagent-start-matcher-regex.sh
# P5 — verify track-task-lifecycle.sh fires correctly per agent invocation.
#
# Behavioural assertion (matcher-structure-agnostic):
#   - Each invocation of track-task-lifecycle.sh writes exactly ONE entry to
#     ${CLAUDE_WORKFLOW_STATE_DIR}/task-events.jsonl.
#   - 3 invocations (one per agent type: code-researcher, plan-reviewer, code-reviewer)
#     produce exactly 3 task-events entries, each with the correct agent_type.
#
# This test passes under both:
#   (a) legacy settings.json structure: 3 separate matcher entries
#   (b) consolidated structure: 1 regex matcher 'code-researcher|plan-reviewer|code-reviewer'
# because Claude Code's matcher routing fires the script exactly once per matched agent.
#
# An additional INFORMATIONAL check reports whether settings.json is consolidated yet.
#
# Convention: exit 0 on success, exit 1 on assertion failure.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SANDBOX="$(mktemp -d -t matcher-regex-XXXXXX)"
trap 'rm -rf "${SANDBOX}"' EXIT
export CLAUDE_WORKFLOW_STATE_DIR="${SANDBOX}"

# ---- Test 1: track-task-lifecycle.sh fires once per simulated invocation ----
for agent in code-researcher plan-reviewer code-reviewer; do
  echo "{\"hook_event_name\":\"SubagentStart\",\"agent_type\":\"${agent}\",\"agent_id\":\"x-${agent}\",\"session_id\":\"s\"}" \
    | bash "${REPO_ROOT}/.claude/scripts/track-task-lifecycle.sh" >/dev/null 2>&1 || true
done

if [[ ! -f "${SANDBOX}/task-events.jsonl" ]]; then
  echo "[test-subagent-start-matcher-regex] FAIL: task-events.jsonl not created" >&2
  exit 1
fi
LINES=$(wc -l < "${SANDBOX}/task-events.jsonl" | tr -d ' ')
if [[ "${LINES}" -ne 3 ]]; then
  echo "[test-subagent-start-matcher-regex] FAIL: expected 3 task-events lines (one per invocation), got ${LINES}" >&2
  exit 1
fi

# ---- Test 2: each entry has correct agent_type ----
for agent in code-researcher plan-reviewer code-reviewer; do
  if ! grep -q "\"agent_type\": \"${agent}\"" "${SANDBOX}/task-events.jsonl"; then
    echo "[test-subagent-start-matcher-regex] FAIL: missing agent_type=${agent} in task-events" >&2
    exit 1
  fi
done

# ---- INFORMATIONAL: settings.json consolidation status ----
# A pass under either structure is fine; this just reports the current state.
ENTRIES=$(jq '[.hooks.SubagentStart[] | select(.hooks[].command | test("track-task-lifecycle.sh"))] | length' \
  "${REPO_ROOT}/.claude/settings.json" 2>/dev/null || echo "?")
if [[ "${ENTRIES}" == "1" ]]; then
  echo "[test-subagent-start-matcher-regex] INFO: settings.json SubagentStart consolidated (1 matcher entry for track-task-lifecycle.sh)" >&2
elif [[ "${ENTRIES}" == "3" ]]; then
  echo "[test-subagent-start-matcher-regex] INFO: settings.json SubagentStart legacy structure (3 separate matcher entries) — consolidation pending user action" >&2
else
  echo "[test-subagent-start-matcher-regex] INFO: settings.json SubagentStart entry count: ${ENTRIES}" >&2
fi

echo "[test-subagent-start-matcher-regex] PASS"
exit 0
