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
  checkpoint_selection:
    rule: "Latest checkpoint is mtime-most-recent, NOT alphabetically-last"
    canonical_helper: ".claude/scripts/lib/state_render.py::latest_checkpoint(state_dir)"
    bash_pattern: "ls -t .claude/workflow-state/*-checkpoint.yaml 2>/dev/null | head -n1"
    rationale: |
      P2 fix (audit ref: .claude/prompts/workflow-hook-loop-audit.md § P2). Readers historically
      mixed `sorted(glob.glob(...))[-1]` (alphabetical) with `notify-workflow-complete.sh:24`'s
      `ls -t | head -n1` (mtime); with divergent feature names the two orders disagree, so different
      hooks pick different active workflows. mtime is the correct semantics; the helper localises it
      so future drift requires changing one line in one file.
    documented_exceptions:
      - script: ".claude/scripts/check-uncommitted.sh:28"
        form: "ls -t … | head -n1 (inline bash, single call site, no Python entry-point)"
      - script: ".claude/scripts/log-permission-denied.sh:62"
        form: "candidates.sort(key=lambda p: (os.path.getmtime(p), p), reverse=True); candidates[0] (inline Python; heredoc does NOT import state_render)"
    tie_break: "Equal mtimes → alphabetically-larger name wins (tuple (mtime, name) with reverse=True). Deterministic and stable."

