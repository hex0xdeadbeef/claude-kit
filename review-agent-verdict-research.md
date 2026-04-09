# Research: Review Agent Verdict Loss — Root Cause Analysis & Improvement Plan

> **Status:** Investigation complete  
> **Problem:** Code-review (and plan-review) agents repeatedly re-launched due to UNKNOWN verdict in review-completions.jsonl  
> **Evidence source:** `/Users/dmitriym/Desktop/catalog/.claude/workflow-state/` (production logs from 2026-04-09)  
> **Scope of fix:** `/Users/dmitriym/Desktop/claude-kit` (this repository)  
> **Complexity:** XL — 5 root causes, 6 improvements, 3 files to modify

---

## 1. Problem Statement

После выполнения фазы code-review (или plan-review) агент не возвращает чёткого вердикта, и оркестратор повторно запускает ревью. Это происходит систематически, замедляя весь workflow.

Конкретные проявления из production-логов:
- `review-completions.jsonl`: 9 из 18 записей (50%) имеют `"verdict": "UNKNOWN"`
- `worktree-events-debug.jsonl`: SubagentStop срабатывает для агентов с `"agent_type": ""` (пустая строка)
- `task-events.jsonl`: план-ревьюер запускался 3+ раза в рамках одного сеанса
- `worktree-events-debug.jsonl`: WorktreeCreate логирует `"worktree_path_found": false` для всех событий

---

## 2. Граф взаимодействия артефактов

```
┌─────────────────────────────────────────────────────────────────────┐
│ ORCHESTRATOR (/workflow command, Claude's context)                   │
│                                                                     │
│  Читает: .claude/workflow-state/{feature}-checkpoint.yaml           │
│  Пишет:  checkpoint.yaml (после каждой фазы)                        │
│  Решает: APPROVED → Phase 5 / CHANGES_REQUESTED → /coder / UNKNOWN → re-launch │
└────────┬────────────────────────────────────────────────────────────┘
         │ делегирует (Agent tool, isolation: none)
         ▼
┌────────────────────────┐        ┌────────────────────────┐
│ plan-reviewer agent    │        │ code-reviewer agent    │
│ .claude/agents/        │        │ .claude/agents/        │
│ plan-reviewer.md       │        │ code-reviewer.md       │
│ isolation: none        │        │ isolation: WORKTREE     │
│ maxTurns: 60           │        │ maxTurns: 60           │
│ memory: project        │        │ memory: project        │
└────────┬───────────────┘        └────────┬───────────────┘
         │                                  │
         │ SubagentStart event              │ SubagentStart event (→ WorktreeCreate)
         ▼                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│ HOOKS CHAIN (settings.json)                                         │
│                                                                     │
│ SubagentStart [matcher: "plan-reviewer"] ─────────────────────────► │
│   → track-task-lifecycle.sh (logs to task-events.jsonl)             │
│   → inject-review-context.sh plan-reviewer (→ additionalContext)    │
│                                                                     │
│ SubagentStart [matcher: "code-reviewer"] ─────────────────────────► │
│   → track-task-lifecycle.sh (logs to task-events.jsonl)             │
│   → inject-review-context.sh code-reviewer (→ additionalContext)    │
│                                                                     │
│ WorktreeCreate [matcher: ""] ─────────────────────────────────────► │
│   → prepare-worktree.sh                                             │
│     → resolve-worktree-path.py (IMP-11)                             │
│     → go mod download (в воркдереве)                                │
│     → agent-memory pre-seed (IMP-09)                                │
│     → пишет worktree-events.jsonl                                   │
│     → пишет worktree-events-debug.jsonl (DEBUG)                     │
│                                                                     │
│ SubagentStop [matcher: "plan-reviewer|code-reviewer"] ────────────► │
│ ⚠️  КРИТИЧЕСКАЯ ТОЧКА ОТКАЗА                                        │
│   → save-review-checkpoint.sh                                       │
│     → Читает payload: agent_type (ЧАСТО ПУСТОЙ "")                  │
│     → Читает transcript_path JSONL → ищет "VERDICT:" regex          │
│     → IMP-H: блокирует stop IF (verdict==UNKNOWN AND agent in       │
│       REVIEW_AGENTS AND agent_id) — НЕ РАБОТАЕТ когда agent_type="" │
│     → Пишет review-completions.jsonl                                │
│     → Пишет worktree-events-debug.jsonl (DEBUG)                     │
└─────────────────────────────────────────────────────────────────────┘
         │ читает                           │ читает (output_validation)
         ▼                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│ .claude/workflow-state/                                             │
│                                                                     │
│  review-completions.jsonl   ← ЗАГРЯЗНЁН записями "unknown" агентов  │
│  {feature}-checkpoint.yaml  ← сохраняет verdict из review          │
│  worktree-events-debug.jsonl ← отладочные данные (исследование)     │
│  task-events.jsonl          ← SubagentStart события                 │
└─────────────────────────────────────────────────────────────────────┘

Легенда:
  ⚠️ — точка отказа / проблемный компонент
  → — направление потока данных
  ─► — hook event flow
```

