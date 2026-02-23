# Language-Specific Detection Patterns

Reference guide for language and framework detection.

---

## Language Detection

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
# Count files by extension
find . -type f -name "*.go" | wc -l
find . -type f -name "*.py" | wc -l
# ... etc

# Check config files
[ -f "go.mod" ] && echo "Go module detected"
[ -f "package.json" ] && echo "Node.js detected"
# ... etc
```

---

## Go

### Framework Detection

| Framework | go.mod Pattern |
|-----------|---------------|
| Gin | `github.com/gin-gonic/gin` |
| Echo | `github.com/labstack/echo` |
| Fiber | `github.com/gofiber/fiber` |
| Chi | `github.com/go-chi/chi` |
| Gorilla Mux | `github.com/gorilla/mux` |
| stdlib | `net/http` only |

### ORM/Database Detection

| Library | go.mod Pattern |
|---------|---------------|
| GORM | `gorm.io/gorm` |
| sqlx | `github.com/jmoiron/sqlx` |
| pgx | `github.com/jackc/pgx` |
| sqlc | `github.com/kyleconroy/sqlc` |
| ent | `entgo.io/ent` |

### Testing Detection

```bash
# Table-driven tests
grep -r "tests := \[\]struct" --include="*_test.go" | wc -l

# Testify usage
grep -r "require\." --include="*_test.go" | wc -l
grep -r "assert\." --include="*_test.go" | wc -l

# Mocks
find . -name "*mock*.go" | wc -l
grep -r "mockery" go.mod 2>/dev/null
grep -r "gomock" go.mod 2>/dev/null
```

### Analysis Commands

```bash
# Module info
cat go.mod | head -5

# Dependencies
grep -E "^\t" go.mod | wc -l

# Internal structure
ls -la internal/ 2>/dev/null

# Compile-time interface checks
grep -r "var _ .* = (\*" --include="*.go" | wc -l
```

---

## Python

### Framework Detection

| Framework | Indicators |
|-----------|------------|
| Django | `django` in deps, `manage.py`, `settings.py` |
| Flask | `flask` in deps, `app.py` |
| FastAPI | `fastapi` in deps, `main.py` with async |
| aiohttp | `aiohttp` in deps |

### Package Manager Detection

```bash
[ -f "pyproject.toml" ] && echo "Poetry/PDM"
[ -f "requirements.txt" ] && echo "pip"
[ -f "Pipfile" ] && echo "pipenv"
[ -f "setup.py" ] && echo "setuptools"
```

### Testing Detection

```bash
# pytest
grep -r "pytest" requirements.txt pyproject.toml 2>/dev/null

# unittest
grep -r "unittest" --include="*.py" | wc -l

# Test files
find . -name "test_*.py" | wc -l
```

### Analysis Commands

```bash
# Framework
grep -E "django|flask|fastapi" requirements.txt pyproject.toml 2>/dev/null

# Type hints
grep -r "def .*:.*->" --include="*.py" | wc -l

# Async usage
grep -r "async def" --include="*.py" | wc -l
```

---

## TypeScript / JavaScript

### Framework Detection

| Framework | package.json Pattern |
|-----------|---------------------|
| React | `react`, `react-dom` |
| Vue | `vue` |
| Angular | `@angular/core` |
| NestJS | `@nestjs/core` |
| Express | `express` |
| Next.js | `next` |
| Nuxt | `nuxt` |

### Package Manager Detection

```bash
[ -f "pnpm-lock.yaml" ] && echo "pnpm"
[ -f "yarn.lock" ] && echo "yarn"
[ -f "package-lock.json" ] && echo "npm"
[ -f "bun.lockb" ] && echo "bun"
```

### Testing Detection

```bash
# Jest
grep -E "jest" package.json

# Vitest
grep -E "vitest" package.json

# Mocha
grep -E "mocha" package.json

# Test files
find . -name "*.spec.ts" -o -name "*.test.ts" | wc -l
```

### Analysis Commands

```bash
# Framework
grep -E "react|vue|angular|nest" package.json

# Strict mode
grep "strict" tsconfig.json

# Module system
grep "type.*module" package.json
```

---

## Rust

### Framework Detection

| Framework | Cargo.toml Pattern |
|-----------|-------------------|
| Actix Web | `actix-web` |
| Axum | `axum` |
| Rocket | `rocket` |
| Warp | `warp` |
| Hyper | `hyper` |

### Analysis Commands

```bash
# Workspace
grep "workspace" Cargo.toml

# Features
grep -A 10 "\[features\]" Cargo.toml

# Dependencies
grep -E "^\w+ = " Cargo.toml | wc -l

# Edition
grep "edition" Cargo.toml
```

### Testing Detection

```bash
# Test modules
grep -r "#\[test\]" --include="*.rs" | wc -l

# Integration tests
ls -la tests/ 2>/dev/null

# Test config
grep -r "#\[cfg(test)\]" --include="*.rs" | wc -l
```

---

## Java

### Build Tool Detection

```bash
[ -f "pom.xml" ] && echo "Maven"
[ -f "build.gradle" ] && echo "Gradle"
[ -f "build.gradle.kts" ] && echo "Gradle Kotlin DSL"
```

### Framework Detection

| Framework | Indicators |
|-----------|------------|
| Spring Boot | `spring-boot-starter-*` |
| Quarkus | `quarkus-*` |
| Micronaut | `io.micronaut` |
| Jakarta EE | `jakarta.*` |

### Analysis Commands

```bash
# Framework
grep -E "spring-boot|quarkus|micronaut" pom.xml build.gradle 2>/dev/null

# Java version
grep -E "java.version|sourceCompatibility" pom.xml build.gradle 2>/dev/null

# Main class
find . -name "*.java" -exec grep -l "public static void main" {} \;
```

---

## Build Tools Detection (Universal)

| Tool | Indicators |
|------|------------|
| Make | `Makefile` |
| Docker | `Dockerfile`, `docker-compose.yml` |
| CI/CD | `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile` |
| Linters | `.golangci.yml`, `.eslintrc`, `.flake8`, `rustfmt.toml` |
| Formatters | `gofmt`, `prettier`, `black`, `rustfmt` |

---

## Common Patterns

### Error Handling Detection

```bash
# Go: Error wrapping
grep -r 'fmt.Errorf.*%w' --include="*.go" | wc -l

# Go: Custom errors
grep -r 'errors.New' --include="*.go" | wc -l

# Go: Error types
grep -r 'type.*Error struct' --include="*.go"
```

### Logging Detection

```bash
# Go: slog
grep -r 'slog\.' --include="*.go" | wc -l

# Go: logrus
grep -r 'logrus\.' --include="*.go" | wc -l

# Go: zap
grep -r 'zap\.' --include="*.go" | wc -l

# Python: logging
grep -r 'logging\.' --include="*.py" | wc -l

# JavaScript: winston
grep -E "winston" package.json
```
