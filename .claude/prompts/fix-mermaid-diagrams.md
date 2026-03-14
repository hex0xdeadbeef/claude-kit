# Fix Mermaid Diagrams and Hook Documentation

## Task
- Type: documentation
- Complexity: XL (user-specified; 4 areas to fix across README.md, cross-referencing 6 diagrams and multiple source files)

## Scope

### Part 1: Fix Development Pipeline diagram (STARTUP order)
**File:** `README.md` lines 206-292

**Problem:** STARTUP subgraph shows `Memory search → Beads check → Session recovery check → Task Analysis`, but per `workflow.md` the actual order is:
- Step 0: Task Analysis (FIRST)
- Step 0.1: Load workflow-protocols
- Step 1: TodoWrite
- Step 2: Memory search
- Step 3: Beads check
- Step 4: Session recovery

**Fix:** Move Task Analysis INTO the STARTUP subgraph as the first node, reorder flow:
```
Task Analysis → Memory search → Beads check → Session recovery
```
Then the routes (S/M/L/XL) flow from STARTUP directly to PLANNER.

### Part 2: Fix Hook Lifecycle diagram (missing check-plan-drift.sh)
**File:** `README.md` lines 378-422

**Problem:** `check-plan-drift.sh` PostToolUse hook (settings.json lines 130-138, matcher: `Write|Edit`) is missing from the diagram.

**Fix:** Add `check-plan-drift.sh` node after EXEC, triggered by Write/Edit, alongside other PostToolUse hooks.

### Part 3: Fix Hooks table (missing check-plan-drift.sh row)
**File:** `README.md` lines 525-538

**Problem:** Table lists 13 hooks but settings.json has 14. Missing `check-plan-drift.sh`.

**Fix:** Add row:
```
| `agents/meta-agent/scripts/check-plan-drift.sh` | PostToolUse (Write/Edit) | Detect plan drift during implementation |
```

### Part 4: Fix Project Structure scripts count
**File:** `README.md` line 509

**Problem:** Says "scripts/ # Lifecycle hook scripts (10 scripts)" — accurate for `.claude/scripts/` only but doesn't account for 5 scripts in `meta-agent/scripts/`.

**Fix:** Update comment to reflect total or clarify scope. Since the structure already shows `meta-agent/` separately, keep "10 scripts" as-is for `.claude/scripts/` — this is actually correct in context.

**Decision:** No change needed for Part 4 (the count is scoped to `.claude/scripts/` which does have 10 scripts).

### Part 5: Fix workflow.md cascade — hooks count and PostToolUse list
**File:** `.claude/commands/workflow.md`

**Problem (from plan-review PR-001 MAJOR):** Line 275 says `"8 event types, 13 scripts"` but after adding `check-plan-drift.sh` the total is 14 scripts.

**Fix:** Change `13 scripts` → `14 scripts` on line 275.

**Problem (from plan-review PR-002 MINOR):** Line 299 `also_active_during_workflow` lists only 3 PostToolUse hooks, missing `check-plan-drift.sh`.

**Fix:** Update line 299 to: `"PostToolUse → auto-fmt-go.sh, yaml-lint.sh, check-references.sh, check-plan-drift.sh"`

## Architecture Decisions
- Keep diagram style consistent (same color scheme, node shapes)
- STARTUP subgraph should accurately reflect workflow.md step order
- All hooks in settings.json must be reflected in both diagram and table

## Tests / Verification
- Visual: render mermaid diagrams to verify syntax
- Cross-reference: every hook in settings.json appears in both diagram and table
- Cross-reference: STARTUP order matches workflow.md startup steps

## Acceptance Criteria
- [ ] Development Pipeline: Task Analysis is first in STARTUP flow
- [ ] Hook Lifecycle: check-plan-drift.sh appears in PostToolUse section
- [ ] Hooks table: 14 rows matching all 14 hooks in settings.json
- [ ] No mermaid syntax errors
- [ ] workflow.md line 275: "14 scripts" (not 13)
- [ ] workflow.md line 299: PostToolUse list includes check-plan-drift.sh
