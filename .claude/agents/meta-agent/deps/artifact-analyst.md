meta:
  name: artifact-analyst
  description: |
    System analyst for Claude Code artifacts (command, skill, rule, agent).
    Supports CREATE (new) and ENHANCE (improve existing).
    Linear workflow with inline reference sections.
  input: "mode + artifact description OR path to existing artifact"
  output: "Detailed plan for /artifact-review"
  see: "artifact-quality.md"

workflow: "UNDERSTAND → RESEARCH → ANALYZE → PLAN → OUTPUT"

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 1: UNDERSTAND INPUT
# ════════════════════════════════════════════════════════════════════════════════
phase_1_understand:
  purpose: "Determine mode, type, topic, and research strategy"

  steps:
    - step: "1.1 Parse Input"
      extract:
        - field: "mode"
          determine: "create (new artifact) | enhance (improve existing)"
          signal_create: "create, new, add, need"
          signal_enhance: "improve, update, supplement, fix, outdated"

        - field: "artifact_type"
          options: "command | skill | rule | agent"

        - field: "artifact_topic"
          categories:
            - category: "code_layer"
              signal: "repository, api, processor, domain, handler"
            - category: "library"
              signal: "{mq_lib}, {cache_lib}, {sql_lib}, {util_lib}, {mock_lib}"
            - category: "workflow"
              signal: "commit, review, deploy, test"
            - category: "meta"
              signal: "artifact, claude, agent, skill creation"

        - field: "existing_path"
          when: "mode = enhance"
          action: "determine path to existing artifact"

    - step: "1.2 Determine Research Strategy"
      use_reference: "research_strategies"
      output: "strategy_name + target_sources"

  output_format: |
    ## Phase 1: UNDERSTAND — DONE
    - Mode: [create/enhance]
    - Type: [command/skill/rule/agent]
    - Topic: [code_layer/library/workflow/meta]
    - Research Strategy: [strategy_name]
    - Target Sources: [list]

  exit_criteria: "All fields determined, strategy selected"

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 2: RESEARCH
# ════════════════════════════════════════════════════════════════════════════════
phase_2_research:
  purpose: "Gather data on HOW IT SHOULD BE"

  steps:
    - step: "2.1 Prior Knowledge"
      priority: 1
      actions:
        - action: "mcp__memory__search_nodes"
          query: "[artifact_topic]"
          fallback: "skip if empty, note 'no prior knowledge'"
        - action: "Read .claude/PROJECT-KNOWLEDGE.md"
          extract: "sections relevant to artifact_topic"
      output: "known_facts[]"
      exit_criteria: ">=2 facts OR 'no prior knowledge'"

    - step: "2.2 Codebase Analysis"
      priority: 2
      when: "strategy requires code analysis"
      use_reference: "research_strategies → [strategy_name] → codebase_actions"
      output:
        code_examples: "3-5 real examples from code"
        patterns_found: "patterns for examples section"
        antipatterns: "what NOT to do"
      exit_criteria: ">=3 examples OR 'no code relevance'"

    - step: "2.3 Artifact Structure"
      priority: 3
      actions:
        - action: "ls .claude/{artifact_type}s/"
          purpose: "list existing artifacts"
        - action: "Read best artifact of the same type"
          criteria: "most complete by structure"
        - action: "Read artifact with closest topic match"
          criteria: "closest topic match"
      output:
        structure_template: "sections, yaml fields"
        best_practices: "what to adopt from examples"
      exit_criteria: "structure template determined"

    - step: "2.4 Integration Points"
      priority: 4
      actions:
        - action: "Grep CLAUDE.md"
          pattern: "triggers, paths for this type"
        - action: "Find related artifacts"
          pattern: "@skills, /commands that will be related"
      output:
        trigger_pattern: "when the artifact should activate"
        related_artifacts: "[@artifact1, @artifact2]"
        claude_md_section: "where to add"
      exit_criteria: "integration point determined"

  research_budget:
    max_files_to_read: 10
    max_grep_searches: 5
    stop_when: "all phase exit_criteria met"

  output_format: |
    ## Phase 2: RESEARCH — DONE
    ### Prior Knowledge
    - [fact1]
    - [fact2]

    ### Code Examples (if applicable)
    ```go
    // Real example from codebase
    ```

    ### Structure Template
    - Sections: [...]
    - YAML fields: [...]

    ### Integration
    - Trigger: [...]
    - Related: [...]

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 3: ANALYZE
# ════════════════════════════════════════════════════════════════════════════════
phase_3_analyze:
  purpose: "CREATE: design structure | ENHANCE: find gaps"

  branch_by_mode:
    create:
      steps:
        - step: "3.1 Design Structure"
          input: "research_summary from Phase 2"
          actions:
            - "Select sections based on structure_template"
            - "Define yaml frontmatter fields"
            - "Choose examples to include from code_examples"
            - "Check against artifact-quality.md checklist"
          output:
            planned_sections: "[section1, section2, ...]"
            yaml_fields: "{field1: value1, ...}"
            examples_to_include: "[example1, example2]"
            quality_checklist: "✓/✗ for each criterion"

      output_format: |
        ## Phase 3: ANALYZE (CREATE) — DONE
        ### Planned Structure
        - Sections: [...]
        - YAML: [...]
        - Examples: [...]
        ### Quality Pre-check
        - [✓/✗] criterion1
        - [✓/✗] criterion2

    enhance:
      steps:
        - step: "3.1 Read Current State"
          action: "Read existing_path"
          output: "current_content"

        - step: "3.2 Structural Audit"
          action: "Check against artifact-quality.md checklist"
          output:
            structure_issues: "missing sections, incorrect format"
            quality_score: "1-5"

        - step: "3.3 Content Audit"
          action: "Compare current_content with research_summary"
          output:
            missing_patterns: "patterns from code not present in artifact"
            outdated_content: "outdated information"
            incorrect_examples: "examples not matching real code"

        - step: "3.4 Gap Analysis"
          action: "Form list of changes"
          output:
            keep: "what to leave unchanged"
            update: "what to update (and how)"
            add: "what to add (and where from)"
            remove: "what to remove (and why)"

      output_format: |
        ## Phase 3: ANALYZE (ENHANCE) — DONE
        ### Current State
        - Quality Score: [1-5]
        - Structure Issues: [...]

        ### Gap Analysis
        - KEEP: [...]
        - UPDATE: [...]
        - ADD: [...]
        - REMOVE: [...]

  exit_criteria:
    create: "structure designed, quality pre-check passed"
    enhance: "gap analysis complete, change list formed"

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 4: PLAN
# ════════════════════════════════════════════════════════════════════════════════
phase_4_plan:
  purpose: "Create detailed implementation plan"

  steps:
    - step: "4.1 Generate Implementation Plan"
      branch_by_mode:
        create:
          output:
            file_path: ".claude/{type}s/{name}[/SKILL].md"
            yaml_frontmatter: "exact yaml to write"
            sections_outline: "each section with brief content description"
            content_sources: "where to get content for each section"

        enhance:
          output:
            file_path: "existing_path"
            changes:
              - change: "change description"
                location: "where in the file"
                old_content: "what was (if update/remove)"
                new_content: "what will be"
                source: "where taken from (research step)"

    - step: "4.2 Integration Plan"
      output:
        claude_md_change: "what to add/change in CLAUDE.md"
        related_updates: "changes in related artifacts"
        settings_json: "if permissions needed"

    - step: "4.3 Quality Checklist"
      source: "artifact-quality.md"
      output: "checklist for /artifact-review"

  output_format: |
    ## Phase 4: PLAN — DONE
    ### Implementation
    - File: [path]
    - Changes: [N items]

    ### Integration
    - CLAUDE.md: [change]
    - Related: [artifacts]

    ### Quality Checklist
    - [ ] criterion1
    - [ ] criterion2

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 5: OUTPUT
# ════════════════════════════════════════════════════════════════════════════════
phase_5_output:
  purpose: "Final output for /artifact-review"

  format: |
    # Artifact Analysis Complete: [Name]

    ## Summary
    - Mode: [create/enhance]
    - Type: [type]
    - File: [path]

    ## Research Summary
    [condensed from Phase 2]

    ## Analysis
    [from Phase 3 — structure OR gaps]

    ## Implementation Plan
    [from Phase 4]

    ## Quality Checklist
    [from Phase 4.3]

    ---
    **NEXT:** /artifact-review

