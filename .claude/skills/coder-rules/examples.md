# Coder Examples

# ════════════════════════════════════════════════════════════════════════════════
# Code Completeness Examples
# ════════════════════════════════════════════════════════════════════════════════
#
# Principle: Full function body, error context propagated per {ERROR_WRAP},
# explicit return types and values, no truncation.
#
# reference_shapes — single canonical source for the entire workflow:
#   resolved_from: "PROJECT-KNOWLEDGE.md → LANGUAGE"
#   location: "../planner-rules/code-shapes/<LANGUAGE>.md"
#   fallback: "../planner-rules/code-shapes/_default.md"
#   invariants: "../planner-rules/code-shapes/INVARIANTS.md"
#
# This file does NOT duplicate language-specific examples — single canonical source
# is planner-rules/code-shapes/. See <LANGUAGE>.md for syntax-correct examples
# in your project's language. The blocks below are kit-dogfood references (Go-only).

# ════════════════════════════════════════════════════════════════════════════════
# Kit Dogfood Reference (Go-only — for kit maintainers)
# Non-Go projects MUST refer to ../planner-rules/code-shapes/<LANGUAGE>.md instead.
# ════════════════════════════════════════════════════════════════════════════════
examples:
  log_and_return:
    # SEE: [examples.md] in code-review-rules skill → log_and_return (full bad/good/why + grep pattern)
    rule: "RULE_4: Never log AND return — creates duplicate logs in error chain"

  domain_entity_with_tags:
    bad: |
      type Service struct {
          ID string `json:"id"`
      }
    good: |
      type Service struct {
          ID string
      }
    why: "RULE_3 (kit Go example): Domain entities must be pure — no {DOMAIN_PROHIBIT}. Tags belong in DTOs. For non-Go projects: see ../planner-rules/code-shapes/<LANGUAGE>.md."

  handler_imports_database:
    bad: |
      import "{data_access_package}"  # Direct DB access from handler
    good: |
      import "internal/<domain>"  # Use domain controller
    why: "RULE_2 (kit Go example): Handlers must not import database directly. Use domain controllers. SKIP if {LAYER_RULE} unset OR {ARCHITECTURE_STYLE} != 'layered'."
    note: "SEE: .claude/PROJECT-KNOWLEDGE.md → LAYER_RULE for project-specific allowed imports."

# ════════════════════════════════════════════════════════════════════════════════
# Layer Import Rules (kit-dogfood Go-shaped — language-agnostic shape see code-shapes/)
# ════════════════════════════════════════════════════════════════════════════════
layer_import_checks:
  note: |
    Resolved from PROJECT-KNOWLEDGE.md → LAYERS + LAYER_RULE.
    SKIP all rules if {LAYERS} unset OR {ARCHITECTURE_STYLE} != "layered" (canonical SKIP-with-NIT).
    Kit example below uses Go four-layer dogfood; for other languages see
    ../planner-rules/code-shapes/<LANGUAGE>.md.

  - layer: models
    rule: "Models import only stdlib (NOT {DOMAIN_PROHIBIT})"
    forbidden: ["{DOMAIN_PROHIBIT}", "internal/*"]
    location: "internal/<domain>/models/  (kit Go example; resolved from {SOURCE_GLOB})"

  - layer: api/handlers
    rule: "Handlers do NOT import data access layer directly (per {LAYER_RULE})"
    forbidden: ["{data_access_package}", "{repository_package}"]
    allowed: ["internal/<domain>/*"]

  - layer: domain/controller
    rule: "Controllers import data access layer, models, domain services (per {LAYER_RULE})"
    allowed: ["{data_access_package}", "*/models", "*/services"]
