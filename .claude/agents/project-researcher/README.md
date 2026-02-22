# Project Researcher Agent

Автономный агент для глубокого исследования проектов и генерации `.claude/` конфигурации.

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
├── AGENT.md                 # Orchestrator (точка входа)
├── phases/
│   ├── 1-validate.md       # VALIDATE + AUDIT + GIT ANALYSIS
│   ├── 2-detect.md         # DETECT (tech stack)
│   ├── 3-analyze.md        # ANALYZE (architecture)
│   ├── 4-map.md            # MAP + DATABASE
│   ├── 5-generate.md       # GENERATE (artifacts)
│   ├── 6-report.md         # REPORT
│   ├── 7-critique.md       # CRITIQUE (self-review) [NEW v2.0]
│   └── 8-verify.md         # VERIFY (external validation) [NEW v2.0]
├── templates/
│   └── project-knowledge.md # Шаблон PROJECT-KNOWLEDGE.md
├── reference/
│   ├── language-patterns.md # Паттерны детекции языков
│   └── scoring.md          # Система confidence scoring
├── examples/                # Sample outputs [NEW v2.0]
│   └── (to be added)
└── README.md               # Этот файл
```

## Workflow

```
VALIDATE → DETECT → ANALYZE → MAP → [DATABASE] → CRITIQUE → GENERATE → VERIFY → REPORT
```

### Phase 1: VALIDATE
- Проверка входных данных
- Определение режима (CREATE/AUGMENT/UPDATE)
- Git analysis для UPDATE режима

### Phase 2: DETECT
- Определение языка программирования
- Детекция фреймворков
- Анализ build tools и тестовой инфраструктуры

### Phase 3: ANALYZE
- Определение архитектурного паттерна
- Анализ слоёв и зависимостей
- Обнаружение конвенций

### Phase 4: MAP
- Построение карты entry points
- Анализ core domain
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
- Quality checks
- Gate: EXTERNAL_VALIDATION_GATE

### Phase 9: REPORT
- Итоговый отчёт
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

## MCP интеграция

- **Memory**: Сохранение архитектурных решений
- **PostgreSQL**: Анализ схемы БД
- **Sequential Thinking**: Сложные архитектурные решения

## Артефакты

| Артефакт | Назначение |
|----------|------------|
| `.claude/CLAUDE.md` | Главный файл (≤200 строк) |
| `.claude/PROJECT-KNOWLEDGE.md` | Полное исследование |
| `.claude/memory.json` | MCP persistent context |
| `.claude/skills/` | Навыки по паттернам |
| `.claude/rules/` | Path-triggered правила |

## Связанные ресурсы

- `meta-agent` — аудит/улучшение артефактов
