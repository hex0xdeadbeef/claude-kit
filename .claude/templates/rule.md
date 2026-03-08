meta:
  type: "rule"
  purpose: "Template for creating rule artifacts in Claude Code format"
  source: "Claude Code docs: https://code.claude.com/docs/en/memory"
  note: |
    IMPORTANT: Rules are a standard Claude Code format. Like skills, they use
    YAML frontmatter (---) + Markdown body. NOT YAML-only.
    Claude loads rules automatically:
      - Without paths: -> globally (for all files)
      - With paths: -> conditionally (only when Claude works with matching files)

# ════════════════════════════════════════════════════════════════════════════════
# OUTPUT FORMAT — what meta-agent should generate
# ════════════════════════════════════════════════════════════════════════════════

template:
  file_path: ".claude/rules/<name>.md"
  naming: "kebab-case, descriptive name — testing.md, api-design.md, error-handling.md"

  # ── Rule .md file structure ──
  # Level 1: YAML Frontmatter (paths: for conditional loading)
  # Level 2: Markdown Body (instructions, checklists, examples)

  output_format: |
    ---
    paths:
      - "<glob-pattern-1>"
      - "<glob-pattern-2>"
    ---

    # <Rule Name>

    <Brief description: what these rules are and when they apply.>

    ## Checklist

    - <Specific, actionable check item 1>
    - <Check item 2>
    - <Check item 3>

    ## Forbidden

    ### <What not to do>
    **Why:** <reason>

    **Bad:**
    ```<lang>
    <wrong code>
    ```

    **Good:**
    ```<lang>
    <correct code>
    ```

    ## References

    - See `@<skill-name>` for detailed patterns

  output_format_global: |
    # <Rule Name>

    <Brief description. This rule is loaded globally (without paths:).>

    ## Checklist

    - <Check item 1>
    - <Check item 2>

  note_on_global: |
    Rules without frontmatter are loaded for ALL files.
    Use sparingly — each global rule consumes context.

# ════════════════════════════════════════════════════════════════════════════════
# FRONTMATTER — field filling rules
# ════════════════════════════════════════════════════════════════════════════════

frontmatter:
  delimiters: "--- (three dashes, separate line, top and bottom)"
  optional: "Frontmatter can be omitted — then the rule will be global"

  fields:
    paths:
      required: false
      note: "If specified — rule is loaded conditionally. If NOT specified — globally."
      format: "YAML list with glob patterns in QUOTES"
      constraints:
        - "Glob patterns MUST be in quotes (YAML parsing issue)"
        - "Brace expansion is supported: {ts,tsx}, {src,lib}"
        - "Standard globs: ** (recursive), * (single level)"
        - "Multiple patterns can be specified as a YAML list"
      valid:
        - |
          paths:
            - "src/api/**/*.ts"
        - |
          paths:
            - "internal/**/*.go"
            - "pkg/**/*.go"
        - |
          paths:
            - "src/**/*.{ts,tsx}"
      invalid:
        - |
          paths: src/api/**/*.ts
          # ❌ Not in quotes — YAML parsing error for patterns with * and {}
        - |
          paths: ["src/**/*.ts"]
          # ⚠️ Inline list — works, but less readable
        - |
          globs:
            - "src/**/*.ts"
          # ❌ globs — this is a Cursor format, not Claude Code

  known_issues:
    - issue: "paths: sometimes does not work (GitHub issue #17204)"
      workaround: "Some users use globs: instead of paths:"
      recommendation: "Stick to paths: — this is the official format"
    - issue: "Unquoted glob patterns break YAML parsing (issue #13905)"
      fix: "ALWAYS wrap glob patterns in quotes"

# ════════════════════════════════════════════════════════════════════════════════
# MARKDOWN BODY — content writing rules
# ════════════════════════════════════════════════════════════════════════════════

body_guidelines:
  format: "Markdown — NOT YAML"
  structure:
    required_sections:
      - "# <Rule Name> — heading"
      - "Brief description (1-2 sentences)"
      - "## Checklist (3-7 specific items)"
    recommended_sections:
      - "## Forbidden (what NOT to do + Bad/Good examples)"
      - "## References (@skill references)"
    optional_sections:
      - "## Exceptions (when the rule does NOT apply)"
      - "## Examples (additional code examples)"

  best_practices:
    be_specific:
      good: "Use 2-space indentation for all YAML files"
      bad: "Format code properly"
      why: "Specific rules vs abstract instructions"

    actionable_checklist:
      good: |
        ## Checklist

        - All exported functions have doc comments
        - Error returns are wrapped with `fmt.Errorf("%s: %w", op, err)`
        - No `panic()` outside of `init()` functions
      bad: |
        ## Rules

        - Write good code
        - Handle errors
        - Document things
      why: "Verifiable items vs vague instructions"

    forbidden_with_examples:
      good: |
        ## Forbidden

        ### Direct database access from handlers
        **Why:** Violates layered architecture, impossible to test.

        **Bad:**
        ```go
        func HandleGetUser(w http.ResponseWriter, r *http.Request) {
            db.Query("SELECT * FROM users WHERE id = ?", id)
        }
        ```

        **Good:**
        ```go
        func HandleGetUser(svc UserService) http.HandlerFunc {
            return func(w http.ResponseWriter, r *http.Request) {
                user, err := svc.GetUser(r.Context(), id)
            }
        }
        ```
      bad: |
        forbidden:
          - "don't access DB directly"
      why: "Markdown + code blocks > YAML one-liners"

    keep_focused:
      principle: "One rule file = one topic"
      good: "testing.md — only about tests, api-design.md — only about API"
      bad: "all-rules.md — everything in one file"

