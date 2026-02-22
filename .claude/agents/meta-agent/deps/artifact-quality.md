# artifact-quality — Quality Criteria for Claude Code Artifacts (YAML-first)

meta:
  name: artifact-quality
  description: |
    Quality criteria for Claude Code artifacts (commands, skills, rules, agents).
    YAML-first approach for maximum LLM parsing efficiency.

    Load when:
    - Auditing .claude/ infrastructure
    - Creating commands, skills, rules, agents
    - Reviewing artifact quality
    - Keywords: quality, audit, review

ai_first_principles:
  core_rule: "All files are for LLM, not for humans"

  format_priority:
    - format: "pure YAML"
      when: "configuration, rules, structured data"
      why: "maximum structure, no ambiguity"

    - format: "YAML frontmatter + minimal markdown"
      when: "need code examples in file body"
      why: "structure + code blocks"

    - format: "AVOID pure markdown prose"
      when: "never"
      why: "ambiguous, poorly parsed by LLM"

  structure_rules:
    - rule: "triggers with if/then"
      example: |
        triggers:
          - if: "condition"
            then: "action"

    - rule: "examples with bad/good/why"
      example: |
        examples:
          pattern_name:
            bad: "wrong code"
            good: "correct code"
            why: "explanation"

    - rule: "forbidden with action/why"
      example: |
        forbidden:
          - action: "what not to do"
            why: "reason"

  metrics:
    yaml_structure: "> 80% content in YAML structure"
    prose_max: "< 10% prose text"
    code_examples: "always bad/good pairs"
    triggers: "explicit if/then patterns"

  size_effectiveness:
    principle: "Smaller is better IF quality preserved"
    critical_insight: |
      Size alone is NOT the metric.
      EFFECTIVENESS = Quality / Size
      High-value sections (examples, lessons_learned) should NEVER be removed.
      Low-value duplication SHOULD be removed.

    baselines:
      command:
        median: "~300 lines / ~12k bytes"
        warning: "> 500 lines OR > 20k bytes"
        critical: "> 800 lines OR > 35k bytes"
      skill:
        median: "~450 lines / ~13k bytes"
        warning: "> 600 lines OR > 18k bytes"
        critical: "> 700 lines OR > 25k bytes"
      rule:
        median: "~100 lines / ~4k bytes"
        warning: "> 200 lines OR > 8k bytes"
        critical: "> 400 lines OR > 15k bytes"

    token_budget:
      single_artifact: "< 10k tokens"
      with_claude_md: "< 15k tokens total"
      why: "Artifacts load together, total context matters"
      formula: "tokens ≈ bytes / 4 (for YAML/code)"

    high_value_sections:
      preserve_always:
        - section: "examples (bad/good/why)"
          why: "Teaches LLM correct patterns"
        - section: "lessons_learned"
          why: "Real project experience, prevents repeated mistakes"
        - section: "forbidden"
          why: "Critical guardrails"
      can_optimize:
        - section: "decision_trees"
          how: "Reference @skill for details, keep unique logic"
        - section: "skills_by_layer"
          how: "Reference CLAUDE.md triggers, avoid duplication"
        - section: "mcp_by_phase"
          how: "Inline into phases, remove separate section"

progressive_offloading:
  purpose: "Split large artifacts to reduce base context load"
  when: "artifact exceeds WARNING threshold"
  principle: "Core file stays small, details loaded on demand via Read"

  skill_pattern:
    structure:
      - file: "SKILL.md"
        max_lines: 100
        contains: ["meta with triggers", "core rules", "references to other files"]
      - file: "reference.md"
        max_lines: 300
        purpose: "detailed docs, helpers — loaded via Read on demand"
      - file: "examples.md"
        max_lines: 200
        purpose: "code examples bad/good/why — loaded via Read on demand"
      - file: "scripts/"
        purpose: "EXECUTED by Bash, NOT loaded into context"
        examples: ["validate.sh", "check-style.py"]

    reference_syntax_in_skill: |
      details:
        helpers: "Read reference.md#helpers for patterns"
        code_examples: "Read examples.md for bad/good patterns"

    example_before: |
      my-skill/
      └── SKILL.md (700 lines) ← exceeds critical

    example_after: |
      my-skill/
      ├── SKILL.md (100 lines)     # triggers, core rules, references
      ├── reference.md (300 lines) # detailed helpers
      ├── examples.md (200 lines)  # bad/good code patterns
      └── scripts/
          └── validate.sh          # executed, not loaded

  command_pattern:
    structure:
      - file: "commands/<name>.md"
        max_lines: 300
        contains: ["workflow", "output", "references to deps/"]
      - file: "agents/<name>/deps/"
        purpose: "patterns, checklists, templates — loaded via Read"

    reference_syntax_in_command: |
      references:
        patterns: ".claude/agents/<name>/deps/patterns.md"
        checklist: ".claude/agents/<name>/deps/checklist.md"

    example_before: |
      commands/
      └── my-command.md (1000 lines) ← exceeds critical

    example_after: |
      commands/
      └── my-command.md (300 lines)  # workflow, references

      agents/my-command/
      └── deps/
          ├── patterns.md (400 lines)   # detection patterns
          └── checklist.md (200 lines)  # validation checklist

  key_distinction:
    reference_md: "Loaded into context via Read tool when needed"
    scripts: "EXECUTED via Bash, output returned, file NOT in context"

    duplication_detection:
      check_against:
        - "CLAUDE.md triggers section"
        - "Related @skills"
        - "Other artifacts in same domain"
      threshold: "< 10% overlap acceptable"
      action_on_duplication: |
        1. Identify duplicated content
        2. Keep in PRIMARY location (usually CLAUDE.md or specific skill)
        3. Replace in artifact with reference: "see @skill-name" or "see CLAUDE.md"
        4. Verify reference is clear and findable

