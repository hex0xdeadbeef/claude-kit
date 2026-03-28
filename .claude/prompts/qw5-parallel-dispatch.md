---
title: "QW-5: Parallel Agent Dispatch Protocol"
feature: qw5-parallel-dispatch
task_type: new_skill_file
complexity: XL
status: pending_review
plan_version: "1.0"
created: "2026-03-29"
---

# Plan: Parallel Agent Dispatch — supporting file для workflow-protocols

## Context

Из cross-review Superpowers (QW-5): адаптировать паттерн dispatch одного агента per independent problem domain. Superpowers инкапсулирует это в `skills/dispatching-parallel-agents/SKILL.md` — decision flowchart, prompt structure, conflict detection.

В Claude Kit уже есть partial реализация: code-researcher поддерживает `run_in_background: true` в /planner Phase 3. Но паттерн не формализован — нет decision criteria, нет multi-dispatch шаблона, нет post-merge conflict check.

**Цель:** Добавить `parallel-dispatch.md` как supporting file в `workflow-protocols` skill. Обновить SKILL.md — добавить event trigger. Никаких архитектурных изменений.

## Scope

### IN
- Создать `.claude/skills/workflow-protocols/parallel-dispatch.md`
- Обновить `.claude/skills/workflow-protocols/SKILL.md` — добавить protocol entry + event trigger
- Адаптировать decision flowchart под контекст Claude Kit (code-researcher multi-dispatch + /coder debugging)
- Документировать существующий background mode как часть паттерна

### OUT
- Изменения в `/planner`, `/coder`, или других командах — только документация паттерна
- Новые hooks или agents
- Изменения в `workflow-architecture.md` (это reference-документ, не spec)

## Исследование (завершено перед написанием плана)

### Superpowers — dispatching-parallel-agents

Ключевые концепции из `superpowers-main/skills/dispatching-parallel-agents/SKILL.md`:

**Decision flowchart:**
```
Multiple tasks/failures?
  → Are they independent? (no shared state, fix-one doesn't fix-others)
    → Can they work in parallel? (no file conflicts)
      → Parallel dispatch (one agent per domain)
      → Sequential agents (shared state)
    → Single agent (related failures)
```

**4-step pattern:**
1. Identify independent domains (group by root cause area)
2. Create focused agent prompts (scope + goal + constraints + expected output)
3. Dispatch in parallel (all Task/Agent calls in one message)
4. Review and integrate (conflict check → full suite → spot check)

**Focused prompt structure (обязательные поля):**
- Specific scope: one subsystem/file
- Clear goal: what to achieve
- Constraints: don't change other code
- Expected output: summary format

**Anti-patterns:** Too broad scope, no context, no constraints, vague output

### Claude Kit — существующий background mode

Из `workflow-architecture.md` и `commands/planner.md`:

- **Где используется:** `/planner` Phase 3 (Research), complexity L/XL
- **Механизм:** `Agent tool` с `run_in_background: true`
- **Async integration point:** /planner DESIGN phase — ждёт результатов фоновых агентов
- **Ограничение:** Только для read-only research, не для fix/implementation

Из `commands/workflow.md` (code_researcher_usage):
```
invoked_by: "planner (Phase 3) and coder (Phase 1.5) — NOT by orchestrator"
mechanism: "Agent tool (run_in_background supported) or Task tool"
returns: "Structured summary ≤2000 tokens"
```

### Два контекста использования в Claude Kit

**Контекст 1: /planner Research Phase (существующий, background mode)**
- Несколько независимых research-вопросов (разные части кодовой базы)
- Все агенты read-only — no file conflicts by construction
- Parallel → всегда OK, нет shared state

**Контекст 2: /coder — независимые failing tests (новый случай)**
- N test файлов с разными root causes
- Агенты могут edit файлы — нужна проверка на file overlap ПЕРЕД dispatch
- Conflict detection post-merge обязательна

### SKILL.md — текущее состояние

Workflow-protocols уже имеет event triggers для:
- "Completing a phase → Checkpoint Protocol"
- "Forming handoff → Handoff Protocol"
- "Mismatch signal → Re-routing"
- "All phases done → Pipeline Metrics"

**Gap:** нет trigger для "multiple independent research questions" или "independent failures".

## Architecture Decision

**Где хранить:** `.claude/skills/workflow-protocols/parallel-dispatch.md`
- Rationale: Паттерн относится к orchestration (как /workflow и /planner координируют агентов), не к конкретной фазе (planner-rules) или имплементации (coder-rules)
- Аналог в Superpowers: отдельный skill; у нас — supporting file внутри workflow-protocols (меньше overhead, нет нужды в отдельном SKILL.md)

**Trigger для загрузки:** "Multiple independent research questions OR independent failures identified"
- Загружается on-demand, не при старте (event-driven модель workflow-protocols)

**Как интегрировать с background mode:** parallel-dispatch.md описывает паттерн; существующий background mode code-researcher — конкретная реализация для Research Use Case. Документ унифицирует оба случая под одним паттерном.

## Parts

### Part 1: Создать parallel-dispatch.md

**Файл:** `.claude/skills/workflow-protocols/parallel-dispatch.md`

**Структура:**

```yaml
# YAML frontmatter: name, description, когда загружать
```

**Секции:**

**1. Overview (2-3 предложения)**
- Когда параллельный dispatch быстрее последовательного
- Ключевое условие: independence (no shared state, no file conflicts)

**2. Decision Flowchart**
Mermaid-адаптация из Superpowers dot-graph:
```
Multiple tasks/questions?
  → Are they independent? (разные файлы, разные root causes)
    → File overlap possible? (только для fix-agents, не для read-only)
      → Parallel dispatch
      → Sequential (если один файл редактируется несколькими агентами)
    → Single agent (related tasks)
```

