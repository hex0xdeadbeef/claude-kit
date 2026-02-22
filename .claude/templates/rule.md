meta:
  type: "rule"
  purpose: "Template для создания rule артефактов"

template:
  file_path: ".claude/rules/<name>.md"

  structure:
    meta:
      paths: "<glob-pattern>"

    see: ["@skill1", "@skill2"]

    checklist:
      - "<check item 1>"
      - "<check item 2>"
      - "<check item 3>"

    forbidden:
      - action: "<what not to do>"
        why: "<reason>"
        example: "<code example>"

examples:
  good:
    description: "Clear checklist + forbidden examples"
    content: |
      meta:
        paths: "internal/**/*_test.go"

      see: ["@testing-patterns"]

      checklist:
        - "Table-driven tests"
        - "Descriptive test names"
        - "Setup/teardown in helpers"

      forbidden:
        - action: "hardcoded test data"
          why: "tests should be maintainable"
          example: |
            // BAD
            func TestUser(t *testing.T) {
                user := User{ID: "123", Name: "John"}
            }

            // GOOD
            func TestUser(t *testing.T) {
                user := newTestUser(t)
            }

  bad:
    description: "Prose without checklist"
    content: |
      ---
      paths: internal/**/*_test.go
      ---

      # Testing

      Tests should follow best practices and be maintainable.
      You should use table-driven tests when possible...

      (prose instead of checklist, no forbidden examples)
    why: "prose instead of checklist, no examples"
