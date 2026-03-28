# IMP-W09: Agent memory freshness validation

## Metadata

- **Complexity:** XL (user-requested; actual S)
- **Type:** protocol/documentation update
- **Feature:** Claude Code v2.1.75 — last-modified timestamps to memory files
- **Risk:** LOW — warnings only, no auto-deletion
- **Note:** XL per user request; actual complexity is S (4 markdown file updates)

## Scope

**IN:**

- Add freshness validation rules to agent-memory-protocol.md
- Add freshness check instruction to Memory section of plan-reviewer.md, code-reviewer.md, code-researcher.md

**OUT:**

- Implementing automated scripts/hooks for freshness checks (agents check manually)
- Auto-deleting stale memory (warnings only — agent decides)
- Changing memory storage format or location

## Context

### Problem

Agent memory (code-reviewer, plan-reviewer, code-researcher) can contain stale data from previous
projects or outdated reviews. The protocol says "cleanup: Remove outdated entries when updating"
but defines no mechanism for determining freshness — no thresholds, no behavior rules.

### Solution

Add freshness validation rules to agent-memory-protocol.md with concrete thresholds:
- Files modified < 30 days ago: FRESH — use normally
- Files modified 30-90 days ago: STALE — warn, verify relevance before relying on
- Files modified > 90 days ago: EXPIRED — suggest deletion, do not rely on

Agents check freshness on startup via `ls -la` on their memory directory. Warnings only.

## Parts

### Part 1: Update agent-memory-protocol.md

**File:** `.claude/skills/workflow-protocols/agent-memory-protocol.md`

Add `freshness` section after `limits`:

```yaml
freshness:
  source: "File system mtime (v2.1.75 — last-modified timestamps in memory files)"
  check_when: "On startup, after reading MEMORY.md"
  method: "Run: ls -la .claude/agent-memory/{agent_name}/ to see file dates"
  thresholds:
    fresh: "< 30 days — use normally"
    stale: "30-90 days — WARN: verify relevance before relying on patterns"
    expired: "> 90 days — WARN: suggest deletion, do not rely on for decisions"
  behavior:
    on_stale: "Log warning, still read content but cross-check against current code"
    on_expired: "Log warning, suggest cleanup in completion phase, do not base decisions on"
    never: "Never auto-delete — agent proposes, user decides"
  severity: "NON_CRITICAL — proceed even if freshness check fails"
```

### Part 2: Update plan-reviewer.md Memory section

**File:** `.claude/agents/plan-reviewer.md`

Add freshness check to startup instruction:

```
- On startup: read your agent memory for patterns from past reviews (recurring issues, common plan mistakes)
- Freshness: check file dates via `ls -la .claude/agent-memory/plan-reviewer/`. Files > 30d = stale (verify), > 90d = expired (suggest cleanup)
```

### Part 3: Update code-reviewer.md Memory section

**File:** `.claude/agents/code-reviewer.md`

Same pattern as Part 2, adapted for code-reviewer.

### Part 4: Update code-researcher.md Memory section

**File:** `.claude/agents/code-researcher.md`

Same pattern as Part 2, adapted for code-researcher.

## Files Summary

| File | Action |
|------|--------|
| `.claude/skills/workflow-protocols/agent-memory-protocol.md` | UPDATE |
| `.claude/agents/plan-reviewer.md` | UPDATE |
| `.claude/agents/code-reviewer.md` | UPDATE |
| `.claude/agents/code-researcher.md` | UPDATE |

## Acceptance Criteria

**Functional:**

- [ ] agent-memory-protocol.md has freshness section with 3 thresholds and behavior rules
- [ ] All 3 agents mention freshness check in their Memory section

**Technical:**

- [ ] No existing memory behavior broken — freshness is additive
- [ ] Severity is NON_CRITICAL (agent proceeds even if check fails)

**Architecture:**

- [ ] Protocol is the source of truth; agent files reference it
- [ ] Warnings only, never auto-delete

## Safety

- **Backward compatible:** freshness rules are additive, no existing behavior removed
- **No auto-deletion:** agents warn about stale memory but never delete without user consent
- **NON_CRITICAL severity:** if freshness check fails, agent proceeds normally
- **Rollback:** remove freshness section from protocol and agent files
