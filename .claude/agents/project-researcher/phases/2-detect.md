# PHASE 2: DETECT

**Goal:** Определить технологический стек проекта.

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

## 2.2 Framework Detection

| Language | Framework Indicators |
|----------|---------------------|
| Go | `gin-gonic/gin`, `labstack/echo`, `gofiber/fiber`, `go-chi/chi`, `gorilla/mux` |
| Go | `gorm.io/gorm`, `jmoiron/sqlx`, `jackc/pgx` |
| Python | `django`, `flask`, `fastapi`, `aiohttp` |
| TypeScript | `@nestjs`, `express`, `koa`, `next`, `nuxt` |
| Rust | `actix-web`, `axum`, `rocket`, `warp` |
| Java | `spring-boot`, `quarkus`, `micronaut`, `jakarta` |

**Detection:**
```bash
# Go frameworks
grep -r "gin-gonic/gin" go.mod 2>/dev/null && echo "Framework: Gin"
grep -r "labstack/echo" go.mod 2>/dev/null && echo "Framework: Echo"

# Python frameworks
grep -E "django|flask|fastapi" requirements.txt pyproject.toml 2>/dev/null

# TypeScript frameworks
grep -E "@nestjs|express|next" package.json 2>/dev/null
```

---

## 2.3 Build Tools Detection

| Tool | Indicators |
|------|------------|
| Make | `Makefile` |
| Docker | `Dockerfile`, `docker-compose.yml` |
| CI/CD | `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile` |
| Linters | `.golangci.yml`, `.eslintrc`, `.flake8`, `rustfmt.toml` |
| Formatters | `gofmt`, `prettier`, `black`, `rustfmt` |

---

## 2.4 Testing Detection

| Language | Test Indicators |
|----------|-----------------|
| Go | `*_test.go`, `testify`, `gomock`, `mockgen` |
| Python | `pytest`, `unittest`, `test_*.py` |
| TypeScript | `jest`, `vitest`, `mocha`, `*.spec.ts`, `*.test.ts` |
| Rust | `#[test]`, `#[cfg(test)]` |
| Java | `junit`, `mockito`, `*Test.java` |

---

## Output

```
[PHASE 2/6] DETECT -- DONE
- Primary language: Go
- Secondary: TypeScript (frontend)
- Frameworks: {http_framework}, {orm_tool}
- Build: Make, Docker, GitHub Actions
- Testing: {test_framework}, {mock_tool}
- Linters: {linter}
```

**SEE:** `reference/language-patterns.md` для language-specific детекции
