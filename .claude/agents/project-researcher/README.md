# Project Researcher Agent v3.0

Автономный агент для глубокого исследования проектов и генерации `.claude/` конфигурации.

## Что нового в v3.0

- **AST-based analysis** — структурный анализ кода через ast-grep вместо grep-эвристик
- **Dependency graph** — построение графа зависимостей с метриками fan-in/fan-out
- **Structured state** — typed state contract между фазами вместо markdown-передачи
- **DISCOVER phase** — нативная поддержка монореп и multi-module проектов
- **Progressive context loading** — фазы загружаются по одной, стейт сохраняется

## Использование

```
Task tool:
  subagent_type: "project-researcher"
  prompt: "Исследуй проект и создай .claude/ конфигурацию"
```

## Операционные режимы

| Режим | Когда | Действия |
|-------|-------|----------|
| CREATE | Нет `.claude/` | Полный анализ, создание с нуля |
| AUGMENT | Есть `.claude/`, нет `PROJECT-KNOWLEDGE.md` | Дополнение существующей конфигурации |
| UPDATE | Есть `PROJECT-KNOWLEDGE.md` | Инкрементальное обновление |

## Структура

```
project-researcher/
├── AGENT.md                    # Orchestrator (точка входа)
├── phases/
│   ├── 1-validate.md          # VALIDATE + AUDIT + GIT ANALYSIS
│   ├── 1.5-discover.md        # DISCOVER (monorepo/module detection) [NEW v3.0]
│   ├── 2-detect.md            # DETECT (tech stack, AST-first)
│   ├── 3-analyze.md           # ANALYZE (architecture, AST-enhanced)
│   ├── 4-map.md               # MAP + DEPENDENCY GRAPH + DATABASE
│   ├── 5-generate.md          # GENERATE (artifacts)
│   ├── 6-report.md            # REPORT
│   ├── 7-critique.md          # CRITIQUE (self-review)
│   └── 8-verify.md            # VERIFY (external validation)
├── templates/
│   └── project-knowledge.md   # Шаблон PROJECT-KNOWLEDGE.md
├── reference/
│   ├── language-patterns.md   # Паттерны детекции языков
│   └── scoring.md             # Система confidence scoring
├── deps/
│   ├── ast-analysis.md        # AST-grep patterns [NEW v3.0]
│   ├── state-contract.md      # Inter-phase state schema [NEW v3.0]
│   ├── edge-cases.md          # Known limitations
│   ├── step-quality.md        # Per-phase quality checks
│   └── reflexion.md           # Self-improvement pattern
├── examples/
│   ├── README.md
│   ├── confidence-scoring.md
│   └── sample-report.md
└── README.md                  # Этот файл
```

## Workflow

```
VALIDATE → DISCOVER → DETECT → ANALYZE → MAP → [DATABASE] → CRITIQUE → GENERATE → VERIFY → REPORT
```

### Phase 1: VALIDATE
- Проверка входных данных
- Определение режима (CREATE/AUGMENT/UPDATE)
- Git analysis для UPDATE режима

### Phase 1.5: DISCOVER (NEW v3.0)
- Обнаружение монореп и multi-module проектов
- Классификация модулей (service/library/app/tool)
- Определение inter-module зависимостей
- Выбор стратегии анализа (single/per-module/per-module-with-shared-context)

### Phase 2: DETECT
- Определение языка программирования
- Детекция фреймворков (manifest → AST → grep fallback)
- Анализ build tools и тестовой инфраструктуры
- Проверка доступности ast-grep

### Phase 3: ANALYZE
- Определение архитектурного паттерна (с AST evidence)
- Анализ слоёв и зависимостей
- Обнаружение конвенций (errors, logging, testing)
- Детекция dependency violations через import analysis

### Phase 4: MAP
- Построение карты entry points
- Анализ core domain (entities, interfaces, implementations)
- **Dependency graph** с метриками fan-in/fan-out
- External integrations

### Phase 5: DATABASE (опционально)
- PostgreSQL schema analysis через MCP
- Entity-table mapping

### Phase 6: CRITIQUE (blocking gate)
- Self-review перед генерацией
- Проверка completeness, accuracy, quality
- Plan adjustments

### Phase 7: GENERATE
- Генерация CLAUDE.md
- Создание skills и rules
- PROJECT-KNOWLEDGE.md
- memory.json для MCP

### Phase 8: VERIFY (blocking gate)
- External validation (YAML, references, size)
- State contract validation
- Quality checks

### Phase 9: REPORT
- Итоговый отчёт с dependency topology
- Рекомендации
- Confidence scoring

## Поддерживаемые технологии

| Язык | Фреймворки |
|------|------------|
| Go | gin, echo, chi, fiber, stdlib |
| Python | django, flask, fastapi |
| TypeScript | nestjs, express, next, nuxt |
| Rust | actix-web, axum, rocket |
| Java | spring-boot, quarkus, micronaut |

## Ключевые deps

| Файл | Назначение |
|------|-----------|
| `deps/ast-analysis.md` | AST-grep паттерны для каждого языка |
| `deps/state-contract.md` | Typed state schema между фазами |
| `deps/edge-cases.md` | Ограничения и edge cases |
| `deps/step-quality.md` | Per-phase quality checks |
| `deps/reflexion.md` | Self-improvement pattern |

## Артефакты

| Артефакт | Назначение |
|----------|------------|
| `.claude/CLAUDE.md` | Главный файл (≤200 строк) |
| `.claude/PROJECT-KNOWLEDGE.md` | Полное исследование + dependency topology |
| `.claude/memory.json` | MCP persistent context |
| `.claude/skills/` | Навыки по паттернам |
| `.claude/rules/` | Path-triggered правила |

## Связанные ресурсы

- `meta-agent` — аудит/улучшение артефактов
