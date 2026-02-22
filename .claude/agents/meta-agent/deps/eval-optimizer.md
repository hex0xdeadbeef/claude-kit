# Eval-Optimizer Loop

purpose: "Iterative quality improvement through evaluation cycles"
difference_from_step_quality: "step_quality = pass/fail gate; eval-optimizer = iterate until threshold"

## Loop Configuration

trigger: "After DRAFT phase, before APPLY"

config:
  max_iterations: 3
  quality_threshold: 0.85
  early_exit: "score >= threshold OR iterations >= max"

## Evaluator Role

role: "Critical reviewer (SEPARATE from creator)"
principle: "Same agent creating and evaluating tends to justify own work"

scoring:
  dimensions:
    - name: "completeness"
      weight: 0.3
      question: "All required sections present?"

    - name: "accuracy"
      weight: 0.3
      question: "Facts verified, no fabrication?"

    - name: "clarity"
      weight: 0.2
      question: "Clear structure, no ambiguity?"

    - name: "integration"
      weight: 0.2
      question: "Fits existing patterns?"

output_format:
  score: "0.0-1.0 (weighted average)"
  issues:
    - severity: "critical | major | minor"
      location: "section or line"
      problem: "what's wrong"
      suggestion: "specific fix"

## Optimizer Role

role: "Improver addressing evaluator feedback"

rules:
  - "Fix ALL critical issues (mandatory)"
  - "Fix major issues if score < 0.9"
  - "Minor issues optional"
  - "Preserve what's working"
  - "Track changes: what was fixed"

## Loop Flow

flow: |
  DRAFT ──► EVALUATE ──► score=0.65
                │
                ▼ (< 0.85)
           OPTIMIZE
                │
                ▼
           EVALUATE ──► score=0.78
                │
                ▼ (< 0.85)
           OPTIMIZE
                │
                ▼
           EVALUATE ──► score=0.87 ✓
                │
                ▼ (>= 0.85)
              APPLY

## Score History

track_format:
  eval_history:
    - iteration: 1
      score: 0.65
      issues:
        - severity: "critical"
          problem: "Missing examples section"
        - severity: "major"
          problem: "Unclear terminology"

    - iteration: 2
      score: 0.78
      issues:
        - severity: "major"
          problem: "Examples too complex"

    - iteration: 3
      score: 0.87
      issues:
        - severity: "minor"
          problem: "Could add more edge cases"
      verdict: "PASS (threshold: 0.85)"

## Integration with DRAFT Phase

enhanced_draft_phase:
  steps:
    1_draft: "Generate initial artifact content"
    2_eval: "Score against dimensions"
    3_decide: "score >= 0.85?"
    4_optimize: "If no, fix issues by severity"
    5_loop: "Back to eval (max 3)"
    6_apply: "If yes, proceed to APPLY"

## Output Format

output_per_iteration: |
  ### Eval Iteration {N}
  Score: {score} ({threshold} threshold)

  Issues:
  - ❌ [critical] {problem} → {suggestion}
  - ⚠️ [major] {problem} → {suggestion}
  - 💡 [minor] {problem}

  Verdict: {PASS/CONTINUE}

final_output: |
  ## Eval-Optimizer Summary
  Iterations: {N}
  Score progression: [0.65, 0.78, 0.87]
  Final: PASS ✅

# ════════════════════════════════════════════════════════════════════════════════
# SEPARATED EVALUATOR (v9.0 — P3.5)
# Reflexion pattern: evaluator as separate subagent
# ════════════════════════════════════════════════════════════════════════════════

