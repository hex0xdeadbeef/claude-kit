# PHASE 8: VERIFY (Post-Generation Validation)

## 8.1 PURPOSE

**Goal:** Validate generated artifacts AFTER creation to ensure quality.

**When:** After GENERATE, before REPORT

**Principle:** External validation catches errors that self-review misses.

---

## 8.2 EXTERNAL VALIDATION

### 8.2.1 YAML Syntax Check

**Tool:** Ruby/Python YAML parser

```bash
# Test YAML validity
for file in .claude/skills/*/SKILL.md .claude/commands/*.md .claude/rules/*.md; do
  # Extract YAML frontmatter (between --- markers)
  ruby -e "require 'yaml'; YAML.load_file('$file')" 2>&1
done
```

**Check:**
- [ ] All YAML frontmatter valid
- [ ] No syntax errors
- [ ] All required fields present

**On failure:**
- Fix YAML syntax errors
- Re-run validation

---

### 8.2.2 Reference Validation

**Check all references point to existing resources:**

```bash
# Check file references
grep -r "SEE:\|phases/\|reference/\|templates/\|deps/" .claude/ | \
  while read ref; do
    # Verify file exists
    [ -f "$ref" ] || echo "BROKEN: $ref"
  done

# Check skill references (@skill-name)
grep -r "@[a-z-]\\+" .claude/ | \
  while read skill; do
    # Verify skill exists in .claude/skills/
    [ -d ".claude/skills/$skill" ] || echo "MISSING SKILL: $skill"
  done
```

**Check:**
- [ ] All `phases/` references exist
- [ ] All `reference/` references exist
- [ ] All `templates/` references exist
- [ ] All `@skill` references exist
- [ ] All `deps/` references exist (if applicable)

**On failure:**
- Fix broken references
- Remove non-existent references
- Re-run validation

---

### 8.2.3 Size Check

**Verify artifacts within size limits:**

| Artifact Type | Warning | Critical |
|---------------|---------|----------|
| CLAUDE.md | 150 lines | 200 lines |
| Skill | 500 lines | 600 lines |
| Rule | 150 lines | 200 lines |
| Command | 400 lines | 500 lines |

```bash
# Check sizes
wc -l .claude/CLAUDE.md
wc -l .claude/skills/*/SKILL.md
wc -l .claude/rules/*.md
```

**Check:**
- [ ] CLAUDE.md ≤200 lines
- [ ] All skills ≤600 lines
- [ ] All rules ≤200 lines

**On failure:**
- Split oversized artifacts
- Move details to deps/ or reference/
- Re-run validation

---

### 8.2.4 Structure Validation

**Verify required sections per artifact type:**

**CLAUDE.md required sections:**
- [ ] Role / project description section
- [ ] Tech Stack section
- [ ] Architecture section
- [ ] Commands section (table)
- [ ] Quick Start section

**Skill required sections:**
- [ ] YAML frontmatter with `name`, `triggers`
- [ ] Examples or patterns

**Rule required sections:**
- [ ] YAML frontmatter with `name`, `patterns`
- [ ] When section
- [ ] Constraints

```bash
# Check CLAUDE.md sections
grep "^## " .claude/CLAUDE.md

# Check skill frontmatter
for skill in .claude/skills/*/SKILL.md; do
  head -20 "$skill" | grep "^name:\|^triggers:"
done
```

**Check:**
- [ ] All required sections present
- [ ] Section order logical
- [ ] No missing headers

**On failure:**
- Add missing sections
- Reorder for clarity
- Re-run validation

---

### 8.2.5 Duplicate Check

**Semantic similarity check across artifacts:**

```bash
# Check for duplicate skills (similar names)
ls .claude/skills/*/SKILL.md | xargs -I {} basename $(dirname {}) | sort | uniq -c | grep -v "^\s*1"

# Check for overlapping triggers
grep "^triggers:" .claude/skills/*/SKILL.md | sort
```

**Check:**
- [ ] No duplicate skill names
- [ ] No overlapping triggers (same keywords)
- [ ] No redundant rules (same patterns)

**On failure:**
- Merge duplicate skills
- Remove redundant artifacts
- Re-run validation

---

## 8.3 VALIDATION CHECKLIST

### Functional Checks
- [ ] All planned artifacts created?
- [ ] File permissions correct (readable)?
- [ ] Directory structure correct?

### Technical Checks
- [ ] YAML syntax valid (8.2.1)
- [ ] References exist (8.2.2)
- [ ] Sizes within limits (8.2.3)
- [ ] Structure correct (8.2.4)
- [ ] No duplicates (8.2.5)

### Content Checks
- [ ] Skills based on real code examples?
- [ ] Rules match actual project paths?
- [ ] CLAUDE.md reflects project accurately?
- [ ] No generic placeholders left?
- [ ] Confidence scores documented?

---

## 8.4 OUTPUT FORMAT

```
[PHASE 8/9] VERIFY -- DONE

### External Validation
| Check | Status | Details |
|-------|--------|---------|
| YAML Syntax | ✅ | All valid |
| References | ✅ | All exist |
| Size | ⚠️ | CLAUDE.md at 195 lines (limit: 200) |
| Structure | ✅ | All sections present |
| Duplicates | ✅ | No duplicates found |

### Quality Metrics
- Artifacts created: 5
- Total lines: 1,247
- Avg confidence: 82% (HIGH)
- Validation errors: 0

### Size Report
| File | Lines | Status |
|------|-------|--------|
| CLAUDE.md | 195 | ✅ Within limit |
| skill/database-patterns | 487 | ✅ Within limit |
| skill/error-handling | 312 | ✅ Within limit |
| rule/repository-layer | 156 | ✅ Within limit |
| rule/usecase-layer | 143 | ✅ Within limit |

### Issues Found
None - all validations passed ✅

Quality: PASSED
```

---

## 8.5 GATE: EXTERNAL_VALIDATION_GATE

**Blocking:** YES

**Conditions to pass:**
- [ ] All YAML valid
- [ ] All references exist
- [ ] All sizes within limits
- [ ] All required sections present
- [ ] No critical duplicates

**On failure:**
- Fix validation errors
- Re-run VERIFY phase
- Do NOT proceed to REPORT until PASSED

---

## 8.6 STEP QUALITY

**Checks:**
- [ ] External validation completed
- [ ] All 5 validation types run
- [ ] Issues documented (or "none")
- [ ] Quality metrics collected

**Min pass:** 4/4 checks

**Output:**
```
Quality: 4/4 checks ✅
Gate: EXTERNAL_VALIDATION_GATE PASSED
```

---

## 8.7 COMMON ISSUES

| Issue | Cause | Fix |
|-------|-------|-----|
| YAML parse error | Broken frontmatter | Fix YAML syntax, re-test |
| Broken @skill reference | Skill not generated | Generate missing skill or remove ref |
| CLAUDE.md too large | Too much detail | Move to skills/rules |
| Missing sections | Template not followed | Add required sections |
| Duplicate skills | Similar names | Merge or rename |

---

## NEXT PHASE

→ **PHASE 9: REPORT** (final summary)
