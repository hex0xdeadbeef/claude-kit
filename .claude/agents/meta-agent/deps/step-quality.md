# Step Quality (Process Reward Model)

purpose: "Continuous quality scoring per phase — catch degradation early via trajectory analysis"
enabled: true
version: "continuous scoring (0.0-1.0 per check, weighted average)"
research: "Lightman et al. 2023 'Let's Verify Step by Step'; AgentPRM (2025); DSPy assertions"
backward_compat: "threshold 0.5 = old 'pass', below = old 'fail'. Existing gates unchanged."

## Scoring Model

scoring:
  type: "continuous 0.0-1.0 per check"
  phase_score: "weighted average of check scores within phase"
  check_score_guide:
    0.0: "Not done / completely missing"
    0.3: "Attempted but inadequate (critical gaps)"
    0.5: "Minimum acceptable (old 'pass' threshold)"
    0.7: "Good (meets expectations)"
    0.9: "Excellent (exceeds expectations)"
    1.0: "Perfect (no improvement possible)"

thresholds:
  phase_pass: 0.5       # minimum to proceed (backward compat with old boolean)
  phase_good: 0.7       # no warnings
  phase_excellent: 0.9  # skip deeper checks in next phase (fast-track)

# ── Phase Criteria ──
phase_criteria:
  EXPLORE:
    checks:
      - name: "project_context"
        question: "PROJECT-KNOWLEDGE.md and CLAUDE.md read and summarized?"
        weight: 0.3
      - name: "artifact_loaded"
        question: "Current artifact content loaded and understood?"
        weight: 0.4
      - name: "patterns_found"
        question: "Relevant skills/patterns/conventions identified?"
        weight: 0.3
    on_low: "Repeat EXPLORE with broader search"

  RESEARCH:
    checks:
      - name: "code_examples"
        question: "Found relevant code examples from codebase?"
        weight: 0.35
        scoring_hint: "0.3 = 1 example, 0.5 = 2-3 examples, 0.7 = 4+ examples, 0.9 = examples cover all aspects"
      - name: "patterns_documented"
        question: "Identified patterns documented with context?"
        weight: 0.35
      - name: "similar_artifacts"
        question: "Similar existing artifacts checked for overlap?"
        weight: 0.3
    on_low: "Expand search scope, try different keywords"

  PLAN:
    checks:
      - name: "specificity"
        question: "All changes are specific (file, section, content)?"
        weight: 0.30
      - name: "size_estimation"
        question: "Size estimation within threshold for artifact type?"
        weight: 0.25
      - name: "no_duplication"
        question: "No duplication with existing artifacts?"
        weight: 0.25
      - name: "dependencies"
        question: "Dependencies identified and resolvable?"
        weight: 0.20
    on_low: "Revise plan with more specificity"

  CONSTITUTE:
    checks:
      - name: "principles_applied"
        question: "All P1-P5 principles evaluated against plan?"
        weight: 0.40
      - name: "issues_documented"
        question: "Issues documented with severity and location?"
        weight: 0.35
      - name: "improvements_proposed"
        question: "Actionable improvements proposed for each issue?"
        weight: 0.25
    on_low: "Cannot proceed — complete constitutional review"

  APPLY:
    checks:
      - name: "changes_applied"
        question: "All planned changes applied correctly?"
        weight: 0.40
      - name: "yaml_valid"
        question: "YAML/markdown syntax valid (lint passes)?"
        weight: 0.30
      - name: "references_intact"
        question: "No broken references (SEE:, deps/, @skill)?"
        weight: 0.30
    on_low: "Fix issues before VERIFY"

# ── Trajectory Tracking ──

trajectory:
  purpose: "Detect quality degradation across phases before hard failure"
  storage: "progress.json → quality_trajectory[]"

  structure:
    quality_trajectory:
      - phase: "string"
        score: "float 0.0-1.0"
        checks: "dict {check_name: score}"
        timestamp: "ISO datetime"

  analysis:
    declining_warning:
      trigger: "3 consecutive phases where score_N < score_{N-1}"
      action: |
        ⚠️ QUALITY TRAJECTORY DECLINING
        Scores: {phase_1}: {score_1} → {phase_2}: {score_2} → {phase_3}: {score_3}
        Trend: ↓ declining for 3 phases
        Recommend: Review approach at next checkpoint
      severity: "advisory (does not block)"

    early_termination:
      trigger: "any phase_score < 0.3 OR 2 consecutive phases < 0.5"
      action: |
        ❌ QUALITY DEGRADATION — EARLY TERMINATION
        Last acceptable phase: {phase} (score: {score})
        Failed phase: {current_phase} (score: {current_score})
        Issues: {list}
        Options: [Review approach / Ask user / Abort]
      severity: "blocking (stops execution)"

    fast_track:
      trigger: "phase_score >= 0.9"
      action: "Next phase can skip redundant re-checks of same criteria"
      example: "EXPLORE score 0.95 → RESEARCH can skip re-checking project context"

## Integration Points

blocking_gates_ref: "SEE: deps/blocking-gates.md#STEP_QUALITY_GATE"
gate_behavior: "STEP_QUALITY_GATE passes if phase_score >= 0.5 (backward compat)"

progress_tracking_ref: "SEE: deps/progress-tracking.md"
checkpoint_write: "quality_trajectory appended after each phase"

observability_ref: "SEE: deps/observability.md"
trace_event: "step_quality_score logged per phase with full check breakdown"

## Output Format

output_per_phase: |
  📊 Quality: {phase_score}/1.0 ({grade})
  Checks:
    {check_1}: {score_1} {icon}
    {check_2}: {score_2} {icon}
    ...
  Trajectory: [{phase_1}:{score_1}] → [{phase_2}:{score_2}] → [{current}:{current_score}] {trend_icon}

grade_mapping:
  "≥ 0.9": "excellent ✅✅"
  "≥ 0.7": "good ✅"
  "≥ 0.5": "acceptable ⚠️"
  "< 0.5": "failing ❌"

trend_icons:
  improving: "📈"
  stable: "➡️"
  declining: "📉"
