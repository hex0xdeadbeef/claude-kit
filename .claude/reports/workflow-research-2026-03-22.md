# Workflow System Research Report

**Date:** 2026-03-22
**Scope:** Complete analysis of Claude Kit Workflow pipeline — artifact inventory, interaction graph, CHANGELOG analysis, improvement proposals
**Classification:** XL

---

## 1. Executive Summary

Claude Kit Workflow — это многофазный пайплайн разработки, координирующий 7 команд, 3+ агентов, 6 пакетов навыков, 8 правил, 15 скриптов и 6 шаблонов (~137 файлов, ~10,000+ строк). Пайплайн обеспечивает полный цикл: анализ задачи → планирование → ревью плана → реализация → ревью кода → коммит.

В ходе анализа CHANGELOG (версии 2.1.16 — 2.1.81) выявлено **15 ключевых улучшений**, которые могут быть внедрены в текущий пайплайн для повышения наблюдаемости, надежности, производительности и безопасности.

---

## 2. Inventory of Workflow Artifacts

### 2.1 Commands (shared context — orchestration layer)

| Artifact | File                           | Lines | Model  | Role in Pipeline                                     |
| -------- | ------------------------------ | ----- | ------ | ---------------------------------------------------- |
| workflow | `.claude/commands/workflow.md` | 340   | opus   | Orchestratор — координация всех фаз                  |
| planner  | `.claude/commands/planner.md`  | 372   | opus   | Phase 1 — исследование кодовой базы + создание плана |
| coder    | `.claude/commands/coder.md`    | 464   | sonnet | Phase 3 — реализация кода строго по плану            |

### 2.2 Agents (clean context — isolated review)

| Artifact        | File                                | Model  | maxTurns | Role in Pipeline                                |
| --------------- | ----------------------------------- | ------ | -------- | ----------------------------------------------- |
| plan-reviewer   | `.claude/agents/plan-reviewer.md`   | sonnet | 40       | Phase 2 — архитектурная валидация плана         |
| code-reviewer   | `.claude/agents/code-reviewer.md`   | sonnet | 45       | Phase 4 — ревью кода (worktree isolation)       |
| code-researcher | `.claude/agents/code-researcher.md` | haiku  | 20       | Tool-agent — исследование кодовой базы для L/XL |

### 2.3 Skills (reusable playbooks)

| Package            | Files | Loaded When                     | Purpose                                                   |
| ------------------ | ----- | ------------------------------- | --------------------------------------------------------- |
| workflow-protocols | 8     | /workflow startup (step 0.1)    | Handoff, checkpoint, re-routing, metrics, autonomy, beads |
| planner-rules      | 8     | /planner startup (step 0)       | Task classification, data-flow, ST guide, MCP tools       |
| coder-rules        | 5     | /coder startup (step 0)         | 5 CRITICAL rules, evaluate protocol, MCP tools            |
| plan-review-rules  | 5     | plan-reviewer (via frontmatter) | Required sections, architecture checks                    |
| code-review-rules  | 5     | code-reviewer (via frontmatter) | Security checklist, review examples                       |
| tdd-go             | 2     | /coder (if plan has `## TDD`)   | Red-Green-Refactor workflow                               |

### 2.4 Rules (project constraints)

| Rule                | Scope                    | Relevance to Workflow                             |
| ------------------- | ------------------------ | ------------------------------------------------- |
| workflow.md         | Global                   | Commands vs Agents design decision                |
| architecture.md     | `internal/**/*.go`       | Import matrix (handler → service → repo → models) |
| go-conventions.md   | `**/*.go`                | Error wrapping, concurrency                       |
| testing.md          | `**/*_test.go`           | Table-driven tests, race detector                 |
| handler-rules.md    | `internal/handler/**`    | HTTP validation, codes                            |
| service-rules.md    | `internal/service/**`    | Business logic, interfaces                        |
| repository-rules.md | `internal/repository/**` | SQL, cleanup                                      |
| models-rules.md     | `internal/models/**`     | Stdlib-only, no tags                              |

### 2.5 Scripts & Hooks (automation layer)

