#!/usr/bin/env bash
# test-hotpath-hooks-state-anchor.sh
# Stray-.claude fix: the hot-path Pre/PostToolUse logger hooks must anchor their
# LOG_DIR/STATE_DIR to ${CLAUDE_PROJECT_DIR} (project root), NOT to a relative `.claude/...`
# path that resolves against the hook's cwd. When Claude Code fires a hook with cwd = a
# subdirectory (docs: "Handlers run in the current directory"), a relative path scatters a
# stray `.claude/workflow-state` into that subdir. See .claude/workflow-feature-2026-07-01.md.
#
# Two layers:
#   (A) STRUCTURAL — every target script's LOG_DIR/STATE_DIR definition references CLAUDE_PROJECT_DIR.
#   (B) BEHAVIORAL — firing the hook with cwd=subdir + CLAUDE_PROJECT_DIR=root creates state at
#       the ROOT and leaves NO stray `.claude` in the subdir.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SCRIPTS="${REPO_ROOT}/.claude/scripts"

rc=0
fail() { echo "[test-hotpath-hooks-state-anchor] FAIL: $*" >&2; rc=1; }

# ── (A) STRUCTURAL: LOG_DIR/STATE_DIR must anchor to CLAUDE_PROJECT_DIR ──
for s in auto-fmt.sh pre-commit-build.sh protect-files.sh; do
  def="$(grep -nE '^[[:space:]]*(LOG_DIR|STATE_DIR)=' "${SCRIPTS}/${s}" | head -1)"
  if [[ -z "${def}" ]]; then fail "${s}: no LOG_DIR/STATE_DIR definition found"; continue; fi
  if ! echo "${def}" | grep -q 'CLAUDE_PROJECT_DIR'; then
    fail "${s}: LOG_DIR/STATE_DIR not anchored to CLAUDE_PROJECT_DIR -> ${def}"
  fi
done

# ── (B) BEHAVIORAL: protect-files.sh + auto-fmt.sh mkdir their LOG_DIR unconditionally ──
command -v python3 >/dev/null 2>&1 || { echo "[test-hotpath-hooks-state-anchor] SKIP behavioral: python3 unavailable" >&2; [[ $rc -eq 0 ]] && echo "[test-hotpath-hooks-state-anchor] PASS (structural only)"; exit $rc; }

behavioral_no_stray() {
  local script="$1" payload="$2"
  local base proj sub
  base="$(mktemp -d)"; proj="${base}/proj"; sub="${proj}/internal/service"
  mkdir -p "${proj}/.claude/scripts" "${sub}"
  cp "${SCRIPTS}/${script}" "${proj}/.claude/scripts/${script}"
  ( cd "${sub}" && printf '%s' "${payload}" | CLAUDE_PROJECT_DIR="${proj}" bash "${proj}/.claude/scripts/${script}" ) >/dev/null 2>&1 || true
  if [[ -d "${sub}/.claude" ]]; then
    fail "${script}: stray .claude created in subdir cwd (${sub}/.claude)"
  fi
  if [[ ! -d "${proj}/.claude/workflow-state" ]]; then
    fail "${script}: expected state dir at project root (${proj}/.claude/workflow-state) not created"
  fi
  rm -rf "${base}"
}

# protect-files.sh: benign (non-protected) file path -> mkdir runs, then clean exit.
behavioral_no_stray protect-files.sh '{"tool_name":"Write","tool_input":{"file_path":"/tmp/benign.txt"}}'
# auto-fmt.sh: mkdir runs before the file-existence check; any payload reaches it.
behavioral_no_stray auto-fmt.sh '{"tool_name":"Write","tool_input":{"file_path":"/tmp/none.go"},"tool_response":{"success":true}}'

[[ $rc -eq 0 ]] && echo "[test-hotpath-hooks-state-anchor] PASS"
exit $rc
