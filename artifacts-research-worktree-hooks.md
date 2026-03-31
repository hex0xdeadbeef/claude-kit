# Исследование: WorktreeCreate Hook — Диагностика и улучшения

**Дата исследования:** 2026-03-31  
**Сложность задачи:** XL  
**Статус:** Завершено  

---

## 1. Executive Summary

Проблема `WorktreeCreate hook failed: no successful output` вызвана **критическим несоответствием** между задокументированным поведением `prepare-worktree.sh` и новым протоколом Claude Code для WorktreeCreate hooks.

**Что сломано:** `prepare-worktree.sh` намеренно не выводит ничего в stdout (защита от старого бага). Новая версия Claude Code требует минимум `{}` в stdout как сигнал успеха. Хук возвращает exit 0, но без stdout — Claude Code считает это ошибкой и **блокирует создание worktree**.

**Последствие для pipeline:** Phase 4 (Code Review) полностью заблокирована. `code-reviewer` агент не может запуститься с `isolation: worktree`. Весь review loop разорван.

**Мгновенный fix:** `echo "{}"` перед `exit 0` в prepare-worktree.sh.

**Системная проблема:** Комментарий в скрипте (`# CRITICAL: Do NOT output ANYTHING`) стал активной дезинформацией. Требуется обновление документации и защита от регрессий.

---

## 2. Отбор артефактов Workflow

### 2.1 Критерии отбора

Отобраны артефакты, которые:
- Непосредственно участвуют в pipeline `/workflow`
- Связаны с хуками, срабатывающими во время workflow фаз
- Являются утилитами, используемыми workflow-специфичными скриптами

### 2.2 Отобранные артефакты

| Артефакт | Тип | Hook / Роль | Релевантность |
|----------|-----|-------------|---------------|
| `.claude/settings.json` | Config | Конфигурация всех хуков | Центральный |
| `.claude/scripts/prepare-worktree.sh` | Script | WorktreeCreate | **Источник проблемы** |
| `.claude/scripts/resolve-worktree-path.py` | Utility | Shared — worktree resolution | Критически связан |
| `.claude/scripts/sync-agent-memory.sh` | Utility | Shared — memory sync | Связан с worktree |
| `.claude/scripts/save-review-checkpoint.sh` | Script | SubagentStop (plan-reviewer\|code-reviewer) | Phase 4 завершение |
| `.claude/scripts/track-task-lifecycle.sh` | Script | SubagentStart (code-researcher) | Phase 1/3 метрики |
| `.claude/scripts/session-analytics.sh` | Script | SessionEnd | Worktree cleanup |
| `.claude/scripts/enrich-context.sh` | Script | UserPromptSubmit | Checkpoint state |
| `.claude/scripts/save-progress-before-compact.sh` | Script | PreCompact | State preservation |
| `.claude/scripts/verify-state-after-compact.sh` | Script | PostCompact | State integrity |
| `.claude/scripts/check-uncommitted.sh` | Script | Stop | Phase 5 gate |
| `.claude/agents/code-reviewer.md` | Agent | isolation: worktree | WorktreeCreate consumer |
| `.claude/skills/workflow-protocols/` | Skills | Orchestration protocols | Pipeline design |

### 2.3 Исключённые артефакты (не Workflow)

| Артефакт | Причина исключения |
|----------|--------------------|
| `validate-instructions.sh` | InstructionsLoaded — глобальный, не workflow |
| `block-dangerous-commands.sh` | PreToolUse безопасность — не workflow-специфичен |
| `protect-files.sh` | PreToolUse файлозащита — глобальный |
| `auto-fmt-go.sh` | PostToolUse Go-specific — не workflow |
| `pre-commit-build.sh` | Git-specific — не workflow |
| `log-stop-failure.sh` | StopFailure — глобальный |
| `notify-user.sh` | Notification — глобальный |
| `.claude/agents/meta-agent/` | Meta-агент — отдельная система |

---

## 3. Граф взаимодействия артефактов

