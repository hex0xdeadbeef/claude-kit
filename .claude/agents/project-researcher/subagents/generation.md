# SUBAGENT: GENERATION
**Model:** sonnet
**Phases:** GENERATE
**Input:** Full accumulated state (all phases), config.dry_run
**Output:** state.generate
---

## Overview
The GENERATION subagent transforms accumulated research from earlier phases into concrete artifacts: CLAUDE.md, skills, rules, PROJECT-KNOWLEDGE.md, and memory.json. It respects the configured mode (CREATE/AUGMENT/UPDATE) and honors dry_run settings.

---

## 5.1 CLAUDE.md Generation (≤200 lines)

Generate a comprehensive but concise project guide from the research state.

**Template Structure:**
```
# [PROJECT_NAME]
[One-line description from state.analyze.project_summary]

## Role
[From state.analyze.project_role - what does this project do?]

## Architecture
[Summary of state.analyze.architecture with ≤3 key layers]
- Brief layer descriptions
- Key responsibility separation

## Key Rules
| Area | Rule |
|------|------|
| [Area from state.analyze.conventions] | [Convention/Pattern] |
| Testing | [Testing approach from state.analyze.conventions.testing.style] |
| Error Handling | [Error pattern from state.analyze.conventions.errors.pattern] |
| Logging | [Logging convention from state.analyze.conventions.logging.library] |

## Project Structure
[Show core directory tree from state.validate.structure, depth 2-3]

## Quick Start
1. [Entry point from state.map.entry_points[0]]
2. [Key package description]
3. [Test execution command]

## Skills Reference
@skill-[name] — [description] (triggers: @pattern-name)

## Rules Reference
[List layer rules paths and what they check]

## Further Reading
- See PROJECT-KNOWLEDGE.md for deep analysis
- See individual skill files for detailed guidance
```

**Link Pattern:**
- Reference skills with `@skill-name` matching skill file naming
- Map triggers to architectural patterns detected in state.analyze

**Generation Logic:**
- Extract project_name from state.analyze.project_name
- Use project_role from state.analyze
- Build architecture section from state.analyze.architecture + state.analyze.layers + state.map.entry_points
- Populate Key Rules table from state.analyze (conventions, testing, errors, logging)
- Generate project structure from state.discover.analysis_targets (directory tree)
- Create quick start from state.map.entry_points
- List all generated skills with triggers
- List all rule file paths by layer
- Word count: target ≤200 lines; warn if ≥150

---

## 5.2 Skills Generation

Transform detected patterns into reusable skill cards (≤600 lines each).

**Pattern → Skill Mapping:**

