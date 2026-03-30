# Workflow Analysis: Worktree + Verdict Propagation

**Date:** 2026-03-30
**Scope:** Comprehensive analysis of workflow pipeline artifacts, two confirmed bugs, root cause tracing, and improvement roadmap.

---

## 1. Исследованные артефакты

Из 140 файлов проекта к Workflow относятся следующие:

### 1.1 Оркестрация (commands)

| Файл                           | Роль                          |
| ------------------------------ | ----------------------------- |
| `.claude/commands/workflow.md` | Главный оркестратор пайплайна |
| `.claude/commands/planner.md`  | Создание плана реализации     |
| `.claude/commands/designer.md` | Дизайн-спека (L/XL tasks)     |
| `.claude/commands/coder.md`    | Реализация по плану           |

### 1.2 Агенты (agents)

| Файл                                | Роль                                           |
| ----------------------------------- | ---------------------------------------------- |
| `.claude/agents/code-reviewer.md`   | Ревью кода (isolation: worktree, maxTurns: 45) |
| `.claude/agents/plan-reviewer.md`   | Ревью плана                                    |
| `.claude/agents/code-researcher.md` | Research-помощник (haiku, tool-assist)         |

### 1.3 Скиллы (skills)

| Директория            | Роль                                                                                                                                       |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `workflow-protocols/` | SKILL.md + 8 протоколов (orchestration-core, handoff, checkpoint, re-routing, pipeline-metrics, autonomy, agent-memory, parallel-dispatch) |
| `code-review-rules/`  | Чеклист ревью + безопасность                                                                                                               |
| `plan-review-rules/`  | Чеклист ревью плана                                                                                                                        |
| `coder-rules/`        | Правила имплементации + spec-check                                                                                                         |
| `planner-rules/`      | Task-analysis + MCP tools                                                                                                                  |

### 1.4 Скрипты / Хуки

| Скрипт                      | Хук                                         | Блокирующий |
| --------------------------- | ------------------------------------------- | ----------- |
| `prepare-worktree.sh`       | WorktreeCreate                              | Нет         |
| `save-review-checkpoint.sh` | SubagentStop (plan-reviewer\|code-reviewer) | **Да**      |
| `sync-agent-memory.sh`      | — (вызывается из save-review-checkpoint.sh) | Нет         |
| `yaml-lint.sh`              | PostToolUse (Edit `.claude/**`)             | Нет         |
| `check-references.sh`       | PostToolUse (Write `.claude/**`)            | Нет         |
| `check-plan-drift.sh`       | PostToolUse (Write/Edit `.claude/**`)       | Нет         |
| `check-uncommitted.sh`      | Stop                                        | **Да**      |
| `track-task-lifecycle.sh`   | SubagentStart (code-researcher)             | Нет         |
| `enrich-context.sh`         | UserPromptSubmit                            | Нет         |

### 1.5 Конфигурация

| Файл                                                 | Роль                                            |
| ---------------------------------------------------- | ----------------------------------------------- |
| `.claude/settings.json`                              | Hook-конфиги, permissions, worktree.sparsePaths |
| `.claude/workflow-state/review-completions.jsonl`    | Маркеры завершения ревью-агентов                |
| `.claude/workflow-state/worktree-events-debug.jsonl` | Debug-лог WorktreeCreate payload                |
| `.claude/workflow-state/{feature}-checkpoint.yaml`   | Состояние пайплайна                             |

---

## 2. Граф взаимодействия артефактов

