# PHASE 7: CRITIQUE (Self-Adversarial Review)

## 7.1 PURPOSE

**Goal:** Adversarial review planned artifacts BEFORE generation. Not just checking boxes — actively looking for counterarguments and weak spots.

**When:** After MAP/DATABASE, before GENERATE

**Required state:** `state.detect.*`, `state.analyze.*`, `state.map.*`

**Outputs:** `state.critique`

**SEE:** `deps/state-contract.md` for the full state schema.

**Principle:** A checklist catches obvious problems. Adversarial review catches what the checklist misses — overcalibration, confirmation bias, false confidence.

---

## 7.2 CRITIQUE CHECKLIST

Review the planned artifact generation against these criteria:

### 7.2.1 Completeness
- [ ] All major architectural patterns identified?
- [ ] All layers/modules mapped?
- [ ] Entry points documented?
- [ ] External dependencies captured?
- [ ] Database schema analyzed (if applicable)?
- [ ] Dependency graph built (if Go project)?
- [ ] Monorepo modules discovered (if applicable)?

### 7.2.2 Accuracy
- [ ] Confidence scores realistic?
- [ ] Language detection correct?
- [ ] Framework versions match codebase?
- [ ] No assumptions without evidence?
- [ ] Edge cases considered?
- [ ] AST vs grep detection methods recorded correctly?

### 7.2.3 Quality
- [ ] CLAUDE.md will be ≤200 lines?
- [ ] Skills focus on real patterns (not generic)?
- [ ] Rules match actual project structure?
- [ ] PROJECT-KNOWLEDGE.md comprehensive but not bloated?
- [ ] No duplicate information across artifacts?

### 7.2.4 Relevance
- [ ] Generated artifacts match project needs?
- [ ] Skills target actual pain points?
- [ ] Rules cover common operations?
- [ ] No over-engineering for simple projects?
- [ ] No under-engineering for complex projects?

---

## 7.3 ADVERSARIAL REVIEW (NEW v3.0)

**Principle:** Force yourself to argue *against* your own conclusions. If you cannot find counterarguments — the conclusions are likely correct. If you can — they need refinement.

### 7.3.1 Devil's Advocate Questions

Answer each question **in detail**, do not dismiss with "no issues":

1. **"Name 3 things that a senior developer on this project would consider inaccurate in my analysis."**
   - Think about domain knowledge you do not have
   - Think about implicit conventions not expressed in code
   - Think about decisions whose context you do not know (legacy constraints, business requirements)

2. **"What is the most important aspect of the project I may have missed?"**
   - Check: does the project have `.env.example`, `docker-compose.yml`, `Makefile` — they often contain key information about workflows
   - Check: README.md, CONTRIBUTING.md — do they describe patterns you did not find?
   - Check: CI/CD configs — what testing/deployment steps are used?

3. **"If my architecture detection were wrong — what alternative is most likely?"**
   - For `state.analyze.architecture`:
     - If detected Clean Architecture → could it be Layered with good organization?
     - If detected Layered → could it be Clean Architecture with non-standard names?
     - If detected DDD → are there real aggregates or just CRUD with pretty names?
   - Provide specific evidence for the alternative

4. **"Which conventions did I assume to be a project standard even though they occur <5 times?"**
   - For each convention in `state.analyze.conventions` — how many times does it actually occur?
   - Example: "fmt.Errorf %w" — if found 3 times out of 50 error handling sites, this is not a convention

5. **"Which artifacts am I generating out of inertia rather than necessity?"**
   - Is a @logging skill needed for a project with 10 files?
   - Are rules needed for every layer if there are only 2 layers?
   - Is memory.json needed if the project is trivial?

### 7.3.2 Alternative Architecture Analysis

For the current `state.analyze.architecture`, perform a counter-check:

```
DETECTED: Clean Architecture (confidence: 0.88)

COUNTER-CHECK:
  Alternative 1: Layered Architecture
    Evidence FOR:  service/, repository/, handler/ structure
    Evidence AGAINST: ports/adapters pattern, interface segregation
    Verdict: REJECTED (insufficient evidence)

  Alternative 2: Modular Monolith
    Evidence FOR:  internal/<module>/ structure, module boundaries
    Evidence AGAINST: no cross-module APIs, shared domain layer
    Verdict: REJECTED (no module isolation)

CONCLUSION: Clean Architecture confirmed. Alternatives lack evidence.
```

