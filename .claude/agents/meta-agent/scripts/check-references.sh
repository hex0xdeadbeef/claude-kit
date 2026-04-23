#!/usr/bin/env bash
# check-references.sh — PostToolUse hook (Write)
# Deterministic reference validation after writing .claude/ artifacts.
#
# Hook contract:
#   stdin: JSON {"tool_name":"Write","tool_input":{"file_path":"..."},"tool_result":{"content":"..."}}
#   stdout: validation messages (informational)
#   exit 0 always
#
# Checks:
#   1. All ref:/deps/ references point to existing files
#   2. All arrow (→) references point to existing files
#   3. Legacy SEE: references (warn to migrate)
#   4. No self-references

set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Skip agent-memory paths — avoid hook amplification loop during agent memory saves
if [[ "$FILE_PATH" == *"agent-memory"* ]]; then
  exit 0
fi

# --- PK-01: PROJECT-KNOWLEDGE.md canonical path check ---
# Canonical path is the canonical form (SEE .claude/rules/workflow.md → Path Conventions).
# Detects the bare form (no `.claude/` prefix) and logs to stdout.
# Runs for ANY file type (this block is BEFORE the .md-only filter below).
# Output: stdout (consistent with existing ❌/✅/⚠️ pattern in this script).
# Exit: 0 (non-blocking WARN) by default. Strict mode via CLAUDE_PK_PATH_MODE=strict (opt-in, exit 2).
# Implementation note: uses perl instead of `grep -P` because BSD grep on macOS does
# not support PCRE lookbehind; perl 5.x is preinstalled on macOS/Linux and supports it natively.
#
# Exemption list (files that legitimately contain the bare-form literal):
#   - this script (check-references.sh) — regex literal appears in comments + echo
#   - .claude/rules/workflow.md — canonical rule doc describing the forbidden form
# Without these exemptions the hook self-fires and blocks its own maintenance (strict mode).
PK_SKIP=false
case "$FILE_PATH" in
  *check-references.sh|*.claude/rules/workflow.md|.claude/rules/workflow.md)
    PK_SKIP=true
    ;;
esac
if [[ "$PK_SKIP" == "false" ]] && [[ -f "$FILE_PATH" ]]; then
  PK_BARE_LINES=$(perl -ne 'print "$.:$_" if /(?<![\/.])PROJECT-KNOWLEDGE\.md/' "$FILE_PATH" 2>/dev/null || true)
  if [[ -n "$PK_BARE_LINES" ]]; then
    if [[ "${CLAUDE_PK_PATH_MODE:-warn}" == "strict" ]]; then
      echo "❌ PK path validation FAILED for ${FILE_PATH}:"
    else
      echo "⚠️  PK path validation WARN for ${FILE_PATH}:"
    fi
    while IFS= read -r occurrence; do
      echo "  - PK_PATH: bare form detected — use the canonical '.claude/' prefix (${occurrence})"
    done <<< "$PK_BARE_LINES"
    if [[ "${CLAUDE_PK_PATH_MODE:-warn}" == "strict" ]]; then
      exit 2
    fi
  fi
fi
# --- end PK-01 ---

# Only check .claude/ artifact files
if [[ ! "$FILE_PATH" =~ \.claude/ ]] || [[ ! "$FILE_PATH" =~ \.md$ ]]; then
  exit 0
fi

if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

# Determine the .claude/ root directory
CLAUDE_ROOT=$(echo "$FILE_PATH" | sed 's|\(.*/\.claude/\).*|\1|')
if [[ ! -d "$CLAUDE_ROOT" ]]; then
  exit 0
fi

ERRORS=()
WARNINGS=()

# Extract all referenced file paths from patterns:
#   ref: "deps/file.md"          — new standard format
#   "→ deps/file.md"             — arrow inline format
#   # → deps/file.md             — arrow comment format
#   deps/something.md            — bare deps/ path
#   SEE: path/to/file.md         — legacy format (will warn)

# New format: ref fields and arrow references
# Note: || true prevents pipefail from killing script when grep finds no matches
NEW_REFS=$(grep -oP '(?:ref:\s*"|"→\s*|#\s*→\s*)[a-zA-Z0-9_./-]+\.md' "$FILE_PATH" 2>/dev/null | \
           grep -oP '[a-zA-Z0-9_./-]+\.md' | sort -u || true)

# Bare deps/ paths (catches both old and new)
DEPS_REFS=$(grep -oP 'deps/[a-zA-Z0-9_.-]+\.md' "$FILE_PATH" 2>/dev/null | sort -u || true)

# Legacy SEE: references (should be migrated)
LEGACY_REFS=$(grep -oP 'SEE:\s*["\x27]?[a-zA-Z0-9_./-]+\.md' "$FILE_PATH" 2>/dev/null | \
              grep -oP '[a-zA-Z0-9_./-]+\.md' | sort -u || true)
if [[ -n "$LEGACY_REFS" ]]; then
  WARNINGS+=("REF_FORMAT: Found legacy SEE: references in ${FILE_PATH} — migrate to ref: format")
fi

ALL_REFS=$(echo -e "${NEW_REFS}\n${DEPS_REFS}\n${LEGACY_REFS}" | sort -u | grep -v '^$' || true)

if [[ -z "$ALL_REFS" ]]; then
  exit 0
fi

# Resolve and check each reference
while IFS= read -r ref; do
  [[ -z "$ref" ]] && continue

  # Try multiple resolution strategies
  FOUND=false

  # Strategy 1: relative to file's directory
  FILE_DIR=$(dirname "$FILE_PATH")
  if [[ -f "${FILE_DIR}/${ref}" ]]; then
    FOUND=true
  fi

  # Strategy 2: relative to .claude/ root
  if [[ "$FOUND" == "false" ]] && [[ -f "${CLAUDE_ROOT}${ref}" ]]; then
    FOUND=true
  fi

  # Strategy 3: search in agents/*/deps/
  if [[ "$FOUND" == "false" ]]; then
    BASENAME=$(basename "$ref")
    SEARCH=$(find "$CLAUDE_ROOT" -name "$BASENAME" -type f 2>/dev/null | head -1)
    if [[ -n "$SEARCH" ]]; then
      FOUND=true
    fi
  fi

  # Self-reference check
  if [[ "$(basename "$FILE_PATH")" == "$(basename "$ref")" ]]; then
    WARNINGS+=("REF_CHECK: Possible self-reference to ${ref}")
    continue
  fi

  if [[ "$FOUND" == "false" ]]; then
    ERRORS+=("REF_CHECK: Broken reference '${ref}' in ${FILE_PATH} — file not found")
  fi
done <<< "$ALL_REFS"

# Output results
if (( ${#ERRORS[@]} > 0 )); then
  echo "❌ Reference validation FAILED for ${FILE_PATH}:"
  for err in "${ERRORS[@]}"; do
    echo "  - ${err}"
  done
fi

if (( ${#WARNINGS[@]} > 0 )); then
  for warn in "${WARNINGS[@]}"; do
    echo "  ⚠️ ${warn}"
  done
fi

if (( ${#ERRORS[@]} == 0 )) && (( ${#WARNINGS[@]} == 0 )); then
  echo "✅ Reference validation passed: ${FILE_PATH}"
fi
