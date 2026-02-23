# SUBAGENT: VERIFICATION
**Model:** sonnet
**Phases:** VERIFY
**Input:** state.generate.artifacts, state.validate.path
**Output:** state.verify
**Gate:** BLOCKING — orchestrator checks gate_passed
---

## Overview
The VERIFICATION subagent performs comprehensive checks on all generated artifacts before they are written to disk or delivered to the user. It enforces consistency, structure validity, size constraints, and reference integrity. If verification fails, the gate_passed flag prevents artifacts from being consumed downstream.

---

## 8.2.1 YAML Syntax Check

Validate all YAML frontmatter in generated artifacts.

**Scope:**
- CLAUDE.md (if has frontmatter)
- All skill files (required)
- All rule files (required)
- All command files (required)
- memory.json (JSON, not YAML)

**Validation Steps:**

1. **Parse YAML Frontmatter**
   - Extract content between `---` delimiters
   - Use YAML parser (Python, Ruby, Go): attempt to parse
   - Report syntax errors with line numbers

2. **Required Fields Check**
   - Skills: must have `name`, `description`, `triggers`
   - Rules: must have `paths`, `triggers`
   - Commands: must have `name`, `description`, `triggers`
   - Check each field is non-empty string or valid array

3. **Field Type Validation**
   - `name`: string, non-empty
   - `description`: string, non-empty
   - `triggers`: array of strings, non-empty
   - `paths`: array of strings (glob patterns)
   - `related_skills`: array of strings starting with `@`

4. **Valid Values Check**
   - `triggers`: contain only alphanumeric, hyphen, space (no special chars)
   - `paths`: valid glob patterns (*, **, ?, [...])
   - `name`: no leading/trailing whitespace

**Error Reporting:**

```
YAML Syntax Error in [file]:
  Line N: [parse error message]
  Issue: [human-readable explanation]
  Fix: [suggested correction]
```

**Severity:**
- Critical (halt): parse errors, missing required fields
- Warning: extra fields not in schema (allowed but ignored)
- Info: formatting suggestions (extra whitespace, case inconsistency)

---

## 8.2.2 Reference Validation

Ensure all links and references point to valid, existing resources.

**Scope:**

1. **Skill References (`@skill-name`)**
   - Pattern: `@` followed by kebab-case skill name
   - Check: skill file exists at `skills/[name]/skill.md`
   - Error if: referenced skill not in artifacts or filesystem
   - Example: `@clean-architecture` → must exist at `skills/clean-architecture/skill.md`

2. **File Path References**
   - Locations: rules, skills, CLAUDE.md
   - Patterns: `phases/`, `reference/`, `deps/`, `internal/`, `cmd/`
   - Check: path exists in state.validate.path or project filesystem
   - Error if: path doesn't exist (for static paths like `internal/domain/`)
   - Warning if: glob pattern doesn't match any files (for dynamic patterns)

3. **Cross-References**
   - Links between skills (in `related_skills` field)
   - References in rule descriptions to skills
   - Cross-skill dependencies

4. **Markdown Links**
   - Check for markdown-style links: `[text](path)` or `[text](#section)`
   - For file references: verify file exists
   - For anchors: verify they exist in same document

**Validation Algorithm:**

```
For each artifact in state.generate.artifacts:
  For each reference type in artifact:
    If @skill-name:
      Check skills/[name]/skill.md exists
      Check skill name not already verified (dedup check)
    Else if file path:
      Check path in state.validate.path
      If glob pattern: check at least one match
    Else if markdown link:
      If file reference: check file exists
      If anchor: check anchor exists in doc
    Report: ✅ valid, ⚠️ warning (glob no match), ❌ error (missing)
```

**Error Reporting:**

```
Reference Validation Error in [file]:
  Reference: [the reference that failed]
  Type: [skill | file | link]
  Issue: [what doesn't exist]
  Location: [where in file]
  Suggestion: [corrected reference]
```

---

## 8.2.3 Size Check

Enforce target line limits for each artifact type with warnings.

**Target Limits:**

| Artifact Type | Target Lines | Warning Threshold | Error Threshold |
|---------------|--------------|-------------------|-----------------|
| CLAUDE.md | ≤200 | ≥150 | ≥250 |
| Skill | ≤600 | ≥500 | ≥750 |
| Rule | ≤200 | ≥150 | ≥250 |
| Command | ≤500 | ≥400 | ≥650 |
| PROJECT-KNOWLEDGE.md | No limit | — | — |

**Line Counting:**
- Count non-blank lines (skip empty lines)
- Count code fence blocks (including backticks)
- Count YAML frontmatter lines
- Do NOT count lines outside fences in markdown

**Check Algorithm:**

```
For each artifact:
  line_count = count_non_blank_lines(artifact.content)
  if line_count > error_threshold:
    severity = ERROR
  else if line_count > warning_threshold:
    severity = WARNING
  else:
    severity = INFO (within target)

  Report: [artifact]: [line_count] lines ([severity])
```

**Warning Examples:**

