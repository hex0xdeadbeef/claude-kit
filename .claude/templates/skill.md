meta:
  type: "skill"
  purpose: "Template for creating skill artifacts in Claude Skills format"
  source: "The Complete Guide to Building Skills for Claude (Anthropic, 2026)"
  note: |
    IMPORTANT: Skills are a standard Anthropic format. Unlike commands/agents,
    the AI-first YAML-only approach CANNOT be used here. Claude expects:
      1. YAML frontmatter in `---` delimiters (loaded into system prompt)
      2. Markdown body with instructions (loaded when skill is active)
      3. Optionally: scripts/, references/, assets/ subfolders

# ════════════════════════════════════════════════════════════════════════════════
# OUTPUT FORMAT — what meta-agent should generate
# ════════════════════════════════════════════════════════════════════════════════

template:
  # Skill is a FOLDER, not just a file
  folder_path: ".claude/skills/<name>/"
  main_file: ".claude/skills/<name>/SKILL.md"
  optional_dirs:
    scripts: "Executable code (Python, Bash, etc.) — called from instructions"
    references: "Detailed documentation — loaded by reference from SKILL.md"
    assets: "Templates, fonts, icons — used in output"

  # ── SKILL.md structure ──
  # Level 1: YAML Frontmatter (always in Claude's system prompt)
  # Level 2: Markdown Body (loaded when skill is active)
  # Level 3: Linked files (loaded as needed)

  output_format: |
    ---
    name: <name>
    description: <description>
    ---

    # <Skill Name>

    ## Instructions

    ### Step 1: <First Major Step>
    <Clear explanation of what happens.>

    ### Step 2: <Next Step>
    <Concrete, actionable instructions.>

    ## Rules

    - <MUST-DO or MUST-NOT-DO rule 1>
    - <Rule 2>

    ## Examples

    ### <Pattern Name>

    **Good:**
    ```<lang>
    <correct code>
    ```

    **Bad:**
    ```<lang>
    <wrong code>
    ```
    **Why:** <explanation>

    ## Common Issues

    ### <Error or Problem>
    **Cause:** <why it happens>
    **Fix:** <how to resolve>

# ════════════════════════════════════════════════════════════════════════════════
# FRONTMATTER — field filling rules
# ════════════════════════════════════════════════════════════════════════════════

frontmatter:
  delimiters: "--- (three dashes, separate line, top and bottom)"

  fields:
    name:
      required: true
      format: "kebab-case only"
      constraints:
        - "No spaces, no capital letters, no underscores"
        - "Must match the folder name"
        - "No 'claude' or 'anthropic' in the name"
      valid: ["error-patterns", "api-design", "go-testing"]
      invalid: ["Error Patterns", "error_patterns", "ErrorPatterns", "claude-helper"]

    description:
      required: true
      max_length: 1024
      format: "[What it does] + [When to use it] + [Key capabilities]"
      constraints:
        - "MUST include WHAT the skill does"
        - "MUST include WHEN to use (trigger conditions / user phrases)"
        - "No XML tags (< or >)"
        - "Mention specific tasks that the user may request"
        - "Mention file types if applicable"
      good_examples:
        - |
          # Specific + trigger phrases
          description: Analyzes Figma design files and generates developer handoff
            documentation. Use when user uploads .fig files, asks for "design specs",
            "component documentation", or "design-to-code handoff".
        - |
          # Value proposition + keywords
          description: Go error handling patterns — wrapping, sentinel errors, custom
            types. Use when working with error handling, asks about "wrap errors",
            "error types", or "error context". Keywords: error, wrap, sentinel, fmt.Errorf.
        - |
          # Scope clarification
          description: PayFlow payment processing for e-commerce. Use specifically for
            online payment workflows, not for general financial queries.
      bad_examples:
        - value: "Helps with projects."
          why: "Too abstract — Claude will not understand when to load"
        - value: "Creates sophisticated multi-page documentation systems."
          why: "No trigger phrases — user does not know what to say"
        - value: "Implements the Project entity model with hierarchical relationships."
          why: "Technical description without user-facing triggers"

    license:
      required: false
      note: "Specify if the skill will be open source"
      values: ["MIT", "Apache-2.0"]

    compatibility:
      required: false
      max_length: 500
      note: "Runtime environment: intended product, required packages, network access"

    metadata:
      required: false
      note: "Arbitrary key-value pairs"
      suggested: ["author", "version", "mcp-server"]

  forbidden:
    - "XML angle brackets (< >) in frontmatter"
    - "'claude' or 'anthropic' in name"
    - "Multiline values without proper YAML quoting"

