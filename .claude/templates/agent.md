meta:
  type: "agent"
  purpose: "Template for creating agent artifacts"
  format: "> 80% YAML, no prose paragraphs, no ## headers"

template:
  file_path: ".claude/agents/<name>/<name>.md"

  structure:
    meta:
      name: "<agent-name>"
      version: "1.0.0"
      model: "opus | sonnet | haiku"
      description: "<One-line: what this agent does>"
      tools: ["Read", "Write", "Bash", "Glob", "Grep"]
      triggers:
        - "<trigger keyword 1>"
        - "<trigger keyword 2>"

    autonomy:
      rule: "<When to stop vs continue>"
      continue_conditions:
        - "<condition to keep going>"
      stop_conditions:
        - "FATAL error encountered"
        - "<task completion condition>"

    input:
      arguments: "<format: path | name | none>"
      modes:
        - input: "<mode1>"
          action: "<what happens>"
        - input: "<mode2>"
          action: "<what happens>"

    workflow: "<PHASE1 → PHASE2 → PHASE3 → PHASE4>"

    phases:
      - phase: 1
        name: "<NAME>"
        purpose: "<description>"
        steps: ["step1", "step2", "step3"]
        output: "<expected output or state>"

      - phase: 2
        name: "<NAME>"
        purpose: "<description>"
        steps: ["step1", "step2"]
        output: "<expected output>"

    rules:
      - id: R1
        severity: critical
        rule: "<Must-do or must-not-do>"
      - id: R2
        severity: high
        rule: "<Important constraint>"

    error_handling:
      - situation: "<error condition>"
        action: "<what to do>"
      - situation: "File not found"
        action: "FATAL: <message> — stop execution"

    beads_integration:
      on_start: "bd create --title='<agent> {input}' --type=task"
      on_finish: "bd close {id} --reason='Completed'"

    output:
      format: "<markdown | YAML | text>"
      sections: ["section1", "section2"]

    fatal_errors:
      - error: "<ERROR_CODE>"
        condition: "<when this happens>"
        message: "FATAL: <message>"

    checklist:
      startup: ["Load PROJECT-KNOWLEDGE.md if exists", "Confirm input valid"]
      execution: ["<phase 1 check>", "<phase 2 check>"]
      completion: ["Output written", "beads closed"]

ai_first_principles:
  format:
    prefer: "pure YAML"
    allow: "YAML + fenced code blocks for code examples"
    avoid: ["prose paragraphs", "## headers inside content", "markdown tables"]
  metrics:
    yaml_ratio: "> 80%"
    prose_max: "< 10%"
    examples: "always bad/good pairs with 'why'"
  patterns:
    examples: "grep/glob patterns to find current code — never hardcode snippets"
    structure: "YAML lists over prose bullets"

quality_gates:
  post_create:
    - "File at correct path: .claude/agents/<name>/<name>.md"
    - "All required sections present: meta, autonomy, input, workflow, phases, rules, output"
    - "YAML > 80% of file content"
    - "No prose paragraphs or ## headers"
    - "fatal_errors defined"
    - "beads_integration present"
    - "checklist present"

examples:
  good:
    description: "Complete YAML structure with all required sections"
    content: |
      meta:
        name: doc-gen
        version: "1.0.0"
        model: sonnet
        description: "Generate API documentation for Go services"
        tools: ["Read", "Glob", "Write"]
        triggers: ["docs", "documentation", "generate docs"]

      autonomy:
        rule: "Execute until all docs generated or FATAL error"
        stop_conditions:
          - "FATAL error"
          - "All target files documented"

      workflow: "SCAN → ANALYZE → GENERATE → VERIFY"

      phases:
        - phase: 1
          name: SCAN
          purpose: "Find source files"
          steps: ["Glob **/*.go", "Filter exported symbols"]
          output: "file_list[]"

        - phase: 2
          name: GENERATE
          purpose: "Write documentation"
          steps: ["Read each file", "Write docs/<name>.md"]
          output: "docs/ populated"

      rules:
        - id: R1
          severity: critical
          rule: "Never overwrite existing docs without --force flag"

      error_handling:
        - situation: "Source file unreadable"
          action: "Skip with warning, continue"
        - situation: "Output dir missing"
          action: "FATAL: docs/ not found — create it first"

      beads_integration:
        on_start: "bd create --title='doc-gen {input}' --type=task"
        on_finish: "bd close {id} --reason='Docs generated'"

      output:
        format: "markdown"
        sections: ["overview", "functions", "types"]

  bad:
    description: "Prose-heavy, missing structure"
    why: "No autonomy rule, no phases, no rules, no error_handling — unpredictable behavior"
    content: |
      ---
      name: doc-gen
      description: Documentation generator
      ---

      # DOC-GEN

      This agent generates documentation for your code.
      It scans the codebase and writes markdown files.
      Run it when you need docs updated.
