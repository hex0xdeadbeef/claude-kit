# SUBAGENT: DETECTION

**Model:** sonnet
**Phases:** DETECT
**Input:** state.validate (path, mode), state.discover (analysis_targets, is_monorepo)
**Output:** state.detect

---

## PHASE 2: DETECT

The DETECT phase analyzes project code to identify languages, frameworks, build tools, and testing infrastructure.

### 2.1 Analysis Method Check (v4.2)

Determine the best available analysis method using a 3-tier fallback chain:

**Tier 1: tree-sitter MCP (preferred)**

Check if tree-sitter MCP server tools are available in the current environment.
If available: `analysis_method = "tree-sitter-mcp"`, register project.

```yaml
# Register project with tree-sitter MCP:
register_project:
  path: "{state.validate.path}"
  name: "{project_name}"
```

**Tier 2: ast-grep CLI (fallback)**

```bash
command -v ast-grep > /dev/null 2>&1 || command -v sg > /dev/null 2>&1
```

If NOT found, attempt auto-install:
```bash
npm install -g @ast-grep/cli 2>/dev/null
```

If available: `analysis_method = "ast-grep"`

**Tier 3: grep (last resort)**

Always available: `analysis_method = "grep"`

**Store:** `analysis_method: "tree-sitter-mcp" | "ast-grep" | "grep"`

**SEE:** `deps/tree-sitter-patterns.md` for query patterns per method.

---

### 2.2 Language Detection

Identify primary programming language(s) in the project:

**Step 1: File Count Analysis**

For each analysis target, scan for source files:

```bash
find {TARGET} -type f \
  \( -name "*.go" -o -name "*.py" -o -name "*.ts" -o -name "*.tsx" \
     -o -name "*.js" -o -name "*.jsx" -o -name "*.rs" -o -name "*.java" \
     -o -name "*.cpp" -o -name "*.c" -o -name "*.rb" -o -name "*.php" \
     -o -name "*.scala" -o -name "*.kt" -o -name "*.swift" \) \
  ! -path "*/vendor/*" ! -path "*/node_modules/*" ! -path "*/.git/*" \
  ! -path "*/build/*" ! -path "*/dist/*" ! -path "*/generated/*" \
  | sort | uniq -c | sort -rn
```

**Action:**
- Count files by extension
- Calculate totals: `primary_files` (extension with most files), `total_files` (all files)
- Store: `language_counts: {".go": N, ".py": M, ...}`

**Step 2: Confidence Calculation**

```
confidence = primary_files / total_files
```

**Action:**
- If `confidence ≥ 0.7` → primary language is definite
- If `confidence ≥ 0.3` → primary language is strong
- If `confidence < 0.3` → multi-language project

**Step 3: Manifest Verification**

Cross-reference with manifest files from DISCOVER phase:
- If manifest exists (go.mod, package.json, etc.), confirm manifest language matches file count
- If mismatch: investigate (e.g., Go project may have few *.go files in root)

**Store per target:**
```yaml
language_detection:
  primary: "Go|JavaScript|Python|..."
  confidence: 0.85
  language_counts:
    ".go": 45
    ".ts": 3
  total_files: 48
  multi_language: false
```

---

### 2.3 Framework Detection (3-Tier Approach)

Detect frameworks and major dependencies used in the project.

#### Tier 1: Manifest Parsing

Parse manifest files for framework imports/dependencies:

**For Go (go.mod):**
```bash
grep "require" {go.mod} | grep -E "(github\.com|golang\.org)" | head -20
```

**For JavaScript (package.json):**
```bash
jq '.dependencies, .devDependencies | keys[]' {package.json}
```

**For Python (pyproject.toml or requirements.txt):**
```bash
grep -E "^[a-zA-Z0-9_-]+" {pyproject.toml|requirements.txt}
```

**For Rust (Cargo.toml):**
```bash
grep "\[dependencies\]" -A 50 {Cargo.toml}
```

**Action:**
- Parse each manifest
- Extract dependencies list
- For each known framework pattern, check if present
- Record: `{framework_name, version: "x.y.z or constraint", source: "manifest"}`

