# Презентация claude-kit для другой команды

> **Формат:** 10–15 мин доклад + воркшоп (живой прогон) + 10 мин Q&A  
> **Аудитория:** команда разработки, знакомая с Claude Code на базовом уровне  
> **Цель:** показать, что такое claude-kit, зачем он нужен, как встроить в свой процесс

---

## Блок 1. ХУК — «боль, которую решаем» (1–2 мин)

- Claude Code из коробки — мощный, но **без структуры**: один длинный разговор, нет фаз, нет шлюзов качества
- Реальные проблемы, с которыми сталкиваются все команды:
  - **Контекст-байас ревью** — тот же агент, который написал код, его же проверяет → *«конечно, всё ок»*
  - **Кривой план → месиво кода** — начинаем кодить без плана, через 30 минут осознаём, что надо всё переделать
  - **Потеря прогресса** — сессия упала на Phase 3 Part 5 из 7 → начинаем с нуля
  - **Drift между планом и кодом** — реализовали не то, что планировали, без явного лога отклонений
- **claude-kit** превращает Claude Code из «умного автокомплита» в **управляемый pipeline с шлюзами качества**

---

## Блок 2. ЧТО ЭТО — высокоуровневый обзор (2–3 мин)

- **claude-kit** = переиспользуемая конфигурация `.claude/` для Claude Code: многоагентный workflow с фазами планирования, реализации и ревью
- Один reusable pack для любого проекта — Go, Python, TypeScript, Rust, Java (31 язык через tree-sitter)
- Масштаб:
  - **8 команд** (/workflow, /planner, /coder, /designer, /meta-agent, /project-researcher, /db-explorer, /review-checklist)
  - **4 агента** (plan-reviewer, code-reviewer, code-researcher, verdict-recovery)
  - **8 skill-пакетов** (workflow-protocols, planner-rules, coder-rules, plan-review-rules, code-review-rules, design-rules, systematic-debugging, tdd-go)
  - **24+ hook-скрипта** — автоматически срабатывают на 14 событиях жизненного цикла Claude Code
- Инсталляция одной командой: `curl … install.sh | bash`

---

## Блок 3. АРХИТЕКТУРА — pipeline из 8 фаз (3–4 мин)

- Центральный элемент: `/workflow` — **оркестратор**, который последовательно делегирует работу специализированным агентам

**Поток:**
```
Task Analysis (0.5) → Design (0.7, только L/XL) → Planning (1)
  → Plan Review (2) → Implementation (3) → Spec Check (3.5)
  → Code Review (4) → Completion (5, git commit + метрики)
```

- **Маршрутизация по сложности** (S/M/L/XL) — не все фазы запускаются для тривиальных задач:
  - **S** (1 Part, 1 слой): `/planner --minimal` → сразу `/coder` → ревью кода (пропускаем дизайн и ревью плана)
  - **M** (2–3 Parts, 2 слоя): стандарт без дизайна
  - **L** (4–6 Parts, 3+ слоя): полный цикл + Sequential Thinking рекомендован
  - **XL** (7+ Parts, 4+ слоя): полный цикл + Sequential Thinking обязателен
- **Ключевое архитектурное разделение:**
  - **Commands** (`/workflow`, `/planner`, `/coder`) — работают в **общем контексте**, разделяют анализ, память, handoffs
  - **Agents** (`plan-reviewer`, `code-reviewer`) — работают в **изолированном «чистом» контексте** → нет authorship-байаса, ревью непредвзято
- Это разделение — намеренное. Код-ревью от того же агента, который писал код, — это не ревью
- **Модели:** `/workflow`, `/planner`, `/coder`, plan-reviewer, code-reviewer — все на Opus (effort: max). Только code-researcher и verdict-recovery — Haiku (для скорости и стоимости)

---

## Блок 4. КАК ЭТО РАБОТАЕТ — 5 принципов, которые делают систему надёжной (3–4 мин)

- **1. Типизированные handoff-контракты между фазами** (MetaGPT pattern)
  - 4 контракта: `designer → planner`, `planner → plan-review`, `plan-review → coder`, `coder → code-review`
  - Каждый handoff — JSON, валидируется автоматически хуком `validate-handoff.sh` по JSON Schema
  - Никаких «а я забыл передать»: orchestrator обязан записать полный payload перед делегированием