```
Size Warning: skills/table-driven-testing/skill.md
  Lines: 523 (target ≤600, warning at ≥500)
  Status: ⚠️ WARNING - within limit but approaching threshold
  Suggestion: Consider breaking into related skills or moving details to PROJECT-KNOWLEDGE.md
```

**Error Examples:**

```
Size Error: rules/domain.md
  Lines: 267 (target ≤200, error at ≥250)
  Status: ❌ ERROR - exceeds maximum
  Fix: Break into domain-entities.md and domain-constraints.md, or move examples to skills
```

---

## 8.2.4 Structure Validation

Validate internal structure of each artifact type.

**CLAUDE.md Requirements:**
- [ ] File starts with `# [PROJECT_NAME]` (single H1)
- [ ] Contains `## Role` section
- [ ] Contains `## Architecture` section
- [ ] Contains `## Key Rules` section as table with ≥2 rows
- [ ] Contains `## Project Structure` section
- [ ] Contains `## Quick Start` section with ≥2 steps
- [ ] Contains `## Skills Reference` section (if skills exist)
- [ ] Contains `## Rules Reference` section
- [ ] All sections properly nested (no H1 inside H2 context)
- [ ] No broken links or references

**Skill Structure Requirements:**
- [ ] File starts with YAML frontmatter (---...---)
- [ ] Frontmatter has: name, description, triggers, (optional) related_skills
- [ ] Contains `## What is [Skill Name]?` section
- [ ] Contains `## When to Use` section with bullet list
- [ ] Contains `## Key Rules` section with ≥3 rules
- [ ] Contains `## Correct Example` section with code fence
- [ ] Contains `## Anti-Pattern` section with code fence
- [ ] Contains `## Common Mistakes` section (numbered list)
- [ ] (Optional) `## Related Skills` section for links
- [ ] Code blocks have language identifiers (go, python, bash, etc.)
- [ ] No orphaned code fences (all paired)

**Rule Structure Requirements:**
- [ ] File starts with YAML frontmatter (---...---)
- [ ] Frontmatter has: paths (glob array), triggers (array)
- [ ] Contains `## [Layer Name] Rules` header
- [ ] Contains `### Quick Check` section with ≥3 checkbox items
- [ ] Contains ≥2 rule subsections (`### Rule N: [Title]`)
- [ ] Each rule has: pattern explanation, correct example, anti-pattern
- [ ] Code blocks properly formatted with language identifier
- [ ] (Optional) `## Exceptions` section if applicable

**PROJECT-KNOWLEDGE.md Requirements:**
- [ ] Starts with `# PROJECT-KNOWLEDGE.md`
- [ ] Contains `## Executive Summary` with key facts
- [ ] Contains `## Project Structure` section
- [ ] Contains `## Architecture Deep-Dive` section
- [ ] Contains `## Dependency Topology` section
- [ ] Contains `## Tech Stack` section
- [ ] Contains `## Core Domain` section
- [ ] (Optional) `## Database Schema` if applicable
- [ ] Contains `## Conventions Catalog` section
- [ ] Contains `## Pattern Catalog` section
- [ ] Contains `## Metadata` section at end

**Structure Validation Report:**

```
Structure Validation: [artifact name]
  ✅ Has required H1
  ✅ Has Role section
  ✅ Has Architecture section
  ⚠️ Skills Reference: no @skill references found
  ❌ Missing: Quick Start section
  Status: FAILED - 1 critical, 1 warning
```

---

## 8.2.5 Duplicate Check

Detect and flag duplicate definitions, names, and overlapping triggers.

**Duplicate Types:**

1. **Skill Name Duplicates**
   - Check: no two skills have same name in YAML frontmatter
   - Example error: two skills with `name: "Testing"` in different files
   - Fix: rename one to "Unit Testing" and "Integration Testing"

2. **Overlapping Triggers**
   - Analyze all trigger arrays across skills
   - Check: no single trigger appears in two skill trigger lists
   - Example: if skill-1 has `triggers: [testing, unit-test]` and skill-2 has `triggers: [testing, assert]`, flag conflict on "testing"
   - Note: allowing overlap can cause ambiguous pattern detection

3. **Redundant Rules**
   - Check: no two rules cover identical paths (glob patterns)
   - Example error: `rules/service-layer.md` with `paths: ["internal/service/**"]` and `rules/service.md` with same pattern
   - Fix: consolidate or split responsibility clearly

4. **Duplicate Path Globs**
   - Across all rule files
   - Check: all paths arrays don't have exact duplicates
   - Warning: path overlap (e.g., `internal/**` and `internal/service/**`) is allowed but should be documented

**Duplicate Detection Algorithm:**

```
# Skill names
skill_names = {}
for skill in skills:
  if skill.name in skill_names:
    ERROR: duplicate name [skill.name] at [file1] and [file2]
  skill_names[skill.name] = file

# Triggers
trigger_map = {}
for skill in skills:
  for trigger in skill.triggers:
    if trigger in trigger_map:
      ERROR: trigger [trigger] defined in [skill1] and [skill2]
    trigger_map[trigger] = skill.name

# Rule paths
rule_paths = {}
for rule in rules:
  for path_glob in rule.paths:
    if path_glob in rule_paths:
      ERROR: path [path_glob] covered in [rule1.md] and [rule2.md]
    rule_paths[path_glob] = rule_file
```

