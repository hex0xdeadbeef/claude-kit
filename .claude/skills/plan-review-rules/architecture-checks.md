# Architecture Compliance Checks

purpose: "Validation checks for project's architecture compliance in implementation plans. Slot values resolved from .claude/PROJECT-KNOWLEDGE.md (or from CLAUDE.md Language Profile as legacy fallback)."

## Slot Resolution

The checks below reference SLOTS — abstract names that the reviewer resolves
from `.claude/PROJECT-KNOWLEDGE.md` (injected via `additionalContext` by the
SubagentStart hook) at run-time.

| Slot | Source | Used by check |
|------|--------|---------------|
| ARCHITECTURE_STYLE | PROJECT-KNOWLEDGE.md → ARCHITECTURE_STYLE | Gates layer-related checks (Layer imports, Handler → Business Logic flow, Parts ordering) |
| LAYERS | PROJECT-KNOWLEDGE.md → LAYERS | Layer imports, Handler → Business Logic flow |
| LAYER_RULE | PROJECT-KNOWLEDGE.md → LAYER_RULE | Layer imports |
| DOMAIN_PROHIBIT | PROJECT-KNOWLEDGE.md → DOMAIN_PROHIBIT | Clean domain |
| ERROR_WRAP | PROJECT-KNOWLEDGE.md → ERROR_WRAP | Error handling |
| GENERATED_PATTERN | PROJECT-KNOWLEDGE.md → GENERATED_PATTERN | Protected files |
| MOCK_PATTERN | PROJECT-KNOWLEDGE.md → MOCK_PATTERN | Protected files |
| CONCURRENCY_PRIMITIVES | PROJECT-KNOWLEDGE.md → CONCURRENCY_PRIMITIVES | Concurrency check |
| CONCURRENCY_LEAKS | PROJECT-KNOWLEDGE.md → CONCURRENCY_LEAKS | Concurrency check |

**SKIP rule:** If a slot is unset (PROJECT-KNOWLEDGE.md missing OR slot value
is empty / contains `<your-` placeholder), the corresponding check is SKIPPED
for this run.

**Layer-check predicate:** Layer-related checks (Layer imports, Handler →
Business Logic flow, Parts ordering, Business Logic Layer Check) run ONLY when
BOTH conditions hold:

- `ARCHITECTURE_STYLE` is `layered` (or unset AND `LAYERS` is populated — back-compat)
- `LAYERS` and `LAYER_RULE` are populated

Otherwise these checks are SKIPPED with one consolidated NIT entry.

The reviewer:

1. Emits ONE consolidated NIT issue at the end of the verdict:
   `{severity: "NIT", category: "completeness", problem: "N checks skipped
   due to unconfigured PROJECT-KNOWLEDGE.md slots: [<slot1>, <slot2>, ...].
   Populate PROJECT-KNOWLEDGE.md to enable full validation."}`
2. The `inject-review-context.sh` SubagentStart hook writes a per-invocation
   `record_kind="pk_missing_at_inject"` entry to `handoff-validation.jsonl`
   when PROJECT-KNOWLEDGE.md is missing entirely (file-level telemetry).
   Per-slot SKIP details are visible in the consolidated NIT issue text.

The NIT issue does NOT block approval (auto-escalation rule "5+ MINOR" does
NOT escalate NIT — verified per `plan-review-rules/SKILL.md:21`). Telemetry
is hook-side only — reviewer agents lack a Bash tool and cannot write to
`handoff-validation.jsonl` directly.

## Manual Checks (Simple Plans)

```yaml
manual_checks:
  - check: Layer imports
    resolved_from: PROJECT-KNOWLEDGE.md → LAYERS, LAYER_RULE
    skip_if_unset: true
    how: "Verify project's package structure per LAYERS list and LAYER_RULE description"
    pass_criteria:
      - models_pure: "Lowest-level layer (LAYERS[0]) imports only stdlib"
      - business_logic_imports_data_access: "Business-layer imports data-access-layer per LAYER_RULE"
      - api_imports_business_logic: "API/transport layer imports business-layer (NOT data-access directly) per LAYER_RULE"
      - no_api_to_db: "API/transport layer NEVER imports data-access layer directly"
    # <!-- EXAMPLE (lang: go) — for reference only -->
    # LAYERS: [models, repository, service, handler]
    # LAYER_RULE: handler → service → repository → models
    # <!-- end EXAMPLE -->

  - check: Clean domain
    resolved_from: PROJECT-KNOWLEDGE.md → DOMAIN_PROHIBIT
    skip_if_unset: true
    how: "Search for DOMAIN_PROHIBIT pattern in domain entities"
    pass_criteria:
      - domain_pure: "No DOMAIN_PROHIBIT pattern matches in entity files"
    # <!-- EXAMPLE (lang: go) — DOMAIN_PROHIBIT = `json:` or `db:` struct tags -->
    # <!-- EXAMPLE (lang: python) — DOMAIN_PROHIBIT = `from sqlalchemy` or `from django.db` imports -->

  - check: Handler → Business Logic flow
    resolved_from: PROJECT-KNOWLEDGE.md → LAYERS, LAYER_RULE
    skip_if_unset: true
    how: "Verify API layer doesn't bypass business logic layer per LAYER_RULE"
    pass_criteria:
      - handler_calls_business_logic: "API-layer methods call business-layer methods"
      - no_handler_to_db: "API-layer NEVER imports data-access layer directly"

  - check: Error handling
    resolved_from: PROJECT-KNOWLEDGE.md → ERROR_WRAP
    skip_if_unset: true
    how: "Verify project-specific error handling pattern per ERROR_WRAP"
    pass_criteria:
      - error_context: "Errors carry context per ERROR_WRAP convention"
      - no_log_and_return: "Never log AND return same error"
    # <!-- EXAMPLE (lang: go) — ERROR_WRAP = `fmt.Errorf("context: %w", err)` -->
    # <!-- EXAMPLE (lang: python) — ERROR_WRAP = `raise XError("context") from err` -->

  - check: Protected files
    resolved_from: PROJECT-KNOWLEDGE.md → GENERATED_PATTERN, MOCK_PATTERN
    skip_if_unset: true
    how: "Verify plan doesn't edit generated or mock files"
    pass_criteria:
      - no_generated_edits: "No changes to files matching GENERATED_PATTERN glob"
      - no_mock_edits: "No changes to files matching MOCK_PATTERN glob"
    severity_if_fail: BLOCKER
```

