#!/bin/bash
# Hook: PostToolUse (matcher: Write|Edit)
# Purpose: Auto-format source files per project's FMT_CMD slot from PROJECT-KNOWLEDGE.md
# Cascade: PROJECT-KNOWLEDGE.md → CLAUDE.md Language Profile → SKIP
# Non-blocking: exit 0 on success/skip; exit 2 only if python3 missing
#
# Contract:
#   stdin: JSON {"tool_name":"Write|Edit","tool_input":{"file_path":"..."},"tool_response":{"success":bool}}
#   stdout: silent on success; debug logs to .claude/workflow-state/hook-log.txt
#   stderr: only on python3-missing (exit 2)
#
# Slot semantics:
#   FMT_CMD            — formatter command. May contain literal "{}" — substituted with the
#                        shell-escaped file path (per-file mode). Without "{}" → run as-is
#                        (whole-project mode). Empty or "(none ...)" → SKIP.
#   LANG_EXT           — comma-separated list of file extensions (with leading dot). Hook
#                        fires only when the changed file's extension is in this list.
#   GENERATED_PATTERN  — comma-separated bash globs. Matching files SKIPped (not formatted).
#   MOCK_PATTERN       — comma-separated bash globs. Matching files SKIPped.
#
# Backwards compat (AC-P3-6): when LANG_EXT contains .go AND both skip slots are unset,
# applies historical Go-default skips (*_gen.go, */mocks/*.go, */vendor/*).
#
# Note on cascade format: this hook reads `KEY: value` lines from BOTH PROJECT-KNOWLEDGE.md
# and CLAUDE.md. The kit's CLAUDE.md (Language Profile section) uses inline `FMT=` syntax in a
# "Commands:" line — that format is NOT supported by this parser. Users relying on CLAUDE.md
# fallback should add explicit `- KEY: value` lines OR (preferred) populate
# .claude/PROJECT-KNOWLEDGE.md.
#
# Note on FMT_CMD format (PR-f23384de):
#   FMT_CMD MUST begin with the formatter binary token (the first whitespace-delimited word
#   of FMT_CMD, extracted via `awk '{print $1}'` default field-split, is what `command -v`
#   checks). The `{}` placeholder MAY appear LATER as an argument. Templates beginning with
#   `{}` (e.g., `{} --check`) are not supported and will cause a `command -v {} not found`
#   WARN + SKIP.
#   ✓ supported:   `gofmt -w {}`, `make fmt`, `black --quiet {}`, `prettier --write {}`
#   ✗ unsupported: `{} --check`, `{}-fmt -w` (placeholder cannot be the binary)
#
# Note on path quoting:
#   The substituted `{}` is shell-escaped via `printf '%q'` before being injected into CMD.
#   This preserves the quoted-path semantics of the prior Go-only hook (which used
#   `gofmt -w "$FILE_PATH"` with explicit double-quotes) for paths containing spaces,
#   single-quotes, or shell metacharacters. The eval'd CMD therefore receives the path
#   as one safe-quoted token regardless of FILE_PATH content.

set -euo pipefail

# ── Hard dependency: python3 ──
command -v python3 >/dev/null 2>&1 || {
  echo "[auto-fmt] ERROR: python3 required but not found" >&2
  exit 2
}

# ── Read stdin ──
INPUT=$(cat)