# ════════════════════════════════════════════════════════════════════════════════
# MARKDOWN BODY — instruction writing rules
# ════════════════════════════════════════════════════════════════════════════════

body_guidelines:
  structure:
    required_sections:
      - "# <Skill Name>"
      - "## Instructions (step-by-step steps)"
    recommended_sections:
      - "## Rules (MUST-DO / MUST-NOT-DO)"
      - "## Examples (good/bad pairs with explanation)"
      - "## Common Issues (troubleshooting)"
    optional_sections:
      - "## Performance Notes (encourage thoroughness)"
      - "## References (links to references/ files)"

  best_practices:
    be_specific:
      good: |
        Run `python scripts/validate.py --input {filename}` to check data format.
        If validation fails, common issues include:
        - Missing required fields (add them to the CSV)
        - Invalid date formats (use YYYY-MM-DD)
      bad: "Validate the data before proceeding."
      why: "Specific commands and error cases vs abstract instruction"

    reference_bundled_files:
      good: |
        Before writing queries, consult `references/api-patterns.md` for:
        - Rate limiting guidance
        - Pagination patterns
        - Error codes and handling
      bad: "Check the documentation for details."
      why: "Explicit reference to bundled file vs vague reference"

    include_error_handling:
      good: |
        ## Common Issues

        ### MCP Connection Failed
        If you see "Connection refused":
        1. Verify MCP server is running: Check Settings > Extensions
        2. Confirm API key is valid
        3. Try reconnecting: Settings > Extensions > [Service] > Reconnect
      bad: "Handle errors appropriately."
      why: "Specific recovery steps vs empty instruction"

    progressive_disclosure:
      principle: "SKILL.md — core instructions. Details in references/"
      example: |
        If instructions for a single section exceed 50 lines:
        1. Move details to references/<section>.md
        2. Reference from SKILL.md: "For detailed API patterns, see `references/api-patterns.md`"
      max_skill_md_size: "~5000 words recommended"

    avoid_ambiguity:
      good: |
        CRITICAL: Before calling create_project, verify:
        - Project name is non-empty
        - At least one team member assigned
        - Start date is not in the past
      bad: "Make sure to validate things properly."
      why: "CRITICAL + checklist vs vague instruction"

# ════════════════════════════════════════════════════════════════════════════════
# QUALITY GATES — post-generation checks
# ════════════════════════════════════════════════════════════════════════════════

quality_gates:
  structural:
    - "Folder named in kebab-case"
    - "SKILL.md exists (exact case-sensitive spelling)"
    - "YAML frontmatter has --- delimiters (top and bottom)"
    - "name field: kebab-case, no spaces, no capitals, matches folder name"
    - "description: includes WHAT + WHEN, under 1024 chars"
    - "No XML tags (< or >) anywhere in frontmatter"
    - "No README.md inside skill folder"

  content:
    - "Instructions are clear and actionable (specific commands, not vague)"
    - "At least one good/bad example pair with 'why'"
    - "Error handling / Common Issues section present"
    - "References clearly linked if bundled files exist"

  trigger_testing:
    should_trigger:
      - "Obvious task matching skill description"
      - "Paraphrased request"
    should_not_trigger:
      - "Unrelated topic"
      - "Similar-sounding but different domain"

# ════════════════════════════════════════════════════════════════════════════════
# EXAMPLES — good vs bad
# ════════════════════════════════════════════════════════════════════════════════

