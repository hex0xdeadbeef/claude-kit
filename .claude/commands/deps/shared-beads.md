# Shared: Beads Integration

Beads issue tracking workflow patterns for Claude Code commands.

---

## Common Workflow Phases

### PHASE 0: Get Task (optional)

**When:** Task comes from beads issue tracking system

**Actions:**
```bash
bd show <id>                         # View task details
bd update <id> --status=in_progress  # Claim task
```

**Skip when:**
- Task not from beads (ad-hoc request)
- Task already in_progress
- Beads unavailable

---

### START: Check Available Work

**When:** User needs to find work to do

**Actions:**
```bash
bd ready                    # Show ready issues (no blockers)
bd list --status=open       # All open issues
bd list --status=in_progress  # Active work
```

**Integration point:** Before starting `/workflow` or `/planner`

---

### COMPLETION: Close Task

**When:** Feature/fix completed successfully

**Actions:**
```bash
bd close <id>               # Close single issue
bd close <id1> <id2> ...    # Close multiple (more efficient)
bd close <id> --reason="explanation"  # Close with reason
```

**When NOT to auto-close:**
- User didn't explicitly request closure
- Task requires user verification
- Task is parent epic (close children first)

**Reminder format:**
```
Feature ready! To close beads issue: `bd close <id>`
```

---

### SYNC: Synchronize with Remote

**When:** After completing local work

**Actions:**
```bash
bd sync                    # Sync to remote
bd sync --status           # Check sync status
bd sync --from-main        # Pull from main branch
```

**When to sync:**
- After closing issues
- Before starting new session
- After long editing session

**Auto-sync:** Daemon handles this automatically (auto-commit + auto-push + auto-pull enabled)

---

## Dependency Management

### Add Dependencies

```bash
bd dep add <issue> <depends-on>
# Example: beads-yyy depends on beads-xxx
# (beads-xxx blocks beads-yyy)
```

**When to use:**
- Feature depends on another feature
- Bug fix requires architectural change first
- Implementation needs design approval

### Check Blocked Issues

```bash
bd blocked                 # Show all blocked issues
bd show <id>               # See what blocks this issue
```

**Integration:** `/planner` should check if task is blocked

---

## Creating Issues

### Single Issue

```bash
bd create --title="..." --type=task|bug|feature --priority=2
```

**Priority values:**
- `0` or `P0`: Critical (use numbers 0-4, not "high"/"medium"/"low")
- `1` or `P1`: High
- `2` or `P2`: Medium (default)
- `3` or `P3`: Low
- `4` or `P4`: Backlog

### Multiple Issues (Parallel)

**For many issues:** Use parallel subagents for efficiency

```
Task: Create 10 beads issues for optimization tasks

Action: Spawn Task agents in parallel, each creating 2-3 issues
(More efficient than sequential creates)
```

---

## Project Health

### Statistics

```bash
bd stats                   # Open/closed/blocked counts
```

### Health Check

```bash
bd doctor                  # Check sync, hooks, issues
```

---

## Common Patterns

### Pattern 1: Start Work from Beads

```yaml
1. bd ready                             # Find available work
2. bd show <id>                         # Review details
3. bd update <id> --status=in_progress  # Claim it
4. /planner or /workflow                # Execute
5. bd close <id>                        # Complete
6. (Daemon auto-syncs)                  # Automatic
```

### Pattern 2: Create Dependent Work

```yaml
# Create issues in parallel (use subagents for many items)
1. bd create --title="Feature X" --type=feature
   # Returns: beads-xxx

2. bd create --title="Tests for X" --type=task
   # Returns: beads-yyy

3. bd dep add beads-yyy beads-xxx
   # Tests depend on Feature (Feature blocks Tests)
```

### Pattern 3: Closing Multiple Issues

```yaml
# After completing multi-part work
bd close <id1> <id2> <id3>  # More efficient than separate calls
git push                    # Push code (beads auto-synced by daemon)
```

---

## Availability Handling

### Beads Unavailable

```yaml
Detection:
  - `bd` command not found
  - `.beads/` directory missing
  - `bd` command fails

Recovery:
  - Warn user: "Beads unavailable, skipping task tracking"
  - Skip all beads phases (bd show, bd update, bd close)
  - Continue with core workflow

Severity: NON_CRITICAL (beads is optional enhancement)
```

### Beads Sync Failed

```yaml
Detection:
  - `bd sync` returns error
  - Network unavailable

Recovery:
  - Warn user: "Beads sync failed, continuing with local state"
  - Reminder: "Run 'bd sync --from-main' manually later"
  - Continue workflow (don't block)

Severity: WARNING (sync can be deferred)
```

---

## Command Integration Points

### /planner

**Start:**
```yaml
- bd show <id> (if task from beads)
- Check dependencies: bd show <id> shows blockers
```

**End:**
```yaml
- (No beads action - planning doesn't close tasks)
```

---

### /coder

**Start:**
```yaml
- (Assumes task already claimed by /planner or user)
```

**End:**
```yaml
- (No auto-close - wait for /code-review approval)
```

---

### /workflow

**Start:**
```yaml
- bd show <id> (if task from beads)
- bd update <id> --status=in_progress (if not already)
```

**End (ЗАВЕРШЕНИЕ phase):**
```yaml
- bd sync (MANDATORY - sync local changes)
- Reminder: "Feature ready! To close: `bd close <id>`"
- (User closes manually after verification)
```

---

### /code-review

**Start:**
```yaml
- (No beads action)
```

**End:**
```yaml
- If APPROVED: Reminder to close issue
- If REJECTED: No close reminder (work not done)
```

---

## Usage in Commands

**In command workflow sections:**
```yaml
## WORKFLOW

### PHASE 0: GET TASK (optional)

SEE: `deps/shared-beads.md#phase-0-get-task`

{Command-specific beads integration}

### ЗАВЕРШЕНИЕ

SEE: `deps/shared-beads.md#completion-close-task`

Command-specific completion actions:
- ...
- bd sync (if beads available)
- Reminder: bd close <id>
```

---

## Anti-Patterns

❌ **DON'T auto-close without user approval**
```yaml
# BAD: Auto-close immediately after code complete
bd close <id>  # User hasn't verified!
```

✅ **DO remind user to close**
```yaml
# GOOD: Remind, let user decide
echo "Feature ready! To close: 'bd close <id>'"
```

---

❌ **DON'T block workflow on beads unavailability**
```yaml
# BAD: Exit if beads unavailable
if ! command -v bd; then
  echo "ERROR: beads required"
  exit 1
fi
```

✅ **DO degrade gracefully**
```yaml
# GOOD: Warn and continue
if ! command -v bd; then
  echo "WARN: Beads unavailable, skipping tracking"
  # Continue with core workflow
fi
```

---

❌ **DON'T create issues sequentially when creating many**
```yaml
# BAD: Sequential creates (slow)
bd create --title="Task 1"
bd create --title="Task 2"
# ... (10 more creates)
```

✅ **DO use parallel subagents for bulk creation**
```yaml
# GOOD: Parallel creates via Task agents
Task: Create 12 beads issues
Action: Spawn 4 agents, each creates 3 issues in parallel
```

---

## SEE ALSO

- `shared-autonomy.md` — Autonomy modes (beads unavailable handling)
- `shared-error-handling.md` — Beads error scenarios
- Session START hook — Auto-runs `bd prime` for context recovery
- Session CLOSE protocol — Checklist including `bd sync`