---

## 3. Детальный анализ компонентов

### 3.1 `save-review-checkpoint.sh` — центральный компонент

**Расположение:** `.claude/scripts/save-review-checkpoint.sh`

**Назначение:** Blocking SubagentStop hook. Извлекает вердикт из завершающегося агента и пишет в `review-completions.jsonl`.

**Алгоритм извлечения вердикта:**
```
1. Читает payload stdin как JSON
2. agent_type = payload.agent_type OR payload.agent_name OR payload.name OR "unknown"
3. Стратегия 1: payload.last_assistant_message (поле добавлено в v2.1.47, может отсутствовать)
4. Стратегия 2: читает transcript_path JSONL в обратном порядке, ищет последнее
   assistant-сообщение → regex: r'(?i)verdict:\s*(APPROVED_WITH_COMMENTS|APPROVED|...)'
5. IMP-H: если verdict==UNKNOWN И agent_type in {"plan-reviewer","code-reviewer"} И agent_id:
   → записывает .verdict-block-{agent_id} маркер → exit 0 с decision:"block"
   → второй раз: удаляет маркер, разрешает stop
6. Пишет запись в review-completions.jsonl
```

**Ключевая уязвимость IMP-H:**
```python
# Эта проверка ПРОВАЛИТСЯ если agent_type == "" (пустая строка)
if verdict == "UNKNOWN" and agent_type in REVIEW_AGENTS and agent_id:
    # agent_type = "unknown" (из пустой строки)
    # "unknown" NOT IN {"plan-reviewer", "code-reviewer"}
    # → IMP-H НЕ СРАБАТЫВАЕТ → агент останавливается без вердикта
```

### 3.2 `settings.json` — конфигурация хуков

**SubagentStop matcher:** `"plan-reviewer|code-reviewer"`

**Проблема:** Matcher должен фильтровать только review-агентов. НО:
- Хук срабатывает для агентов с `agent_type: ""` (пустая строка)
- Claude Code v2.1.x имеет баг: при пустом `agent_type` matcher может не отфильтровать
- Результат: хук активируется для ВСЕХ агентов, включая неизвестные

### 3.3 `code-reviewer.md` — агент с isolation: worktree

**Критическое поведение:**
- `isolation: worktree` → Claude Code создаёт отдельный git-worktree для агента
- В SubagentStop payload: `agent_type: ""` (пустая строка) — **это поведение Claude Code для worktree-агентов**
- SubagentStart для code-reviewer срабатывает корректно (agent_type = "code-reviewer")
- SubagentStop для code-reviewer возвращает agent_type = "" → записывается как "unknown"

### 3.4 `inject-review-context.sh` — контекстная инъекция

**Назначение:** SubagentStart hook. Инъектирует workflow-контекст (feature, complexity, iteration, prior verdicts) как `additionalContext`.

**Последствие пустого agent_type:** Если code-reviewer запускается без SubagentStart (или SubagentStart не матчится), inject-review-context.sh не срабатывает → агент не получает контекст итерации → может выдать неформатированный вывод.

---

## 4. Root Cause Analysis — 5 корневых причин

### RC-1: SubagentStop matcher не фильтрует агентов с пустым agent_type

**Описание:**  
Claude Code v2.1.x при агентах с `isolation: worktree` передаёт в SubagentStop payload `agent_type: ""` (пустую строку). Matcher `"plan-reviewer|code-reviewer"` должен НЕ матчить пустую строку. Однако хук срабатывает — предположительно fail-open поведение: если поле не совпадает, Claude Code всё равно запускает хук.

