# PHASE 1: VALIDATE & INITIALIZATION

## 1.1 VALIDATE

**Goal:** Проверить что путь валидный и содержит код.

```bash
# 1. Directory exists?
[ -d "$PROJECT_PATH" ] || FATAL "Directory not found: $PROJECT_PATH"

# 2. Has source files?
find "$PROJECT_PATH" -type f \( -name "*.go" -o -name "*.py" -o -name "*.ts" -o -name "*.rs" -o -name "*.java" \) | head -1

# 3. Is git repo?
[ -d "$PROJECT_PATH/.git" ] && GIT_REPO=true || GIT_REPO=false

# 4. Existing .claude/?
[ -d "$PROJECT_PATH/.claude" ] && HAS_CLAUDE=true || HAS_CLAUDE=false
```

**Output:**
```
[PHASE 1/6] VALIDATE -- DONE
- Path: /path/to/project
- Git repo: YES/NO
- Existing .claude/: YES/NO
- Source files: YES
- Mode: CREATE/AUGMENT
```

**FATAL:**
```
FATAL: No source files found in: /path/to/project
```

---

## 1.2 AUDIT (AUGMENT mode only)

**Goal:** Проанализировать существующую конфигурацию.

**Выполняется только если:** `HAS_CLAUDE=true` AND not UPDATE mode

### Audit Steps

```bash
# 1. Read existing artifacts
[ -f ".claude/CLAUDE.md" ] && Read ".claude/CLAUDE.md"
Glob ".claude/skills/**/SKILL.md"
Glob ".claude/rules/**/*.md"
Glob ".claude/commands/**/*.md"

# 2. Inventory
EXISTING_SKILLS=$(ls .claude/skills/ 2>/dev/null | wc -l)
EXISTING_RULES=$(ls .claude/rules/ 2>/dev/null | wc -l)
EXISTING_COMMANDS=$(ls .claude/commands/ 2>/dev/null | wc -l)
```

### Artifact Analysis

Для каждого существующего артефакта:

| Check | Purpose |
|-------|---------|
| File exists | Подтвердить наличие |
| Valid YAML frontmatter | Проверить структуру |
| Has content | Не пустой |
| References valid skills/rules | Ссылки корректны |

### Gap Detection

```bash
# Сравнить обнаруженные паттерны с существующими skills
DETECTED_PATTERNS="arch testing errors logging http"
EXISTING_SKILLS="arch testing"
MISSING_SKILLS="errors logging http"

# Вывести недостающее
echo "Missing skills: $MISSING_SKILLS"
```

**Output:**
```
[PHASE 1.5/6] AUDIT -- DONE (AUGMENT mode)
- Existing artifacts:
  - CLAUDE.md: YES
  - Skills: 2 (arch, testing)
  - Rules: 1 (domain)
  - Commands: 0
- Gaps detected:
  - Skills: errors, logging, http (based on code analysis)
  - Rules: usecase, tests (based on structure)
```

**Skip if CREATE mode:**
```
[PHASE 1.5/6] AUDIT -- SKIPPED (CREATE mode)
```

---

## 1.3 GIT ANALYSIS (UPDATE mode only)

**Goal:** Проанализировать изменения в коде с последнего обновления.

**Выполняется только если:** UPDATE mode (PROJECT-KNOWLEDGE.md exists)

### Read Last Update Timestamp

```bash
# Extract timestamp from PROJECT-KNOWLEDGE.md
LAST_UPDATE=$(grep "^Last Updated:" .claude/PROJECT-KNOWLEDGE.md | cut -d' ' -f3-)

# If no timestamp, use git history for entire project
if [ -z "$LAST_UPDATE" ]; then
    LAST_UPDATE="1970-01-01"
    echo "No previous timestamp, analyzing entire git history"
fi
```

### Analyze Git Commits

```bash
# Get commits since last update
git log --since="$LAST_UPDATE" --pretty=format:"%h|%ai|%s" --name-status > /tmp/commits.txt

# Count changes by category
NEW_FILES=$(grep "^A" /tmp/commits.txt | wc -l)
MODIFIED_FILES=$(grep "^M" /tmp/commits.txt | wc -l)
DELETED_FILES=$(grep "^D" /tmp/commits.txt | wc -l)

# Extract changed files by layer (configure layer paths per project from CLAUDE.md)
LAYER1_CHANGES=$(grep -E "internal/{layer1}|{layer1}/" /tmp/commits.txt | wc -l)
LAYER2_CHANGES=$(grep -E "internal/{layer2}|{layer2}/" /tmp/commits.txt | wc -l)
LAYER3_CHANGES=$(grep -E "internal/{layer3}|{layer3}/" /tmp/commits.txt | wc -l)
```

### Detect Pattern Changes

```bash
# New test files
NEW_TESTS=$(git diff --name-only --since="$LAST_UPDATE" | grep "_test.go$" | wc -l)

# New dependencies
git diff --since="$LAST_UPDATE" go.mod | grep "^+" | grep -v "^+++" > /tmp/new_deps.txt

# New interfaces (configure {interfaces_layer} per project)
git diff --since="$LAST_UPDATE" -- "*/{interfaces_layer}/*.go" | grep "^+.*interface" > /tmp/new_interfaces.txt

# Error handling pattern changes
git diff --since="$LAST_UPDATE" | grep -E "^\+.*fmt.Errorf|errors.New" > /tmp/error_patterns.txt
```

### Categorize Changes

| Category | Detection | Impact |
|----------|-----------|--------|
| **Architecture** | New layer directories, interface changes | HIGH - needs skill updates |
| **New Features** | New domain entities, usecases | MEDIUM - extend existing skills |
| **Refactoring** | File moves, renames | LOW - update references |
| **Dependencies** | go.mod changes | MEDIUM - check new patterns |
| **Testing** | New test files, mock changes | MEDIUM - update testing skill |

### Determine Update Scope

```bash
# Map changes to sections in PROJECT-KNOWLEDGE.md
UPDATE_SECTIONS=()

if [ $LAYER1_CHANGES -gt 0 ]; then
    UPDATE_SECTIONS+=("## Core Domain")
    UPDATE_SECTIONS+=("## Architecture")
fi

if [ $LAYER3_CHANGES -gt 0 ]; then
    UPDATE_SECTIONS+=("## External Integrations")
fi

if [ $NEW_TESTS -gt 0 ]; then
    UPDATE_SECTIONS+=("## Testing Patterns")
fi

if [ -s /tmp/new_deps.txt ]; then
    UPDATE_SECTIONS+=("## Technology Stack")
fi
```

**Output:**
```
[PHASE 1.6/6] GIT ANALYSIS -- DONE (UPDATE mode)
- Commits since last update: 47
- Files changed: 23 (15 modified, 5 new, 3 deleted)
- Changes by layer:
  - {layer_1}: 3 files
  - {layer_2}: 8 files
  - {layer_3}: 12 files
- New patterns detected:
  - 2 new interfaces in {interfaces_layer}/
  - 5 new test files
  - 3 new dependencies ({dependency_1}, {dependency_2}, {dependency_3})
- Update scope: 4 sections (Core Domain, Architecture, External Integrations, Testing Patterns)
```

**Skip if not UPDATE mode:**
```
[PHASE 1.6/6] GIT ANALYSIS -- SKIPPED (CREATE/AUGMENT mode)
```