| Pattern | Skill Name | Trigger |
|---------|------------|---------|
| Clean Architecture / Layered | @arch | architecture, layers, internal/*, interfaces |
| Table-driven tests / Testify | @testing | *_test.go, test patterns, assert |
| Structured logging | @logging | log.*, logger, slog, zap |
| fmt.Errorf %w / Error wrapping | @errors | error handling, fmt.Errorf, error wrapping |
| Dependency Injection | @di | container, inject, provider, constructor |
| HTTP framework (Gin/Echo/stdlib) | @http | http.Handler, router, middleware, mux |
| gRPC | @grpc | protobuf, gRPC, service definition |
| Database ORM (GORM/sqlc) | @db | database, SQL, queries, migrations |
| Configuration management | @config | config, flags, env, viper |
| Middleware/Interceptors | @middleware | middleware, interceptor, handler chain |

**Skill File Template:**

```yaml
---
name: "[Skill Name]"
description: "[What this pattern is and why it matters]"
triggers: [list, of, pattern, keywords]
related_skills: [@skill-a, @skill-b]
---

## What is [Skill Name]?
[2-3 sentence explanation of the pattern and its benefits]

## When to Use
- Situation 1
- Situation 2
- Situation 3

## Key Rules
- Rule 1: [guideline]
- Rule 2: [guideline]
- Rule 3: [guideline]

## Correct Example (from project)
\`\`\`[language]
[Real code snippet from state.analyze.patterns showing the pattern correctly]
\`\`\`

**Why this works:**
- [Explanation 1]
- [Explanation 2]

## Anti-Pattern (what to avoid)
\`\`\`[language]
[Real anti-pattern example or common mistake]
\`\`\`

**Why not:**
- [Problem explanation]

## Common Mistakes
1. [Mistake 1 and correction]
2. [Mistake 2 and correction]
3. [Mistake 3 and correction]

## Related Skills
See @skill-name, @another-skill

---
```

**Generation Logic:**
- For each pattern in state.analyze.patterns:
  - Create skill file in `skills/[pattern-slug]/`
  - Generate filename: `skill.md`
  - Extract real examples from state.analyze.code_snippets
  - Include anti-patterns from state.analyze.anti_patterns
  - Link related skills based on state.analyze.dependencies
- Verify skill names don't duplicate (check duplicates during verification phase)
- Line count per skill: target ≤600; warn if ≥500
- YAML frontmatter required: name, description, triggers

**Skill Naming Convention:**
- Use kebab-case in filenames: `@clean-architecture`, `@table-driven-testing`
- Use spaces in YAML name field: `Clean Architecture`, `Table-Driven Testing`
- Generate trigger list from state.analyze.pattern_triggers

---

## 5.3 Rules Generation

Create path-triggered validation rules for each architectural layer (≤200 lines each).

**Path-Triggered Rules Pattern:**

| Layer | Glob Paths | Rule File |
|-------|-----------|-----------|
| Domain | `internal/domain/**` | `rules/domain.md` |
| Repository | `internal/repository/**` | `rules/repository.md` |
| Service | `internal/service/**` | `rules/service.md` |
| Handler | `internal/handler/**` | `rules/handler.md` |
| Middleware | `internal/middleware/**` | `rules/middleware.md` |
| Testing | `**/*_test.go` | `rules/testing.md` |
| Entry Point | `cmd/**` | `rules/cmd.md` |
| Config | `internal/config/**` | `rules/config.md` |

**Rule File Template:**

```yaml
---
paths: ["internal/[layer]/**"]
triggers: [pattern, keywords]
author: "project-researcher"
generated: true
---

## [Layer Name] Rules

### Quick Check
- [ ] [Check 1 - testable statement]
- [ ] [Check 2 - testable statement]
- [ ] [Check 3 - testable statement]
- [ ] [Check 4 - testable statement]

### Rule 1: [Rule Title]
**Pattern:** [What pattern this rule enforces]

[2-3 sentence explanation]

**✅ Correct:**
\`\`\`
[Code example from project]
\`\`\`

**❌ Incorrect:**
\`\`\`
[Anti-pattern or violation]
\`\`\`

### Rule 2: [Rule Title]
[Same structure as Rule 1]

## Exceptions
- [If exceptions exist in the project, document them]

---
```

**Generation Logic:**
- For each layer in state.analyze.architecture.layers:
  - Create rule file in `rules/[layer].md`
  - Extract Quick Check items from state.analyze.layer_constraints
  - Build rules from state.analyze.patterns with real code examples
  - Document layer responsibility and boundaries
  - Include common violations detected (state.analyze.violations)
- Testing rules: drawn from state.analyze.testing_style, test structure patterns
- Entry point rules: from state.analyze.entry_points, initialization patterns
- Line count per rule: target ≤200; warn if ≥150
- YAML frontmatter required: paths glob, triggers

---

## 5.4 Commands Generation (Optional)

Only generate if state.analyze.explicit_workflows contains workflow definitions.

**Command File Template:**

```yaml
---
name: "[Workflow Name]"
description: "[What this workflow does]"
triggers: [keywords]
---

## Overview
[Purpose and context]

## Steps
1. Step 1: [Description]
2. Step 2: [Description]
3. Step 3: [Description]

## Examples
[Use cases and examples]

---
```

**Generation Logic:**
- Check if state.analyze.explicit_workflows has entries
- For each workflow: create file in `commands/[workflow-name].md`
- Limit: ≤500 lines per command; warn if ≥400
- Skip entirely if no workflows detected

---

## 5.5 PROJECT-KNOWLEDGE.md Generation

Create comprehensive research document (no line limit; reference guide).

**Template Sections (order matters):**

```markdown
# PROJECT-KNOWLEDGE.md
[Date and metadata]

## Executive Summary
- **Project:** [name]
- **Role:** [purpose]
- **Architecture:** [pattern, key layers]
- **Core Tech:** [languages, frameworks, key dependencies]
- **Scale:** [lines of code, packages, test coverage %]
- **Key Characteristics:** [3-5 defining traits]

## Project Structure
[Detailed directory tree with descriptions, depth 3-4]

## Architecture Deep-Dive

### Overall Pattern
[Detailed explanation from state.analyze.architecture]

### Layer Descriptions
For each layer from state.analyze.architecture.layers:
- **[Layer Name]** (`internal/[layer]`)
  - Purpose: [what it does]
  - Responsibilities: [list]
  - Key packages: [list from state.validate.packages]
  - Constraints: [rules from state.analyze.layer_constraints]

### Entry Points
[Detailed explanation of how code is invoked, from state.analyze.entry_points]

## Dependency Topology

### Hub Packages
[From state.analyze.dependencies, list central packages]

### Depth Map
[Show dependency tree depth, identify leaf packages]

### Circular Dependencies
[If detected in state.analyze.violations, document them]

## Tech Stack

### Language & Runtime
[Language, version, tools]

### Key Frameworks
[List from state.analyze.dependencies with descriptions]

### Key Dependencies
[Group by category: database, logging, testing, HTTP, etc.]

## Core Domain

### Entities
[From state.analyze.domain_entities, describe key types]

### Workflows
[Main user/system workflows, flows of data]

## Database Schema
[If applicable: tables, relationships, key fields from state.analyze]

## Conventions Catalog

### Naming
[From state.analyze.naming_conventions]

### Error Handling
[From state.analyze.error_patterns]

### Logging
[From state.analyze.logging_convention]

### Testing
[From state.analyze.testing_style]

## Pattern Catalog

### Detected Patterns
[For each pattern in state.analyze.patterns:]
- **[Pattern Name]:** [locations, usage count, purpose]

## Technical Debt
[From state.analyze.violations if any; document known issues]

## External Integrations
[APIs called, services, external systems]

## Metadata
- **Generated:** [timestamp]
- **Language:** [project language]
- **LOC:** [line count]
- **Files:** [file count]
- **Packages:** [package count]
- **Test Files:** [count]
- **Test Coverage:** [estimated %]

---
```

**Generation Logic:**
- Use template from `templates/project-knowledge.md` as base structure
- Populate all sections from accumulated state (all phases)
- Real code examples from state.analyze.code_snippets
- Include confidence notes for inferred sections
- Create comprehensive reference document (no length constraints)

---

## 5.6 memory.json Generation (MCP)

Generate structured entity and relation data for the Claude Memory Protocol.

**Template Structure:**

```json
{
  "entities": [
    {
      "type": "project",
      "id": "[project-slug]",
      "name": "[project name]",
      "description": "[from state.analyze.project_role]",
      "language": "[detected language]",
      "architecture": "[from state.analyze.architecture.pattern]",
      "entry_points": "[from state.analyze.entry_points]",
      "created_at": "[timestamp]"
    },
    {
      "type": "architecture",
      "id": "arch-[pattern]",
      "name": "[Pattern Name]",
      "pattern": "[from state.analyze.architecture.pattern]",
      "layers": "[from state.analyze.architecture.layers]",
      "description": "[explanation]"
    },
    {
      "type": "domain_entity",
      "id": "entity-[name]",
      "name": "[Entity Name]",
      "description": "[from state.analyze.domain_entities]",
      "location": "[package path]"
    }
  ],
  "relations": [
    {
      "source": "[entity-id]",
      "target": "[entity-id]",
      "type": "uses",
      "description": "[purpose]"
    },
    {
      "source": "[entity-id]",
      "target": "[entity-id]",
      "type": "contains",
      "description": "[composition]"
    }
  ]
}
```

**Generation Logic:**
- Create entities for: project, architecture, each domain entity, each major package
- Create relations for: uses (dependency), contains (composition), implements (interface)
- Pull data from state.analyze and state.validate
- Timestamp: current generation time
- Slug: convert project name to kebab-case

---

## 5.7 Mode-Aware Writing

**CREATE Mode:**
- Generate all artifacts from scratch
- No preservation of existing files
- Overwrite all files in generation paths

**AUGMENT Mode:**
- Preserve existing skills if they exist (check filesystem)
- Fill gaps: only write files that don't exist
- If CLAUDE.md exists, preserve and augment (add new sections, don't remove)
- For PROJECT-KNOWLEDGE.md: merge findings, preserve hand-written notes if present

**UPDATE Mode:**
- Incremental changes only
- Track what changed: added patterns, new entry points, updated conventions
- For each artifact:
  - If content identical: preserve as-is, mark "unchanged"
  - If content changed: write update, add timestamp to header
  - If no longer relevant: mark deprecated (don't delete)
- Update memory.json with new relations discovered
- Generate CHANGES.md documenting all updates

**Dry Run (config.dry_run = true):**
- Do NOT write any files to disk
- Generate all artifacts in memory
- Report what would be generated with file paths and sizes
- Return preview in state.generate.dry_run_preview

---

## Output Format

```yaml
subagent_result:
  status: "success" | "error" | "partial"
  state_updates:
    generate:
      mode: "CREATE" | "AUGMENT" | "UPDATE"
      artifacts:
        - type: "CLAUDE.md" | "skill" | "rule" | "command" | "knowledge" | "memory"
          path: "[full/path/to/file]"
          size_bytes: N
          status: "created" | "preserved" | "updated" | "skipped"
          lines: N
      total_created: N
      total_preserved: N
      total_updated: N
      total_skipped: N
      warnings:
        - "[line count warning for artifact XYZ]"
        - "[missing trigger mapping for pattern]"
      dry_run_preview: "[if dry_run=true, summary of what would be written]"
  progress_summary: "generate.artifacts=5, created=5, lines_total=1200"
  timestamp: "[ISO 8601]"
```

---

## Error Handling

- **Invalid state:** Return error if missing required fields (project_name, architecture, patterns)
- **Dry run conflict:** If dry_run=true and files would be overwritten, report in warnings
- **Template errors:** If template from templates/ is missing, use inline template
- **Encoding issues:** UTF-8 only; report if non-UTF8 detected in project files

---

## Implementation Notes

1. **Idempotency:** Running generation twice with same input should produce identical output
2. **Artifact Versioning:** Add generation timestamp to each file header
3. **Link Validation:** Verify all @skill and path references will be valid after writing
4. **Size Warnings:** Report before writing if artifact exceeds target size
5. **Skill Deduplication:** Check for skill name collisions; error if found
