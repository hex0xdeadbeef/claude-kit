---
name: project-conventions
description: Claude Kit repo conventions for code review — what to check, what to skip, known patterns
type: project
---

## Repo type
This is a Claude Code configuration kit — 112 Markdown, 16 Shell, 4 JSON, ~25k lines.
No Go application code in the repo itself. Language Profile targets Go >= 1.24 for the
projects this kit is deployed to.

## What changes look like
- Most PRs modify: `.claude/agents/*.md`, `.claude/commands/*.md`, `.claude/scripts/*.sh`,
  `.claude/agents/meta-agent/scripts/*.sh`
- No Go source in the kit itself — architecture import matrix check is N/A unless
  reviewing a project that uses this kit

## Shell script conventions
- All scripts: `set -euo pipefail`
- Hook scripts exit 0 always (PostToolUse hooks cannot block)
- Guards placed immediately after variable extraction, before processing
- No unit tests for shell scripts — manual testing via pipe + exit code is the pattern

## Hook guard pattern
When a PostToolUse hook should skip certain paths, the guard goes immediately after
`FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')`:
```bash
if [[ "$FILE_PATH" == *"pattern"* ]]; then
  exit 0
fi
```
This is the established pattern in yaml-lint.sh, check-references.sh, check-plan-drift.sh.

## Plan artifacts location
Plans live in `.claude/prompts/` with names like `{feature-name}.md` (YAML-first format).
Evaluate results live as `{feature-name}-evaluate.md` in the same directory.

## Spec compliance note
When plan Part 5 step numbers differ between plan and implementation (e.g., plan has 4
steps but implementation collapses to 3), this is MINOR — check functional equivalence,
not step count. The evaluate artifact may reference old step numbers.
