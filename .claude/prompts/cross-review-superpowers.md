---
title: "Cross-Review: Superpowers vs Claude Kit Workflow"
task_type: documentation
complexity: XL
output: ".claude/docs/cross-review-superpowers.md"
---

# Prompt: Cross-Review Superpowers → Claude Kit Workflow

## Задача

Провести глубокий анализ проекта **Superpowers** (`/Users/dmitriym/Desktop/claude-kit/superpowers-main`) и выполнить кросс-ревью с нашим Workflow-пайплайном (документация: `.claude/docs/workflow-architecture.md`). Результат — детальный `.md`-отчёт с рекомендациями по адаптации сильных сторон Superpowers в наш Workflow.

## Исследование Superpowers (Фаза 1)

### 1.1 — Структура проекта

Прочитай и задокументируй:

- **Skills** (14 пакетов в `skills/`): прочитай каждый `SKILL.md` и все supporting-файлы. Особое внимание:
  - `subagent-driven-development` — как организована параллельная работа субагентов
  - `systematic-debugging` — методология отладки (7 файлов, включая test-pressure-*, root-cause-tracing)
  - `brainstorming` — визуальный компаньон, WebSocket-сервер (`scripts/server.cjs`), spec-reviewer
  - `dispatching-parallel-agents` — паттерн параллельного запуска агентов
  - `writing-skills` — мета-навык: как писать навыки (persuasion-principles, anthropic-best-practices)
  - `verification-before-completion` — финальная верификация перед завершением
  - `finishing-a-development-branch` — завершение ветки (git workflow)
  - `receiving-code-review` / `requesting-code-review` — двусторонний процесс code review

- **Commands** (3 файла в `commands/`): `write-plan.md`, `execute-plan.md`, `brainstorm.md`
- **Agents** (1 файл в `agents/`): `code-reviewer.md`
- **Hooks** (`hooks/hooks.json`, `hooks-cursor.json`, `session-start`, `run-hook.cmd`)
- **Multi-platform** (`.claude-plugin/`, `.cursor-plugin/`, `.codex/`, `.opencode/`, `GEMINI.md`, `gemini-extension.json`)
- **Tests** (`tests/` — все поддиректории: claude-code, explicit-skill-requests, skill-triggering, subagent-driven-dev, brainstorm-server, opencode)
- **Docs** (`docs/` — планы, спеки, windows-совместимость)

### 1.2 — Архитектурные паттерны

Для каждого артефакта определи:
- Назначение и роль в workflow
- Триггер активации (автоматический через SKILL.md frontmatter vs ручной через /command)
- Зависимости от других артефактов
- Ограничения и edge cases

### 1.3 — Ключевые концепции

Извлеки и задокументируй уникальные концепции Superpowers:
- **Subagent-Driven Development (SDD)** — как организована параллельная работа
- **Visual Brainstorming** — WebSocket-сервер для визуального companion
- **Document Review System** — spec-reviewer, plan-reviewer промпты
- **Persuasion Principles** — как навыки "убеждают" модель следовать им
- **Multi-platform plugin architecture** — единый код для 5+ платформ
- **Test infrastructure** — как тестируются skills и их триггеринг
- **Skill auto-triggering** — как модель автоматически активирует навыки без /command

## Кросс-ревью (Фаза 2)

Прочитай `.claude/docs/workflow-architecture.md` (наша документация по Workflow) и сравни по следующим осям:

### 2.1 — Сравнительная таблица

| Аспект             | Claude Kit Workflow | Superpowers | Преимущество |
| ------------------ | ------------------- | ----------- | ------------ |
| Pipeline structure | ...                 | ...         | ...          |
| Planning phase     | ...                 | ...         | ...          |
| Code review        | ...                 | ...         | ...          |
| Debugging          | ...                 | ...         | ...          |
| Testing approach   | ...                 | ...         | ...          |
| Parallel execution | ...                 | ...         | ...          |
| State management   | ...                 | ...         | ...          |
| Multi-platform     | ...                 | ...         | ...          |
| Skill loading      | ...                 | ...         | ...          |
| Hooks system       | ...                 | ...         | ...          |
| Agent isolation    | ...                 | ...         | ...          |
| Verification       | ...                 | ...         | ...          |

### 2.2 — Сильные стороны Superpowers

Для каждой сильной стороны:
- **Что:** описание фичи/подхода
- **Как работает:** техническая реализация
- **Почему сильно:** что это даёт по сравнению с альтернативами
- **Есть ли у нас аналог:** да/нет/частично → что именно

### 2.3 — Сильные стороны Claude Kit Workflow

Аналогичная структура для наших преимуществ — чтобы отчёт был объективным.

## Рекомендации по адаптации (Фаза 3)

### 3.1 — Quick Wins (можно внедрить быстро)

Фичи, которые:
- Не требуют архитектурных изменений
- Можно добавить как новый skill или дополнение к существующему
- Оценка: S-M complexity

Для каждой:
- Что адаптируем
- Откуда берём (файл в Superpowers)
- Куда кладём (путь в Claude Kit)
- Что нужно изменить при адаптации

### 3.2 — Strategic Adoptions (требуют планирования)

Фичи, которые:
- Требуют изменения существующих артефактов
- Могут потребовать новые hooks, agents, или commands
- Оценка: L-XL complexity

Для каждой:
- Описание и мотивация
- Архитектурный импакт на наш Workflow
- Зависимости и риски
- Приоритет (P1/P2/P3)

### 3.3 — НЕ рекомендуется адаптировать

Фичи, которые не подходят или уже решены лучше в нашем Workflow. С обоснованием.

## Формат выходного файла

Создай файл `.claude/docs/cross-review-superpowers.md`:

```yaml
---
title: "Cross-Review: Superpowers vs Claude Kit Workflow"
version: "1.0"
date: "{дата}"
superpowers_version: "{из package.json}"
claude_kit_ref: "workflow-architecture.md"
skills_analyzed: {число}
recommendations_total: {число}
quick_wins: {число}
strategic: {число}
not_recommended: {число}
---
```

Затем Markdown-тело с секциями:
1. Executive Summary (5-7 предложений)
2. Superpowers Architecture Overview
3. Сравнительная таблица (2.1)
4. Сильные стороны Superpowers (2.2)
5. Сильные стороны Claude Kit (2.3)
6. Quick Wins (3.1)
7. Strategic Adoptions (3.2)
8. Не рекомендуется (3.3)
9. Приоритизированный Roadmap (топ-5 рекомендаций с обоснованием)

## Правила исследования

- Читай ВСЕ файлы, не пропускай — проект небольшой (~138 файлов)
- Используй code-researcher агентов параллельно для ускорения (минимум 3 агента)
- Не делай предположений — только факты из кода
- Технические термины на английском, описания на русском
- Если файл большой (>200 строк) — читай полностью, не пропускай секции
- Мермейд-диаграммы приветствуются для визуализации архитектуры Superpowers
