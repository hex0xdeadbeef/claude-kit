meta:
  type: "agent"
  purpose: "Template для создания agent артефактов"

template:
  file_path: ".claude/agents/<name>/<name>.md"

  structure:
    meta:
      name: "<agent-name>"
      model: "opus | sonnet | haiku"
      description: |
        <What this agent does>

        Use when:
        - Condition 1
        - Condition 2
      tools:
        - "Read"
        - "Write"
        - "Bash"
      triggers:
        - "<trigger keyword 1>"
        - "<trigger keyword 2>"

    autonomy:
      rule: "<when to stop/continue>"
      stop_conditions:
        - "<condition 1>"
        - "<condition 2>"

    input:
      arguments: "<format>"
      modes:
        - input: "<mode1>"
          action: "<what happens>"

    workflow: "<PHASE1 → PHASE2 → PHASE3>"

    phases:
      - phase: 1
        name: "<Name>"
        purpose: "<description>"
        steps: ["step1", "step2"]
        output: "<expected output>"

    output:
      format: "<expected format>"
      sections: ["section1", "section2"]

    fatal_errors:
      - error: "<ERROR_CODE>"
        condition: "<when>"
        message: "<FATAL: message>"

ai_first_principles:
  core_rule: "All artifacts are instructions for LLM, not for humans"

  format_priority:
    - format: "pure YAML"
      when: "configuration, rules, agents"
      why: "maximum structure"

    - format: "YAML + code blocks"
      when: "skills with code examples"
      why: "syntax highlighting"

    - format: "AVOID"
      what: "prose, ## headers, tables"
      why: "ambiguous for LLM"

  metrics:
    yaml_structure: "> 80%"
    prose_max: "< 10%"
    code_examples: "always bad/good pairs"

quality_gates:
  pre_implementation:
    - "Plan passed /artifact-review (APPROVED)"
    - "All issues resolved"
    - "Integration steps defined"

  post_implementation:
    - "File created in correct location"
    - "YAML frontmatter valid"
    - "All required sections present"
    - "AI-first format checklist passed"
    - "Added to CLAUDE.md"
    - "beads updated"

  final_check:
    command:
      - "description in YAML"
      - "WORKFLOW section"
      - "OUTPUT section"
    skill:
      - "name + description in YAML"
      - "Trigger keywords"
      - "< 500 lines"
    rule:
      - "paths in YAML"
      - "Quick checklist"
      - "@skill reference"
    agent:
      - "name + description + tools in YAML"
      - "AUTONOMY RULE"
      - "INPUT/OUTPUT"

examples:
  good:
    description: "YAML structure + phases"
    content: |
      meta:
        name: doc-gen
        model: sonnet
        description: |
          Generate documentation for {project} code

          Use when:
          - Documentation is needed
          Keywords: docs, documentation
        tools: ["Read", "Write", "Grep"]

      autonomy:
        rule: "Execute until all files generated"
        stop_conditions:
          - "FATAL ERROR"
          - "All docs generated"

      workflow: "SCAN → ANALYZE → GENERATE → VERIFY"

      phases:
        - phase: 1
          name: "SCAN"
          purpose: "Find source files"
          tools: ["Glob"]

  bad:
    description: "Prose without structure"
    content: |
      ---
      name: doc-gen
      description: Documentation generator
      tools: [Read, Write]
      ---

      # DOC-GEN

      This agent generates documentation for your code.
      It will scan your codebase, analyze the structure...

      (too much prose, no YAML structure, no phases)
    why: "prose, no phases, no autonomy rule"
