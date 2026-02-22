# PHASE 2: DETECT

**Goal:** Определить технологический стек проекта.

**Required state:** `state.validate.path`, `state.discover.analysis_targets`

**Outputs:** `state.detect`

---

## 2.0 AST Availability Check

Первым шагом проверить доступность ast-grep — это определит метод анализа для всей фазы.

```bash
if command -v ast-grep &>/dev/null || command -v sg &>/dev/null; then
    AST_AVAILABLE=true
    AST_CMD=$(command -v ast-grep || command -v sg)
else
    AST_AVAILABLE=false
    # Попытка установки (опционально)
    npm install -g @ast-grep/cli 2>/dev/null && AST_AVAILABLE=true && AST_CMD="ast-grep"
fi
```

**SEE:** `deps/ast-analysis.md` для полного каталога AST-паттернов.

---

## 2.1 Language Detection

| File/Pattern | Language | Confidence |
|--------------|----------|------------|
| `*.go`, `go.mod` | Go | HIGH |
| `*.py`, `pyproject.toml`, `requirements.txt` | Python | HIGH |
| `*.ts`, `tsconfig.json` | TypeScript | HIGH |
| `*.js`, `package.json` (no ts) | JavaScript | HIGH |
| `*.rs`, `Cargo.toml` | Rust | HIGH |
| `*.java`, `pom.xml`, `build.gradle` | Java | HIGH |
| `*.rb`, `Gemfile` | Ruby | HIGH |
| `*.php`, `composer.json` | PHP | HIGH |
| `*.cs`, `*.csproj` | C# | HIGH |
| `*.kt`, `build.gradle.kts` | Kotlin | HIGH |

**Detection algorithm:**
```bash
# Count files by extension (exclude vendor/node_modules/.git/generated)
for ext in go py ts js rs java rb php cs kt; do
    count=$(find . -type f -name "*.$ext" \
        -not -path "*/vendor/*" \
        -not -path "*/node_modules/*" \
        -not -path "*/.git/*" \
        -not -path "*/generated/*" \
        -not -path "*/_build/*" | wc -l)
    echo "$ext: $count"
done

# Check config files (manifest detection)
[ -f "go.mod" ] && echo "Go module detected"
[ -f "package.json" ] && echo "Node.js detected"
[ -f "Cargo.toml" ] && echo "Rust detected"
# ... etc

# Primary = язык с наибольшим количеством файлов
# Confidence = файлов_primary / файлов_total
```

**Note:** При `state.discover.is_monorepo == true` выполнять для каждого `analysis_target` отдельно.

---

## 2.2 Framework Detection

### Strategy: manifest-first, AST-second, grep-fallback

**Tier 1 — Manifest (highest confidence):**
```bash
# Go: parse go.mod
grep "gin-gonic/gin" go.mod 2>/dev/null && echo "gin"
grep "labstack/echo" go.mod 2>/dev/null && echo "echo"
grep "go-chi/chi" go.mod 2>/dev/null && echo "chi"
grep "gofiber/fiber" go.mod 2>/dev/null && echo "fiber"
grep "gorm.io/gorm" go.mod 2>/dev/null && echo "gorm"
grep "jmoiron/sqlx" go.mod 2>/dev/null && echo "sqlx"
grep "jackc/pgx" go.mod 2>/dev/null && echo "pgx"
grep "sqlc" go.mod 2>/dev/null && echo "sqlc"
grep "entgo.io/ent" go.mod 2>/dev/null && echo "ent"

# Python: parse requirements.txt / pyproject.toml
grep -E "django|flask|fastapi" requirements.txt pyproject.toml 2>/dev/null

# TypeScript: parse package.json
grep -E "@nestjs|express|next|nuxt" package.json 2>/dev/null

# Rust: parse Cargo.toml
grep -E "actix-web|axum|rocket|warp" Cargo.toml 2>/dev/null

# Java: parse pom.xml / build.gradle
grep -E "spring-boot|quarkus|micronaut" pom.xml build.gradle 2>/dev/null
```

**Tier 2 — AST (if available, confirms actual usage):**
```bash
# Подтвердить реальное использование фреймворка в коде (не просто зависимость)
# Go: Chi router setup
ast-grep --pattern 'chi.NewRouter()' --lang go
ast-grep --pattern 'r.Get($$$)' --lang go
ast-grep --pattern 'r.Post($$$)' --lang go

# Go: Gin engine
ast-grep --pattern 'gin.Default()' --lang go
ast-grep --pattern 'gin.New()' --lang go

# Go: pgx pool
ast-grep --pattern 'pgxpool.New($$$)' --lang go
ast-grep --pattern 'pgx.Connect($$$)' --lang go
```

**Tier 3 — grep fallback (lowest confidence):**
```bash
# Только если manifest и AST не дали результата
grep -r "gin\." --include="*.go" -l | head -5
grep -r "echo\." --include="*.go" -l | head -5
```

**Version extraction:**
```bash
# Go: extract version from go.mod
grep "go-chi/chi" go.mod | awk '{print $2}'  # → v5.1.0

# Node: extract from package.json
grep -A1 '"express"' package.json | grep -o '"[0-9].*"'
```

