meta:
  type: "skill"
  purpose: "Template для создания skill артефактов в формате Claude Skills"
  source: "The Complete Guide to Building Skills for Claude (Anthropic, 2026)"
  note: |
    ВАЖНО: Skills — это стандартный формат Anthropic. В отличие от commands/agents,
    здесь НЕЛЬЗЯ использовать AI-first YAML-only подход. Claude ожидает:
      1. YAML frontmatter в `---` делимитерах (загружается в system prompt)
      2. Markdown body с инструкциями (загружается когда skill активен)
      3. Опционально: scripts/, references/, assets/ подпапки

# ════════════════════════════════════════════════════════════════════════════════
# OUTPUT FORMAT — что meta-agent должен генерировать
# ════════════════════════════════════════════════════════════════════════════════

template:
  # Skill — это ПАПКА, не просто файл
  folder_path: ".claude/skills/<name>/"
  main_file: ".claude/skills/<name>/SKILL.md"
  optional_dirs:
    scripts: "Executable code (Python, Bash, etc.) — вызывается из инструкций"
    references: "Detailed documentation — загружается по ссылке из SKILL.md"
    assets: "Templates, fonts, icons — используется в output"

  # ── Структура SKILL.md ──
  # Level 1: YAML Frontmatter (всегда в system prompt Claude)
  # Level 2: Markdown Body (загружается когда skill активен)
  # Level 3: Linked files (подгружаются по необходимости)

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
# FRONTMATTER — правила заполнения полей
# ════════════════════════════════════════════════════════════════════════════════

frontmatter:
  delimiters: "--- (три дефиса, отдельная строка, сверху и снизу)"

  fields:
    name:
      required: true
      format: "kebab-case only"
      constraints:
        - "Без пробелов, без заглавных букв, без подчёркиваний"
        - "Должен совпадать с именем папки"
        - "Без 'claude' или 'anthropic' в имени"
      valid: ["error-patterns", "api-design", "go-testing"]
      invalid: ["Error Patterns", "error_patterns", "ErrorPatterns", "claude-helper"]

    description:
      required: true
      max_length: 1024
      format: "[What it does] + [When to use it] + [Key capabilities]"
      constraints:
        - "MUST include WHAT the skill does"
        - "MUST include WHEN to use (trigger conditions / user phrases)"
        - "Без XML тегов (< или >)"
        - "Упоминать конкретные задачи, которые пользователь может попросить"
        - "Упоминать file types если применимо"
      good_examples:
        - |
          # Конкретный + trigger phrases
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
          why: "Слишком абстрактно — Claude не поймёт когда загружать"
        - value: "Creates sophisticated multi-page documentation systems."
          why: "Нет trigger phrases — пользователь не знает что сказать"
        - value: "Implements the Project entity model with hierarchical relationships."
          why: "Техническое описание без user-facing triggers"

    license:
      required: false
      note: "Указать если skill будет open source"
      values: ["MIT", "Apache-2.0"]

    compatibility:
      required: false
      max_length: 500
      note: "Среда выполнения: intended product, required packages, network access"

    metadata:
      required: false
      note: "Произвольные key-value пары"
      suggested: ["author", "version", "mcp-server"]

  forbidden:
    - "XML angle brackets (< >) в frontmatter"
    - "'claude' или 'anthropic' в name"
    - "Многострочные значения без proper YAML quoting"

# ════════════════════════════════════════════════════════════════════════════════
# MARKDOWN BODY — правила написания инструкций
# ════════════════════════════════════════════════════════════════════════════════

body_guidelines:
  structure:
    required_sections:
      - "# <Skill Name>"
      - "## Instructions (пошаговые шаги)"
    recommended_sections:
      - "## Rules (MUST-DO / MUST-NOT-DO)"
      - "## Examples (good/bad pairs с объяснением)"
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
      why: "Конкретные команды и error cases vs абстрактное указание"

    reference_bundled_files:
      good: |
        Before writing queries, consult `references/api-patterns.md` for:
        - Rate limiting guidance
        - Pagination patterns
        - Error codes and handling
      bad: "Check the documentation for details."
      why: "Явная ссылка на bundled file vs неопределённая отсылка"

    include_error_handling:
      good: |
        ## Common Issues

        ### MCP Connection Failed
        If you see "Connection refused":
        1. Verify MCP server is running: Check Settings > Extensions
        2. Confirm API key is valid
        3. Try reconnecting: Settings > Extensions > [Service] > Reconnect
      bad: "Handle errors appropriately."
      why: "Конкретные шаги recovery vs пустое указание"

    progressive_disclosure:
      principle: "SKILL.md — core instructions. Детали в references/"
      example: |
        Если инструкции по одному разделу > 50 строк:
        1. Вынести детали в references/<section>.md
        2. В SKILL.md сослаться: "For detailed API patterns, see `references/api-patterns.md`"
      max_skill_md_size: "~5000 words recommended"

    avoid_ambiguity:
      good: |
        CRITICAL: Before calling create_project, verify:
        - Project name is non-empty
        - At least one team member assigned
        - Start date is not in the past
      bad: "Make sure to validate things properly."
      why: "CRITICAL + checklist vs размытое указание"

# ════════════════════════════════════════════════════════════════════════════════
# QUALITY GATES — проверки после генерации
# ════════════════════════════════════════════════════════════════════════════════

quality_gates:
  structural:
    - "Папка named in kebab-case"
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
# ПРИМЕРЫ — good vs bad
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
      - "Нет --- frontmatter делимитеров → Claude не загрузит как skill"
      - "Чистый YAML вместо Markdown body → не соответствует формату Skills"
      - "Нет секции Instructions → Claude не знает пошаговый workflow"
      - "Нет секции Common Issues → нет error handling guidance"
      - "description в meta: вместо frontmatter → невалидная структура"

  bad_2:
    description: "Prose-only без структуры — другая крайность"
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
      - "description слишком короткий — нет trigger phrases, нет keywords"
      - "Prose без ## headers → трудно парсить, нет структуры"
      - "Нет конкретных примеров кода (good/bad)"
      - "Нет Rules секции — нет чётких do/don't"
      - "Нет Common Issues — нет troubleshooting"

# ════════════════════════════════════════════════════════════════════════════════
# DIFF: что изменилось vs старый шаблон
# ════════════════════════════════════════════════════════════════════════════════

changelog:
  version: "2.0.0"
  date: "2026-02-26"
  breaking_changes:
    - "Output format: pure YAML → YAML frontmatter + Markdown body"
    - "Good/bad examples inverted: old 'good' (YAML-only) now 'bad'"
    - "folder_path вместо file_path: skill = папка, не файл"
  additions:
    - "frontmatter field requirements (name, description format)"
    - "body_guidelines с best practices из Anthropic guide"
    - "quality_gates для валидации после генерации"
    - "description_guide с good/bad примерами"
    - "folder_structure с optional dirs (scripts/, references/, assets/)"
  source: "The Complete Guide to Building Skills for Claude, Chapters 1-2, 5"
