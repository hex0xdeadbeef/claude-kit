# State Layer

purpose: "File contracts, lifecycle rules, and cleanup protocol for .claude/workflow-state/"
loaded_when: "On-demand — when debugging state issues or at Phase 5 completion (cleanup)"

# ─────────────────────────────────────────────────────
# DIRECTORY CONTRACT
# ─────────────────────────────────────────────────────
directory:
  path: ".claude/workflow-state/"
  git_status: "Untracked — gitignored via `.claude/workflow-state/` entry in .gitignore"
  visibility: "NOT visible in worktree agents (untracked files excluded from sparse checkout)"
  access_pattern: "SubagentStart hook reads files → injects via additionalContext JSON"
  creation: "mkdir -p .claude/workflow-state 2>/dev/null || true (each script ensures dir exists)"
  concurrency: "Hooks run sequentially per event — no concurrent writes to same file"

# ─────────────────────────────────────────────────────
# FILE CONTRACTS
# ─────────────────────────────────────────────────────
files:
  - name: "{feature}-checkpoint.yaml"
    format: YAML
    written_by:
      - "Orchestrator — phase-end checkpoint after every phase"
      - "CronCreate — auto-save every 10 min (L/XL tasks only)"
    read_by:
      - "save-progress-before-compact.sh (PreCompact) — saves state to additionalContext"
      - "verify-state-after-compact.sh (PostCompact) — re-injects state summary"
      - "inject-review-context.sh (SubagentStart) — injects context for review agents"
      - "session-analytics.sh (SessionEnd) — reads feature/phase/complexity for analytics"
      - "audit-config-change.sh (ConfigChange) — existence check only (active workflow gate)"
    schema: "SEE checkpoint-protocol.md — 12+ YAML fields"
    lifecycle: session-specific
    cleanup: "Phase 5 completion — deleted LAST (after metrics collected and final checkpoint written)"

  - name: "review-completions.jsonl"
    format: JSONL
    written_by:
      - "save-review-checkpoint.sh (SubagentStop, matcher: plan-reviewer|code-reviewer)"
    read_by:
      - "inject-review-context.sh (SubagentStart) — prior verdicts for review agents"
      - "verify-state-after-compact.sh (PostCompact) — integrity verification"
      - "Orchestrator — output_validation fallback (when agent returns incomplete)"
    schema:
      required: "{agent, completed_at, session_id, verdict}"
      optional: "{verdict_source, worktree_path, worktree_resolution, memory_sync, memory_files_synced}"
    lifecycle: session-specific
    cleanup: "Phase 5 completion"

  - name: "agent-id-registry.jsonl"
    format: JSONL
    written_by:
      - "track-task-lifecycle.sh (SubagentStart, matcher: plan-reviewer|code-reviewer) — IMP-01"
    read_by:
      - "save-review-checkpoint.sh (SubagentStop) — recover agent_type when payload omits it"
    schema: "{agent_id, agent_type, session_id, registered_at}"
    lifecycle: session-specific
    cleanup: "Phase 5 completion"
    note: "Enables IMP-H to work for code-reviewer (isolation:worktree) where SubagentStop payload has empty agent_type"

  - name: "task-events.jsonl"
    format: JSONL
    written_by:
      - "track-task-lifecycle.sh (SubagentStart, matcher: code-researcher)"
    read_by:
      - "Orchestrator (Phase 5) — code_researcher_metrics in pipeline-metrics"
    schema: "{timestamp, event, agent_type, agent_id, session_id}"
    lifecycle: session-specific
    cleanup: "Phase 5 completion"

  - name: "pipeline-metrics.jsonl"
    format: JSONL
    written_by:
      - "Orchestrator (Phase 5 completion)"
    read_by:
      - "Orchestrator — aggregation triggers (every 5th run, anomaly detection)"
      - "User — on-demand pipeline analysis"
    schema: "SEE pipeline-metrics.md — 12+ fields"
    lifecycle: cross-session
    cleanup: "Manual — user decides when to archive/clear. Suggest at 100+ entries."

  - name: "session-analytics.jsonl"
    format: JSONL
    written_by:
      - "session-analytics.sh (SessionEnd)"
      - "log-stop-failure.sh (StopFailure) — appends error events with type='stop_failure'"
    read_by:
      - "pipeline-metrics anomaly detection (exploration_loop_signal)"
      - "User — on-demand session analysis"
    schema: "{session_id, timestamp, reason, duration_seconds, message_count, user_prompts, tool_calls, tool_breakdown, exploration_metrics, agent_metrics, errors, checkpoint}"
    lifecycle: cross-session
    cleanup: "Manual — user decides when to archive/clear. Suggest at 100+ entries."

  - name: "worktree-events-debug.jsonl"
    format: JSONL
    written_by:
      - "save-review-checkpoint.sh (SubagentStop) — payload discovery + memory sync events"
      - "track-task-lifecycle.sh (SubagentStart) — payload discovery"
    read_by:
      - "Developer — debug/contract discovery only"
    schema: "Variable — discovery entries with received_keys, payload_sample"
    lifecycle: debug
    cleanup: "Phase 5 completion"

  - name: "config-changes.jsonl"
    format: JSONL
    written_by:
      - "audit-config-change.sh (ConfigChange)"
    read_by:
      - "Developer — audit trail"
    schema: "{timestamp, source, session_id, blocked, reason}"
    lifecycle: cross-session
    cleanup: "Manual — audit log, user decides when to archive/clear"

  - name: "hook-log.txt"
    format: Plain text
    written_by:
      - "Various hooks — debug logging"
    read_by:
      - "Developer — debug only"
    schema: "Unstructured text lines"
    lifecycle: debug
    cleanup: "Phase 5 completion"