separated_evaluator:
  purpose: "Objective evaluation without generator's sunk cost bias"
  principle: "Intrinsic self-correction often fails (Huang et al., 2023). External evaluation required."
  pattern_source: "Reflexion (Shinn et al., NeurIPS 2023)"
  v10_upgrade: "Multi-Agent Reflexion (MAR) — diverse persona critics replace single evaluator"
  mar_source: "https://arxiv.org/html/2512.20845"

  architecture:
    actor: "Generator (DRAFT phase) — creates artifact"
    evaluator: "v9: single evaluator_agent → v10: 3 persona-driven critics (MAR)"
    reflector: "Subagent (REFLECT sub-phase) — synthesizes all critic feedback"

  # ──────────────────────────────────────────────────────────────────────────
  # MULTI-AGENT REFLEXION (v10.0 — MAR)
  # ──────────────────────────────────────────────────────────────────────────
  mar_evaluation:
    purpose: "Diverse persona critics eliminate blind spots of single evaluator"
    principle: "Each critic has distinct expertise, focus, and model tier"
    paper: "MAR (2024) — persona-driven critics with diverse perspectives"
    replaces: "Single evaluator_agent (v9.0)"

    evaluation_team:
      - name: correctness_critic
        persona: "Senior engineer focused on correctness and edge cases"
        focus: [P1_correctness, P3_robustness]
        model: opus
        scoring_dimensions: [accuracy, completeness]
        weight: 0.40
        context_provided: ["draft artifact", "artifact constitution P1+P3", "adaptive weights"]
        context_NOT_provided: ["generation plan", "previous drafts", "user conversation"]
        output: "scores{accuracy, completeness} + issues[{severity, location, suggestion}]"

      - name: clarity_critic
        persona: "Technical writer focused on readability and structure"
        focus: [P2_clarity, P5_maintainability]
        model: sonnet
        scoring_dimensions: [clarity, integration]
        weight: 0.35
        context_provided: ["draft artifact", "artifact constitution P2+P5", "existing artifacts for style"]
        context_NOT_provided: ["generation plan", "previous drafts"]
        output: "scores{clarity, integration} + issues[{severity, location, suggestion}]"

      - name: efficiency_critic
        persona: "Performance engineer focused on size and duplication"
        focus: [P4_efficiency, token_density]
        model: haiku
        scoring_dimensions: [token_efficiency, duplication_score]
        weight: 0.25
        context_provided: ["draft artifact", "SIZE_GATE thresholds", "existing similar artifacts"]
        context_NOT_provided: ["generation plan", "previous drafts"]
        output: "scores{efficiency, duplication} + issues[{severity, location, suggestion}]"

    execution:
      mode: "parallel"
      note: "All 3 critics run concurrently (no dependencies between them)"
      max_concurrent: 3
      isolation: "Each critic has own context — no cross-contamination"

    aggregation:
      method: "weighted_merge"
      aggregate_score: "correctness_critic.score * 0.40 + clarity_critic.score * 0.35 + efficiency_critic.score * 0.25"
      issue_merge: "Union of all issues, deduplicated by location"
      conflict_resolution: "If critics disagree on severity → use highest severity"
      consensus_bonus: "If all 3 agree on an issue → severity += 1 level"

    key: "Each critic ONLY sees output + their focused principles, never the generation process"

  reflector_role:
    trigger: "After MAR evaluation if aggregate_score < 0.85 OR after user rejection"
    implementation: "Subagent (SEE: deps/subagents.md#reflector_agent)"
    v10_change: "Reflector now receives merged feedback from 3 critics instead of 1"
    context_provided:
      - "Draft artifact"
      - "All 3 critic evaluations (scores + issues, attributed by critic)"
      - "Past reflections on same artifact type (from episodic memory)"
    output:
      what_failed: "Linguistic description (which critics flagged what)"
      why_failed: "Root cause analysis (pattern across critics)"
      how_to_fix: "Actionable steps (prioritized by cross-critic consensus)"
      key_insight: "One-line lesson for future"
    storage: "mcp__memory as meta-agent-reflection entity"

  updated_flow_v10: |
    GENERATE (actor)
      → EVALUATE (3 critics in parallel):
          ├── correctness_critic (opus) → scores + issues
          ├── clarity_critic (sonnet) → scores + issues
          └── efficiency_critic (haiku) → scores + issues
      → AGGREGATE (lead merges scores, dedup issues)
      → aggregate_score < 0.85?
          ↓ YES
         REFLECT (reflector, opus) ← all 3 critic reports
          ↓
         OPTIMIZE (actor with reflection context)
          ↓
         EVALUATE (3 critics again, parallel) → ...
          ↓ (max 3 iterations)
         aggregate_score >= 0.85? → APPLY

  difference_from_v9:
    before: "Single evaluator_agent (opus) — one perspective, possible blind spots"
    after: "3 persona-driven critics (opus+sonnet+haiku) — diverse perspectives, MAR pattern"
    benefit: "Correctness expert catches bugs, clarity expert catches readability issues, efficiency expert catches bloat — blind spots eliminated"
    cost_note: "haiku + sonnet critics are cheaper than opus; net cost increase ~30% for 3x coverage"

  fallback:
    when: "Cannot spawn 3 critics (e.g., context budget exceeded)"
    action: "Fall back to single evaluator_agent (v9.0 behavior)"
    note: "Single evaluator still provides value — MAR is enhancement, not requirement"

# ════════════════════════════════════════════════════════════════════════════════
# ADAPTIVE WEIGHTS PER ARTIFACT TYPE (v9.0 — P3.6)
# ════════════════════════════════════════════════════════════════════════════════

adaptive_weights:
  purpose: "Different artifact types need different quality emphasis"
  principle: "One-size-fits-all weights miss type-specific priorities"

  per_artifact_type:
    command:
      completeness: 0.25
      accuracy: 0.25
      clarity: 0.30
      integration: 0.20
      rationale: "Commands must be immediately clear to use (clarity highest)"

    skill:
      completeness: 0.35
      accuracy: 0.25
      clarity: 0.25
      integration: 0.15
      rationale: "Skills must cover all use cases (completeness highest)"

    rule:
      completeness: 0.20
      accuracy: 0.40
      clarity: 0.20
      integration: 0.20
      rationale: "Wrong rules cause harm (accuracy highest)"

    agent:
      completeness: 0.30
      accuracy: 0.25
      clarity: 0.20
      integration: 0.25
      rationale: "Agents depend on ecosystem (integration elevated)"

  default_weights:
    note: "Used when artifact_type unknown or for general evaluation"
    completeness: 0.30
    accuracy: 0.30
    clarity: 0.20
    integration: 0.20

  learning_mechanism:
    trigger: "User rejects artifact at CHECKPOINT"
    process:
      - "Ask user: 'What aspect wasn't working?'"
      - "Map response to dimension:"
      - "  'Not clear how to use' → increase clarity"
      - "  'Missing features' → increase completeness"
      - "  'Had bugs/errors' → increase accuracy"
      - "  'Doesn't work with other tools' → increase integration"
    update_rule: |
      selected_dimension += 0.05
      other_dimensions -= 0.05/3
      bounds: min 0.10, max 0.50 per dimension
    persistence: "Store in mcp__memory as adaptive-weights-{artifact_type}"
    decay: "Reset to defaults after 30 days without reinforcement"
