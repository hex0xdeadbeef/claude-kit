# Confidence Scoring Examples

Real-world examples of confidence scoring in project analysis.

---

## SCORING SCALE

| Score | Level | Meaning |
|-------|-------|---------|
| 90-100% | CRITICAL | Absolute certainty (e.g., file exists, import found) |
| 75-89% | HIGH | Strong evidence (e.g., ≥5 examples, clear pattern) |
| 50-74% | MEDIUM | Some evidence (e.g., 2-4 examples, partial pattern) |
| 25-49% | LOW | Weak evidence (e.g., 1 example, assumption) |
| 0-24% | VERY LOW | Guess (e.g., no examples, pure inference) |

**SEE:** `reference/scoring.md` for full algorithm

---

## EXAMPLE 1: Go Clean Architecture Project (HIGH)

### Language Detection
```
Go files: 127
Total files: 148
Percentage: 85.8%
```
**Score:** 98% (CRITICAL)
**Reason:** Clear majority, >80% threshold

### Framework Detection ({codegen_tool})
```
Evidence:
- {codegen_tool} config found ✓
- {codegen_output_dir} directory ✓
- N *_gen.go files ✓
- import "{db_driver}" found in N files ✓
```
**Score:** 100% (CRITICAL)
**Reason:** Config file + generated code + imports

### Architecture Pattern (Clean Architecture)
```
Evidence:
- internal/{domain_layer}/ (N entities) ✓
- internal/{contract_layer}/ (N interfaces) ✓
- internal/{usecase_layer}/ (N use cases) ✓
- internal/{repository_layer}/ (N implementations) ✓
- Dependency flow: {entry_layer} → {usecase_layer} → {contract_layer} ✓
- Zero import violations ✓
```
**Score:** 92% (HIGH)
**Reason:** All layers present, correct dependencies, naming matches

**Overall Confidence:** 87% (HIGH)

---

## EXAMPLE 2: Legacy Python Project (MEDIUM)

### Language Detection
```
Python files: 43
JavaScript files: 18
Total files: 78
Percentage: 55.1%
```
**Score:** 65% (MEDIUM)
**Reason:** Majority but not overwhelming, mixed codebase

### Framework Detection ({http_framework})
```
Evidence:
- {pkg_file} has {http_framework}=={version} ✓
- main file has "from {http_framework} import ..." ✓
- No route decorators found ✗
- No module system usage found ✗
```
**Score:** 58% (MEDIUM)
**Reason:** Import found but no usage patterns

### Architecture Pattern (MVC)
```
Evidence:
- models/ directory (3 files) ✓
- views/ directory (2 files) ✓
- controllers/ directory (0 files) ✗
- Unclear separation ✗
```
**Score:** 42% (LOW)
**Reason:** Partial structure, inconsistent naming

**Overall Confidence:** 51% (MEDIUM)
**Recommendation:** Manual review needed, generated artifacts are starting point

---

## EXAMPLE 3: Greenfield TypeScript Project (LOW)

### Language Detection
```
TypeScript files: 8
Total files: 15
Percentage: 53.3%
```
**Score:** 63% (MEDIUM)
**Reason:** Majority but small sample size

### Framework Detection ({http_framework})
```
Evidence:
- {pkg_file} has "{http_framework}": "{version}" ✓
- {framework_config} found ✓
- Only N controllers found ✗
- No services found ✗
```
**Score:** 48% (LOW)
**Reason:** Config present but minimal usage

### Architecture Pattern
```
Evidence:
- src/ directory exists ✓
- No clear module structure ✗
- No separation of concerns ✗
```
**Score:** 28% (LOW)
**Reason:** Early stage, patterns not yet established

**Overall Confidence:** 34% (LOW)
**Recommendation:** Too early for meaningful artifact generation, suggest manual setup

---

## EXAMPLE 4: Monorepo Java Project (HIGH)

### Language Detection
```
Java files: 312
Kotlin files: 45
Total files: 387
Percentage: 80.6% Java
```
**Score:** 95% (CRITICAL)
**Reason:** Clear majority

### Framework Detection ({http_framework})
```
Evidence:
- {build_file} has {http_framework}-starter ✓
- N @{controller_annotation} annotations ✓
- N @{service_annotation} annotations ✓
- N @{repository_annotation} annotations ✓
- {config_file} found ✓
```
**Score:** 98% (CRITICAL)
**Reason:** Config + widespread annotation usage

