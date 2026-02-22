# Task Analysis

Классификация и маршрутизация задачи ПЕРЕД началом планирования.

---

## Purpose

Определить тип, сложность и оптимальный маршрут задачи ДО того, как planner начнёт research. Цель — тривиальные задачи не должны проходить полный 4-фазный цикл.

**⚠️ NEVER skip TASK ANALYSIS — wrong routing = wasted time on over-/under-planning.**

---

## Step 1: Classify Task Type

```yaml
task_types:
  - type: "new_feature"
    keywords: "добавить, создать, реализовать, новый endpoint, new"
    typical_complexity: M-XL

  - type: "bug_fix"
    keywords: "исправить, баг, fix, broken, не работает"
    typical_complexity: S-M

  - type: "refactoring"
    keywords: "рефакторинг, переписать, вынести, разделить, extract"
    typical_complexity: M-L

  - type: "config_change"
    keywords: "конфиг, параметр, переменная окружения, config"
    typical_complexity: S

  - type: "documentation"
    keywords: "документация, README, описать, задокументировать"
    typical_complexity: S

  - type: "performance"
    keywords: "оптимизация, медленно, performance, N+1, cache"
    typical_complexity: M-L

  - type: "integration"
    keywords: "интеграция, external service, API call, клиент"
    typical_complexity: L-XL
```

---

## Step 2: Estimate Complexity

```yaml
complexity_matrix:
  S:
    parts: "1"
    layers: "1"
    files: "1-2"
    examples:
      - "Добавить поле в модель"
      - "Исправить опечатку"
      - "Обновить конфиг"
    indicators:
      - "Изменения в одном слое архитектуры"
      - "Нет новых зависимостей"
      - "Паттерн уже существует в проекте"

  M:
    parts: "2-3"
    layers: "2"
    files: "3-5"
    examples:
      - "Добавить новое поле через все слои (model → controller → API)"
      - "Исправить баг с error handling в нескольких местах"
    indicators:
      - "Изменения в 2 слоях"
      - "Следует существующим паттернам"
      - "Нет архитектурных решений"

  L:
    parts: "4-6"
    layers: "3+"
    files: "6-10"
    examples:
      - "Новый endpoint с database → domain → API"
      - "Рефакторинг controller с разделением на сервисы"
    indicators:
      - "Затрагивает 3+ слоя архитектуры"
      - "Может потребовать архитектурное решение"
      - "Новые SQL queries или миграции"

  XL:
    parts: "7+"
    layers: "4+"
    files: "10+"
    examples:
      - "Новый домен с полным стеком (DB → models → controller → API → tests)"
      - "Интеграция с внешним сервисом"
      - "Плагинная архитектура"
    indicators:
      - "Cross-domain изменения"
      - "Новая интеграция с внешней системой"
      - "Нужен Sequential Thinking для выбора подхода"
```

---

## Step 3: Route Decision

```yaml
routing:
  S:
    planner_mode: "--minimal"
    plan_review: "SKIP (опционально)"
    code_review: "standard"
    sequential_thinking: "НЕ нужен"
    note: "Быстрый путь — не перегружать процесс для тривиальных задач"

  M:
    planner_mode: "standard"
    plan_review: "standard"
    code_review: "standard"
    sequential_thinking: "по необходимости"
    note: "Основной рабочий режим"

  L:
    planner_mode: "standard"
    plan_review: "standard"
    code_review: "standard + parallel agents (если >5 файлов)"
    sequential_thinking: "РЕКОМЕНДОВАН"
    note: "Полный flow с возможной параллелизацией ревью"

  XL:
    planner_mode: "full research"
    plan_review: "standard + Sequential Thinking ОБЯЗАТЕЛЕН"
    code_review: "standard + parallel agents"
    sequential_thinking: "ОБЯЗАТЕЛЕН"
    note: "Максимальный flow — все проверки, все инструменты"
```

---

## Step 4: Preconditions Check

```yaml
preconditions:
  always:
    - check: "git status clean?"
      fail_action: "WARN: uncommitted changes detected"

  if_beads:
    - check: "bd show <id> → не blocked?"
      fail_action: "STOP: задача заблокирована. SEE: bd blocked"
    - check: "Зависимости закрыты?"
      fail_action: "WARN: зависимость <dep-id> ещё открыта"

  if_database:
    - check: "Схема актуальна? (migrations applied)"
      fail_action: "WARN: pending migrations detected"

  if_external_library:
    - check: "Библиотека в go.mod?"
      fail_action: "INFO: потребуется go get"
```