```
User Input
    │
    ▼
/workflow (commands/workflow.md)  ← model: opus
    │  STARTUP: load workflow-protocols/SKILL.md
    │           + orchestration-core.md + autonomy.md
    │
    ├─── Phase 0.5: Task Analysis (planner-rules/task-analysis.md)
    │         S/M/L/XL → route selection
    │
    ├─── Phase 0.7: /designer (L/XL only)
    │         → .claude/prompts/{feature}-spec.md
    │
    ├─── Phase 1: /planner (commands/planner.md)
    │         → .claude/prompts/{feature}.md
    │         └── optional: code-researcher (agents/code-researcher.md, haiku)
    │
    ├─── Phase 2: plan-reviewer agent (agents/plan-reviewer.md)
    │         │   clean context, skills: plan-review-rules
    │         │
    │         ╔══ SubagentStop hook ══════════════════════════════╗
    │         ║  save-review-checkpoint.sh                        ║
    │         ║    IN:  payload.last_assistant_message (MISSING)  ║
    │         ║    ACT: regex search for VERDICT: pattern         ║
    │         ║    OUT: review-completions.jsonl ← verdict=UNKNOWN║
    │         ╚══════════════════════════════════════════════════╝
    │         └── verdict → orchestrator (UNKNOWN → fallback)
    │
    ├─── Phase 3: /coder (commands/coder.md)
    │         model: sonnet
    │         EVALUATE → IMPLEMENT → SIMPLIFY? → VERIFY → SPEC CHECK
    │         └── optional: code-researcher (Task tool)
    │
    └─── Phase 4: code-reviewer agent (agents/code-reviewer.md)
              │   model: sonnet, isolation: worktree, maxTurns: 45
              │
              ╔══ WorktreeCreate hook ════════════════════════════╗
              ║  prepare-worktree.sh                              ║
              ║    IN:  {cwd, hook_event_name, name,              ║
              ║          session_id, transcript_path}             ║
              ║    MISSING: worktree_path ← не в payload          ║
              ║    ACT: sys.exit(0) — ранний выход                ║
              ║    RESULT: go mod download НЕ выполнен            ║
              ║            agent-memory НЕ pre-seeded             ║
              ╚══════════════════════════════════════════════════╝
              │
              │  Агент работает в воркдереве, пишет agent-memory:
              │
              │  Write/Edit .claude/agent-memory/** →
              │  ┌─ yaml-lint.sh      [GUARD: agent-memory → exit 0] ✅
              │  ├─ check-references.sh [GUARD: agent-memory → exit 0] ✅
              │  └─ check-plan-drift.sh [GUARD: agent-memory → exit 0] ✅
              │
              │  RULE_5 (3-tier):
              │  Turn 25 → self-check, Turn 33 → hard abort, Turn 40 → memory skip
              │
              ╔══ SubagentStop hook ══════════════════════════════╗
              ║  save-review-checkpoint.sh                        ║
              ║    IN:  payload.last_assistant_message (MISSING)  ║
              ║    ACT: sync-agent-memory.sh (fallback strategies)║
              ║    OUT: review-completions.jsonl ← verdict=UNKNOWN║
              ╚══════════════════════════════════════════════════╝
              │
              └── output_validation → on_incomplete_output
                    step_1: check review-completions.jsonl → UNKNOWN
                    step_3: re-launch с minimal prompt
```

### 2.1 Поток данных SubagentStop (детально)

```
Claude Code runtime
    → fires SubagentStop
    → passes JSON payload to save-review-checkpoint.sh stdin:
       {
         "session_id": "...",
         "transcript_path": "/path/to/session.jsonl",
         "cwd": "/path/to/project",
         "hook_event_name": "SubagentStop",
         "name": "agent-XXXXXXXX",
         "agent_type"/"agent_name": "plan-reviewer" | "" | ???
         // last_assistant_message: НЕТ в payload
       }

save-review-checkpoint.sh:
    output = data.get("last_assistant_message", "")  # → ""
    verdict = "UNKNOWN"
    if output:   # → False, блок пропускается
        match = re.search(r'VERDICT:...', str(output))
    # verdict остаётся "UNKNOWN"
    → writes {"verdict": "UNKNOWN"} to review-completions.jsonl
```

### 2.2 Поток данных WorktreeCreate (детально)

