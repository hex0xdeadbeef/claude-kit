# Self-Improvement (Reflexion Pattern)

purpose: "Learn from mistakes, improve over time without fine-tuning"
principle: "External feedback → textual reflection → episodic memory → few-shot hints"
research: "Reflexion: GPT-4 HumanEval 80% → 91% with verbal reinforcement"

## Lessons Learned

storage: "mcp__memory"
entity_type: "meta-agent-lesson"

### Capture When

triggers:
  - event: "CRITIQUE found issues"
    severity: "medium"
    capture: "always"
  - event: "VERIFY failed"
    severity: "high"
    capture: "always + detailed context"
  - event: "User rejected at CHECKPOINT"
    severity: "high"
    capture: "always + user feedback"
  - event: "Rollback was needed"
    severity: "critical"
    capture: "always + full trace"
  - event: "Gate failed unexpectedly"
    severity: "medium"
    capture: "always"
  - event: "External validation failed"
    severity: "high"
    capture: "always + validation errors"

### Lesson Format

structure:
  trigger: "Situation causing issue (e.g. 'Creating skill for API patterns')"
  context: "Environment/state (e.g. 'Existing @{skill-name} covered 60%')"
  mistake: "Wrong action (e.g. 'Created new skill instead of enhancing')"
  consequence: "Result (e.g. 'Duplicate content, user had to rollback')"
  fix: "Correct approach (e.g. 'Search existing first, enhance if >40% overlap')"
  example: {bad: "failed action/code", good: "correct approach", why: "reasoning"}
  metadata: [artifact_type, mode, severity(low|medium|high|critical), date, times_occurred]

### Save Lesson

tool: "mcp__memory__add_observations"
entity: "meta-agent-lesson-{artifact_type}-{date}"
format: |
  LESSON: {short_title}
  TRIGGER: {trigger}
  CONTEXT: {context}
  MISTAKE: {mistake}
  CONSEQUENCE: {consequence}
  FIX: {fix}
  EXAMPLE_BAD: {bad}
  EXAMPLE_GOOD: {good}
  WHY: {why}
  SEVERITY: {severity}
  OCCURRED: {times_occurred}

# ── Auto-Injection (Few-Shot Hints) ──
auto_injection:
  when: "INIT phase — before any planning"
  purpose: "Inject relevant lessons as few-shot examples"

  steps:
    1_load:
      action: "mcp__memory__read_graph"
      query: "meta-agent-lesson"
    2_filter:
      criteria:
        - "artifact_type matches current operation"
        - "mode matches (create/enhance)"
        - "severity >= medium OR times_occurred >= 2"
      max_lessons: 5
      sort_by: "severity DESC, times_occurred DESC, date DESC"
    3_format:
      output: |
        ## 📚 Relevant Lessons ({N} loaded)

        ### Lesson 1: {short_title}
        - **Trigger**: {trigger}
        - **Don't**: {mistake}
        - **Do**: {fix}
        - **Example**:
          - ❌ Bad: {bad}
          - ✅ Good: {good}

        [repeat for each lesson]
    4_inject:
      position: "After INIT, before EXPLORE/RESEARCH"
      visibility: "Show to user in INIT output"

  output: |
    ## [1/8] INIT ✓
    Artifact: .claude/<type>/<name>.md (XXX lines)

    📚 **Lessons Loaded: {N}** (from previous runs)
    [if N > 0]
    ⚠️ Watch for:
    - {lesson_1_trigger}: {lesson_1_fix_short}
    - {lesson_2_trigger}: {lesson_2_fix_short}
    [/if]

    📋 Continue? [Y/n]

# ── Decay Mechanism ──
decay_mechanism:
  purpose: "Prevent stale lessons from cluttering context"

rules:
  - condition: "lesson.date > 30 days AND times_occurred == 1"
    action: "Reduce priority, don't auto-inject"

  - condition: "lesson.date > 90 days AND times_occurred < 3"
    action: "Archive (remove from active lessons)"

  - condition: "times_occurred >= 5"
    action: "Promote to troubleshooting section"

### Promotion to Troubleshooting

trigger: "Same lesson captured ≥5 times OR severity=critical ≥2 times"
action: "Auto-suggest addition to meta-agent.md#troubleshooting"
output: |
  💡 **RECURRING ISSUE DETECTED**

  Lesson: {short_title}
  Occurrences: {times_occurred}
  Severity: {severity}

  This issue keeps happening. Add to troubleshooting section?

  Proposed entry:
  ```yaml
  - problem: "{trigger}"
    cause: "{context}"
    fix: "{fix}"
    lesson: "{why}"
  ```

  [Add to troubleshooting / Keep as lesson / Dismiss]

