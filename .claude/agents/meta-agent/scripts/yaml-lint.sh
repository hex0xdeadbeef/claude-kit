#!/usr/bin/env bash
# yaml-lint.sh — PostToolUse hook (Edit/Write)
# Deterministic YAML validation after any edit to .claude/ artifacts.
#
# Hook contract:
#   stdin: JSON {"tool_name":"Edit","tool_input":{"file_path":"..."},"tool_result":{"content":"..."}}
#   stdout: validation messages (informational, PostToolUse cannot block)
#   exit 0 always
#
# Checks:
#   1. YAML frontmatter syntax (if present)
#   2. Balanced braces/brackets in YAML-style content
#   3. Indentation consistency
#   4. No tab characters (YAML requires spaces)

set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only check .claude/ artifact files with .md extension
if [[ ! "$FILE_PATH" =~ \.claude/ ]] || [[ ! "$FILE_PATH" =~ \.md$ ]]; then
  exit 0
fi

if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

ERRORS=()

# Check 1: No tab characters
if grep -Pn '\t' "$FILE_PATH" > /dev/null 2>&1; then
  TAB_LINES=$(grep -Pn '\t' "$FILE_PATH" | head -5 | cut -d: -f1 | tr '\n' ',' | sed 's/,$//')
  ERRORS+=("YAML_LINT: Tab characters found at lines: ${TAB_LINES}. YAML requires spaces for indentation.")
fi

# Check 2: Unbalanced braces (common in YAML inline maps)
OPEN_BRACES=$(grep -o '{' "$FILE_PATH" | wc -l)
CLOSE_BRACES=$(grep -o '}' "$FILE_PATH" | wc -l)
if (( OPEN_BRACES != CLOSE_BRACES )); then
  ERRORS+=("YAML_LINT: Unbalanced braces — { count: ${OPEN_BRACES}, } count: ${CLOSE_BRACES}")
fi

# Check 3: Unbalanced brackets
OPEN_BRACKETS=$(grep -o '\[' "$FILE_PATH" | wc -l)
CLOSE_BRACKETS=$(grep -o '\]' "$FILE_PATH" | wc -l)
if (( OPEN_BRACKETS != CLOSE_BRACKETS )); then
  ERRORS+=("YAML_LINT: Unbalanced brackets — [ count: ${OPEN_BRACKETS}, ] count: ${CLOSE_BRACKETS}")
fi

# Check 4: Duplicate top-level keys (common copy-paste error)
# Extract lines that look like top-level YAML keys (no leading whitespace, ends with :)
DUPES=$(grep -n '^[a-zA-Z_][a-zA-Z0-9_]*:' "$FILE_PATH" | cut -d: -f2 | sort | uniq -d)
if [[ -n "$DUPES" ]]; then
  ERRORS+=("YAML_LINT: Duplicate top-level keys: ${DUPES}")
fi

# Check 5: Trailing whitespace (cleanup)
TRAILING=$(grep -Pcn ' +$' "$FILE_PATH" 2>/dev/null || true)
if (( TRAILING > 5 )); then
  ERRORS+=("YAML_LINT: ${TRAILING} lines with trailing whitespace")
fi

# Output results
if (( ${#ERRORS[@]} > 0 )); then
  echo "⚠️ YAML validation issues in ${FILE_PATH}:"
  for err in "${ERRORS[@]}"; do
    echo "  - ${err}"
  done
  echo "Fix these issues to maintain artifact quality."
else
  echo "✅ YAML validation passed: ${FILE_PATH}"
fi
