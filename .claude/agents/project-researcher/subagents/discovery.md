# SUBAGENT: DISCOVERY

**Model:** haiku
**Phases:** VALIDATE + DISCOVER
**Input:** project_path, config (dry_run, mode override)
**Output:** state.validate + state.discover

---

## PHASE 1: VALIDATE

The VALIDATE phase establishes the project baseline and determines operational mode.

### 1.1 Directory Structure Check

Verify the project path exists and is accessible:

```bash
[ -d "$PROJECT_PATH" ] || exit 1
```

**Action:** Check that `$PROJECT_PATH` is a valid directory. If not, emit FATAL error: "Project path does not exist or is not accessible: {PROJECT_PATH}"

### 1.2 Source File Detection

Scan for source files to confirm this is a software project:

```bash
find "$PROJECT_PATH" -type f \
  \( -name "*.go" -o -name "*.py" -o -name "*.ts" -o -name "*.tsx" \
     -o -name "*.js" -o -name "*.jsx" -o -name "*.rs" -o -name "*.java" \
     -o -name "*.cpp" -o -name "*.c" -o -name "*.rb" -o -name "*.php" \) \
  ! -path "*/vendor/*" ! -path "*/node_modules/*" ! -path "*/.git/*" \
  | wc -l
```

**Action:** Count source files by extension. Store:
- `source_file_count`: total files found
- `extension_distribution`: {ext: count} for each language

**Quality Check:** Must have `source_file_count ≥ 1`. If zero, emit FATAL: "No source files detected in supported languages."

### 1.3 Git Repository Check

Determine if the project is version-controlled:

```bash
[ -d "$PROJECT_PATH/.git" ] && GIT_AVAILABLE=true || GIT_AVAILABLE=false
```

**Action:** Record:
- `is_git_repo`: boolean
- If true: run `git rev-parse --show-toplevel` to get git root
- If true: run `git config --get remote.origin.url` to get remote (or null if none)
- If true: run `git rev-list --count HEAD` to get commit count

### 1.4 Claude Directory Audit

Check for existing Claude project artifacts:

```bash
[ -d "$PROJECT_PATH/.claude" ] && CLAUDE_DIR_EXISTS=true || CLAUDE_DIR_EXISTS=false
```

**Action:** If directory exists:
- List all `.md` files in `.claude/` directory
- List all subdirectories (skills/, rules/, commands/)
- Record artifact inventory for audit trail

**Store:**
- `has_claude_dir`: boolean
- `claude_artifacts`: {files: [...], dirs: [...]}

### 1.5 Mode Detection

Determine the operational mode based on project state:

**Decision Tree:**

1. **CREATE mode**: `.claude/` directory does NOT exist
   - Action: Set `mode = "CREATE"`
   - Rationale: Greenfield project, full analysis needed

2. **UPDATE mode**: Both conditions must be true:
   - `.claude/` directory EXISTS
   - `.git` repository EXISTS
   - `PROJECT-KNOWLEDGE.md` exists in `.claude/`
   - Action: Set `mode = "UPDATE"`
   - Rationale: Existing Claude project, incremental refresh

3. **AUGMENT mode**: All other cases
   - Action: Set `mode = "AUGMENT"`
   - Rationale: Partial existing artifacts, merge new findings

**Store:** `mode: "CREATE" | "UPDATE" | "AUGMENT"`

### 1.6 Conditional Git Analysis (UPDATE mode only)

If mode is UPDATE:

```bash
git log --oneline -n 1 --format="%H %aI" # latest commit hash and timestamp
git diff --name-only HEAD~50..HEAD | sort -u # changed files in last 50 commits
git diff --stat HEAD~50..HEAD # statistics
```

**Action:**
- `since_commit`: hash of commit from 50 revisions ago (or oldest if repo < 50 commits)
- `recent_files`: list of files changed since that commit
- `changed_layers`: infer from paths (cmd/, pkg/, internal/, services/, etc.)

**Store:** `git_context: {since_commit, recent_files, changed_layers}`

### 1.7 Conditional Artifact Audit (AUGMENT mode only)

If mode is AUGMENT and `.claude/` exists:

