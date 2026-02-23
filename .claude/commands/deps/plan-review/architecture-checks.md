# Architecture Compliance Checks

purpose: "Validation checks for Clean Architecture compliance in implementation plans"

## Manual Checks (Simple Plans)

```yaml
manual_checks:
  - check: Layer imports
    how: "Verify project's package structure (SEE: PROJECT-KNOWLEDGE.md#Dependency Matrix, if available)"
    pass_criteria:
      - models_pure: "Models in <domain>/models/ import only stdlib"
      - business_logic_imports_data_access: "Business logic layer ({controller/service/usecase}) imports data access, models, domain services per project conventions"
      - api_imports_business_logic: "API imports business logic layer (not database directly) — {controller/service/usecase} per project"
      - no_api_to_db: "API NEVER imports database directly"

  - check: Clean domain
    how: "Search for tags in domain entities"
    pass_criteria:
      - no_json_tags: "No `json:` tags in entity structs"
      - no_db_tags: "No `db:` tags in entity structs"
      - pure_go: "Only stdlib imports allowed"

  - check: "Handler → Business Logic flow"
    how: "Verify API layer doesn't bypass business logic layer (SEE: PROJECT-KNOWLEDGE.md for layer naming)"
    pass_criteria:
      - handler_calls_business_logic: "Handler methods call {controller/service/usecase} methods"
      - no_handler_to_db: "Handler NEVER imports database package directly"

  - check: Error handling
    how: "Verify project-specific error handling pattern (SEE: PROJECT-KNOWLEDGE.md)"
    pass_criteria:
      - error_context: "Errors carry context per project convention"
      - wrap_with_w: "Errors wrapped with %w (standard Go error wrapping)"
      - no_log_and_return: "Never log AND return same error"

  - check: Protected files
    how: "Verify plan doesn't edit generated files"
    pass_criteria:
      - no_generated_edits: "No changes to generated query files"
      - no_gen_edits: "No changes to *_gen.go files"
      - no_mock_edits: "No changes to */mocks/*.go files"
    severity_if_fail: BLOCKER
```

## Automated Checks (Complex Plans)

```yaml
automated_checks:
  when_to_use:
    - complex_plan: "4+ Parts"
    - multi_layer: "3+ layers modified"
    - high_risk: "Core domain changes"

  task_tool_usage:
    subagent_type: "arch-checker"
    model: "haiku"
    prompt_template: |
      Validate architecture compliance for files mentioned in the plan:
      - Check layer imports matrix compliance
      - Find json/db tags in domain entities
      - Verify error handling patterns per project conventions (%w wrapping, error context)
      - List any protected file modifications

    output_format:
      - violations: "List of import matrix violations"
      - domain_issues: "Tags found in entities"
      - error_issues: "Missing error context or %w wrapping"
      - protected_files: "Generated files in change list"
```

## Security Checklist (API Endpoints)

```yaml
security_checklist:
  when: "Plan includes API handler changes"

  checks:
    - check: SQL injection prevention
      validate: "Uses parameterized queries (prepared statements)"
      pass: "All DB queries via generated code or parameterized queries"
      fail: "Raw SQL concatenation found"
      severity: BLOCKER

    - check: Input validation
      validate: "DTOs have validate tags OR manual validation"
      pass: "All user inputs validated at boundary"
      fail: "Direct use of unvalidated input"
      severity: BLOCKER

    - check: Auth/AuthZ
      validate: "Authentication and authorization middleware in place"
      pass: "Auth middleware validates tokens and enforces access control"
      fail: "Missing auth check or authorization bypass"
      severity: BLOCKER

    - check: Sensitive data
      validate: "No passwords/tokens in logs"
      pass: "Sensitive fields redacted or not logged"
      fail: "Plain text secrets in log statements"
      severity: BLOCKER
```

## Design Patterns Check

```yaml
design_patterns_check:
  when: "Plan mentions patterns (Factory, Strategy, etc.)"

  validation:
    - question: "Are patterns justified (not over-engineering)?"
      check: "Pattern solves real problem, not hypothetical future need"
      pass: "Clear benefit stated (e.g., 'enables multiple implementations')"
      fail: "Pattern added 'for flexibility' without concrete use case"

    - question: "KISS check passed for each pattern?"
      check: "Simpler alternative considered and rejected"
      pass: "Shows why simple approach insufficient"
      fail: "Pattern chosen without considering simple solution"

    - question: "Do patterns align with Clean Architecture layers?"
      check: "Pattern doesn't violate layer boundaries"
      pass: "Factory in infrastructure, Strategy in domain"
      fail: "Domain pattern imports infrastructure"
```

## Concurrency Check

```yaml
concurrency_check:
  when: "Plan includes goroutines, channels, sync primitives"

  validation:
    - question: "Is the right concurrency pattern chosen?"
      options: ["Worker Pool", "errgroup", "Pipeline", "Fan-out/Fan-in"]
      check: "Pattern matches problem (e.g., Worker Pool for limited concurrency)"

    - question: "Is graceful shutdown addressed?"
      check: "Context cancellation propagates, workers clean up"
      pass: "ctx.Done() handled, resources released"
      fail: "No shutdown mechanism or goroutine leaks"

    - question: "Is concurrency level defined?"
      check: "Worker count or buffer size specified"
      pass: "Explicit limit (e.g., 10 workers, 100 buffer)"
      fail: "Unbounded concurrency or missing limits"
```

## Business Logic Layer Check

```yaml
business_logic_pattern_check:
  when: "Plan modifies business logic layer ({controller/service/usecase} per project)"
  note: "SEE: PROJECT-KNOWLEDGE.md for project-specific layer naming (if available)"

  validation:
    - check: "Business logic layer has proper dependencies"
      pass: "Business logic layer injects {data_access_interface} and domain-specific services per project conventions"
      fail: "Business logic layer creates dependencies internally"
      severity: MAJOR

    - check: "API layer uses business logic layer"
      pass: "Handlers call {controller/service/usecase} methods, not database directly"
      fail: "Handler imports data access layer directly"
      severity: BLOCKER

    - check: "Models in correct location"
      pass: "Domain models in <domain>/models/ package"
      fail: "Models defined in business logic or API layer"
      severity: MAJOR
```
