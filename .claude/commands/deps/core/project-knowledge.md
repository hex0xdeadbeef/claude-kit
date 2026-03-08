# Project Knowledge

**File:** PROJECT-KNOWLEDGE.md (project root or .claude/)
**Status:** NON_CRITICAL — workflow continues without it, but with reduced precision.
**Created by:** Manual analysis or /planner onboarding phase.

language_profile:
  description: "Language-specific patterns. Agents use aliases (VERIFY, FMT, LINT, TEST, EXT, etc.) from PK or Go defaults below."

  commands:
    format: "make fmt"            # alias: FMT
    lint: "make lint"             # alias: LINT
    test: "make test"             # alias: TEST
    verify: "make fmt && make lint && make test"  # alias: VERIFY

  error_pattern:
    wrap: "%w"                    # alias: ERROR_WRAP
    example: 'fmt.Errorf("context: %w", err)'
    anti_patterns: ["log AND return same error"]

  domain_rules:
    prohibited_annotations: ["encoding/json tags in domain entities"]  # alias: DOMAIN_PROHIBIT
    note: "Domain entities must be pure — no serialization annotations. Tags belong in DTOs."

  file_patterns:
    source_ext: ".go"             # alias: EXT
    generated: ["*_gen.go"]       # alias: GENERATED
    mocks: ["*/mocks/*.go"]       # alias: MOCKS
    source_glob: "internal/**/*.go"  # alias: SOURCE_GLOB

  config_convention:
    example_file: "config.yaml.example"    # alias: CONFIG_EXAMPLE
    docs_file: "README.md"                 # alias: CONFIG_DOCS
    note: "When config changes → update CONFIG_EXAMPLE + CONFIG_DOCS"

  concurrency:
    primitives: ["goroutines", "channels", "mutex", "sync primitives"]
    race_check: "go test -race"

fallback_protocol:
  step_1_check: "Read PROJECT-KNOWLEDGE.md from project root, then .claude/"
  step_2_if_missing:
    warn: "PROJECT-KNOWLEDGE.md not found. Using Go defaults from language_profile above."
    actions:
      import_matrix: "Infer from project structure: ls internal/ (or src/) → identify layers → grep import patterns"
      layer_naming: "Detect via directory naming: controller|service|usecase|handler|repository|storage"
      layer_order: "Default: data-access → domain/models → business-logic → api/handler → tests → wiring"
      test_command: "Use language_profile.commands.test (Go default: make test)"
      error_pattern: "Use language_profile.error_pattern (Go default: wrap with %w, no log+return)"
      domain_structure: "Infer: ls internal/*/models/ (or src/*/models/)"
    language_profile: "Use Go defaults from schema above. Override in PROJECT-KNOWLEDGE.md for non-Go projects."

heuristic_discovery:
  description: "When PROJECT-KNOWLEDGE.md is missing, agent SHOULD attempt auto-discovery"
  commands:
    - "ls -la internal/ (or src/)"
    - "head -20 Makefile (or package.json, pyproject.toml, Cargo.toml)"
    - "grep -r 'import' internal/*/handler*/ | head -10"
    - "grep -r 'import' internal/*/service*/ | head -10"
  output: "Use discovered structure as runtime substitute. Note in handoff: 'PK missing, used heuristic discovery.'"

save_recommendation:
  when: "Planner successfully discovers project structure via heuristic"
  action: "Recommend user: 'Consider creating PROJECT-KNOWLEDGE.md to improve precision. Run /planner --analyze to generate.'"
