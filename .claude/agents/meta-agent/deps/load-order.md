# 4-Tier Lazy Loading

purpose: "Explicit loading strategy with tiers and unloading"
difference_from_context_management: "context_management = what to preserve; load-order = when to load/unload"

## Tiers

tier_1:
  name: "Always Loaded"
  when: "Session start"
  files:
    - "meta-agent.md (core workflow)"
  max_lines: 300
  unload: "Never"

tier_2:
  name: "Mode-Specific"
  when: "Mode determined (create/enhance/audit)"
  files:
    create:
      - "deps/blocking-gates.md"
      - "deps/subagents.md"
      - "deps/agent-teams.md (Agent Teams for CREATE mode)"
    enhance:
      - "deps/artifact-analyst.md"
    audit:
      - "deps/observability.md"
  max_lines: 150
  unload: "Never (persists for run)"

tier_3:
  name: "Phase-Specific"
  when: "Phase starts"
  files:
    RESEARCH:
      - "deps/artifact-analyst.md"
    PLAN:
      - "deps/artifact-review.md"
      - "deps/plan-exploration.md (ToT, conditional: CREATE or changes > 5)"
    CONSTITUTE:
      - "deps/artifact-constitution.md"
    DRAFT:
      - "deps/eval-optimizer.md"
      - "deps/artifact-archive.md (step 0 — active composition, both modes)"
      - "templates/<type>.md"
    APPLY:
      - "deps/artifact-quality.md"
    VERIFY:
      - "deps/artifact-quality.md#external_validation"
    CLOSE:
      - "deps/artifact-archive.md (extract patterns + feedback)"
  max_lines: 400
  unload: "When phase completes"

tier_4:
  name: "On-Demand Reference"
  when: "Explicitly needed during work"
  files:
    - "deps/troubleshooting.md"
    - "deps/artifact-fix.md"
    - "examples files"
  trigger: "Issue requires deep reference"
  max_lines: 250
  unload: "After use"

## Loading Rules

rules:
  - "NEVER load Tier 4 proactively"
  - "Unload Tier 3 when phase completes"
  - "Track loaded_deps to avoid duplicate loads"
  - "Total loaded at any time: <1500 lines"
  - "Prefer handles for Tier 3/4 — load sections on demand"

# Handle-Aware Loading
handle_aware_loading:
  purpose: "Use artifact handles to reduce budget consumption"
  ref: "SEE: deps/artifact-handles.md for full Handle Pattern"
  policy:
    tier_1: "Always full load (meta-agent.md — too critical for partial)"
    tier_2: "Full load (mode-specific deps, persistent for run)"
    tier_3: "Handle by default → load sections on demand per phase needs"
    tier_4: "Handle by default → load single section, unload after use"
  example: |
    # Before (v9): DRAFT phase loads eval-optimizer.md fully (250 lines)
    # After (v10):  Create handle (15 lines) → load mar_evaluation section (60 lines)
    # Savings: 250 → 75 lines (70% reduction per file)

## Loading Flow

flow: |
  Session Start
       │
       ▼
  ┌─────────────────────┐
  │ Load Tier 1 (300)   │ ← Always: meta-agent.md
  └──────────┬──────────┘
             │
             ▼
       Mode: create
             │
             ▼
  ┌─────────────────────┐
  │ Load Tier 2 (150)   │ ← Mode: blocking-gates.md
  └──────────┬──────────┘
             │
             ▼
     Phase: RESEARCH
             │
             ▼
  ┌─────────────────────┐
  │ Load Tier 3 (400)   │ ← Phase: artifact-analyst.md
  └──────────┬──────────┘
             │
             ▼
      RESEARCH done
             │
             ▼
  ┌─────────────────────┐
  │ Unload Tier 3       │ ← Free context for next phase
  └──────────┬──────────┘
             │
             ▼
      Phase: PLAN
             │
             ▼
  ┌─────────────────────┐
  │ Load Tier 3 (400)   │ ← Phase: artifact-review.md
  └─────────────────────┘

## Context Budget

budget:
  tier_1: 300
  tier_2: 150
  tier_3: 400
  tier_4: 250
  max_total: 1500

tracking:
  format: "loaded_deps: ['meta-agent.md', 'blocking-gates.md', 'artifact-analyst.md']"
  current_lines: 850
  available: 650

## Unloading Strategy

tier_3_unload:
  trigger: "Phase completes successfully"
  action: "Remove from loaded_deps tracking"
  benefit: "Free context for next phase deps"

tier_4_unload:
  trigger: "Reference used, issue resolved"
  action: "Immediate unload"
  benefit: "Prevent context bloat during long runs"

## Integration

INIT:
  - "Load Tier 1"
  - "Initialize loaded_deps = ['meta-agent.md']"

mode_detection:
  - "Load Tier 2 based on mode"
  - "Add to loaded_deps"

phase_start:
  - "Load Tier 3 for current phase"
  - "Add to loaded_deps"
  - "Check total < 1500"

phase_end:
  - "Unload Tier 3"
  - "Remove from loaded_deps"

on_demand:
  - "Load Tier 4 only when needed"
  - "Use, then immediately unload"

# ════════════════════════════════════════════════════════════════════════════════
# BEFORE-LOAD CHECKS
# ════════════════════════════════════════════════════════════════════════════════

before_load_checks:
  purpose: "Validate budget before every file load"

  check_1_budget:
    action: "total_lines + new_file_lines <= max_total?"
    if_no: "Unload lowest-tier file, summarize if needed, retry"
    ref: "SEE: deps/context-management.md#enforcement"

  check_2_necessity:
    action: "Is this file actually needed for current phase?"
    if_no: "Skip loading (save budget for what matters)"

  check_3_alternatives:
    action: "Is there a lighter-weight alternative (handle, summary, cached findings)?"
    if_yes: "Use handle or summary instead of full file"
    v10_preference: "For Tier 3/4: always try handle first → section on demand → full load as last resort"

enforcement_gates:
  at_tier_2_load: "Check budget; unload Tier 4 if needed"
  at_tier_3_load: "Check budget; unload previous Tier 3 + Tier 4"
  at_tier_4_load: "Check budget; unload other Tier 4"

# ════════════════════════════════════════════════════════════════════════════════
# UPDATED TIER 3 MAPPING
# ════════════════════════════════════════════════════════════════════════════════

