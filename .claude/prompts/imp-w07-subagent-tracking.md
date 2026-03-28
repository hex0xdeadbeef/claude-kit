# IMP-W07: SubagentStart hook for code-researcher lifecycle tracking

## Metadata

- **Complexity:** XL (user-requested; actual S)
- **Type:** new hook + script + documentation
- **Feature:** Claude Code v2.0.43 — SubagentStart hook event
- **Risk:** LOW — non-blocking logging only
- **Note:** Original plan referenced TaskCreated — corrected to SubagentStart (TaskCreated fires for TaskCreate tool only, not Agent tool)

## Scope

**IN:**

- Create `.claude/scripts/track-task-lifecycle.sh` (logging script)
- Add `SubagentStart` hook in `.claude/settings.json` (matcher: code-researcher)
- Update `.claude/commands/workflow.md` hooks section
- Update `CLAUDE.md` Enforcement section

**OUT:**

- Tracking plan-reviewer/code-reviewer (already tracked via SubagentStop)
- Auto-integration into pipeline-metrics (orchestrator reads JSONL manually at Phase 5)
- TaskCreated hook (wrong hook type for this use case)

## Context

### Problem

Workflow uses code-researcher via Agent tool, but lifecycle of these invocations is not tracked.
SubagentStop fires only for plan-reviewer/code-reviewer. pipeline-metrics has `code_researcher_metrics`
fields but no data source to populate them.

### Solution

Add SubagentStart hook with matcher `code-researcher` to log invocations to JSONL.
Non-blocking (exit 0 always). Orchestrator can read the log at completion phase.

## Parts

### Part 1: Create track-task-lifecycle.sh

**File:** `.claude/scripts/track-task-lifecycle.sh` (CREATE)

Script reads stdin JSON, appends entry to `.claude/workflow-state/task-events.jsonl`.
Fields: timestamp, event, agent_type, agent_id, session_id.
Always exits 0 (non-blocking).

### Part 2: Add SubagentStart hook to settings.json

**File:** `.claude/settings.json` (UPDATE)

Add after SubagentStop entry:
```json
"SubagentStart": [
  {
    "matcher": "code-researcher",
    "hooks": [
      {
        "type": "command",
        "command": ".claude/scripts/track-task-lifecycle.sh"
      }
    ]
  }
]
```

### Part 3: Update workflow.md hooks section

**File:** `.claude/commands/workflow.md` (UPDATE)

Add SubagentStart to workflow_specific hooks list.

### Part 4: Update CLAUDE.md

**File:** `CLAUDE.md` (UPDATE)

Add SubagentStart to Enforcement hooks list.

## Files Summary

| File | Action |
|------|--------|
| `.claude/scripts/track-task-lifecycle.sh` | CREATE |
| `.claude/settings.json` | UPDATE |
| `.claude/commands/workflow.md` | UPDATE |
| `CLAUDE.md` | UPDATE |

## Acceptance Criteria

**Functional:**

- [ ] SubagentStart hook fires when code-researcher agent is invoked
- [ ] JSONL entry logged with timestamp, agent_type, agent_id, session_id

**Technical:**

- [ ] Script always exits 0 (non-blocking)
- [ ] settings.json is valid JSON
- [ ] Script handles missing python3 gracefully (exit 0, not crash)

**Architecture:**

- [ ] Follows existing hook script patterns (stdin JSON, python3 parsing)
- [ ] JSONL output matches existing workflow-state file patterns

## Safety

- **Non-blocking:** script always exits 0, never blocks agent invocation
- **Logging only:** no state changes, no modifications to workflow flow
- **Rollback:** remove SubagentStart from settings.json, delete script