**Known Framework Patterns (non-exhaustive):**
- Go: gin, echo, fiber, gorm, sqlc, grpc, protobuf, cobra, urfave/cli
- JavaScript: react, vue, angular, next.js, express, fastify, nestjs, apollo
- Python: django, fastapi, flask, sqlalchemy, pydantic
- Rust: actix, tokio, serde, diesel, sqlx
- Java: spring, hibernate, junit, gradle

---

#### Tier 2: Structural Analysis Confirmation (tree-sitter or ast-grep)

Confirm actual framework usage in code using structural analysis:

**With tree-sitter MCP (preferred):**

```yaml
# Run import query to confirm framework usage:
run_query:
  language: "go"
  query: |
    (import_declaration
      (import_spec_list
        (import_spec
          path: (interpreted_string_literal) @import.path)))
  # Filter results for known framework import paths
```

**With ast-grep (fallback):**

```bash
ast-grep --pattern 'import ( $_ "$_" )' --lang go | grep -E "(gin|echo|gorm)" | head -10
ast-grep --pattern 'import $_ from $_' --lang javascript | grep -E "(react|vue)" | head -10
ast-grep --pattern 'import $_' --lang python | grep -E "(django|fastapi)" | head -10
```

**Action:**
- For each framework from Tier 1, run structural query to confirm usage
- If pattern matches: update confidence and set `detection_method: "manifest + tree-sitter"` (or `"manifest + AST"`)
- If pattern does NOT match: reduce confidence and mark as `detection_method: "manifest only"`
- If structural analysis found framework NOT in manifest: flag as `detection_method: "tree-sitter only"` (unusual case)

**Store per framework:**
```yaml
framework:
  name: "gin"
  version: "v1.9.0"
  detection_method: "manifest + tree-sitter"
  confidence: 0.95
  structural_match_count: 15
```

---

#### Tier 3: Grep Fallback (if AST unavailable or for confirmation)

Use grep patterns for framework detection:

**Go patterns:**
```bash
grep -r "gin-gonic/gin\|github.com/gin-gonic/gin" {TARGET} --include="*.go" | wc -l
grep -r "gorm.io/gorm" {TARGET} --include="*.go" | wc -l
grep -r "grpc" {TARGET} --include="*.go" | wc -l
```

**JavaScript patterns:**
```bash
grep -r "from ['\"]react['\"]" {TARGET} --include="*.js" --include="*.ts" | wc -l
grep -r "from ['\"]express['\"]" {TARGET} --include="*.js" | wc -l
```

**Python patterns:**
```bash
grep -r "from django\|import django" {TARGET} --include="*.py" | wc -l
grep -r "from fastapi\|import fastapi" {TARGET} --include="*.py" | wc -l
```

**Action:**
- Run grep patterns for each framework
- Count matches (threshold: ≥1 for presence)
- If manifest + grep both found: `detection_method: "manifest + grep"`, `confidence: 0.85`
- If only grep found: `detection_method: "grep only"`, `confidence: 0.70`
- Record: `grep_match_count: N`

---

#### Confidence Modifiers

Apply adjustments based on detection method reliability:

```
baseline_confidence = 1.0  (if manifest only, with version specified)

if detection_method includes "AST":
  confidence_mod = 0.0  (no adjustment, AST is definitive)
elif detection_method includes "manifest" and "grep":
  confidence_mod = 0.00   (both agree, very reliable — no penalty)
elif detection_method == "grep only, single pattern":
  confidence_mod = -0.05  (one grep pattern match)
elif detection_method == "grep only, complex regex":
  confidence_mod = -0.10  (complex regex can have false positives)
elif detection_method == "heuristic (dir name)":
  confidence_mod = -0.15  (directory naming alone is weak)

final_confidence = max(0.0, min(1.0, baseline_confidence + confidence_mod))
```

**Store per framework:**
```yaml
frameworks:
  - name: "gin"
    version: "v1.9.0"
    detection_method: "manifest + AST"
    confidence: 0.95
    match_count: 15
  - name: "gorm"
    version: "v1.25.0"
    detection_method: "manifest + grep"
    confidence: 0.85
    match_count: 42
```

---

### 2.4 Build Tools Detection

Identify build systems, CI/CD infrastructure, and development tooling:

**Step 1: Build System Files**

