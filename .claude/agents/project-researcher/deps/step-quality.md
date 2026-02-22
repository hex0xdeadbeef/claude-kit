# Step Quality (Process Reward)

**Purpose:** Evaluate quality after each phase, catch errors early.

**Principle:** Early detection prevents cascading failures.

**Load when:** Implementing quality checks or debugging phase failures.

---

## STEP QUALITY (Process Reward)

### Per-Phase Quality Checks

Each phase defines quality checks in format:

```yaml
step_quality:
  checks:
    - "Check 1 description"
    - "Check 2 description"
    - "Check 3 description"
  min_pass: N  # Minimum checks to pass
```

### Output Format

After each phase:
```
Quality: {passed}/{total} checks ✅
```

### Example Checks

**DETECT phase:**
- [ ] Primary language detected (≥60% files)
- [ ] ≥1 framework identified
- [ ] Build tool found

**ANALYZE phase:**
- [ ] Architecture pattern identified
- [ ] ≥3 layers detected
- [ ] Import violations checked

**CRITIQUE phase:**
- [ ] All checklist items reviewed
- [ ] ≥1 issue found OR explicit "none"
- [ ] Size limits verified

**VERIFY phase:**
- [ ] YAML syntax valid
- [ ] All references exist
- [ ] Sizes within limits
- [ ] Structure complete

### Benefits

- **Early failure detection**: Catch issues before GENERATE
- **Quality metrics**: Track improvement over time
- **Debugging**: Identify which phase failed

**SEE:** meta-agent v7.0 STEP_QUALITY for full specification