**Доказательства из логов:**
```jsonl
// worktree-events-debug.jsonl — повторяется 9 раз
{
  "hook": "SubagentStop",
  "agent_type": "unknown",           // ← script записал "unknown" вместо правильного типа
  "payload_sample": {
    "agent_type": "",                 // ← ПУСТАЯ СТРОКА в payload от Claude Code
    "hook_event_name": "SubagentStop"
  },
  "verdict_found": false
}
```

**Последствие:** `review-completions.jsonl` загрязняется записями от посторонних агентов:
```jsonl
{"agent": "unknown", "verdict": "UNKNOWN", ...}  // от неизвестного агента
{"agent": "plan-reviewer", "verdict": "APPROVED", ...}  // настоящий вердикт
{"agent": "unknown", "verdict": "UNKNOWN", ...}  // снова загрязнение ПОСЛЕ вердикта
```

### RC-2: code-reviewer не записывает agent_type в SubagentStop при isolation: worktree

**Описание:**  
Когда агент запускается с `isolation: worktree`, Claude Code создаёт изолированный worktree. В момент SubagentStop `agent_type` приходит пустым. Это блокирует ВСЕ защитные механизмы, которые проверяют `agent_type in REVIEW_AGENTS`.

**Доказательства:**
```
Временна́я шкала session 49ad8007:
  17:37 SubagentStart  — plan-reviewer (agent_type: "plan-reviewer")  ✓
  17:41 SubagentStop   — plan-reviewer (agent_type: "plan-reviewer")  ✓ APPROVED
  17:53 WorktreeCreate — code-reviewer создаёт worktree               ←──┐
  18:05 SubagentStop   — agent_type: ""  verdict: UNKNOWN             ←── code-reviewer!
  18:19 SubagentStop   — agent_type: ""  verdict: UNKNOWN
  18:26 SubagentStart  — plan-reviewer (RE-LAUNCH!)  ← неверная реакция
```

### RC-3: Нет корреляции agent_id между SubagentStart и SubagentStop

**Описание:**  
При SubagentStart агент регистрируется с корректным `agent_type` и `agent_id`. При SubagentStop тот же `agent_id` приходит, но `agent_type` пустой. Нет механизма сопоставления этих событий для восстановления типа агента.

**Доказательства:**
```
SubagentStart: agent_id=acc34e6d  agent_type="plan-reviewer"  ✓
SubagentStop:  agent_id=acc34e6d  agent_type=""               ✗ не сопоставляется

SubagentStart: agent_id=???  (нет записи для code-reviewer!)
SubagentStop:  agent_id=a28244fc  agent_type=""               ✗ code-reviewer без идентификации
```

Примечание: SubagentStart для code-reviewer в логах НЕ ВИДЕН — возможно, hook не срабатывает для worktree-агентов на SubagentStart.

### RC-4: Оркестратор читает review-completions.jsonl без фильтрации по agent_type

**Описание:**  
Когда оркестратор выполняет output_validation (orchestration-core.md Phase 2/4), он проверяет наличие вердикта в `review-completions.jsonl`. Если последняя запись — `{"agent": "unknown", "verdict": "UNKNOWN"}`, оркестратор считает, что ревью не вернуло вердикт, и запускает recovery flow.

**Последствие:** Оркестратор RE-LAUNCH-ит plan-reviewer (вместо code-reviewer или verdict-recovery), потому что видит UNKNOWN ПОСЛЕ APPROVED:

```jsonl
// review-completions.jsonl — что видит оркестратор
{"agent": "plan-reviewer", "verdict": "APPROVED"}    // ← правильный вердикт
{"agent": "unknown",        "verdict": "UNKNOWN"}    // ← загрязнение от code-reviewer
{"agent": "unknown",        "verdict": "UNKNOWN"}    // ← ещё загрязнение
// оркестратор читает последнее → UNKNOWN → re-launch план-ревьюера ← неверно!
```

### RC-5: WorktreeCreate не может разрешить путь к worktree