```bash
find {TARGET} -maxdepth 2 \
  \( -name "Makefile" -o -name "CMakeLists.txt" -o -name "build.sh" \
     -o -name "Dockerfile" -o -name "docker-compose.yml" \
     -o -name "*.gradle" -o -name "setup.py" \) \
  ! -path "*/vendor/*" ! -path "*/node_modules/*"
```

**Action:** For each found:
- Record presence: `{tool: "Dockerfile", path: "..."}`
- Check for multi-stage builds (Dockerfile): grep `FROM.*AS`
- For docker-compose: count services: `grep "^\s\s[a-z_]:" | wc -l`

**Store:** `build_files: [{name, path, details: {...}}]`

**Step 2: CI/CD Pipelines**

```bash
find {TARGET}/.github/workflows -name "*.yml" -o -name "*.yaml" 2>/dev/null | head -5
find {TARGET}/.gitlab-ci.yml -o {TARGET}/.circleci/config.yml 2>/dev/null
```

**Action:**
- List CI/CD providers found (GitHub Actions, GitLab CI, CircleCI, Jenkins, etc.)
- Count workflow files
- Extract stage names (for GitHub Actions: job names; for GitLab: stage names)

**Store:** `ci_cd: {providers: ["GitHub Actions", ...], pipeline_count: N, stages: [...]}`

**Step 3: Linters and Code Quality Tools**

```bash
find {TARGET} -maxdepth 2 \
  \( -name ".golangci.yml" -o -name ".eslintrc*" -o -name "biome.json" \
     -o -name "pylintrc" -o -name ".flake8" -o -name "pyproject.toml" \) \
  2>/dev/null
```

**Action:**
- Identify linters by config file name
- If manifest declares linting tools (package.json eslint, go.mod golangci-lint): add those

**Store:** `linters: ["golangci-lint", "eslint", ...]`

---

### 2.5 Testing Infrastructure Detection

Identify testing frameworks, test utilities, and testing patterns:

#### Tier 1: Manifest Analysis

**For Go:**
```bash
grep -E "testify|gomock|mockery|testing" {go.mod}
```

**For JavaScript:**
```bash
jq '.devDependencies | keys[]' {package.json} | grep -E "jest|mocha|vitest|chai"
```

**For Python:**
```bash
grep -E "pytest|unittest|nose" {requirements.txt}
```

**Action:**
- Extract testing frameworks: `{framework: "pytest", version: "7.4.0", source: "manifest"}`
- Extract mocking tools: `{tool: "gomock", source: "manifest"}`

**Store:** `test_frameworks: [{name, version, source}]`, `mock_tools: [{name, source}]`

#### Tier 2: AST-Based Pattern Detection (if AST_AVAILABLE)

**Go table-driven tests:**
```bash
ast-grep --pattern 'var $tests = []struct { ... }' --lang go | wc -l
```

**JavaScript/TypeScript describe/it pattern:**
```bash
ast-grep --pattern 'describe($_, function() { ... })' --lang javascript | wc -l
```

**Python unittest pattern:**
```bash
ast-grep --pattern 'class $Test(unittest.TestCase)' --lang python | wc -l
```

**Action:**
- Count pattern matches for each testing style
- Record: `table_driven_tests: N`, `describe_it_tests: M`, etc.

**Store:** `test_patterns: {table_driven: N, describe_it: M, assertion_style: "require|assert|expect"}`

#### Tier 3: Grep Fallback

**Go test files and assertions:**
```bash
find {TARGET} -name "*_test.go" | wc -l
grep -r "t\.Run\|t\.Parallel\|assert\\.Equal\|require\\.Equal" {TARGET} --include="*.go" | wc -l
```

**JavaScript test files:**
```bash
find {TARGET} -name "*.test.ts" -o -name "*.test.js" -o -name "*.spec.ts" | wc -l
grep -r "describe\|it(\|test(" {TARGET} --include="*.test.*" --include="*.spec.*" | wc -l
```

**Python test files:**
```bash
find {TARGET} -path "*/test*" -name "*.py" | wc -l
grep -r "def test_\|class Test" {TARGET} --include="*.py" | wc -l
```

**Action:**
- Count test files: `test_file_count: N`
- Count test assertions/cases: `test_case_count: M`
- Detect assertion library: check for `require.Equal`, `assert.Equal`, `expect()`, etc.

