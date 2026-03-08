---
name: workflow
description: "Полный цикл разработки: task-analysis → planner → plan-review → coder → code-review"
model: opus
---

# Language & aliases: SEE .claude/PROJECT-KNOWLEDGE.md

role:
  identity: "Orchestrator"
  owns: "Координация полного цикла разработки: task-analysis → planner → plan-review → coder → code-review"
  does_not_own: "Планирование, имплементация, review — делегирует sub-commands"
  output_contract: "Реализованный, протестированный и отревьюенный код с коммитом + pipeline metrics"
  success_criteria: "Все фазы пройдены, handoff контракты соблюдены, checkpoint сохранён, метрики записаны"
  style: "Sequential phases with user confirmation between each phase"

# ════════════════════════════════════════════════════════════════════════════════
# TRIGGERS
# ════════════════════════════════════════════════════════════════════════════════
triggers:
  - if: "Task requires full development cycle (planning + implementation + review)"
    then: "Use /workflow instead of individual commands"

  - if: "Phase verdict is REJECTED or NEEDS_CHANGES"
    then: "Return to previous phase, do NOT skip ahead"

  - if: "User says 'stop' or 'pause'"
    then: "Stop immediately, save current state for --from-phase resume"

  - if: "Tests fail 3x consecutively in Phase 3"
    then: "Stop, request manual intervention"

  - if: "Review cycle exceeds 3 iterations (plan-review or code-review)"
    then: "STOP immediately, show iteration summary, request user help"

# ════════════════════════════════════════════════════════════════════════════════
# INPUT
# ════════════════════════════════════════════════════════════════════════════════
input:
  arguments:
    - name: task
      required: true
      format: "Текст или beads ID"
      example: "Добавить новую функциональность"

    - name: --auto
      required: false
      format: flag
      description: "Автономный режим без подтверждений"

    - name: --from-phase
      required: false
      format: "1-4"
      description: "Продолжить с указанной фазы"

  examples:
    - "/workflow Добавить новый endpoint"
    - "/workflow --auto Реализовать обновление ресурса"
    - "/workflow --from-phase 3"
    - "/workflow beads-abc123"

# ════════════════════════════════════════════════════════════════════════════════
# OUTPUT
# ════════════════════════════════════════════════════════════════════════════════
output:
  phases:
    - phase: Planning
      produces: Implementation plan
      location: ".claude/prompts/{feature}.md"

    - phase: Plan Review
      produces: Verdict + issues
      location: Console

    - phase: Implementation
      produces: Working code + tests
      location: Source files

    - phase: Code Review
      produces: Verdict + comments
      location: Console

    - phase: Completion
      produces: Git commit + lessons_learned in Memory (if non-trivial)
      location: Repository + Memory MCP

  final_output: "Реализованный, протестированный и отревьюенный код с коммитом."

# ════════════════════════════════════════════════════════════════════════════════
# AUTONOMY RULE
# ════════════════════════════════════════════════════════════════════════════════
autonomy_rule:
  # Common autonomy patterns: SEE deps/core/autonomy.md
  modes:
    - INTERACTIVE (default): Ask before each phase
    - AUTONOMOUS (--auto): Execute all phases automatically
    - RESUME (--from-phase N): Skip to specified phase (or checkpoint-based)
    - MINIMAL (--minimal): Minimal research, only critical checks

  stop_conditions:
    - Plan REJECTED → Stop, request new requirements
    - Tests FAIL 3x → Stop, request manual intervention
    - Loop limit exceeded (3 iterations) → Stop, show summary

  continue_conditions:  # autonomous mode only
    - Phase completed → Next phase
    - NEEDS_CHANGES → Return to previous phase

# ════════════════════════════════════════════════════════════════════════════════
# RELATED TOOLS
# ════════════════════════════════════════════════════════════════════════════════
related_tools:

  - tool: "mcp__memory (MCP server)"
    when: "Saving lessons learned"
    priority: HIGH

# ════════════════════════════════════════════════════════════════════════════════
# MCP TOOLS
# ════════════════════════════════════════════════════════════════════════════════
mcp_tools:
  # Common MCP patterns: SEE deps/core/mcp-tools.md
  - tool: "Sequential Thinking"
    usage: "Complex multi-phase orchestration"
    when:
      - "Task spans 4+ phases with complex dependencies"
      - "Multiple sub-commands need coordination"
      - "Recovery from failed phase requires analysis"

  - tool: "Memory"
    usage: "STARTUP: search_nodes; ЗАВЕРШЕНИЕ: save lessons_learned + pipeline_metrics"

