meta:
  type: "rule"
  purpose: "Template для создания rule артефактов в формате Claude Code"
  source: "Claude Code docs: https://code.claude.com/docs/en/memory"
  note: |
    ВАЖНО: Rules — это стандартный формат Claude Code. Как и skills, они используют
    YAML frontmatter (---) + Markdown body. НЕ YAML-only.
    Claude загружает rules автоматически:
      - Без paths: → глобально (для всех файлов)
      - С paths: → условно (только когда Claude работает с matching файлами)

# ════════════════════════════════════════════════════════════════════════════════
# OUTPUT FORMAT — что meta-agent должен генерировать
# ════════════════════════════════════════════════════════════════════════════════

template:
  file_path: ".claude/rules/<name>.md"
  naming: "kebab-case, описательное имя — testing.md, api-design.md, error-handling.md"

  # ── Структура rule .md файла ──
  # Level 1: YAML Frontmatter (paths: для conditional loading)
  # Level 2: Markdown Body (инструкции, чеклисты, примеры)

  output_format: |
    ---
    paths:
      - "<glob-pattern-1>"
      - "<glob-pattern-2>"
    ---

    # <Rule Name>

    <Краткое описание: что это за правила и когда они применяются.>

    ## Checklist

    - <Конкретный, actionable check item 1>
    - <Check item 2>
    - <Check item 3>

    ## Forbidden

    ### <What not to do>
    **Why:** <причина>

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

    <Краткое описание. Этот rule загружается глобально (без paths:).>

    ## Checklist

    - <Check item 1>
    - <Check item 2>

  note_on_global: |
    Rules без frontmatter загружаются для ВСЕХ файлов.
    Используй осторожно — каждый global rule расходует контекст.

# ════════════════════════════════════════════════════════════════════════════════
# FRONTMATTER — правила заполнения полей
# ════════════════════════════════════════════════════════════════════════════════

frontmatter:
  delimiters: "--- (три дефиса, отдельная строка, сверху и снизу)"
  optional: "Frontmatter можно не указывать — тогда rule будет глобальным"

  fields:
    paths:
      required: false
      note: "Если указано — rule загружается условно. Если НЕ указано — глобально."
      format: "YAML list с glob-паттернами в КАВЫЧКАХ"
      constraints:
        - "Glob-паттерны ОБЯЗАТЕЛЬНО в кавычках (YAML parsing issue)"
        - "Поддерживается brace expansion: {ts,tsx}, {src,lib}"
        - "Стандартные glob: ** (рекурсивно), * (один уровень)"
        - "Можно указать несколько паттернов как YAML list"
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
          # ❌ Не в кавычках — YAML parsing error для паттернов с * и {}
        - |
          paths: ["src/**/*.ts"]
          # ⚠️ Inline list — работает, но менее читаемый
        - |
          globs:
            - "src/**/*.ts"
          # ❌ globs — это формат Cursor, не Claude Code

  known_issues:
    - issue: "paths: иногда не работает (GitHub issue #17204)"
      workaround: "Некоторые пользователи используют globs: вместо paths:"
      recommendation: "Придерживаться paths: — это официальный формат"
    - issue: "Unquoted glob patterns break YAML parsing (issue #13905)"
      fix: "ВСЕГДА оборачивать glob-паттерны в кавычки"

# ════════════════════════════════════════════════════════════════════════════════
# MARKDOWN BODY — правила написания содержимого
# ════════════════════════════════════════════════════════════════════════════════

body_guidelines:
  format: "Markdown — НЕ YAML"
  structure:
    required_sections:
      - "# <Rule Name> — заголовок"
      - "Краткое описание (1-2 предложения)"
      - "## Checklist (3-7 конкретных пунктов)"
    recommended_sections:
      - "## Forbidden (что НЕ делать + Bad/Good примеры)"
      - "## References (@skill ссылки)"
    optional_sections:
      - "## Exceptions (когда правило НЕ применяется)"
      - "## Examples (дополнительные code examples)"

  best_practices:
    be_specific:
      good: "Use 2-space indentation for all YAML files"
      bad: "Format code properly"
      why: "Конкретные правила vs абстрактные указания"

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
      why: "Проверяемые пункты vs размытые указания"

    forbidden_with_examples:
      good: |
        ## Forbidden

        ### Direct database access from handlers
        **Why:** Нарушает layered architecture, невозможно тестировать.

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
      principle: "Один rule файл = одна тема"
      good: "testing.md — только про тесты, api-design.md — только про API"
      bad: "all-rules.md — всё в одном файле"

# ════════════════════════════════════════════════════════════════════════════════
# QUALITY GATES — проверки после генерации
# ════════════════════════════════════════════════════════════════════════════════

quality_gates:
  structural:
    - "Файл .md в .claude/rules/ (или подпапке)"
    - "Если path-scoped: YAML frontmatter с --- делимитерами"
    - "paths: значения в КАВЫЧКАХ (YAML safety)"
    - "Body в Markdown формате (НЕ YAML)"
    - "Имя файла в kebab-case, описательное"

  content:
    - "Checklist: 3-7 конкретных, проверяемых пунктов"
    - "Каждый пункт — actionable (можно проверить: да/нет)"
    - "Forbidden section с Bad/Good code примерами"
    - "References на @skills если есть связанные patterns"

  scope:
    - "paths: паттерны точные (не **/*.go для всего)"
    - "Нет пересечения paths: с другими rules"
    - "Global rules используются осторожно (расходуют контекст)"

# ════════════════════════════════════════════════════════════════════════════════
# ПРИМЕРЫ — good vs bad
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
    description: "Valid global rule (без frontmatter) — загружается для всех файлов"
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
    description: "Невалидный rule — YAML body вместо Markdown"
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
      - "Нет --- frontmatter делимитеров → paths не работает"
      - "YAML body вместо Markdown → Claude не парсит как rule instructions"
      - "paths: внутри meta: вместо frontmatter → Claude не видит scope"
      - "Нет конкретных code examples в forbidden"

  bad_2:
    description: "Prose-only без структуры"
    content: |
      ---
      paths:
        - "internal/**/*_test.go"
      ---

      Tests should follow best practices and be maintainable.
      You should use table-driven tests when possible.
      Don't hardcode test data.
    problems:
      - "Нет заголовков (##) — трудно парсить"
      - "Prose вместо checklist — не actionable"
      - "Нет code examples — абстрактные указания"
      - "'best practices' — что именно?"

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
      - "Glob-паттерны без кавычек → YAML parsing error"
      - "{ и * — reserved YAML characters, требуют кавычки"

# ════════════════════════════════════════════════════════════════════════════════
# DIFF: что изменилось vs старый шаблон
# ════════════════════════════════════════════════════════════════════════════════

changelog:
  version: "2.0.0"
  date: "2026-02-26"
  breaking_changes:
    - "Output format: YAML body → Markdown body"
    - "paths: из meta: YAML → в --- frontmatter"
    - "Good/bad examples инвертированы: старый 'good' (YAML-only) теперь 'bad'"
    - "checklist:/forbidden: YAML → ## Checklist / ## Forbidden Markdown"
  additions:
    - "frontmatter field requirements (paths: format, quoting rules)"
    - "body_guidelines с best practices"
    - "quality_gates для валидации"
    - "Global rule формат (без frontmatter)"
    - "Known issues (GitHub #17204, #13905)"
    - "bad_3 example для unquoted globs"
  source: "Claude Code docs: https://code.claude.com/docs/en/memory"
