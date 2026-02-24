# blocking_gates

purpose: "Prevent skipping mandatory steps"
enforcement_layers:
  advisory: "This file — agent follows instructions (can be skipped)"
  deterministic: "Hooks in settings.json — guaranteed execution (cannot be skipped)"
  mapping: "SEE: meta-agent.md#hooks for advisory_vs_deterministic table"

## gates

RESEARCH_GATE:
  when: "before PLAN"
  modes: [create, enhance]
  checks_create: ["research_summary exists", "code_examples >= 3"]
  checks_enhance: ["EXPLORE completed + project_state", "gap_analysis (keep/update/add/remove)"]
  on_fail: "STOP: Cannot proceed without research"

EXPLORE_GATE:
  when: "before ANALYZE (enhance)"
  checks: ["PROJECT-KNOWLEDGE.md read", "current artifact read", "new findings documented"]
  on_fail: "STOP: Cannot enhance without exploring project first"

CRITIQUE_GATE:
  when: "after PLAN, before CHECKPOINT"
  checks: ["self-review completed", "issues addressed or documented"]
  on_fail: "STOP: Cannot ask for approval without self-critique"

CHECKPOINT_GATE:
  when: "after CRITIQUE, before APPLY"
  checks: ["user approved plan"]
  on_fail: "STOP: User approval required"

QUALITY_GATE:
  when: "after APPLY, before VERIFY"
  checks: ["artifact-quality checklist passed", "size within thresholds"]
  on_fail: "STOP: Quality check failed"

SIZE_GATE:
  enforcement: "deterministic (PreToolUse hook: check-artifact-size.sh blocks on critical)"
  thresholds: {command: [300/500/800], skill: [300/600/700], rule: [100/200/400]}
  format: "[recommended/warning/critical]"
  on_exceed: "Split — SEE: artifact-quality.md#progressive_offloading"

STEP_QUALITY_GATE:
  when: "after each phase"
  enforcement: "partially deterministic (Stop hook: verify-phase-completion.sh checks all phases ran)"
  scoring: "continuous 0.0-1.0 per check, weighted average per phase"
  checks: ["phase_score >= 0.5 (continuous scoring)", "no 2 consecutive phases < 0.5", "trajectory not declining 3+ phases (advisory)"]
  on_fail: "score < 0.5 → repeat phase or escalate. Declining trajectory → advisory warning at checkpoint."
  ref: "SEE: deps/step-quality.md for full scoring model and trajectory tracking"

EXTERNAL_VALIDATION_GATE:
  when: "VERIFY phase"
  enforcement: "partially deterministic (PostToolUse hooks: yaml-lint.sh + check-references.sh)"
  checks: ["YAML syntax valid (inline parse)", "All references exist (Glob+Grep)", "Size within thresholds", "Required sections present", "No critical duplicates (mcp__memory)"]
  deterministic_checks: ["YAML syntax (yaml-lint.sh)", "References exist (check-references.sh)"]
  advisory_checks: ["Required sections present", "No critical duplicates"]
  on_fail: "❌ Fix all errors before proceeding, acknowledge warnings to continue"

OBSERVABILITY_GATE:
  when: "CLOSE phase"
  checks: ["trace_data collected", "mcp_memory updated"]
  on_fail: "Warn but allow close (non-blocking)"

## validation_before_write

rule: "NEVER call Write tool without passing all gates"
enforcement: |
  Before ANY Write/Edit to artifact:
  1. Check: research_completed = true
  2. Check: project_explored = true (if enhance)
  3. Check: quality_checked = true
  4. Check: step_quality passed for all prior phases
  If ANY check fails → ABORT with gate error message

# ════════════════════════════════════════════════════════════════════════════════
# ADDITIONAL GATES
# ════════════════════════════════════════════════════════════════════════════════

new_gates_v9:
  CONSTITUTE_GATE:
    position: "After CONSTITUTE phase, before CHECKPOINT"
    checks:
      - "Constitutional evaluation completed (all P1-P5 scored)"
      - "Aggregate score >= 0.85"
      - "All BLOCK-level violations (P1 < 0.7) resolved"
    on_fail: "Fix violations, re-evaluate"

  EVALUATE_GATE:
    position: "After MAR EVALUATE sub-phase in DRAFT, before APPLY"
    v10: "Multi-Agent Reflexion — 3 critics replace single evaluator"
    checks:
      - "All 3 MAR critics returned scores (correctness_critic, clarity_critic, efficiency_critic)"
      - "Aggregate score >= 0.85 (weighted: 0.40/0.35/0.25)"
      - "No critical issues remaining (cross-critic consensus)"
    on_fail: "Trigger REFLECT (with all 3 critic reports) → OPTIMIZE loop"
    fallback: "If MAR unavailable → single evaluator (v9 behavior)"

# ════════════════════════════════════════════════════════════════════════════════
# GATE RECOVERY STRATEGIES
# ════════════════════════════════════════════════════════════════════════════════

