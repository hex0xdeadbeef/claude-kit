---
description: "Полный цикл разработки: task-analysis → planner → plan-review → coder → code-review"
model: opus
---

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
      produces: Git commit
      location: Repository

  final_output: "Реализованный, протестированный и отревьюенный код с коммитом."

# ════════════════════════════════════════════════════════════════════════════════
# AUTONOMY RULE
# ════════════════════════════════════════════════════════════════════════════════
autonomy_rule:
  # Common autonomy patterns: SEE deps/shared-core.md#autonomy
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
  # Common MCP patterns: SEE deps/shared-core.md#mcp-tools
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
    # SEE: deps/shared-core.md#beads-integration

# ════════════════════════════════════════════════════════════════════════════════
# SESSION RECOVERY
# ════════════════════════════════════════════════════════════════════════════════
session_recovery:
  reference: "SEE: .claude/commands/deps/shared-core.md#session-recovery"
  contains: "Auto-detect algorithm, decision table, quick check commands"

# ════════════════════════════════════════════════════════════════════════════════
# PIPELINE
# ════════════════════════════════════════════════════════════════════════════════
pipeline:
  mandatory: "🔴 MANDATORY: Read .claude/commands/deps/shared-core.md BEFORE executing any phase"

  flow: "task-analysis → /planner → /plan-review → /coder → /code-review"

  load_phases:
    action: "Read .claude/commands/deps/shared-core.md"
    when: "BEFORE starting Phase 0"
    required: true
    contains:
      - Pipeline diagram with verdicts and routing
      - Loop limits (max 3 iterations per review cycle)
      - Context isolation rules for review phases
      - Phase 0-4 detailed instructions
      - Completion actions (git, beads)
      - Lessons learned format

# ════════════════════════════════════════════════════════════════════════════════
# HANDOFF PROTOCOL
# ════════════════════════════════════════════════════════════════════════════════
handoff_protocol:
  purpose: "Структурированная передача контекста между фазами pipeline"
  severity: CRITICAL
  rule: "Каждая фаза ОБЯЗАНА создать handoff payload для следующей фазы"

  contract:
    planner_to_plan_review:
      producer: "/planner"
      consumer: "/plan-review"
      payload:
        artifact: ".claude/prompts/{feature}.md"
        metadata:
          task_type: "{new_feature|bug_fix|refactoring|...}"
          complexity: "{S|M|L|XL}"
          sequential_thinking_used: true|false
          alternatives_considered: N
        key_decisions:
          - "Описание ключевого решения + обоснование"
        known_risks:
          - "Описание известного риска"
        areas_needing_attention:
          - "Part N: почему требует внимания"

    plan_review_to_coder:
      producer: "/plan-review"
      consumer: "/coder"
      payload:
        artifact: ".claude/prompts/{feature}.md"
        verdict: "APPROVED|NEEDS_CHANGES|REJECTED"
        issues_summary:
          blocker: 0
          major: 0
          minor: 0
        approved_with_notes:
          - "Note about Part N"
        iteration: "N/3"

    coder_to_code_review:
      producer: "/coder"
      consumer: "/code-review"
      payload:
        branch: "feature/{name}"
        parts_implemented: ["Part 1: DB", "Part 2: Domain"]
        evaluate_adjustments:
          - "Part N: описание adjustment"
        risks_mitigated:
          - "Risk + как решён"
        deviations_from_plan:
          - "Описание + обоснование"

    code_review_to_completion:
      producer: "/code-review"
      consumer: "workflow/completion"
      payload:
        verdict: "APPROVED|APPROVED_WITH_COMMENTS|CHANGES_REQUESTED"
        issues:
          - id: "CR-001"
            severity: "BLOCKER|MAJOR|MINOR|NIT"
            category: "architecture|security|error_handling|completeness|style"
            location: "path/file.go:line"
            problem: "..."
            suggestion: "..."
        iteration: "N/3"

  narrative_casting:
    purpose: "Context handoff to review phases without creation-process bias"
    rule: "Review phases receive narrative context + artifact, NOT creation history"
    template_fields:
      - field: "context_source"
        value: "{agent_name}"
        description: "Which agent produced the artifact"
      - field: "work_performed"
        value: "{brief_description}"
        description: "What the agent did"
      - field: "key_decisions"
        value: "[list]"
        description: "Architectural/design decisions with rationale"
      - field: "known_risks"
        value: "[list]"
        description: "Identified risks and their status"
      - field: "reviewer_recommendations"
        value: "[list]"
        description: "Specific areas for reviewer attention"

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
    reference: "SEE: deps/shared-core.md#loop-limits"
    severity: CRITICAL

  - rule: "Context Isolation"
    description: "Review-фазы ДОЛЖНЫ работать с чистым контекстом (subagent или перечитывание с нуля)"
    reference: "SEE: deps/shared-core.md#context-isolation"
    severity: CRITICAL

