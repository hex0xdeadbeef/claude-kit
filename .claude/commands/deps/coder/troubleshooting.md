# Coder Troubleshooting

troubleshooting:
  - problem: "Tests fail 3x in a row - stuck"
    cause: "Bug in implementation logic or wrong approach"
    fix: "Review Part logic with Sequential Thinking, compare with plan examples"
    lesson: "Complex business logic needs structured analysis before coding"

  - problem: "Import matrix violation detected by hooks"
    cause: "Didn't check architecture rules before implementation"
    fix: "Review import matrix from PROJECT-KNOWLEDGE.md, refactor imports to follow layer dependencies"
    lesson: "Architecture violations caught early prevent major refactoring later"

  - problem: "Hook blocks edit - generated file"
    cause: "Attempted to edit generated files (*_gen.go, mocks/*.go) directly"
    fix: "Regenerate via project's code generation commands (SEE: PROJECT-KNOWLEDGE.md or Makefile), edit source files instead"
    lesson: "Generated files must be regenerated, not manually edited"

  - problem: "New library used without Context7"
    cause: "Assumed familiarity with library API"
    fix: "ALWAYS use Context7 for external dependencies: resolve-library-id → query-docs"
    lesson: "Documentation prevents incorrect API usage and saves debugging time"

  - problem: "Config added without README update"
    cause: "Forgot RULE about config changes"
    fix: "Update config.yaml.example AND README.md table with new config parameters"
    lesson: "Config changes require documentation updates - mandatory per project rules"
