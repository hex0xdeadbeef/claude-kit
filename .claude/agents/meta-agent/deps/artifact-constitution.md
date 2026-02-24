# ════════════════════════════════════════════════════════════════════════════════
# ARTIFACT CONSTITUTION (P3.3)
# Constitutional AI pattern for artifact quality
# v9.0.0
# ════════════════════════════════════════════════════════════════════════════════

purpose: "Systematic quality evaluation via explicit constitutional principles"
principle: "Each artifact is critiqued against 5 universal + 2 domain-specific principles, not ad-hoc review"
pattern_source: "Constitutional AI (Bai et al., 2022) — principles-based self-critique"
replaces: "Ad-hoc CRITIQUE phase questions"
used_by: ["CONSTITUTE phase", "EVALUATE subagent", "PLAN ToT fast eval"]

# ════════════════════════════════════════════════════════════════════════════════
# PRINCIPLES
# ════════════════════════════════════════════════════════════════════════════════

principles:
  P1_correctness:
    weight: 0.30
    question: "Does the artifact work as intended without errors?"
    checks:
      - "YAML parses without syntax errors"
      - "All file references (@skill, deps/, paths) exist"
      - "Workflow is executable (each step has clear output)"
      - "No circular dependencies"
      - "All required sections for artifact type present"
    scoring:
      1.0: "All checks pass, no issues"
      0.8: "Minor edge case missing, non-blocking"
      0.5: "Major functionality broken or missing"
      0.0: "Fundamentally broken, unparseable"
    violation_action: "BLOCK — do not proceed to APPLY until fixed"
    examples:
      good: "All YAML valid, all refs verified via Glob/Grep"
      bad: "References @skill-foo but file doesn't exist"

  P2_clarity:
    weight: 0.25
    question: "Can a developer understand the artifact in 2 minutes?"
    checks:
      - "Structure is primarily YAML (>80% not prose)"
      - "Each major section has purpose or description"
      - "Examples for each non-trivial pattern (bad/good/why)"
      - "No ambiguous terminology without explanation"
    scoring:
      1.0: "Crystal clear, minimal explanation needed"
      0.8: "Generally clear, 1-2 minor confusion points"
      0.5: "Unclear structure or missing examples"
      0.0: "Incomprehensible structure or all prose"
    violation_action: "WARN — add comments/examples before APPLY"
    examples:
      good: "Each section has purpose:, examples with bad/good/why"
      bad: "Long prose paragraphs explaining what to do"

  P3_robustness:
    weight: 0.20
    question: "Does the artifact handle errors and edge cases?"
    checks:
      - "troubleshooting section present"
      - "common_mistakes section present"
      - "Forbidden patterns described (what NOT to do)"
      - "Fallback behaviors defined for critical operations"
    scoring:
      1.0: "Comprehensive error handling with recovery paths"
      0.8: "Most common issues covered"
      0.5: "Some robustness, significant gaps remain"
      0.0: "No error handling at all"
    violation_action: "WARN — add troubleshooting/common_mistakes before APPLY"
    examples:
      good: "troubleshooting: 5 items, common_mistakes: 4 items, forbidden: 3 items"
      bad: "No mention of what happens when things go wrong"

  P4_efficiency:
    weight: 0.15
    question: "Does the artifact use LLM context optimally?"
    checks:
      - "Size within type-specific threshold (SEE blocking-gates.md)"
      - "No semantic duplication with other artifacts"
      - "Progressive offloading applied (deps/ for large sections)"
      - "Load order tier appropriate"
    scoring:
      1.0: "Optimal size, well-structured, no duplication"
      0.8: "Slightly large but acceptable, minimal duplication"
      0.5: "Exceeds warning threshold, needs splitting"
      0.0: "Critically oversized, major duplication"
    violation_action: "WARN — apply progressive offloading or split"
    examples:
      good: "Command at 280 lines (threshold: 500 warning)"
      bad: "Skill at 750 lines with 200 lines duplicated from another skill"

  P5_maintainability:
    weight: 0.10
    question: "Can developers easily update this artifact?"
    checks:
      - "No hardcoded code examples (uses grep/glob patterns instead)"
      - "deps/ files < 500 lines each"
      - "Version and changelog present (or referenced)"
      - "Clear deprecation paths if removing features"
    scoring:
      1.0: "Easy to maintain and evolve"
      0.8: "Mostly maintainable, minor coupling"
      0.5: "Hard to modify safely, tightly coupled"
      0.0: "Brittle, high risk of breakage on any change"
    violation_action: "INFO — recommendation for improvement"
    examples:
      good: "Uses grep patterns to find code, version tracked"
      bad: "Hardcoded code snippets that break when codebase evolves"

