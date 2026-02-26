# Eval-Optimizer Loop

purpose: "Iterative quality improvement through evaluation cycles"
difference_from_step_quality: "step_quality = continuous per-phase scoring (0.0-1.0) with trajectory tracking; eval-optimizer = iterative loop until 0.85 threshold in DRAFT specifically"

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
# SEPARATED EVALUATOR
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
  # MULTI-AGENT REFLEXION (MAR)
  # ──────────────────────────────────────────────────────────────────────────
  mar_evaluation:
    purpose: "Diverse persona critics eliminate blind spots of single evaluator"
    principle: "Each critic has distinct expertise, focus, and model tier"
    paper: "MAR (2024) — persona-driven critics with diverse perspectives"
    replaces: "Single evaluator_agent"

    evaluation_team:
      - name: correctness_critic
        persona: "Senior engineer focused on correctness and edge cases"
        focus: [P1_correctness, P3_robustness, P6_domain, P7_domain]
        model: opus
        scoring_dimensions: [accuracy, completeness, domain_p6, domain_p7]
        weight: 0.40
        context_provided: ["draft artifact", "artifact constitution P1+P3", "domain principles P6+P7 for artifact_type", "adaptive weights"]
        context_NOT_provided: ["generation plan", "previous drafts", "user conversation"]
        output: "scores{accuracy, completeness, domain_p6, domain_p7} + issues[{severity, location, suggestion}]"

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

    # ──────────────────────────────────────────────────────────────────────────
    # DEBATE ROUND
    # Research: Du et al. 2023 "Multi-Agent Debate"; ChatEval (ICLR 2024)
    # ──────────────────────────────────────────────────────────────────────────
    debate:
      purpose: "Cross-critique between critics to catch blind spots and resolve disagreements"
      research:
        - "Du et al. 2023: multi-agent debate improves factual accuracy +10-15%"
        - "ChatEval (ICLR 2024): diverse role prompts essential — same roles degrade performance"
      principle: "Critics reviewing each other's findings surface issues that solo evaluation misses"

      trigger:
        condition: "score_spread > 0.15 OR aggregate_score in [0.75, 0.90]"
        score_spread: "max(critic_scores) - min(critic_scores)"
        rationale: |
          - spread > 0.15: critics significantly disagree → debate resolves conflict
          - aggregate in [0.75, 0.90]: borderline pass/fail → debate breaks tie
          - aggregate < 0.75: clearly failing, debate won't help → skip to REFLECT
          - aggregate > 0.90: clearly passing, debate overhead not justified → skip to APPLY
        skip_reason: "When outcome is unambiguous, debate adds cost without value"

      rounds: 1  # single round — diminishing returns on additional rounds (Du et al.)

      execution:
        mode: "parallel"
        note: "All 3 debate reviews run concurrently (each reviews the other two)"
        max_concurrent: 3

      per_critic_input:
        correctness_critic_debate:
          receives: ["own issues", "clarity_critic issues", "efficiency_critic issues", "draft artifact"]
          prompt_focus: "Review other critics' issues through correctness lens. Do clarity/efficiency issues mask correctness problems?"
        clarity_critic_debate:
          receives: ["own issues", "correctness_critic issues", "efficiency_critic issues", "draft artifact"]
          prompt_focus: "Review other critics' issues through clarity lens. Are correctness fixes introducing ambiguity?"
        efficiency_critic_debate:
          receives: ["own issues", "correctness_critic issues", "clarity_critic issues", "draft artifact"]
          prompt_focus: "Review other critics' issues through efficiency lens. Do proposed fixes increase bloat?"

      per_critic_output:
        actions:
          - type: "agree"
            meaning: "Confirm another critic's issue as valid"
            effect: "Issue gets +1 confirmation"
          - type: "disagree"
            meaning: "Challenge another critic's issue with reasoning"
            effect: "Issue gets -1 confirmation, reasoning logged"
          - type: "escalate"
            meaning: "Raise severity of another critic's issue"
            effect: "Issue severity += 1 level (minor→major, major→critical)"
          - type: "add"
            meaning: "New issue discovered while reviewing others' findings"
            effect: "Added to issue pool with source='debate'"
        output_schema:
          reviews: "list[{critic_name, issue_id, action, reasoning}]"
          new_issues: "list[{severity, location, description, suggestion, discovered_via}]"

      post_debate_scoring:
        confirmed_issues: "Issues agreed by 2+ critics → severity += 1 level (consensus bonus)"
        disputed_issues: "Issues with disagree + no other support → severity -= 1 level (min: minor)"
        new_debate_issues: "Added to issue pool at stated severity"
        score_adjustment: |
          post_debate_score = recalculate aggregate using adjusted issue severities
          critical_count_change: log if debate promoted issues to critical

    aggregation:
      method: "weighted_merge + domain bonus"
      base_score: "correctness_critic.score * 0.40 + clarity_critic.score * 0.35 + efficiency_critic.score * 0.25"
      domain_bonus: "(correctness_critic.domain_p6 + correctness_critic.domain_p7) / 2 * 0.10 - 0.05"
      aggregate_score: "clamp(base_score + domain_bonus, 0.0, 1.0)"
      post_debate: "If debate triggered → recalculate using debate-adjusted issues and severities (domain bonus applied after)"
      issue_merge: "Union of all issues (initial + debate-discovered + domain P6/P7), deduplicated by location"
      conflict_resolution: "If critics disagree on severity → use debate consensus; if no debate → use highest severity"
      consensus_bonus: "If 2+ critics confirm an issue (initial or debate) → severity += 1 level"

    key: "Each critic ONLY sees output + their focused principles, never the generation process. Debate adds cross-visibility of ISSUES ONLY (not scores)."

  reflector_role:
    trigger: "After MAR evaluation + optional debate, if aggregate_score < 0.85 OR after user rejection"
    implementation: "Subagent → deps/subagents.md#reflector_agent — episodic learning, reflection synthesis"
    context_provided:
      - "Draft artifact"
      - "All 3 critic evaluations (scores + issues, attributed by critic)"
      - "Debate results if triggered (consensus actions, disputed/confirmed issues, new debate issues)"
      - "Past reflections on same artifact type (from episodic memory)"
    output:
      what_failed: "Linguistic description (which critics flagged what, debate consensus)"
      why_failed: "Root cause analysis (pattern across critics, confirmed by debate)"
      how_to_fix: "Actionable steps (prioritized by debate consensus > individual critic)"
      key_insight: "One-line lesson for future"
    storage: "mcp__memory as meta-agent-reflection entity"

  updated_flow_v10: |
    GENERATE (actor)
      → EVALUATE (3 critics in parallel):
          ├── correctness_critic (opus, max_turns:3) → scores + issues
          ├── clarity_critic (sonnet, max_turns:3) → scores + issues
          └── efficiency_critic (haiku, max_turns:3) → scores + issues
      → PRE-AGGREGATE (lead computes initial scores + spread)
      → DEBATE GATE: spread > 0.15 OR score in [0.75, 0.90]?
          ↓ YES
         DEBATE (3 critics in parallel, max_turns:3 each):
          ├── correctness_critic reviews clarity + efficiency issues
          ├── clarity_critic reviews correctness + efficiency issues
          └── efficiency_critic reviews correctness + clarity issues
         → each outputs: agree/disagree/escalate/add per issue
          ↓
         POST-DEBATE SCORING (adjust severities by consensus)
          ↓ NO (skip debate)
      → AGGREGATE (lead merges scores, apply consensus adjustments)
      → aggregate_score < 0.85?
          ↓ YES
         REFLECT (reflector, opus, max_turns:5) ← all critic reports + debate results
          ↓
         OPTIMIZE (actor with reflection + debate context)
          ↓
         EVALUATE → [DEBATE if triggered] → AGGREGATE → ...
          ↓ (max 3 iterations)
         aggregate_score >= 0.85? → APPLY

  difference_from_v9:
    before: "Single evaluator_agent (opus) — one perspective, possible blind spots"
    after: "3 persona-driven critics (opus+sonnet+haiku) — diverse perspectives, MAR pattern"
    benefit: "Correctness expert catches bugs, clarity expert catches readability issues, efficiency expert catches bloat — blind spots eliminated"
    cost_note: "haiku + sonnet critics are cheaper than opus; net cost increase ~30% for 3x coverage"

  fallback:
    when: "Cannot spawn 3 critics (e.g., context budget exceeded)"
    action: "Fall back to single evaluator_agent"
    note: "Single evaluator still provides value — MAR is enhancement, not requirement"

# ════════════════════════════════════════════════════════════════════════════════
# ADAPTIVE WEIGHTS PER ARTIFACT TYPE
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