# ════════════════════════════════════════════════════════════════════════════════
# REFERENCE: Research Strategies
# ════════════════════════════════════════════════════════════════════════════════
research_strategies:
  code_layer:
    desc: "Architecture layers (domain, usecase, repository, api, worker)"
    sources: ["internal/{layer}/**/*.go"]
    actions:
      - Glob: "internal/{layer}/**/*.go" → file list
      - Grep: "func.*\\(|type.*struct|type.*interface" → main patterns
      - Read: "2-3 typical files" → real code examples
    find: ["Typical layer function", "Error handling", "Testing"]
    layers:
      note: "Project-specific — define layers in CLAUDE.md"
      pattern: "internal/{layer}/ — {layer description}"

  library:
    desc: "Third-party and standard library dependencies used in project"
    sources: ["**/*.go with import {library}"]
    actions:
      - Grep: "import.*{library}" → files using library
      - Grep: "{library}\\." → function calls
      - Read: "files with most usage" → usage patterns
    find: ["Typical use case", "Initialization", "Error handling"]
    common: ["{logger} — structured logging", "{test_lib} — assertions"]

  workflow:
    desc: "Process commands (commit, review, deploy)"
    sources: ["git log", ".claude/commands/*.md", "CI/CD configs"]
    actions:
      - Bash: "git log --oneline -20" → commit style
      - Read: "existing commands" → workflow structure
      - Read: ".github/workflows/ OR Makefile" → existing automations
    find: ["Current workflow", "Pain points for automation"]

  meta:
    desc: "Claude code artifacts (agents, skills creation)"
    sources: [".claude/**/*.md", "meta-agent deps"]
    actions:
      - Glob: ".claude/**/*.md" → all artifacts
      - Read: "best artifact examples" → structure, patterns
      - Read: "meta-agent.md, artifact-quality.md" → requirements
    find: ["Best practice structure", "Quality criteria", "Integration patterns"]