```
Claude Code runtime
    → fires WorktreeCreate (code-reviewer с isolation: worktree)
    → passes JSON payload:
       {
         "session_id": "bbf20db4-...",
         "transcript_path": "/path/to/session.jsonl",
         "cwd": "/path/to/project",
         "hook_event_name": "WorktreeCreate",
         "name": "agent-af5a930e"
         // worktree_path: НЕТ в payload
       }

prepare-worktree.sh:
    worktree_path = hook_input.get("worktree_path") \   # None
                    or hook_input.get("worktreePath") \  # None
                    or hook_input.get("path") \          # None
                    or worktree.get("path")              # None
    if not worktree_path:
        sys.exit(0)  # ← РАННИЙ ВЫХОД
    # go mod download — не выполнен
    # agent-memory pre-seed — не выполнен
    # analytics — не записан
```

---

## 3. Детальный анализ проблем

### Проблема A: Вердикт всегда UNKNOWN

#### A1. Подтверждение из данных

Файл `review-completions.jsonl` (все 3 записи):

```jsonl
{"agent": "plan-reviewer", "verdict": "UNKNOWN", "session_id": "bbf20db4-..."}
{"agent": "", "verdict": "UNKNOWN", "session_id": "bbf20db4-..."}
{"agent": "plan-reviewer", "verdict": "UNKNOWN", "session_id": "4804e2fd-..."}
```

**100% UNKNOWN** — ни одного успешного извлечения вердикта за всё время работы системы.

#### A2. Корневая причина

Поле `last_assistant_message` **отсутствует** в SubagentStop payload.

Это подтверждено косвенно через `worktree-events-debug.jsonl` — WorktreeCreate и SubagentStop используют схожую структуру payload (оба генерируются Claude Code runtime). WorktreeCreate payload содержит только: `cwd, hook_event_name, name, session_id, transcript_path`.

Поле, которое должно содержать последнее сообщение агента — это `transcript_path`. Это путь к JSONL-файлу транскрипта сессии, последний assistant-entry которого содержит вердикт.

#### A3. Цепочка отказа

```
SubagentStop payload не имеет last_assistant_message
    → output = ""
    → regex не применяется
    → verdict = "UNKNOWN" (hardcoded default)
    → review-completions.jsonl хранит "UNKNOWN"
    → orchestrator читает review-completions.jsonl
    → шаг 1 on_incomplete_output: находит "UNKNOWN" (не валидный вердикт)
    → шаг 3: re-launch code-reviewer с minimal prompt
    → повторный агент делает полный review заново (20+ turns)
    → SubagentStop снова: verdict = "UNKNOWN"
    → шаг 4: запрос manual verdict у пользователя
```

Итого: каждый review-цикл требует ручного вмешательства пользователя.

#### A4. Предыстория (уже исправленные проблемы)

До этого была вторичная проблема: hook amplification loop.

```
code-reviewer пишет в .claude/agent-memory/ →
PostToolUse hooks (yaml-lint, check-references, check-plan-drift) выдают feedback →
агент видит feedback и пытается исправить →
ещё Write/Edit → ещё hooks → loop →
45 turns исчерпаны без вердикта
```

**Это уже исправлено** (коммиты `2c39d6b`, `6f73fbb`, `03027af`):

- `yaml-lint.sh` строка 21-24: guard `*agent-memory*` → exit 0 ✅
- `check-references.sh` строка 20-23: guard ✅
- `check-plan-drift.sh` строка 31-34: guard ✅
- `code-reviewer.md` RULE_5: 3-tier enforcement (turn 25/33/40) ✅

Но hook amplification fix не решает корневую проблему: даже если агент успешно выводит `VERDICT: APPROVED`, хук не может его извлечь.

---

### Проблема B: Воркдерево не подготавливается

#### B1. Подтверждение из данных

Файл `worktree-events-debug.jsonl` (обе записи):

```json
{
  "hook": "WorktreeCreate",
  "worktree_path_found": false,
  "received_keys": ["cwd", "hook_event_name", "name", "session_id", "transcript_path"]
}
```

`worktree_path_found: false` в **100% случаев**. Скрипт всегда уходит по раннему выходу.

#### B2. Что НЕ происходит

1. `go mod download` не запускается в воркдереве
2. `.claude/agent-memory/code-reviewer/` не копируется в воркдерево
3. Analytics event не записывается в `worktree-events.jsonl`

#### B3. Что происходит