```bash
ls -la "$PROJECT_PATH/.claude/" | grep -E "^-" # files
ls -d "$PROJECT_PATH/.claude"/*/ 2>/dev/null # subdirectories
```

**Action:**
- List each skill (from skills/ subdirectory)
- List each rule (from rules/ subdirectory)
- List each command (from commands/ subdirectory)
- Check for stale artifacts (modified timestamp >90 days ago)

**Store:** `existing_artifacts: {skills: [...], rules: [...], commands: [...], stale_count: N}`

### 1.8 VALIDATE Phase Quality Checklist

Verify all success criteria before proceeding:

- ✓ Project path exists and is readable
- ✓ At least one source file detected
- ✓ Mode determined (CREATE/UPDATE/AUGMENT)
- ✓ If UPDATE: git context extracted
- ✓ If AUGMENT: artifact inventory completed

**Emit:** FATAL error if any check fails. Otherwise, proceed to DISCOVER.

---

## PHASE 1.5: DISCOVER

The DISCOVER phase maps the project structure and determines analysis strategy.

### 2.1 Manifest File Scanning

Identify all manifest files that declare project structure and dependencies:

```bash
find "$PROJECT_PATH" -maxdepth 3 \
  -type f \( -name "go.mod" -o -name "package.json" -o -name "Cargo.toml" \
             -o -name "pom.xml" -o -name "pyproject.toml" -o -name "requirements.txt" \
             -o -name "build.gradle" -o -name "Gemfile" \) \
  ! -path "*/vendor/*" ! -path "*/node_modules/*" ! -path "*/.git/*"
```

**Action:** For each manifest found:
- Store absolute path
- Identify language from manifest type (go.mod→Go, package.json→JavaScript, etc.)
- Extract version info (if applicable)
- Parse for direct/indirect dependencies

**Store:** `manifests: [{path, language, type, version_info: {...}}]`

### 2.2 Module Classification

Classify each manifest as representing a module and infer its type:

**Language Inference:**
- `go.mod` → language: Go
- `package.json` → language: JavaScript/TypeScript
- `Cargo.toml` → language: Rust
- `pom.xml` → language: Java
- `pyproject.toml` → language: Python

**Module Type Inference (from directory path):**
- `/services/{name}/` → type: service
- `/pkg/{name}/` or `/packages/{name}/` → type: library
- `/internal/{name}/` → type: internal_library
- `/cmd/{name}/` → type: command_line_tool
- root (`./{manifest}`) → type: root_module
- `/tools/` → type: tool
- Default → type: library

**Store per module:** `{language, type, path, manifest_file}`

### 2.3 Inter-Module Dependency Detection

Detect dependencies between modules within the project (focusing on Go projects):

**For Go projects:**
1. Extract the root module name from root `go.mod` (line 1: `module {name}`)
2. For each non-root `go.mod`, parse `require` statements
3. Identify which requires reference the root module name (indicating internal dependencies)
4. Build dependency graph: `{module_path: [dependent_modules]}`

**For other languages:**
- JavaScript/Node: parse `package.json` for local workspace references (via `"@scope/*"` or `"./packages/*"`)
- Python: parse `pyproject.toml` for `path = "..."` dependencies
- Store as: `{module_path: [dependent_modules]}`

**Store:** `internal_dependencies: {module_path: [list_of_dependent_modules]}`

### 2.4 Root Module Detection

Identify the primary/root module of the project:

**Decision Logic (in order):**
1. If module contains `main.go` → it is the root module
2. If exactly one module at project root → it is the root module
3. If multiple modules, calculate "fan-out": count how many other modules depend on each
4. Module with highest fan-out → it is the root module
5. If tie: alphabetically first wins

**Store:** `root_module: {path, language, type}`

### 2.5 Monorepo Detection

Determine if the project is a monorepo or single-module:

**Monorepo conditions (ANY of the following):**
- More than 1 manifest file found
- More than 3 entries in `cmd/` directory (multi-command project)
- More than 1 entry in `services/` directory (multi-service project)

**Store:** `is_monorepo: boolean`

### 2.6 Analysis Strategy Selection

Choose the analysis strategy based on project structure:

**Decision Logic:**