# ════════════════════════════════════════════════════════════════════════════════
# DOMAIN-SPECIFIC PRINCIPLES P6-P7 (v9.2)
# Per artifact type — activated only when artifact_type is known
# ════════════════════════════════════════════════════════════════════════════════

domain_principles:
  purpose: "P1-P5 are universal. P6-P7 capture type-specific quality dimensions that universal checks miss."
  v9_2_change: "NEW — extends constitution from 5 to 5+2 principles per evaluation"
  activation: "When artifact_type is known (always after INIT phase)"
  weight_budget: |
    P1-P5 weights sum to 1.0 (unchanged).
    P6-P7 are BONUS principles: they adjust the aggregate UP or DOWN by max ±0.05.
    Formula: final_aggregate = base_aggregate(P1-P5) + bonus(P6, P7)
    Where bonus = (P6_score + P7_score) / 2 * 0.10 - 0.05
    Effect: perfect P6+P7 (1.0) → +0.05 bonus; zero P6+P7 (0.0) → -0.05 penalty
    This preserves backward compatibility: P1-P5 remain the core gate.

  per_type:
    command:
      P6_executability:
        question: "Can each workflow step execute without human guessing?"
        checks:
          - "Every step has explicit tool/action (Read/Write/Bash/Grep/etc.)"
          - "Inputs/outputs between steps are clear (no implicit state)"
          - "No step requires knowledge not available in prior steps or context"
          - "Terminal output format is defined"
        scoring:
          1.0: "Every step machine-executable, full I/O chain"
          0.5: "Some steps vague ('analyze', 'check') without specifying how"
          0.0: "Workflow is aspirational prose, not actionable steps"
        violation_action: "WARN — clarify vague steps with tool/action specifics"
      P7_composability:
        question: "Can this command chain with other commands/skills?"
        checks:
          - "Output format documented (what downstream consumers expect)"
          - "NEXT command suggestion present"
          - "@skill references for shared logic (not duplicated)"
          - "Exit conditions clear (success vs partial vs failure)"
        scoring:
          1.0: "Full chain: output format + NEXT + @skills + exit codes"
          0.5: "Some chaining, missing NEXT or output format"
          0.0: "Standalone island, no integration points"
        violation_action: "INFO — add NEXT suggestion and output format"

    skill:
      P6_trigger_coverage:
        question: "Do triggers cover all realistic use-cases?"
        checks:
          - "Load when: conditions cover primary + secondary scenarios"
          - "Keywords include synonyms and common misspellings"
          - "Negative triggers present (when NOT to load)"
          - "Trigger overlap with other skills documented"
        scoring:
          1.0: "All scenarios covered, negative triggers present, overlap mapped"
          0.5: "Primary scenario only, missing edge cases"
          0.0: "No triggers or keywords section"
        violation_action: "WARN — add missing trigger scenarios"
      P7_example_depth:
        question: "Does every non-trivial pattern have bad/good/why examples?"
        checks:
          - "Each trigger/if-then has at least one example"
          - "Examples use bad/good/why structure"
          - "Examples are realistic (from actual codebase, not contrived)"
          - "Forbidden section has examples of violations"
        scoring:
          1.0: "100% pattern coverage with realistic examples"
          0.5: "50-80% coverage or examples are contrived"
          0.0: "No examples or all examples trivial"
        violation_action: "WARN — add examples for uncovered patterns"

    rule:
      P6_specificity:
        question: "Is the rule precisely scoped to its target?"
        checks:
          - "paths: glob is specific (not '**/*.go' for everything)"
          - "Conditions are testable (not 'when appropriate')"
          - "Scope boundary explicit (what this rule does NOT cover)"
          - "No overlap with other rules on same paths"
        scoring:
          1.0: "Precise paths, clear scope, no overlap"
          0.5: "Paths too broad or conditions vague"
          0.0: "No paths or applies to everything indiscriminately"
        violation_action: "WARN — narrow paths and add scope boundary"
      P7_enforcement:
        question: "Can this rule be checked automatically?"
        checks:
          - "At least one check is automatable (grep, lint, parse)"
          - "Violation is detectable without human judgment"
          - "Fix suggestion is concrete (not 'improve this')"
          - "Integration with hooks/gates possible"
        scoring:
          1.0: "Fully automatable checks, hook-ready"
          0.5: "Some checks automatable, some require judgment"
          0.0: "Purely subjective, no automation path"
        violation_action: "INFO — identify automatable subset"

    agent:
      P6_autonomy_bounds:
        question: "Are stop conditions and escalation points clear?"
        checks:
          - "autonomy_rule has explicit terminal conditions"
          - "Max iterations/turns defined"
          - "Escalation to user defined (when to ask vs proceed)"
          - "Failure modes handled (timeout, error, ambiguity)"
        scoring:
          1.0: "All bounds defined, failure modes covered"
          0.5: "Stop conditions present but incomplete"
          0.0: "No autonomy_rule or unbounded execution"
        violation_action: "BLOCK — add autonomy_rule before APPLY"
      P7_observability:
        question: "Does every phase produce visible progress output?"
        checks:
          - "Each workflow phase has output format defined"
          - "Progress tracking integrated (checkpoint/progress.json)"
          - "Error states produce informative messages"
          - "Final output clearly signals success/failure"
        scoring:
          1.0: "Every phase visible, full progress tracking"
          0.5: "Some phases silent, partial progress"
          0.0: "Black box — no output until completion or failure"
        violation_action: "WARN — add output format per phase"

