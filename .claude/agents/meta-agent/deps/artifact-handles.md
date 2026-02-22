# Artifact Handles (v10.0)

purpose: "Pass lightweight references instead of full content — save context budget"
source: "Context engineering research + Google ADK handle pattern"
principle: "Load metadata first, content on demand — like file descriptors vs file contents"

## Why Handles

problem:
  current: "Artifact loaded entirely into context (Read tool → full content)"
  cost: "500-line artifact = 500 lines of budget consumed even if only 20 lines needed"
  budget: "1500-line global budget → single large artifact eats 33%"

solution:
  handle: "Lightweight reference (path + size + section map + summary) — ~10-15 lines"
  on_demand: "Load specific sections when actually needed via Read with offset/limit"
  savings: "500-line artifact → 15-line handle + 50 lines on-demand = 65 lines (87% savings)"

## Handle Structure

artifact_handle:
  schema:
    path: "string — absolute path to artifact file"
    type: "string — command|skill|rule|agent"
    size: "int — total lines"
    last_modified: "string — ISO date"
    sections: "list[{name, start_line, end_line, summary}]"
    loaded_sections: "list[string] — which sections are currently in context"
    budget_cost: "int — lines currently consuming budget"

  example: |
    artifact_handle:
      path: .claude/skills/{skill-name}/SKILL.md
      type: skill
      size: 350
      last_modified: 2026-02-01
      sections:
        - {name: frontmatter, lines: "1-15", summary: "triggers, meta, dependencies"}
        - {name: core_instructions, lines: "16-120", summary: "main rules and patterns"}
        - {name: examples, lines: "121-250", summary: "bad/good/why examples"}
        - {name: troubleshooting, lines: "251-350", summary: "edge cases, known issues, workarounds"}
      loaded_sections: [frontmatter]
      budget_cost: 15

## Handle Operations

operations:
  create_handle:
    when: "First encounter of artifact (EXPLORE or RESEARCH phase)"
    process:
      - "Read file with limit=30 (frontmatter + first section)"
      - "Parse section boundaries (## headers or YAML top-level keys)"
      - "Generate 1-line summary per section"
      - "Store handle in session context (replaces full file)"
    cost: "~15 lines per handle (vs 100-500 lines for full file)"

  load_section:
    when: "Specific section needed for current task"
    command: '"Load section {name} from {handle.path}"'
    process:
      - "Read(path, offset=section.start_line, limit=section.end_line - section.start_line)"
      - "Update handle.loaded_sections += [section_name]"
      - "Update handle.budget_cost += section_lines"
    cost: "Only the requested section lines"

  unload_section:
    when: "Section no longer needed (phase transition)"
    process:
      - "Remove section content from context"
      - "Update handle.loaded_sections -= [section_name]"
      - "Update handle.budget_cost -= section_lines"
    note: "Handle itself always stays (15 lines) — only section content unloaded"

  refresh_handle:
    when: "Artifact modified during session (APPLY phase)"
    process:
      - "Re-read frontmatter"
      - "Re-parse section boundaries"
      - "Update size, last_modified, sections"
      - "Invalidate loaded_sections cache"

## Section Detection

section_detection:
  strategies:
    yaml_keys: "Top-level YAML keys (no indentation, ends with ':')"
    markdown_headers: "## or # headers"
    separator_comments: "# ═══ or # ──── style dividers"
    explicit_markers: "Frontmatter sections field (if present)"

  priority: [explicit_markers, separator_comments, markdown_headers, yaml_keys]

  minimum_section_size: 10  # lines — don't split smaller than this
  maximum_sections: 15      # per artifact — keep handle manageable

## Phase Integration

phase_usage:
  EXPLORE:
    action: "Create handles for all discovered artifacts"
    load: "frontmatter only (triggers, meta)"
    budget: "~15 lines per artifact × N artifacts"

  ANALYZE:
    action: "Load core_instructions sections for gap analysis"
    load: "frontmatter + core sections"
    unload_after: "Summarize findings, unload sections"

  PLAN:
    action: "Handles provide section map for planning changes"
    load: "Only sections identified as change targets"

  DRAFT:
    action: "Load sections being rewritten"
    load: "Target sections + adjacent for context"
    note: "Never load entire artifact if only editing 1 section"

  VERIFY:
    action: "Load modified sections for validation"
    load: "Only changed sections"
    refresh: "Handle refreshed after APPLY"

## Budget Impact

budget_comparison:
  scenario: "ENHANCE mode, 3 artifacts analyzed"
  without_handles:
    artifact_1: 350  # lines loaded
    artifact_2: 280
    artifact_3: 450
    total: 1080  # leaves only 420 for deps
  with_handles:
    artifact_1_handle: 15
    artifact_1_sections_loaded: 60  # 2 sections on demand
    artifact_2_handle: 12
    artifact_2_sections_loaded: 40
    artifact_3_handle: 15
    artifact_3_sections_loaded: 80
    total: 222  # leaves 1278 for deps — 3x more budget!
  savings: "1080 → 222 lines (79% reduction)"

## Integration with Existing Systems

integration:
  load_order:
    change: "Tier 3/4 files loaded as handles by default, sections on demand"
    ref: "SEE: deps/load-order.md#handle_aware_loading"

  context_management:
    change: "budget_tracking.loaded_files gets handle_sections field"
    ref: "SEE: deps/context-management.md#handle_tracking"

  subagents:
    change: "Subagent inputs specify sections, not full files"
    example: "codebase_analyzer receives artifact handles, loads sections it needs"

  before_load_checks:
    change: "check_3_alternatives now includes 'use handle instead of full load'"

## Constraints

constraints:
  always_full_load:
    - "meta-agent.md (Tier 1 — always loaded, too critical for partial)"
    - "Template files during DRAFT (need complete template)"
    - "Active artifact being written/applied in APPLY phase"
  handle_only:
    - "Artifacts being analyzed (EXPLORE/ANALYZE — section-level access)"
    - "Reference artifacts for style comparison (clarity_critic)"
    - "Dependency artifacts (check existence, not content)"