| Script                          | Hook Event               | Blocking    | Purpose                                                       |
| ------------------------------- | ------------------------ | ----------- | ------------------------------------------------------------- |
| enrich-context.sh               | UserPromptSubmit         | No          | Workflow state injection (checkpoint, plans, reviews, branch) |
| protect-files.sh                | PreToolUse (Write/Edit)  | Yes         | Prevent modifications to .env, secrets                        |
| block-dangerous-commands.sh     | PreToolUse (Bash)        | Yes         | Block rm -rf, git reset --hard, sudo                          |
| pre-commit-build.sh             | PreToolUse (Bash)        | Yes         | go build before commit                                        |
| check-artifact-size.sh          | PreToolUse (Write)       | Yes         | Artifact size limits                                          |
| auto-fmt-go.sh                  | PostToolUse (Write/Edit) | No          | Auto-format Go after changes                                  |
| yaml-lint.sh                    | PostToolUse (Edit)       | No          | YAML validation                                               |
| check-references.sh             | PostToolUse (Write)      | No          | Cross-reference verification                                  |
| check-plan-drift.sh             | PostToolUse (Write/Edit) | No          | Plan-code divergence detection                                |
| save-progress-before-compact.sh | PreCompact               | No          | Checkpoint + reviews → additionalContext                      |
| save-review-checkpoint.sh       | SubagentStop             | Yes         | Review completion marker (JSONL)                              |
| verify-phase-completion.sh      | Stop                     | Yes         | Phase completion validation                                   |
| check-uncommitted.sh            | Stop                     | Conditional | Block stop if uncommitted (workflow only)                     |
| session-analytics.sh            | SessionEnd               | No          | Pipeline metrics → JSONL                                      |
| notify-user.sh                  | Notification             | No          | OS-native desktop alerts                                      |

### 2.6 Templates

| Template             | Purpose                       | Used By            |
| -------------------- | ----------------------------- | ------------------ |
| plan-template.md     | Implementation plan structure | /planner           |
| command.md           | Command specification         | meta-agent         |
| agent.md             | Agent specification           | meta-agent         |
| rule.md              | Rule specification            | meta-agent         |
| skill.md             | Skill specification           | meta-agent         |
| project-claude-md.md | CLAUDE.md for target projects | project-researcher |

### 2.7 Configuration & State

| File                      | Purpose                                                            |
| ------------------------- | ------------------------------------------------------------------ |
| `.claude/settings.json`   | Hook definitions (8 events), permissions (allow/deny), MCP servers |
| `.claude/workflow-state/` | Checkpoints (YAML), review completions (JSONL), analytics (JSONL)  |
| `.claude/prompts/`        | Saved implementation plans + evaluate outputs                      |

---

## 3. Artifact Interaction Graph

