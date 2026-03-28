# IMP-W01: Conditional `if` fields for hooks — reduce spawning overhead

## Metadata
- **Complexity:** XL (user-requested)
- **Type:** config_change + documentation
- **Feature:** Claude Code v2.1.85 — conditional `if` field for hooks
- **Risk:** LOW — all conditions are subsets of existing script-internal filtering
- **Note:** XL per user request; Sequential Thinking used for design — actual complexity is M

## Scope

**IN:**

- Add `if` field to 6 hook handlers in `.claude/settings.json` (PreToolUse + PostToolUse)
- Update documentation in `CLAUDE.md` and `.claude/commands/workflow.md`

**OUT:**

- Changing hook scripts themselves — scripts are unchanged, filtering is runtime-side
- Adding `if` to non-tool events (Stop, SessionEnd, etc.) — not supported by the feature
- Updating `settings.local.json.example` — user-local overrides, not part of this feature
- Narrowing security hooks (protect-files.sh, block-dangerous-commands.sh) — must remain unconditional

## Context

### Problem
All hooks in `settings.json` fire on every matching tool call regardless of file path.
For example, `auto-fmt-go.sh` spawns a process on every Write/Edit — even for `.md` files
where it immediately exits after checking the extension. This creates unnecessary process
spawning overhead (~30-50% of hook invocations are no-ops).

### Solution
Add `if` field (v2.1.85) to hook handlers using permission rule syntax.
The `if` field prevents Claude Code from spawning the hook process when the condition
doesn't match — filtering happens at the runtime level, not inside the script.

### Key Constraints
- `if` field is at **handler level** (inside `hooks` array), not at hook entry level
- Uses **permission rule syntax** (same as `allow`/`deny`: `Write(.claude/**)`, `Bash(git *)`)
- **No pipe `|` support** in `if` field — use separate handler entries for Write vs Edit
- **Only works on tool events** (PreToolUse, PostToolUse) — NOT on Stop, SessionEnd, etc.
- `matcher` still required — `if` is additional filtering on top of matcher

## Parts

### Part 1: PreToolUse hooks (settings.json)

**File:** `.claude/settings.json`

**Change 1.1 — check-artifact-size.sh:**
```json
// BEFORE:
{ "type": "command", "command": ".claude/agents/meta-agent/scripts/check-artifact-size.sh" }

// AFTER:
{ "type": "command", "if": "Write(.claude/**)", "command": ".claude/agents/meta-agent/scripts/check-artifact-size.sh" }
```
**Rationale:** Only `.claude/` artifacts have size limits. Skips spawn for all non-.claude/ writes.

**Change 1.2 — pre-commit-build.sh:**
```json
// BEFORE:
{ "type": "command", "command": ".claude/scripts/pre-commit-build.sh" }

// AFTER:
{ "type": "command", "if": "Bash(git commit*)", "command": ".claude/scripts/pre-commit-build.sh" }
```
**Rationale:** Only `git commit` commands need build verification. Skips spawn for all other Bash calls.

**NO CHANGE:**
- `protect-files.sh` — must check ALL writes/edits (security gate, cannot narrow)
- `block-dangerous-commands.sh` — must check ALL bash commands (security gate, cannot narrow)

### Part 2: PostToolUse hooks (settings.json)

**File:** `.claude/settings.json`

**Change 2.1 — auto-fmt-go.sh:**
```json
// BEFORE (single handler):
{
  "matcher": "Write|Edit",
  "hooks": [{ "type": "command", "command": ".claude/scripts/auto-fmt-go.sh" }]
}

// AFTER (two handlers — no pipe in `if`):
{
  "matcher": "Write|Edit",
  "hooks": [
    { "type": "command", "if": "Write(**/*.go)", "command": ".claude/scripts/auto-fmt-go.sh" },
    { "type": "command", "if": "Edit(**/*.go)", "command": ".claude/scripts/auto-fmt-go.sh" }
  ]
}
```
**Rationale:** Only `.go` files need `gofmt`. Script already checks extension internally — `if` prevents spawn entirely. Two handlers because `if` doesn't support pipe.

**Change 2.2 — yaml-lint.sh:**
```json
// BEFORE:
{ "type": "command", "command": ".claude/agents/meta-agent/scripts/yaml-lint.sh" }

// AFTER:
{ "type": "command", "if": "Edit(.claude/**)", "command": ".claude/agents/meta-agent/scripts/yaml-lint.sh" }
```
**Rationale:** Only `.claude/` artifacts have YAML frontmatter to lint. Script checks `.md` extension internally.