- **2. Context isolation для ревью**
  - plan-reviewer и code-reviewer запускаются как **native sub-agents** Claude Code с собственным контекстом
  - Не видят историю разговора с оркестратором → нет байаса «автор уже объяснил, почему так»
  - code-reviewer дополнительно изолирован через **git worktree** — видит только закоммиченный diff, не кэш редактора

- **3. Лимиты циклов — максимум 3 итерации на ревью**
  - Если plan-review 3 раза подряд вернул NEEDS_CHANGES → остановка, показ таблицы итераций, запрос помощи пользователя
  - Защищает от бесконечных циклов, когда агент не может выйти на APPROVED
  - Сводка с difference: какие issues были, какие resolved, какие regressed

- **4. Checkpoint-протокол — мгновенное восстановление после падения**
  - После **каждой** фазы пишется `{feature}-checkpoint.yaml` (12 полей: фаза, итерация, verdict, handoff, issues_history)
  - Дополнительно для XL-задач: CronCreate каждые 10 минут пишет mid-phase checkpoint
  - Пропала сессия на Part 5 из 7? `/workflow --from-phase 3` → продолжаем с Part 6 (предыдущие не перереализуем)

- **5. Evaluate gate — coder критически читает план ДО реализации**
  - Перед IMPLEMENT coder запускает EVALUATE sub-phase: PROCEED / REVISE / RETURN
  - RETURN → план возвращается в Phase 1 (до реализации!) — защита от «плохих планов, которые проще переписать»
  - Это дешевле, чем найти проблему на code-review после 4 часов кодинга

---

## Блок 5. ЧТО ПОЛУЧАЕМ В ИТОГЕ (1–2 мин)

- **Каждое изменение проходит через:**
  - Explicit план в `.claude/prompts/{feature}.md`
  - Архитектурное ревью плана (import matrix, слои, sections)
  - Реализацию строго по плану с логом отклонений
  - Автозапуск `fmt + lint + test` (VERIFY)
  - Spec check — соответствие реализации плану
  - Security + архитектурное ревью кода в изолированном worktree
  - Git commit по conventional format
- **Метрики собираются автоматически** в `pipeline-metrics.jsonl`: итераций ревью, найдено issues по severity, использовался ли Sequential Thinking, сколько времени заняла фаза
- Результат: **воспроизводимый, ревьюабельный, тестируемый процесс разработки с AI**

---

## Блок 6. ДЛЯ КОГО ЭТО (1 мин)

- **Команды, которые уже используют Claude Code** и хотят структуру
- **Legacy-проекты**, где нельзя допускать «хаотичных AI-правок» без ревью
- **Проекты с жёсткими архитектурными контрактами** (например, слоистая архитектура: handler → service → repository → models)
- **Не подходит для:** быстрых one-off скриптов, экспериментов, когда план избыточен

---

# ВОРКШОП — живая демонстрация (10–15 мин)

## План воркшопа

### Шаг 1. Подготовка — 1 мин
- Показать `.claude/` структуру
- Показать `CLAUDE.md` — project-specific конфиг (Language Profile, Rules)
- Показать `settings.json` — хуки, permissions

### Шаг 2. Запуск `/workflow` на реальной задаче — 8–10 мин

**Кейс для демо:** небольшой M-complexity таск (например, «добавить поле `status` в модель User с миграцией и endpoint»)

- **Phase 0.5 — Task Analysis:**
  - Показать, как `/workflow` классифицирует: `type=new_feature, complexity=M, route=standard`
  - Объяснить: вот эта классификация определяет, какие фазы запустятся

- **Phase 1 — Planning:**
  - Показать `.claude/prompts/add-user-status.md` — реальный плановый артефакт
  - Обратить внимание на: Parts, Architecture Decision, Tests section, acceptance criteria

- **Phase 2 — Plan Review** (самое эффектное):
  - Показать, как plan-reviewer запускается в отдельном контексте (Task tool → clean slate)
  - Показать VERDICT_JSON в выводе ревьюера: `APPROVED / NEEDS_CHANGES / REJECTED` + структурированные issues
  - Показать `.claude/workflow-state/review-completions.jsonl` — автоматический persist ревью
  - **Если время есть:** спровоцировать NEEDS_CHANGES, показать iteration 2/3 loop