```
                              ┌─────────────────────┐
                              │    /workflow (opus)   │
                              │    ORCHESTRATOR       │
                              └───────┬───────────────┘
                                      │
             ┌────────────────────────┼──────────────────────────┐
             │                        │                          │
    ┌────────▼─────────┐    ┌────────▼──────────┐    ┌─────────▼────────┐
    │  workflow-protocols│    │   settings.json    │    │  CLAUDE.md       │
    │  (SKILL.md)       │    │  (hooks config)    │    │  (error handling │
    │  ├─ autonomy.md   │    │  8 event types     │    │   + lang profile)│
    │  ├─ beads.md      │    │  14 scripts        │    └──────────────────┘
    │  ├─ orchestration │    │  permissions       │
    │  │  -core.md      │    └────────────────────┘
    │  ├─ handoff-      │
    │  │  protocol.md   │
    │  ├─ checkpoint-   │
    │  │  protocol.md   │
    │  ├─ re-routing.md │
    │  ├─ pipeline-     │
    │  │  metrics.md    │
    │  └─ examples.md   │
    └────────────────────┘
                ║
    ════════════╬═══════════════════════════════════════════════
    PIPELINE    ║
    ════════════╬═══════════════════════════════════════════════
                ║
    Phase 0.5   ║  Task Analysis (S/M/L/XL routing)
                ║         │
                ║         ▼
    Phase 1     ║  ┌──────────────┐    ┌─────────────────┐
                ║  │ /planner     │───▶│ planner-rules    │
                ║  │ (opus)       │    │ (SKILL.md)       │
                ║  │              │    │ ├─ task-analysis  │
                ║  │ Output:      │    │ ├─ data-flow     │
                ║  │ .claude/     │    │ ├─ ST-guide      │
                ║  │ prompts/     │    │ ├─ mcp-tools     │
                ║  │ {feature}.md │    │ ├─ checklist     │
                ║  └──────┬───────┘    │ ├─ examples      │
                ║         │            │ └─ troubleshoot  │
                ║         │            └─────────────────┘
                ║         │
                ║         │  ┌──────────────────┐
                ║         ├──┤ code-researcher   │ (haiku, via Task tool)
                ║         │  │ for L/XL research │ ─── Optional tool-agent
                ║         │  └──────────────────┘
                ║         │
                ║         │  Handoff payload:
                ║         │  artifact + metadata + key_decisions + known_risks
                ║         ▼
    Phase 2     ║  ┌──────────────────┐    ┌─────────────────┐
                ║  │ plan-reviewer     │───▶│ plan-review-rules│
                ║  │ (sonnet, agent)   │    │ (SKILL.md)       │
                ║  │ maxTurns: 40     │    │ ├─ req-sections  │
                ║  │                   │    │ ├─ arch-checks   │
                ║  │ Verdict:          │    │ ├─ checklist     │
                ║  │ APPROVED /        │    │ └─ troubleshoot  │
                ║  │ NEEDS_CHANGES /   │    └─────────────────┘
                ║  │ REJECTED          │
                ║  └──────┬────────────┘
                ║         │ (max 3 iterations ↔ /planner)
                ║         │
                ║         │  Handoff payload:
                ║         │  artifact + verdict + issues_summary + iteration
                ║         ▼
    Phase 3     ║  ┌──────────────┐    ┌─────────────────┐
                ║  │ /coder       │───▶│ coder-rules      │
                ║  │ (sonnet)     │    │ (SKILL.md)       │
                ║  │              │    │ ├─ mcp-tools     │
                ║  │ Sub-phases:  │    │ ├─ checklist     │
                ║  │ 1. Read plan │    │ ├─ examples      │
                ║  │ 1.5 Evaluate │    │ └─ troubleshoot  │
                ║  │ 2. Implement │    └─────────────────┘
                ║  │ 3. Verify    │
                ║  └──────┬───────┘
                ║         │
                ║         │  ┌──────────────────┐
                ║         ├──┤ code-researcher   │ (haiku, via Task tool)
                ║         │  │ for evaluate gaps │ ─── Optional tool-agent
                ║         │  └──────────────────┘
                ║         │
                ║         │  ┌──────────────────┐
                ║         ├──┤ tdd-go (skill)    │ ─── Conditional (if plan has ## TDD)
                ║         │  └──────────────────┘
                ║         │
                ║         │  Handoff payload:
                ║         │  branch + parts + evaluate_adjustments + verify_status
                ║         ▼
    Phase 4     ║  ┌──────────────────┐    ┌─────────────────┐
                ║  │ code-reviewer     │───▶│ code-review-rules│
                ║  │ (sonnet, agent)   │    │ (SKILL.md)       │
                ║  │ maxTurns: 45     │    │ ├─ checklist     │
                ║  │ isolation:        │    │ ├─ security      │
                ║  │   worktree       │    │ ├─ examples      │
                ║  │                   │    │ └─ troubleshoot  │
                ║  │ Verdict:          │    └─────────────────┘
                ║  │ APPROVED /        │
                ║  │ APPROVED_WITH_    │
                ║  │ COMMENTS /        │
                ║  │ CHANGES_REQUESTED │
                ║  └──────┬────────────┘
                ║         │ (max 3 iterations ↔ /coder)
                ║         ▼
    Phase 5     ║  ┌──────────────────┐
                ║  │ Completion        │
                ║  │ - git commit      │
                ║  │ - bd sync         │
                ║  │ - pipeline metrics│
                ║  │ - lessons_learned │
                ║  └──────────────────┘
```

### 3.1 Hook Execution Chain (chronological)

```
1. UserPromptSubmit  →  enrich-context.sh
                         ↓ injects workflow state
2. PreToolUse        →  protect-files.sh (Write|Edit)
                    →  check-artifact-size.sh (Write)
                    →  block-dangerous-commands.sh (Bash)
                    →  pre-commit-build.sh (Bash)
                         ↓ gates before tool execution
3. [Tool Execution]
                         ↓
4. PostToolUse       →  auto-fmt-go.sh (Write|Edit)
                    →  yaml-lint.sh (Edit)
                    →  check-references.sh (Write)
                    →  check-plan-drift.sh (Write|Edit)
                         ↓ validation after tool execution
5. PreCompact        →  save-progress-before-compact.sh
                         ↓ preserves state before context compaction
6. SubagentStop      →  save-review-checkpoint.sh (plan-reviewer|code-reviewer)
                         ↓ records review completion
7. Stop              →  verify-phase-completion.sh
                    →  check-uncommitted.sh
                         ↓ gates before session stop
8. SessionEnd        →  session-analytics.sh
                         ↓ final metrics collection
9. Notification      →  notify-user.sh
                         ↓ OS-native desktop alerts
```

