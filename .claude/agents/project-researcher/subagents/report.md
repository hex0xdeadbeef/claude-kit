# SUBAGENT: REPORT
**Model:** haiku
**Phases:** REPORT
**Input:** Full accumulated state
**Output:** Final markdown report (no state updates)
---

## Overview
The REPORT subagent synthesizes all accumulated state from prior phases and generates a comprehensive, human-readable markdown report. It surfaces key findings, confidence levels, generated artifacts, recommendations, and next steps. The report is the final deliverable to the user and must be clear, structured, and actionable.

---

## Report Structure

The report format differs based on execution mode (CREATE, AUGMENT, UPDATE). All reports include a summary and detailed sections.

---

## CREATE Mode Report

**Full analysis of a new project from scratch.**

### Report Header

```markdown
# Project Research Report: [PROJECT_NAME]

**Generated:** [ISO 8601 timestamp]
**Mode:** CREATE (Full Analysis)
**Analyzer:** project-researcher (sonnet)
**Status:** [SUCCESS | PARTIAL | FAILED]

---
```

### Section 1: Executive Summary (≤400 words)

```markdown
## Executive Summary

[2-3 sentence high-level overview from state.analyze.project_summary]

**Key Findings:**
- **Architecture Pattern:** [from state.analyze.architecture.pattern]
- **Language & Runtime:** [from state.analyze.language]
- **Estimated Size:** [from state.validate.metrics] lines of code
- **Core Purpose:** [from state.analyze.project_role]
- **Test Coverage Style:** [from state.analyze.testing_style]

**This report documents:**
1. Discovered architecture and layer structure
2. Established naming and coding conventions
3. Testing methodology and patterns
4. Error handling and logging strategies
5. Key dependencies and integrations
6. Recommendations for agent configuration

---
```

### Section 2: Summary Table (Key Metadata)

```markdown
## Project at a Glance

| Attribute | Value |
|-----------|-------|
| **Project Name** | [name] |
| **Primary Language** | [language] |
| **Architecture Pattern** | [pattern] |
| **Distinct Layers** | [count] ([layer-1], [layer-2], ...) |
| **Entry Points** | [count] ([main.go], [api.go], ...) |
| **Core Domain Entities** | [count] ([Entity1], [Entity2], ...) |
| **Test Style** | [e.g., "Table-driven with Testify"] |
| **Package Count** | [count] |
| **Test File Count** | [count] |
| **Estimated Test Coverage** | [percentage %] |
| **Primary Framework** | [framework if applicable] |

---
```

### Section 3: Analysis Confidence Table

```markdown
## Analysis Confidence

Assessment of confidence in findings across key areas:

| Area | Confidence | Evidence | Notes |
|------|-----------|----------|-------|
| **Architecture** | HIGH | [# files analyzed], [# patterns confirmed] | Layered pattern evident across file organization |
| **Naming Conventions** | HIGH | [# examples found] | Consistent across [X%] of codebase |
| **Testing Patterns** | MEDIUM | [# test files], [test count] | Table-driven tests prevalent; some test gaps |
| **Error Handling** | MEDIUM | [# error instances] | Mix of error wrapping and custom types |
| **Logging** | HIGH | [# log statements], [# packages] | Structured logging with consistent format |
| **Dependency Topology** | HIGH | [# dependencies analyzed] | Hub packages clearly identified |
| **Entry Points** | HIGH | [# entry points], [# invocation patterns] | Clear initialization paths |

**Overall Confidence:** [WEIGHTED AVERAGE] (range: LOW, MEDIUM, HIGH)

**Low-Confidence Areas:**
- [If any]: [area] — [reason why confidence is low] — [what would improve it]

---
```

### Section 4: Generated Artifacts Table

```markdown
## Generated Artifacts

All artifacts have been generated and verified. Below is the inventory:

| Type | Name | File | Status | Lines | Issues |
|------|------|------|--------|-------|--------|
| Core Guide | CLAUDE.md | `CLAUDE.md` | ✅ Created | [N] | — |
| Skill | Clean Architecture | `skills/clean-architecture/skill.md` | ✅ Created | [N] | — |
| Skill | Table-Driven Testing | `skills/table-driven-testing/skill.md` | ✅ Created | [N] | — |
| Skill | Error Wrapping | `skills/error-wrapping/skill.md` | ✅ Created | [N] | — |
| Rule | Domain Layer | `rules/domain.md` | ✅ Created | [N] | — |
| Rule | Service Layer | `rules/service.md` | ✅ Created | [N] | — |
| Rule | Testing Rules | `rules/testing.md` | ✅ Created | [N] | — |
| Knowledge | PROJECT-KNOWLEDGE.md | `PROJECT-KNOWLEDGE.md` | ✅ Created | [N] | — |
| Memory | memory.json | `memory.json` | ✅ Created | [entities] entities, [relations] relations | — |

**Total:** [N] artifacts created | [total lines] total lines of guidance

---
```