**If an alternative has ≥40% evidence → lower the confidence of the primary variant.**

---

## 7.4 CONFIDENCE CALIBRATION (NEW v3.0)

### 7.4.1 Overcalibration Detection

Compare claimed confidence with the amount of supporting data:

```
FOR each finding in [architecture, conventions, patterns]:
    IF finding.confidence > 0.8 AND finding.evidence_count < 5:
        WARN: "OVERCALIBRATED: {finding} has confidence {confidence} but only {evidence_count} evidence points"
        ACTION: Lower confidence to min(confidence, evidence_count * 0.15 + 0.1)

    IF finding.confidence > 0.9 AND finding.detection_method == "grep":
        WARN: "HIGH CONFIDENCE FROM GREP: {finding} — grep-based detection rarely warrants >0.9"
        ACTION: Cap confidence at 0.85 for grep-based detections

    IF finding.confidence < 0.5 AND finding.evidence_count > 10:
        WARN: "UNDERCALIBRATED: {finding} has low confidence but {evidence_count} evidence points"
        ACTION: Raise confidence to max(confidence, min(evidence_count * 0.08, 0.85))
```

### 7.4.2 Evidence Count Rules

| State Field | Min Evidence for HIGH (>0.8) | Min for MEDIUM (>0.6) |
|-------------|------------------------------|----------------------|
| architecture | 5 indicators (dirs + AST + imports) | 3 indicators |
| conventions.errors | 10 occurrences in code | 5 occurrences |
| conventions.logging | 8 occurrences | 4 occurrences |
| conventions.testing | 5 test files with pattern | 3 test files |
| frameworks (each) | manifest + usage in code | manifest only |
| layer detection | interfaces + implementations + imports | directory structure only |

### 7.4.3 Calibration Output

```
### Confidence Calibration
| Finding | Claimed | Evidence | Calibrated | Change |
|---------|---------|----------|------------|--------|
| architecture: clean | 0.88 | 7 indicators | 0.88 | — |
| conventions.errors: %w | 0.90 | 3 occurrences | 0.55 | ⚠️ OVERCALIBRATED |
| conventions.logging: slog | 0.85 | 45 occurrences | 0.85 | — |
| framework: chi | 0.95 | manifest+AST | 0.95 | — |
| layer: domain | 0.90 | dir+12 ifaces | 0.90 | — |
```

---

## 7.5 COMMON ISSUES TO CATCH

| Issue | Detection | Fix |
|-------|-----------|-----|
| Generic artifacts | Skills like "write tests", "handle errors" | Make project-specific (e.g., "{codegen_tool} query patterns") |
| Missing context | No PROJECT-KNOWLEDGE.md planned | Add comprehensive project map |
| Over-sized CLAUDE.md | Exceeds 200 lines | Move details to skills/rules, keep CLAUDE.md as index |
| Low confidence | Many "LOW" scores in analysis | Add disclaimer, suggest manual review |
| Incomplete coverage | Major patterns/layers missing | Re-run ANALYZE/MAP phases |
| Wrong language | Python detected but project is Go | Re-run DETECT phase |
| Overcalibrated | High confidence, few evidence points | Run calibration, lower confidence |
| Confirmation bias | Only looked for evidence supporting initial hypothesis | Run adversarial review |
| Missing dep graph | Go project but no dependency metrics | Re-run MAP phase with `go list` |

---

## 7.6 QUESTIONS TO ASK

1. **Simplest solution?**
   - Am I generating too many artifacts?
   - Can I merge similar skills/rules?

2. **Missing edge cases?**
   - What if database unavailable?
   - What if mixed languages?
   - What if legacy code inconsistent?

3. **Size within limits?**
   - CLAUDE.md ≤200 lines?
   - Skills ≤600 lines?
   - Rules ≤200 lines?

