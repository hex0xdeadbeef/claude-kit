# Required Sections Validation

purpose: "Plan template compliance checklist - verify all required sections present"

reference: ".claude/templates/plan-template.md"

## Sections Checklist

```yaml
required_sections:
  - section: Context
    required: ALWAYS
    validate:
      - present: true
      - has_business_value: "Explains WHY feature needed"
      - clear_scope: "Understandable without external context"

  - section: "Scope (IN/OUT)"
    required: ALWAYS
    validate:
      - in_items: "≥1 item clearly scoped"
      - out_items_with_reasons: "Each OUT has explanation WHY excluded"
      - no_ambiguity: "Clear boundary of what's included/excluded"

  - section: Dependencies
    required: OPTIONAL
    validate:
      - blocking_issues: "List what must complete first"
      - blocked_issues: "List what this blocks"

  - section: "Architecture Decision"
    required: IF_SEQUENTIAL_THINKING
    validate:
      - alternatives_documented: "≥2 approaches considered"
      - chosen_approach_justified: "Clear rationale for choice"
      - tradeoffs_listed: "Pros/cons of chosen approach"

  - section: Parts
    required: ALWAYS
    validate:
      - ordered_correctly: "Parts follow dependency direction (lower layers first per project structure)"
        reference: "SEE: PROJECT-KNOWLEDGE.md for project-specific layer order (if available)"
      - full_code_examples: "Complete, runnable code (not snippets)"
      - imports_listed: "All imports shown"

  - section: "Files Summary"
    required: ALWAYS
    validate:
      - all_files_listed: "Every file from Parts section"
      - action_specified: "CREATE or UPDATE for each"
      - paths_absolute: "Full paths from project root"

  - section: "Acceptance Criteria"
    required: ALWAYS
    validate:
      - functional: "≥1 functional criterion (feature works)"
      - technical: "≥1 technical criterion (tests pass, no warnings)"
      - architecture: "≥1 architecture criterion (layer rules followed)"

  - section: "Config Changes"
    required: IF_CONFIG_TOUCHED
    validate:
      - config_example_updated: "CONFIG_EXAMPLE has new fields (Go default: config.yaml.example)"
      - config_docs_updated: "CONFIG_DOCS documents new config (Go default: README.md)"
      - example_values: "Sensible defaults provided"
```

## Validation Logic

```yaml
validation_flow:
  - step: 1
    action: "Read plan file"
    tool: "Read"

  - step: 2
    action: "Extract section headers (## Section Name)"
    tool: "Grep '^## '"

  - step: 3
    action: "Check each required section present"
    logic: |
      for section in required_sections:
        if section.required == ALWAYS or condition_met(section.required):
          if not found_in_plan(section.name):
            add_issue(severity=BLOCKER, message=f"Missing required section: {section.name}")

  - step: 4
    action: "Validate section content"
    logic: |
      for section in found_sections:
        for check in section.validate:
          if not check.passes:
            add_issue(severity=MAJOR, message=check.failure_message)
```

## Common Issues

```yaml
common_issues:
  - issue: "Context missing business value"
    example_bad: "Add endpoint for operations"
    example_good: "Add {feature} endpoint to enable {business_value} per project requirements"
    severity: MAJOR

  - issue: "OUT items without reasons"
    example_bad: |
      OUT:
      - Bind/Unbind endpoints
    example_good: |
      OUT:
      - {Related feature} (tracked separately, requires own research)
    severity: MAJOR

  - issue: "Parts not ordered by dependency"
    example_bad: "API → Controller → Database"
    example_good: "Database → Models → Controller → API"
    severity: BLOCKER
    why: "Implementation order must follow dependency direction"

  - issue: "Code snippets instead of full examples"
    example_bad: |
      func GetByID(...) {
        // implementation
      }
    example_good: |
      func (s *Service) GetByID(ctx context.Context, id string) (*models.Entity, error) {
        result, err := s.repo.Get(ctx, id)
        if err != nil {
          return nil, fmt.Errorf("get entity: %w", err)
        }
        return result, nil
      }
    severity: MAJOR
```