**Описание:**  
`prepare-worktree.sh` вызывает `resolve-worktree-path.py` для определения пути воркдерева. Все 4 события WorktreeCreate в логах возвращают `"worktree_path_found": false`. Это означает:
- `go mod download` не запускается в воркдереве
- agent-memory не копируется в воркдерево (не pre-seed)
- code-reviewer запускается без необходимых зависимостей

**Доказательства:**
```jsonl
// worktree-events-debug.jsonl — все 4 WorktreeCreate события
{"hook": "WorktreeCreate", "worktree_path_found": false, "worktree_resolution": null}
{"hook": "WorktreeCreate", "worktree_path_found": false, "worktree_resolution": null}
{"hook": "WorktreeCreate", "worktree_path_found": false, "worktree_resolution": null}
{"hook": "WorktreeCreate", "worktree_path_found": false, "worktree_resolution": null}
```

Payload WorktreeCreate содержит только: `["cwd", "hook_event_name", "name", "session_id", "transcript_path"]`  
Отсутствуют: `worktree_path`, `worktree_name`, `worktree_branch`, `original_repo_dir` — поля, которые ожидает resolver.

---

## 5. Дерево причинно-следственных связей

```
ПРОБЛЕМА: Review re-launched (review не возвращает чёткий вердикт)
│
├── RC-1: SubagentStop matcher fail-open для agent_type=""
│   ├── Загрязнение review-completions.jsonl записями "unknown"
│   └── IMP-H не может заблокировать (agent_type не в REVIEW_AGENTS)
│
├── RC-2: isolation:worktree → agent_type="" в SubagentStop
│   ├── code-reviewer не идентифицируется как review-агент
│   ├── IMP-H блок не срабатывает
│   └── Агент может остановиться без вердикта
│
├── RC-3: Нет agent_id → agent_type корреляции
│   └── Невозможно восстановить тип агента по ID
│
├── RC-4: Оркестратор читает JSONL без фильтрации
│   ├── Видит UNKNOWN (от code-reviewer) как текущий вердикт
│   └── Неверно re-launch-ит plan-reviewer вместо verdict-recovery
│
└── RC-5: WorktreeCreate payload не содержит worktree_path
    ├── go mod download не запускается
    └── agent-memory не копируется → агент без контекста прошлых ревью
```

---

## 6. Лист улучшений

### IMP-01: Agent-ID Registry — сопоставление SubagentStart с SubagentStop

**Суть:** При SubagentStart для review-агентов сохранять `agent_id → agent_type` в файл-реестр. При SubagentStop читать реестр для восстановления agent_type.

**Файл для изменения:** `.claude/scripts/track-task-lifecycle.sh` (добавить запись в реестр) + `.claude/scripts/save-review-checkpoint.sh` (добавить чтение реестра).

**Реализация:**
```python
# track-task-lifecycle.sh — при SubagentStart
registry_file = ".claude/workflow-state/agent-id-registry.jsonl"
# Записывать: {"agent_id": "...", "agent_type": "plan-reviewer", "session_id": "..."}

# save-review-checkpoint.sh — при SubagentStop, если agent_type == ""
registry = read_agent_id_registry()
if agent_id in registry:
    agent_type = registry[agent_id]  # восстановить тип агента
```

**Почему это нужно:**  
RC-3 — без корреляции SubagentStart/Stop невозможно определить тип агента, когда Claude Code не передаёт `agent_type` в SubagentStop. Этот файл решает проблему на уровне данных.

**Польза:** IMP-H начнёт работать для code-reviewer (isolation: worktree), потому что `agent_type` будет восстановлен из реестра.

**Scope:** NON_CRITICAL failure — если реестр недоступен, продолжить как сейчас (graceful degradation).

---

### IMP-02: Фильтрация review-completions.jsonl по registered agent_ids

**Суть:** Оркестратор и output_validation должны читать review-completions.jsonl с фильтрацией:
1. По `agent_type` (игнорировать "unknown")
2. По session_id (игнорировать записи из других сессий)
3. По registered agent_ids (из agent-id-registry.jsonl)

**Файл для изменения:** `.claude/skills/workflow-protocols/orchestration-core.md` (инструкции для оркестратора) + `.claude/scripts/inject-review-context.sh` (already reads completions).

