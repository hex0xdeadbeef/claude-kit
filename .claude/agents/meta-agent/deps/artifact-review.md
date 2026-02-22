meta:
  name: artifact-review
  description: |
    Review of a Claude Code artifact plan with automatic fixing.
    Linear workflow with inline reference sections.
  input: "Plan from /artifact-analyst"
  output: "Fixed and approved plan for implementation"
  see: "artifact-quality.md"

workflow: "LOAD → VALIDATE → QUALITY → INTEGRATION → FIX → APPROVE → OUTPUT"

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 1: LOAD PLAN
# ════════════════════════════════════════════════════════════════════════════════
phase_1_load:
  purpose: "Extract data from the artifact-analyst plan"

  steps:
    - step: "1.1 Parse Plan"
      extract:
        - field: "artifact_type"
          from: "Summary → Type"
        - field: "artifact_name"
          from: "Summary → Name"
        - field: "file_path"
          from: "Summary → File"
        - field: "yaml_structure"
          from: "Implementation Plan → YAML"
        - field: "sections_list"
          from: "Implementation Plan → Sections"
        - field: "integration_steps"
          from: "Implementation Plan → Integration"
        - field: "quality_checklist"
          from: "Quality Checklist"

  output_format: |
    ## Phase 1: LOAD — DONE
    - Type: [command/skill/rule/agent]
    - Name: [artifact_name]
    - File: [file_path]
    - Sections: [N items]
    - Integration: [N steps]

  exit_criteria: "All fields extracted, type determined"

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 2: VALIDATE STRUCTURE
# ════════════════════════════════════════════════════════════════════════════════
phase_2_validate:
  purpose: "Check structure against type requirements"

  steps:
    - step: "2.1 Check YAML Fields"
      use_reference: "required_yaml_fields"
      action: "Verify presence of required fields for artifact_type"
      output: "yaml_check: PASS/FAIL + missing_fields[]"

    - step: "2.2 Check Sections"
      use_reference: "required_sections"
      action: "Verify presence of required sections for artifact_type"
      output: "sections_check: PASS/FAIL + missing_sections[]"

  output_format: |
    ## Phase 2: VALIDATE — DONE
    ### YAML Fields
    - Status: [PASS/FAIL]
    - Missing: [list or "none"]

    ### Sections
    - Status: [PASS/FAIL]
    - Missing: [list or "none"]

  exit_criteria: "All required fields and sections checked"

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 3: CHECK QUALITY
# ════════════════════════════════════════════════════════════════════════════════
phase_3_quality:
  purpose: "Evaluate quality against artifact-quality.md criteria"

  steps:
    - step: "3.1 Quality Checklist"
      use_reference: "quality_criteria"
      action: "Check each criterion for artifact_type"
      output:
        criteria_results: "[criterion: PASS/FAIL]"
        quality_score: "X/5"

    - step: "3.2 Identify Issues"
      action: "Collect all FAIL criteria into issues list"
      output:
        issues: "[issue, severity, fix_suggestion]"

  output_format: |
    ## Phase 3: QUALITY — DONE
    ### Checklist
    - [✓/✗] criterion1
    - [✓/✗] criterion2

    ### Score: X/5

    ### Issues Found
    | # | Issue | Severity | Fix |
    |---|-------|----------|-----|
    | 1 | ...   | HIGH     | ... |

  exit_criteria: "Quality score determined, issues list formed"

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 4: CHECK INTEGRATION
# ════════════════════════════════════════════════════════════════════════════════
phase_4_integration:
  purpose: "Verify integration plan"

  steps:
    - step: "4.1 CLAUDE.md Check"
      checks:
        - "Target section for addition specified"
        - "Entry format is correct"
      output: "claude_md_check: PASS/FAIL"

    - step: "4.2 Related Artifacts Check"
      checks:
        - "@skill references are correct"
        - "Related commands specified"
        - "Pipeline position defined (if applicable)"
      output: "related_check: PASS/FAIL"

    - step: "4.3 Settings Check"
      checks:
        - "Permissions defined (if needed)"
      output: "settings_check: PASS/FAIL/N/A"

  output_format: |
    ## Phase 4: INTEGRATION — DONE
    - CLAUDE.md: [PASS/FAIL]
    - Related: [PASS/FAIL]
    - Settings: [PASS/FAIL/N/A]

  exit_criteria: "Integration checklist fully passed"

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 5: FIX ISSUES
# ════════════════════════════════════════════════════════════════════════════════
phase_5_fix:
  purpose: "Automatically fix found issues in the plan"
  rule: "Agent fixes the plan itself, does not reject"

  steps:
    - step: "5.1 Apply Auto-Fixes"
      use_reference: "auto_fix_rules"
      action: "For each issue apply the corresponding fix"
      output:
        fixes_applied: "[issue → fix]"
        remaining_issues: "[issues that cannot be auto-fixed]"

    - step: "5.2 Update Plan"
      action: "Apply corrections to the plan"
      output: "corrected_plan"

  output_format: |
    ## Phase 5: FIX — DONE
    ### Fixes Applied
    | # | Issue | Fix Applied |
    |---|-------|-------------|
    | 1 | ...   | ...         |

    ### Remaining Issues
    - [list or "none"]

  exit_criteria: "All auto-fixable issues resolved"

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 6: APPROVE
# ════════════════════════════════════════════════════════════════════════════════
phase_6_approve:
  purpose: "Make decision on the plan"

  steps:
    - step: "6.1 Evaluate"
      use_reference: "decision_matrix"
      input:
        - quality_score
        - structure_check
        - integration_check
        - remaining_issues
      output: "decision: APPROVED / NEEDS_WORK"

    - step: "6.2 Generate Verdict"
      if_approved:
        - "Add implementation checklist"
        - "Prepare final plan"
      if_needs_work:
        - "Form list of critical issues"
        - "Specify required actions"

  output_format: |
    ## Phase 6: APPROVE — DONE
    - Decision: [APPROVED/NEEDS_WORK]
    - Quality Score: [X/5]
    - Fixes Applied: [N]
    - Remaining Issues: [N]

  exit_criteria: "Decision made: APPROVED or NEEDS_WORK"

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 7: OUTPUT
# ════════════════════════════════════════════════════════════════════════════════
phase_7_output:
  purpose: "Final review result output"

  branch_by_decision:
    approved:
      format: |
        # Artifact Review: APPROVED

        ## Summary
        - Type: [type]
        - Name: [name]
        - File: [path]
        - Quality: [X/5]

        ## Final Plan
        [corrected_plan with all fixes applied]

        ## Implementation Checklist
        - [ ] Create file at [path]
        - [ ] Write YAML frontmatter
        - [ ] Write sections
        - [ ] Update CLAUDE.md
        - [ ] Update settings.json (if needed)
        - [ ] Test invocation

        ---
        **NEXT:** Implement artifact

    needs_work:
      format: |
        # Artifact Review: NEEDS_WORK

        ## Summary
        - Type: [type]
        - Name: [name]
        - Quality: [X/5]

        ## Critical Issues
        | # | Issue | Severity | Required Action |
        |---|-------|----------|-----------------|
        | 1 | ...   | ...      | ...             |

        ## Required Actions
        1. [action1]
        2. [action2]

        ---
        **NEXT:** /artifact-fix or manual revision

  exit_criteria: "Final output formed"