**Change 2.3 — check-references.sh:**
```json
// BEFORE:
{ "type": "command", "command": ".claude/agents/meta-agent/scripts/check-references.sh" }

// AFTER:
{ "type": "command", "if": "Write(.claude/**)", "command": ".claude/agents/meta-agent/scripts/check-references.sh" }
```
**Rationale:** Only `.claude/` artifacts contain cross-references to validate.

**Change 2.4 — check-plan-drift.sh:**
```json
// BEFORE (single handler):
{
  "matcher": "Write|Edit",
  "hooks": [{ "type": "command", "command": ".claude/agents/meta-agent/scripts/check-plan-drift.sh" }]
}

// AFTER (two handlers — no pipe in `if`):
{
  "matcher": "Write|Edit",
  "hooks": [
    { "type": "command", "if": "Write(.claude/**)", "command": ".claude/agents/meta-agent/scripts/check-plan-drift.sh" },
    { "type": "command", "if": "Edit(.claude/**)", "command": ".claude/agents/meta-agent/scripts/check-plan-drift.sh" }
  ]
}
```
**Rationale:** Plan drift tracking only applies to `.claude/` artifact changes.

### Part 3: Documentation updates

**File:** `.claude/commands/workflow.md`

- In the `hooks` section, add note about conditional `if` filtering (v2.1.85)
- Document which hooks have `if` conditions and why

**File:** `CLAUDE.md`

- Update Enforcement section: mention `if` conditions reduce hook overhead

### Part 4: Verification

Manual verification checklist:
- [ ] Write a `.go` file → `auto-fmt-go.sh` fires
- [ ] Write a `.md` file → `auto-fmt-go.sh` does NOT fire
- [ ] Write a `.claude/commands/test.md` → `check-artifact-size.sh` fires
- [ ] Write a `README.md` (root) → `check-artifact-size.sh` does NOT fire
- [ ] Run `git commit` → `pre-commit-build.sh` fires
- [ ] Run `ls` → `pre-commit-build.sh` does NOT fire
- [ ] Edit `.claude/agents/code-reviewer.md` → `yaml-lint.sh` fires
- [ ] Edit `internal/handler/foo.go` → `yaml-lint.sh` does NOT fire

## Impact Summary

| Hook | Before | After | Savings |
|------|--------|-------|---------|
| check-artifact-size.sh | Every Write | Write(.claude/**) only | ~80% fewer spawns |
| pre-commit-build.sh | Every Bash | Bash(git commit*) only | ~95% fewer spawns |
| auto-fmt-go.sh | Every Write/Edit | **/*.go only | ~70% fewer spawns |
| yaml-lint.sh | Every Edit | Edit(.claude/**) only | ~80% fewer spawns |
| check-references.sh | Every Write | Write(.claude/**) only | ~80% fewer spawns |
| check-plan-drift.sh | Every Write/Edit | .claude/** only | ~80% fewer spawns |

**Unchanged (security gates):** protect-files.sh, block-dangerous-commands.sh

## Files Summary

| File | Action |
|------|--------|
| `.claude/settings.json` | UPDATE |
| `.claude/commands/workflow.md` | UPDATE |
| `CLAUDE.md` | UPDATE |

## Acceptance Criteria

**Functional:**

- [ ] Hooks with `if` conditions fire only for matching files/commands
- [ ] Hooks without `if` (security gates) continue to fire on all matching tool calls
- [ ] Part 4 verification checklist passes (positive and negative cases)

**Technical:**

- [ ] `settings.json` is valid JSON after all changes
- [ ] No existing hook behavior regressed for target file types

**Architecture:**

- [ ] `protect-files.sh` remains unconditional (all Write/Edit)
- [ ] `block-dangerous-commands.sh` remains unconditional (all Bash)
- [ ] Two-handler split pattern used correctly for Write|Edit matchers with `if`

## Safety

- **Backward compatible:** removing `if` returns to current behavior
- **Security preserved:** both security hooks (protect-files, block-dangerous) remain unconditional
- **No logic changes:** scripts unchanged, only spawn frequency reduced
- **Rollback:** revert settings.json to remove all `if` fields
