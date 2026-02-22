# PHASES: CREATE (detailed)

note: |
  CREATE mode uses same integrated patterns as ENHANCE:
  - Pattern 1 (Progress Tracking): workspace, checkpoints, resume
  - Pattern 2 (Eval-Optimizer): DRAFT phase with quality loop
  - Pattern 3 (4-Tier Loading): Tier 3 load/unload per phase
  - Pattern 4 (Activation Layer): validation in INIT
  v10.0: Agent Teams pattern for RESEARCH + DRAFT phases
  - SEE: deps/agent-teams.md for team definition and constraints

## phase_1_init

note: "Same as phases_enhance.phase_1_init with activation, progress, load_order"

## phase_2_research

name: "RESEARCH"
effort: medium
model: "haiku (teammates) / sonnet (lead)"
mode: "agent_team"
team_ref: "SEE: deps/agent-teams.md#create_mode_team"

steps_v10_team:
  # Load Order (Pattern 3) — Tier 3
  - "1. LOAD: Tier 3 — relevant skills, codebase patterns"
  # Agent Team execution
  - "2. TEAM: Spawn 'researcher' teammate (haiku) → analyze codebase for patterns"
  - "3. TEAM: Spawn 'scanner' teammate (haiku) → find similar artifacts, check duplicates"
  - "4. TEAM: researcher and scanner exchange findings peer-to-peer if needed"
  - "5. TEAM: Lead aggregates teammate outputs into research_summary"
  # Unload (Pattern 3)
  - "6. UNLOAD: Tier 3 (keep findings in memory)"
  # Checkpoint (Pattern 1)
  - "7. CHECKPOINT: Update progress.json (RESEARCH: done), write checkpoints/research.json"

advantages_over_v9:
  - "Teammates persist — can be re-queried in DRAFT phase for clarification"
  - "Isolated contexts — no pollution between researcher and scanner"
  - "Peer-to-peer — researcher can send patterns directly to scanner for overlap check"

fallback_v9_dag:
  when: "Agent Teams unavailable"
  steps:
    - "Spawn codebase_analyzer: find code patterns"
    - "Spawn artifact_scanner: find similar artifacts"
    - "Spawn context_loader: load PROJECT-KNOWLEDGE + MCP"
    - "Await all, aggregate into research_summary"

fallback_sequential:
  when: "All subagent systems unavailable"
  steps:
    - "Explore src/ for the area to document"
    - "Find ≥3 code examples"
    - "Identify common patterns"

step_quality:
  checks: ["≥3 code examples", "patterns identified", "similar artifacts checked"]
  min_pass: 3

output: |
  ## [2/9] RESEARCH ✓ (agent team)
  Teammates: researcher (haiku), scanner (haiku)
  Code examples: {N} found
  Similar artifacts: {N} found
  Patterns: [list]
  Quality: {passed}/{total} checks ✅

## phase_3_template

name: "TEMPLATE"
path: ".claude/templates/<type>.md"

steps:
  # Load Order (Pattern 3) — Tier 3
  - "1. LOAD: Tier 3 — templates/<type>.md"
  - "2. Load template for artifact type"
  - "3. Review required sections"
  - "4. Check for duplicate artifact (semantic search)"
  # Unload (Pattern 3)
  - "5. UNLOAD: Tier 3 (template reviewed)"
  # Checkpoint (Pattern 1)
  - "6. CHECKPOINT: Update progress.json (TEMPLATE: done), write checkpoints/template.json"

duplicate_check:
  tool: "mcp__memory__read_graph"
  query: "claude-artifact {name}"
  on_found: |
    ⚠️ Similar artifact may exist: {found_name}
    Options: [Enhance existing / Create new / Cancel]

## other_phases

note: |
  Same as ENHANCE with integrated patterns:
  - PLAN (phase 4): Tier 3 load/unload + checkpoint
  - CONSTITUTE (phase 5): constitutional evaluation + checkpoint
  - DRAFT (phase 6): 'designer' teammate generates draft → evaluator_agent (subagent, opus) → reflector_agent (subagent, opus) if needed
    Note: evaluator/reflector remain subagents (NOT teammates) for fresh-context isolation. SEE: deps/agent-teams.md#evaluator_reflector_note
  - APPLY (phase 7): Tier 3 load/unload + checkpoint
  - VERIFY (phase 8): Tier 3 load/unload + checkpoint
  - CLOSE (phase 9): final progress update + auto-chain