### 3.2 Handoff Contract Chain

```
/planner ──[planner_to_plan_review]──▶ plan-reviewer
    │ artifact: .claude/prompts/{feature}.md
    │ metadata: task_type, complexity, ST_used
    │ key_decisions: [list]
    │ known_risks: [list]
    ▼
plan-reviewer ──[plan_review_to_coder]──▶ /coder
    │ artifact: .claude/prompts/{feature}.md
    │ verdict: APPROVED|NEEDS_CHANGES|REJECTED
    │ issues_summary: {blocker, major, minor}
    │ iteration: N/3
    ▼
/coder ──[coder_to_code_review]──▶ code-reviewer
    │ branch: feature/{name}
    │ parts_implemented: [list]
    │ evaluate_adjustments: [list]
    │ verify_status: {lint, test}
    │ iteration: N/3
    ▼
code-reviewer ──[code_review_to_completion]──▶ workflow/completion
    │ verdict: APPROVED|APPROVED_WITH_COMMENTS|CHANGES_REQUESTED
    │ issues: [{id, severity, category, location, problem, suggestion}]
    │ iteration: N/3
```

### 3.3 State Persistence Flow

```
Checkpoint YAML                    Review JSONL                   Analytics JSONL
(.claude/workflow-state/           (.claude/workflow-state/       (.claude/workflow-state/
 {feature}-checkpoint.yaml)         review-completions.jsonl)      session-analytics.jsonl)
         │                                  │                              │
         │ Written after each phase         │ Written by SubagentStop      │ Written at SessionEnd
         │ 12 YAML fields                   │ {agent, verdict, timestamp}  │ Full session metrics
         │                                  │                              │
         └──── enrich-context.sh reads ─────┴──── enrich-context.sh reads ─┘
                        │
                        ▼
              additionalContext → injected into every prompt
```

---

## 4. CHANGELOG Analysis (v2.1.16 — v2.1.81)

Проанализировано **50+ версий** CHANGELOG. Выделены фичи, релевантные для Workflow pipeline:

### 4.1 New Hook Events

| Version | Feature                                                       | Current Status |
| ------- | ------------------------------------------------------------- | -------------- |
| v2.1.78 | `StopFailure` hook — fires on API errors (rate limit, auth)   | **NOT USED**   |
| v2.1.76 | `PostCompact` hook — fires after compaction                   | **NOT USED**   |
| v2.1.76 | `Elicitation` + `ElicitationResult` hooks                     | **NOT USED**   |
| v2.1.69 | `InstructionsLoaded` hook — fires when CLAUDE.md/rules loaded | **NOT USED**   |
| v2.1.49 | `ConfigChange` hook — fires on settings changes               | **NOT USED**   |
| v2.1.33 | `TeammateIdle` + `TaskCompleted` hooks                        | **NOT USED**   |
| v2.1.50 | `WorktreeCreate` + `WorktreeRemove` hooks                     | **NOT USED**   |

### 4.2 Agent & Frontmatter Features

| Version | Feature                                    | Current Status                                           |
| ------- | ------------------------------------------ | -------------------------------------------------------- |
| v2.1.80 | `effort` frontmatter for skills/commands   | **NOT USED**                                             |
| v2.1.78 | `disallowedTools` frontmatter for agents   | **NOT USED**                                             |
| v2.1.49 | `background: true` for agents              | **NOT USED**                                             |
| v2.1.33 | `memory` frontmatter for agents            | **USED** (plan-reviewer, code-reviewer, code-researcher) |
| v2.1.51 | `isolation: worktree` in agent definitions | **USED** (code-reviewer)                                 |

### 4.3 Tools & Commands

