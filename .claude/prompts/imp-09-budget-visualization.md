meta:
  type: "plan"
  task: "IMP-09: Exploration budget visualization in enrich-context.sh"
  complexity: M
  user_override: XL
  sequential_thinking: not_required

plan:
  title: "Exploration Budget Visualization in enrich-context.sh"

  context:
    summary: |
      Extend enrich-context.sh (UserPromptSubmit hook) to display exploration budget
      consumption from checkpoint sub_phase data. Currently the model must self-track
      its read count against planner/coder budget limits. This adds an explicit signal
      in additionalContext showing reads/limit with percentage and >80% warning.

  scope:
    in:
      - "Read checkpoint sub_phase fields (current, file_reads_in_sub_phase)"
      - "Budget limit lookup table by phase_name + complexity"
      - "Budget visualization line in additionalContext"
      - "Warning at >80% budget consumption"
    out:
      - item: "Modifying planner.md/coder.md budget definitions"
        reason: "Budget limits are authoritative in those files; script just reads them"
      - item: "Replacing existing transcript-based exploration detection (section 4)"
        reason: "Keep both — checkpoint-based is primary, transcript-based is fallback"
      - item: "Enforcing budget (blocking)"
        reason: "Script is non-blocking (exit 0 always). Enforcement remains model's responsibility"

  dependencies:
    beads_issue: "N/A"
    blocks: []
    blocked_by: []

  architecture:
    decision: "New section in enrich-context.sh Python block reading checkpoint sub_phase data"
    alternatives:
      - option: "Replace existing section 4 (transcript-based detection) with checkpoint-based"
        rejected_because: "Transcript detection is a fallback when no checkpoint exists (ad-hoc sessions)"
      - option: "Separate script for budget tracking"
        rejected_because: "Adds hook overhead; enrich-context.sh already reads checkpoint"
      - option: "Use YAML parser library (pyyaml)"
        rejected_because: "Script has zero-dependency constraint (no pyyaml)"
    chosen:
      approach: "Add section 4b in the existing Python block, between exploration detection and git branch"
      rationale: "Reuses checkpoint parsing from section 1, no new dependencies, additionalContext is the right delivery mechanism"

  parts:
    - part: 1
      name: "Extend checkpoint parser for sub_phase fields"
      file: ".claude/scripts/enrich-context.sh"
      action: "UPDATE"
      description: |
        Extend the YAML parser in section 1 (lines 26-53) to also extract:
        - `file_reads_in_sub_phase` — read count in current sub-phase
        - `budget_threshold` — limit from checkpoint (if written by model)
        - `current` — sub-phase name (e.g., "RESEARCH", "EVALUATE") from `sub_phase.current`
        Add these 3 keys to the extraction whitelist in the `if key in (...)` check.
        NOTE: Do NOT add `sub_phase` to whitelist — it appears twice in checkpoint YAML
        (as `implementation_progress.sub_phase` string and as `sub_phase:` section header),
        causing a collision in the flat parser. Use `current` for the sub-phase label instead.

    - part: 2
      name: "Add budget limits lookup table"
      file: ".claude/scripts/enrich-context.sh"
      action: "UPDATE"
      description: |
        Add BUDGET_LIMITS dict mapping (phase_type, complexity) → read limit.
        Sources:
        - planner.md research_budget: S=5, M=10, L=20, XL=30
        - coder.md evaluate_budget: S=3, M=6, L=12, XL=18
        - Default per-sub-phase: 20 (from checkpoint-protocol.md)
        Phase detection: phase_name "planning" → planner budgets, "implementation" → coder budgets.

    - part: 3
      name: "Add budget visualization section (4b)"
      file: ".claude/scripts/enrich-context.sh"
      action: "UPDATE"
      description: |
        New section between existing section 4 and section 5 (git branch).
        Logic:
        1. Check if sub_phase data exists in checkpoint (file_reads_in_sub_phase)
        2. Determine budget limit: use budget_threshold from checkpoint if available,
           otherwise lookup from BUDGET_LIMITS by (phase_name, complexity)
        3. Resolve limit with explicit priority chain:
           limit = int(data.get("budget_threshold")) or BUDGET_LIMITS.get((phase_name, complexity), 20)
           (checkpoint budget_threshold takes priority → then phase/complexity lookup → then default 20)
        4. Calculate percentage = (reads / limit) * 100
        5. Format output: "Budget: {reads}/{limit} ({percentage}%) — {sub_phase_name}"
           where sub_phase_name = data.get("current", "unknown")
        6. If percentage > 80: append " — consider transitioning"
        Guard: if no file_reads_in_sub_phase in checkpoint → skip silently (section 4 fallback handles it)

    - part: 4
      name: "Update workflow documentation"
      file: ".claude/commands/workflow.md"
      action: "UPDATE"
      description: |
        Update the hooks.also_active_during_workflow entry for enrich-context.sh
        to mention budget visualization capability.

  files_summary:
    - file: ".claude/scripts/enrich-context.sh"
      action: "UPDATE"
      description: "Add budget visualization from checkpoint sub_phase data (~30 lines)"
    - file: ".claude/commands/workflow.md"
      action: "UPDATE"
      description: "Update hook description to mention budget visualization"

  acceptance_criteria:
    functional:
      - "When checkpoint has sub_phase.file_reads_in_sub_phase, budget line appears in additionalContext"
      - "Budget percentage calculated correctly (reads/limit * 100)"
      - "Warning appears when percentage > 80%"
      - "No output when sub_phase data is absent (graceful degradation)"
      - "Script still exits 0 in all cases (non-blocking)"
    technical:
      - "bash -n .claude/scripts/enrich-context.sh passes (syntax check)"
      - "python3 -c 'compile(open(...).read(), ..., \"exec\")' passes"
      - "Performance < 500ms (no new subprocess calls)"
      - "No pyyaml or external dependencies"
    architecture:
      - "Budget limits match planner.md and coder.md definitions exactly"
      - "Existing transcript-based detection (section 4) preserved as fallback"
      - "Output format consistent with existing additionalContext style"

  config_changes: []

  notes: |
    - Checkpoint sub_phase data is Optional per protocol — may not exist in all sessions.
    - The flat YAML parser extracts keys by name. Keys `file_reads_in_sub_phase`,
      `budget_threshold`, and `current` are unique enough for safe extraction.
      Key `sub_phase` is NOT extracted — it appears twice in checkpoint YAML
      (implementation_progress.sub_phase as string value, sub_phase: as section header)
      causing a collision in flat parsing. `current` is used for sub-phase label instead.
    - Budget limits are duplicated from planner.md/coder.md into the script as constants.
      If limits change in the source docs, the script constants must be updated manually.
      This is acceptable: limits rarely change and the script is a visualization aid, not enforcement.
    - Limit resolution priority: checkpoint budget_threshold > BUDGET_LIMITS lookup > default 20.
