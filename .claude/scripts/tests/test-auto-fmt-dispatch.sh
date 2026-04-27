#!/usr/bin/env bash
# test-auto-fmt-dispatch.sh — verify auto-fmt.sh slot-driven dispatch (P1+P2+P3 ACs)
# Usage: bash .claude/scripts/tests/test-auto-fmt-dispatch.sh
# Covers: AC-P1-1..3, AC-P2-1..4, AC-P3-1..3 + cascade fallback + iter-2 regression guards
#
# 8 cases (TC-1..TC-8):
#   TC-1 Go per-file substitution        — AC-P2-2
#   TC-2 Whole-project (no `{}`)         — AC-P2-2
#   TC-3 Python via `{}`                 — AC-P1-1, AC-P1-2
#   TC-4 Empty FMT_CMD → SKIP            — AC-P2-3
#   TC-5 Generated-pattern skip          — AC-P3-2
#   TC-6 Cascade to CLAUDE.md            — AC-P2-1, AC-P1-2 cascade
#   TC-7 FAILED-branch logging           — PR-e22c8795 regression guard
#   TC-8 Missing tool_response key       — PR-34518de3 regression guard
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
HOOK="${REPO_ROOT}/.claude/scripts/auto-fmt.sh"

PASS=0
FAIL=0

if [[ ! -x "$HOOK" ]]; then
  echo "FAIL: hook not found or not executable at $HOOK"
  exit 1
fi

run_case() {
  # Args: <case-name> <pk-content> <claude-md-content> <relative-file-path>
  #       <expected-log-substring> [omit_tool_response]
  # When omit_tool_response=true, the synthetic JSON omits the tool_response key,
  # exercising the parser's default-success=True branch (CR-004 + PR-34518de3 guard).
  local name="$1" pk="$2" cl="$3" rel="$4" expect="$5" omit_tr="${6:-false}"

  local tmp; tmp=$(mktemp -d)
  mkdir -p "$tmp/.claude/workflow-state"
  if [[ -n "$pk" ]]; then
    printf '%s\n' "$pk" > "$tmp/.claude/PROJECT-KNOWLEDGE.md"
  fi
  if [[ -n "$cl" ]]; then
    printf '%s\n' "$cl" > "$tmp/CLAUDE.md"
  fi
  mkdir -p "$(dirname "$tmp/$rel")"
  : > "$tmp/$rel"

  # Build synthetic PostToolUse JSON
  local payload
  payload=$(TMP="$tmp" REL="$rel" OMIT_TR="$omit_tr" python3 -c "
import json, os
data = {
    'tool_name': 'Edit',
    'tool_input': {'file_path': os.environ['TMP'] + '/' + os.environ['REL']},
}
if os.environ['OMIT_TR'] != 'true':
    data['tool_response'] = {'success': True}
print(json.dumps(data))
")

  # Run hook from within tmp dir so relative paths (.claude/workflow-state, .claude/PROJECT-KNOWLEDGE.md)
  # resolve to the stub tree, not the live kit repo.
  ( cd "$tmp" && printf '%s' "$payload" | bash "$HOOK" ) >/dev/null 2>&1 || true

  local log="$tmp/.claude/workflow-state/hook-log.txt"
  local content=""
  [[ -f "$log" ]] && content=$(cat "$log")

  if echo "$content" | grep -qE "$expect"; then
    echo "  PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name"
    echo "    Expected log to match: $expect"
    echo "    Got:"
    if [[ -n "$content" ]]; then
      echo "$content" | sed 's/^/      /'
    else
      echo "      (empty hook-log.txt)"
    fi
    FAIL=$((FAIL + 1))
  fi

  rm -rf "$tmp"
}

echo "=== auto-fmt dispatch tests (P1+P2+P3 ACs) ==="

# TC-1: Go per-file substitution (AC-P2-2)
run_case \
  "TC-1 Go per-file via {} placeholder" \
  $'- LANG_EXT: .go\n- FMT_CMD: "echo perfile-{}"' \
  "" \
  "src/foo.go" \
  "perfile-.*src/foo\.go"

# TC-2: Whole-project (no {} placeholder) (AC-P2-2)
run_case \
  "TC-2 Whole-project (no placeholder)" \
  $'- LANG_EXT: .go\n- FMT_CMD: "echo wholeproj"' \
  "" \
  "src/foo.go" \
  "via \[echo wholeproj\]"

# TC-3: Python via {} (AC-P1-1, AC-P1-2)
run_case \
  "TC-3 Python via {} placeholder" \
  $'- LANG_EXT: .py\n- FMT_CMD: "echo py-{}"' \
  "" \
  "pkg/foo.py" \
  "py-.*pkg/foo\.py"

# TC-4: Empty FMT_CMD → SKIP (AC-P2-3)
run_case \
  "TC-4 Empty FMT_CMD --> SKIP" \
  $'- LANG_EXT: .go\n- FMT_CMD: ""' \
  "" \
  "src/foo.go" \
  "SKIP FMT_CMD unset"

# TC-5: Generated-pattern skip (AC-P3-2)
run_case \
  "TC-5 Generated pattern skip" \
  $'- LANG_EXT: .go\n- FMT_CMD: "echo never-{}"\n- GENERATED_PATTERN: "*.pb.go"' \
  "" \
  "rpc/foo.pb.go" \
  "SKIP generated"

# TC-6: Cascade fallback to CLAUDE.md (AC-P2-1, AC-P1-2 cascade)
run_case \
  "TC-6 Cascade to CLAUDE.md when PK missing" \
  "" \
  $'- LANG_EXT: .go\n- FMT_CMD: "echo cascade-{}"' \
  "src/foo.go" \
  "cascade-.*src/foo\.go"

# TC-7: FAILED-branch logging when formatter exits non-zero (PR-e22c8795 regression guard)
run_case \
  "TC-7 FAILED-branch logging" \
  $'- LANG_EXT: .go\n- FMT_CMD: "false {}"' \
  "" \
  "src/foo.go" \
  "auto-fmt: FAILED on .* \(exit 1\)"

# TC-8: missing tool_response key — parser defaults success=True (PR-34518de3 regression guard)
# Refactored to use run_case helper with omit_tool_response=true (CR-004).
run_case \
  "TC-8 missing tool_response --> formatter runs (defaults success=True)" \
  $'- LANG_EXT: .go\n- FMT_CMD: "echo notool-{}"' \
  "" \
  "src/foo.go" \
  "notool-.*src/foo\.go" \
  "true"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]