## Reflection Generation

when: "Error or failure occurs"
purpose: "Generate structured reflection for future use"

### Reflection Prompt

template: |
  An error occurred during meta-agent execution.

  **Context**: {phase}, {mode}, {artifact_type}
  **Error**: {error_description}
  **State**: {current_state}

  Generate a lesson in this format:
  1. What TRIGGER led to this? (situation description)
  2. What CONTEXT was important? (environment/state)
  3. What MISTAKE was made? (specific action)
  4. What CONSEQUENCE resulted? (outcome)
  5. What FIX should be applied? (correct approach)
  6. Provide BAD/GOOD/WHY example

### Auto-Reflection

enabled: true
trigger: "Any gate failure or validation error"
output_to: "CLOSE phase for user review before saving"

## Metrics

track:
  - lessons_total: "Total lessons in memory"
  - lessons_injected: "Lessons used in current run"
  - lessons_helped: "Issues prevented (same trigger, no failure)"
  - promotion_rate: "Lessons promoted to troubleshooting"

output: |
  📊 Self-Improvement Metrics:
  - Total lessons: {lessons_total}
  - Injected this run: {lessons_injected}
  - Estimated issues prevented: {lessons_helped}

# ════════════════════════════════════════════════════════════════════════════════
# EPISODIC MEMORY
# Reflexion pattern: trajectory-level learning
# ════════════════════════════════════════════════════════════════════════════════

episodic_memory:
  purpose: "Store and retrieve reflections from evaluation failures for future improvement"
  difference_from_lessons: "Lessons = single mistakes; Reflections = full evaluation trajectories"
  pattern_source: "Reflexion (Shinn et al., NeurIPS 2023) — episodic verbal reinforcement"

  entity_type: "meta-agent-reflection"
  storage: "mcp__memory"

  reflection_structure:
    reflection_id: "meta-agent-reflection-{artifact_type}-{timestamp}"
    run_id: "string (links to progress.json)"
    artifact_type: "command | skill | rule | agent"

    what_happened:
      draft_summary: "string (1-2 sentence summary of what was generated)"
      evaluation_scores: "dict {P1: float, P2: float, P3: float, P4: float, P5: float, aggregate: float}"
      issues_found: "list[{severity, location, description}]"
      iteration: "int (which eval-optimize iteration)"

    why_it_failed:
      root_cause: "string (what fundamental issue caused low scores)"
      violated_principle: "string (which P1-P5 was most impacted)"
      context: "string (what was the plan, what was attempted)"

    how_to_fix:
      steps: "list[string] (actionable steps taken or recommended)"
      rationale: "string (why these fixes address root cause)"

    key_insight: "string (one-line lesson for future, max 50 words)"

    metadata:
      created_at: "timestamp"
      artifact_type: "string"
      used_count: "int (how many times this reflection was injected as context)"
      effectiveness: "float (did subsequent artifacts score higher?)"

  save_reflection:
    tool: "mcp__memory__add_observations"
    entity: "meta-agent-reflection-{artifact_type}-{timestamp}"
    observations:
      - "type: {artifact_type}"
      - "run_id: {run_id}"
      - "what_failed: {draft_summary + issues}"
      - "why_failed: {root_cause}"
      - "how_to_fix: {steps}"
      - "key_insight: {key_insight}"

  retrieval_strategy:
    trigger: "INIT phase when preparing DRAFT context"
    query:
      - "Match: artifact_type (exact)"
      - "Sort by: recency (newest first)"
      - "Weight: used_count * 0.3 + effectiveness * 0.7"
    limit: 3
    injection: "Include top 3 reflections in DRAFT actor context as 'lessons from past evaluations'"
    format: |
      🔄 Past Reflections (episodic):
      1. [{artifact_type}] {key_insight}
         Root cause: {root_cause}
         Fix: {steps[0]}
      2. ...

  decay_for_reflections:
    stale: "60 days without being used (used_count == 0)"
    archive: "120 days AND effectiveness < 0.5"
    note: "Reflections have longer decay than lessons (more detailed, less frequent)"

  metrics:
    reflections_total: "int (all stored)"
    reflections_injected: "int (used in DRAFT context)"
    avg_effectiveness: "float (did scores improve when reflection was used?)"
    promotion_path: "Reflection with effectiveness >= 0.8 AND used_count >= 3 → promote to lesson"
