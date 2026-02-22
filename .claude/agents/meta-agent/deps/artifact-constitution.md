# ════════════════════════════════════════════════════════════════════════════════
# ARTIFACT CONSTITUTION (P3.3)
# Constitutional AI pattern for artifact quality
# v9.0.0
# ════════════════════════════════════════════════════════════════════════════════

purpose: "Systematic quality evaluation via explicit constitutional principles"
principle: "Each artifact is critiqued against 5 formal principles, not ad-hoc review"
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
    method: "weighted_sum(P1*0.30 + P2*0.25 + P3*0.20 + P4*0.15 + P5*0.10)"
    threshold: 0.85
    on_pass: "Proceed to DRAFT"
    on_fail: "Fix issues, re-evaluate until >= 0.85 or escalate to user"

  output_format: |
    ## Constitution Review
    P1 Correctness ({weight}): {score} {✅/⚠️/❌} — {reasoning}
    P2 Clarity ({weight}): {score} {✅/⚠️/❌} — {reasoning}
    P3 Robustness ({weight}): {score} {✅/⚠️/❌} — {reasoning}
    P4 Efficiency ({weight}): {score} {✅/⚠️/❌} — {reasoning}
    P5 Maintainability ({weight}): {score} {✅/⚠️/❌} — {reasoning}

    Overall: {aggregate} (threshold: 0.85) {✅ PASS / ❌ FAIL}

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
    - "This constitution (all 5 principles)"
    - "Adaptive weights for artifact type (SEE: deps/eval-optimizer.md#adaptive_weights)"
  context_NOT_provided:
    - "Generation process or plan (prevents sunk cost bias)"
    - "Previous drafts (evaluates only current version)"
  output: "Same format as critique_protocol.output_format"