Воркдерево **создаётся** Claude Code (frontmatter `isolation: worktree` обрабатывается runtime'ом). Но хук подготовки не может найти путь к нему.

**Поле `name`** в payload (`"agent-af5a930e"`, `"agent-a7c8c68b"`) — это имя агента/воркдерева. Фактический путь воркдерева, скорее всего, конструируется Claude Code внутренне (например, `/tmp/claude-worktrees/agent-af5a930e` или аналог), но не передаётся в hook payload.

#### B4. История проблемы

Была смежная проблема `{}` dir bug: скрипт выводил `echo '{}'`, который Claude Code парсил как worktreePath, создавая директорию `{}/` в корне проекта. Исправлено в коммите `8cde7c5` — скрипт теперь выводит `echo 'worktree prepared'`.

Но фундаментальная проблема остаётся: payload не содержит путь.

#### B5. Частичный workaround в save-review-checkpoint.sh

`save-review-checkpoint.sh` имеет 3 стратегии для нахождения worktree_path:

1. Из payload (не работает — поля нет)
2. Scan `.git/worktrees/` — ищет директорию, читает `gitdir` файл
3. `git worktree list --porcelain`

`prepare-worktree.sh` этих fallback'ов **не имеет** — после раннего выхода ничего не делает.

---

### Проблема C: Несогласованность документации и кода

#### C1. workflow-architecture.md vs реальное поведение

| Пункт                      | В docs                                   | В реальности                                                                                 |
| -------------------------- | ---------------------------------------- | -------------------------------------------------------------------------------------------- |
| WorktreeCreate stdout      | `{}` (minimal JSON)                      | `'worktree prepared'` (plain text)                                                           |
| PreToolUse blocking format | `{"decision": "block", "reason": "..."}` | `{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", ...}}` |

Исправленный формат зафиксирован в agent-memory (`hook-stdout-contracts.md`) — но не в официальной документации.

#### C2. orchestration-core.md: устаревший fallback

Phase 2/4 recovery:

```
2. If missing → SendMessage to the same agent requesting verdict only (1 retry, use agentId)
```

SendMessage — это deferred tool, которого нет в списке доступных. Исправлено в `workflow.md` (commands), но `orchestration-core.md` (skills) всё ещё содержит старый текст. Два источника правды расходятся.

#### C3. agent-memory/code-reviewer/hook-stdout-contracts.md

Гласит: `WorktreeCreate: {} — minimal non-empty JSON required`.

Но скрипт уже изменён на plain text. Файл agent-memory не обновлён.

---

### Проблема D: Второстепенные архитектурные риски

#### D1. Blocking SubagentStop hook без defensive exit

`save-review-checkpoint.sh` использует `set -euo pipefail` и `exit 2` при ошибке записи. Хук **блокирующий**. Если запись в `review-completions.jsonl` или вызов `sync-agent-memory.sh` провалится неожиданным образом — агент не сможет завершиться.

Критический путь:

```
sync-agent-memory.sh вызывается с subprocess.run(timeout=30)
→ если worktree_path неверный → exit 1 → записывает sync_log
→ save-review-checkpoint.sh продолжает
→ OK в этом случае
```

Но если `write completions_file` падает с `PermissionError`:

```python
sys.exit(2)  # ← hook exit 2 = Claude Code блокирует завершение агента
```

Нет retry, нет fallback в tmp.

#### D2. agent_type vs agent_name поле в SubagentStop

```python
agent_type = data.get("agent_type", data.get("agent_name", "unknown"))
```

review-completions.jsonl показывает `"agent": ""` (пустая строка) для code-reviewer в одной сессии. Поле может быть пустым или называться иначе (например, `name`, как в WorktreeCreate). Нет debug-логирования для SubagentStop аналогичного WorktreeCreate.

#### D3. plan-reviewer не имеет isolation: worktree, но save-review-checkpoint.sh его обрабатывает

`WORKTREE_AGENTS = {"code-reviewer"}` — guard правильный. Но в review-completions.jsonl первая запись:

```json
{"agent": "plan-reviewer", "worktree_path": "/Users/dmitriym/Desktop/claude-kit", "worktree_resolution": "payload"}
```

Это из предыдущей версии, где был `cwd` fallback (уже исправлено). Текущий код не попадёт в это состояние.

---

## 4. Граф причинно-следственных связей

```
КОРНЕВЫЕ ПРИЧИНЫ
    │
    ├─ [ROOT-1] SubagentStop payload не содержит last_assistant_message
    │       ↓ влияет на
    │   [P-A] verdict всегда UNKNOWN
    │       ↓ влияет на
    │   [E-A1] orchestrator не может автоматически завершить Phase 4
    │   [E-A2] каждый review требует re-launch или ручного вмешательства
    │   [E-A3] pipeline-metrics не записывают реальный вердикт
    │
    ├─ [ROOT-2] WorktreeCreate payload не содержит worktree_path
    │       ↓ влияет на
    │   [P-B] воркдерево не подготавливается
    │       ↓ влияет на
    │   [E-B1] go mod download не выполняется (риск компиляции)
    │   [E-B2] agent-memory не pre-seeded (агент начинает без истории)
    │   [E-B3] analytics события не записываются
    │
    ├─ [SECONDARY] Hook amplification loop (ИСПРАВЛЕНО)
    │   Было: agent-memory writes → hooks → feedback → loop → 45 turns исчерпаны
    │   Теперь: agent-memory guards → silent exit 0 ✅
    │   RULE_5 3-tier: turn 25/33/40 enforcement ✅
    │
    └─ [DOC-GAP] Расхождение документации и кода
            ↓ влияет на
        [E-D1] разработчик читает неверный hook contract
        [E-D2] orchestration-core.md ссылается на недоступный SendMessage
```

---

## 5. Лист улучшений с обоснованием

### IMP-01 (CRITICAL): Исправить извлечение вердикта в save-review-checkpoint.sh

**Проблема:** `last_assistant_message` отсутствует в SubagentStop payload. Вердикт всегда UNKNOWN.

**Решение:** Читать `transcript_path` из payload → парсить последний `assistant`-entry из JSONL → применять regex.

**Реализация:**

```python
# НОВЫЙ блок после agent_type extraction:
output = data.get("last_assistant_message", "")

# Если last_assistant_message отсутствует — читаем transcript
if not output:
    transcript_path = data.get("transcript_path", "")
    if transcript_path and os.path.isfile(transcript_path):
        try:
            with open(transcript_path) as f:
                lines = f.readlines()
            # Ищем последнее assistant-сообщение в обратном порядке
            for line in reversed(lines):
                try:
                    entry = json.loads(line.strip())
                    role = entry.get("role", "")
                    if role == "assistant":
                        content = entry.get("content", "")
                        if isinstance(content, list):
                            # Anthropic message format: [{type: "text", text: "..."}]
                            for block in content:
                                if isinstance(block, dict) and block.get("type") == "text":
                                    output = block.get("text", "")
                                    break
                        elif isinstance(content, str):
                            output = content
                        if output:
                            break
                except (json.JSONDecodeError, KeyError):
                    continue
        except Exception as e:
            print(f"save-review-checkpoint: transcript read failed: {e}", file=sys.stderr)
```

**Почему это нужно:**

- 100% записей в review-completions.jsonl имеют `verdict: "UNKNOWN"` — система полностью не работает
- Без реального вердикта каждый цикл code-review требует re-launch или manual intervention
- `transcript_path` уже присутствует в payload (подтверждено логами) — это правильный источник

**Польза:**

- Вердикт будет корректно извлекаться и записываться в review-completions.jsonl
- Orchestrator сможет автоматически двигаться по пайплайну без ручных вмешательств
- Статистика pipeline-metrics станет достоверной

---

### IMP-02 (CRITICAL): Добавить fallback-стратегии в prepare-worktree.sh

**Проблема:** `worktree_path` отсутствует в WorktreeCreate payload. Скрипт всегда уходит через ранний выход.

**Решение:** Добавить те же fallback-стратегии, что уже есть в `save-review-checkpoint.sh`.

**Реализация:** После блока `if not worktree_path: sys.exit(0)` — добавить:

```python
# Fallback Strategy 1: scan .git/worktrees/ for most recent worktree
if not worktree_path:
    worktrees_dir = os.path.join(".git", "worktrees")
    if os.path.isdir(worktrees_dir):
        try:
            entries = [d for d in os.listdir(worktrees_dir)
                       if os.path.isdir(os.path.join(worktrees_dir, d))]
            if entries:
                entries.sort(key=lambda d: os.path.getmtime(
                    os.path.join(worktrees_dir, d)), reverse=True)
                gitdir_file = os.path.join(worktrees_dir, entries[0], "gitdir")
                if os.path.isfile(gitdir_file):
                    with open(gitdir_file) as f:
                        candidate = f.read().strip().rsplit("/.git", 1)[0]
                    if os.path.isdir(candidate):
                        worktree_path = candidate
        except Exception as e:
            print(f"prepare-worktree: .git/worktrees scan failed: {e}", file=sys.stderr)

# Fallback Strategy 2: git worktree list --porcelain
if not worktree_path:
    try:
        import subprocess
        result = subprocess.run(
            ["git", "worktree", "list", "--porcelain"],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0:
            worktrees = []
            for line in result.stdout.splitlines():
                if line.startswith("worktree "):
                    path = line[len("worktree "):]
                    if path != os.getcwd():
                        worktrees.append(path)
            if worktrees:
                candidate = worktrees[-1]
                if os.path.isdir(candidate):
                    worktree_path = candidate
    except Exception:
        pass

if not worktree_path:
    sys.exit(0)  # Честный fallback если всё равно не нашли
```

**Почему это нужно:**

- Без `worktree_path` агент работает в воркдереве без `go mod download` — риск compilation failure
- Agent-memory не pre-seeded — каждый запуск code-reviewer начинает с нуля, без накопленных паттернов ревью
- Analytics не записываются — нет observability для worktree операций
- Код fallback уже написан и протестирован в `save-review-checkpoint.sh` — можно переиспользовать напрямую

**Польза:**

- Воркдерево будет правильно подготовлено в большинстве случаев
- Агент унаследует накопленный agent-memory с паттернами ревью
- Worktree analytics будут работать

---

### IMP-03 (HIGH): Добавить debug-логирование для SubagentStop payload

**Проблема:** Нет аналога `worktree-events-debug.jsonl` для SubagentStop. Не знаем точно, какие поля есть в payload, кроме тех что уже используем.

**Решение:** В `save-review-checkpoint.sh`, добавить ALWAYS-логирование всех полей payload (кроме `last_assistant_message` — слишком большой) в `worktree-events-debug.jsonl`.

```python
# ALWAYS log SubagentStop payload for contract discovery
try:
    discovery = {
        "timestamp": timestamp,
        "hook": "SubagentStop",
        "agent_type": agent_type,
        "session_id": session_id,
        "received_keys": sorted(data.keys()),
        "payload_sample": {
            k: str(v)[:200] for k, v in data.items()
            if k not in ("last_assistant_message",)
        },
        "verdict_found": verdict != "UNKNOWN",
        "transcript_path_present": bool(data.get("transcript_path")),
    }
    with open(DEBUG_FILE, "a") as f:
        f.write(json.dumps(discovery) + "\n")
except Exception:
    pass
```

**Почему это нужно:**

- Мы знаем WorktreeCreate payload, но не знаем SubagentStop payload точно
- `agent_type` иногда `""` — не знаем почему (возможно используется другое поле)
- После IMP-01 нужно проверить, что `transcript_path` действительно присутствует

**Польза:**

- Возможность верифицировать IMP-01 после деплоя
- Понимание почему agent иногда "" — можно добавить fallback на `data.get("name")`
- Основа для контрактной документации SubagentStop

---

### IMP-04 (HIGH): Синхронизировать документацию с реальными hook contracts

**Проблема:** `workflow-architecture.md` и `agent-memory/code-reviewer/hook-stdout-contracts.md` содержат устаревшую информацию о WorktreeCreate stdout contract (`{}` vs plain text).

**Решение:**

В `workflow-architecture.md` строка 17:

```markdown
# БЫЛО:
| WorktreeCreate | prepare-worktree.sh | `{}` (minimal JSON) | Required non-empty |

# СТАЛО:
| WorktreeCreate | prepare-worktree.sh | Plain text (e.g. `worktree prepared`) | Required non-empty; JSON avoided — Claude Code parses JSON as worktree metadata |
```

В `agent-memory/code-reviewer/hook-stdout-contracts.md`:

```markdown
# БЫЛО:
WorktreeCreate (prepare-worktree.sh):
`{}` — minimal non-empty JSON required.

# СТАЛО:
WorktreeCreate (prepare-worktree.sh):
Plain text required (e.g. 'worktree prepared').
WARNING: JSON output (e.g. '{}') is parsed by Claude Code as WorktreeCreate metadata
and was causing '{}/' directory creation at project root (fixed 2026-03-30, commit 8cde7c5).
```

Дополнительно — исправить PreToolUse blocking format в `workflow-architecture.md` (уже зафиксированный в agent-memory, но не в docs):

```markdown
# БЫЛО:
| PreToolUse | protect-files.sh | `{"decision": "block", "reason": "..."}` |

# СТАЛО:
| PreToolUse | protect-files.sh | `{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "..."}}` |
```

