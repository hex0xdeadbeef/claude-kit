meta:
  type: "command"
  purpose: "Template для создания command артефактов"

template:
  file_path: ".claude/commands/<name>.md"

  structure:
    meta:
      description: "<one-line description>"

    workflow: "<STEP1 → STEP2 → STEP3>"

    phases:
      - phase: 1
        name: "<Name>"
        purpose: "<description>"
        steps: ["step1", "step2"]
      - phase: 2
        name: "<Name>"
        purpose: "<description>"

    output:
      format: "<expected output format>"

    examples:
      - cmd: "/<command> arg1"
        desc: "<what it does>"

    next: "/<next-command>"

examples:
  good:
    description: "AI-optimized with YAML structure"
    content: |
      meta:
        description: "Analyze task requirements and design implementation plan"

      workflow: "INPUT → RESEARCH → ANALYZE → DESIGN → PLAN → OUTPUT"

      phases:
        - phase: 1
          name: "Read task"
          tools: ["Read"]
        - phase: 2
          name: "Search codebase"
          tools: ["Grep", "Glob"]

      output:
        format: "plan.md"
        sections: ["Dependencies", "Steps", "Risks"]

  bad:
    description: "Human-optimized prose"
    content: |
      ---
      description: This command helps you analyze your tasks
      ---

      # TASK-ANALYST

      This is a task analysis command that will help you understand
      the requirements of your task and create a comprehensive plan
      for implementation. It works by first reading your task...

      (too much prose, no YAML structure, unclear workflow)
    why: "prose instead of structure, no phases, ambiguous"
