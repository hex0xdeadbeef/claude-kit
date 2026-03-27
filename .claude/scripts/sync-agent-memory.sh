#!/bin/bash
# Purpose: Sync agent memory from worktree to main repository
# Usage: sync-agent-memory.sh <agent_type> <worktree_path>
# Exit codes: 0=success/no_files, 1=error, 2=invalid args
#
# Standalone utility extracted from save-review-checkpoint.sh (IMP-05).
# Can be called from SubagentStop hook or manually for debugging.
# Memory sync is NON_CRITICAL — caller decides whether to block on failure.
#
# Output (stdout JSON): {"result": "synced|no_files|no_src_dir|error", "files": [...]}
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

# Create destination and copy
mkdir -p "$DST_DIR"

SYNCED_FILES=()
ERRORS=()

for src_file in "${REGULAR_FILES[@]}"; do
  filename=$(basename "$src_file")
  dst_file="$DST_DIR/$filename"
  if cp -p "$src_file" "$dst_file" 2>/dev/null; then
    SYNCED_FILES+=("$filename")
  else
    ERRORS+=("$filename")
  fi
done

# Build JSON output
FILES_JSON=$(printf '"%s",' "${SYNCED_FILES[@]}" | sed 's/,$//')
ERRORS_JSON=""
if [[ ${#ERRORS[@]} -gt 0 ]]; then
  ERRORS_JSON=$(printf '"%s",' "${ERRORS[@]}" | sed 's/,$//')
fi

if [[ ${#ERRORS[@]} -gt 0 ]]; then
  echo "sync-agent-memory: synced ${#SYNCED_FILES[@]}, failed ${#ERRORS[@]} for $AGENT_TYPE" >&2
  echo "{\"result\": \"partial\", \"files\": [$FILES_JSON], \"errors\": [$ERRORS_JSON]}"
  exit 1
else
  echo "sync-agent-memory: synced ${#SYNCED_FILES[@]} file(s) for $AGENT_TYPE: ${SYNCED_FILES[*]}" >&2
  echo "{\"result\": \"synced\", \"files\": [$FILES_JSON]}"
  exit 0
fi
