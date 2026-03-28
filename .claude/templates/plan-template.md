meta:
  type: "plan-template"
  purpose: "Implementation plan template — output of /planner, input to /plan-review"
  usage: "Fill placeholders → save as plan.md → pass to /plan-review"

plan:
  title: "{Feature Name}"

  context:
    summary: "{Brief description and business value}"

  scope:
    in:
      - "{Functionality 1}"
      - "{Functionality 2}"
    out:
      - item: "{What is excluded}"
        reason: "{Why}"

  dependencies:
    blocks: []                # tasks this blocks
    blocked_by: []            # tasks blocking this

  architecture:
    decision: "{Chosen approach — describe if Sequential Thinking was used}"
    alternatives:
      - option: "{Alternative 1}"
        rejected_because: "{Why not chosen}"
      - option: "{Alternative 2}"
        rejected_because: "{Why not chosen}"
    chosen:
      approach: "{Approach}"
      rationale: "{Rationale}"

  parts:
    - part: 1
      name: "{Name}"
      file: "path/to/file.go"
      action: "CREATE"  # CREATE | UPDATE
      description: "{What this part does}"
      code: |
        package example

        func Example() {
            // ...
        }

    - part: 2
      name: "{Name}"
      file: "path/to/file.go"
      action: "UPDATE"
      description: "{What this part does}"
      code: |
        // full code example

    - part: N
      name: "Tests"
      file: "path/to/file_test.go"
      action: "CREATE"
      description: "Tests for new functionality"
      code: |
        func TestExample(t *testing.T) {
            tests := []struct {
                name    string
                input   string
                want    string
                wantErr bool
            }{
                // ...
            }
            for _, tt := range tests {
                t.Run(tt.name, func(t *testing.T) {
                    // ...
                })
            }
        }

  files_summary:
    - file: "path/to/file1.go"
      action: "CREATE"
      description: "{description}"
    - file: "path/to/file2.go"
      action: "UPDATE"
      description: "{description}"

  acceptance_criteria:
    functional:
      - "{Criterion 1}"
      - "{Criterion 2}"
    technical:
      - "{build_check_command} passes"
      - "{test_command} passes"
      - "Coverage >= 70%"
      - "No security vulnerabilities"
    architecture:
      - "Import matrix respected"
      - "Clean domain (no serialization tags in domain entities)"
      - "Error handling follows project conventions"

  config_changes:
    - path: "config.yaml.example"
      changes: |
        new_section:
          param: value  # description
    - path: "README.md"
      changes: "Update configuration table"

  notes: "{Additional notes, edge cases, known limitations}"
