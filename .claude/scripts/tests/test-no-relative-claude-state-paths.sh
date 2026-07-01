#!/usr/bin/env bash
# test-no-relative-claude-state-paths.sh
# Part 5 (stray-.claude fix): INVARIANT GUARD. No hook script may define its workflow-state or
# agent-memory write directory as a BARE RELATIVE `.claude/...` literal — such a path resolves
# against the hook's cwd (docs: "Handlers run in the current directory"), scattering stray
# .claude/ dirs into random subdirs of the user's project. Every state/memory write dir MUST be
# anchored to ${CLAUDE_PROJECT_DIR:-${REPO_ROOT}} (see .claude/scripts/lib/paths.sh).
#
# Scope: HOOK scripts under .claude/scripts/*.sh, EXCLUDING test-*.sh (test harnesses control their
# own cwd and legitimately use relative paths inside mktemp sandboxes). Deferred and NOT guarded:
# cwd-relative `.claude/prompts` READS (a distinct context-miss concern, not a stray-dir write).

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
HOOKS_DIR="${REPO_ROOT}/.claude/scripts"

# The detector prints "file:line: text" for every bare-relative state/memory write-path literal.
# A bare-relative literal = an opening quote (single OR double) DIRECTLY followed by
# .claude/(workflow-state|agent-memory). This catches the pre-fix convention
# `STATE_DIR=".claude/workflow-state"` / `DST_DIR='.claude/agent-memory/...'` and `mkdir "..."`
# literals. It does NOT match:
#   - anchored forms `"${CLAUDE...}/.claude/workflow-state}"` (the `.claude` is slash-preceded);
#   - path-continuation `"$WORKTREE_PATH/.claude/agent-memory/..."` (slash-preceded);
#   - python fallbacks `os.environ.get(..., ".claude/...")` (excluded by ENV_EXCL, matched tightly
#     to the fallback shape so a real bad line that merely mentions os.environ.get is NOT excused);
#   - prose message strings / relative READS (`ls .claude/...`) — space-preceded, not quote-preceded.
# Accepted, documented limitation: unquoted assignments (STATE_DIR=.claude/...) and unquoted
# mkdir/cd literals are not matched — none occur in the hook set (universal convention: quoted
# state-dir assignment). Broadening beyond quote-anchored would false-positive on prose + reads.
detect_relative_state_paths() { # dir
  local d="$1" f
  local FLAG_RE='["'"'"']\.claude/(workflow-state|agent-memory)'
  local ENV_EXCL='os\.environ\.get\([^)]*,[[:space:]]*["'"'"']\.claude/'
  for f in "$d"/*.sh; do
    [[ -e "$f" ]] || continue
    case "$(basename "$f")" in test-*) continue ;; esac   # skip test harnesses
    grep -nE "$FLAG_RE" "$f" \
      | grep -vE "$ENV_EXCL" \
      | grep -vE '^[0-9]+:[[:space:]]*#' \
      | sed "s#^#$(basename "$f"):#"
  done
}

rc=0

# ── (1) SELF-TEST (non-vacuous): the detector MUST flag synthetic bad hooks (double AND single quote) ──
tmp="$(mktemp -d)"
cat > "${tmp}/bad-double.sh" <<'BAD'
#!/usr/bin/env bash
STATE_DIR=".claude/workflow-state"
mkdir -p "$STATE_DIR"
BAD
cat > "${tmp}/bad-single.sh" <<'BAD'
#!/usr/bin/env bash
DST_DIR='.claude/agent-memory/code-reviewer'
mkdir -p "$DST_DIR"
BAD
if [[ -z "$(detect_relative_state_paths "$tmp" | grep 'bad-double.sh')" ]]; then
  echo "[test-no-relative-claude-state-paths] FAIL: detector VACUOUS — missed a double-quoted violation" >&2; rc=1
fi
if [[ -z "$(detect_relative_state_paths "$tmp" | grep 'bad-single.sh')" ]]; then
  echo "[test-no-relative-claude-state-paths] FAIL: detector missed a SINGLE-quoted violation (CR-001 regression)" >&2; rc=1
fi
[[ $rc -eq 0 ]] && echo "[test-no-relative-claude-state-paths] self-test OK: detector flags double- and single-quoted violations" >&2
# and it must NOT flag the anchored form / env-get fallback / prose
cat > "${tmp}/good-hook.sh" <<'GOOD'
#!/usr/bin/env bash
STATE_DIR="${CLAUDE_WORKFLOW_STATE_DIR:-${CLAUDE_PROJECT_DIR:-${REPO_ROOT}}/.claude/workflow-state}"
SRC_DIR="$WORKTREE_PATH/.claude/agent-memory/$AGENT_TYPE"
# python: STATE_DIR = os.environ.get("STATE_DIR") or os.environ.get("CLAUDE_WORKFLOW_STATE_DIR", ".claude/workflow-state")
echo "Project STATE (.claude/prompts, .claude/workflow-state, .claude/agent-memory) note"
GOOD
rm -f "${tmp}/bad-double.sh" "${tmp}/bad-single.sh"
if [[ -n "$(detect_relative_state_paths "$tmp")" ]]; then
  echo "[test-no-relative-claude-state-paths] FAIL: detector false-positives on anchored/env-get/prose forms:" >&2
  detect_relative_state_paths "$tmp" | sed 's/^/    /' >&2
  rc=1
fi
rm -rf "$tmp"

# ── (2) INVARIANT: zero bare-relative state/memory write paths in real hook scripts ──
violations="$(detect_relative_state_paths "$HOOKS_DIR")"
if [[ -n "$violations" ]]; then
  echo "[test-no-relative-claude-state-paths] FAIL: bare-relative state/memory write path in hook script(s):" >&2
  echo "$violations" | sed 's/^/    /' >&2
  echo "    -> anchor to \${CLAUDE_WORKFLOW_STATE_DIR:-\${CLAUDE_PROJECT_DIR:-\${REPO_ROOT}}/.claude/workflow-state} (see lib/paths.sh)" >&2
  rc=1
fi

[[ $rc -eq 0 ]] && echo "[test-no-relative-claude-state-paths] PASS"
exit $rc
