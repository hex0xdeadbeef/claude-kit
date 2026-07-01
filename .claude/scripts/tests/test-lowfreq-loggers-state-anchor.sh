#!/usr/bin/env bash
# test-lowfreq-loggers-state-anchor.sh
# Part 4 (stray-.claude fix): the low-frequency logger hooks + the agent-memory sync must anchor
# their write dir to ${CLAUDE_PROJECT_DIR}, never a relative path resolved against the hook's cwd.
#   audit-config-change.sh (ConfigChange), log-permission-denied.sh (PermissionDenied),
#   log-stop-failure.sh (StopFailure)  -> .claude/workflow-state (bash anchor + export + python prefers)
#   sync-agent-memory.sh (invoked as subprocess by save-review-checkpoint) -> .claude/agent-memory
# See .claude/workflow-feature-2026-07-01.md (Part 4).

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SCRIPTS="${REPO_ROOT}/.claude/scripts"

rc=0
fail() { echo "[test-lowfreq-loggers-state-anchor] FAIL: $*" >&2; rc=1; }

# ── (A) STRUCTURAL ──
for s in audit-config-change.sh log-permission-denied.sh log-stop-failure.sh; do
  f="${SCRIPTS}/${s}"
  grep -qE '^[[:space:]]*(STATE_DIR|LOG_DIR)="\$\{CLAUDE_WORKFLOW_STATE_DIR:-\$\{CLAUDE_PROJECT_DIR' "$f" \
    || fail "${s}: bash state/log dir not anchored to CLAUDE_PROJECT_DIR"
  grep -q 'export STATE_DIR' "$f" || fail "${s}: STATE_DIR not exported (python heredoc cannot see resolved dir)"
  grep -qE 'os\.environ\.get\("STATE_DIR"\)' "$f" || fail "${s}: python does not prefer os.environ.get(\"STATE_DIR\")"
done
# sync-agent-memory.sh: DST_DIR (agent-memory) anchored, bash-only
grep -qE '^[[:space:]]*DST_DIR="\$\{CLAUDE_PROJECT_DIR' "${SCRIPTS}/sync-agent-memory.sh" \
  || fail "sync-agent-memory.sh: DST_DIR not anchored to CLAUDE_PROJECT_DIR"

# ── (B) BEHAVIORAL ──
command -v python3 >/dev/null 2>&1 || { echo "[test-lowfreq-loggers-state-anchor] SKIP behavioral: python3 unavailable" >&2; [[ $rc -eq 0 ]] && echo "[test-lowfreq-loggers-state-anchor] PASS (structural only)"; exit $rc; }

fire_ws() { # script payload   (workflow-state writers: assert no stray + state at root)
  local script="$1" payload="$2" base proj sub
  base="$(mktemp -d)"; proj="${base}/proj"; sub="${proj}/internal/service"
  mkdir -p "${proj}/.claude/scripts" "${sub}"
  cp "${SCRIPTS}/${script}" "${proj}/.claude/scripts/${script}"
  ( cd "${sub}" && printf '%s' "${payload}" | CLAUDE_PROJECT_DIR="${proj}" bash "${proj}/.claude/scripts/${script}" ) >/dev/null 2>&1 || true
  [[ -d "${sub}/.claude" ]] && fail "${script}: stray .claude created in subdir cwd (${sub}/.claude)"
  [[ ! -d "${proj}/.claude/workflow-state" ]] && fail "${script}: expected workflow-state at project root not created"
  rm -rf "${base}"
}
fire_ws audit-config-change.sh '{"session_id":"s1"}'
fire_ws log-permission-denied.sh '{"tool_name":"Bash","tool_input":{"command":"x"}}'
fire_ws log-stop-failure.sh '{"session_id":"s1","error_type":"rate_limit","error_message":"x"}'

# sync-agent-memory.sh: fire from subdir cwd; DST must land in proj/.claude/agent-memory, not subdir
base="$(mktemp -d)"; proj="${base}/proj"; sub="${proj}/internal/service"; wt="${base}/wt"
mkdir -p "${proj}/.claude/scripts" "${sub}" "${wt}/.claude/agent-memory/code-reviewer"
cp "${SCRIPTS}/sync-agent-memory.sh" "${proj}/.claude/scripts/sync-agent-memory.sh"
printf 'mem\n' > "${wt}/.claude/agent-memory/code-reviewer/MEMORY.md"
( cd "${sub}" && CLAUDE_PROJECT_DIR="${proj}" bash "${proj}/.claude/scripts/sync-agent-memory.sh" code-reviewer "${wt}" ) >/dev/null 2>&1 || true
[[ -d "${sub}/.claude" ]] && fail "sync-agent-memory.sh: stray .claude created in subdir cwd (${sub}/.claude)"
[[ ! -f "${proj}/.claude/agent-memory/code-reviewer/MEMORY.md" ]] && fail "sync-agent-memory.sh: memory not synced to project-root agent-memory"
rm -rf "${base}"

[[ $rc -eq 0 ]] && echo "[test-lowfreq-loggers-state-anchor] PASS"
exit $rc