**Почему это нужно:**

- Разработчик, читая документацию, получит неверные инструкции для нового хука
- Два источника правды (`workflow-architecture.md` и `agent-memory/hook-stdout-contracts.md`) расходятся — непонятно какому верить
- PreToolUse в Claude Code v2.x использует `hookSpecificOutput` envelope — это критически важно для blocking hooks

**Польза:**

- Единый источник правды для hook contracts
- Новые хуки будут написаны с правильным форматом сразу

---

### IMP-05 (MEDIUM): Синхронизировать orchestration-core.md с исправлением output_validation

**Проблема:** `orchestration-core.md` (в skills) ссылается на SendMessage в Phase 2/4 recovery:

```
2. If missing → SendMessage to the same agent requesting verdict only (1 retry, use agentId)
```

`workflow.md` (в commands) уже исправлен — там re-launch вместо SendMessage.

**Решение:** Обновить orchestration-core.md Phase 2/4 раздел:

```markdown
# БЫЛО:
2. If missing → SendMessage to the same agent requesting verdict only (1 retry, use agentId)
3. If verdict recovered → continue pipeline normally
4. If unrecoverable → WARN user with available agent summary, request manual verdict decision

# СТАЛО:
2. If missing → re-launch review agent with minimal prompt (SEE workflow.md → output_validation.on_incomplete_output)
   Minimal prompt: "Output ONLY: VERDICT: {verdict} followed by brief handoff. No memory save."
3. If verdict recovered from re-launch → continue pipeline normally
4. If re-launch also fails → WARN user, check review-completions.jsonl, request manual verdict
```

