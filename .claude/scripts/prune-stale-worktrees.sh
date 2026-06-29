#!/usr/bin/env bash
# prune-stale-worktrees.sh [max_age_hours]
#
# Standalone maintenance helper (NOT hook-wired). Reaps leaked, locked
# .claude/worktrees/agent-* registrations left by killed worktree-isolated reviewer
# agents on Claude Code < 2.1.187 (which has no platform auto-clean; CC 2.1.187 makes
# this redundant — see .claude/docs/platform-guarantees.md). Run manually:
#     bash .claude/scripts/prune-stale-worktrees.sh [max_age_hours]
# Default threshold 6h (positional arg — intentionally NOT an env var). Best-effort:
# always exits 0; never blocks. Stderr convention: [prune-stale-worktrees] LABEL: msg.
# A threshold of 0 DISABLES the age guard (reaps ALL agent-* registrations regardless of
# age) — use only for a deliberate full sweep, never the default.
#
# Safety: only touches worktrees under .claude/worktrees/agent-* (scope guard); never the
# main worktree (it is not under that prefix); only reaps registrations older than the
# threshold (review agents finish in minutes, so >= 6h is definitively a dead agent — the
# age guard errs safe for any active worktree). Does NOT delete the leftover
# worktree-agent-* branches (git branch -D is in the user permission deny-list; the refs
# are harmless).
set -uo pipefail

MAX_AGE_HOURS="${1:-6}"
case "$MAX_AGE_HOURS" in ''|*[!0-9]*) MAX_AGE_HOURS=6 ;; esac

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[prune-stale-worktrees] SKIP: not inside a git work tree" >&2
  exit 0
fi

COMMON_DIR="$(git rev-parse --git-common-dir 2>/dev/null)" || {
  echo "[prune-stale-worktrees] SKIP: cannot resolve git-common-dir" >&2; exit 0; }
COMMON_DIR="$(cd "$COMMON_DIR" 2>/dev/null && pwd -P)" || {
  echo "[prune-stale-worktrees] SKIP: git-common-dir unreadable" >&2; exit 0; }

NOW="$(date +%s)"
MAX_AGE_SECS=$(( MAX_AGE_HOURS * 3600 ))

mtime_of() {  # metadata dir -> epoch mtime (empty if missing/unreadable)
  [[ -e "$1" ]] || { echo ""; return; }
  if [[ "$(uname)" == "Darwin" ]]; then stat -f %m "$1" 2>/dev/null; else stat -c %Y "$1" 2>/dev/null; fi
}

removed=0
while IFS= read -r line; do
  case "$line" in
    "worktree "*) wt="${line#worktree }" ;;
    *) continue ;;
  esac
  # Scope guard: only kit reviewer worktrees (never the main worktree or unrelated ones).
  case "$wt" in
    */.claude/worktrees/agent-*) ;;
    *) continue ;;
  esac
  name="$(basename "$wt")"
  # AGE SOURCE (PR-002): the .git/worktrees/<name> METADATA-dir mtime — the same signal
  # resolve-worktree-path.py Strategy 2 trusts. (PR-006) Metadata mtime approximates the
  # last git activity on the worktree; for a leaked/killed agent that is its creation/lock
  # time (nothing writes to it after the agent dies), so age >= threshold is a reliable
  # "definitively dead" signal. The metadata dir also persists when the checkout directory
  # is already gone, so this same path covers the locked + dir-missing orphan shape.
  meta="${COMMON_DIR}/worktrees/${name}"
  m="$(mtime_of "$meta")"
  [[ -z "$m" ]] && continue
  age=$(( NOW - m ))
  if (( age >= MAX_AGE_SECS )); then
    # PR-001: a single --force will NOT remove a LOCKED worktree; unlock first, then remove.
    git worktree unlock "$wt" >/dev/null 2>&1 || true
    git worktree remove --force "$wt" >/dev/null 2>&1 || true
    removed=$(( removed + 1 ))
    echo "[prune-stale-worktrees] INFO: reaped stale worktree ${name} (age $(( age / 3600 ))h >= ${MAX_AGE_HOURS}h)" >&2
  fi
done < <(git worktree list --porcelain 2>/dev/null)

# Sweep any now-unlocked, dir-missing residue (covers the locked+dir-missing shape after unlock).
git worktree prune >/dev/null 2>&1 || true
echo "[prune-stale-worktrees] INFO: reaped ${removed} stale worktree(s) under .claude/worktrees/agent-*; ran git worktree prune" >&2
exit 0