## Inline Architecture Checks (Complex Plans)

```yaml
inline_checks:
  when_to_use:
    - complex_plan: "4+ Parts"
    - multi_layer: "3+ layers modified"
    - high_risk: "Core domain changes"

  note: |
    plan-reviewer has Read/Grep/Glob only (no Task/Agent tool; Bash disallowed).
    Run these checks INLINE with grep against the plan's code examples — do NOT
    dispatch a subagent.

  procedure:
    - layer_imports: "grep each Part's code-example import lines; verify against LAYER_RULE (SKIP with consolidated NIT if LAYER_RULE unset OR ARCHITECTURE_STYLE != layered)"
    - domain_purity: "grep for DOMAIN_PROHIBIT pattern in domain-entity code examples"
    - error_handling: "grep for ERROR_WRAP convention in error-return code examples"
    - protected_files: "scan the plan's change list for GENERATED_PATTERN / MOCK_PATTERN file modifications"
```

## Security Checklist (API Endpoints)

```yaml
security_checklist:
  when: "Plan includes API/transport handler changes"
  note: "Security checks are LANGUAGE-AGNOSTIC and run regardless of PROJECT-KNOWLEDGE.md state"

  checks:
    - check: SQL injection prevention
      validate: "Uses parameterized queries (prepared statements)"
      pass: "All DB queries via generated code or parameterized queries"
      fail: "Raw SQL concatenation found"
      severity: BLOCKER

    - check: Input validation
      validate: "DTOs have validation OR manual validation at boundary"
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
  note: "Pattern names are language-agnostic — runs regardless of PROJECT-KNOWLEDGE.md state"

  validation:
    - question: "Are patterns justified (not over-engineering)?"
      check: "Pattern solves real problem, not hypothetical future need"
      pass: "Clear benefit stated (e.g., 'enables multiple implementations')"
      fail: "Pattern added 'for flexibility' without concrete use case"

    - question: "KISS check passed for each pattern?"
      check: "Simpler alternative considered and rejected"
      pass: "Shows why simple approach insufficient"
      fail: "Pattern chosen without considering simple solution"

    - question: "Do patterns align with the project's architecture layers?"
      check: "Pattern doesn't violate LAYER_RULE boundaries"
      pass: "Pattern placed in appropriate layer per LAYERS"
      fail: "Pattern violates layer boundaries"
```

## Concurrency Check

```yaml
concurrency_check:
  when: "Plan includes concurrency primitives"
  resolved_from: PROJECT-KNOWLEDGE.md → CONCURRENCY_PRIMITIVES, CONCURRENCY_LEAKS
  skip_if_unset: true

  validation:
    - question: "Is the right concurrency pattern chosen?"
      options: ["Worker Pool", "Pipeline", "Fan-out/Fan-in", "Producer/Consumer"]
      check: "Pattern matches problem (e.g., Worker Pool for limited concurrency)"

    - question: "Is graceful shutdown addressed?"
      check: "Cancellation propagates, workers clean up"
      pass: "Shutdown signal handled, resources released"
      fail: "No shutdown mechanism or CONCURRENCY_LEAKS risk"

    - question: "Is concurrency level defined?"
      check: "Worker count or buffer size specified"
      pass: "Explicit limit (e.g., 10 workers, 100 buffer)"
      fail: "Unbounded concurrency or missing limits"
```

## Business Logic Layer Check

```yaml
business_logic_pattern_check:
  when: "Plan modifies business logic layer (per PROJECT-KNOWLEDGE.md → LAYERS)"
  resolved_from: PROJECT-KNOWLEDGE.md → LAYERS, LAYER_RULE
  skip_if_unset: true

  validation:
    - check: "Business logic layer has proper dependencies"
      pass: "Business-layer injects data-access-layer interfaces and domain services per LAYER_RULE"
      fail: "Business-layer creates dependencies internally"
      severity: MAJOR

    - check: "API layer uses business logic layer"
      pass: "API-layer methods call business-layer methods, not data-access directly"
      fail: "API-layer imports data-access layer directly"
      severity: BLOCKER

    - check: "Models in correct location"
      pass: "Domain models in lowest layer (LAYERS[0]) per LAYER_RULE"
      fail: "Models defined in business or API layer"
      severity: MAJOR
```