**Почему это нужно:**

- `SendMessage` — deferred tool, недоступен без явного запроса. Ссылка на него вводит в заблуждение
- Расхождение между `workflow.md` (commands) и `orchestration-core.md` (skills) — какому артефакту доверять?
- Оркестратор читает оба файла при старте; если они расходятся, поведение непредсказуемо

**Польза:**

- Единое поведение re-launch fallback задокументировано в обоих местах
- Оркестратор не будет пытаться вызвать недоступный SendMessage

---

### IMP-06 (MEDIUM): Добавить defensive fallback в blocking SubagentStop hook

**Проблема:** `save-review-checkpoint.sh` — блокирующий хук с `exit 2` при ошибке записи. При `PermissionError` на запись в `review-completions.jsonl` агент не сможет завершиться.

**Решение:** Добавить fallback в tmp-директорию при ошибке записи основного файла:

```python
completions_file = ".claude/workflow-state/review-completions.jsonl"
try:
    with open(completions_file, "a") as f:
        f.write(json.dumps(marker) + "\n")
except Exception as e:
    # Fallback: write to /tmp to avoid blocking agent completion
    import tempfile
    fallback_file = os.path.join(tempfile.gettempdir(), "claude-review-completions-fallback.jsonl")
    try:
        with open(fallback_file, "a") as f:
            f.write(json.dumps(marker) + "\n")
        print(f"WARN: Primary write failed ({e}), wrote to fallback: {fallback_file}", file=sys.stderr)
        # Exit 0 — don't block agent completion for a logging failure
    except Exception as e2:
        print(f"ERROR: Both primary and fallback write failed: {e} / {e2}", file=sys.stderr)
        sys.exit(2)  # Только если вообще ничего не работает
```