### 3.1 Полный граф Pipeline (нормальный путь)

```
/workflow orchestrator
│
├─── Phase 1: /planner
│     └─── [code-researcher — tool-assist via Agent/Task]
│           SubagentStart → track-task-lifecycle.sh
│                           └── .claude/workflow-state/task-events.jsonl
│
│    UserPromptSubmit → enrich-context.sh (каждый промпт)
│                       └── читает: checkpoint.yaml, prompts/*.md,
│                               review-completions.jsonl
│                       └── output: additionalContext (workflow state)
│
├─── Phase 2: plan-reviewer (agent)
│     SubagentStop → save-review-checkpoint.sh
│                    ├── resolve-worktree-path.py (НЕ worktree агент)
│                    ├── extract verdict from transcript
│                    └── .claude/workflow-state/review-completions.jsonl
│
├─── Phase 3: /coder
│
├─── Phase 4: code-reviewer (agent, isolation: worktree)
│     │
│     ├── Claude Code: git worktree create ──────────────────────────┐
│     │                                                               │
│     │   WorktreeCreate EVENT                                        │
│     │   └── prepare-worktree.sh                                     │
│     │         ├── reads stdin JSON (hook payload)                   │
│     │         ├── resolve-worktree-path.py                          │
│     │         │     ├── Strategy 1: payload fields                  │
│     │         │     │   (worktree_path, worktreePath, path)         │
│     │         │     ├── Strategy 2: .git/worktrees/ scan (mtime)    │
│     │         │     └── Strategy 3: git worktree list --porcelain   │
│     │         ├── copy .env.example → .env (if exists)             │
│     │         ├── go mod download (timeout: 30s)                    │
│     │         ├── copy .claude/agent-memory/ → worktree             │
│     │         ├── log → worktree-events.jsonl                       │
│     │         └── exit 0 [⚠️ NO STDOUT → BUG]                      │
│     │                                                               │
│     │   Claude Code: "no successful output" → BLOCKED ◄────────────┘
│     │
│     └─── [если запустился нормально]
│           SubagentStop → save-review-checkpoint.sh
│                          ├── resolve-worktree-path.py
│                          │     └── [для code-reviewer: worktree resolver]
│                          ├── sync-agent-memory.sh
│                          │     ├── читает: worktree/.claude/agent-memory/
│                          │     └── sync в: .claude/agent-memory/code-reviewer/
│                          └── .claude/workflow-state/review-completions.jsonl
│
├─── Phase 5: Completion
│     Stop → check-uncommitted.sh
│             ├── git status --porcelain
│             ├── читает checkpoint (phase_completed, complexity)
│             └── decision: block | warn
│
│    PreCompact → save-progress-before-compact.sh
│                 └── output: additionalContext (checkpoint + reviews)
│
│    PostCompact → verify-state-after-compact.sh
│                  ├── verify checkpoint integrity
│                  ├── verify review-completions.jsonl (JSONL valid)
│                  └── output: additionalContext (state summary)
│
└─── SessionEnd → session-analytics.sh
                  ├── parse transcript
                  ├── read latest checkpoint
                  ├── calculate duration/tool_calls/errors
                  ├── write .claude/workflow-state/session-analytics.jsonl
                  └── git worktree prune (IMP-16)
```

### 3.2 Схема данных workflow-state/

```
.claude/workflow-state/
├── {feature}-checkpoint.yaml          ← read: enrich-context, verify-after-compact
│                                         write: /workflow orchestrator (via /coder, /planner)
├── review-completions.jsonl           ← read: enrich-context, verify-after-compact
│                                         write: save-review-checkpoint.sh
├── task-events.jsonl                  ← write: track-task-lifecycle.sh
├── worktree-events.jsonl              ← write: prepare-worktree.sh
├── worktree-events-debug.jsonl        ← write: prepare-worktree.sh,
│                                              save-review-checkpoint.sh,
│                                              track-task-lifecycle.sh
├── session-analytics.jsonl            ← write: session-analytics.sh
└── hook-log.txt                       ← write: block-dangerous-commands.sh
```

