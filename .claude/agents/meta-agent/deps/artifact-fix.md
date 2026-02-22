meta:
  name: artifact-fix
  description: |
    Исправление Claude Code артефакта по результатам ревью.
    Линейный workflow с inline reference секциями.
  input: "Issues из /artifact-review или code review"
  output: "Исправленный артефакт + changelog"
  see: "artifact-quality.md"

workflow: "LOAD → PRIORITIZE → FIX → VERIFY → OUTPUT → INTEGRATE → MEMORY → LESSONS → FINAL"

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 1: LOAD ISSUES
# ════════════════════════════════════════════════════════════════════════════════
phase_1_load:
  purpose: "Загрузить список issues из источника"

  steps:
    - step: "1.1 Parse Issues"
      sources:
        - "/artifact-review output"
        - "code review comments"
        - "manual issue list"
      extract:
        - field: "issue_id"
        - field: "issue_description"
        - field: "severity"
        - field: "location"
        - field: "fix_required"

    - step: "1.2 Build Issues Table"
      format:
        columns: ["#", "Issue", "Severity", "Location", "Fix Required"]

  output_format: |
    ## Phase 1: LOAD — DONE
    ### Issues Table
    | # | Issue | Severity | Location | Fix |
    |---|-------|----------|----------|-----|
    | 1 | ...   | ...      | ...      | ... |

    - Total: [N] issues

  exit_criteria: "Все issues извлечены и записаны в таблицу"

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 2: PRIORITIZE
# ════════════════════════════════════════════════════════════════════════════════
phase_2_prioritize:
  purpose: "Определить порядок исправления"

  steps:
    - step: "2.1 Sort by Severity"
      use_reference: "severity_levels"
      order: "CRITICAL → HIGH → MEDIUM → LOW"

    - step: "2.2 Check Stop Conditions"
      rule: "Если CRITICAL/HIGH не могут быть исправлены → STOP"
      output: "can_proceed: true/false"

  output_format: |
    ## Phase 2: PRIORITIZE — DONE
    ### Fix Order
    1. [CRITICAL issues]
    2. [HIGH issues]
    3. [MEDIUM issues]
    4. [LOW issues]

    - Can proceed: [YES/NO]

  exit_criteria: "Порядок определён, stop conditions проверены"

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 3: FIX
# ════════════════════════════════════════════════════════════════════════════════
phase_3_fix:
  purpose: "Применить исправления к артефакту"

  steps:
    - step: "3.1 For Each Issue (by priority)"
      actions:
        - "Найти location в файле"
        - "Применить fix (use Edit tool)"
        - "Записать в changelog"

    - step: "3.2 Apply Fix Patterns"
      use_reference: "fix_patterns"
      for_each_issue:
        - "Match issue type to fix pattern"
        - "Apply pattern"
        - "Record change"

  output_format: |
    ## Phase 3: FIX — DONE
    ### Changes Applied
    | # | Issue | Fix Applied | Status |
    |---|-------|-------------|--------|
    | 1 | ...   | ...         | ✅     |

    ### Changelog
    ```diff
    - old content
    + new content
    ```

  exit_criteria: "Все HIGH/CRITICAL исправлены, changelog записан"

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 4: VERIFY
# ════════════════════════════════════════════════════════════════════════════════
phase_4_verify:
  purpose: "Проверить что исправления работают"

  steps:
    - step: "4.1 Re-check Quality"
      action: "Прогнать чеклист из artifact-quality.md"
      format:
        columns: ["Criterion", "Before", "After"]
      output: "quality_delta"

    - step: "4.2 Verify Each Fix"
      format:
        columns: ["#", "Issue", "Fixed", "Verified"]
      action: "Проверить что каждый fix действительно решает issue"

  output_format: |
    ## Phase 4: VERIFY — DONE
    ### Quality Score
    - Before: [X/5]
    - After: [Y/5]

    ### Verification
    | # | Issue | Fixed | Verified |
    |---|-------|-------|----------|
    | 1 | ...   | ✅    | ✅       |

  exit_criteria: "Quality score улучшился, все fixes verified"

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 5: OUTPUT
# ════════════════════════════════════════════════════════════════════════════════
phase_5_output:
  purpose: "Сформировать отчёт об исправлениях"

  steps:
    - step: "5.1 Generate Report"
      sections:
        - "Issues Fixed (table)"
        - "Changelog (diff format)"
        - "Quality Score (before/after)"
        - "Status: FIXED / PARTIAL / BLOCKED"

    - step: "5.2 Determine Next Action"
      decision:
        if_fixed: "→ Phase 6 (INTEGRATE)"
        if_blocked: "→ Stop and report to user"
        if_partial: "→ Report partial + continue to Phase 6"

  output_format: |
    ## Phase 5: OUTPUT — DONE
    ### Summary
    - Issues Fixed: [N/M]
    - Quality: [before] → [after]
    - Status: [FIXED/PARTIAL/BLOCKED]

  exit_criteria: "Отчёт сформирован, next action определён"

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 6: INTEGRATE
# ════════════════════════════════════════════════════════════════════════════════
phase_6_integrate:
  purpose: "Автоматически выполнить интеграцию после FIXED статуса"
  rule: "Выполняется автоматически, без подтверждения пользователя"

  steps:
    - step: "6.1 Update CLAUDE.md"
      action: "Добавить/обновить запись в соответствующей секции"
      sections:
        command: "commands section"
        skill: "skills section"
        rule: "path rules section"
        agent: "agents section"

    - step: "6.2 Update settings.json"
      when: "артефакт требует permissions"
      format: "permissions.allow: [Skill(<name>)]"

    - step: "6.3 Update Related Artifacts"
      actions:
        - "Добавить @<name> ссылку в связанные skills"
        - "Добавить в pipeline description если часть pipeline"
        - "Обновить triggers в description связанных артефактов"

    - step: "6.4 Integration Checklist"
      verify:
        - "CLAUDE.md updated (section)"
        - "settings.json updated (if needed)"
        - "Related artifacts updated"

  output_format: |
    ## Phase 6: INTEGRATE — DONE
    - CLAUDE.md: ✅ [section]
    - settings.json: ✅/➖
    - Related: ✅ [list]

  exit_criteria: "Все integration steps выполнены и проверены"

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 7: SAVE TO MEMORY
# ════════════════════════════════════════════════════════════════════════════════
phase_7_memory:
  purpose: "Сохранить информацию об артефакте в MCP memory"
  rule: "Персистентность знаний между сессиями"

  steps:
    - step: "7.1 Create Entity"
      tool: "mcp__memory__create_entities"
      entity:
        type: "claude-artifact-<type>"
        name: "<artifact-name>"
        observations:
          - "Type: command|skill|rule|agent"
          - "File: .claude/<type>s/<name>.md"
          - "Purpose: <краткое описание>"
          - "Created: <YYYY-MM-DD>"
          - "Triggers: <когда использовать>"
          - "Related: <связанные артефакты>"

    - step: "7.2 Create Relations"
      tool: "mcp__memory__create_relations"
      relation_types:
        uses: "Артефакт использует другой (@skill reference)"
        triggers: "Артефакт вызывает другой (NEXT: /command)"
        extends: "Артефакт расширяет функционал другого"
        part_of: "Артефакт часть pipeline"

  output_format: |
    ## Phase 7: MEMORY — DONE
    - Entity: ✅ <name>
    - Relations: ✅ [N] created

  exit_criteria: "Entity и relations созданы в MCP memory"

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 8: LESSONS LEARNED
# ════════════════════════════════════════════════════════════════════════════════
phase_8_lessons:
  purpose: "Сохранить уроки для self-improvement"
  integration: "SEE: meta-agent.md#self_improvement"

  capture_when:
    - "Fix required multiple iterations"
    - "Issue was recurring (seen before)"
    - "Fix revealed a pattern worth remembering"

  lesson_format:
    trigger: "What caused the issue"
    mistake: "What was wrong in artifact"
    fix: "How it was fixed"
    artifact_type: "command | skill | rule | agent"
    date: "YYYY-MM-DD"

  save_to_memory:
    tool: "mcp__memory__add_observations"
    entity: "meta-agent-lesson-{date}"

  output_format: |
    ## Phase 8: LESSONS — DONE
    - Lessons captured: {N}
    - Saved to MCP memory: ✅

  exit_criteria: "Уроки сохранены в MCP memory"

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 9: FINAL OUTPUT
# ════════════════════════════════════════════════════════════════════════════════
phase_9_final:
  purpose: "Финальный вывод результата"

  format: |
    # Artifact Fix Complete: [Name]

    ## Summary
    - Type: [type]
    - File: [path]
    - Status: INTEGRATED

    ## Issues Fixed
    | # | Issue | Status |
    |---|-------|--------|
    | 1 | ...   | ✅     |

    ## Integration
    - CLAUDE.md: ✅ Added to [section]
    - settings.json: ✅/➖
    - Related: ✅ [list]

    ## Memory
    - Entity: ✅ [name]
    - Relations: ✅ [N]
    - Lessons: ✅ [N] saved

    ## Next Steps
    - Test invocation: `/<command>` or load `@<skill>`
    - Verify in new session

  exit_criteria: "Финальный отчёт выведен"

