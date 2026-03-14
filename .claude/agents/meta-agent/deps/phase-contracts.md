# ════════════════════════════════════════════════════════════════════════════════
# TYPED PHASE CONTRACTS
# Structured inter-phase communication — MetaGPT pattern
# ════════════════════════════════════════════════════════════════════════════════

purpose: "Eliminate information loss between phases via typed contracts"
principle: "Each phase produces structured output validated before next phase starts"
pattern_source: "MetaGPT (Hong et al., 2023) — structured intermediate outputs"

# ════════════════════════════════════════════════════════════════════════════════
# CONTRACTS
# ════════════════════════════════════════════════════════════════════════════════

contracts:
  INIT_to_EXPLORE:
    description: "Context loaded, ready for exploration"
    fields:
      artifact_path: { type: "string", example: ".claude/commands/workflow.md" }
      artifact_content: { type: "string", note: "Full file content loaded" }
      artifact_lines: { type: "int", example: 350 }
      lessons: { type: "list[Lesson]", note: "Auto-injected from self-improvement" }
      reflections: { type: "list[Reflection]", note: "Episodic memory (max 3)" }
      run_id: { type: "string", example: "20260208-143052-enhance-command-workflow" }
      workspace_path: { type: "string", example: ".meta-agent/runs/{run_id}/" }
      budget_state: { type: "BudgetState", note: "loaded_files, total_lines, remaining" }
    validation: "artifact_path exists AND artifact_content not empty AND run_id set"

  # CREATE mode contracts
  INIT_to_RESEARCH:
    description: "Context loaded, ready for codebase research (CREATE mode)"
    mode: create
    fields:
      artifact_type: { type: "string", note: "command | skill | rule | agent" }
      artifact_name: { type: "string", example: "auth-middleware" }
      research_scope: { type: "list[string]", note: "Directories/patterns to research" }
      template_path: { type: "string", example: ".claude/templates/skill.md" }
      run_id: { type: "string" }
      workspace_path: { type: "string" }
      budget_state: { type: "BudgetState" }
    validation: "artifact_type is valid AND artifact_name not empty AND run_id set"

  RESEARCH_to_TEMPLATE:
    description: "Research complete, ready for template loading (CREATE mode)"
    mode: create
    fields:
      research_summary: { type: "string", note: "Key patterns and examples found" }
      code_examples: { type: "list[CodeExample]", note: "Minimum 3 relevant examples" }
      template_path: { type: "string", note: "Selected template for artifact type" }
      existing_similar: { type: "list[string]", note: "Similar existing artifacts found" }
    validation: "code_examples length >= 3 AND template_path exists"

  TEMPLATE_to_PLAN:
    description: "Template loaded, ready for planning (CREATE mode)"
    mode: create
    fields:
      template_content: { type: "string", note: "Full template content loaded" }
      customizations: { type: "list[Customization]", note: "Template sections to customize" }
      research_alignment: { type: "float", note: "0.0-1.0 — how well research maps to template" }
    validation: "template_content not empty AND customizations is list"

  EXPLORE_to_ANALYZE:
    description: "Knowledge gathered, ready for gap analysis"
    fields:
      sources_read: { type: "list[string]", example: ["PROJECT-KNOWLEDGE.md", "CLAUDE.md"] }
      new_findings: { type: "list[Finding]", note: "Each: {description, impact, location}" }
      relevant_artifacts: { type: "list[string]", example: ["@command-workflow", "@agent-code-searcher"] }
      project_patterns: { type: "dict", note: "Key patterns found in codebase" }
      lessons_loaded: { type: "int", example: 3 }
    validation: "sources_read not empty AND new_findings is list"

  ANALYZE_to_PLAN:
    description: "Gaps identified, ready for planning"
    fields:
      gaps: { type: "list[Gap]", note: "Each: {description, priority (P0-P3), estimated_lines}" }
      existing_strengths: { type: "list[string]", note: "What already works well" }
      checklist_results: { type: "dict", note: "{item: pass/fail/na}" }
    validation: "gaps is list AND checklist_results is dict"

  PLAN_to_CONSTITUTE:
    description: "Plan defined, ready for constitutional review"
    fields:
      changes: { type: "list[Change]", note: "Each: {description, location, preview, size_delta}" }
      size_impact: { type: "SizeImpact", note: "{before, after, delta, threshold_status}" }
      research_alignment: { type: "float", note: "0.0-1.0 — how well plan matches findings" }
      tot_applied: { type: "bool", note: "Whether Tree of Thought was used" }
      tot_alternatives: { type: "list[Alternative]", note: "If ToT: rejected alternatives with scores" }
      success_criteria: { type: "SuccessCriteria | null", note: "Skill-type only: {quantitative: {trigger_rate, workflow_efficiency, error_rate}, qualitative: {autonomy, consistency, learnability}, test_queries: {should_trigger, should_not_trigger}}" }
    validation: "changes not empty AND size_impact.threshold_status in [ok, warning, critical]"

  CONSTITUTE_to_DRAFT:
    description: "Plan constitutionally approved, ready for drafting"
    fields:
      approved_changes: { type: "list[Change]", note: "Changes that passed constitutional review" }
      constitution_scores: { type: "dict", note: "{P1: float, P2: float, ..., P5: float, aggregate: float}" }
      issues_addressed: { type: "list[Issue]", note: "Constitutional issues fixed during CONSTITUTE" }
      improvements_applied: { type: "list[string]", note: "Improvements from constitutional critique" }
    validation: "constitution_scores.aggregate >= 0.85 AND approved_changes not empty"

  DRAFT_to_APPLY:
    description: "Draft evaluated and approved, ready for application"
    fields:
      draft_content: { type: "string", note: "Final artifact content after eval-reflect loop" }
      eval_history: { type: "list[EvalResult]", note: "Each: {iteration, scores, issues, verdict}" }
      final_score: { type: "float", note: ">= 0.85" }
      reflections_captured: { type: "int", note: "Number of reflections stored in episodic memory" }
      eval_iterations: { type: "int", note: "1-3" }
    validation: "final_score >= 0.85 AND draft_content not empty"

  APPLY_to_VERIFY:
    description: "Changes applied, ready for external validation"
    fields:
      applied_changes: { type: "list[AppliedChange]", note: "Each: {location, what_changed, success}" }
      file_path: { type: "string", note: "Modified artifact file path" }
      changes_count: { type: "int" }
      all_applied: { type: "bool" }
    validation: "all_applied == true AND file_path exists"

  VERIFY_to_CLOSE:
    description: "Artifact validated, ready for closing"
    fields:
      validation_results: { type: "dict", note: "{yaml_syntax, references, size, structure, duplicates}" }
      all_passed: { type: "bool" }
      size_check: { type: "SizeCheck", note: "{current_lines, threshold, status}" }
      regressions_found: { type: "bool" }
    validation: "all_passed == true AND regressions_found == false"