1. **single** strategy
   - Condition: NOT monorepo AND only 1 manifest
   - Approach: Single analysis pass over entire project
   - Rationale: Simple, linear project structure

2. **per-module-with-shared-context** strategy
   - Condition: monorepo AND all modules same language AND ≤5 modules
   - Approach: Analyze each module separately, maintain shared context (shared patterns, reused components)
   - Rationale: Consistent codebase, manageable scope, leverage shared knowledge

3. **per-module** strategy
   - Condition: monorepo AND (different languages OR >5 modules)
   - Approach: Analyze each module independently, minimal cross-module context
   - Rationale: Language-specific tools required, too large for shared context memory

**Store:**
- `strategy: "single" | "per-module-with-shared-context" | "per-module"`
- Rationale as comment

### 2.7 Analysis Targets Selection

Define the modules/targets to analyze based on strategy:

**For "single" strategy:**
- `analysis_targets: ["."]` (analyze project root)

**For "per-module-with-shared-context" strategy:**
- `analysis_targets: [{path: module.path, language: module.language, type: module.type} for each module]`
- Include root module first in list

**For "per-module" strategy:**
- `analysis_targets: [{path: module.path, language: module.language, type: module.type} for each module]`
- Include root module first in list
- Add note: "Analyze sequentially, minimal shared context"

**Store:** `analysis_targets: [...]`

### 2.8 DISCOVER Phase Quality Checklist

Verify all success criteria before proceeding:

- ✓ At least one manifest scanned
- ✓ Each manifest classified (language, type, path)
- ✓ Monorepo status determined
- ✓ Root module identified
- ✓ Inter-module dependencies mapped (if applicable)
- ✓ Strategy selected with rationale
- ✓ Analysis targets populated (non-empty list)

---

## OUTPUT FORMAT

Upon successful completion of both VALIDATE and DISCOVER phases, emit:

```yaml
subagent_result:
  status: "success"
  state_updates:
    validate:
      path: "{PROJECT_PATH}"
      mode: "CREATE|UPDATE|AUGMENT"
      is_git_repo: boolean
      git_root: "path/to/.git or null"
      git_remote: "https://... or null"
      commit_count: number
      source_file_count: number
      extension_distribution:
        ".go": count
        ".ts": count
        ...
      has_claude_dir: boolean
      claude_artifacts:
        files: [...]
        dirs: [...]
      git_context:
        since_commit: "hash (UPDATE mode only)"
        recent_files: [...] (UPDATE mode only)
        changed_layers: [...] (UPDATE mode only)
      existing_artifacts:
        skills: [...] (AUGMENT mode only)
        rules: [...] (AUGMENT mode only)
        commands: [...] (AUGMENT mode only)
        stale_count: number (AUGMENT mode only)
    discover:
      manifests:
        - path: "absolute/path/to/manifest"
          type: "go.mod|package.json|Cargo.toml|..."
          language: "Go|JavaScript|Rust|..."
          version_info: {...}
      modules:
        - path: "."
          language: "Go"
          type: "root_module"
          manifest_file: "./go.mod"
        - path: "./pkg/database"
          language: "Go"
          type: "library"
          manifest_file: "./pkg/database/go.mod (or inherited)"
      is_monorepo: boolean
      internal_dependencies:
        ".": ["./pkg/database", "./pkg/cache"]
        "./pkg/database": []
      root_module:
        path: "."
        language: "Go"
        type: "root_module"
      strategy: "single|per-module-with-shared-context|per-module"
      strategy_rationale: "explanation of choice"
      analysis_targets:
        - path: "."
          language: "Go"
          type: "root_module"
        - path: "./pkg/database"
          language: "Go"
          type: "library"
  progress_summary: "validate.mode=CREATE, discover.strategy=per-module-with-shared-context, targets=[., ./pkg/database, ./pkg/cache]"
```

---

## EXECUTION CONTEXT

- **Working Directory:** Project root (PROJECT_PATH)
- **Tools Available:** Bash (for file scanning, git operations), standard utilities (find, wc, grep, ls)
- **Error Handling:** Emit FATAL on validation failure; emit SUCCESS on completion
- **Dry Run:** If `dry_run=true`, emit state updates without modifying .claude/ directory