**3. Use Case 1: Research Multi-Dispatch (/planner Phase 3)**

Когда применять:
- L/XL complexity, 3+ независимых research question
- Разные пакеты/слои (handler vs service vs repository)
- Каждый вопрос самодостаточен

Паттерн:
```
// Dispatch ALL background agents в одном сообщении
Agent("Explore handler layer patterns", run_in_background: true)
Agent("Explore service layer patterns", run_in_background: true)
Agent("Explore repository layer patterns", run_in_background: true)
// Продолжить DESIGN phase
// Async integration point: проверить результаты перед финализацией
```

Focused prompt template для code-researcher:
```
Research question: [конкретный вопрос]
Scope: [пакет/директория]
Focus areas: [что искать]
Return: structured summary ≤2000 tokens (patterns, files, imports, key snippets)
```

Async integration point:
- Проверить результаты при переходе к DESIGN
- Если late findings противоречат design → inline revision (≤1 part) или re-evaluate

**4. Use Case 2: Independent Failure Investigation (/coder debugging)**

Когда применять:
- 3+ test файлов failing с разными root causes
- Независимые subsystems (abort logic ≠ batch completion ≠ race conditions)
- NO shared state между investigations

Pre-dispatch checklist (ОБЯЗАТЕЛЬНО):
```
□ Failures confirmed independent (fix-one не fix-others)?
□ File overlap check: agents edit разные файлы?
□ No shared mocks or test fixtures?
```

Паттерн:
```
// После Independence check
Task("Investigate и fix [failure domain A]")
Task("Investigate и fix [failure domain B]")
Task("Investigate и fix [failure domain C]")
// Wait for ALL to complete
// Post-merge conflict detection
```

Focused prompt template:
```
Fix failing tests in [конкретный файл/subsystem]:
- [test name 1]: [expected behavior]
- [test name 2]: [expected behavior]

Root cause area: [timing/race condition/data structure/etc.]

Constraints:
- Do NOT change [other files]
- Fix tests only, don't refactor production code

Return: root cause identified + changes made (file:line)
```

**5. Post-Merge Conflict Detection**

После того как все агенты вернули результаты:
```
1. Read each summary (что изменил каждый агент)
2. Check file overlap: git diff --name-only per agent's changes
3. If overlap detected → manual review of conflicting sections
4. Run full test suite (не только targeted tests)
5. Spot check: агенты могут делать systematic errors
```

Red flags после merge:
- Два агента изменили один файл → review обоих изменений
- Один агент fix сломал тест другого агента → связанные проблемы, не независимые

**6. Common Mistakes**
- Too broad scope → агент теряется
- No constraints → агент рефакторит всё
- Related failures диспатчены параллельно → конфликты и гонки
- Skip post-merge conflict check → скрытые несовместимости

**7. When NOT to Use**
- Failures related (fix one might fix others) → single agent + systematic debugging
- Exploratory debugging (root cause неизвестен) → investigate first, dispatch after
- Shared state (same config, same db, same mock) → sequential

### Part 2: Обновить SKILL.md workflow-protocols

**Файл:** `.claude/skills/workflow-protocols/SKILL.md`

**Изменения:**

1. Добавить в таблицу Protocol Overview:

```markdown
| Parallel Dispatch | Multiple independent research questions OR independent failures | Multi-agent dispatch patterns (research + debugging) |
```

2. Добавить в Event Triggers:

```markdown
- Multiple independent research questions (L/XL planner) OR independent failures identified → read [Parallel Dispatch](parallel-dispatch.md)
```

3. Добавить в Protocol References:

```markdown
- [Parallel Dispatch](parallel-dispatch.md) — decision flowchart, research multi-dispatch, failure isolation, conflict detection
```

## Files Summary

- CREATE `.claude/skills/workflow-protocols/parallel-dispatch.md`
- MODIFY `.claude/skills/workflow-protocols/SKILL.md` (добавить 3 строки)

## Acceptance Criteria

- [ ] `parallel-dispatch.md` создан и содержит decision flowchart (Mermaid)
- [ ] Use Case 1 (research multi-dispatch) документирует существующий background mode как часть паттерна
- [ ] Use Case 2 (independent failures) содержит pre-dispatch checklist с file overlap check
- [ ] Post-merge conflict detection — конкретные шаги (не абстрактно)
- [ ] Focused prompt templates для обоих use cases
- [ ] Common Mistakes и When NOT to Use секции
- [ ] SKILL.md обновлён: Protocol Overview table + Event Triggers + Protocol References
- [ ] YAML frontmatter корректный
- [ ] Файл ≤250 строк (supporting file, не основной SKILL.md)
- [ ] YAML-first формат (minimal prose, bullet-driven)

## Testing Plan

Documentation task — no code tests.

Verification:
- Прочитать parallel-dispatch.md, убедиться что все 7 секций присутствуют
- Проверить Mermaid flowchart на синтаксис
- Убедиться что SKILL.md обновлён корректно (таблица + triggers + references)
- Проверить что Use Case 1 ссылается на существующий background mode (не изобретает новый механизм)

## Handoff Notes

Весь research завершён в этом плане. Implementer (coder) может работать напрямую — дополнительных filesystem reads не требуется, кроме spot-check существующих файлов.

Ключевые решения:
- parallel-dispatch.md — supporting file (не отдельный skill пакет)
- Два use case разделены чётко: read-only research (всегда OK) vs fix-agents (нужен pre-check)
- Post-merge conflict detection — конкретный процесс, не абстрактный принцип
- Flowchart в Mermaid (не dot — наш стандарт)
- Файл ≤250 строк — поддерживаем size limit workflow-protocols supporting files
