# Step Quality (Process Reward)

purpose: "Evaluate quality after each phase, catch errors early"
enabled: true

## Phase Criteria

### EXPLORE
checks:
  - "PROJECT-KNOWLEDGE.md read"
  - "Current artifact content loaded"
  - "≥1 relevant skill/pattern identified"
min_pass: 3
on_fail: "Repeat EXPLORE with broader search"

### RESEARCH
checks:
  - "Found ≥3 code examples"
  - "Identified patterns documented"
  - "Similar artifacts checked"
min_pass: 3
on_fail: "Expand search scope, try different keywords"

### PLAN
checks:
  - "All changes are specific (file, section, content)"
  - "Size estimation within threshold"
  - "No duplication with existing artifacts"
  - "Dependencies identified"
min_pass: 4
on_fail: "Revise plan with more specificity"

### CRITIQUE
checks:
  - "All self-review questions answered"
  - "Issues documented or explicitly 'none found'"
  - "Improvements proposed if applicable"
min_pass: 3
on_fail: "Cannot proceed — complete self-review"

### APPLY
checks:
  - "All planned changes applied"
  - "YAML syntax valid"
  - "No broken references"
min_pass: 3
on_fail: "Fix issues before VERIFY"

## Early Termination

trigger: "2 consecutive phases fail quality check"
action: |
  ⚠️ QUALITY DEGRADATION DETECTED
  Last good phase: {phase}
  Issues: {list}
  Recommend: Review approach or ask user for clarification
  [Continue anyway / Stop and review]

## Output Format

output_per_phase: |
  Quality: {passed}/{total} checks ✅