- **Phase 3 — Implementation:**
  - Показать coder EVALUATE sub-phase: «я читаю план, решаю PROCEED/REVISE/RETURN»
  - Показать автоматический pre-commit build hook (`pre-commit-build.sh`)
  - Показать import matrix enforcer (prompt-hook) в действии — попытка импорта repository в handler блокируется

- **Phase 4 — Code Review:**
  - Показать, как code-reviewer запускается в **git worktree** (изолированная копия репо)
  - Показать `worktree.sparsePaths` в settings.json — какие директории попадают в worktree
  - Показать verdict + handoff

- **Phase 5 — Completion:**
  - Показать git commit message format
  - Показать `pipeline-metrics.jsonl` — что зафиксировалось

### Шаг 3. Сценарий восстановления — 2 мин
- Намеренно прервать workflow командой Ctrl+C посреди Phase 3
- Показать `{feature}-checkpoint.yaml` на диске
- Запустить `/workflow --from-phase 3` — продолжить с того же места
- Ключевой тезис: **«вы не теряете работу»**

### Шаг 4. Кастомизация под свой стек — 1 мин
- Показать, как обновить `CLAUDE.md` Language Profile под Python/TS
- Показать override `settings.local.json` для личных настроек (gitignored)
- Команда `/project-researcher` — автогенерация `PROJECT-KNOWLEDGE.md` под свою кодобазу

---

# Q&A — заготовки для типичных вопросов (10 мин)

### Q1: «А сколько это стоит в токенах/деньгах на каждую задачу?»
- Зависит от сложности:
  - **S:** ~20–40k токенов (один prompt → план → код → ревью)
  - **M:** ~80–150k токенов
  - **L/XL:** 300k–1M+ токенов (особенно при 3 итерациях ревью и code-researcher)
- Оптимизации в kit:
  - `effort: max` только для pipeline-агентов (Opus)
  - code-researcher и verdict-recovery на Haiku (в 10–20 раз дешевле)
  - `disable-model-invocation: true` для skills — не загружаются, пока не нужны
  - Conditional `if:` на хуках (v2.1.85+) — не спавним процессы зря

### Q2: «Почему не один агент делает всё? Зачем plan-reviewer отдельно?»
- Ключевой архитектурный принцип: **context isolation устраняет authorship-bias**
- Тот же агент, который написал код, найдёт в нём на 30–50% меньше проблем (подтверждено и исследованиями, и нашей практикой)
- plan-reviewer и code-reviewer запускаются через native Claude Code sub-agents — они **не знают**, что до них был /planner и /coder; видят только артефакт + handoff
- Это аналог code review в обычной разработке: автор и ревьюер — разные люди по очень веским причинам

### Q3: «Что если я хочу кастомную фазу? Например, security-review?»
- `/meta-agent create agent security-reviewer` — сгенерирует skeleton агента с артефакт-валидацией
- Добавить его в pipeline workflow.md (Phase 4.5 между code-review и completion)
- Kit спроектирован расширяемым: команды/агенты/хуки/скиллы — всё отдельные файлы с типовым форматом

### Q4: «Как это сочетается с обычным git workflow (branches, PR)?»
- /workflow создаёт коммит в текущей ветке
- code-reviewer работает на уже закоммиченных изменениях (через worktree)
- После APPROVED → обычный `git push` + PR на GitHub/GitLab
- Можно связать с GitHub: есть `/review` и `/security-review` команды для работы с PR через `gh` CLI

### Q5: «Что если Claude даст неправильный verdict или застрянет?»
- **Safety nets:**
  - Лимит 3 итерации на ревью → автостоп с показом iteration summary
  - VERDICT_JSON валидация через JSON Schema (IMP-02) — если агент выдал мусор, hook ловит
  - verdict-recovery агент (Haiku, 30 сек) — если основной ревьюер не дал verdict, запускается lightweight fallback
  - При 3x VERIFY fail auto-loads `systematic-debugging` skill — 4-phase debugging process
- **Вы всегда можете:**
  - Сказать «stop» → checkpoint сохраняется, можно возобновить
  - `--from-phase N` → вручную выбрать фазу возобновления