# ════════════════════════════════════════════════════════════════════════════════
# STARTUP
# ════════════════════════════════════════════════════════════════════════════════
startup:
  critical: "При запуске агента СРАЗУ выполнить ВСЕ шаги"

  steps:
    - step: 0
      action: "Task Analysis — классификация задачи"
      reference: "SEE: .claude/commands/deps/planner/task-analysis.md"
      purpose: "Определить complexity (S/M/L/XL) и маршрут ПЕРЕД планированием"
      decisions:
        S: "/planner --minimal → skip Phase 2 → /coder → /code-review"
        M: "standard flow (все фазы)"
        L: "full flow + Sequential Thinking рекомендован"
        XL: "full flow + Sequential Thinking ОБЯЗАТЕЛЕН"
      after_classification: "Применить CONDITIONAL DEPS LOADING (секция ниже) — НЕ ЧИТАЙ deps, помеченные SKIP для этой complexity"
      warning: "ОБЯЗАТЕЛЬНО! Неправильная классификация = лишняя работа"

    - step: 1
      action: "TodoWrite — создать список фаз (с учётом route из Task Analysis)"
      items:
        - "Phase 0: Get Task (pending)"
        - "Phase 0.5: Task Analysis (completed — уже выполнен в step 0)"
        - "Phase 1: Planning (pending)"
        - "Phase 2: Plan Review (pending — или skip если S-complexity)"
        - "Phase 3: Implementation (pending)"
        - "Phase 4: Code Review (pending)"

    - step: 2
      action: "mcp__memory__search_nodes — query: '{ключевые слова задачи}'"
      note: "ОБЯЗАТЕЛЬНО! Проверить нет ли похожих решений"

    - step: 3
      action: "Проверить beads"
      checks:
        - "bd list --status=open → есть ли связанная задача?"
        - "bd list --status=in_progress → есть ли незавершённая работа?"

    - step: 4
      action: "Проверить session recovery"
      checks:
        - "Есть ли `.claude/prompts/{feature}.md`? → можно пропустить Phase 1"
        - "Есть ли beads issue in_progress? → bd show <id>"

  beads_integration:
    # SEE: deps/core/beads.md

# ════════════════════════════════════════════════════════════════════════════════
# SESSION RECOVERY
# ════════════════════════════════════════════════════════════════════════════════
session_recovery:
  reference: "SEE: .claude/commands/deps/workflow/orchestration-core.md#session-recovery"
  contains: "Auto-detect algorithm, decision table, quick check commands"

# ════════════════════════════════════════════════════════════════════════════════
# PIPELINE
# ════════════════════════════════════════════════════════════════════════════════
pipeline:
  mandatory: |
    🔴 MANDATORY: Read role-specific core deps BEFORE executing any phase:
    - Workflow: deps/core/autonomy.md + deps/core/beads.md + deps/core/error-handling.md
    - Planner: deps/core/mcp-tools.md + deps/core/project-knowledge.md + deps/core/error-handling.md
    - Plan Review: deps/core/context-isolation.md + deps/core/error-handling.md
    - Coder: deps/core/mcp-tools.md + deps/core/project-knowledge.md + deps/core/error-handling.md
    - Code Review: deps/core/context-isolation.md + deps/core/error-handling.md

  flow: "task-analysis → /planner → /plan-review → /coder → /code-review"

  load_phases:
    - action: "Read .claude/commands/deps/core/autonomy.md"
      when: "BEFORE starting Phase 0"
      required: true
    - action: "Read .claude/commands/deps/core/beads.md"
      when: "BEFORE starting Phase 0"
      required: true
    - action: "Read .claude/commands/deps/core/error-handling.md"
      when: "BEFORE starting Phase 0"
      required: true
    - action: "Read .claude/commands/deps/workflow/orchestration-core.md"
      when: "ALWAYS — contains pipeline phases, loop limits, session recovery"
      required: true
      contains:
        - Pipeline diagram with verdicts and routing
        - Loop limits (max 3 iterations per review cycle, tracking protocol)
        - Session recovery (checkpoint-first, heuristic fallback)