**Store:**
```yaml
testing:
  test_frameworks: ["testing (builtin)", "testify"]
  mock_tools: ["gomock"]
  test_file_count: 24
  test_case_count: 156
  table_driven_tests: 12
  assertion_style: "testify/assert"
  detection_method: "manifest + AST + grep"
```

---

### 2.6 DETECT Phase Quality Checklist

Verify all success criteria before proceeding:

- ✓ Analysis method determined (tree-sitter-mcp / ast-grep / grep)
- ✓ Primary language detected with confidence ≥ 0.3
- ✓ At least 1 framework detected (or empty list `[]` if none found, valid)
- ✓ Build tool(s) identified (at least one of: Makefile, Dockerfile, CI/CD)
- ✓ Testing framework identified (at least one of: test files, test frameworks from manifest)
- ✓ All detection methods recorded (manifest/AST/grep)
- ✓ Confidence scores assigned and justified

**Note:** It is valid to find zero frameworks (pure library with no external dependencies), but must have build tooling.

---

## OUTPUT FORMAT

Upon successful completion of DETECT phase, emit:

```yaml
subagent_result:
  status: "success"
  state_updates:
    detect:
      analysis_method: "tree-sitter-mcp"  # or "ast-grep" or "grep"
      primary_language: "Go"
      primary_confidence: 0.92
      secondary_languages: []             # or [{language: "proto", file_count: 8, role: "grpc"}]
      language_counts:
        ".go": 156
        ".proto": 8
      frameworks:
        - name: "gin"
          version: "v1.9.0"
          category: "http"
          detection_method: "manifest + AST"
          confidence: 0.95
          match_count: 24
        - name: "gorm"
          version: "v1.25.0"
          category: "orm"
          detection_method: "manifest + grep"
          confidence: 0.85
          match_count: 38
      build_tools:
        files:
          - name: "Makefile"
            path: "./Makefile"
            details: { has_docker: true }
          - name: "Dockerfile"
            path: "./Dockerfile"
            details: { multi_stage: true }
        ci_cd:
          providers: ["GitHub Actions"]
          pipeline_count: 3
          stages: ["test", "build", "deploy"]
        linters: ["golangci-lint"]
      testing:
        frameworks: ["testing (builtin)", "testify"]
        mock_tools: ["gomock"]
        test_file_count: 24
        test_case_count: 156
        table_driven_tests: 12
        assertion_style: "testify/assert"
        detection_method: "manifest + AST + grep"
```

---

## EXECUTION CONTEXT

- **Working Directory:** Project root or analysis target
- **Tools Available:** Bash, find, grep, jq (for JSON parsing), ast-grep (if available)
- **Language-Specific Tools:** Can use language-specific commands (go list, npm list, pip freeze) if needed
- **Error Handling:** Non-fatal if a tool is unavailable; fall back to next tier. Emit warnings but continue.
- **Performance:** Limit grep recursion depth to 3 levels; use `--max-count=1` to stop at first match when only presence matters
- **Output:** All confidence scores between 0.0 and 1.0; all counts as integers; all versions as strings

---

## REFERENCE: Framework Detection Patterns

This section documents common AST and grep patterns for framework detection. See `deps/ast-analysis.md` for complete patterns.

### Go Patterns

**Gin Framework:**
```
AST: import statements with "github.com/gin-gonic/gin"
Grep: grep -r "gin\\.Default\|gin\\.New\|\\*gin\\.Engine"
```

**GORM:**
```
AST: import statements with "gorm.io/gorm"
Grep: grep -r "gorm\\.DB\|gorm\\.Open"
```

**gRPC:**
```
AST: import statements with "google.golang.org/grpc"
Grep: grep -r "proto\\.Client\|proto\\.Server"
```

### JavaScript Patterns

**React:**
```
AST: import React from 'react' or JSX syntax
Grep: grep -r "from ['\"]react['\"]" or "React\\.createElement"
```

**Express:**
```
AST: import express from 'express'
Grep: grep -r "from ['\"]express['\"]" or "express\\.Router"
```

### Python Patterns

**FastAPI:**
```
AST: from fastapi import FastAPI
Grep: grep -r "from fastapi\|import fastapi"
```

**Django:**
```
AST: from django imports
Grep: grep -r "from django\\..*import\|django\\.setup"
```
