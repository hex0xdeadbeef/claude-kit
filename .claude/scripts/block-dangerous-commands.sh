#!/bin/bash
# Hook: PreToolUse (matcher: Bash — regex on tool_name)
# Purpose: Block destructive bash commands (rm -rf, git reset --hard, etc.)
# Blocking: exit 0 + permissionDecision:"deny" for dangerous commands
# Non-blocking: exit 0 (no output) for safe commands, exit 2 if python3 missing
#
# Categories blocked:
#   - Destructive rm (rm -rf, rm -fr, rm -r -f)
#   - Git destructive (reset --hard, clean -f/--force, push --force, checkout ., restore .)
#   - File truncation (truncate, : >)
#   - Disk operations (dd if=, mkfs.)
#   - Unsafe permissions (chmod 777/0777, a+w)
#   - Privilege escalation (sudo)

set -euo pipefail

# ── Hard dependency: python3 ──
command -v python3 >/dev/null 2>&1 || {
  echo "block-dangerous-commands: python3 required but not found" >&2
  exit 2
}

# ── Read stdin JSON ──
INPUT=$(cat)

# ── Log directory ──
LOG_DIR=".claude/workflow-state"
LOG_FILE="$LOG_DIR/hook-log.txt"
mkdir -p "$LOG_DIR" 2>/dev/null || {
  echo "block-dangerous-commands: cannot create log directory" >&2
  exit 2
}

# ── Parse command from stdin ──
COMMAND=$(echo "$INPUT" | python3 -c "
import json, sys
try:
    data = json.loads(sys.stdin.read())
    print(data.get('tool_input', {}).get('command', ''))
except Exception as e:
    print('')
    print(f'JSON parse error: {e}', file=sys.stderr)
" 2>>"$LOG_FILE") || COMMAND=""

# ── Empty command — allow ──
if [[ -z "$COMMAND" ]]; then
  exit 0
fi

# ── Check dangerous patterns (regex) ──
DENY_REASON=""

# Category 1: Destructive rm (rm with -rf or -fr flags, combined or split)
# Fix BLOCKER-1: Also catch space-separated flags: rm -r -f
if echo "$COMMAND" | grep -qE '\brm\s+(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r)\b'; then
  DENY_REASON="Destructive rm command (rm -rf). Remove specific files instead: rm file.go"
elif echo "$COMMAND" | grep -qE '\brm\s+.*-r\s+.*-f|\brm\s+.*-f\s+.*-r'; then
  DENY_REASON="Destructive rm command (rm -r -f). Remove specific files instead: rm file.go"

# Category 2: git reset --hard
elif echo "$COMMAND" | grep -qE '\bgit\s+reset\s+--hard\b'; then
  DENY_REASON="Destructive git reset --hard. Use git stash to save changes, or git checkout -- <file> for specific files."

# Category 3: git clean with -f flag (short or long form)
# Fix MINOR-2: Also catch --force (long form)
elif echo "$COMMAND" | grep -qE '\bgit\s+clean\s+.*(-[a-zA-Z]*f|--force)'; then
  DENY_REASON="Destructive git clean -f. Use git status to review, then remove specific files manually."

# Category 4: git push --force / -f (but NOT --force-with-lease)
# Fix MAJOR-1: Exclude --force-with-lease (safe alternative)
elif echo "$COMMAND" | grep -qE '\bgit\s+push\s+.*--force\b' && ! echo "$COMMAND" | grep -qE '\-\-force-with-lease'; then
  DENY_REASON="Destructive git push --force. Use git push or git push --force-with-lease."
elif echo "$COMMAND" | grep -qE '\bgit\s+push\s+.*-f\b'; then
  DENY_REASON="Destructive git push -f. Use git push without -f."

# Category 5: git checkout . (discard all changes)
# Fix BLOCKER-3: Replace $ anchor with chain-aware ending
elif echo "$COMMAND" | grep -qE '\bgit\s+checkout\s+\.\s*($|&&|\|\||;)'; then
  DENY_REASON="Destructive git checkout . (discards ALL changes). Use git checkout -- <specific-file> instead."
elif echo "$COMMAND" | grep -qE '\bgit\s+checkout\s+--\s+\.\s*($|&&|\|\||;)'; then
  DENY_REASON="Destructive git checkout -- . (discards ALL changes). Use git checkout -- <specific-file> instead."

# Category 5b: git restore . (modern equivalent)
# Fix MAJOR-2: git restore . is equivalent to git checkout .
elif echo "$COMMAND" | grep -qE '\bgit\s+restore\s+\.\s*($|&&|\|\||;)'; then
  DENY_REASON="Destructive git restore . (discards ALL changes). Use git restore <specific-file> instead."

# Category 6: truncate / : > (file truncation)
elif echo "$COMMAND" | grep -qE '\btruncate\s+'; then
  DENY_REASON="File truncation command. Use Edit tool to modify file contents instead."
elif echo "$COMMAND" | grep -qE ':\s*>\s*\S'; then
  DENY_REASON="File truncation (: > file). Use Edit tool to modify file contents instead."

# Category 7: dd (disk operations)
elif echo "$COMMAND" | grep -qE '\bdd\s+if='; then
  DENY_REASON="Disk operation (dd). Not needed in this workflow."

# Category 8: mkfs (filesystem format)
elif echo "$COMMAND" | grep -qE '\bmkfs\.'; then
  DENY_REASON="Filesystem format (mkfs). Not needed in this workflow."

# Category 9: chmod 777 / 0777 / a+w (world-writable)
# Fix BLOCKER-5: Handle octal prefix 0777
elif echo "$COMMAND" | grep -qE '\bchmod\s+(-[a-zA-Z]*\s+)*0?777\b'; then
  DENY_REASON="Unsafe permissions (chmod 777). Use chmod 644 for files or chmod 755 for directories."
elif echo "$COMMAND" | grep -qE '\bchmod\s+.*\ba\+w\b'; then
  DENY_REASON="Unsafe permissions (chmod a+w). Use specific user/group permissions instead."

# Category 10: sudo (privilege escalation)
# Fix BLOCKER-6: Remove ^ anchor — catch sudo in chained commands
elif echo "$COMMAND" | grep -qE '\bsudo\s+'; then
  DENY_REASON="Privilege escalation (sudo). Not needed in this workflow — all operations run as current user."
fi

# ── If dangerous — deny with explanation ──
if [[ -n "$DENY_REASON" ]]; then
  # Truncate command for logging (may be very long)
  LOG_CMD=$(echo "$COMMAND" | head -c 200)
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] block-dangerous: BLOCKED [$LOG_CMD] — $DENY_REASON" >> "$LOG_FILE"

  export DENY_REASON
  python3 -c "
import json, os
output = {
    'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'permissionDecision': 'deny',
        'permissionDecisionReason': os.environ.get('DENY_REASON', 'Dangerous command blocked')
    }
}
print(json.dumps(output))
"
  exit 0
fi

# ── Not dangerous — allow ──
exit 0