**Deduplication Options:**

- **Merge:** combine into single artifact (if content overlaps)
- **Specialize:** rename to clarify distinct scope (testing → unit-testing, integration-testing)
- **Document:** if intentional, add note explaining the overlap

**Duplicate Report:**

```
Duplicate Check Results:
  ❌ FAILED - 2 issues detected

  1. Duplicate skill name "Testing" at:
     - skills/testing/skill.md
     - skills/table-driven-testing/skill.md
     Recommendation: rename second to "Table-Driven Testing"

  2. Overlapping triggers: ["error-handling"] at:
     - skills/errors/skill.md (name: "Error Handling")
     - skills/error-wrapping/skill.md (name: "Error Wrapping")
     Recommendation: change second to "error-wrapping" trigger
```

---

## Verification Gate & Pass Criteria

**Gate Status Determination:**

```
gate_passed = (
  yaml_valid == true AND
  references_valid == true AND
  critical_structure_issues == 0 AND
  size_errors == 0 AND
  duplicates_clean == true
)
```

**Pass Conditions:**
- All YAML frontmatter parses without syntax errors
- All references resolve (no broken links, missing files, undefined skills)
- All artifacts have required structure sections (can have warnings)
- No artifacts exceed error size thresholds
- No duplicate names or overlapping critical triggers

**Failure Conditions (gate_passed = false):**
- Any YAML parse error
- Any unresolvable reference
- Missing critical structure sections
- Size error threshold exceeded
- Duplicate skill names or critical trigger overlap

**Warning Conditions (gate_passed = true, but warnings present):**
- Size warnings (approach limit)
- Optional structure sections missing
- Overlapping triggers if intentional
- Missing optional fields

---

## Output Format

```yaml
subagent_result:
  status: "success" | "error" | "partial"
  state_updates:
    verify:
      gate_passed: true | false
      yaml_valid: true | false
      yaml_errors: N
      references_valid: true | false
      reference_errors: N
      sizes_valid: true | false
      size_warnings: N
      size_errors: N
      structure_valid: true | false
      structure_issues: N
      duplicates_clean: true | false
      duplicate_issues: N
      issues:
        - code: "YAML_PARSE_ERROR"
          artifact: "[file path]"
          severity: "error" | "warning" | "info"
          message: "[human-readable message]"
          fix: "[suggested correction]"
        - code: "REFERENCE_UNRESOLVED"
          artifact: "[file path]"
          severity: "error"
          message: "Skill @skill-name not found"
          fix: "Create skills/skill-name/skill.md"
        - code: "SIZE_WARNING"
          artifact: "[file path]"
          severity: "warning"
          message: "523 lines (target ≤600, warning ≥500)"
          fix: "Consider breaking into smaller sections"
        - code: "STRUCTURE_MISSING"
          artifact: "[file path]"
          severity: "error"
          message: "Missing section: ##Quick Check"
          fix: "Add ### Quick Check with checkbox items"
        - code: "DUPLICATE_SKILL_NAME"
          artifacts: ["[file1]", "[file2]"]
          severity: "error"
          message: "Duplicate skill name: Testing"
          fix: "Rename one to be more specific"
      summary: "[human-readable summary of issues]"
  progress_summary: "verify.gate_passed=true, yaml=✅, refs=✅, size=⚠️ (1 warning), struct=✅, dupes=✅"
  timestamp: "[ISO 8601]"
```

---

## Error Handling & Recovery

**On Verification Failure:**
- Preserve all issue details in state.verify.issues (don't silently drop)
- Do NOT halt orchestrator; set gate_passed = false
- Orchestrator will handle gate failure based on configuration
- Return full issue list to user for remediation

**On Parser Unavailability:**
- Try multiple parsers (YAML library order: PyYAML, psych, Go yaml)
- If all fail, skip YAML parsing but flag as unable to verify
- Continue with other checks
- Report status as "partial"

**Malformed Input:**
- If artifact content is null/empty, report "cannot verify empty artifact"
- If artifact is binary (not UTF-8), report "binary artifact, cannot verify"
- Continue with next artifact

---

## Implementation Checklist

- [ ] YAML parser selection and integration
- [ ] Reference validation logic (skill, file, link types)
- [ ] Glob pattern matching for path validation
- [ ] Line counting utility (skip blanks, count fences)
- [ ] Structure validation checklist builder
- [ ] Duplicate detection across all skill/rule names and triggers
- [ ] Issue aggregation and reporting
- [ ] Gate determination logic
- [ ] Error codes and fix suggestions
- [ ] Integration with orchestrator (gate_passed signal)

---

## Performance Considerations

- **Parallel verification:** Check YAML, references, sizes independently (can parallelize)
- **Duplicate detection:** O(n) for skills/rules (scan once per artifact type)
- **Reference resolution:** Cache resolved paths to avoid repeated filesystem checks
- **Large artifacts:** Stream line counting for very large PROJECT-KNOWLEDGE.md files