# ════════════════════════════════════════════════════════════════════════════════
# QUALITY GATES — post-generation checks
# ════════════════════════════════════════════════════════════════════════════════

quality_gates:
  structural:
    - ".md file in .claude/rules/ (or subfolder)"
    - "If path-scoped: YAML frontmatter with --- delimiters"
    - "paths: values in QUOTES (YAML safety)"
    - "Body in Markdown format (NOT YAML)"
    - "File name in kebab-case, descriptive"

  content:
    - "Checklist: 3-7 specific, verifiable items"
    - "Each item is actionable (can be verified: yes/no)"
    - "Forbidden section with Bad/Good code examples"
    - "References to @skills if there are related patterns"

  scope:
    - "paths: patterns are precise (not **/*.go for everything)"
    - "No overlap of paths: with other rules"
    - "Global rules used sparingly (they consume context)"

# ════════════════════════════════════════════════════════════════════════════════
# EXAMPLES — good vs bad
# ════════════════════════════════════════════════════════════════════════════════

examples:
  good:
    description: "Valid Claude Code rule: frontmatter (paths:) + Markdown body"
    file_name: ".claude/rules/testing.md"
    content: |
      ---
      paths:
        - "internal/**/*_test.go"
        - "pkg/**/*_test.go"
      ---

      # Go Testing Standards

      Rules for all Go test files in this project.

      ## Checklist

      - Use table-driven tests for functions with multiple input/output cases
      - Test names follow `Test<Function>_<scenario>` pattern
      - Setup/teardown logic extracted to `testutil` helpers
      - No hardcoded test data — use test fixtures or builder functions
      - `t.Helper()` called in all test helper functions
      - Parallel tests where possible: `t.Parallel()` in subtests

      ## Forbidden

      ### Hardcoded test data
      **Why:** Makes tests brittle and hard to maintain.

      **Bad:**
      ```go
      func TestGetUser(t *testing.T) {
          user := User{ID: "123", Name: "John", Email: "john@test.com"}
          // ... 10 more hardcoded fields
      }
      ```

      **Good:**
      ```go
      func TestGetUser(t *testing.T) {
          user := testutil.NewUser(t, testutil.WithName("John"))
          // builder pattern — only specify what matters for this test
      }
      ```

      ### Testing unexported functions directly
      **Why:** Tests should verify behavior through public API.

      **Bad:**
      ```go
      func Test_parseConfig(t *testing.T) { // testing unexported
      ```

      **Good:**
      ```go
      func TestLoadConfig(t *testing.T) { // testing exported API
      ```

      ## References

      - See `@testing-patterns` for detailed table-driven test templates
      - See `@testutil` for available test builder functions

  good_global:
    description: "Valid global rule (without frontmatter) — loaded for all files"
    file_name: ".claude/rules/code-style.md"
    content: |
      # Code Style

      General code style rules for the entire project.

      ## Checklist

      - 2-space indentation for YAML, 4-space for Go (gofmt)
      - Line length: 120 chars max for Go, 100 for YAML
      - No trailing whitespace
      - Files end with a single newline

  bad:
    description: "Invalid rule — YAML body instead of Markdown"
    content: |
      meta:
        paths: "internal/**/*_test.go"

      see: ["@testing-patterns"]

      checklist:
        - "Table-driven tests"
        - "Descriptive test names"

      forbidden:
        - action: "hardcoded test data"
          why: "tests should be maintainable"
    problems:
      - "No --- frontmatter delimiters -> paths does not work"
      - "YAML body instead of Markdown -> Claude does not parse as rule instructions"
      - "paths: inside meta: instead of frontmatter -> Claude does not see scope"
      - "No specific code examples in forbidden"

  bad_2:
    description: "Prose-only without structure"
    content: |
      ---
      paths:
        - "internal/**/*_test.go"
      ---

      Tests should follow best practices and be maintainable.
      You should use table-driven tests when possible.
      Don't hardcode test data.
    problems:
      - "No headings (##) — hard to parse"
      - "Prose instead of checklist — not actionable"
      - "No code examples — abstract instructions"
      - "'best practices' — what exactly?"

  bad_3:
    description: "Unquoted glob patterns"
    content: |
      ---
      paths:
        - internal/**/*.go
        - {src,lib}/**/*.ts
      ---

      # Rules
      ...
    problems:
      - "Glob patterns without quotes -> YAML parsing error"
      - "{ and * — reserved YAML characters, require quotes"

# ════════════════════════════════════════════════════════════════════════════════
# DIFF: what changed vs old template
# ════════════════════════════════════════════════════════════════════════════════

changelog:
  version: "2.0.0"
  date: "2026-02-26"
  breaking_changes:
    - "Output format: YAML body -> Markdown body"
    - "paths: from meta: YAML -> into --- frontmatter"
    - "Good/bad examples inverted: old 'good' (YAML-only) is now 'bad'"
    - "checklist:/forbidden: YAML -> ## Checklist / ## Forbidden Markdown"
  additions:
    - "frontmatter field requirements (paths: format, quoting rules)"
    - "body_guidelines with best practices"
    - "quality_gates for validation"
    - "Global rule format (without frontmatter)"
    - "Known issues (GitHub #17204, #13905)"
    - "bad_3 example for unquoted globs"
  source: "Claude Code docs: https://code.claude.com/docs/en/memory"