# ════════════════════════════════════════════════════════════════════════════════
# CHECKPOINT PROTOCOL
# ════════════════════════════════════════════════════════════════════════════════
checkpoint_protocol:
  purpose: "Proactive сохранение состояния pipeline для мгновенного восстановления"
  severity: HIGH

  when: "После завершения КАЖДОЙ фазы (включая iteration loops)"
  file: ".claude/workflow-state/{feature}-checkpoint.yaml"

  format:
    feature: "{feature-name}"
    phase_completed: "0.5|1|2|3|4"
    phase_name: "task-analysis|planning|plan-review|implementation|code-review"
    iteration:
      plan_review: "N/3"
      code_review: "N/3"
    verdict: "APPROVED|NEEDS_CHANGES|REJECTED|null"
    timestamp: "ISO 8601"
    complexity: "S|M|L|XL"
    route: "minimal|standard|full"
    handoff_payload: "{ ... содержимое последнего handoff_output ... }"
    issues_history:
      - phase: 2
        iteration: 1
        issues: ["PR-001: MAJOR — missing tests section"]

  recovery:
    action: "Read checkpoint → resume from next phase"
    steps:
      - "Read .claude/workflow-state/{feature}-checkpoint.yaml"
      - "Verify checkpoint integrity (все поля заполнены)"
      - "Skip all completed phases"
      - "Resume from phase_completed + 1"
      - "Load handoff_payload как input для текущей фазы"
    advantage: "Не нужно re-evaluate состояние по косвенным признакам (plan exists? changes exist?)"

  example:
    file: ".claude/workflow-state/{feature}-checkpoint.yaml"
    fields:
      feature: "{feature-name}"
      phase_completed: 2
      phase_name: "plan-review"
      iteration:
        plan_review: "1/3"
        code_review: "0/3"
      verdict: "APPROVED"
      timestamp: "2026-02-20T14:30:00Z"
      complexity: "L"
      route: "standard"
      handoff_payload:
        to: "coder"
        artifact: ".claude/prompts/{feature}.md"
        verdict: "APPROVED"
        issues_summary: { blocker: 0, major: 0, minor: 1 }
        approved_with_notes:
          - "Part 3: minor — add error context in helper"
        iteration: "1/3"

# ════════════════════════════════════════════════════════════════════════════════
# RE-ROUTING
# ════════════════════════════════════════════════════════════════════════════════
re_routing:
  purpose: "Самокорректирующийся pipeline — изменение route при неверной классификации"
  severity: MEDIUM

  triggers:
    - trigger: "plan-review находит что план слишком простой для текущего route"
      action: "Downgrade route"
      examples:
        - "L→M: план оказался < 3 Parts, убрать обязательный Sequential Thinking"
        - "M→S: только 1 Part, 1 layer — skip plan-review в следующей итерации"

    - trigger: "plan-review находит что план слишком сложный для текущего route"
      action: "Upgrade route"
      examples:
        - "S→M: обнаружены cross-layer зависимости — добавить full plan-review"
        - "M→L: 4+ Parts, 3+ layers — добавить Sequential Thinking"

    - trigger: "coder evaluate находит hidden complexity"
      action: "Upgrade route или RETURN to planner"
      examples:
        - "M→L: evaluate обнаружил что нужна миграция БД (не учтена в плане)"

  tracking: "Записать re-routing в checkpoint для анализа точности task-analysis"
  learning: "Сохранить в MCP Memory: original_route → actual_route + причина для улучшения heuristics"