### 3.3 Зависимости shared utilities

```
resolve-worktree-path.py
├── вызывается из: prepare-worktree.sh (WorktreeCreate)
└── вызывается из: save-review-checkpoint.sh (SubagentStop)

sync-agent-memory.sh
├── вызывается из: save-review-checkpoint.sh (SubagentStop)
└── читает: worktree_path (результат resolve-worktree-path.py)

prepare-worktree.sh (WorktreeCreate)
└── копирует agent-memory: .claude/agent-memory/ → worktree/.claude/agent-memory/
    sync-agent-memory.sh (SubagentStop)
    └── копирует обратно: worktree/.claude/agent-memory/ → .claude/agent-memory/
```

---

## 4. Анализ WorktreeCreate Protocol

### 4.1 История изменений (Claude Code CHANGELOG)

| Версия | Дата | Изменение |
|--------|------|-----------|
| v2.1.49 | — | `--worktree` flag для agent isolation |
| v2.1.50 | — | Добавлены `WorktreeCreate` и `WorktreeRemove` hook events |
| v2.1.76 | — | `worktree.sparsePaths` в settings.json (git sparse-checkout) |
| v2.1.77 | — | Fix race condition: stale-worktree cleanup не удаляет живой worktree |
| v2.1.78 | — | Fix: `--worktree` не загружал skills/hooks из worktree директории |
| v2.1.84 | — | WorktreeCreate http hook: `hookSpecificOutput.worktreePath` |
| v2.1.85 | — | PreToolUse: `if` field для conditional hook spawning |

### 4.2 Протокол WorktreeCreate: старый vs новый

**Старый протокол (до v2.1.84, command hooks):**
```
hook exit 0 + NO stdout → SUCCESS (worktree создаётся нормально)
hook stdout (любой)    → интерпретируется как путь к worktree
                         "{}" → worktreePath="{}"
                              → Claude Code создаёт "{}/.claude/agent-memory/"
```

Именно это описывает комментарий в `prepare-worktree.sh` (строки 220–225) — он был верен для своего времени.

**Новый протокол (текущий, command hooks):**
```
hook exit 0 + "{}"   → SUCCESS (worktree использует путь по умолчанию)
hook exit 0 + NO stdout → "no successful output" → BLOCKED
hook stdout JSON с worktreePath → Claude Code использует указанный путь
```

**HTTP hooks (v2.1.84):**
```json
{ "hookSpecificOutput": { "worktreePath": "/path/to/worktree" } }
```

### 4.3 Механизм error "no successful output"

Claude Code проверяет stdout хука WorktreeCreate:
1. Если stdout пустой → `WorktreeCreate hook failed: no successful output` → worktree creation BLOCKED
2. Если stdout = `{}` (empty JSON) → SUCCESS, используется путь по умолчанию
3. Если stdout = `{"worktreePath": "/tmp/wt"}` → SUCCESS, используется указанный путь

Это изменение поведения не задокументировано в CHANGELOG для `type: command` hooks (только для `type: http`), что делает регрессию скрытой.

---

## 5. Детальный анализ ключевых артефактов

### 5.1 prepare-worktree.sh — источник проблемы

**Файл:** `.claude/scripts/prepare-worktree.sh`

**Назначение:** Подготовка worktree окружения для code-reviewer агента.

**Критическая проблема (строки 219–225):**
```bash
# CRITICAL: Do NOT output ANYTHING to stdout from WorktreeCreate hooks.
# Claude Code parses ALL WorktreeCreate hook stdout as worktree metadata:
#   - "{}" → worktreePath="{}" → creates "{}/.claude/agent-memory/" directory
#   - "worktree prepared" → worktreePath="worktree prepared" → creates "worktree prepared/.claude/agent-memory/"
# The ONLY safe option is silent exit (no stdout at all).
exit 0
```

