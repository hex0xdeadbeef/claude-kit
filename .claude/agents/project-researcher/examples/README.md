# Examples Directory

Sample outputs and demonstrations for project-researcher agent.

---

## Contents

| File | Description |
|------|-------------|
| [sample-report.md](sample-report.md) | Complete REPORT phase output for Go Clean Architecture project |
| [confidence-scoring.md](confidence-scoring.md) | Real-world confidence scoring examples with calculations |

---

## Purpose

These examples demonstrate:

1. **Expected output quality** - What a successful run produces
2. **Confidence scoring** - How scores are calculated and interpreted
3. **Edge cases** - How agent handles different project types
4. **Quality metrics** - What "HIGH" vs "MEDIUM" vs "LOW" means

---

## Using Examples

### For Users
- Review `sample-report.md` to understand what to expect
- Check `confidence-scoring.md` to interpret your project's scores
- Use as reference when evaluating generated artifacts

### For Developers
- Use as test fixtures for regression testing
- Compare actual outputs against samples
- Update when output format changes

---

## Adding Examples

When adding new examples:

1. **Use real projects** (anonymized if needed)
2. **Show edge cases** (monorepos, mixed languages, legacy code)
3. **Include confidence scores** with evidence breakdown
4. **Document limitations** (what wasn't detected)

---

## Related

- `../subagents/report.md` - REPORT subagent specification
- `../reference/scoring.md` - Confidence scoring algorithm
- `../templates/project-knowledge.md` - PROJECT-KNOWLEDGE.md structure