---

## Output Format

```yaml
## Task Analysis Result

Type: {new_feature | bug_fix | refactoring | config_change | documentation | performance | integration}
Complexity: {S | M | L | XL}
Route: {minimal | standard | full}
Sequential Thinking: {required | recommended | not_needed}
Plan Review: {skip | standard}
Preconditions: {all_clear | warnings_list}

Rationale: "{1-2 предложения почему выбрана эта сложность и маршрут}"
```

---

## Examples

### Example 1: Simple Config Change

```
Input: "Добавить timeout параметр в конфиг HTTP-сервера"

Task Analysis:
  Type: config_change
  Complexity: S (1 Part, 1 layer — config only)
  Route: minimal
  Sequential Thinking: not_needed
  Plan Review: skip
  Rationale: "Стандартное добавление конфиг-параметра, паттерн уже существует"
```

### Example 2: New API Endpoint

```
Input: "Добавить endpoint GET /api/v1/{resource}/:id"

Task Analysis:
  Type: new_feature
  Complexity: L (5 Parts: DB query + model + controller + handler + tests)
  Route: standard
  Sequential Thinking: recommended
  Plan Review: standard
  Rationale: "Новый endpoint через все слои, но следует существующему паттерну для данного ресурса"
```

### Example 3: Plugin Architecture

```
Input: "Реализовать систему плагинов для worker'а"

Task Analysis:
  Type: new_feature
  Complexity: XL (новый паттерн, cross-domain, 10+ файлов)
  Route: full
  Sequential Thinking: required
  Plan Review: standard
  Rationale: "Архитектурное решение с 3+ альтернативами, затрагивает несколько доменов"
```

---

## Re-Routing Mechanism

```yaml
re_routing:
  purpose: "Корректировка route если начальная оценка complexity оказалась неточной"
  severity: MEDIUM

  triggers:
    downgrade:
      - trigger: "plan-review: план проще ожидаемого"
        condition: "Parts < expected for route OR layers < expected"
        actions:
          L_to_M: "Убрать обязательный Sequential Thinking, standard checks"
          M_to_S: "Skip plan-review в следующей итерации"
        example: "Classified as L (5 Parts), plan-review видит 2 Parts → downgrade to M"

      - trigger: "coder evaluate: план тривиален"
        condition: "PROCEED без adjustments, 1-2 файла"
        actions:
          M_to_S: "Simplified code-review (no parallel agents)"

    upgrade:
      - trigger: "plan-review: план сложнее ожидаемого"
        condition: "Parts > expected OR cross-domain dependencies found"
        actions:
          S_to_M: "Добавить full plan-review (был skipped)"
          M_to_L: "Добавить Sequential Thinking requirement"
        example: "Classified as S, but plan-review видит 4 Parts + 3 layers → upgrade to L"

      - trigger: "coder evaluate: hidden complexity"
        condition: "REVISE с 3+ adjustments OR RETURN"
        actions:
          M_to_L: "Добавить Sequential Thinking, return to planner"
          L_to_XL: "Mandatory Sequential Thinking, full research"
        example: "Classified as M, coder видит нужна DB migration + new service → upgrade to L"

  tracking:
    - "Записать re-routing в checkpoint: original_route → new_route + reason"
    - "Сохранить в MCP Memory для улучшения heuristics task-analysis"
    - "Format: 'Re-routing: {task_type}/{original} → {new} because {reason}'"
```

---

## Anti-Patterns

❌ **DON'T skip task analysis for "obvious" tasks**
```
# BAD: Jump straight to planning
/planner "добавить поле в модель"
→ Full research, full plan, full review for a 5-line change
```

✅ **DO classify first, then route appropriately**
```
# GOOD: Classify → route → execute
Task Analysis: S complexity → /planner --minimal → skip plan-review → /coder
```

❌ **DON'T ignore re-routing signals**
```
# BAD: plan-review finds 4 Parts but route stays S
Plan classified as S → plan-review finds cross-domain dependencies → continues with S route
```

✅ **DO re-route when evidence contradicts classification**
```
# GOOD: re-route based on evidence
Plan classified as S → plan-review finds 4 Parts + 3 layers → upgrade to M/L
```

---

## SEE ALSO

- `shared-autonomy.md` — Autonomy modes affected by routing
- `workflow-phases.md` — Phase execution affected by skip decisions
- `planner.md` — Receives classification as input context