Этот комментарий документирует OLD поведение. Сейчас:
- `{}` как stdout интерпретируется как JSON (не как строка-путь)
- `worktreePath` отсутствует в `{}` → используется default path
- Риска создания директории `{}/.claude/` больше нет

**Что делает скрипт (полный анализ):**

| Шаг | Действие | Критичность | Статус |
|-----|----------|-------------|--------|
| 1 | `cat` stdin (hook JSON payload) | REQUIRED | ✅ |
| 2 | `python3` check | Guard | ✅ |
| 3 | Parse JSON payload | Data extraction | ✅ |
| 4 | `resolve-worktree-path.py` call | Path resolution | ✅ |
| 5 | Debug logging → `worktree-events-debug.jsonl` | Analytics | ✅ |
| 6 | `.env.example` copy | Environment prep | ✅ |
| 7 | `go mod download` (30s timeout) | Deps install | ✅ (но см. проблему #7) |
| 8 | agent-memory copy | Memory pre-seed | ✅ |
| 9 | Analytics log → `worktree-events.jsonl` | Observability | ✅ |
| **10** | **`exit 0` без stdout** | **Protocol signal** | **❌ BROKEN** |

### 5.2 resolve-worktree-path.py — устаревший guard

**Файл:** `.claude/scripts/resolve-worktree-path.py`

**Guard (строки 42–45):**
```python
if not wp.startswith("/") or " " in wp or "{" in wp or "}" in wp:
    print(f"{CALLER}: rejecting invalid worktree_path: {worktree_path!r}", file=sys.stderr)
    worktree_path = None
```

**Исходное назначение guard'а:** Защита от old behavior, когда `{}` в stdout превращалось в путь `{}` в payload.

**Текущий статус guard'а:** В новом протоколе guard всё ещё валиден как protection against path injection, но изменился контекст его применения. Теперь `{}` в stdout — это корректный JSON, который Claude Code разберёт сам, а в payload придёт уже null/empty `worktreePath`.

**Race condition (Strategy 2):** `.git/worktrees/` scan берёт "наиболее свежий по mtime". Если два code-review запускаются параллельно (нестандартный сценарий), resolve может вернуть неверный worktree.

### 5.3 save-review-checkpoint.sh — verdicts и memory sync

**Файл:** `.claude/scripts/save-review-checkpoint.sh`

**Функции:**
1. Извлечение verdict из transcript (IMP-01) — Strategy 1: payload, Strategy 2: transcript JSONL
2. Resolve worktree path (только для `code-reviewer`)
3. Sync agent memory через `sync-agent-memory.sh`
4. Запись маркера в `review-completions.jsonl`
5. Defensive fallback → `/tmp` при ошибке записи (IMP-06)

**Что важно:** SubagentStop срабатывает ПОСЛЕ того как агент завершился. Если WorktreeCreate заблокировал создание worktree, агент не стартует → SubagentStop не срабатывает → `review-completions.jsonl` не пишется → orchestrator видит отсутствие verdict.

### 5.4 session-analytics.sh — worktree cleanup

**Файл:** `.claude/scripts/session-analytics.sh`

**IMP-16 (строка 194):**
```bash
git worktree prune 2>/dev/null || true
```

Это cleanup stale worktrees при завершении сессии. Важно: если WorktreeCreate провалился, "stale" worktree в `.git/worktrees/` может остаться если worktree был частично создан до выполнения хука.

### 5.5 code-reviewer.md — consumer WorktreeCreate

**Файл:** `.claude/agents/code-reviewer.md`

**Ключевые настройки:**
```yaml
isolation: worktree
model: sonnet
maxTurns: 45
```

**worktree.sparsePaths** (из settings.json):
```json
[".claude/", "internal/", "cmd/", "go.mod", "go.sum", "Makefile", "CLAUDE.md"]
```

Sparse checkout включается через `worktree.sparsePaths` (v2.1.76). Это ускоряет создание worktree но ограничивает видимые файлы. Для `prepare-worktree.sh` это не проблема — скрипт запускается ДО агента (WorktreeCreate), поэтому он видит весь репозиторий через CWD (main repo), а не через sparse worktree.

---

## 6. Каталог проблем

### P-01 ⛔ CRITICAL — prepare-worktree.sh: нет stdout при exit 0

**Симптом:** `WorktreeCreate hook failed: no successful output`  
**Файл:** `.claude/scripts/prepare-worktree.sh`, строка 225  
**Механизм:** Claude Code (текущая версия) требует минимум `{}` в stdout для подтверждения успеха. Пустой stdout при exit 0 интерпретируется как failed hook.  
**Последствие:** code-reviewer агент не стартует → Phase 4 заблокирована → workflow broken.  
**Исправление:**
```bash
echo "{}"   # Required by Claude Code WorktreeCreate protocol — signals hook success
exit 0
```

---

### P-02 🔴 HIGH — Опасная дезинформация в комментарии

**Симптом:** Будущие разработчики читают комментарий и убеждаются, что stdout вреден  
**Файл:** `.claude/scripts/prepare-worktree.sh`, строки 220–225  
**Механизм:** Комментарий документирует OLD протокол (stdout = worktree path). В новом протоколе `{}` — валидный JSON-сигнал успеха без побочных эффектов.  
**Последствие:** При обслуживании скрипта комментарий будет воспринят как актуальная истина, что заблокирует правильный fix или спровоцирует регресс.  
**Исправление:** Обновить комментарий с документацией нового протокола и историей изменения.

---

### P-03 🟠 MEDIUM — Нет version gate для WorktreeCreate протокола

**Симптом:** Непонятно, в какой версии Claude Code изменилось поведение  
**Файл:** `.claude/scripts/prepare-worktree.sh`, заголовок; `CLAUDE.md`  
**Механизм:** CHANGELOG v2.1.84 упоминает `hookSpecificOutput.worktreePath` только для HTTP hooks. Для command hooks изменение поведения не задокументировано.  
**Последствие:** При откате Claude Code или переходе на другую среду невозможно определить, нужен ли stdout.  
**Исправление:** Добавить в комментарий: `# Protocol changed: ~v2.1.84+ requires stdout JSON. Legacy (pre-v2.1.84): silent exit was OK.`

---

### P-04 🟠 MEDIUM — resolve-worktree-path.py: race condition в Strategy 2

**Файл:** `.claude/scripts/resolve-worktree-path.py`, строки 48–69  
**Механизм:** При Strategy 2 (`.git/worktrees/` scan) берётся наиболее свежий по mtime. При параллельном запуске двух code-review сессий (edge case, но возможен при manual testing) резолвер может вернуть неправильный worktree.  
**Последствие:** `sync-agent-memory.sh` может скопировать память из неверного worktree → память агента смешается между review сессиями.  
**Исправление:** Передавать session_id или worktree_name через `_HOOK_INPUT` env var и приоритизировать matching по имени.

---

### P-05 🟠 MEDIUM — Semantic mismatch: "non-blocking" vs реальная блокировка

**Файл:** `CLAUDE.md` (hooks таблица), `.claude/scripts/prepare-worktree.sh`  
**Механизм:** CLAUDE.md описывает WorktreeCreate hook как `blocking: false`. Но в новом Claude Code поведении отсутствие stdout блокирует создание worktree — это de-facto блокирующее поведение.  
**Последствие:** Неправильные ожидания у разработчиков. "Non-blocking" hook по факту блокирует pipeline.  
**Исправление:** Обновить CLAUDE.md: `blocking: false (exit code) — stdout required for protocol compliance`.

---

### P-06 🟡 LOW — go mod download: race с запуском code-reviewer

**Файл:** `.claude/scripts/prepare-worktree.sh`, строки 135–158  
**Механизм:** `go mod download` выполняется с timeout 30s. Хук помечен non-blocking. Если download занимает > 30s или происходит timeout, код-ревьюер стартует с неполными зависимостями. При этом агент может попытаться собрать проект (`make test`) и получить ошибку.  
**Вероятность:** Низкая для проектов с кешированными модулями. Высокая для fresh CI.  
**Исправление:** Добавить fallback: если go mod download failed/timeout → логировать warning но продолжить. В документации указать, что для CI рекомендуется предварительный `go mod download` в main repo.

---

### P-07 🟡 LOW — IMP-XX tracking не централизован

**Файл:** Все `.claude/scripts/*.sh`, `.claude/agents/*.md`  
**Механизм:** Улучшения трекируются как комментарии `# IMP-XX` в коде. IMP-16 в session-analytics.sh, IMP-18 в track-task-lifecycle.sh, IMP-01..IMP-11 разбросаны по скриптам. Нет единого реестра.  
**Последствие:** При ревью кода невозможно понять статус каждого улучшения. `grep IMP-` — единственный способ навигации.  
**Исправление:** Создать `.claude/workflow-state/improvements-log.md` или включить IMP tracking в CLAUDE.md как раздел.

---

### P-08 🟡 LOW — Manual YAML parsing fragility

**Файлы:** `.claude/scripts/enrich-context.sh`, `.claude/scripts/verify-state-after-compact.sh`  
**Механизм:** Обе скрипта парсят `.claude/workflow-state/*-checkpoint.yaml` вручную через Python string split:
```python
key, _, val = line.partition(":")
```
Это не обрабатывает: многострочные значения, вложенный YAML, значения со строками. Для текущей упрощённой схемы checkpoint работает, но хрупко.  
**Последствие:** Если checkpoint schema усложнится (например, добавится nested object), парсинг молча даст неверный результат.  
**Исправление:** Использовать `yaml.safe_load` (из stdlib-compatible json-based parser) или принудительно держать checkpoint в JSON формате.

---

### P-09 ℹ️ INFO — SubagentStart tracking только для code-researcher

**Файл:** `.claude/settings.json`, `.claude/scripts/track-task-lifecycle.sh`  
**Механизм:** `SubagentStart` hook настроен с `matcher: "code-researcher"`. Plan-reviewer и code-reviewer субагенты не трекируются через SubagentStart (только через SubagentStop).  
**Последствие:** В `task-events.jsonl` отсутствуют события start для review агентов. Для pipeline metrics это gap.  
**Исправление:** Добавить отдельный SubagentStart hook с `matcher: "plan-reviewer|code-reviewer"` который логирует start event в `task-events.jsonl`. Или расширить track-task-lifecycle.sh для обработки всех matcher'ов.

---

## 7. Лист улучшений с обоснованием

### IMP-19: Fix WorktreeCreate stdout protocol

**Приоритет:** P0 — BLOCKING  
**Файл:** `.claude/scripts/prepare-worktree.sh`, строка 225  
**Изменение:**
```bash
# Заменить:
exit 0

# На:
echo "{}"   # WorktreeCreate protocol: stdout JSON required for success signal.
            # Empty object = use default worktree path, no metadata override.
            # Claude Code ~v2.1.84+: silent exit = "no successful output" error.
exit 0
```

**Почему нужно:**  
Без этого fix Phase 4 (Code Review) полностью заблокирована. `code-reviewer` с `isolation: worktree` не может запуститься. Вся pipeline `/workflow` теряет code-review.

**Что это даст:**  
- code-reviewer агент запускается нормально
- WorktreeCreate хук проходит валидацию Claude Code
- Pipeline восстанавливается полностью

**Польза:**  
Critical path fix. Без него XL tasks (с обязательным code-review) невозможно завершить через workflow.

---

### IMP-20: Обновить комментарий с историей протокола

**Приоритет:** P1 — HIGH  
**Файл:** `.claude/scripts/prepare-worktree.sh`, строки 220–225  
**Изменение:** Заменить WARNING-комментарий о запрете stdout на документацию нового протокола:
```bash
# WorktreeCreate stdout protocol (history):
#   Pre-v2.1.84: Claude Code parsed stdout as worktree PATH (not JSON).
#                Empty/no stdout was required to avoid "{}/.claude/" directory creation.
#   v2.1.84+:    Claude Code parses stdout as JSON. Empty object {} = success, default path.
#                If stdout is missing: "WorktreeCreate hook failed: no successful output".
#
# Current requirement: echo "{}" before exit 0 (signals success, no path override).
# If you need to override worktree path: echo '{"worktreePath": "/abs/path/to/worktree"}'
```

**Почему нужно:**  
Старый комментарий стал дезинформацией. Разработчик, читающий его, намеренно уберёт `echo "{}"` "для безопасности", сломав хук снова.

**Что это даст:**  
Предотвращение регрессий. Исторический контекст для будущих maintainer'ов.

**Польза:**  
Documentation as prevention. Дешевле чем debugging next regression.

---

### IMP-21: Обновить CLAUDE.md — описание WorktreeCreate hook

**Приоритет:** P1 — HIGH  
**Файл:** `CLAUDE.md`, секция Hooks  
**Изменение:**
```markdown
# Изменить:
WorktreeCreate: `.claude/scripts/prepare-worktree.sh` — blocking: false

# На:
WorktreeCreate: `.claude/scripts/prepare-worktree.sh` — stdout `{}` required (v2.1.84+), 
                exit 0 always (never block). Prepares env, deps, memory.
```

**Почему нужно:**  
CLAUDE.md — единственный источник правды для разработчиков, работающих с проектом. Описание "blocking: false" создаёт ложное ощущение что хук ничего не требует от Claude Code.

**Что это даст:**  
Корректная документация поведения хука для всех кто читает CLAUDE.md.

**Польза:**  
Onboarding новых разработчиков без ложных предположений о WorktreeCreate.

---

### IMP-22: Добавить структурную валидацию stdout в prepare-worktree.sh

**Приоритет:** P2 — MEDIUM  
**Файл:** `.claude/scripts/prepare-worktree.sh`  
**Изменение:**
```bash
# В конце скрипта, перед exit 0:
# Output hook success signal — REQUIRED by Claude Code WorktreeCreate protocol
# Empty JSON = success, use default path. If worktree_path known:
#   echo '{"worktreePath": "'"$WORKTREE_PATH"'"}'
echo "{}"
exit 0
```
Дополнительно: добавить smoke-тест в CI/startup, который проверяет что prepare-worktree.sh выводит valid JSON:
```bash
output=$(bash .claude/scripts/prepare-worktree.sh <<< '{}')
python3 -c "import json, sys; json.loads(sys.stdin.read())" <<< "$output"
```

**Почему нужно:**  
Протокол может эволюционировать. Явная проверка подтверждает соответствие контракту.

**Что это даст:**  
Быстрое обнаружение protocol drift при обновлении Claude Code.

**Польза:**  
Preventive testing. Лучше поймать в тесте чем при живом workflow.

---

### IMP-23: Resolve-worktree-path.py — session-aware matching

**Приоритет:** P2 — MEDIUM  
**Файл:** `.claude/scripts/resolve-worktree-path.py`  
**Изменение:**
```python
# Strategy 2: добавить session_id matching если доступен
session_id = data.get("session_id", "")
if session_id and entries:
    # Найти worktree с matching session name
    for entry in entries:
        if session_id[:8] in entry:  # First 8 chars of UUID
            candidate = ...  # resolve this entry
            if os.path.isdir(candidate):
                worktree_path = candidate
                resolution = "fallback_gitdir_session_match"
                break
# Fallback к старому поведению (most recent mtime)
if not worktree_path:
    # существующая логика Strategy 2
```

**Почему нужно:**  
Параллельные review сессии (manual testing, concurrent agents) могут вернуть неверный worktree через Strategy 2.

**Что это даст:**  
Корректная привязка к session при наличии session_id в payload.

**Польза:**  
Защита целостности agent memory при параллельных workflows.

---

### IMP-24: Централизовать IMP tracking

**Приоритет:** P3 — LOW  
**Файл:** Новый файл `.claude/workflow-state/improvements-registry.md`  
**Изменение:**
```markdown
# Improvements Registry

| ID | Status | File | Description | Added |
|----|--------|------|-------------|-------|
| IMP-01 | DONE | save-review-checkpoint.sh | Verdict extraction from transcript | 2026-03-30 |
| IMP-11 | DONE | resolve-worktree-path.py | Shared worktree resolver | |
| IMP-16 | DONE | session-analytics.sh | git worktree prune at SessionEnd | |
| IMP-18 | DONE | track-task-lifecycle.sh | SubagentStart debug logging | |
| IMP-19 | PENDING | prepare-worktree.sh | WorktreeCreate stdout fix | |
| ... | | | | |
```

**Почему нужно:**  
`grep IMP-` по всем файлам — единственный способ понять статус. Это неудобно и легко пропустить.

**Что это даст:**  
Единый реестр: что сделано, что в плане, когда добавлено.

**Польза:**  
Engineering hygiene. Снижение cognitive load при code review и onboarding.

---

### IMP-25: SubagentStart tracking для review агентов

**Приоритет:** P3 — LOW  
**Файл:** `.claude/settings.json`, `.claude/scripts/track-task-lifecycle.sh`  
**Изменение:**
```json
"SubagentStart": [
  {
    "matcher": "code-researcher",
    "hooks": [{ "type": "command", "command": ".claude/scripts/track-task-lifecycle.sh" }]
  },
  {
    "matcher": "plan-reviewer|code-reviewer",
    "hooks": [{ "type": "command", "command": ".claude/scripts/track-task-lifecycle.sh" }]
  }
]
```

**Почему нужно:**  
Pipeline metrics (через session-analytics.sh) не видят start time review агентов. Нельзя измерить duration Phase 2 и Phase 4.

**Что это даст:**  
Полные pipeline metrics: start+stop для каждого агента.

**Польза:**  
Observability. Возможность профилировать где workflow тратит больше всего времени.

---

## 8. Приоритизированный план исправлений

| # | IMP | Приоритет | Effort | Impact | Файл |
|---|-----|-----------|--------|--------|------|
| 1 | IMP-19 | P0 BLOCKING | 5 мин | Восстанавливает Phase 4 | prepare-worktree.sh |
| 2 | IMP-20 | P1 HIGH | 10 мин | Предотвращает regress | prepare-worktree.sh |
| 3 | IMP-21 | P1 HIGH | 5 мин | Корректная документация | CLAUDE.md |
| 4 | IMP-22 | P2 MEDIUM | 30 мин | Smoke-тест для protocol | prepare-worktree.sh |
| 5 | IMP-23 | P2 MEDIUM | 1 час | Race condition fix | resolve-worktree-path.py |
| 6 | IMP-24 | P3 LOW | 30 мин | Engineering hygiene | новый файл |
| 7 | IMP-25 | P3 LOW | 30 мин | Observability | settings.json + script |

---

## 9. Заключение

### Корневая причина

Изменение протокола WorktreeCreate hook в Claude Code (~v2.1.84+): command hooks теперь требуют stdout JSON для сигнала успеха. prepare-worktree.sh намеренно подавлял stdout (защита от старого баг), что привело к конфликту с новым требованием.

### Системный вывод

Проект имеет хорошо продуманную hook архитектуру с defensive coding (IMP-серия, fallback chains, graceful degradation). Основная уязвимость — отсутствие contract tests для hook протоколов. Изменение поведения Claude Code не было поймано автоматически, потому что:
1. Нет smoke-тестов для hook stdout  
2. Changelog не отразил изменение для command hooks (только для http)
3. Комментарий в коде создал ложное доверие к "правильному" поведению

### Минимальный fix

```bash
# В .claude/scripts/prepare-worktree.sh, строка 225:
echo "{}"   # Required: WorktreeCreate protocol stdout signal (Claude Code v2.1.84+)
exit 0
```

**Эффект:** Восстанавливает Phase 4 workflow. Нулевой risk (empty JSON = no path override).
