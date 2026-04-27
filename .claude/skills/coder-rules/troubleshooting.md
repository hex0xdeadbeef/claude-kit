# Coder Troubleshooting

troubleshooting:
  - problem: "Tests fail 3x in a row - stuck"
    cause: "Bug in implementation logic or wrong approach"
    fix: "Load systematic-debugging skill. Run Phase 1 (Root Cause Investigation):
      read error output, reproduce with `go test -v -count=1 -run TestXxx ./...`,
      trace data flow backward. Find root cause before attempting fix."
    lesson: "Systematic root cause investigation is faster than guess-and-check.
      3x failures = time for structured approach, not another fix attempt."

  - problem: "Layer-dependency violation detected by hooks"
    cause: "Didn't check architecture rules before implementation"
    fix: "Review layer-dependency rule per resolved {LAYER_RULE} (resolved from PROJECT-KNOWLEDGE.md → LAYER_RULE; CLAUDE.md fallback). Refactor imports per resolved rule. SKIP-with-consolidated-NIT when {LAYER_RULE} unset OR {ARCHITECTURE_STYLE} != \"layered\" (canonical SKIP)."
    lesson: "Architecture violations caught early prevent major refactoring later"

  - problem: "Hook blocks edit - generated file"
    cause: "Attempted to edit generated files (per {GENERATED_PATTERN}/{MOCK_PATTERN} slots resolved from PROJECT-KNOWLEDGE.md; kit-default Go: *_gen.go, mocks/*.go) directly"
    fix: "Regenerate via project's code generation commands (SEE: .claude/PROJECT-KNOWLEDGE.md or Makefile), edit source files instead"
    lesson: "Generated files must be regenerated, not manually edited"

  - problem: "New library used without Context7"
    cause: "Assumed familiarity with library API"
    fix: "ALWAYS use Context7 for external dependencies: resolve-library-id → query-docs"
    lesson: "Documentation prevents incorrect API usage and saves debugging time"

  - problem: "Config added without docs update"
    cause: "Forgot RULE about config changes"
    fix: "Update CONFIG_EXAMPLE AND CONFIG_DOCS with new config parameters"
    lesson: "Config changes require documentation updates - mandatory per project rules"