**Реализация (в orchestration-core.md):**
```yaml
output_validation:
  read_review_completions:
    filter_by:
      - agent_type: ["plan-reviewer", "code-reviewer"]  # игнорировать "unknown"
      - session_id: current_session_id                  # только текущая сессия
    fallback: "if no matching entry → INCOMPLETE_OUTPUT"
    note: "Entries with agent_type='unknown' are noise from platform behavior — ignore"
```

**Почему это нужно:**  
RC-4 — оркестратор не фильтрует записи и видит UNKNOWN от code-reviewer как сигнал о провале plan-reviewer. Фильтрация устраняет false positives.

**Польза:** Оркестратор перестанет re-launch-ить plan-reviewer по вине code-reviewer entries. Correct escalation path: UNKNOWN code-reviewer → verdict-recovery, не plan-reviewer.

---

### IMP-03: Hardened IMP-H — использование agent-id-registry для verdict block

**Суть:** Расширить проверку IMP-H в `save-review-checkpoint.sh`. Если `agent_type` пустой, попытаться восстановить из agent-id-registry перед проверкой `agent_type in REVIEW_AGENTS`.

**Файл для изменения:** `.claude/scripts/save-review-checkpoint.sh`

**Реализация:**
```python
# Было:
if verdict == "UNKNOWN" and agent_type in REVIEW_AGENTS and agent_id:
    # Срабатывает только если agent_type передан корректно

# Стало:
effective_agent_type = agent_type
if not effective_agent_type or effective_agent_type == "unknown":
    # Попытка восстановить из registry
    registry_entry = lookup_agent_id_registry(agent_id)
    if registry_entry:
        effective_agent_type = registry_entry.get("agent_type", "unknown")

if verdict == "UNKNOWN" and effective_agent_type in REVIEW_AGENTS and agent_id:
    # Теперь IMP-H сработает для code-reviewer с isolation:worktree
```

**Почему это нужно:**  
RC-2 — IMP-H является первой линией защиты от агентов без вердикта. Без этого фикса code-reviewer может остановиться без вердикта, и блокирующий механизм не активируется.

**Польза:** code-reviewer получит шанс переформировать вывод перед остановкой. Единственный механизм, работающий на уровне хука до того, как оркестратор увидит результат.

---

### IMP-04: Исправление WorktreeCreate payload parsing

**Суть:** `resolve-worktree-path.py` не может разрешить путь воркдерева, потому что WorktreeCreate payload не содержит ожидаемых полей (`worktree_path`, `worktree_name`). Нужно добавить новые стратегии разрешения на основе реального содержимого payload.

**Реальный payload WorktreeCreate** (из логов):
```json
{
  "session_id": "...",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/Users/.../catalog",
  "hook_event_name": "WorktreeCreate",
  "name": "agent-a62d6504"
}
```

**Поле `name`** содержит agent ID в формате `agent-{id}`. Это позволяет:
1. Читать `.git/worktrees/` для поиска воркдерева по agent ID
2. Запускать `git worktree list --porcelain` для поиска по имени

**Файл для изменения:** `.claude/scripts/resolve-worktree-path.py`

**Реализация:**
```python
# Добавить стратегию: поиск по agent name из payload
agent_name = payload.get("name", "")  # "agent-a62d6504"
if agent_name:
    # Стратегия: git worktree list --porcelain | grep -A1 "agent-a62d6504"
    result = subprocess.run(
        ["git", "worktree", "list", "--porcelain"],
        capture_output=True, text=True
    )
    for line in result.stdout.split("\n"):
        if agent_name in line:
            # найден worktree path
```

**Почему это нужно:**  
RC-5 — без корректного пути воркдерева prepare-worktree.sh не может запустить `go mod download` и не может скопировать agent-memory. Код-ревьюер стартует без контекста и зависимостей.

**Польза:** code-reviewer будет стартовать с pre-seeded memory и корректными зависимостями → более качественные ревью → меньше CHANGES_REQUESTED из-за технических проблем.

---

### IMP-05: Explicit agent_type в review-completions.jsonl marker

**Суть:** Добавить `"effective_agent_type"` поле в marker review-completions.jsonl, отдельно от `"agent"`. Поле `"effective_agent_type"` содержит тип после recovery из реестра (может отличаться от сырого payload).

**Файл для изменения:** `.claude/scripts/save-review-checkpoint.sh`

