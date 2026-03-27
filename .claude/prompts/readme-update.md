# Plan: Full README.md Documentation Update

## Task
Update README.md to reflect all changes since 2026-03-20 (5 commits: a0f58c9, 4b4b765, e6c64df, f07bd60, 78bd4aa).

## Complexity: XL
- 8 distinct update areas across README.md
- Mermaid diagram modifications (2 diagrams)
- Badge updates, table changes, structural updates

## Scope

### Part 1: Badge Update
- Line 10: `hooks-14_scripts` → `hooks-19_scripts` (19 unique hook scripts across 12 event types)
- Source of truth: `.claude/settings.json` (12 event types, 19 script entries)

### Part 2: Hooks Table (line ~597-616)
Add 5 new entries to match settings.json:

| Hook | Trigger | Purpose |
|------|---------|---------|
| `validate-instructions.sh` | InstructionsLoaded | Validate critical rules loaded into context |
| `pre-commit-build.sh` | PreToolUse (Bash) | Validate go build before git commit |
| `verify-state-after-compact.sh` | PostCompact | Verify workflow state after compaction |
| `prepare-worktree.sh` | WorktreeCreate | Prepare worktree environment for code review |
| `log-stop-failure.sh` | StopFailure | Log API errors to analytics |

Reorder table to match event lifecycle order (InstructionsLoaded → UserPromptSubmit → PreToolUse → PostToolUse → PreCompact → PostCompact → SubagentStop → WorktreeCreate → Stop → SessionEnd → StopFailure → Notification).

### Part 3: Hook Lifecycle Mermaid Diagram (line ~437-485)
Add missing hooks to diagram:
1. InstructionsLoaded → validate-instructions.sh (at session start, before User Prompt)
2. PreToolUse/Bash → pre-commit-build.sh (alongside existing Bash check)
3. PostCompact → verify-state-after-compact.sh (after COMPACT node)
4. WorktreeCreate → prepare-worktree.sh (new node after code-review delegation)
5. StopFailure → log-stop-failure.sh (after STOP, parallel to SESS)

### Part 4: Development Pipeline Mermaid Diagram (line ~252-339)
Add SIMPLIFY optional sub-phase between IMPLEMENT and VERIFY:
- `IMPLEMENT --> SIMPLIFY{"SIMPLIFY (optional,<br/>L/XL, ≥5 parts)"}`
- `SIMPLIFY -->|applied| VERIFY`
- `SIMPLIFY -->|skipped/reverted| VERIFY`

### Part 5: Project Structure (line ~584)
- `scripts/` description: "10 scripts" → "15 scripts" (actual count: `ls .claude/scripts/*.sh | wc -l` = 15)

### Part 6: Workflow Phases Table (line ~89-97)
The existing phases table is still accurate. No changes needed.

### Part 7: Key Principles Section (line ~505-514)
Add new capabilities mentioned in recent commits:
- Add: **Cron Auto-Save** — periodic checkpoint auto-save for L/XL tasks via CronCreate
- Add: **Simplify Protocol** — optional code simplification before review (L/XL, ≥5 parts, 30% guard)
- Add: **Worktree Optimization** — sparse checkout via `worktree.sparsePaths` reduces worktree size

### Part 8: Model Routing / Agent Capabilities
- Mention `effort` field in agent frontmatter (new in agents: code-researcher=medium, code-reviewer=high, plan-reviewer=high)
- Note `disallowedTools` for plan-reviewer (Write, Edit, Bash blocked)

## Architecture Decision
- Keep existing structure, add to it — no reorganization
- Match settings.json as source of truth for hooks
- All diagram changes are additive

## Risks
- Mermaid diagram complexity — adding 5+ nodes may affect readability
- Badge count may change again soon — use authoritative count from settings.json

## Acceptance Criteria
1. All 19 hook scripts listed in Hooks table
2. Hook Lifecycle diagram includes all 12 event types
3. Pipeline diagram shows SIMPLIFY sub-phase
4. Badge reflects actual count (19)
5. Project structure shows actual script count (15)
6. All new capabilities from recent commits documented