# ════════════════════════════════════════════════════════════════════════════════
# CONDITIONAL DEPS LOADING
# ════════════════════════════════════════════════════════════════════════════════
conditional_deps:
  purpose: "Не загружать тяжёлые deps для простых задач. Complexity определяется в Phase 0.5 (task-analysis)."
  severity: HIGH

  rule: |
    ПОСЛЕ task-analysis определена complexity (S/M/L/XL).
    Используй таблицу ниже — НЕ ЧИТАЙ файлы, помеченные SKIP для текущей complexity.

  matrix: |
    | Dep file                                  | S    | M    | L/XL | Reason (S skip)                     |
    |-------------------------------------------|------|------|------|-------------------------------------|
    | sequential-thinking-guide.md (120)          | SKIP | SKIP | LOAD | Нет 3+ альтернатив при S/M          |
    | plan-review/architecture-checks.md (171)  | SKIP | LOAD | LOAD | Phase 2 скипнута при S               |
    | plan-review/required-sections.md (136)    | SKIP | LOAD | LOAD | Phase 2 скипнута при S               |
    | planner/data-flow.md (42)                 | SKIP | LOAD | LOAD | Простые задачи — один слой           |
    | code-review/security-checklist.md (72)    | SKIP | LOAD | LOAD | Простые задачи — низкий security risk |
    | workflow/pipeline-metrics.md (97)         | SKIP | SKIP | SKIP | Load только в completion фазе         |
    | workflow/examples-troubleshooting.md (90) | SKIP | SKIP | SKIP | Load on-demand при проблемах           |
    | workflow/handoff-protocol.md (NEW)        | SKIP | SKIP | SKIP | Load при формировании handoff           |
    | workflow/checkpoint-protocol.md (NEW)      | SKIP | SKIP | SKIP | Load при записи checkpoint              |
    | workflow/re-routing.md (NEW)               | SKIP | SKIP | SKIP | Load при re-routing event               |

    Savings: S = ~784 строк (~6 300 токенов), M = ~363 строк (~2 900 токенов), L/XL = ~187 строк (~1 500 токенов).
    Note: workflow/* файлы имеют SKIP для всех complexity — загружаются по event trigger, а не по complexity.

  always_load:
    - "deps/core/error-handling.md — всегда нужен (все агенты)"
    - "deps/core/autonomy.md — workflow only"
    - "deps/core/beads.md — workflow only"
    - "deps/core/mcp-tools.md — planner, coder"
    - "deps/core/project-knowledge.md — planner, coder"
    - "deps/core/context-isolation.md — plan-review, code-review"
    - "deps/workflow/orchestration-core.md — pipeline, loop limits, session recovery (workflow only)"
    - "deps/shared-review.md — severity classification, decision matrix (plan-review, code-review only)"
    - "deps/planner/task-analysis.md — нужен для классификации"
    - "deps/coder/examples.md — нужен при имплементации"
    - "deps/code-review/examples.md — нужен при ревью"
    - "deps/*/troubleshooting.md — загружать только при ошибках"

# ════════════════════════════════════════════════════════════════════════════════
# HANDOFF PROTOCOL
# ════════════════════════════════════════════════════════════════════════════════
handoff_protocol:
  reference: "SEE: deps/workflow/handoff-protocol.md"
  when: "Read BEFORE forming handoff between phases"
  contains: "4 contracts (planner→plan-review, plan-review→coder, coder→code-review, code-review→completion) + narrative_casting template"

# ════════════════════════════════════════════════════════════════════════════════
# RULES
# ════════════════════════════════════════════════════════════════════════════════
rules:
  - rule: "Sequential execution"
    description: "Фазы выполнять последовательно, не параллельно"

  - rule: "No Skip phases"
    description: "НИКОГДА не пропускать фазы (кроме Phase 2 при S-complexity route)"

  - rule: "User Confirmation"
    description: "Спрашивать подтверждение перед каждой фазой"

  - rule: "Handle Failures"
    description: "При REJECTED/CHANGES REQUESTED возвращаться к предыдущей фазе"

  - rule: "Loop Limits"
    description: "Максимум 3 итерации для каждого цикла ревью (plan-review, code-review)"
    reference: "SEE: deps/workflow/orchestration-core.md#loop-limits"
    severity: CRITICAL

  - rule: "Context Isolation"
    description: "Review-фазы ОБЯЗАНЫ запускаться как Task subagent (REQUIRED, не preferred)"
    enforcement: "REQUIRED — subagent saves 67% context. Exception: Task tool unavailable → fallback re-read"
    reference: "SEE: deps/core/context-isolation.md"
    severity: CRITICAL