**Реализация:**
```python
marker = {
    "agent": agent_type,                    # сырой payload (может быть "unknown")
    "effective_agent_type": effective_agent_type,  # после registry lookup
    "completed_at": timestamp,
    "session_id": session_id,
    "verdict": verdict,
}
```

**Почему это нужно:**  
Позволяет оркестратору и inject-review-context.sh корректно фильтровать по `effective_agent_type` даже когда `agent` = "unknown". Также помогает в отладке — сразу видно, был ли recovery из реестра.

**Польза:** Даёт надёжный способ отличить "noise unknown entries" (настоящие неизвестные агенты) от "recovered unknown entries" (code-reviewer с пустым agent_type).

---

### IMP-06: Обновить orchestration-core.md — правила работы с UNKNOWN verdicts

**Суть:** Текущая документация Phase 2/4 incomplete output recovery описана недостаточно точно. Нужно добавить явные правила:
1. При UNKNOWN verdict СНАЧАЛА проверить, есть ли запись с корректным `agent_type` в текущей сессии
2. Фильтровать по `session_id` (кросс-сессионные записи = шум)
3. При genuine UNKNOWN → verdict-recovery агент (не plan-reviewer re-launch)

**Файл для изменения:** `.claude/skills/workflow-protocols/orchestration-core.md`

**Добавить явное правило:**
```yaml
Phase 4 — Incomplete Output Recovery:
  step_1: "Read review-completions.jsonl — filter by session_id AND agent_type in ['plan-reviewer', 'code-reviewer']"
  step_2: "If no matching entry → genuine UNKNOWN → launch verdict-recovery"
  step_3: "If entries exist with UNKNOWN verdict from known agent → IMP-H already blocked once; if still UNKNOWN → verdict-recovery"
  step_4: "NEVER re-launch plan-reviewer when code-review phase is active"
  
  anti_pattern:
    wrong: "Re-launch plan-reviewer because review-completions.jsonl last entry is UNKNOWN"
    right: "Filter by agent_type, distinguish plan-review UNKNOWN from code-review UNKNOWN"
```

**Почему это нужно:**  
RC-4 — документация не говорит, что делать с загрязнёнными записями. Оркестратор принимает неверные решения (re-launch plan-reviewer вместо verdict-recovery). Explicit rules устраняют двусмысленность.

**Польза:** Устраняет самый дорогой сценарий — ненужный re-launch full plan-reviewer (5+ минут) вместо lightweight verdict-recovery (~30 секунд).

---

## 7. Сводная таблица улучшений

| ID     | Компонент                         | RC   | Приоритет | Сложность | Польза                                                    |
|--------|-----------------------------------|------|-----------|-----------|-----------------------------------------------------------|
| IMP-01 | track-task-lifecycle.sh + save-review-checkpoint.sh | RC-3 | P1 | Medium | Основа для IMP-02, IMP-03 — восстановление agent_type    |
| IMP-02 | orchestration-core.md             | RC-4 | P1 | Low    | Устраняет ложные re-launch plan-reviewer                  |
| IMP-03 | save-review-checkpoint.sh         | RC-2 | P1 | Low    | IMP-H работает для code-reviewer с isolation:worktree     |
| IMP-04 | resolve-worktree-path.py          | RC-5 | P2 | Medium | code-reviewer стартует с зависимостями и памятью          |
| IMP-05 | save-review-checkpoint.sh         | RC-1 | P2 | Low    | Чистый лог без шума — надёжная фильтрация                 |
| IMP-06 | orchestration-core.md             | RC-4 | P2 | Low    | Explicit rules убирают ambiguity в recovery flow          |

**Порядок реализации (зависимости):**
```
IMP-01 → IMP-03 (зависит от registry)
IMP-01 → IMP-05 (зависит от effective_agent_type из registry)
IMP-02 → IMP-06 (оба в orchestration-core, можно совместить)
IMP-04 (независимый)
```

---

## 8. Ожидаемый результат после внедрения

### До (current state):
```
review-completions.jsonl:
  50% UNKNOWN (загрязнение от worktree agents)
  50% APPROVED (реальные вердикты)

Поведение оркестратора:
  Видит UNKNOWN → re-launch plan-reviewer → лишние 5-10 мин
  Повторяется 2-3 раза за workflow
```