| Version | Feature                                        | Current Status                                                  |
| ------- | ---------------------------------------------- | --------------------------------------------------------------- |
| v2.1.71 | `/loop` — recurring prompts                    | **NOT USED**                                                    |
| v2.1.69 | `${CLAUDE_SKILL_DIR}` variable                 | **NOT USED**                                                    |
| v2.1.63 | HTTP hooks (POST JSON to URL)                  | **NOT USED**                                                    |
| v2.1.63 | `/simplify` bundled command                    | **NOT USED**                                                    |
| v2.1.30 | Token count/tool uses/duration in Task results | **NOT LEVERAGED** in metrics                                    |
| v2.1.69 | `agent_id`/`agent_type` in hook events         | **PARTIALLY USED** (save-review-checkpoint.sh reads agent_type) |
| v2.1.76 | `worktree.sparsePaths`                         | **NOT USED**                                                    |

### 4.4 Platform Improvements (already benefiting workflow)

| Version | Feature                                   | Impact                            |
| ------- | ----------------------------------------- | --------------------------------- |
| v2.1.75 | 1M context for Opus 4.6                   | Deeper planning for XL tasks      |
| v2.1.77 | 64k/128k output token limits              | Longer plan artifacts             |
| v2.1.47 | `last_assistant_message` in SubagentStop  | Used by save-review-checkpoint.sh |
| v2.1.77 | `SendMessage` auto-resumes stopped agents | Better incomplete output recovery |

---

## 5. Improvement Proposals

### IMP-04: `disallowedTools` для plan-reviewer

**Что:** Добавить `disallowedTools: [Write, Edit, Bash]` в frontmatter plan-reviewer.md.

**Как:** Одна строка в frontmatter:

```yaml
disallowedTools:
  - Write
  - Edit
  - Bash
```

**Обоснование:** Plan-reviewer по дизайну read-only агент: «NEVER modify the plan — only recommend changes». Сейчас это правило enforcement-ится только текстовыми инструкциями. v2.1.78 добавил `disallowedTools` — это platform-level enforcement. Если модель случайно попытается изменить план (hallucination), инструменты просто не будут доступны.

**Польза:**

- Platform-level enforcement read-only constraint
- Устранение риска случайной модификации плана ревьюером
- Consistency с design principle: «agents for unbiased review»

**Сложность:** S — одна строка в frontmatter.

---

**Что:** Расширить session-analytics.sh для сбора per-agent метрик с использованием `agent_id` и `agent_type` полей из hook events.

**Как:** Модифицировать `session-analytics.sh`:

- Парсить `agent_type` из hook input
- Агрегировать tool_breakdown по agent_type (orchestrator vs planner vs coder vs reviewer)
- Добавить поле `agent_metrics` в analytics entry

**Обоснование:** v2.1.69 добавил `agent_id`/`agent_type` в hook events. Сейчас session-analytics.sh собирает общую статистику по сессии, без разделения по агентам. Невозможно понять, какой агент потребляет больше всего tool calls, какой застревает в exploration loops, какой использует Sequential Thinking эффективнее.

**Польза:**

- Видимость узких мест: какой агент тормозит pipeline
- Данные для оптимизации budgets (research_budget в planner, evaluate_budget в coder)
- Возможность обнаружить, что code-researcher используется слишком часто/редко для данной complexity

**Сложность:** M — модификация существующего скрипта.

---

### IMP-07: HTTP hooks для внешнего мониторинга

**Что:** Добавить HTTP hook для отправки pipeline events во внешние системы (Slack, dashboards).

**Как:**

- Добавить HTTP hook в settings.json для ключевых событий (SubagentStop, Stop, StopFailure)
- Формат: `{"type": "http", "url": "http://localhost:3000/webhook/claude-pipeline", "method": "POST"}`
- Документировать в settings.local.json.example (не коммитить URL-ы)

**Обоснование:** v2.1.63 добавил HTTP hooks. Текущий мониторинг — только локальные JSONL-файлы. Для команд, работающих с Claude Kit, нужна видимость pipeline status в реальном времени: когда pipeline прошел ревью, когда застрял на loop limit, когда произошел StopFailure.

**Польза:**

- Real-time уведомления в Slack при pipeline events
- Интеграция с внешними dashboards для team visibility
- Возможность триггерить автоматизации (CI/CD, Jira updates)

**Сложность:** S-M — конфигурация в settings.local.json.example + документация.

---

### IMP-08: `${CLAUDE_SKILL_DIR}` для портативных ссылок в skills

