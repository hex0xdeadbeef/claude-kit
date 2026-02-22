# PHASE 7: CRITIQUE (Self-Review)

## 7.1 PURPOSE

**Goal:** Review planned artifacts BEFORE generation to catch issues early.

**When:** After MAP/DATABASE, before GENERATE

**Principle:** Self-review prevents generating low-quality or incorrect artifacts.

---

## 7.2 CRITIQUE CHECKLIST

Review the planned artifact generation against these criteria:

### 7.2.1 Completeness
- [ ] All major architectural patterns identified?
- [ ] All layers/modules mapped?
- [ ] Entry points documented?
- [ ] External dependencies captured?
- [ ] Database schema analyzed (if applicable)?

### 7.2.2 Accuracy
- [ ] Confidence scores realistic?
- [ ] Language detection correct?
- [ ] Framework versions match codebase?
- [ ] No assumptions without evidence?
- [ ] Edge cases considered?

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

## 7.3 COMMON ISSUES TO CATCH

| Issue | Detection | Fix |
|-------|-----------|-----|
| Generic artifacts | Skills like "write tests", "handle errors" | Make project-specific (e.g., "{codegen_tool} query patterns") |
| Missing context | No PROJECT-KNOWLEDGE.md planned | Add comprehensive project map |
| Over-sized CLAUDE.md | Exceeds 200 lines | Move details to skills/rules, keep CLAUDE.md as index |
| Low confidence | Many "LOW" scores in analysis | Add disclaimer, suggest manual review |
| Incomplete coverage | Major patterns/layers missing | Re-run ANALYZE/MAP phases |
| Wrong language | Python detected but project is Go | Re-run DETECT phase |

---

## 7.4 QUESTIONS TO ASK

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

## 7.5 SELF-REVIEW QUESTIONS

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

## 7.6 OUTPUT FORMAT

```
[PHASE 7/9] CRITIQUE -- DONE

### Review Summary
✅ Completeness: All major patterns identified
✅ Accuracy: High confidence (85%) on architecture detection
⚠️ Quality: CLAUDE.md at 220 lines (target: 200) → will split
✅ Relevance: Skills match {codegen_tool} + {db_driver} patterns
✅ Size: Within limits after split

### Issues Found
1. CLAUDE.md exceeds 200 lines
   → Fix: Move database patterns to dedicated skill

2. Generic "error-handling" skill planned
   → Fix: Make project-specific: "repository-error-patterns"

### Plan Adjustments
- Split CLAUDE.md: move DB patterns to skill
- Rename error-handling → repository-error-patterns
- Add 3 code examples to repository-error-patterns

### Confidence After Review
- Overall: HIGH (was MEDIUM)
- Artifacts: 5 planned (was 7, merged 2)
```

---

## 7.7 GATE: CRITIQUE_GATE

**Blocking:** YES

**Conditions to pass:**
- [ ] All checklist items reviewed
- [ ] Issues identified (or explicitly "none found")
- [ ] Plan adjustments documented (or "no changes needed")
- [ ] Confidence level re-assessed

**On failure:**
- Return to ANALYZE or MAP phase
- Fix identified issues
- Re-run CRITIQUE

---

## 7.8 STEP QUALITY

**Checks:**
- [ ] Critique checklist completed
- [ ] ≥1 issue found OR explicit "no issues"
- [ ] Plan adjustments documented
- [ ] Size limits verified

**Min pass:** 4/4 checks

**Output:**
```
Quality: 4/4 checks ✅
```

---

## NEXT PHASE

→ **PHASE 8: GENERATE** (create artifacts)
