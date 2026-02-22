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
#   1. All SEE: references point to existing files
#   2. All Read/Load references point to existing files
#   3. No self-references

set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

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

# Extract all referenced file paths from common patterns:
#   SEE: path/to/file.md
#   "path/to/file.md"
#   deps/something.md
REFS=$(grep -oP '(?:SEE:|Read |Load )\s*["\x27]?([a-zA-Z0-9_./-]+\.md)' "$FILE_PATH" | \
       grep -oP '[a-zA-Z0-9_./-]+\.md' | sort -u)

# Also check deps/ references
DEPS_REFS=$(grep -oP 'deps/[a-zA-Z0-9_-]+\.md' "$FILE_PATH" | sort -u)

ALL_REFS=$(echo -e "${REFS}\n${DEPS_REFS}" | sort -u | grep -v '^$')

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