# ════════════════════════════════════════════════════════════════════════════════
# VALIDATION PROTOCOL
# ════════════════════════════════════════════════════════════════════════════════

validation_protocol:
  when: "After each phase output, before starting next phase"
  how: "Check all validation conditions in contract"
  on_fail:
    - "Log: 'Contract validation failed: {phase} → {field}: {reason}'"
    - "Attempt auto-fix if possible (fill missing fields)"
    - "If unfixable: escalate to gate recovery → deps/blocking-gates.md#recovery_strategies"
  output: |
    📝 Contract: {phase_from} → {phase_to}: {VALID/INVALID}
    [if INVALID]
    Missing: {field} — {reason}
    [/if]

# ════════════════════════════════════════════════════════════════════════════════
# TYPE DEFINITIONS
# ════════════════════════════════════════════════════════════════════════════════

type_definitions:
  Finding: { description: "string", impact: "high|medium|low", location: "string" }
  Gap: { description: "string", priority: "P0|P1|P2|P3", estimated_lines: "int" }
  Change: { description: "string", location: "string (section or line range)", preview: "string (first 2 lines)", size_delta: "int (+/-)" }
  SizeImpact: { before: "int", after: "int", delta: "int", threshold_status: "ok|warning|critical" }
  Issue: { severity: "critical|major|minor", location: "string", description: "string", suggestion: "string" }
  EvalResult: { iteration: "int", scores: "dict", issues: "list[Issue]", verdict: "pass|fail" }
  AppliedChange: { location: "string", what_changed: "string", success: "bool" }
  SizeCheck: { current_lines: "int", threshold: "int", status: "ok|warning|critical" }
  BudgetState: { loaded_files: "list[{path, lines, tier}]", total_lines: "int", remaining: "int" }
  Lesson: { trigger: "string", fix: "string", severity: "string" }
  Reflection: { key_insight: "string", score_before: "float", score_after: "float" }
  Alternative: { name: "string", score: "float", reason_rejected: "string" }
  CodeExample: { source_file: "string", pattern: "string", relevance: "high|medium|low" }
  Customization: { section: "string", description: "string", source: "research|user|template" }
  SuccessCriteria: { quantitative: "{ trigger_rate: string, workflow_efficiency: string, error_rate: string }", qualitative: "{ autonomy: string, consistency: string, learnability: string }", test_queries: "{ should_trigger: list[string], should_not_trigger: list[string] }" }
