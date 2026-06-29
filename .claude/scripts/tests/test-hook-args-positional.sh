#!/usr/bin/env bash
# RED then GREEN: handlers that take a positional argument (inject-review-context.sh and
# caveman-suspend-for-reviewer.sh) must deliver the expected agent-type token via args[0].
# Part 1 step 1.5 of changelog-v2.1.121-141-uplift.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SETTINGS="${REPO_ROOT}/.claude/settings.json"

# Map: matcher -> expected args[0] for each script under SubagentStart
check_arg() {
  local matcher="$1"
  local script_suffix="$2"
  local expected="$3"
  local actual
  actual="$(jq -r --arg m "${matcher}" --arg s "${script_suffix}" '
    .hooks.SubagentStart[]?
    | select(.matcher == $m)
    | .hooks[]?
    | select(.type == "command")
    | select(.command | endswith($s))
    | .args[0] // empty
  ' "${SETTINGS}" | head -n1)"
  if [[ "${actual}" != "${expected}" ]]; then
    echo "[test-hook-args-positional] FAIL: matcher=${matcher} script=${script_suffix} expected args[0]='${expected}' got '${actual}'" >&2
    return 1
  fi
}

rc=0
check_arg "(claude-kit:)?plan-reviewer"   "inject-review-context.sh"        "plan-reviewer"   || rc=1
check_arg "(claude-kit:)?code-reviewer"   "inject-review-context.sh"        "code-reviewer"   || rc=1
check_arg "(claude-kit:)?code-researcher" "caveman-suspend-for-reviewer.sh" "code-researcher" || rc=1
check_arg "(claude-kit:)?plan-reviewer"   "caveman-suspend-for-reviewer.sh" "plan-reviewer"   || rc=1
check_arg "(claude-kit:)?code-reviewer"   "caveman-suspend-for-reviewer.sh" "code-reviewer"   || rc=1
check_arg "(claude-kit:)?verdict-recovery" "caveman-suspend-for-reviewer.sh" "verdict-recovery" || rc=1

if [[ "${rc}" -ne 0 ]]; then
  exit 1
fi
echo "[test-hook-args-positional] PASS"