# ─────────────────────────────────────────────────────
# FILE CONTRACTS
# ─────────────────────────────────────────────────────
files:
  - name: "{feature}-checkpoint.yaml"
    format: YAML
    written_by:
      - "Orchestrator — phase-end checkpoint after every phase"
      - "CronCreate — auto-save every 10 min (L/XL tasks only)"
      - "Orchestrator — delta_review_mode at plan-review pre_delegation (STEP MODE)"
      - "Orchestrator — iteration_commit_sha[N] at code-review pre_delegation (STEP SHA)"
    read_by:
      - "save-progress-before-compact.sh (PreCompact) — saves state to additionalContext"
      - "verify-state-after-compact.sh (PostCompact) — re-injects state summary"
      - "inject-review-context.sh (SubagentStart) — injects context for review agents; reads delta_review_mode (both plan-reviewer and code-reviewer branches)"
      - "inject-review-context.sh (SubagentStart) — reads iteration_commit_sha (code-reviewer branch only) for git diff delta range"
      - "session-analytics.sh (SessionEnd) — reads feature/phase/complexity for analytics"
      - "audit-config-change.sh (ConfigChange) — existence check only (active workflow gate)"
    schema: "SEE checkpoint-protocol.md — 14+ YAML fields (incl. iteration_commit_sha, delta_review_mode added by delta-review-mode feature)"
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
      required: "{agent, effective_agent_type, completed_at, session_id, verdict}"
      optional: "{verdict_source, verdict_transcript_source, verdict_mismatch_warning, schema_failure_reason, worktree_path, worktree_resolution, memory_sync, memory_files_synced}"
      note: "agent=raw payload agent_type (may be 'unknown'); effective_agent_type=post-registry-recovery value (always present)"
    imp02_fields:
      purpose: "IMP-02 structured verdict extraction — disambiguate HOW the verdict was parsed vs WHERE the transcript came from"
      verdict_source:
        type: "string"
        semantics: "HOW the verdict was extracted from the transcript"
        values:
          - "structured_json — VERDICT_JSON fenced block parsed and validated against .claude/schemas/handoff.schema.json (plan_review_verdict | code_review_verdict). Primary path (IMP-02)."
          - "regex_fallback — VERDICT_JSON block missing, malformed, or failed schema validation; hook fell back to regex on the human-readable VERDICT: line. Defense-in-depth, non-fatal."
          - "none — no verdict recovered by either path; orchestrator must invoke on_incomplete_output chain (step_0..step_5 in incomplete-output-recovery.md)."
      verdict_transcript_source:
        type: "string"
        semantics: "WHERE the transcript data came from (reverse-search path)"
        values:
          - "last_assistant_message — raw payload last_assistant_message field (fast path)"
          - "transcript_reverse_search — scanned transcript JSONL in reverse for role:assistant (fallback when payload lacks last_assistant_message)"
          - "not_searched — payload had a direct verdict field, no transcript scan needed"
      verdict_mismatch_warning:
        type: "string (optional)"
        semantics: "Present when structured JSON verdict differs from human-readable VERDICT: line. Non-fatal — structured value wins per RULE_5. Logged for drift detection."
        example: "structured=APPROVED vs regex=NEEDS_CHANGES"
      schema_failure_reason:
        type: "string (optional)"
        semantics: "Populated when verdict_source == regex_fallback due to schema validation failure (as opposed to missing/malformed fence). One of: structured_json_schema_invalid | verdict_json_decode_error | verdict_json_missing_fence."
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

  - name: ".iteration-in-flight"
    format: "JSON (single object: agent, started_at, feature, source)"
    written_by:
      - "inject-review-context.sh (SubagentStart, matcher: plan-reviewer|code-reviewer) — P5 auto-write at hook entry; idempotent over orchestrator's manual write"
      - "Orchestrator — delegation-templates.md STEP -1 (legacy-but-idempotent since P5 fix 2026-05-22; harmless if both fire — same content shape, last-writer-wins on the `agent` field)"
    read_by:
      - "save-progress-before-compact.sh (PreCompact auto) — reads `agent` field for the BLOCKED reason text; ignores all other fields; checks mtime for 30-min staleness window"
    deleted_by:
      - "save-review-checkpoint.sh (SubagentStop, matcher: plan-reviewer|code-reviewer|verdict-recovery) — P0-04 deletion on successful review completion"
      - "save-progress-before-compact.sh (PreCompact auto) — staleness auto-delete when mtime > 30 min"
    schema: "JSON object — required: `agent` (string, e.g. 'plan-reviewer'); optional: `started_at` (ISO-8601 UTC), `feature` (checkpoint feature name or 'unknown'), `source` (forensic — 'inject-review-context.sh' if hook-written, omitted by orchestrator), `iteration` (legacy orchestrator field, ignored by consumer)"
    lifecycle: session-specific
    cleanup: "SubagentStop deletion (primary) → PreCompact 30-min staleness auto-delete (secondary, crash recovery)"
    purpose: |
      Sentinel that the PreCompact auto-trigger reads to BLOCK auto-compaction mid-review (would
      otherwise fragment the reviewer's verdict narrative). Audit refs:
      .claude/prompts/workflow-hook-loop-audit.md § P1 (PreCompact consumer cooldown) + § P5
      (write-side automation: P5 moved the write into inject-review-context.sh for lifecycle
      symmetry with SubagentStop deletion, replacing a manual orchestrator step that could be
      silently skipped).

  - name: ".stop-block-attempts-{session_id}"
    format: "plaintext (single line: COUNT:UNCOMMITTED_COUNT)"
    written_by:
      - "check-uncommitted.sh (Stop) — increments per block; resets when UNCOMMITTED count changes"
    read_by:
      - "check-uncommitted.sh (Stop) — circuit-breaker check"
    schema: "single line, format `<int>:<int>` (block count : uncommitted file count at last block)"
    lifecycle: session-specific
    cleanup: "SessionEnd via session-analytics.sh glob `find … -name '.stop-block-attempts-*' -delete`"
    purpose: |
      P3 circuit breaker (audit § P3 — .claude/prompts/workflow-hook-loop-audit.md):
      prevents infinite Stop-block loop when user cannot satisfy commit precondition
      (e.g. pre-commit-build.sh denies git commit because build fails). After
      STOP_BLOCK_MAX=5 consecutive blocks with unchanged UNCOMMITTED count, the
      Stop hook emits a WARN and allows stop instead of re-emitting decision:block.
    fallback: "`.stop-block-attempts-default` when session_id unavailable in stdin payload"
    knob: "STOP_BLOCK_MAX hard-coded to 5 at top of check-uncommitted.sh (no env var per user direction 2026-05-22)"

  - name: ".enrich-last-hash"
    format: "Plain text (one-line SHA256 hex)"
    written_by:
      - "enrich-context.sh (UserPromptSubmit) — after successful checkpoint injection"
    read_by:
      - "enrich-context.sh (UserPromptSubmit) — hash-guard short-circuit check"
    schema: "SHA256 hex string of latest checkpoint file content (64 chars)"
    lifecycle: session-specific
    cleanup: "Phase 5 completion — deleted alongside other session files"
    note: "Hash-guard state file. Missing → first injection runs unconditionally (no stale risk). Stale across sessions → worst case one spurious re-injection on session start."

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

  - name: "tool-failures.jsonl"
    format: JSONL
    written_by:
      - "log-tool-failure.sh (PostToolUseFailure, matcher: Bash)"
    read_by:
      - "Operator on-demand — failure-pattern detection across iterations"
      - "systematic-debugging skill — Phase 1 Root Cause Investigation input (last 3 entries)"
    schema: "{ts, session_id, tool_name, command_excerpt, exit_signature, effort_level}"
    lifecycle: cross-session
    cleanup: "Head-trim rotation at CLAUDE_TOOL_FAILURES_MAX_LINES (default 1000); never auto-deleted."

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
    files: ["{feature}-checkpoint.yaml", "review-completions.jsonl", "agent-id-registry.jsonl",
            "task-events.jsonl", ".enrich-last-hash"]
    retention: "Until Phase 5 completion (data captured in pipeline-metrics.jsonl)"

  cross-session:
    description: "Persistent data that accumulates across workflows"
    files: ["pipeline-metrics.jsonl", "session-analytics.jsonl", "config-changes.jsonl", "tool-failures.jsonl"]
    retention: "Manual cleanup — suggest archiving when file exceeds 100 entries (tool-failures.jsonl auto-rotates at CLAUDE_TOOL_FAILURES_MAX_LINES, default 1000)"

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
      - ".enrich-last-hash"
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
