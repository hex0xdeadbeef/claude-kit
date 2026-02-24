# ════════════════════════════════════════════════════════════════════════════════
# PHASES: ENHANCE (detailed)
# Offloaded from meta-agent.md
# ════════════════════════════════════════════════════════════════════════════════

# Phase Output Template (shared by all phases)
# Each phase uses: "USE phase_output_template: fields=[...]"
phase_output_template: |
  ## [{phase_num}/9] {PHASE_NAME} ✓
  {fields rendered as key: value pairs}
  📊 Budget: {loaded_lines}/{max_total} ({percent}%)
  [if warnings] ⚠️ {warning} [/if]
  📋 Continue? [Y/n]

phases_enhance:
  phase_1_init:
    name: "INIT"
    effort: low
    model: sonnet
    steps:
      # Activation Layer (Pattern 4) — FIRST
      - "1. ACTIVATION: Match keywords → extract type/name → filter false positives"
      - "2. ACTIVATION: If ambiguous → ask user for clarification"
      # Progress Tracking (Pattern 1)
      - "3. PROGRESS: Create workspace: .meta-agent/runs/{run_id}/"
      - "4. PROGRESS: Generate run_id: {YYYYMMDD}-{HHMMSS}-{mode}-{target}"
      - "5. PROGRESS: Write initial progress.json (current_phase: INIT)"
      # Load Order (Pattern 3) — Tier 1 + Tier 2
      - "6. LOAD: Tier 1 — meta-agent.md already loaded"
      - "7. LOAD: Tier 2 — deps/artifact-analyst.md (for enhance mode)"
      - "8. LOAD: Initialize loaded_deps tracking"
      # Context Budget
      - "8a. BUDGET: Initialize budget_tracking (total=0, loaded_files=[])"
      # Original steps
      - "9. mcp__memory__read_graph (load context)"
      - "9a. Load episodic reflections: SEE deps/self-improvement.md#episodic_memory"
      - "10. Read current artifact file"
      - "11. Load lessons (auto-injection): SEE deps/self-improvement.md#auto_injection"
      - "12. If --track: bd create"
      # Phase Contract Output
      - "12a. Validate INIT output against phase contract: SEE deps/phase-contracts.md"
      # Checkpoint (Pattern 1)
      - "13. CHECKPOINT: Update progress.json (INIT: done), write checkpoints/init.json"
    activation:
      ref: "SEE: deps/activation-layer.md"
      steps: ["keywords", "patterns", "filter", "validate", "disambiguate"]
    progress:
      ref: "SEE: deps/progress-tracking.md"
      creates: ["workspace dir", "progress.json", "checkpoints/init.json"]
    load_order:
      ref: "SEE: deps/load-order.md"
      tier_1: "meta-agent.md (already loaded)"
      tier_2: "deps/artifact-analyst.md"
      loaded_deps: ["meta-agent.md", "artifact-analyst.md"]
    auto_injection:
      enabled: true
      max_lessons: 5
      filter: "artifact_type matches, severity >= medium"
    episodic_reflections:
      enabled: true
      max_inject: 3
      filter: "artifact_type matches, recency weighted"
      ref: "SEE: deps/self-improvement.md#episodic_memory"
    output: "USE phase_output_template: fields=[activation, run_id, workspace, artifact, lessons:{N}, reflections:{R}, loaded_deps, budget]"

  phase_2_explore:
    name: "EXPLORE"
    effort: medium
    model: "haiku (subagents) / sonnet (main)"
    gate: "EXPLORE_GATE"
    steps:
      # Load Order (Pattern 3) — Tier 3
      - "1. LOAD: Tier 3 — PROJECT-KNOWLEDGE.md, relevant skills"
      # Context Budget Check
      - "1a. BUDGET: Check total + new_files <= max_total before loading"
      # Knowledge gathering
      - "2. Read PROJECT-KNOWLEDGE.md → Directory Structure, Code Patterns"
      - "3. Load relevant skills"
      - "4. Search for NEW/CHANGED patterns only"
      - "5. mcp__memory: load meta-agent-lesson entities"
      # Unload (Pattern 3)
      - "6. UNLOAD: Tier 3 (keep findings in memory)"
      # Phase Contract Output
      - "6a. Validate EXPLORE output against phase contract: SEE deps/phase-contracts.md"
      # Checkpoint (Pattern 1)
      - "7. CHECKPOINT: Update progress.json (EXPLORE: done), write checkpoints/explore.json"
    knowledge_hierarchy:
      1_map: "PROJECT-KNOWLEDGE.md → Directory Structure, Code Patterns"
      2_related: "Load related artifacts (skills, commands)"
      3_code: "Search for NEW/CHANGED patterns only"
      4_lessons: "mcp__memory: load meta-agent-lesson entities"
    layer_reference:
      note: "Project-specific — define layers in CLAUDE.md"
      pattern: "internal/{layer}/ — {layer description}"
    step_quality:
      checks: ["PROJECT-KNOWLEDGE.md read", "artifact loaded", "≥1 skill/pattern found"]
      scoring: "continuous 0.0-1.0 per check, weighted average (SEE: deps/step-quality.md#phase_criteria.EXPLORE)"
      threshold: 0.5  # minimum phase_score to proceed
    output: "USE phase_output_template: fields=[sources, new_findings, lessons:{N}, quality_checks, budget, gate:EXPLORE_GATE]"

  phase_3_analyze:
    name: "ANALYZE"
    effort: high
    model: sonnet
    steps:
      - "1. Analyze artifact against checklist"
      - "2. Identify gaps and priorities"
      # Phase Contract Output
      - "2a. Validate ANALYZE output against phase contract: SEE deps/phase-contracts.md"
      # Checkpoint (Pattern 1)
      - "3. CHECKPOINT: Update progress.json (ANALYZE: done), write checkpoints/analyze.json"
    checklist:
      - "troubleshooting section?"
      - "common_mistakes section?"
      - "examples for each pattern?"
    output: "USE phase_output_template: fields=[gaps_table(Missing|Priority|Est.lines)]"

  phase_4_plan:
    name: "PLAN"
    effort: max
    model: sonnet
    steps:
      # Load Order (Pattern 3) — Tier 3
      - "1. LOAD: Tier 3 — deps/artifact-review.md"
      # Context Budget Check
      - "1a. BUDGET: Check total + new_files <= max_total before loading"
      # Tree of Thought exploration(conditional)
      - "1b. If CREATE mode OR estimated_changes > 5: LOAD deps/plan-exploration.md"
      - "1c. ToT: Generate 3 approaches → fast eval → prune → detail → full eval → select"
      - "1d. Present 2-3 options to user (if ToT active)"
      # Standard planning
      - "2. Define exact changes for each gap"
      - "3. Check SIZE threshold"
      # Unload (Pattern 3)
      - "4. UNLOAD: Tier 3 (artifact-review.md, plan-exploration.md)"
      # Phase Contract Output
      - "4a. Validate PLAN output against phase contract: SEE deps/phase-contracts.md"
      # Checkpoint (Pattern 1)
      - "5. CHECKPOINT: Update progress.json (PLAN: done), write checkpoints/plan.json"
    tree_of_thought:
      ref: "SEE: deps/plan-exploration.md"
      trigger: "CREATE mode OR estimated_changes > 5"
      fallback: "Linear plan if ToT not triggered or all branches < 0.7"
    thresholds:
      command: "warning > 500, critical > 800"
      skill: "warning > 600, critical > 700"
    output: "USE phase_output_template: fields=[tot_summary(if active), changes_list, size_delta]"

  phase_5_constitute:
    name: "CONSTITUTE"
    effort: high
    model: sonnet
    when: "ALWAYS before CHECKPOINT — mandatory constitutional review"
    gate: "CONSTITUTE_GATE"
    steps:
      # Load Order (Pattern 3) — Tier 3
      - "1. LOAD: Tier 3 — deps/artifact-constitution.md"
      # Constitutional evaluation(replaces ad-hoc critique)
      - "2. Evaluate plan against each universal principle (P1-P5)"
      - "3. Score each principle 0.0-1.0 with explicit reasoning"
      - "3a. Evaluate domain-specific P6-P7 for artifact_type (SEE: artifact-constitution.md#domain_principles)"
      - "4. If any principle < 0.7: describe violation + propose fix"
      - "5. Calculate: base = weighted_sum(P1-P5), bonus = (P6+P7)/2*0.10-0.05, final = clamp(base+bonus, 0, 1)"
      - "6. If final < 0.85: propose improvements, loop"
      # Legacy critique questions (kept for compatibility)
      - "7. Cross-check: Is this the simplest solution?"
      - "8. Cross-check: Am I missing edge cases?"
      - "9. Cross-check: Does size stay within thresholds?"
      - "10. Cross-check: Is there duplication with existing artifacts?"
      # Unload (Pattern 3)
      - "11. UNLOAD: Tier 3 (artifact-constitution.md)"
      # Phase Contract Output
      - "11a. Validate CONSTITUTE output against phase contract: SEE deps/phase-contracts.md"
      # Checkpoint (Pattern 1)
      - "12. CHECKPOINT: Update progress.json (CONSTITUTE: done), write checkpoints/constitute.json"
    constitution:
      ref: "SEE: deps/artifact-constitution.md"
      universal: ["P1_correctness (0.30)", "P2_clarity (0.25)", "P3_robustness (0.20)", "P4_efficiency (0.15)", "P5_maintainability (0.10)"]
      domain: "P6 + P7 per artifact_type (bonus ±0.05)"
      threshold: 0.85
    output: "USE phase_output_template: fields=[P1-P5_scores, P6-P7_domain, base, bonus, final, issues(if any), CHECKPOINT]"

  phase_6_draft:
    name: "DRAFT"
    effort: max
    model: "sonnet (generation) / opus+sonnet+haiku (MAR critics) / opus (reflector)"
    when: "After CHECKPOINT approval, before APPLY"
    purpose: "Generate artifact content with MAR eval-reflect loop (Multi-Agent Reflexion)"
    steps:
      # Load Order (Pattern 3) — Tier 3
      - "1. LOAD: Tier 3 — deps/eval-optimizer.md, templates/<type>.md"
      # Context Budget Check
      - "1a. BUDGET: Check total + new_files <= max_total before loading"
      # ── Step 0: Archive Active Composition ──
      - "0a. LOAD: deps/artifact-archive.md (Tier 3)"
      - "0b. ARCHIVE QUERY: Query archive with {artifact_type, domain_tags, mode}"
      - "0c. ARCHIVE HINTS: Format top 5 patterns as structural_hints (max 50 lines)"
      - "0d. ARCHIVE TRACK: Record patterns_queried, patterns_presented in progress.json"
      - "0e. If no matching patterns: skip silently, proceed to generation"
      - "0f. Present hints to generator as pre-generation context"
      # SEE: deps/artifact-archive.md#active_composition for query API + hint format
      # Note: archive unloaded in step 11 together with eval-optimizer
      # ── End Step 0 ──
      # Draft generation (Actor)
      - "2. GENERATE: Create initial artifact based on approved plan + archive hints + reflections"
      - "3. Save draft to workspace: drafts/v1.md"
      # MAR Evaluation (3 critics in parallel)
      - "4. EVALUATE (MAR): Spawn 3 critics in parallel (max_turns:3 each):"
      - "   4a. correctness_critic (opus) → P1+P3+P6+P7 scores + issues"
      - "   4b. clarity_critic (sonnet) → P2+P5 scores + issues"
      - "   4c. efficiency_critic (haiku) → P4+token_density scores + issues"
      # Debate Round (conditional, SEE: eval-optimizer.md#debate)
      - "4d. DEBATE GATE: if score_spread > 0.15 OR aggregate in [0.75, 0.90]:"
      - "   4e. Spawn 3 debate reviews in parallel (max_turns:3 each) — each critic reviews other two's issues"
      - "   4f. POST-DEBATE: adjust severities by consensus (confirmed ↑, disputed ↓)"
      - "5. AGGREGATE: Merge critic scores (weighted: 0.40/0.35/0.25), apply debate adjustments, deduplicate issues"
      # Decision
      - "6. If aggregate_score >= 0.85: PASS → continue to step 10"
      - "7. If aggregate_score < 0.85: REFLECT → spawn reflector_agent"
      # Reflection (Reflector receives all 3 critic reports + debate results)
      - "8. REFLECT: Reflector receives all 3 critic evaluations + debate consensus, generates synthesis"
      - "8a. Store reflection in episodic memory (mcp__memory)"
      # Optimize loop
      - "9. OPTIMIZE: Fix issues prioritized by cross-critic consensus (max 3 iterations, return to step 4)"
      # Save results
      - "10. Save eval_history to progress.json (includes per-critic scores)"
      - "10a. Save archive_composition to progress.json: {patterns_queried, patterns_presented, patterns_used, patterns_skipped}"
      # Unload (Pattern 3)
      - "11. UNLOAD: Tier 3 (eval-optimizer.md, artifact-archive.md)"
      # Phase Contract Output
      - "11a. Validate DRAFT output against phase contract: SEE deps/phase-contracts.md"
      # Checkpoint (Pattern 1)
      - "12. CHECKPOINT: Update progress.json (DRAFT: done), write checkpoints/draft.json"
    archive_composition:
      ref: "SEE: deps/artifact-archive.md#active_composition"
      trigger: "Step 0, before generation (BOTH enhance and create modes)"
    eval_optimizer:
      ref: "SEE: deps/eval-optimizer.md#mar_evaluation and #debate"
      max_iterations: 3
      quality_threshold: 0.85
      adaptive_weights: "SEE: deps/eval-optimizer.md#adaptive_weights"
      mar_critics: "SEE: deps/subagents.md#correctness_critic, clarity_critic, efficiency_critic"
      debate: "SEE: deps/subagents.md#debate_round (conditional on spread/score)"
      reflector: "SEE: deps/subagents.md#reflector_agent"
      flow: |
        GENERATE → [3 critics ∥] → DEBATE GATE → [3 debate reviews ∥ if triggered] → AGGREGATE → 0.65
                                                                                                     ↓ REFLECT
        OPTIMIZE → [3 critics ∥] → DEBATE GATE → ... → AGGREGATE → 0.78
                                                                       ↓ REFLECT
        OPTIMIZE → [3 critics ∥] → (no debate: clear pass) → AGGREGATE → 0.87 ✓ → APPLY
      fallback: "If MAR unavailable → single evaluator_agent (opus, v9 behavior)"
    output: "USE phase_output_template: fields=[iterations, per_critic_scores, aggregate_progression, final_score, reflections(if >1 iter), budget]"

  phase_7_apply:
    name: "APPLY"
    effort: medium
    model: sonnet
    steps:
      # Load Order (Pattern 3) — Tier 3
      - "1. LOAD: Tier 3 — deps/artifact-quality.md"
      - "2. Apply changes from approved draft using Edit/Write"
      - "3. Verify each change applied correctly"
      # Unload (Pattern 3)
      - "4. UNLOAD: Tier 3 (artifact-quality.md)"
      # Phase Contract Output
      - "4a. Validate APPLY output against phase contract: SEE deps/phase-contracts.md"
      # Checkpoint (Pattern 1)
      - "5. CHECKPOINT: Update progress.json (APPLY: done), write checkpoints/apply.json"
    quality_checklist: ".claude/agents/meta-agent/deps/artifact-quality.md"
    output: "USE phase_output_template: fields=[modified_file, changes_applied:{N}]"

  phase_8_verify:
    name: "VERIFY"
    effort: medium
    model: "haiku (validation checks) / sonnet (main)"
    when: "ALWAYS after APPLY — check result before closing"
    steps:
      # Load Order (Pattern 3) — Tier 3
      - "1. LOAD: Tier 3 — deps/artifact-quality.md#external_validation"
      - "2. Run external validation pipeline"
      - "3. Check result matches approved plan"
      - "4. Verify size within thresholds"
      - "5. Confirm no regressions introduced"
      # Unload (Pattern 3)
      - "6. UNLOAD: Tier 3 (artifact-quality.md)"
      # Phase Contract Output
      - "6a. Validate VERIFY output against phase contract: SEE deps/phase-contracts.md"
      # Checkpoint (Pattern 1)
      - "7. CHECKPOINT: Update progress.json (VERIFY: done), write checkpoints/verify.json"
    external_validation:
      enabled: true
      checks:
        - yaml_syntax: "Parse and validate YAML"
        - references: "Verify all file/skill refs exist"
        - size: "Check against thresholds"
        - structure: "Required sections per artifact type"
        - duplicates: "Semantic similarity check"
      gate: "EXTERNAL_VALIDATION_GATE"
      blocking: true
    checks:
      - "All planned changes applied?"
      - "Size: within limits?"
      - "No broken references?"
      - "YAML valid?"
      - "External validation passed?"
    output: "USE phase_output_template: fields=[validation_table(YAML|Refs|Size|Structure), size, quality_status]"

  phase_9_close:
    name: "CLOSE"
    effort: low
    model: sonnet
    steps:
      - "1. Collect trace metrics (observability)"
      - "2. mcp__memory__add_observations (save results + trace)"
      - "3. Check for lessons_learned to save (self-improvement)"
      # Archive extraction
      - "3a. LOAD: deps/artifact-archive.md"
      - "3b. ARCHIVE: Extract reusable patterns from created/enhanced artifact"
      - "3c. Save patterns to .meta-agent/archive/ with quality_score"
      # Archive feedback
      - "3e. FEEDBACK: If patterns_used non-empty in progress.json → update success_rate"
      - "3f. FEEDBACK: SEE deps/artifact-archive.md#feedback for EMA formula"
      - "3d. UNLOAD: deps/artifact-archive.md"
      # Original steps
      - "4. If --track: bd close"
      # Progress Tracking (Pattern 1) — Final
      - "5. PROGRESS: Update progress.json (status: completed)"
      - "6. PROGRESS: Archive or keep workspace based on config"
      # Auto-Chain (Pattern 4)
      - "7. AUTO-CHAIN: Suggest /meta-agent audit if major changes"
    observability:
      save_trace: true
      save_lessons: "if CONSTITUTE found issues or VERIFY had problems"
    archive_extraction:
      ref: "SEE: deps/artifact-archive.md"
      trigger: "After successful APPLY"
      action: "Extract self-contained patterns into archive"
    auto_chain:
      ref: "SEE: deps/activation-layer.md#auto_chain"
      suggestion: "Run /meta-agent audit to verify all artifacts"
    output: "USE phase_output_template: fields=[mcp_memory, metrics(duration|reads|writes), lessons:{N}, patterns:{P}, run_id, auto_chain(if major)]"