# ── Log directory ──
# stray-.claude fix (2026-07-01): anchor state to project root, never cwd (hooks run in cwd).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LOG_DIR="${CLAUDE_WORKFLOW_STATE_DIR:-${CLAUDE_PROJECT_DIR:-${REPO_ROOT}}/.claude/workflow-state}"
LOG_FILE="$LOG_DIR/hook-log.txt"
mkdir -p "$LOG_DIR" 2>/dev/null || exit 0

ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# ── Parse stdin: extract file_path and tool_response.success ──
# success defaults to True when tool_response is absent (matches the prior Go-only hook).
PARSE=$(echo "$INPUT" | python3 -c "
import json, sys
try:
    data = json.loads(sys.stdin.read())
except Exception:
    print('|false'); sys.exit(0)
fp = data.get('tool_input', {}).get('file_path', '')
ok = str(data.get('tool_response', {}).get('success', True))
print(f'{fp}|{ok}')
" 2>/dev/null) || PARSE="|false"

FILE_PATH=$(echo "$PARSE" | cut -d'|' -f1)
SUCCESS=$(echo "$PARSE" | cut -d'|' -f2)

# ── Skip on tool failure or empty/missing path ──
if [[ "$SUCCESS" == "false" || "$SUCCESS" == "False" ]]; then
  exit 0
fi
if [[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]]; then
  exit 0
fi

# ── Slot cascade resolver ──
# Reads "- KEY: value" line from PROJECT-KNOWLEDGE.md first, then CLAUDE.md.
# Strips trailing inline comments (only when the value is not fully quoted),
# strips surrounding quotes, and treats values starting with "(none" as empty.
# Returns empty string on miss.
resolve_slot() {
  local key="$1"
  local val=""
  for src in ".claude/PROJECT-KNOWLEDGE.md" "CLAUDE.md"; do
    [[ -f "$src" ]] || continue
    val=$(KEY="$key" SRC="$src" python3 - <<'PYEOF' 2>/dev/null || true
import os, re, sys
key = os.environ['KEY']
path = os.environ['SRC']
try:
    with open(path, 'r', encoding='utf-8') as f:
        for line in f:
            m = re.match(r'^[\s\-*]*' + re.escape(key) + r'\s*:\s*(.*)$', line)
            if m:
                v = m.group(1).rstrip('\n')
                # Strip trailing inline comment ONLY when the value is not fully quoted.
                # Match YAML inline-comment delimiter ' #' (space-hash) instead of bare '#'
                # so '#' chars inside FMT_CMD args (e.g., black --target=#3) survive parsing
                # even when the value is not fully quoted (CR-003 robustness).
                stripped = v.strip()
                if not ((stripped.startswith('"') and stripped.endswith('"')) or
                        (stripped.startswith("'") and stripped.endswith("'"))):
                    if ' #' in v:
                        v = v.split(' #', 1)[0]
                v = v.strip()
                # Strip surrounding quotes
                if (v.startswith('"') and v.endswith('"')) or (v.startswith("'") and v.endswith("'")):
                    v = v[1:-1]
                # Treat literal "(none ...)" as empty
                if v.lower().startswith('(none'):
                    v = ''
                print(v)
                sys.exit(0)
except Exception:
    pass
PYEOF
)
    if [[ -n "$val" ]]; then
      printf '%s' "$val"
      return 0
    fi
  done
  printf ''
}

FMT_CMD=$(resolve_slot "FMT_CMD")
LANG_EXT=$(resolve_slot "LANG_EXT")
GENERATED_PATTERN=$(resolve_slot "GENERATED_PATTERN")
MOCK_PATTERN=$(resolve_slot "MOCK_PATTERN")

# ── SKIP: FMT_CMD unset ──
if [[ -z "$FMT_CMD" ]]; then
  echo "[$(ts)] auto-fmt: SKIP FMT_CMD unset for $(basename "$FILE_PATH")" >> "$LOG_FILE"
  exit 0
fi

# ── SKIP: LANG_EXT unresolved ──
if [[ -z "$LANG_EXT" ]]; then
  echo "[$(ts)] auto-fmt: SKIP LANG_EXT unresolved for $(basename "$FILE_PATH")" >> "$LOG_FILE"
  exit 0
fi

# ── Extension match (case-insensitive, leading-dot tolerated) ──
ext_lower=".${FILE_PATH##*.}"
ext_lower="$(echo "$ext_lower" | tr '[:upper:]' '[:lower:]')"
match=false
IFS=',' read -ra EXTS <<<"$LANG_EXT"
for e in "${EXTS[@]}"; do
  e_norm="$(echo "$e" | xargs | tr '[:upper:]' '[:lower:]')"
  [[ -z "$e_norm" ]] && continue
  # Tolerate missing leading dot in slot value (e.g. "go" instead of ".go")
  [[ "$e_norm" != .* ]] && e_norm=".$e_norm"
  if [[ "$ext_lower" == "$e_norm" ]]; then
    match=true; break
  fi
done
if [[ "$match" == "false" ]]; then
  exit 0
fi

# ── Glob match against comma-separated patterns ──
match_glob_csv() {
  local csv="$1" path="$2"
  local IFS=','
  read -ra PATS <<<"$csv"
  for p in "${PATS[@]}"; do
    p_norm="$(echo "$p" | xargs)"
    [[ -z "$p_norm" ]] && continue
    case "$path" in
      $p_norm) return 0;;
    esac
  done
  return 1
}