### Architecture Pattern (Layered Architecture)
```
Evidence:
- {pkg_root}/{controller_layer}/ (N classes) ✓
- {pkg_root}/{service_layer}/ (N classes) ✓
- {pkg_root}/{repository_layer}/ (N classes) ✓
- {pkg_root}/{domain_layer}/ (N classes) ✓
- Annotations match layers ✓
```
**Score:** 94% (HIGH)
**Reason:** Clear layering, consistent patterns

**Overall Confidence:** 91% (HIGH)

---

## CONFIDENCE FACTORS

### Positive Factors (increase confidence)
- ✅ Config files present (Makefile, Dockerfile, package.json, etc.)
- ✅ Multiple examples of pattern (≥5 files)
- ✅ Consistent naming conventions
- ✅ Clear directory structure
- ✅ Generated code markers ({codegen_tool}, etc.)
- ✅ Import statements match expectations
- ✅ Test files mirror source structure

### Negative Factors (decrease confidence)
- ❌ Mixed languages/frameworks
- ❌ Inconsistent patterns
- ❌ Small codebase (<10 files)
- ❌ Legacy/unmaintained code
- ❌ Missing config files
- ❌ No clear entry point
- ❌ Monorepo ambiguity (which module to analyze?)

---

## ADJUSTMENT RULES

### Sample Size Penalty
- <10 files: -20% confidence
- 10-30 files: -10% confidence
- >30 files: no penalty

### Pattern Consistency Bonus
- 100% consistent: +10% confidence
- 80-99% consistent: +5% confidence
- <80% consistent: no bonus

### Evidence Multiplier
- Config file only: 1.0x base score
- Config + imports: 1.2x base score
- Config + imports + usage: 1.5x base score
- Config + imports + usage + tests: 1.8x base score

---

## EXAMPLE CALCULATIONS

### {codegen_tool} Detection

**Base Evidence:**
- {codegen_tool} config exists: 40 points
- Generated files found: 30 points
- Imports found: 20 points
- Usage in repository layer: 10 points

**Total:** 100 points = 100% (CRITICAL)

### {http_framework} Detection (Legacy)

**Base Evidence:**
- {pkg_file} entry: 40 points
- Import statement: 20 points
- No usage patterns found: -10 points
- Inconsistent structure: -5 points

**Total:** 45 points = 45% (LOW)

**Adjustment:**
- Small sample (12 files): -10%
- Legacy code penalty: -5%

**Final:** 30% (LOW)

---

## INTERPRETING SCORES

### HIGH (75-100%)
- ✅ Trust generated artifacts
- ✅ Minimal manual review needed
- ✅ Strong evidence for decisions

### MEDIUM (50-74%)
- ⚠️ Use as starting point
- ⚠️ Manual review recommended
- ⚠️ Some uncertainty remains

### LOW (25-49%)
- ❌ Manual setup preferred
- ❌ Artifacts are educated guesses
- ❌ Significant adjustments likely

### VERY LOW (<25%)
- 🚫 Do not generate artifacts
- 🚫 Insufficient evidence
- 🚫 Manual investigation required

---

## REPORTING CONFIDENCE

In REPORT phase, always include:

1. **Overall confidence** (weighted average)
2. **Per-category breakdown** (language, framework, architecture)
3. **Evidence summary** (what we found)
4. **Limitations** (what we couldn't determine)
5. **Recommendations** (trust level, review needed?)

**Example Report:**
```
Overall Confidence: 87% (HIGH)

Breakdown:
- Language Detection: 98% (CRITICAL) - Clear Go majority
- Framework Detection: 91% (HIGH) - {codegen_tool} + {db_driver} confirmed
- Architecture: 92% (HIGH) - Clean Architecture verified
- Database Alignment: 100% (CRITICAL) - Perfect entity-table mapping

Evidence:
- N Go files analyzed
- {codegen_tool} config + N generated files
- N {layer} interfaces match pattern
- 0 dependency violations

Limitations:
- Plugin system patterns unclear (only 2 examples)
- E2E test coverage not analyzed

Recommendations:
✅ Generated artifacts ready to use
⚠️ Manually document plugin system
```