# ─────────────────────────────────────────────────────
# LIFECYCLE CATEGORIES
# ─────────────────────────────────────────────────────
lifecycle_categories:
  session-specific:
    description: "Created during workflow, consumed by pipeline, cleaned at completion"
    files: ["{feature}-checkpoint.yaml", "review-completions.jsonl", "agent-id-registry.jsonl", "task-events.jsonl"]
    retention: "Until Phase 5 completion (data captured in pipeline-metrics.jsonl)"

  cross-session:
    description: "Persistent data that accumulates across workflows"
    files: ["pipeline-metrics.jsonl", "session-analytics.jsonl", "config-changes.jsonl"]
    retention: "Manual cleanup — suggest archiving when file exceeds 100 entries"

  debug:
    description: "Ephemeral debug/discovery data, no pipeline dependency"
    files: ["worktree-events-debug.jsonl", "hook-log.txt"]
    retention: "Cleaned at Phase 5 completion — no data loss"

# ─────────────────────────────────────────────────────
# CLEANUP PROTOCOL
# ─────────────────────────────────────────────────────
cleanup_protocol:
  trigger: "Phase 5 completion — AFTER git commit AND metrics collection"
  owner: "Orchestrator (inline in Phase 5, not a separate script)"

  session_files:
    action: "Delete after Phase 5 metrics are collected and written to pipeline-metrics.jsonl"
    files:
      - "review-completions.jsonl"
      - "agent-id-registry.jsonl"
      - "task-events.jsonl"
      - "worktree-events-debug.jsonl"
      - "hook-log.txt"
      - "{feature}-checkpoint.yaml (LAST — other steps may read it)"
    method: "rm -f (safe — files are session-specific, data already captured)"
    order: "Checkpoint deleted LAST — Phase 5 steps 1-4 may still reference it"

  persistent_files:
    action: "Preserve — cross-session data"
    files:
      - "pipeline-metrics.jsonl"
      - "session-analytics.jsonl"
      - "config-changes.jsonl"
    rotation_hint: "When file exceeds 100 lines, suggest user archive older entries"

  failure_handling: "Cleanup failure is NON_CRITICAL — warn but do not block commit"