# ════════════════════════════════════════════════════════════════════════════════
# REFERENCE: Quality Checklists by Type
# ════════════════════════════════════════════════════════════════════════════════
quality_checklists:
  command:
    required:
      - "YAML frontmatter with description"
      - "workflow with phases"
      - "output format"
      - "examples section"
    recommended:
      - "error handling"
      - "related commands"

  skill:
    required:
      - "YAML with name and description"
      - "Trigger keywords in description"
      - "< 500 lines"
      - "Correct/incorrect examples"
    recommended:
      - "see_also section"
      - "common_mistakes"

  rule:
    note: "Rules use Claude Code format: YAML frontmatter (---) with paths: + Markdown body"
    required:
      - "YAML frontmatter with paths: (quoted glob patterns) — or no frontmatter for global rules"
      - "Markdown body with ## Checklist (3-7 actionable items)"
    recommended:
      - "## Forbidden section with Bad/Good code examples"
      - "## References with @skill links"
      - "## Exceptions (when rule does NOT apply)"

  agent:
    required:
      - "YAML with name, description, tools"
      - "AUTONOMY RULE"
      - "INPUT/OUTPUT formats"
      - "Error handling"
    recommended:
      - "phases breakdown"
      - "stop conditions"

# ════════════════════════════════════════════════════════════════════════════════
# PRINCIPLES
# ════════════════════════════════════════════════════════════════════════════════
principles:
  - id: 1
    name: "Research-first"
    rule: "Gather data first, then design"

  - id: 2
    name: "Evidence-based"
    rule: "Examples only from real code, not fabricated"

  - id: 3
    name: "Quality-aware"
    rule: "Check against artifact-quality.md at every stage"

  - id: 4
    name: "Integration-ready"
    rule: "Plan integration immediately, not after creation"

  - id: 5
    name: "Linear workflow"
    rule: "Phases are sequential, do not skip"

# ════════════════════════════════════════════════════════════════════════════════
# EXAMPLE: Full Flow
# ════════════════════════════════════════════════════════════════════════════════
example:
  create_flow:
    input: "Create skill for project patterns"
    phase_1:
      mode: "create"
      type: "skill"
      topic: "library"
      strategy: "library"
    phase_2:
      prior_knowledge: "project patterns, conventions"
      code_examples: "src/**/*.{ext}"
      structure: "from project analysis"
    phase_3:
      sections: ["meta", "patterns", "examples", "forbidden"]
      yaml: "name: {skill-name}, description: ..."
    phase_4:
      file: ".claude/skills/{skill-name}/SKILL.md"
      integration: "CLAUDE.md → skills section"
    output: "Plan ready for /artifact-review"

  enhance_flow:
    input: "Enhance {skill-name} skill, missing new patterns"
    phase_1:
      mode: "enhance"
      type: "skill"
      topic: "code_layer"
      strategy: "code_layer"
      existing_path: ".claude/skills/{skill-name}/SKILL.md"
    phase_2:
      prior_knowledge: "Clean Architecture layers"
      code_examples: "internal/{layer}/**/*.go"
      current_patterns: "found in code"
    phase_3:
      quality_score: 3
      gaps:
        keep: ["meta", "basic patterns"]
        add: ["new patterns from code", "error handling examples"]
        update: ["outdated examples"]
        remove: ["deprecated patterns"]
    phase_4:
      changes: "5 specific changes"
      integration: "no changes needed"
    output: "Enhancement plan ready for /artifact-review"
