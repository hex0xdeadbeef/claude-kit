# Beads Integration

**Core commands:**
```
bd show <id>       — view task details
bd update <id> --status=in_progress  — claim task
bd ready           — show ready issues (no blockers)
bd close <id>      — close issue (NEVER auto-close, remind user)
bd sync            — sync to remote (MANDATORY at workflow end)
bd dep add <A> <B> — A depends on B (B blocks A)
bd create --title="..." --type=task|bug|feature --priority=0-4
bd blocked          — show blocked issues
bd stats            — open/closed/blocked counts
bd doctor           — check sync, hooks, issues
```

**Priority values:** 0=Critical, 1=High, 2=Medium (default), 3=Low, 4=Backlog.

**Bulk creation:** For many issues — spawn parallel Task subagents (more efficient than sequential bd create).

**Integration by command:**

| Command | Start | End |
|---------|-------|-----|
| /planner | bd show (if beads task), check deps | No beads action |
| /coder | Task already claimed | No auto-close (wait for review) |
| /plan-review | No beads action | No beads action |
| /code-review | No beads action | If APPROVED → remind bd close |
| /workflow | bd show + bd update in_progress | bd sync (MANDATORY) + remind bd close |

**Rule:** Beads is NON_CRITICAL. If `bd` unavailable → warn, skip beads phases, continue core workflow.