**Почему это нужно:**

- Logging failure не должна блокировать завершение review агента
- Блокировка агента ведёт к тому, что оркестратор застывает в ожидании
- Tmp fallback достаточен для диагностики

**Польза:**

- Надёжность: ошибки инфраструктуры не блокируют workflow
- Данные не теряются — записываются в fallback

---

### IMP-07 (LOW): Добавить `name`-поле в agent_type extraction

**Проблема:** В review-completions.jsonl встречается `"agent": ""` — agent_type оказывается пустой строкой. Это может быть случай, когда поле называется `name` (как в WorktreeCreate payload), а не `agent_type` или `agent_name`.

**Решение:**

```python
# БЫЛО:
agent_type = data.get("agent_type", data.get("agent_name", "unknown"))

# СТАЛО:
agent_type = (
    data.get("agent_type")
    or data.get("agent_name")
    or data.get("name")
    or "unknown"
)
```

**Почему это нужно:**

- `"agent": ""` в completions.jsonl не позволяет понять, какой агент завершился
- Matcher `"plan-reviewer|code-reviewer"` работает по этому полю — `""` не матчится (но хук всё равно запускается)
- Диагностика усложняется когда агент не идентифицирован

**Польза:**

- Корректная идентификация агента в журнале
- Возможность отладки при будущих проблемах