artifact_quality:
  command:
    required:
      - field: "description"
        in: "YAML frontmatter"
      - field: "workflow"
        format: "numbered steps"
      - field: "output"
        format: "expected result"

    recommended:
      - "examples with arguments"
      - "NEXT command reference"
      - "@skill references"

    template: |
      ---
      description: What this command does
      ---

      workflow:
        - step: 1
          action: "do X"
        - step: 2
          action: "do Y"

      output:
        format: "description"
        example: "sample output"

  skill:
    required:
      - field: "name"
        in: "YAML frontmatter"
      - field: "description with triggers"
        format: "Load when: conditions, Keywords: ..."
      - field: "examples"
        format: "bad/good/why structure"

    recommended:
      - "< 600 lines (warning threshold)"
      - "triggers section"
      - "forbidden section"

    template: |
      meta:
        name: skill-name
        description: |
          Purpose of skill.
          Load when: condition1, condition2
          Keywords: keyword1, keyword2

      triggers:
        - if: "condition"
          then: "action"

      examples:
        pattern:
          bad: "wrong"
          good: "correct"
          why: "reason"

      forbidden:
        - action: "what not to do"
          why: "reason"

  rule:
    required:
      - field: "paths"
        in: "YAML frontmatter"
        format: "glob pattern"

    recommended:
      - "@skill references"
      - "quick checklist (3-7 items)"

    template: |
      ---
      paths: internal/{layer}/**/*.go
      ---

      skills: ["@{skill-1}", "@{skill-2}"]

      checklist:
        - check: "item 1"
        - check: "item 2"

    layer_paths:
      note: "Project-specific — configure in CLAUDE.md"
      pattern: "internal/{layer}/**/*.go"

  agent:
    required:
      - field: "name, description, tools"
        in: "YAML frontmatter"
      - field: "autonomy_rule"
        format: "when to stop"
      - field: "input/output"
        format: "expected formats"
      - field: "workflow"
        format: "phases"

    recommended:
      - "error handling"
      - "progress tracking"

    template: |
      ---
      name: agent-name
      description: What agent does
      tools: [Read, Write, Bash]
      ---

      autonomy_rule: "Run until: condition"

      input:
        format: "expected arguments"

      output:
        format: "what agent produces"

      workflow:
        - phase: 1
          name: "Phase Name"
          steps: ["step1", "step2"]

      errors:
        fatal: ["condition1"]
        recoverable: ["condition2"]

rating_scale:
  - rating: "5/5 Excellent"
    criteria: "All REQUIRED + all RECOMMENDED + YAML-first"

  - rating: "4/5 Good"
    criteria: "All REQUIRED + 50% RECOMMENDED"

  - rating: "3/5 Acceptable"
    criteria: "All REQUIRED"

  - rating: "2/5 Needs Work"
    criteria: "Missing 1-2 REQUIRED"

  - rating: "1/5 Poor"
    criteria: "Missing 3+ REQUIRED or prose-heavy"

audit_format:
  template: |
    artifact_audit:
      name: "[artifact name]"
      type: "command | skill | rule | agent"
      file: ".claude/[path]"
      rating: "[1-5]/5"

      checklist:
        - item: "YAML frontmatter"
          status: "pass | fail"
        - item: "triggers/if-then"
          status: "pass | fail"
        - item: "examples bad/good"
          status: "pass | fail"

      issues:
        - issue: "description"
          severity: "HIGH | MEDIUM | LOW"
          fix: "how to fix"

      recommendations:
        - "recommendation 1"
        - "recommendation 2"