recovery_strategies:
  purpose: "Graceful degradation when gates fail — no more dead ends"
  principle: "Every gate failure has: auto-recovery → fallback → user escalation"

  RESEARCH_GATE:
    condition: "Failed: insufficient code examples or patterns"
    auto_recovery:
      retry: 1
      action: "Expand search scope (broader grep patterns, adjacent domains)"
      time_limit: "5 min"
    fallback:
      action: "Proceed with minimal context (artifact template + existing artifact only)"
      quality_note: "Lower confidence, warn user"
    escalate:
      when: "Auto + fallback both insufficient"
      present: |
        Gate RESEARCH_GATE failed: Not enough context found.
        Options:
        1. Continue with template only (lower quality)
        2. Provide examples manually
        3. Abort run
      options: ["Continue with template", "Manual examples", "Abort"]

  SIZE_GATE:
    condition: "Artifact exceeds critical threshold for type"
    auto_recovery:
      action: "Progressive offloading"
      steps:
        - "Identify sections > 100 lines"
        - "Move largest section to deps/ file"
        - "Update artifact with SEE: reference"
        - "Verify references work"
      retry: 1
    fallback:
      action: "Suggest splitting into multiple artifacts"
      example: "skill-auth-basic.md + skill-auth-advanced.md"
    escalate:
      when: "Offloading + split still exceed limits"
      present: |
        Gate SIZE_GATE failed: Scope too large even after offloading.
        Current: {current_lines} lines, threshold: {critical} lines
        Options:
        1. Split into {N} separate artifacts
        2. Reduce scope (user chooses what to cut)
        3. Override threshold (proceed with warning)
      options: ["Split artifacts", "Reduce scope", "Override threshold"]

  EXTERNAL_VALIDATION_GATE:
    condition: "One or more validation checks failed"
    auto_recovery:
      per_failure_type:
        yaml_fail:
          action: "Auto-fix YAML (indentation, missing colons, quotes)"
          method: "Parse error → targeted fix → re-validate"
        ref_fail:
          action: "Search for alternative references"
          method: "Glob for similar filenames → suggest replacement"
        size_fail:
          action: "Trigger SIZE_GATE recovery"
        structure_fail:
          action: "Add missing sections from template"
          method: "Load template → identify missing → append stubs"
        duplicate_fail:
          action: "Rename sections to differentiate; suggest merge to user"
      retry: 2
    fallback:
      action: "List all failures to user with suggested fixes"
      output: |
        Validation failures:
        1. [{check}] {description}
           Suggested fix: {fix}
        2. ...
    escalate:
      when: "Auto-fixes exhausted after 2 retries"
      present: |
        Gate EXTERNAL_VALIDATION_GATE failed after auto-recovery.
        Remaining issues: {issues_list}
        Options:
        1. Apply suggested fixes manually
        2. Rollback and retry
        3. Proceed with known issues (warning)
      options: ["Manual fix", "Rollback", "Proceed with warning"]

  QUALITY_GATE:
    condition: "Score < 0.85 after eval-optimizer loop"
    auto_recovery:
      action: "Run additional REFLECT → OPTIMIZE iteration"
      retry: 1
      note: "Beyond the standard 3 iterations"
    fallback:
      action: "Lower threshold to 0.75, proceed with warning"
      warning: "⚠️ Artifact below optimal quality (score: {score}) but proceeding"
    escalate:
      when: "Score still < 0.75 after extra iteration"
      present: |
        Gate QUALITY_GATE failed: Score {score} < 0.75
        Breakdown:
        P1 Correctness: {p1}
        P2 Clarity: {p2}
        P3 Robustness: {p3}
        P4 Efficiency: {p4}
        P5 Maintainability: {p5}

        Primary weakness: {lowest_principle}
        Options:
        1. Edit plan and retry from PLAN phase
        2. Lower threshold and proceed
        3. Abort run
      options: ["Edit plan", "Lower threshold", "Abort"]

  EXPLORE_GATE:
    condition: "Insufficient exploration data"
    auto_recovery:
      retry: 1
      action: "Try alternative sources (different skills, broader grep)"
    fallback:
      action: "Proceed with available data, warn user"
    escalate:
      present: "Not enough context. [Continue anyway / Provide hints / Abort]"
      options: ["Continue", "Provide hints", "Abort"]

  CHECKPOINT_GATE:
    condition: "User said 'n' or no approval"
    auto_recovery: "None — user decision is authoritative"
    action: "Ask: 'What needs to change?'"
    options: ["Modify plan", "More exploration", "Different approach", "Abort"]

# ════════════════════════════════════════════════════════════════════════════════
# ESCALATION PROTOCOL
# ════════════════════════════════════════════════════════════════════════════════

escalation_protocol:
  max_auto_retries: 3
  per_gate_retries: "1-2 (varies by gate, see above)"
  output_format: |
    ⚠️ Gate Failed: {gate_name}
    Reason: {failure_reason}

    Auto-Recovery: {attempt_description} → {result}
    [if fallback attempted]
    Fallback: {fallback_description} → {result}
    [/if]

    Options:
    1. {option_1}
    2. {option_2}
    3. {option_3}

    📋 Choose [1/2/3]:
  logging: "All recovery attempts logged to progress.json and observability trace"