# ════════════════════════════════════════════════════════════════════════════════
# PIPELINE METRICS
# ════════════════════════════════════════════════════════════════════════════════
pipeline_metrics:
  purpose: "Автоматический сбор метрик для оптимизации pipeline"
  when: "В completion-фазе workflow"
  severity: MEDIUM

  format:
    feature: "{feature-name}"
    timestamp: "ISO 8601"
    total_phases_executed: N
    review_iterations:
      plan_review: N
      code_review: N
    complexity:
      estimated: "S|M|L|XL"
      actual: "S|M|L|XL (если re-routing произошёл)"
    re_routing_occurred: true|false
    issues_found:
      blocker: N
      major: N
      minor: N
      nit: N
    sequential_thinking_used: true|false
    mcp_tools_used: ["memory", "sequential_thinking", "context7", "postgresql"]
    evaluate_decision: "PROCEED|REVISE|RETURN"

  storage:
    action: "mcp__memory__create_entities"
    entity:
      name: "Pipeline Metrics: {feature}"
      entityType: "pipeline_metrics"
      observations:
        - "Phases: {total}, PR iterations: {N}, CR iterations: {N}"
        - "Complexity: estimated {X} → actual {Y}"
        - "Issues: {blocker}B {major}M {minor}m"
        - "Tools: {list}"

  analysis:
    purpose: "Со временем позволяет:"
    benefits:
      - "Оценивать точность task-analysis (estimated vs actual complexity)"
      - "Находить паттерны (какие типы задач генерируют больше issues)"
      - "Оптимизировать pipeline на основе данных"
      - "Выявлять bottlenecks (какая фаза генерирует больше итераций)"

# ════════════════════════════════════════════════════════════════════════════════
# ERROR HANDLING
# ════════════════════════════════════════════════════════════════════════════════
error_handling:
  # Common error patterns: SEE deps/shared-core.md#error-handling
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
    reference: "SEE: deps/shared-core.md#loop-limits"

# ════════════════════════════════════════════════════════════════════════════════
# EXAMPLES
# ════════════════════════════════════════════════════════════════════════════════
examples:
  sequential_execution_with_confirmations:
    good:
      input: "Add new endpoint"
      steps:
        - phase: 1
          action: "/planner"
          result: "Plan created"
        - checkpoint: "Proceed to Phase 2?"
          answer: "yes"
        - phase: 2
          action: "/plan-review"
          result: "APPROVED"
        - checkpoint: "Proceed to Phase 3?"
          answer: "yes"
        - phase: 3
          action: "/coder"
          result: "Code written, tests pass"
        - checkpoint: "Proceed to Phase 4?"
          answer: "yes"
        - phase: 4
          action: "/code-review"
          result: "APPROVED → feature complete"
    bad:
      input: "Just write code, no planning"
      steps:
        - skip: "Phase 1 and Phase 2"
        - jump_to: "Phase 3 directly"
    why: "Skipping phases leads to low-quality code without architectural review and validation"

  completion_without_autocommit:
    good:
      trigger: "Phase 4: APPROVED"
      steps:
        - action: "Suggest commit command to user"
          command: "git add . && git commit -m 'feat: ...' && bd sync"
        - action: "Wait for user to decide when to commit"
    bad:
      trigger: "Phase 4: APPROVED"
      steps:
        - action: "git add && git commit && git push (automatically)"
    why: "Auto-commit without permission violates user control over repository"

# ════════════════════════════════════════════════════════════════════════════════
# TROUBLESHOOTING
# ════════════════════════════════════════════════════════════════════════════════
troubleshooting:
  - problem: "Phase 2 keeps returning NEEDS_CHANGES"
    cause: "Plan missing critical sections (Scope, Architecture Decision, Tests)"
    fix: "Check plan against templates/plan-template.md, ensure all sections filled"

  - problem: "Phase 3 tests fail repeatedly"
    cause: "Plan not detailed enough or missing edge cases"
    fix: "Return to Phase 1, add specific test cases to plan"

  - problem: "Stuck in Phase 1 → Phase 2 loop"
    cause: "Requirements unclear or too broad"
    fix: "Ask user to clarify scope, break task into smaller pieces"

  - problem: "Session interrupted mid-workflow"
    cause: "Connection lost, timeout, or manual stop"
    fix: "Check `.claude/prompts/{feature}.md` for saved plan, use --from-phase to resume"

  - problem: "bd sync fails"
    cause: "Network issue or beads daemon not running"
    fix: "Run `bd doctor` to diagnose, restart daemon if needed"

common_mistakes:
  - mistake: "Skipping Phase 2 (plan-review)"
    why_bad: "Unvalidated plans lead to rework in Phase 3/4"
    fix: "Always run /plan-review even for 'simple' tasks"

  - mistake: "Auto-committing without user consent"
    why_bad: "User loses control over repository state"
    fix: "Always ask before git commit, never auto-push"

  - mistake: "Not saving lessons_learned for complex tasks"
    why_bad: "Knowledge lost, same mistakes repeated"
    fix: "After non-trivial tasks, save insights to MCP memory"

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
    - "Если ценные insights → lessons learned сохранены в memory"
    - "Если задача из beads → напомнить о закрытии (`bd close <id>`)"
    - "Git commit создан"
    - "**`bd sync` выполнен** (ОБЯЗАТЕЛЬНО)"