### Section 5: Dependency Topology

```markdown
## Dependency Topology

Understanding the structure of dependencies and package relationships:

### Hub Packages (Central Dependencies)

Packages that are imported most frequently or act as central coordination points:

| Package | Import Count | Role | Key Dependents |
|---------|--------------|------|---|
| [hub-1] | [count] | [role description] | [dependent-1], [dependent-2], ... |
| [hub-2] | [count] | [role description] | [dependent-1], [dependent-2], ... |

**Pattern:** [Describe hub pattern: e.g., "Core domain types are hub; all layers depend on domain"]

### Dependency Depth Map

```
Depth 0 (Leaf):
  - [package-1]
  - [package-2]

Depth 1 (Depends on Depth 0):
  - [package-3]

Depth 2 (Depends on Depth 0-1):
  - [package-4]
  - [package-5]

Depth 3+ (Core/Hub):
  - [hub-package] ← imports most things in tree
```

### Circular Dependencies

[If state.analyze.violations contains circular deps:]
```
Detected Circular Dependencies:
- [Package A] ↔ [Package B]: [Brief description]
  Impact: [severity]
  Workaround: [how it's currently handled]
```

[If none detected:]
```
✅ No circular dependencies detected
```

---
```

### Section 6: Technology Stack

```markdown
## Technology Stack

### Language & Runtime
- **Language:** [language, version]
- **Runtime:** [runtime if applicable]
- **Build Tool:** [e.g., make, go build]
- **Package Manager:** [if applicable]

### Key Frameworks & Libraries

**HTTP/Web:**
- [Framework] ([version]) — [Purpose/Role in project]

**Database:**
- [ORM/Driver] ([version]) — [Purpose]

**Logging:**
- [Package] ([version]) — [Logging approach]

**Testing:**
- [Framework] ([version])
- [Assertion lib] ([version])

**Other Notable Dependencies:**
- [Package] — [Purpose]
- [Package] — [Purpose]

**External Integrations:**
- [Service/API] — [how it's used]

---
```

### Section 7: Architecture Deep-Dive

```markdown
## Architecture Deep-Dive

### Overall Pattern: [Pattern Name]

[2-3 paragraph explanation of the architecture pattern, how it's implemented in this project, and why it fits]

**Key Benefits:**
- [Benefit 1]
- [Benefit 2]
- [Benefit 3]

### Layer Structure

[For each layer in state.analyze.architecture.layers:]

#### [Layer Name] (`internal/[layer]`)

**Purpose:** [What this layer does and its responsibility]

**Key Packages:**
- `internal/[layer]/[subpkg]` — [responsibility]
- `internal/[layer]/[subpkg]` — [responsibility]

**Constraints:**
- [Constraint 1]: [explanation]
- [Constraint 2]: [explanation]

**Examples:**
```[language]
[Real code example from project showing layer in use]
```

---
```

### Section 8: Core Domain & Entities

```markdown
## Core Domain

### Entities

[From state.analyze.domain_entities]

| Entity | Location | Purpose | Related Entities |
|--------|----------|---------|---|
| [Entity] | `internal/domain/[entity].go` | [description] | [related-1], [related-2] |

### Data Flow

[High-level description of how data flows through the system from entry point]

```
[Entry Point]
  ↓
[Handler/Router]
  ↓
[Service Layer]
  ↓
[Repository/Database]
  ↓
[Response/Return]
```

---
```

### Section 9: Conventions Catalog

```markdown
## Conventions Catalog

Discovered naming, coding, and structural conventions in the project:

### Naming Conventions

[From state.analyze.naming_conventions]

- **Package Names:** [e.g., "snake_case, single word"]
- **Interface Names:** [e.g., "typically end with 'er': Reader, Writer"]
- **Exported Types:** [e.g., "PascalCase"]
- **Private Functions:** [e.g., "camelCase"]
- **Constants:** [e.g., "UPPER_SNAKE_CASE"]
- **Variables:** [e.g., "camelCase"]

**Examples:**
```
✅ Correct: type UserRepository interface { ... }
❌ Incorrect: type user_repository interface { ... }
```

### Error Handling

[From state.analyze.error_patterns]

**Approach:** [e.g., "Error wrapping with fmt.Errorf %w"]

**Pattern:**
```[language]
[Example of correct error handling from project]
```

**Anti-Pattern:**
```[language]
[Example of error handling to avoid]
```

### Logging

[From state.analyze.logging_convention]

**Library:** [library name]

**Format:** [e.g., "Structured JSON or key-value pairs"]

**Level Usage:**
- DEBUG: [when used]
- INFO: [when used]
- WARN: [when used]
- ERROR: [when used]

**Example:**
```[language]
[Real logging example from project]
```

### Testing Conventions

[From state.analyze.testing_style]

**Approach:** [e.g., "Table-driven tests with Testify assertions"]

**Structure:**
```[language]
[Example test structure from project]
```

**Assertion Style:**
- Use [assertion library]: `assert.Equal(t, expected, actual)`
- Coverage pattern: [positive, negative, edge cases]

---
```

### Section 10: Pattern Catalog

```markdown
## Detected Patterns

Architectural and coding patterns identified in the project:

| Pattern | Locations | Frequency | Purpose |
|---------|-----------|-----------|---------|
| [Pattern] | [examples: files/packages] | [# occurrences] | [what it does] |

### Pattern Details

[For each major pattern:]

#### [Pattern Name]

**Description:** [What this pattern is]

**Locations:** [Where used in project]

**Example:**
```[language]
[Code example from project]
```

**Why Used:** [Reasoning for pattern choice in this project]

---
```

### Section 11: Recommendations

```markdown
## Recommendations

Strategic suggestions for agent configuration and project guidance:

| # | Area | Recommendation | Priority | Rationale |
|---|------|-----------------|----------|-----------|
| 1 | [Area] | [Specific recommendation] | [HIGH/MEDIUM/LOW] | [Why this matters] |
| 2 | [Area] | [Specific recommendation] | [HIGH/MEDIUM/LOW] | [Why this matters] |
| 3 | [Area] | [Specific recommendation] | [HIGH/MEDIUM/LOW] | [Why this matters] |

**High-Priority Actions:**
1. [Action 1] — [reason]
2. [Action 2] — [reason]

**Medium-Priority Enhancements:**
1. [Action 1] — [reason]
2. [Action 2] — [reason]

---
```

### Section 12: Next Steps

```markdown
## Next Steps

### For Human Review

1. **Review CLAUDE.md**
   - Check that project name, role, and architecture match your understanding
   - Verify Quick Start instructions are accurate
   - Add any missing context or clarifications

2. **Customize Skills**
   - Review each skill file in `skills/` directory
   - Verify examples match your codebase conventions
   - Add project-specific tips or anti-patterns

3. **Validate Rules**
   - Review each rule file in `rules/` directory
   - Ensure rules accurately capture your project's constraints
   - Add exceptions or special cases as needed

4. **Audit PROJECT-KNOWLEDGE.md**
   - Verify all sections are accurate and complete
   - Add missing technical details or domain knowledge
   - Review metadata and update coverage estimates

### For Agent Configuration

1. **Deploy CLAUDE.md and skills to [target location]**
   - Skills will be auto-loaded when referenced with @skill-name
   - CLAUDE.md is the primary entry point

2. **Test Meta-Agent with Artifacts**
   - Use skills in instructions to validate triggers
   - Check that rules catch violations as expected
   - Verify reference resolution works

3. **Monitor Rule Effectiveness**
   - Track which rules provide most value
   - Adjust rule sensitivity based on feedback
   - Add new rules for patterns as they emerge

### For Ongoing Maintenance

1. **Keep artifacts in sync with codebase evolution**
   - Run analyzer periodically to detect changes
   - Use UPDATE mode to capture new patterns
   - Track technical debt and emerging patterns

2. **Expand skill library**
   - Add skills for new patterns as they're adopted
   - Document domain-specific workflows
   - Create command workflows for complex tasks

3. **Review and refine**
   - Monthly: check if skills/rules are being used
   - Quarterly: deep-dive on new patterns or dependencies
   - Annually: full re-analysis for major changes

---
```

### Section 13: Metadata & Appendix

```markdown
## Analysis Metadata

| Attribute | Value |
|-----------|-------|
| **Files Analyzed** | [count] |
| **Lines Analyzed** | [count] |
| **Packages Found** | [count] |
| **Entry Points** | [count] |
| **Domain Entities** | [count] |
| **Test Files** | [count] |
| **Test Cases** | [~count if estimable] |
| **External Dependencies** | [count] |
| **Analysis Duration** | [time in seconds] |
| **Confidence Score** | [overall %] |

---
```

---

## AUGMENT Mode Report

**For adding guidance to an existing project that already has partial artifacts.**

### Report Header

```markdown
# Project Research Report: [PROJECT_NAME]

**Generated:** [ISO 8601 timestamp]
**Mode:** AUGMENT (Incremental Enhancement)
**Previous Analysis:** [date from existing CLAUDE.md]
**Analyzer:** project-researcher (sonnet)
**Status:** [SUCCESS | PARTIAL | FAILED]

---
```

### Section 1: What's New?

```markdown
## What's New in This Analysis?

Comparison of new findings vs. previous analysis:

### Preserved Artifacts
- ✅ CLAUDE.md (verified, no updates needed)
- ✅ [skill]: [preserved reason]

### New Artifacts
- 🆕 [skill]: [new pattern detected]
- 🆕 [rule]: [new layer discovered]

### Enhanced Artifacts
- 📝 [skill]: [what was added]

---
```

### Section 2: Gap Analysis

```markdown
## Gaps Filled

Previous analysis gaps that have now been filled:

| Gap | Resolution | Artifact |
|-----|-----------|----------|
| [Missing pattern] | [Now documented as] | skills/[name]/skill.md |
| [Unclear rule] | [Clarified with examples] | rules/[layer].md |

---
```

### Section 3: Artifact Status (Abbreviated)

```markdown
## Artifact Status

| Type | Total | New | Updated | Preserved |
|------|-------|-----|---------|-----------|
| Skills | [N] | [N] | [N] | [N] |
| Rules | [N] | [N] | [N] | [N] |
| Docs | [N] | [N] | [N] | [N] |

---
```

### Section 4-8: Same as CREATE mode

(Include architecture, domain, conventions, patterns sections similar to CREATE mode)

### Section 9: Recommendations (Focused)

```markdown
## Recommendations

Focus on gaps and new discoveries:

| # | Area | Recommendation | Priority |
|---|------|-----------------|----------|
| 1 | [New pattern] | Adopt as official convention | HIGH |
| 2 | [Gap] | Document in new skill | MEDIUM |

---
```

### Section 10: Next Steps (Focused)

```markdown
## Next Steps

1. **Review New Skills:** [list new skills added]
2. **Update Rules:** [list updated rules]
3. **Verify Integration:** Test new skills with meta-agent
4. **Merge with Existing:** Integrate new artifacts with your existing library

---
```

---

## UPDATE Mode Report

**For tracking incremental changes in an active project.**

### Report Header

```markdown
# Project Research Report: [PROJECT_NAME]

**Generated:** [ISO 8601 timestamp]
**Mode:** UPDATE (Incremental Analysis)
**Last Update:** [date]
**Current Update:** [date]
**Commits Analyzed:** [N] commits
**Analyzer:** project-researcher (sonnet)
**Status:** [SUCCESS | PARTIAL | FAILED]

---
```

### Section 1: Update Summary

```markdown
## Update Summary

**Period:** [date] to [date] ([days] days)

**Activity Level:**
- Commits: [N]
- Files Changed: [N]
- Lines Added: [N]
- Lines Deleted: [N]

**Analysis Scope:**
- New files: [N]
- Modified files: [N]
- Files affecting architecture: [N]
- Files affecting conventions: [N]

---
```

### Section 2: Changes Detected

```markdown
## Changes Detected

### Architecture
- [If changed]: Pattern shift detected: [from] → [to]
- [If changed]: New layer introduced: [layer]
- [If new]: Entry point added: [entry point]
- [If none]: ✅ Architecture stable

### Conventions
- [If changed]: Naming convention addition: [convention]
- [If changed]: Error handling change: [what changed]
- [If new]: Logging tool integration: [tool]
- [If none]: ✅ Conventions consistent

### Dependencies
- [If new]: External dependency added: [package] ([reason])
- [If removed]: Dependency removed: [package]
- [If changed]: Dependency upgraded: [package] [old] → [new]
- [If none]: ✅ Dependency tree stable

### Testing
- [If new]: New test pattern: [pattern]
- [If changed]: Coverage improvement: [old%] → [new%]
- [If none]: ✅ Testing approach stable

---
```

### Section 3: Updated Sections

```markdown
## Artifacts Updated

[For each modified artifact:]

| Artifact | Changes | Status |
|----------|---------|--------|
| CLAUDE.md | Updated entry point, new skill link | ✅ |
| skills/[name]/skill.md | Added new example from recent commits | ✅ |
| rules/[layer].md | Added new constraint discovered | ✅ |

---
```

### Section 4: Memory Updates

```markdown
## Memory Updates (MCP)

Changes to entity-relationship model:

**New Entities:**
- [Entity]: [description]

**New Relations:**
- [Entity A] uses [Entity B]: [context]

**Removed Entities/Relations:**
- [If applicable]

---
```

### Section 5: Confidence Comparison

```markdown
## Confidence Evolution

How confidence changed since last analysis:

| Area | Previous | Current | Change | Notes |
|------|----------|---------|--------|-------|
| Architecture | HIGH | HIGH | — | Stable pattern |
| Naming | MEDIUM | HIGH | ↑ | More examples |
| Testing | MEDIUM | MEDIUM | — | Still some gaps |
| Logging | HIGH | HIGH | — | Consistent |

**Trend:** [Improving / Stable / Declining / Mixed]

---
```

### Section 6: Recommendations (Delta-Focused)

```markdown
## Recommendations (What's New)

| # | Area | Recommendation | Priority | Impact |
|---|------|-----------------|----------|--------|
| 1 | New pattern | Formalize in skill | HIGH | Prevents divergence |
| 2 | [Change] | Update training data | MEDIUM | Reflects current reality |

---
```

### Section 7: Next Steps

```markdown
## Next Steps

1. **Review Changes:** [list what changed and where]
2. **Update Skills:** Add examples from new patterns
3. **Validate Rules:** Ensure rules still apply to new code
4. **Merge Changes:** Integrate new findings into agent context
5. **Monitor:** Set next update check for [date]

---
```

---

## Confidence Scoring Methodology

Used in all report modes to convey certainty level.

### Overall Confidence Calculation

```
Overall Confidence = (
  Architecture × 3 +
  Conventions × 2 +
  Testing × 2 +
  Errors × 1 +
  Logging × 1
) / 9
```

**Range:** 0-100%

**Thresholds:**
- 80-100%: HIGH (strong evidence, multiple confirmations)
- 60-79%: MEDIUM (good evidence, some gaps)
- 40-59%: MIXED (conflicting signals or partial coverage)
- <40%: LOW (insufficient evidence, high uncertainty)

### Per-Category Confidence Factors

**Architecture (weight: 3x):**
- Evident from directory structure ✅
- Consistent across files ✅
- Documented in comments/readme
- Multiple pattern confirmations

**Conventions (weight: 2x):**
- Consistent naming across [X%] of codebase
- Examples found in [N] locations
- Deviations noted and explained

**Testing (weight: 2x):**
- Test coverage analysis
- Test structure consistency
- Testing framework clarity
- Edge case coverage

**Error Handling (weight: 1x):**
- Error pattern consistency
- Error propagation clarity
- Recovery mechanisms documented

**Logging (weight: 1x):**
- Logging library consistency
- Log level usage clarity
- Structured vs. unstructured logging

### Low-Confidence Flag Criteria

Flag as LOW-CONFIDENCE if:
- <3 examples found for pattern
- <50% of codebase follows convention
- Conflicting patterns detected
- Documentation contradicts code
- Major recent changes (untested patterns)

---

## Output Format

```markdown
# Project Research Report: [Project Name]

[Full report content as per sections above]

---

## Report Metadata

- **Report Generated:** [ISO 8601 timestamp]
- **Report Mode:** CREATE | AUGMENT | UPDATE
- **Confidence:** [X%] (WEIGHTED)
- **Files Analyzed:** [N]
- **Analysis Duration:** [T] seconds
- **Artifacts Generated:** [N]
- **Recommended Review Time:** [Est. minutes]

---
```

---

## Implementation Checklist

- [ ] Mode detection (CREATE vs AUGMENT vs UPDATE)
- [ ] Confidence scoring algorithm
- [ ] Table generation utilities
- [ ] Code example extraction and formatting
- [ ] Changelog/delta detection (for UPDATE mode)
- [ ] Recommendation prioritization
- [ ] Markdown rendering validation
- [ ] Report section templating
- [ ] Timestamp and metadata tracking
- [ ] Output file writing

---

## Quality Standards

- **Clarity:** All technical language explained for non-expert readers
- **Completeness:** No report should have more than 1-2 TBD/TK markers
- **Accuracy:** All code examples must be real (from project, not hallucinated)
- **Actionability:** Every recommendation includes next steps
- **Length:** CREATE mode ≤ 5000 words; AUGMENT/UPDATE ≤ 3000 words
- **Formatting:** Valid markdown, tables render correctly, links resolve
