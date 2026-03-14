# Context Management

purpose: "Efficient use of context window, prevent information loss"

## Hierarchy

### Immediate
scope: "current phase"
contains:
  - current_file_content (if reading)
  - user_input
  - phase_output
lifecycle: "cleared after phase"

### Session
scope: "current run"
contains:
  - research_summary
  - approved_plan
  - changes_made
  - trace_data
lifecycle: "persist until CLOSE"
priority: "preserve over immediate"

### Persistent
scope: "across sessions"
storage: "mcp__memory"
contains:
  - lessons_learned
  - artifact_relations
  - project_patterns
  - run_history
lifecycle: "permanent"

## Compaction

trigger: "context seems large (many files read)"
strategy:
  - Summarize EXPLORE findings (keep key facts only)
  - Keep PLAN in full (user-approved)
  - Keep last APPLY output
  - Discard verbose file contents after extraction

## Preserve Always

- user's original request
- approved PLAN from CHECKPOINT
- CONSTITUTE issues found
- VERIFY results
- trace metrics

# ════════════════════════════════════════════════════════════════════════════════
# CONTEXT BUDGET TRACKING & ENFORCEMENT
# ════════════════════════════════════════════════════════════════════════════════

budget_tracking:
  purpose: "Prevent context overflow with explicit budget enforcement"
  principle: "Context engineering (Anthropic, 2025) — curate optimal token set"
  global_budget: 1500

  tracking_structure:
    loaded_files:
      - path: "string (e.g., deps/artifact-analyst.md)"
        lines: "int"
        tier: "int (1-4)"
        loaded_at: "string (phase name)"
        load_mode: "full | handle | handle+sections"
    handles:  # Handle Pattern
      - path: "string"
        handle_lines: "int (~15)"
        loaded_sections: "list[string]"
        section_lines: "int (sum of loaded sections)"
        total_cost: "int (handle_lines + section_lines)"
    total_lines: "int (sum of all loaded_files lines + handle costs)"
    budget_remaining: "int (global_budget - total_lines)"
    percent_used: "float (total_lines / global_budget * 100)"

  # Handle-Aware Tracking
  handle_tracking:
    purpose: "Track handle vs full-load budget costs separately"
    ref: "deps/artifact-handles.md"  # handle pattern, budget costs, section loading
    rule: "Prefer handle for Tier 3/4 files; full load only when explicitly needed"
    budget_display: |
      📊 Context Budget: {total}/{global_budget} ({percent}%)
      Full loads: {full_load_count} files ({full_load_lines} lines)
      Handles: {handle_count} artifacts ({handle_lines} lines, {sections_loaded} sections loaded)

  initialization:
    when: "INIT phase, step 8a"
    state: |
      loaded_files: [{path: "meta-agent.md", lines: ~560, tier: 1, loaded_at: "INIT"}]
      total_lines: ~560
      budget_remaining: ~940

enforcement:
  before_load:
    check: "total_lines + new_file_lines <= global_budget"
    if_pass: "Proceed with load, update tracking"
    if_fail: "Trigger unload strategy"

  if_exceed:
    step_1: "Attempt unload lowest-tier file (Tier 4 first, then Tier 3)"
    step_2: "If still exceed: summarize file contents (10-15 line summary) + unload"
    step_3: "Log context_pressure event → deps/observability.md"  # trace events, logging format
    step_4: "Warn user if exceed 90% budget"
    step_5: "HARD STOP if exceed 100% (force unload before proceeding)"

  unload_strategy:
    priority: "Tier 4 → Tier 3 → Tier 2 → Tier 1 (NEVER unload)"
    for_tier_4: "Always unloadable, unload immediately after use"
    for_tier_3: "Unload when phase completes"
    for_tier_2: "Unload only if mode changes (rare)"
    for_tier_1: "Never unload"

    summarize_rule:
      when: "Unloading file with important findings"
      action: |
        - Extract key facts/patterns (10-15 lines)
        - Store summary in progress.json under context_notes
        - Include reference: "See {file} for details"
      benefit: "Knowledge preserved even after unload"

output_per_phase: |
  📊 Context Budget: {loaded_lines}/{global_budget} ({percent_used}%)
  Loaded:
    - {file1} (T{tier}, {lines} lines)
    - {file2} (T{tier}, {lines} lines)
  [if percent_used > 80]
  ⚠️ Context pressure: consider unloading unused deps
  [/if]