# ════════════════════════════════════════════════════════════════════════════════
# CRITIQUE PROTOCOL
# ════════════════════════════════════════════════════════════════════════════════

critique_protocol:
  when: "CONSTITUTE phase (formerly CRITIQUE)"
  who: "Meta-agent self-evaluation; later verified by separated evaluator in DRAFT"

  for_each_principle:
    - "Evaluate: assign score 0.0-1.0 with explicit reasoning"
    - "If < 0.7: describe specific violation from checks list"
    - "Propose concrete fix (not vague advice)"
    - "Estimate effort to fix (lines of change)"

  aggregate:
    method: |
      base = weighted_sum(P1*0.30 + P2*0.25 + P3*0.20 + P4*0.15 + P5*0.10)
      bonus = (P6_score + P7_score) / 2 * 0.10 - 0.05   # v9.2: domain bonus ±0.05
      final = clamp(base + bonus, 0.0, 1.0)
    threshold: 0.85
    on_pass: "Proceed to DRAFT"
    on_fail: "Fix issues, re-evaluate until >= 0.85 or escalate to user"
    v9_2_note: "P6-P7 bonus cannot compensate for weak P1-P5 (max +0.05)"

  output_format: |
    ## Constitution Review
    P1 Correctness (0.30): {score} {✅/⚠️/❌} — {reasoning}
    P2 Clarity (0.25): {score} {✅/⚠️/❌} — {reasoning}
    P3 Robustness (0.20): {score} {✅/⚠️/❌} — {reasoning}
    P4 Efficiency (0.15): {score} {✅/⚠️/❌} — {reasoning}
    P5 Maintainability (0.10): {score} {✅/⚠️/❌} — {reasoning}
    --- domain ({artifact_type}) ---
    P6 {name} (bonus): {score} {✅/⚠️/❌} — {reasoning}
    P7 {name} (bonus): {score} {✅/⚠️/❌} — {reasoning}

    Base: {base} | Bonus: {bonus:+0.0X} | Final: {final} (threshold: 0.85) {✅ PASS / ❌ FAIL}

    [if any < 0.7]
    Issues:
    1. [{principle}] {description}
       Fix: {concrete_fix}
       Effort: ~{lines} lines
    [/if]

# ════════════════════════════════════════════════════════════════════════════════
# FAST EVAL MODE (for Tree of Thought)
# ════════════════════════════════════════════════════════════════════════════════

fast_eval:
  when: "PLAN phase Tree of Thought — branch evaluation"
  principles_checked: ["P1_correctness only"]
  threshold: 0.5
  purpose: "Quick prune of obviously broken design approaches"
  output: "P1 Correctness: {score} → {PRUNE/KEEP}"

# ════════════════════════════════════════════════════════════════════════════════
# EVALUATOR SUBAGENT USAGE
# ════════════════════════════════════════════════════════════════════════════════

evaluator_usage:
  when: "DRAFT phase — separated evaluation (Reflexion pattern)"
  context_provided:
    - "Draft artifact (complete content)"
    - "This constitution (P1-P5 universal principles)"
    - "Domain-specific P6-P7 for artifact_type (v9.2)"
    - "Adaptive weights for artifact type (SEE: deps/eval-optimizer.md#adaptive_weights)"
  context_NOT_provided:
    - "Generation process or plan (prevents sunk cost bias)"
    - "Previous drafts (evaluates only current version)"
  output: "Same format as critique_protocol.output_format (includes P6-P7 domain section)"
  v9_2_note: "MAR critics receive P6-P7 alongside their focused P1-P5 principles"