# ════════════════════════════════════════════════════════════════════════════════
# REFERENCE: Severity Levels
# ════════════════════════════════════════════════════════════════════════════════
severity_levels:
  - level: "CRITICAL"
    description: "Блокирует использование артефакта"
    must_fix: true
    examples:
      - "Missing required YAML field"
      - "Syntax error in YAML"
      - "No workflow defined"

  - level: "HIGH"
    description: "Нарушает quality criteria"
    must_fix: true
    examples:
      - "No examples section"
      - "No trigger keywords"
      - "Missing autonomy rule (for agent)"

  - level: "MEDIUM"
    description: "Улучшение качества"
    must_fix: false
    examples:
      - "Too long (>500 lines)"
      - "No forbidden section"
      - "Missing recommended fields"

  - level: "LOW"
    description: "Nice to have"
    must_fix: false
    examples:
      - "Formatting issues"
      - "Minor typos"
      - "Could add more examples"

# ════════════════════════════════════════════════════════════════════════════════
# REFERENCE: Fix Patterns
# ════════════════════════════════════════════════════════════════════════════════
fix_patterns:
  - issue: "Missing YAML field"
    fix: "Add field with correct value"
    tool: "Edit"
    example:
      before: |
        meta:
          description: "..."
      after: |
        meta:
          name: artifact-name
          description: "..."

  - issue: "Missing section"
    fix: "Add section with content from research"
    tool: "Edit"
    template: |
      section_name:
        - item1
        - item2

  - issue: "Wrong structure"
    fix: "Restructure per artifact-quality.md template"
    tool: "Write (full rewrite)"

  - issue: "No examples"
    fix: "Add 2-3 examples from codebase"
    tool: "Edit"
    template: |
      examples:
        pattern_name:
          bad: "wrong code"
          good: "correct code"
          why: "explanation"

  - issue: "No trigger keywords"
    fix: "Add to description"
    tool: "Edit"
    template: |
      description: |
        Purpose...

        Load when:
        - Condition 1
        Keywords: keyword1, keyword2

  - issue: "Integration missing"
    fix: "Add INTEGRATION section"
    tool: "Edit"
    template: |
      integration:
        claude_md: "section"
        settings_json: "if needed"
        related: ["@skill1"]

  - issue: "Error handling missing"
    fix: "Add ERROR HANDLING section"
    tool: "Edit"
    template: |
      errors:
        fatal:
          - "condition → stop"
        recoverable:
          - "condition → retry"

# ════════════════════════════════════════════════════════════════════════════════
# PRINCIPLES
# ════════════════════════════════════════════════════════════════════════════════
principles:
  - id: 1
    name: "Точечные правки"
    rule: "Только то, что указано в issues — не рефакторить весь файл"

  - id: 2
    name: "Verify after fix"
    rule: "Проверить что fix работает прежде чем двигаться дальше"

  - id: 3
    name: "Document all"
    rule: "Всё записывать в changelog для аудита"

  - id: 4
    name: "Escalate blockers"
    rule: "Если не можешь исправить — сообщи, не молчи"

  - id: 5
    name: "Linear workflow"
    rule: "Фазы последовательные, не пропускать"

# ════════════════════════════════════════════════════════════════════════════════
# FORBIDDEN
# ════════════════════════════════════════════════════════════════════════════════
forbidden:
  - action: "Добавлять новый функционал"
    why: "Только то, что указано в issues"

  - action: "Рефакторить не связанный код"
    why: "Точечные правки, минимальный scope"

  - action: "Менять structure если не requested"
    why: "Минимальные изменения для fix"

  - action: "Удалять существующий контент без причины"
    why: "Сохранять всё что работает"
