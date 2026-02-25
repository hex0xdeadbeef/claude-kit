# Coder Examples

# ════════════════════════════════════════════════════════════════════════════════
# UNIVERSAL PATTERNS (apply to any Go project)
# ════════════════════════════════════════════════════════════════════════════════
examples:
  log_and_return:
    # SEE: deps/code-review/examples.md#log_and_return (full bad/good/why + grep pattern)
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
    why: "RULE_3: Domain entities must be pure - no encoding/json tags. Tags belong in DTOs."

  handler_imports_database:
    bad: |
      import "{data_access_package}"  # Direct DB access from handler
    good: |
      import "internal/<domain>"  # Use domain controller
    why: "RULE_2: Handlers must not import database directly. Use domain controllers."
    note: "SEE: PROJECT-KNOWLEDGE.md#Dependency Matrix for project-specific allowed imports (if available)"

# ════════════════════════════════════════════════════════════════════════════════
# LAYER IMPORT RULES (generic patterns)
# ════════════════════════════════════════════════════════════════════════════════
layer_import_checks:
  note: "For project-specific package names, SEE: PROJECT-KNOWLEDGE.md#Dependency Matrix (if available)"

  - layer: models
    rule: "Models import only stdlib (NOT encoding/json)"
    forbidden: ["encoding/json", "internal/*"]
    location: "internal/<domain>/models/"

  - layer: api/handlers
    rule: "Handlers do NOT import data access layer directly"
    forbidden: ["{data_access_package}", "{repository_package}"]
    allowed: ["internal/<domain>/*"]

  - layer: domain/controller
    rule: "Controllers import data access layer, models, domain services"
    allowed: ["{data_access_package}", "*/models", "*/services"]