---

## 6. Приоритизированный план действий

| Приоритет | IMP    | Файл                                      | Описание                               | Усилие |
| --------- | ------ | ----------------------------------------- | -------------------------------------- | ------ |
| P0        | IMP-01 | `save-review-checkpoint.sh`               | Читать verdict из transcript_path      | M      |
| P0        | IMP-02 | `prepare-worktree.sh`                     | Добавить git worktree fallbacks        | S      |
| P1        | IMP-03 | `save-review-checkpoint.sh`               | SubagentStop debug logging             | S      |
| P1        | IMP-04 | `workflow-architecture.md` + agent-memory | Синхронизировать hook contracts        | S      |
| P2        | IMP-05 | `orchestration-core.md`                   | Убрать SendMessage, добавить re-launch | S      |
| P2        | IMP-06 | `save-review-checkpoint.sh`               | Defensive fallback для blocking hook   | S      |
| P3        | IMP-07 | `save-review-checkpoint.sh`               | agent_type fallback на `name` field    | XS     |

**Порядок выполнения:** IMP-01 и IMP-02 — независимые, можно делать параллельно. IMP-03 нужен для верификации IMP-01. Остальные — независимые улучшения.

---

## 7. Проверочные критерии

После применения улучшений:

```bash
# P-A: Вердикт больше не UNKNOWN
cat .claude/workflow-state/review-completions.jsonl | jq '.verdict' | sort | uniq
# Expected: ["APPROVED", "APPROVED_WITH_COMMENTS", "CHANGES_REQUESTED"] (не "UNKNOWN")

# P-B: Воркдерево подготавливается
cat .claude/workflow-state/worktree-events-debug.jsonl | jq '.worktree_path_found'
# Expected: true (хотя бы через fallback)

# Регрессия: хуки всё ещё срабатывают на artifacts
echo '{"tool_input":{"file_path":".claude/rules/test.md"}}' | bash .claude/agents/meta-agent/scripts/yaml-lint.sh
# Expected: output (не silent)

# Регрессия: хуки НЕ срабатывают на agent-memory
echo '{"tool_input":{"file_path":".claude/agent-memory/code-reviewer/test.md"}}' | bash .claude/agents/meta-agent/scripts/yaml-lint.sh
# Expected: silent (exit 0)
```
