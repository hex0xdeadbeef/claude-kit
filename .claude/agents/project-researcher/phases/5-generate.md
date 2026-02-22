# PHASE 5: GENERATE

**Goal:** Сгенерировать .claude/ артефакты на основе анализа.

---

## 5.1 CLAUDE.md Generation

```markdown
# <Project Name>

**Role:** <Role based on tech stack>
**Project:** <Description from README or analysis>

---

## Architecture

<Detected architecture pattern>

```
<Directory structure>
```

**SEE:** @<arch-skill> для деталей

---

## Key Rules

| # | Rule | Skill |
|---|------|-------|
<Generated from conventions>

---

## Project Structure

```
<Actual project structure>
```

---

## Quick Start

<Based on detected entry points and Makefile>

---

## References

### Skills
<Generated skills table>

### Path Rules
<Generated rules table>

---
```

---

## 5.2 Skills Generation

Сгенерировать skills на основе обнаруженных паттернов:

| Detected Pattern | Skill to Generate |
|------------------|-------------------|
| Clean Architecture | `@arch` (architecture rules) |
| Testify + table-driven | `@testing` (test patterns) |
| {logger} | `@logging` (logging conventions) |
| fmt.Errorf %w | `@errors` (error handling) |
| DI framework | `@di` (dependency injection) |
| HTTP framework | `@http` (handler patterns) |
| gRPC | `@grpc` (service patterns) |

**Skill template:**
```yaml
---
name: <skill-name>
description: |
  <Description based on project patterns>

  Загружай при:
  - <Conditions from analysis>
---

# <Skill Name>

## Rules

<Extracted from project patterns>

## Examples

```<lang>
// CORRECT (from project)
<actual code pattern>

// INCORRECT
<anti-pattern>
```
```

---

## 5.3 Rules Generation

Сгенерировать path-triggered rules:

| Detected Path | Rule Content |
|---------------|--------------|
| `internal/{layer}/**` | {Layer} layer rules (project-specific — configure per CLAUDE.md) |
| `*_test.go` | Testing rules |
| `cmd/**` | Entry point rules |

**Rule template:**
```yaml
---
paths: <glob-pattern>
---

# <Layer Name>

**SEE:** @<related-skill>

## Quick Check
- [ ] <Check 1 from conventions>
- [ ] <Check 2 from conventions>
```

---

## 5.4 Commands Generation (optional)

Если обнаружены явные workflows:

| Detected Workflow | Command |
|-------------------|---------|
| Makefile targets | `/make <target>` helper |
| Test patterns | `/test` command |
| Lint+fix | `/lint` command |

---

## 5.5 PROJECT-KNOWLEDGE.md Generation

**Goal:** Создать comprehensive research document для полного понимания проекта.

**Storage Strategy:**
```
CLAUDE.md              ≤200 lines, always loaded, links to skills
PROJECT-KNOWLEDGE.md   Full research, loaded by @reference
memory.json            MCP key metadata, auto-loaded by Claude
```

**Template:** Load `templates/project-knowledge.md` for PROJECT-KNOWLEDGE.md structure

---

## 5.6 memory.json Generation (MCP Integration)

**Goal:** Создать MCP memory для persistent project context.

**What goes into memory:**
- Project identity (name, language, architecture)
- Critical decisions and their reasoning
- Core entities and relationships
- External integration points
- Key conventions (only most important)

**Memory structure:**

```json
{
  "entities": [
    {
      "name": "<project-name>",
      "type": "project",
      "observations": [
        "Primary language: <language>",
        "Architecture pattern: <pattern>",
        "Created: <date>",
        "Main purpose: <description>"
      ]
    },
    {
      "name": "<architecture-pattern>",
      "type": "architecture",
      "observations": [
        "Pattern: <Clean Architecture/Hexagonal/etc>",
        "Layers: <list>",
        "Dependency rule: <description>",
        "Confidence: HIGH/MEDIUM/LOW"
      ]
    },
    {
      "name": "<core-entity-1>",
      "type": "domain-entity",
      "observations": [
        "Location: <file path>",
        "Purpose: <business purpose>",
        "Key fields: <critical fields>",
        "Aggregate root: yes/no"
      ]
    }
  ],
  "relations": [
    {
      "from": "<project-name>",
      "to": "<architecture-pattern>",
      "type": "uses"
    },
    {
      "from": "<project-name>",
      "to": "<core-entity-1>",
      "type": "contains"
    }
  ]
}
```

