# ════════════════════════════════════════════════════════════════════════════════
# TREE OF THOUGHT — PLAN EXPLORATION
# Design space exploration for PLAN phase
# ════════════════════════════════════════════════════════════════════════════════

purpose: "Explore multiple design approaches instead of single linear plan"
principle: "Broader exploration → better designs, especially for complex artifacts"
pattern_source: "Tree of Thought (Yao et al., NeurIPS 2023) — 4% → 74% on creative tasks"

# ════════════════════════════════════════════════════════════════════════════════
# ACTIVATION
# ════════════════════════════════════════════════════════════════════════════════

trigger:
  conditions:
    - "CREATE mode (always — new artifact design benefits from exploration)"
    - "ENHANCE with estimated_changes > 5 (significant restructuring)"
    - "--explore flag (user explicitly requests exploration)"
  skip_when:
    - "ENHANCE with <= 5 changes (small focused enhancement)"
    - "AUDIT mode (no artifact design)"
    - "DELETE / ROLLBACK modes (no design)"
  fallback: "If ToT skipped → standard linear plan (current behavior)"

# ════════════════════════════════════════════════════════════════════════════════
# PARAMETERS
# ════════════════════════════════════════════════════════════════════════════════

parameters:
  strategy: "breadth_first"
  max_branches: 3
  max_depth: 2
  eval_mode_l0: "fast (P1_correctness only, threshold 0.5)"
  eval_mode_l1: "full (all P1-P5, threshold 0.75)"
  final_threshold: 0.75

# ════════════════════════════════════════════════════════════════════════════════
# PROCESS
# ════════════════════════════════════════════════════════════════════════════════

process:
  level_0_root:
    goal: "Map the design space — 3 fundamentally different approaches"
    input: "Gaps from ANALYZE + artifact type + domain context"
    action: |
      Generate 3 approaches that differ in:
      - Structure (flat vs. nested, procedural vs. declarative)
      - Scope (minimal vs. comprehensive vs. modular)
      - Style (example-heavy vs. rule-heavy vs. pattern-heavy)
    examples:
      approach_A: "Minimal imperative: step-by-step workflow, few examples, compact"
      approach_B: "Comprehensive declarative: YAML-heavy, all cases covered, large"
      approach_C: "Modular hybrid: core + deps/ offloading, balanced"
    evaluation:
      method: "Fast eval — P1_correctness only"
      for_each_approach:
        - "Score P1_correctness (0.0-1.0)"
        - "If < 0.5: PRUNE (fundamentally broken design)"
        - "If >= 0.5: KEEP for level 1"
      result: "1-3 surviving approaches"
    output: |
      ToT Level 0: {generated} approaches → {surviving} survived (P1 >= 0.5)

  level_1_detail:
    goal: "Detail surviving approaches into concrete implementation variants"
    for_each_surviving_branch:
      action: |
        Generate 2 implementation variants that differ in:
        - Detail level (sections, examples, edge cases)
        - Integration approach (standalone vs. interconnected)
      evaluation:
        method: "Full eval — all P1-P5 (weighted)"
        for_each_variant:
          - "Score all 5 principles (0.0-1.0)"
          - "Calculate weighted aggregate"
          - "If aggregate < 0.75: reject"
          - "If aggregate >= 0.75: keep"
        result: "Best variant per branch (max score)"
    output: |
      ToT Level 1: {variants_evaluated} variants → {viable} viable (score >= 0.75)

  final_selection:
    input: "2-3 top variants with scores"
    present_to_user: |
      ### Design Exploration Results

      **Option 1: {approach_name}** (score: {aggregate})
      P1:{p1} P2:{p2} P3:{p3} P4:{p4} P5:{p5}
      Approach: {description}
      Pros: {pros}
      Cons: {cons}
      Size estimate: {lines} lines

      **Option 2: {approach_name}** (score: {aggregate})
      ...

      📋 Which approach? [1/2/3/custom]
    user_choice:
      explicit: "User picks a number"
      custom: "User describes modifications"
      auto: "If user doesn't choose: select max(score)"
    output: |
      ToT: Selected approach {N}: {name} (score: {score})

# ════════════════════════════════════════════════════════════════════════════════
# FALLBACK
# ════════════════════════════════════════════════════════════════════════════════

fallback:
  when: "All branches score < 0.75 after level 1"
  action:
    - "Present best attempt to user with explanation"
    - "Ask: 'None of the explored approaches scored above threshold.'"
    - "Options: [try different constraints, provide more context, proceed with best available, abort]"
  output: |
    ⚠️ ToT: No approach reached threshold (0.75)
    Best: {name} at {score}
    Issue: {primary_weakness}
    📋 Options: [retry with constraints / more context / proceed anyway / abort]

# ════════════════════════════════════════════════════════════════════════════════
# INTEGRATION
# ════════════════════════════════════════════════════════════════════════════════

integration:
  phase: "PLAN (after ANALYZE, before CONSTITUTE)"
  load_tier: "Tier 3 (loaded in PLAN phase, unloaded after)"
  requires: "deps/artifact-constitution.md (for principle-based evaluation)"
  output_to: "PLAN_to_CONSTITUTE contract (approved_changes + tot_alternatives)"
  contract_fields:
    tot_applied: true
    tot_alternatives: "list of rejected alternatives with scores and reasons"