# ── SKIP: generated file ──
if [[ -n "$GENERATED_PATTERN" ]] && match_glob_csv "$GENERATED_PATTERN" "$FILE_PATH"; then
  echo "[$(ts)] auto-fmt: SKIP generated $(basename "$FILE_PATH")" >> "$LOG_FILE"
  exit 0
fi

# ── SKIP: mock file ──
if [[ -n "$MOCK_PATTERN" ]] && match_glob_csv "$MOCK_PATTERN" "$FILE_PATH"; then
  echo "[$(ts)] auto-fmt: SKIP mock $(basename "$FILE_PATH")" >> "$LOG_FILE"
  exit 0
fi

# ── Backwards-compat (AC-P3-6): Go-default skips when LANG_EXT contains .go and both slots unset ──
if [[ -z "$GENERATED_PATTERN" && -z "$MOCK_PATTERN" ]]; then
  lang_ext_norm=",$(echo "$LANG_EXT" | tr -d '[:space:]"' | tr '[:upper:]' '[:lower:]'),"
  if [[ "$lang_ext_norm" == *",.go,"* ]]; then
    case "$FILE_PATH" in
      *_gen.go|*/mocks/*.go|*/vendor/*)
        echo "[$(ts)] auto-fmt: SKIP go-default-skip $(basename "$FILE_PATH")" >> "$LOG_FILE"
        exit 0
        ;;
    esac
  fi
fi

# ── Build CMD: substitute {} → shell-escaped file path; otherwise run as-is ──
# Shell-escape via `printf '%q'` so paths containing spaces, single-quotes, or shell
# metacharacters survive the eval below intact (preserves the explicit double-quote
# semantics of the prior Go-only hook).
if [[ "$FMT_CMD" == *"{}"* ]]; then
  ESCAPED_PATH="$(printf '%q' "$FILE_PATH")"
  CMD="${FMT_CMD//\{\}/$ESCAPED_PATH}"
else
  CMD="$FMT_CMD"
fi

# ── Verify the binary exists ──
BIN="$(echo "$FMT_CMD" | awk '{print $1}')"
if [[ -z "$BIN" ]] || ! command -v "$BIN" >/dev/null 2>&1; then
  echo "[$(ts)] auto-fmt: WARN $BIN not found, skipping" >> "$LOG_FILE"
  exit 0
fi

# ── Run formatter ──
# Use && || pattern so set -e does not kill the script when CMD exits non-zero.
FMT_OUTPUT=$(eval "$CMD" 2>&1) && FMT_STATUS=0 || FMT_STATUS=$?
if [[ $FMT_STATUS -eq 0 ]]; then
  echo "[$(ts)] auto-fmt: formatted $(basename "$FILE_PATH") via [$CMD]" >> "$LOG_FILE"
else
  echo "[$(ts)] auto-fmt: FAILED on $(basename "$FILE_PATH") [$CMD] (exit $FMT_STATUS): $FMT_OUTPUT" >> "$LOG_FILE"
fi

exit 0