examples:
  good:
    description: "Valid Claude skill: frontmatter + structured markdown body"
    folder_structure: |
      .claude/skills/error-patterns/
      ├── SKILL.md
      └── references/
          └── sentinel-errors.md    # detailed guide, linked from SKILL.md
    content: |
      ---
      name: error-patterns
      description: Go error handling patterns — wrapping, sentinel errors, custom types.
        Use when working with error handling, user asks about "wrap errors", "error types",
        "error context", or reviews code with error handling. Keywords: error, wrap, sentinel.
      ---

      # Error Patterns

      ## Instructions

      ### Step 1: Identify the error pattern needed
      Check which error handling pattern is required:
      - **Wrapping**: Adding context to propagated errors (`fmt.Errorf`)
      - **Sentinel**: Package-level errors for comparison (`errors.Is`)
      - **Custom type**: Errors with structured data (`errors.As`)

      ### Step 2: Apply the pattern
      Use the appropriate pattern from the examples below. Wrap all errors with
      the operation name for debuggability.

      ### Step 3: Verify error chain
      Ensure the error chain is preserved — callers must be able to use
      `errors.Is()` and `errors.As()` on wrapped errors.

      ## Rules

      - ALWAYS wrap errors with operation context: `fmt.Errorf("%s: %w", op, err)`
      - NEVER log AND return the same error — pick one
      - NEVER use `errors.New()` for dynamic messages — use `fmt.Errorf()`
      - For sentinel errors, declare at package level as `var ErrNotFound = errors.New("not found")`

      ## Examples

      ### Error Wrapping

      **Good:**
      ```go
      func (s *UserService) GetUser(ctx context.Context, id string) (*User, error) {
          const op = "UserService.GetUser"
          user, err := s.repo.Find(ctx, id)
          if err != nil {
              return nil, fmt.Errorf("%s: %w", op, err)
          }
          return user, nil
      }
      ```

      **Bad:**
      ```go
      func (s *UserService) GetUser(ctx context.Context, id string) (*User, error) {
          user, err := s.repo.Find(ctx, id)
          if err != nil {
              log.Error(err)        // logging
              return nil, err       // AND returning — duplicate
          }
          return user, nil
      }
      ```
      **Why:** log AND return creates duplicate log entries up the call stack.
      The caller will also log this error, producing noise.

      ### Sentinel Errors

      **Good:**
      ```go
      // Package-level declaration
      var ErrUserNotFound = errors.New("user not found")

      // In function
      if user == nil {
          return nil, fmt.Errorf("%s: %w", op, ErrUserNotFound)
      }

      // Caller checks
      if errors.Is(err, ErrUserNotFound) {
          // handle specifically
      }
      ```

      **Bad:**
      ```go
      if user == nil {
          return nil, errors.New("user not found")  // new instance every time
      }

      // Caller CANNOT use errors.Is() — different instance each time
      ```
      **Why:** `errors.New()` in function body creates unique instances that
      cannot be compared with `errors.Is()`. Sentinel errors must be package-level vars.

      ## Common Issues

      ### Error: "errors.Is() returns false for wrapped error"
      **Cause:** Used `fmt.Errorf("context: %v", err)` instead of `%w`
      **Fix:** Replace `%v` with `%w` — only `%w` preserves the error chain

      ### Error: "duplicate log entries for same error"
      **Cause:** Multiple layers log AND return
      **Fix:** Pick one strategy per layer. Typically: return at domain, log at handler.

      For detailed patterns on sentinel errors, see `references/sentinel-errors.md`.

  bad:
    description: "Invalid skill — no frontmatter, prose-only, no structure"
    content: |
      meta:
        name: errors
        description: |
          Error handling rules

          Load when:
          - Working with errors
          Keywords: error, wrap, context

      rules:
        - id: 1
          rule: "Wrap errors with context"
          pattern: "fmt.Errorf('%s: %w', op, err)"

      examples:
        error_wrap:
          bad: "log.Error(err); return err"
          good: "return fmt.Errorf('op: %w', err)"
          why: "log AND return = duplicate"
    problems:
      - "No --- frontmatter delimiters -> Claude will not load as skill"
      - "Pure YAML instead of Markdown body -> does not match Skills format"
      - "No Instructions section -> Claude does not know the step-by-step workflow"
      - "No Common Issues section -> no error handling guidance"
      - "description in meta: instead of frontmatter -> invalid structure"

  bad_2:
    description: "Prose-only without structure — the other extreme"
    content: |
      ---
      name: errors
      description: Error handling
      ---

      When you handle errors, you should wrap them with context.
      This helps with debugging because you can see the call stack.
      Also, avoid logging and returning at the same time because
      it creates duplicate entries in the logs...
    problems:
      - "description too short — no trigger phrases, no keywords"
      - "Prose without ## headers -> hard to parse, no structure"
      - "No specific code examples (good/bad)"
      - "No Rules section — no clear do/don't"
      - "No Common Issues — no troubleshooting"

# ════════════════════════════════════════════════════════════════════════════════
# DIFF: what changed vs old template
# ════════════════════════════════════════════════════════════════════════════════

changelog:
  version: "2.0.0"
  date: "2026-02-26"
  breaking_changes:
    - "Output format: pure YAML -> YAML frontmatter + Markdown body"
    - "Good/bad examples inverted: old 'good' (YAML-only) now 'bad'"
    - "folder_path instead of file_path: skill = folder, not file"
  additions:
    - "frontmatter field requirements (name, description format)"
    - "body_guidelines with best practices from Anthropic guide"
    - "quality_gates for post-generation validation"
    - "description_guide with good/bad examples"
    - "folder_structure with optional dirs (scripts/, references/, assets/)"
  source: "The Complete Guide to Building Skills for Claude, Chapters 1-2, 5"