common_issues:
  all_types:
    - issue: "Prose-heavy (> 20%)"
      severity: "HIGH"
      fix: "Convert to YAML structure with triggers/examples"

    - issue: "No bad/good examples"
      severity: "MEDIUM"
      fix: "Add examples section with bad/good/why"

    - issue: "Markdown headers instead of YAML keys"
      severity: "MEDIUM"
      fix: "Use YAML structure, not ## headers"

    - issue: "Artifact too large (> critical threshold)"
      severity: "HIGH"
      fix: |
        1. Run baseline comparison: wc -l .claude/{type}s/*.md | sort -n
        2. Identify duplication with CLAUDE.md/skills
        3. Remove duplicated sections, add references
        4. Keep examples and lessons_learned (high-value)
        5. Consider splitting if > 800 lines

    - issue: "Duplication with CLAUDE.md triggers"
      severity: "MEDIUM"
      fix: "Replace duplicated triggers with: 'see CLAUDE.md triggers section'"

    - issue: "Duplication with related skills"
      severity: "MEDIUM"
      fix: "Replace duplicated patterns with: 'see @skill-name for details'"

    - issue: "Removed high-value sections (examples, lessons_learned)"
      severity: "CRITICAL"
      fix: "RESTORE immediately — these sections teach LLM correct patterns"

    - issue: "Added content without measuring impact"
      severity: "MEDIUM"
      fix: "Always measure before/after: wc -l && wc -c"

  commands:
    - issue: "No description"
      severity: "HIGH"
      fix: "Add YAML frontmatter with description:"

  skills:
    - issue: "No trigger keywords"
      severity: "HIGH"
      fix: "Add 'Load when:' and 'Keywords:' to description"

    - issue: "Too long (> 600 lines)"
      severity: "HIGH"
      fix: "Split into focused sub-skills or use progressive_offloading"

  rules:
    - issue: "No paths"
      severity: "HIGH"
      fix: "Add paths: glob in frontmatter"

  agents:
    - issue: "No autonomy rule"
      severity: "HIGH"
      fix: "Add autonomy_rule: when to stop"

integration_checklist:
  - "Added to CLAUDE.md (appropriate section)"
  - "Cross-references (@skill links from related artifacts)"
  - "settings.json (if tools/permissions needed)"
  - "Tested (invoke and verify)"
  - "beads: bd create → bd close → bd sync"

# ════════════════════════════════════════════════════════════════════════════════
# EXTERNAL VALIDATION (merged from external-validation.md)
# When: VERIFY phase, after APPLY | Gate: EXTERNAL_VALIDATION_GATE (blocking)
# Principle: Intrinsic self-correction often fails — external feedback required
# ════════════════════════════════════════════════════════════════════════════════
external_validation:
  pipeline:
    yaml_validation:
      checks: ["valid YAML syntax", "frontmatter present with required fields", "spaces only (no tabs)", "consistent 2-space indent"]
      tool: "inline parse"
      on_fail: "❌ YAML VALIDATION FAILED — fix syntax before proceeding"

    reference_validation:
      checks: ["all .claude/**/*.md paths exist (Glob)", "@skill refs point to real skills (Grep)", "SEE: deps/ paths exist", "no broken internal links"]
      on_fail: "❌ BROKEN REFERENCES — list broken refs, suggest fixes"

    size_validation:
      thresholds: "SEE: size_effectiveness.baselines above"
      token_estimate: "lines * 10 (rough)"
      on_warning: "⚠️ Consider split into deps/ (progressive loading)"
      on_critical: "❌ MUST split before proceeding → SEE: progressive_offloading"

    structure_validation:
      command: {required: ["description in frontmatter", "workflow section", "output section"]}
      skill: {required: ["name+description in frontmatter", "trigger keywords"], max: 700}
      rule: {required: ["paths in frontmatter", "patterns section"]}
      agent: {required: ["name+description+tools in frontmatter", "autonomy rule", "workflow section"]}
      on_fail: "❌ STRUCTURE FAILED — list missing sections, reference template"

    duplicate_detection:
      method: ["Extract key terms", "Search mcp__memory for similar", "Grep .claude/ for patterns"]
      threshold: "70% term overlap = potential duplicate"
      on_found: "⚠️ POTENTIAL DUPLICATE — suggest merge or differentiate"

  summary_format: |
    | Check | Status | Details |
    |-------|--------|---------|
    | YAML Syntax | ✅/❌ | {details} |
    | References | ✅/❌ | {broken_count} broken |
    | Size | ✅/⚠️/❌ | {lines} lines |
    | Structure | ✅/❌ | {missing} |
    | Duplicates | ✅/⚠️ | {similar_count} |
    Overall: {PASSED/FAILED}