### После (target state):
```
review-completions.jsonl:
  ~5% UNKNOWN (только genuine неудачи, не шум)
  ~95% APPROVED/CHANGES_REQUESTED (реальные вердикты)

Поведение оркестратора:
  Читает только записи agent_type in ["plan-reviewer", "code-reviewer"]
  UNKNOWN → verdict-recovery (~30 сек) → не plan-reviewer re-launch
  WorktreeCreate работает → code-reviewer с полным контекстом
```

---

## 9. Технические артефакты — полный список файлов

### Workflow-ориентированные файлы (изучены в ходе исследования):

| Файл | Тип | Роль в workflow |
|------|-----|-----------------|
| `.claude/commands/workflow.md` | Command | Orchestrator — координирует весь pipeline |
| `.claude/agents/code-reviewer.md` | Agent | Phase 4 — ревью кода (isolation: worktree, maxTurns: 60) |
| `.claude/agents/plan-reviewer.md` | Agent | Phase 2 — ревью плана (isolation: none, maxTurns: 60) |
| `.claude/agents/verdict-recovery.md` | Agent | Fallback — lightweight verdict extraction (maxTurns: 10) |
| `.claude/scripts/save-review-checkpoint.sh` | Hook (SubagentStop) | Извлечение вердикта → review-completions.jsonl |
| `.claude/scripts/inject-review-context.sh` | Hook (SubagentStart) | Инъекция контекста в review agents |
| `.claude/scripts/track-task-lifecycle.sh` | Hook (SubagentStart) | Логирование SubagentStart → task-events.jsonl |
| `.claude/scripts/prepare-worktree.sh` | Hook (WorktreeCreate) | Подготовка воркдерева (deps, memory) |
| `.claude/scripts/resolve-worktree-path.py` | Utility | Определение пути воркдерева (shared) |
| `.claude/scripts/sync-agent-memory.sh` | Utility | Копирование memory из воркдерева → main repo |
| `.claude/settings.json` | Config | SubagentStart/Stop/WorktreeCreate hook конфигурация |
| `.claude/skills/workflow-protocols/orchestration-core.md` | Protocol | Pipeline phases, loop limits, recovery rules |
| `.claude/skills/workflow-protocols/handoff-protocol.md` | Protocol | Handoff contracts между фазами |
| `.claude/skills/workflow-protocols/checkpoint-protocol.md` | Protocol | Checkpoint format, recovery steps |
| `.claude/skills/code-review-rules/SKILL.md` | Skill | Decision matrix, severity levels |

### Workflow-state файлы (runtime):

| Файл | Lifecycle | Содержимое |
|------|-----------|------------|
| `review-completions.jsonl` | Session | Completion markers: agent, verdict, session_id, timestamp |
| `{feature}-checkpoint.yaml` | Session | Pipeline state: phase, iteration counters, verdict, issues_history |
| `worktree-events-debug.jsonl` | Session | DEBUG: SubagentStop и WorktreeCreate payload discovery |
| `task-events.jsonl` | Session | SubagentStart lifecycle events |
| `pipeline-metrics.jsonl` | Cross-session | Aggregated metrics per workflow run |

---

## 10. Выводы

**Первопричина** — изменение поведения Claude Code при передаче `agent_type` в SubagentStop payload для агентов с `isolation: worktree`. Это влечёт каскадные сбои:
1. Матчер хука не фильтрует → загрязнение JSONL
2. IMP-H не срабатывает → агент останавливается без вердикта
3. Оркестратор не фильтрует JSONL → видит UNKNOWN → re-launch
4. Re-launch идёт в plan-reviewer (неверная фаза) вместо verdict-recovery

**Приоритетный путь исправления** (P1):
1. Добавить agent-id-registry (IMP-01) — фундамент
2. Расширить IMP-H через registry (IMP-03) — восстановление защитного механизма
3. Обновить orchestration-core.md с фильтрацией (IMP-02, IMP-06) — правильный recovery flow

**P2 (параллельно):**
4. Починить WorktreeCreate path resolution (IMP-04)
5. Добавить `effective_agent_type` в marker (IMP-05)

Все 6 улучшений не нарушают обратную совместимость и работают как graceful enhancement поверх существующей архитектуры.