### Q6: «Что с безопасностью? AI может удалить файлы или отправить данные куда-то?»
- `block-dangerous-commands.sh` (PreToolUse hook) блокирует: `rm -rf`, `git reset --hard`, `git push --force`, `sudo`, `chmod 777`, `git clean`, `dd`, `mkfs`
- `protect-files.sh` блокирует Write/Edit на критичные конфиги (`.env`, keys, secrets)
- `audit-config-change.sh` логирует все изменения `.claude/settings*.json` и блокирует их во время активного workflow
- `log-permission-denied.sh` ведёт audit log всех отказов — post-hoc анализ
- Всё это — **deterministic shell scripts**, не LLM-based, поэтому нельзя «переубедить»

### Q7: «Что с Go-специфичными вещами (import matrix, race detector)? Работает ли для Python?»
- CLAUDE.md имеет **Language Profile** section: по умолчанию Go, но легко переопределяется
- `/project-researcher` автогенерирует `PROJECT-KNOWLEDGE.md` под ваш стек (Python/TS/Rust)
- Rules типа `architecture.md` (import matrix) — опциональны, включаются через `active:` в frontmatter
- Для Python/TS: вместо import matrix — свои архитектурные правила (module boundaries, layer rules)
- Скрипт `auto-fmt-go.sh` легко заменить на `black`/`prettier`/`rustfmt` — это просто shell hook

### Q8: «Сколько времени на настройку kit в новом проекте?»
- Минимум: `curl install.sh | bash` — 30 секунд
- Правильно: + 15 мин на обновление `CLAUDE.md` Language Profile
- Идеал: + `/project-researcher` → автогенерация `PROJECT-KNOWLEDGE.md` — 10–30 мин на средний проект
- Итого: **первый полноценный /workflow за час после установки**

### Q9: «А если я уже использую другие AI-инструменты (Copilot, Cursor)?»
- Не взаимоисключающие: Copilot/Cursor — inline completion, claude-kit — structured workflow для фич целиком
- Типичное разделение: мелкие правки в IDE через Copilot, полноценные фичи через `/workflow`
- Kit не конфликтует с существующими `.cursor/`, `.github/copilot/` и т.п.

### Q10: «Где исходники, как контрибьютить, где changelog?»
- GitHub: `hex0xdeadbeef/claude-kit` (open source)
- Issues/PRs приветствуются
- `/meta-agent` команда специально создана для безопасного изменения самих артефактов kit (9-phase workflow с quality gates)

---

# Запасные слайды / буллеты (на случай если остаётся время)

- **Conditional hooks (v2.1.85+):** `if: Write(internal/**/*.go)` — хук не спавнится на неподходящих событиях → экономия сотен процессов за сессию
- **Sparse checkout для code-reviewer:** `worktree.sparsePaths` в settings.json ограничивает checkout только нужными директориями → быстрее worktree для монорепозиториев
- **IMP-04 Diff-based replan:** на iter 2+ ревью плана не переписывается целиком — только Parts с изменениями; preserve UNCHANGED Parts verbatim → стабильность и экономия токенов
- **`disable-model-invocation: true` в skills:** skill не читается моделью автоматически — только когда orchestrator явно вызывает Skill(). Экономия контекста в startup

---

# Чек-лист для презентующего

**До:**
- [ ] Проверить, что kit установлен на демо-машине
- [ ] Подготовить demo-проект (маленький Go/Python проект с `.claude/`)
- [ ] Протестировать /workflow на demo-задаче заранее — всё должно работать
- [ ] Открыть терминал, VS Code, `.claude/prompts/`, `.claude/workflow-state/` — 3 окна для показа
- [ ] Иметь наготове `--from-phase 3` сценарий восстановления

**Во время:**
- [ ] Каждый блок доклада — максимум 2 тезиса на слайд, не больше
- [ ] Не уходить в IMP-01…IMP-06 детали — это внутренняя кухня, аудитории неинтересно
- [ ] Во время воркшопа показывать файлы на экране в реальном времени, не скриншоты
- [ ] Подчёркивать 2 ключевые идеи: **context isolation для ревью** и **checkpoint для восстановления**

**После:**
- [ ] Дать ссылку на репо
- [ ] Собрать feedback (что было непонятно? что хотите попробовать?)