**State output per framework:**
```yaml
frameworks:
  - name: "chi"
    version: "v5.1.0"
    category: "http"
    confidence: 0.95
    detection_method: "manifest"  # or "ast" or "grep"
```

---

## 2.3 Build Tools Detection

| Tool | Indicators |
|------|------------|
| Make | `Makefile` |
| Docker | `Dockerfile`, `docker-compose.yml`, `compose.yml` |
| CI/CD | `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile` |
| Linters | `.golangci.yml`, `.eslintrc`, `.flake8`, `rustfmt.toml`, `biome.json` |
| Formatters | `gofmt`, `prettier`, `black`, `rustfmt` |
| Task runners | `Taskfile.yml`, `justfile` |

```bash
# Check all build tool indicators
[ -f "Makefile" ] && build_tools+=("make")
[ -f "Dockerfile" ] || [ -f "docker-compose.yml" ] || [ -f "compose.yml" ] && build_tools+=("docker")
[ -d ".github/workflows" ] && build_tools+=("github-actions")
[ -f ".gitlab-ci.yml" ] && build_tools+=("gitlab-ci")
[ -f "Jenkinsfile" ] && build_tools+=("jenkins")
[ -f ".golangci.yml" ] && linters+=("golangci-lint")
[ -f ".eslintrc" ] || [ -f ".eslintrc.json" ] || [ -f ".eslintrc.js" ] && linters+=("eslint")
[ -f "biome.json" ] && linters+=("biome")
[ -f "Taskfile.yml" ] && build_tools+=("task")
[ -f "justfile" ] && build_tools+=("just")
```

---

## 2.4 Testing Detection

### Manifest + AST approach:

```bash
# Go: test dependencies from manifest
grep "testify" go.mod 2>/dev/null && test_framework="testify"
grep "gomock" go.mod 2>/dev/null && mock_tool="gomock"
grep "mockery" go.mod 2>/dev/null && mock_tool="mockery"

# AST: deeper test pattern analysis (if available)
if $AST_AVAILABLE; then
    # Table-driven test count
    table_driven=$(ast-grep --pattern 'tests := []struct { $$$ }{ $$$ }' --lang go | wc -l)
    table_driven=$((table_driven + $(ast-grep --pattern 'tt := []struct { $$$ }{ $$$ }' --lang go | wc -l)))
    table_driven=$((table_driven + $(ast-grep --pattern 'cases := []struct { $$$ }{ $$$ }' --lang go | wc -l)))

    # Testify require/assert usage
    require_count=$(ast-grep --pattern 'require.$METHOD($$$)' --lang go | wc -l)
    assert_count=$(ast-grep --pattern 'assert.$METHOD($$$)' --lang go | wc -l)
else
    # Grep fallback
    table_driven=$(grep -r "tests := \[\]struct" --include="*_test.go" 2>/dev/null | wc -l)
    require_count=$(grep -r "require\." --include="*_test.go" 2>/dev/null | wc -l)
    assert_count=$(grep -r "assert\." --include="*_test.go" 2>/dev/null | wc -l)
fi

# Count test files
test_file_count=$(find . -name "*_test.go" -not -path "*/vendor/*" | wc -l)

# Mock files
mock_count=$(find . -name "*mock*.go" -not -path "*/vendor/*" | wc -l)
```

| Language | Test Indicators |
|----------|-----------------|
| Go | `*_test.go`, `testify`, `gomock`, `mockgen`, `mockery` |
| Python | `pytest`, `unittest`, `test_*.py` |
| TypeScript | `jest`, `vitest`, `mocha`, `*.spec.ts`, `*.test.ts` |
| Rust | `#[test]`, `#[cfg(test)]` |
| Java | `junit`, `mockito`, `*Test.java` |

---

## State Output → `state.detect`

```yaml
detect:
  primary_language: "go"
  primary_confidence: 0.92
  secondary_languages:
    - language: "typescript"
      file_count: 15
      role: "frontend"
  frameworks:
    - name: "chi"
      version: "v5.1.0"
      category: "http"
      confidence: 0.95
      detection_method: "manifest"
    - name: "pgx"
      version: "v5.5.0"
      category: "orm"
      confidence: 0.95
      detection_method: "manifest"
  build_tools:
    - name: "make"
      config_file: "Makefile"
    - name: "docker"
      config_file: "Dockerfile"
    - name: "github-actions"
      config_file: ".github/workflows/"
  test_framework: "testify"
  test_patterns:
    table_driven_count: 45
    mock_count: 12
    test_file_count: 87
  linters: ["golangci-lint"]
  ast_available: true
```

## Output

```
[PHASE 2/10] DETECT — DONE
State: detect.primary_language=go (0.92), frameworks=[chi@v5, pgx@v5], ast=true
- Build: make, docker, github-actions
- Testing: testify (45 table-driven, 12 mocks, 87 test files)
- Linters: golangci-lint
```

**SEE:** `reference/language-patterns.md` для language-specific детекции