# ════════════════════════════════════════════════════════════════════════════════
# REFERENCE: Quality Criteria (canonical source: artifact-quality.md)
# ════════════════════════════════════════════════════════════════════════════════
quality_criteria:
  ref: "SEE: artifact-quality.md for complete required fields, sections, and criteria by type"
  decision_gate: "Score >= 3/5 (all REQUIRED met) → APPROVED"

# ════════════════════════════════════════════════════════════════════════════════
# REFERENCE: Auto-Fix Rules
# ════════════════════════════════════════════════════════════════════════════════
auto_fix_rules:
  - "Missing YAML field → add placeholder (e.g. name: <artifact-name>)"
  - "Missing section → add outline + TODO markers"
  - "No trigger keywords → add 'Load when:' + keywords to description"
  - "No examples → add EXAMPLES with bad/good/why structure"
  - "No error handling → add errors: {fatal: [...], recoverable: [...]}"
  - "No NEXT reference → add 'NEXT: /next-command' (if pipeline)"
  - "Missing integration → add integration: {claude_md, related: [@skill1, @skill2]}"

# ════════════════════════════════════════════════════════════════════════════════
# REFERENCE: Decision Matrix
# ════════════════════════════════════════════════════════════════════════════════
decision_matrix:
  - conditions:
      quality_score: "4-5"
      structure: "PASS"
      integration: "PASS"
    decision: "APPROVED"

  - conditions:
      quality_score: "3"
      structure: "PASS"
      integration: "PASS"
    decision: "APPROVED (with notes)"

  - conditions:
      quality_score: "<3"
    decision: "NEEDS_WORK"

  - conditions:
      structure: "FAIL"
    decision: "NEEDS_WORK"

  - conditions:
      integration: "FAIL"
    decision: "NEEDS_WORK"

# ════════════════════════════════════════════════════════════════════════════════
# PRINCIPLES
# ════════════════════════════════════════════════════════════════════════════════
principles:
  - id: 1
    name: "Fix, don't reject"
    rule: "Auto-fix where possible, do not reject"

  - id: 2
    name: "Quality gates"
    rule: "Do not pass without minimum quality (3/5)"

  - id: 3
    name: "Integration check"
    rule: "An artifact without integration is useless"

  - id: 4
    name: "Concrete fixes"
    rule: "Specify exactly what and how to fix"

  - id: 5
    name: "Linear workflow"
    rule: "Phases are sequential, do not skip"