# ════════════════════════════════════════════════════════════════════════════════
# CHECKPOINT PROTOCOL
# ════════════════════════════════════════════════════════════════════════════════
checkpoint_protocol:
  reference: "SEE: deps/workflow/checkpoint-protocol.md"
  when: "Read BEFORE writing checkpoint after each phase"
  contains: "format (12 YAML fields), recovery (5 steps), example"

# ════════════════════════════════════════════════════════════════════════════════
# RE-ROUTING
# ════════════════════════════════════════════════════════════════════════════════
re_routing:
  reference: "SEE: deps/workflow/re-routing.md"
  when: "Read when re-routing event detected (plan-review or coder signals complexity mismatch)"
  contains: "3 triggers (downgrade, upgrade, hidden complexity) + tracking fields + learning"

# ════════════════════════════════════════════════════════════════════════════════
# PIPELINE METRICS
# ════════════════════════════════════════════════════════════════════════════════
pipeline_metrics:
  # SEE: deps/workflow/pipeline-metrics.md (load at completion phase only)
  trigger: "В completion-фазе workflow — read full metrics guide before saving"
  contains: "format (12 fields), storage (MCP Memory entity), analysis (4 benefits), aggregation (query + report + anomaly detection)"

# ════════════════════════════════════════════════════════════════════════════════
# ERROR HANDLING
# ════════════════════════════════════════════════════════════════════════════════
error_handling:
  # Common error patterns: SEE deps/core/error-handling.md
  - error: "Plan review REJECTED"
    action: "Request new requirements, return to Phase 1"

  - error: "Plan review NEEDS_CHANGES"
    action: "Pass issues to /planner, retry Phase 1"

  - error: "Code review CHANGES_REQUESTED"
    action: "Pass issues to /coder, retry Phase 3"

  - error: "Tests failing"
    action: "Fix in Phase 3"

  - error: "User says 'stop'"
    action: "Stop immediately, await instructions"

  - error: "Loop limit exceeded (3 iterations in plan-review or code-review cycle)"
    action: "STOP. Show: what was requested in each iteration, what issues persisted. Request user to either simplify task or provide specific guidance."
    reference: "SEE: deps/workflow/orchestration-core.md#loop-limits"

# ════════════════════════════════════════════════════════════════════════════════
# EXAMPLES & TROUBLESHOOTING
# ════════════════════════════════════════════════════════════════════════════════
# SEE: deps/workflow/examples-troubleshooting.md
# Load on-demand: при первом запуске workflow или при возникновении проблем.
# Содержит: execution examples (good/bad), troubleshooting (5 problems), common_mistakes (3 items).

# ════════════════════════════════════════════════════════════════════════════════
# CHECKLIST
# ════════════════════════════════════════════════════════════════════════════════
checklist:
  startup:
    - "Task Analysis выполнен (complexity + route)"
    - "TodoWrite создан со всеми фазами (с учётом route)"
    - "Session recovery проверен"

  phases:
    - "Phase 0: Задача из beads взята (если применимо)"
    - "Phase 0.5: Task Analysis выполнен (S/M/L/XL)"
    - "Phase 1: План создан в `prompts/`"
    - "Phase 2: План APPROVED (или skipped для S-complexity)"
    - "Phase 3: Код реализован, tests pass"
    - "Phase 4: Code review APPROVED"
    - "Loop limits не превышены (max 3 итерации per cycle)"

  completion:
    - step: "Save lessons learned to Memory"
      condition: "Sequential Thinking used OR review iterations > 1 OR re-routing occurred OR non-trivial decision made"
      action: |
        1. mcp__memory__search_nodes — query: '{feature name} {domain}'
        2. If 0 results → mcp__memory__create_entities:
           entities: [{
             name: "{Feature Name}",
             entityType: "lessons_learned",
             observations: [
               "PROBLEM: {problem encountered}",
               "SOLUTION: {how resolved}",
               "CONTEXT: {when applicable}",
               "COMPLEXITY: estimated={X} actual={Y}",
               "ITERATIONS: plan_review={N} code_review={N}",
               "CREATED: {ISO date}"
             ]
           }]
        3. If 1 result → mcp__memory__add_observations (merge new findings)
        4. If 2+ results → show to user, ask which to update
      note: "Follow Memory sequence from deps/core/mcp-tools.md (Memory sequence section). NON_CRITICAL."
    - "Если задача из beads → напомнить о закрытии (`bd close <id>`)"
    - "Git commit создан"
    - "**`bd sync` выполнен** (ОБЯЗАТЕЛЬНО)"
