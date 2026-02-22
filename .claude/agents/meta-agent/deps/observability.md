# Observability

purpose: "Track execution, find bottlenecks, debug failures"
enabled: true

## Trace Per Run

capture:
  - start_time, end_time
  - phase_durations (per phase)
  - files_read, files_modified
  - gate_failures (which gates failed)
  - checkpoint_responses (user Y/n/edit)
  - errors_encountered

output_format: |
  ## Meta-Agent Trace: {mode} {type} {name}
  Started: {timestamp}
  Duration: {total_seconds}s

  ### Phase Timings
  | Phase | Duration | Status |
  |-------|----------|--------|
  | INIT | Xs | ✅/❌ |
  | EXPLORE | Xs | ✅/❌ |
  ...

  ### Metrics
  - Files read: N
  - Files modified: N
  - Gate failures: N

  ### Issues
  - [list or "none"]

## Save Trace

when: "always in CLOSE phase"
to_memory:
  tool: "mcp__memory__add_observations"
  entity: "meta-agent-run-{date}"
  observations:
    - "Mode: {mode}"
    - "Target: {type}/{name}"
    - "Duration: {total_seconds}s"
    - "Status: {success|failure}"
    - "Gate failures: {list}"

## Metrics Summary

show_in_close: true
format: |
  📊 Run metrics: {duration}s | {files_read} read | {files_modified} modified
