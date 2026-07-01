#!/usr/bin/env bash
# test-lifecycle-compact-state-anchor.sh
# Part 3 (stray-.claude fix): the session / compact / stop lifecycle hooks must anchor their
# state dir to ${CLAUDE_PROJECT_DIR}, never a relative `.claude/workflow-state` resolved against
# the hook's cwd. Covers enrich-context.sh (UserPromptSubmit), save-progress-before-compact.sh
# (PreCompact), verify-state-after-compact.sh (PostCompact), session-analytics.sh (SessionEnd),
# check-uncommitted.sh (Stop). The first four embed python heredocs that re-derive the dir from
# CLAUDE_WORKFLOW_STATE_DIR, so the bash-resolved STATE_DIR is exported and preferred by python.
# check-uncommitted.sh uses a bash-only STATE_DIR_LOCAL. See .claude/workflow-feature-2026-07-01.md.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SCRIPTS="${REPO_ROOT}/.claude/scripts"

rc=0
fail() { echo "[test-lifecycle-compact-state-anchor] FAIL: $*" >&2; rc=1; }

# ── (A) STRUCTURAL ──
for s in enrich-context.sh save-progress-before-compact.sh verify-state-after-compact.sh session-analytics.sh; do
  f="${SCRIPTS}/${s}"
  echo "$(grep -nE '^[[:space:]]*STATE_DIR=' "$f" | head -1)" | grep -q 'CLAUDE_PROJECT_DIR' \
    || fail "${s}: bash STATE_DIR not anchored to CLAUDE_PROJECT_DIR"
  grep -q 'export STATE_DIR' "$f" || fail "${s}: STATE_DIR not exported (python heredoc cannot see resolved dir)"
  grep -qE 'os\.environ\.get\("STATE_DIR"\)' "$f" || fail "${s}: python does not prefer os.environ.get(\"STATE_DIR\")"
done
# check-uncommitted.sh uses STATE_DIR_LOCAL (bash-only)
echo "$(grep -nE 'STATE_DIR_LOCAL=' "${SCRIPTS}/check-uncommitted.sh" | head -1)" | grep -q 'CLAUDE_PROJECT_DIR' \
  || fail "check-uncommitted.sh: STATE_DIR_LOCAL not anchored to CLAUDE_PROJECT_DIR"

# ── (B) BEHAVIORAL: fire with cwd=subdir + CLAUDE_PROJECT_DIR=root; assert no stray in subdir ──
command -v python3 >/dev/null 2>&1 || { echo "[test-lifecycle-compact-state-anchor] SKIP behavioral: python3 unavailable" >&2; [[ $rc -eq 0 ]] && echo "[test-lifecycle-compact-state-anchor] PASS (structural only)"; exit $rc; }

fire_no_stray() { # script payload  [expect_state_at_root]
  local script="$1" payload="$2" expect_root="${3:-}"
  local base proj sub
  base="$(mktemp -d)"; proj="${base}/proj"; sub="${proj}/internal/service"
  mkdir -p "${proj}/.claude/scripts" "${sub}"
  cp "${SCRIPTS}/${script}" "${proj}/.claude/scripts/${script}"
  cp -R "${SCRIPTS}/lib" "${proj}/.claude/scripts/lib" 2>/dev/null || true   # so python state_render imports
  ( cd "${sub}" && printf '%s' "${payload}" | CLAUDE_PROJECT_DIR="${proj}" bash "${proj}/.claude/scripts/${script}" ) >/dev/null 2>&1 || true
  [[ -d "${sub}/.claude" ]] && fail "${script}: stray .claude created in subdir cwd (${sub}/.claude)"
  if [[ -n "${expect_root}" && ! -d "${proj}/.claude/workflow-state" ]]; then
    fail "${script}: expected state dir at project root not created"
  fi
  rm -rf "${base}"
}

fire_no_stray enrich-context.sh              '{"session_id":"s1","prompt":"hi"}'
fire_no_stray save-progress-before-compact.sh '{"session_id":"s1","trigger":"manual"}'
fire_no_stray verify-state-after-compact.sh  '{"session_id":"s1"}'
fire_no_stray session-analytics.sh           '{"session_id":"s1"}' expect_root   # unconditional os.makedirs(STATE_DIR)
fire_no_stray check-uncommitted.sh           '{"session_id":"s1"}'

[[ $rc -eq 0 ]] && echo "[test-lifecycle-compact-state-anchor] PASS"
exit $rc
