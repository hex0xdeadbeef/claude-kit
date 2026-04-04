# IMP-C: Shared State Layer Formalization

## Summary
Formalize `.claude/workflow-state/` directory with documented file contracts, lifecycle rules, and cleanup protocol.

## Complexity
M (documentation + one cleanup script + minor updates to orchestration-core.md)

## Scope

### Part 1: Create State Layer Contract Document
**File:** `.claude/skills/workflow-protocols/state-layer.md`

New protocol document in workflow-protocols skill. Documents all 8 files currently in `.claude/workflow-state/`:

```yaml
files:
  - name: "{feature}-checkpoint.yaml"
    format: YAML
    written_by: ["Orchestrator (phase-end)", "CronCreate (auto-save, L/XL)"]
    read_by: ["save-progress-before-compact.sh", "verify-state-after-compact.sh", "inject-review-context.sh", "session-analytics.sh", "audit-config-change.sh (existence check only)"]
    schema: "SEE checkpoint-protocol.md"
    lifecycle: session-specific
    cleanup: "Phase 5 completion (after metrics collected)"

  - name: "review-completions.jsonl"
    format: JSONL
    written_by: ["save-review-checkpoint.sh (SubagentStop)"]
    read_by: ["inject-review-context.sh (SubagentStart)", "verify-state-after-compact.sh", "Orchestrator (output_validation fallback)"]
    schema: "{agent, completed_at, session_id, verdict, verdict_source?, worktree_path?, worktree_resolution?, memory_sync?, memory_files_synced?}"
    lifecycle: session-specific
    cleanup: "Phase 5 completion (after metrics collected)"

  - name: "task-events.jsonl"
    format: JSONL
    written_by: ["track-task-lifecycle.sh (SubagentStart, code-researcher)"]
    read_by: ["Orchestrator (Phase 5 — pipeline-metrics.code_researcher_metrics)"]
    schema: "{timestamp, event, agent_type, agent_id, session_id}"
    lifecycle: session-specific
    cleanup: "Phase 5 completion (after metrics collected)"

  - name: "pipeline-metrics.jsonl"
    format: JSONL
    written_by: ["Orchestrator (Phase 5)"]
    read_by: ["Orchestrator (aggregation triggers — every 5th run, anomaly detection)"]
    schema: "SEE pipeline-metrics.md"
    lifecycle: cross-session (persistent)
    cleanup: "Manual — user decides when to archive/clear"

  - name: "session-analytics.jsonl"
    format: JSONL
    written_by: ["session-analytics.sh (SessionEnd)"]
    read_by: ["pipeline-metrics anomaly detection (exploration loop signal)"]
    schema: "{session_id, timestamp, reason, duration_seconds, message_count, user_prompts, tool_calls, tool_breakdown, exploration_metrics, agent_metrics, errors, checkpoint}"
    lifecycle: cross-session (persistent)
    cleanup: "Manual — user decides when to archive/clear"

  - name: "worktree-events-debug.jsonl"
    format: JSONL
    written_by: ["save-review-checkpoint.sh", "track-task-lifecycle.sh"]
    read_by: ["Developer (debug only)"]
    schema: "Variable — discovery/debug entries"
    lifecycle: debug (ephemeral)
    cleanup: "Phase 5 completion"

  - name: "config-changes.jsonl"
    format: JSONL
    written_by: ["audit-config-change.sh (ConfigChange)"]
    read_by: ["Developer (audit trail)"]
    schema: "{timestamp, source, session_id, blocked, reason}"
    lifecycle: cross-session (audit log)
    cleanup: "Manual — user decides when to archive/clear"

  - name: "hook-log.txt"
    format: Plain text
    written_by: ["Various hooks (debug logging)"]
    read_by: ["Developer (debug only)"]
    schema: "Unstructured text lines"
    lifecycle: debug (ephemeral)
    cleanup: "Phase 5 completion"
```

Also documents:
- Directory creation convention (`mkdir -p "$STATE_DIR" 2>/dev/null || true`)
- Git status: untracked (gitignored via `.claude/` pattern) — NOT visible in worktree agents
- Access pattern for worktree agents: SubagentStart hook reads → injects via `additionalContext`
- Concurrency: hooks run sequentially per event, no concurrent writes to same file

### Part 2: Add Cleanup Protocol to State Layer Document
Within the same `state-layer.md`, add cleanup section:

```yaml
cleanup_protocol:
  trigger: "Phase 5 completion (after git commit + metrics collection)"
  owner: "Orchestrator"
  
  session_files:
    action: "Delete after Phase 5 metrics collected"
    files:
      - "{feature}-checkpoint.yaml"
      - "review-completions.jsonl"
      - "task-events.jsonl"
      - "worktree-events-debug.jsonl"
      - "hook-log.txt"
    method: "rm -f (safe — files are session-specific, data already captured in pipeline-metrics.jsonl)"
  
  persistent_files:
    action: "Preserve (cross-session data)"
    files:
      - "pipeline-metrics.jsonl"
      - "session-analytics.jsonl"
      - "config-changes.jsonl"
    rotation: "Manual — suggest archive when file exceeds 100 lines"
```

### Part 3: Implement Cleanup in Orchestration Core
**File:** `.claude/skills/workflow-protocols/orchestration-core.md`

Add cleanup step to Phase 5 — Completion section (after step 4 "Write final checkpoint"):

```
5. Clean up session-specific state files (SEE state-layer.md cleanup_protocol):
   - Delete: {feature}-checkpoint.yaml, review-completions.jsonl, task-events.jsonl, worktree-events-debug.jsonl, hook-log.txt
   - Preserve: pipeline-metrics.jsonl, session-analytics.jsonl, config-changes.jsonl
   - Note: Checkpoint is deleted LAST (after all other Phase 5 steps complete)
```

### Part 4: Register State Layer in Workflow Protocols SKILL.md
**File:** `.claude/skills/workflow-protocols/SKILL.md`

Add state-layer.md to:
- Protocol Overview table
- Event Triggers section
- Protocol References section

## Decision: New Structured Files NOT Needed

The user's spec proposed `{feature}-handoff-latest.yaml` and `{feature}-iteration-context.yaml`. These are NOT needed because:
1. IMP-A (already implemented) handles context injection via SubagentStart hook reading checkpoint directly
2. Handoff payload is already stored in checkpoint yaml (`handoff_payload` field)
3. Iteration context is already stored in checkpoint yaml (`issues_history` field)
4. Adding separate files would create redundant state that must be kept in sync

## Architecture Decisions
- **No new scripts** — cleanup is orchestrator-owned (inline in Phase 5), not a hook
- **No new files in workflow-state/** — formalize existing, don't add redundancy
- **State-layer.md as single source of truth** — all file contracts in one place, referenced by checkpoint-protocol.md and pipeline-metrics.md

## Risk Assessment
- LOW risk — documenting existing patterns, cleanup is additive
- Cleanup order matters: checkpoint deleted LAST (other Phase 5 steps may read it)
- No behavioral change for existing hooks/scripts

## Tests
- Verify state-layer.md is syntactically valid YAML-first format
- Verify orchestration-core.md Phase 5 section includes cleanup step
- Verify SKILL.md references state-layer.md correctly

## Files Modified
1. NEW: `.claude/skills/workflow-protocols/state-layer.md` (Parts 1-2)
2. EDIT: `.claude/skills/workflow-protocols/orchestration-core.md` (Part 3)
3. EDIT: `.claude/skills/workflow-protocols/SKILL.md` (Part 4)
