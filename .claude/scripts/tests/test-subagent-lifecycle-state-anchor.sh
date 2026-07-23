#!/usr/bin/env bash
# test-subagent-lifecycle-state-anchor.sh
# Stray-.claude fix: the subagent-lifecycle hooks that write workflow-state
# (track-task-lifecycle.sh SubagentStart, save-review-checkpoint.sh SubagentStop,
# inject-review-context.sh SubagentStart) must anchor STATE_DIR to ${CLAUDE_PROJECT_DIR},
# never a relative `.claude/workflow-state` that resolves against the hook's cwd.
# These scripts embed python heredocs that INDEPENDENTLY re-derive the state dir, so the
# bash-resolved absolute STATE_DIR must be exported and preferred by the python.
# See .claude/workflow-feature-2026-07-01.md.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SCRIPTS="${REPO_ROOT}/.claude/scripts"

rc=0
fail() { echo "[test-subagent-lifecycle-state-anchor] FAIL: $*" >&2; rc=1; }

# ── (A) STRUCTURAL: bash STATE_DIR anchors to CLAUDE_PROJECT_DIR; python prefers exported STATE_DIR ──
for s in track-task-lifecycle.sh save-review-checkpoint.sh inject-review-context.sh; do
  f="${SCRIPTS}/${s}"
  bashdef="$(grep -nE '^[[:space:]]*STATE_DIR=' "$f" | head -1)"
  if ! echo "$bashdef" | grep -q 'CLAUDE_PROJECT_DIR'; then
    fail "${s}: bash STATE_DIR not anchored to CLAUDE_PROJECT_DIR -> ${bashdef:-<none>}"
  fi
  if ! grep -q 'export STATE_DIR' "$f"; then
    fail "${s}: STATE_DIR not exported (embedded python cannot see resolved dir)"
  fi
  # every embedded-python state-dir derivation must read the exported STATE_DIR env
  if grep -qE '(STATE_DIR|state_dir)[[:space:]]*=[[:space:]]*os\.environ' "$f"; then
    if ! grep -qE 'os\.environ\.get\("STATE_DIR"' "$f"; then
      fail "${s}: python state-dir derivation does not prefer os.environ.get(\"STATE_DIR\")"
    fi
  fi
done

# ── (B) BEHAVIORAL: fire each hook with cwd=subdir + CLAUDE_PROJECT_DIR=root, no CLAUDE_WORKFLOW_STATE_DIR ──
command -v python3 >/dev/null 2>&1 || { echo "[test-subagent-lifecycle-state-anchor] SKIP behavioral: python3 unavailable" >&2; [[ $rc -eq 0 ]] && echo "[test-subagent-lifecycle-state-anchor] PASS (structural only)"; exit $rc; }

behavioral_no_stray() {
  local script="$1" arg="$2" payload="$3"
  local base proj sub
  base="$(mktemp -d)"; proj="${base}/proj"; sub="${proj}/internal/service"
  mkdir -p "${proj}/.claude/scripts" "${sub}"
  cp "${SCRIPTS}/${script}" "${proj}/.claude/scripts/${script}"
  ( cd "${sub}" && printf '%s' "${payload}" | CLAUDE_PROJECT_DIR="${proj}" bash "${proj}/.claude/scripts/${script}" ${arg} ) >/dev/null 2>&1 || true
  if [[ -d "${sub}/.claude" ]]; then
    fail "${script}: stray .claude created in subdir cwd (${sub}/.claude)"
  fi
  if [[ ! -d "${proj}/.claude/workflow-state" ]]; then
    fail "${script}: expected state dir at project root (${proj}/.claude/workflow-state) not created"
  fi
  rm -rf "${base}"
}

behavioral_no_stray track-task-lifecycle.sh "" '{"hook_event_name":"SubagentStart","agent_type":"code-researcher","agent_id":"a1","session_id":"s1"}'
behavioral_no_stray save-review-checkpoint.sh "" '{"hook_event_name":"SubagentStop","agent_type":"code-reviewer","agent_id":"a1","session_id":"s1","last_assistant_message":"VERDICT: APPROVED"}'
behavioral_no_stray inject-review-context.sh "code-reviewer" '{"session_id":"s1"}'

# Isolate the REPO_ROOT-fallback branch — omit CLAUDE_PROJECT_DIR (and CLAUDE_WORKFLOW_STATE_DIR)
# entirely. The script is copied under ${proj}/.claude/scripts/, so REPO_ROOT (=SCRIPT_DIR/../..) == ${proj};
# state must still anchor to ${proj}, never the subdir cwd.
behavioral_reporoot_branch() {
  local script="$1" arg="$2" payload="$3"
  local base proj sub
  base="$(mktemp -d)"; proj="${base}/proj"; sub="${proj}/internal/service"
  mkdir -p "${proj}/.claude/scripts" "${sub}"
  cp "${SCRIPTS}/${script}" "${proj}/.claude/scripts/${script}"
  ( cd "${sub}" && printf '%s' "${payload}" | env -u CLAUDE_PROJECT_DIR -u CLAUDE_WORKFLOW_STATE_DIR bash "${proj}/.claude/scripts/${script}" ${arg} ) >/dev/null 2>&1 || true
  if [[ -d "${sub}/.claude" ]]; then
    fail "${script} (REPO_ROOT branch): stray .claude in subdir cwd (${sub}/.claude)"
  fi
  if [[ ! -d "${proj}/.claude/workflow-state" ]]; then
    fail "${script} (REPO_ROOT branch): expected state at REPO_ROOT (${proj}/.claude/workflow-state) not created"
  fi
  rm -rf "${base}"
}
behavioral_reporoot_branch track-task-lifecycle.sh "" '{"hook_event_name":"SubagentStart","agent_type":"code-researcher","agent_id":"a1","session_id":"s1"}'

[[ $rc -eq 0 ]] && echo "[test-subagent-lifecycle-state-anchor] PASS"
exit $rc
