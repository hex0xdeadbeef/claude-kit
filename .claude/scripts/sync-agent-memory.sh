#!/bin/bash
# Purpose: Sync agent memory from worktree to main repository
# Usage: sync-agent-memory.sh <agent_type> <worktree_path>
# Exit codes: 0=success/no_files, 1=error, 2=invalid args
#
# Standalone utility extracted from save-review-checkpoint.sh (IMP-05).
# Can be called from SubagentStop hook or manually for debugging.
# Memory sync is NON_CRITICAL — caller decides whether to block on failure.
#
# Safety (IMP-08, 2026-03-30):
#   - Only copies files NEWER than their main-repo counterparts (cp -p preserves mtime)
#   - Skips files identical to main repo (seeded but unmodified by agent)
#   - Never deletes main-repo files — additive sync only
#
# Output (stdout JSON): {"result": "synced|no_files|no_src_dir|error|skipped_all", "files": [...]}
# Logs (stderr): human-readable status messages

set -euo pipefail

AGENT_TYPE="${1:-}"
WORKTREE_PATH="${2:-}"

if [[ -z "$AGENT_TYPE" || -z "$WORKTREE_PATH" ]]; then
  echo "Usage: sync-agent-memory.sh <agent_type> <worktree_path>" >&2
  echo '{"result": "error", "files": [], "error": "missing arguments"}'
  exit 2
fi

if [[ ! -d "$WORKTREE_PATH" ]]; then
  echo "sync-agent-memory: worktree path does not exist: $WORKTREE_PATH" >&2
  echo '{"result": "error", "files": [], "error": "worktree path not found"}'
  exit 1
fi

# IMP-08: Validate worktree_path is a real worktree, not a bogus JSON-named dir
# Worktree paths must be absolute and should not contain JSON characters
if [[ ! "$WORKTREE_PATH" = /* ]] || [[ "$WORKTREE_PATH" = *"{"* ]] || [[ "$WORKTREE_PATH" = *"}"* ]]; then
  echo "sync-agent-memory: rejecting suspicious worktree path: $WORKTREE_PATH" >&2
  echo '{"result": "error", "files": [], "error": "invalid worktree path"}'
  exit 1
fi

SRC_DIR="$WORKTREE_PATH/.claude/agent-memory/$AGENT_TYPE"
DST_DIR=".claude/agent-memory/$AGENT_TYPE"

if [[ ! -d "$SRC_DIR" ]]; then
  echo "sync-agent-memory: no memory dir in worktree for $AGENT_TYPE" >&2
  echo '{"result": "no_src_dir", "files": []}'
  exit 0
fi

# Collect regular files (non-recursive)
REGULAR_FILES=()
for f in "$SRC_DIR"/*; do
  [[ -f "$f" ]] && REGULAR_FILES+=("$f")
done

if [[ ${#REGULAR_FILES[@]} -eq 0 ]]; then
  echo "sync-agent-memory: memory dir exists but no files for $AGENT_TYPE" >&2
  echo '{"result": "no_files", "files": []}'
  exit 0
fi

# Create destination (if it doesn't exist)
mkdir -p "$DST_DIR"

SYNCED_FILES=()
SKIPPED_FILES=()
ERRORS=()

for src_file in "${REGULAR_FILES[@]}"; do
  filename=$(basename "$src_file")
  dst_file="$DST_DIR/$filename"

  # IMP-08: Only sync files that were actually modified by the agent
  # Skip if destination exists and files are identical (seeded but unmodified)
  if [[ -f "$dst_file" ]]; then
    if cmp -s "$src_file" "$dst_file"; then
      SKIPPED_FILES+=("$filename")
      continue
    fi
    # Additional safety: skip if worktree file is older than main-repo file
    if [[ "$dst_file" -nt "$src_file" ]]; then
      echo "sync-agent-memory: skipping $filename (main repo is newer)" >&2
      SKIPPED_FILES+=("$filename")
      continue
    fi
  fi

  if cp -p "$src_file" "$dst_file" 2>/dev/null; then
    SYNCED_FILES+=("$filename")
  else
    ERRORS+=("$filename")
  fi
done

# Build JSON output
if [[ ${#SYNCED_FILES[@]} -eq 0 && ${#ERRORS[@]} -eq 0 ]]; then
  SKIPPED_JSON=$(printf '"%s",' "${SKIPPED_FILES[@]}" | sed 's/,$//')
  echo "sync-agent-memory: all ${#SKIPPED_FILES[@]} file(s) unchanged for $AGENT_TYPE" >&2
  echo "{\"result\": \"skipped_all\", \"files\": [], \"skipped\": [$SKIPPED_JSON]}"
  exit 0
fi

FILES_JSON=""
if [[ ${#SYNCED_FILES[@]} -gt 0 ]]; then
  FILES_JSON=$(printf '"%s",' "${SYNCED_FILES[@]}" | sed 's/,$//')
fi

ERRORS_JSON=""
if [[ ${#ERRORS[@]} -gt 0 ]]; then
  ERRORS_JSON=$(printf '"%s",' "${ERRORS[@]}" | sed 's/,$//')
fi

if [[ ${#ERRORS[@]} -gt 0 ]]; then
  echo "sync-agent-memory: synced ${#SYNCED_FILES[@]}, failed ${#ERRORS[@]}, skipped ${#SKIPPED_FILES[@]} for $AGENT_TYPE" >&2
  echo "{\"result\": \"partial\", \"files\": [$FILES_JSON], \"errors\": [$ERRORS_JSON]}"
  exit 1
else
  echo "sync-agent-memory: synced ${#SYNCED_FILES[@]}, skipped ${#SKIPPED_FILES[@]} for $AGENT_TYPE: ${SYNCED_FILES[*]}" >&2
  echo "{\"result\": \"synced\", \"files\": [$FILES_JSON]}"
  exit 0
fi