**In UPDATE mode:**
```bash
# Read existing memory.json
# Update only changed entities
# Add new entities for new features/integrations
# Update relations if architecture changed

# Use mcp__memory__add_observations for incremental updates
```

---

## 5.7 Write Files (с учётом режима)

```bash
# Create .claude/ structure
mkdir -p .claude/skills
mkdir -p .claude/rules
mkdir -p .claude/commands

# Mode-aware writes
MODE=$([ -d ".claude" ] && echo "AUGMENT" || echo "CREATE")
if [ -f ".claude/PROJECT-KNOWLEDGE.md" ]; then
    MODE="UPDATE"
fi

# Write CLAUDE.md
if [ "$MODE" = "CREATE" ] || [ ! -f ".claude/CLAUDE.md" ]; then
    Write ".claude/CLAUDE.md" <generated content>
    STATUS_CLAUDE="CREATED"
elif [ "$MODE" = "UPDATE" ]; then
    STATUS_CLAUDE="REVIEWED (no changes needed)"
else
    STATUS_CLAUDE="PRESERVED (existing)"
fi

# Write PROJECT-KNOWLEDGE.md
if [ "$MODE" = "CREATE" ] || [ ! -f ".claude/PROJECT-KNOWLEDGE.md" ]; then
    Write ".claude/PROJECT-KNOWLEDGE.md" <full research document>
    STATUS_KNOWLEDGE="CREATED"
elif [ "$MODE" = "UPDATE" ]; then
    # Update only changed sections
    STATUS_KNOWLEDGE="UPDATED (incremental)"
fi

# Write skills (only missing)
for skill in $DETECTED_SKILLS; do
    SKILL_FILE=".claude/skills/$skill/SKILL.md"
    if [ ! -f "$SKILL_FILE" ]; then
        mkdir -p ".claude/skills/$skill"
        Write "$SKILL_FILE" <generated content>
        CREATED_SKILLS+=("$skill")
    else
        PRESERVED_SKILLS+=("$skill")
    fi
done

# Write rules (only missing)
for rule in $DETECTED_RULES; do
    RULE_FILE=".claude/rules/$rule.md"
    if [ ! -f "$RULE_FILE" ]; then
        Write "$RULE_FILE" <generated content>
        CREATED_RULES+=("$rule")
    else
        PRESERVED_RULES+=("$rule")
    fi
done
```

---

## Output

**CREATE mode:**
```
[PHASE 5/6] GENERATE -- DONE (CREATE mode)
- CLAUDE.md: CREATED
- PROJECT-KNOWLEDGE.md: CREATED
- memory.json: CREATED (5 entities, 3 relations)
- Skills: 4 created (arch, testing, errors, logging)
- Rules: 3 created (domain, usecase, tests)
- Commands: 0 (none detected)
```

**AUGMENT mode:**
```
[PHASE 5/6] GENERATE -- DONE (AUGMENT mode)
- CLAUDE.md: PRESERVED (existing)
- PROJECT-KNOWLEDGE.md: CREATED
- memory.json: CREATED (5 entities, 3 relations)
- Skills:
  - Preserved: 2 (arch, testing)
  - Created: 2 (errors, logging)
- Rules:
  - Preserved: 1 (domain)
  - Created: 2 (usecase, tests)
- Commands: 0 (none detected)
```

**UPDATE mode:**
```
[PHASE 5/6] GENERATE -- DONE (UPDATE mode)
- CLAUDE.md: REVIEWED (no changes needed)
- PROJECT-KNOWLEDGE.md: UPDATED (4 sections updated)
  - Updated: Core Domain, External Integrations, Testing Patterns, Technology Stack
  - Added to Change History: 2026-01-10 entry
- memory.json: UPDATED (2 entities updated, 1 entity added)
- Skills: No changes (all current)
- Rules: No changes (all current)
- Recommendations: 1 (consider updating logging skill for new {logger} patterns)
```
