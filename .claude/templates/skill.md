meta:
  type: "skill"
  purpose: "Template для создания skill артефактов"

template:
  file_path: ".claude/skills/<name>/SKILL.md"

  structure:
    meta:
      name: "<skill-name>"
      description: |
        <What this skill does>

        Load when:
        - Condition 1
        - Condition 2
        Keywords: keyword1, keyword2

    triggers:
      - if: "<condition>"
        then: "<action>"

    rules:
      - id: 1
        rule: "<rule text>"
        priority: "P0 | P1 | P2"

    examples:
      pattern_name:
        bad: "<wrong code>"
        good: "<correct code>"
        why: "<explanation>"

    forbidden:
      - action: "<what not to do>"
        why: "<reason>"

    checklist:
      - "<check item 1>"
      - "<check item 2>"

examples:
  good:
    description: "YAML structure + code examples"
    content: |
      meta:
        name: errors
        description: |
          Error handling rules

          Load when:
          - Working with errors
          Keywords: error, wrap, context

      rules:
        - id: 1
          rule: "Wrap errors with context"
          pattern: "fmt.Errorf('%s: %w', op, err)"
        - id: 2
          rule: "NO log AND return"
          pattern: "Pick one: log OR return"

      examples:
        error_wrap:
          bad: |
            if err != nil {
                log.Error(err)
                return err  // log AND return
            }
          good: |
            if err != nil {
                return fmt.Errorf("operation context: %w", err)
            }
          why: "log AND return = duplicate logging in error chain"

  bad:
    description: "Prose without structure"
    content: |
      ---
      name: errors
      description: Error handling
      ---

      When you handle errors, you should wrap them with context.
      This helps with debugging because you can see the call stack.
      Also, avoid logging and returning at the same time because...

      (no YAML structure, no triggers, no examples)
    why: "prose, no triggers, no bad/good examples"