**Что:** Заменить относительные пути в SKILL.md файлах на `${CLAUDE_SKILL_DIR}`.

**Как:** В каждом SKILL.md заменить:

- `[MCP Tools](mcp-tools.md)` → `[MCP Tools](${CLAUDE_SKILL_DIR}/mcp-tools.md)`
- `[Task Analysis](task-analysis.md)` → `[Task Analysis](${CLAUDE_SKILL_DIR}/task-analysis.md)`

**Обоснование:** v2.1.69 добавил `${CLAUDE_SKILL_DIR}` для ссылок внутри skills. Сейчас все ссылки — relative markdown links. Относительные ссылки работают, но только если skill загружается из ожидаемого расположения. При копировании skills в другой проект или при использовании через plugins/additional directories, relative paths могут сломаться.

**Польза:**

- Портативность skills при копировании между проектами
- Корректная работа при использовании через --add-dir
- Устойчивость к restructuring директорий

**Сложность:** S — mass replace в markdown файлах. Но нужно проверить, что Claude Code корректно резолвит переменную для ссылок (не для command invocations).

**Риск:** Переменная `${CLAUDE_SKILL_DIR}` предназначена для content в SKILL.md, а не для markdown links. Нужно проверить совместимость.

---

### IMP-13: `ConfigChange` hook для security audit

**Что:** Добавить hook на `ConfigChange` для обнаружения изменений settings во время workflow execution.

**Как:** Создать скрипт `.claude/scripts/audit-config-change.sh`:

- Логирует изменение конфигурации в session-analytics.jsonl
- Если изменились permissions (deny rules removed) → warning в additionalContext
- Добавить в settings.json: `"ConfigChange": [{"matcher": "", "hooks": [{"type": "command", "command": ".claude/scripts/audit-config-change.sh"}]}]`

**Обоснование:** v2.1.49 добавил `ConfigChange` hook. Во время длинного workflow execution модель или пользователь может изменить settings. Если deny rules удалены (случайно или намеренно), pipeline потеряет protection gates. Без audit невозможно отследить, когда и почему protection была ослаблена.

**Польза:**

- Security audit trail для pipeline execution
- Обнаружение ослабления deny rules в реальном времени
- Compliance: доказательство, что pipeline execution происходила с включенными protections

**Сложность:** M — новый скрипт + запись в settings.json.

---

## 6. Priority Matrix

| ID     | Proposal                              | Complexity | Impact               | Priority |
| ------ | ------------------------------------- | ---------- | -------------------- | -------- |
| IMP-13 | `ConfigChange` security audit         | M          | Medium (security)    | **P3**   |
| IMP-07 | HTTP hooks for external monitoring    | S-M        | Medium (integration) | **P3**   |
| IMP-08 | `${CLAUDE_SKILL_DIR}` for portability | S          | Low (portability)    | **P4**   |
| IMP-14 | Background code-researcher            | L          | Medium (performance) | **P4**   |

**P1** (Quick Wins — S complexity, clear benefit): IMP-01, IMP-04, IMP-09
**P2** (High Impact — M complexity, significant benefit): IMP-02, IMP-03, IMP-05, IMP-06, IMP-15
**P3** (Medium Impact): IMP-07, IMP-10, IMP-11, IMP-13
**P4** (Future/Risky): IMP-08, IMP-12, IMP-14

---

## 7. Conclusion

Workflow pipeline представляет собой зрелую, хорошо структурированную систему с 137 артефактами. Основные сильные стороны:

- **Typed handoff contracts** между всеми фазами (MetaGPT pattern)
- **Loop limits** с tracking и recovery
- **Checkpoint-based session recovery** с heuristic fallback
- **Hook automation** (8 event types, 14 scripts) для enforcement без ручного контроля
- **Context isolation** для review agents (unbiased review, no creation bias)

Основные области для улучшения (по результатам CHANGELOG analysis):

1. **Observability gap**: Pipeline не фиксирует API errors (StopFailure), per-agent metrics, tool-agent costs
2. **State integrity**: PostCompact verification отсутствует, checkpoint auto-save не реализован
3. **Platform-level enforcement**: disallowedTools для plan-reviewer, effort tuning для всех компонентов
4. **External integration**: HTTP hooks для team-level monitoring не используются

15 предложений по улучшению ранжированы по приоритету (P1-P4) с учетом сложности реализации и ожидаемого impact.