4. **Duplication with existing?**
   - In AUGMENT mode: conflicts with existing artifacts?
   - Are we regenerating what already exists?

---

## 7.7 SELF-REVIEW QUESTIONS

**For CREATE mode:**
- Is artifact set minimal but sufficient?
- Does CLAUDE.md serve as clear index?
- Are skills based on ≥3 real examples?

**For AUGMENT mode:**
- Am I preserving existing artifacts?
- Am I filling gaps, not replacing?
- Are recommendations clear?

**For UPDATE mode:**
- Are changes incremental (not full rewrite)?
- Is change history updated?
- Are only affected sections updated?

---

## 7.8 OUTPUT FORMAT

```
[PHASE 6/10] CRITIQUE — DONE
State: critique.gate_passed=true, issues=2, calibration_adjustments=1

### Checklist Summary
✅ Completeness: All major patterns identified
✅ Accuracy: High confidence (85%) on architecture detection
⚠️ Quality: CLAUDE.md at 220 lines (target: 200) → will split
✅ Relevance: Skills match {codegen_tool} + {db_driver} patterns
✅ Size: Within limits after split

### Adversarial Review
Q1 (Senior would disagree):
  1. Error handling pattern detected as "%w wrapping" but project also uses sentinel errors extensively — skill should cover both
  2. "Clean Architecture" label may be misleading — project uses ports/adapters but naming is non-standard
  3. Missing: project has custom middleware chain pattern not captured in any skill

Q2 (Most important missed aspect):
  CI/CD pipeline uses integration tests with testcontainers — this pattern not captured in testing skill

Q3 (Alternative architecture):
  Alternative: Layered Architecture — REJECTED (evidence score: 2/7 vs 7/7 for Clean)

Q4 (Weak conventions):
  ⚠️ conventions.errors: "%w wrapping" found only 3 times out of 50 error sites → OVERCALIBRATED

Q5 (Unnecessary artifacts):
  Rule "cmd-layer" removed — only 1 cmd/ entry point, rule adds no value

### Confidence Calibration
| Finding | Claimed | Evidence | Calibrated | Change |
|---------|---------|----------|------------|--------|
| architecture: clean | 0.88 | 7 indicators | 0.88 | — |
| conventions.errors | 0.90 | 3 occurrences | 0.55 | ⚠️ -0.35 |
| conventions.logging | 0.85 | 45 occurrences | 0.85 | — |

### Issues Found
1. CLAUDE.md exceeds 200 lines
   → Fix: Move database patterns to dedicated skill

2. Error handling convention overcalibrated
   → Fix: Lower confidence, document both %w and sentinel patterns

### Plan Adjustments
- Split CLAUDE.md: move DB patterns to skill
- Expand error-handling skill to cover both patterns
- Add testcontainers pattern to testing skill
- Remove cmd-layer rule (unnecessary)

### Confidence After Review
- Overall: HIGH (was MEDIUM, improved after calibration honesty)
- Artifacts: 5 planned (was 7, merged 2, removed 1)
```

---

## 7.9 GATE: CRITIQUE_GATE

**Blocking:** YES

**Conditions to pass:**
- [ ] All checklist items reviewed
- [ ] Adversarial review completed (all 5 questions answered)
- [ ] Confidence calibration run
- [ ] Issues identified (or explicitly "none found after adversarial review")
- [ ] Plan adjustments documented (or "no changes needed")
- [ ] Confidence level re-assessed with calibration data

**On failure:**
- Return to ANALYZE or MAP phase
- Fix identified issues
- Re-run CRITIQUE

---

## 7.10 STEP QUALITY

**Checks:**
- [ ] Critique checklist completed
- [ ] Adversarial review: all 5 questions answered with specifics (not "no issues")
- [ ] Confidence calibration: all findings checked against evidence count
- [ ] ≥1 issue found OR explicit "no issues after adversarial review"
- [ ] Plan adjustments documented
- [ ] Size limits verified

**Min pass:** 6/6 checks

**Output:**
```
Quality: 6/6 checks ✅
```

---

## NEXT PHASE

→ **PHASE 7: GENERATE** (create artifacts)
