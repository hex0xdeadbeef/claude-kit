# Task: {Feature Name}

## Context

{Краткое описание задачи и её бизнес-ценности}

## Scope

### IN (что реализуем)
- [ ] {Функциональность 1}
- [ ] {Функциональность 2}

### OUT (что НЕ реализуем)
- {Что исключено} — {причина}

## Dependencies

- **Beads Issue:** `beads-XXX` (если создан)
- **Blocks:** {список блокирующих задач}
- **Blocked by:** {список задач, которые блокируют эту}

## Architecture Decision

{Если использовался Sequential Thinking — описать выбранный подход и обоснование}

**Альтернативы:**
1. {Альтернатива 1} — {почему не выбрана}
2. {Альтернатива 2} — {почему не выбрана}

**Выбранный подход:** {подход} — {обоснование}

---

## Part 1: {Name}

**File:** `path/to/file.go` (CREATE/UPDATE)

**Описание:** {что делает этот Part}

```go
// Полный пример кода
package example

func Example() {
    // ...
}
```

---

## Part 2: {Name}

**File:** `path/to/file.go` (CREATE/UPDATE)

**Описание:** {что делает этот Part}

```go
// Полный пример кода
```

---

## Part N: Tests

**File:** `path/to/file_test.go` (CREATE/UPDATE)

**Описание:** Тесты для новой функциональности

```go
func TestExample(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        want    string
        wantErr bool
    }{
        // ...
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // ...
        })
    }
}
```

---

## Files Summary

| File | Action | Description |
|------|--------|-------------|
| `path/to/file1.go` | CREATE | {description} |
| `path/to/file2.go` | UPDATE | {description} |

---

## Acceptance Criteria

### Functional
- [ ] {Критерий 1}
- [ ] {Критерий 2}

### Technical
- [ ] `{build_check_command}` passes
- [ ] `{test_command}` passes
- [ ] Coverage >= 70%
- [ ] No security vulnerabilities

### Architecture
- [ ] Import matrix respected
- [ ] Clean domain (no serialization tags in domain entities)
- [ ] Error handling follows project conventions

---

## Config Changes (если есть)

**config.yaml.example:**
```yaml
new_section:
  param: value  # description
```

**README.md:** Обновить таблицу конфигурации

---

## Notes

{Дополнительные заметки, edge cases, известные ограничения}
