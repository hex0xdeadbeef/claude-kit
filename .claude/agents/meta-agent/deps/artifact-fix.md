meta:
  name: artifact-fix
  description: |
    Fix a Claude Code artifact based on review results.
    Linear workflow with inline reference sections.
  input: "Issues from /artifact-review or code review"
  output: "Fixed artifact + changelog"
  see: "artifact-quality.md"

workflow: "LOAD → PRIORITIZE → FIX → VERIFY → OUTPUT → INTEGRATE → MEMORY → LESSONS → FINAL"

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 1: LOAD ISSUES
# ════════════════════════════════════════════════════════════════════════════════
phase_1_load:
  purpose: "Load the list of issues from the source"

  steps:
    - step: "1.1 Parse Issues"
      sources:
        - "/artifact-review output"
        - "code review comments"
        - "manual issue list"
      extract:
        - field: "issue_id"
        - field: "issue_description"
        - field: "severity"
        - field: "location"
        - field: "fix_required"

    - step: "1.2 Build Issues Table"
      format:
        columns: ["#", "Issue", "Severity", "Location", "Fix Required"]

  output_format: |
    ## Phase 1: LOAD — DONE
    ### Issues Table
    | # | Issue | Severity | Location | Fix |
    |---|-------|----------|----------|-----|
    | 1 | ...   | ...      | ...      | ... |

    - Total: [N] issues

  exit_criteria: "All issues extracted and recorded in the table"

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 2: PRIORITIZE
# ════════════════════════════════════════════════════════════════════════════════
phase_2_prioritize:
  purpose: "Determine the order of fixes"

  steps:
    - step: "2.1 Sort by Severity"
      use_reference: "severity_levels"
      order: "CRITICAL → HIGH → MEDIUM → LOW"

    - step: "2.2 Check Stop Conditions"
      rule: "If CRITICAL/HIGH cannot be fixed → STOP"
      output: "can_proceed: true/false"

  output_format: |
    ## Phase 2: PRIORITIZE — DONE
    ### Fix Order
    1. [CRITICAL issues]
    2. [HIGH issues]
    3. [MEDIUM issues]
    4. [LOW issues]

    - Can proceed: [YES/NO]

  exit_criteria: "Order determined, stop conditions checked"

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 3: FIX
# ════════════════════════════════════════════════════════════════════════════════
phase_3_fix:
  purpose: "Apply fixes to the artifact"

  steps:
    - step: "3.1 For Each Issue (by priority)"
      actions:
        - "Find location in the file"
        - "Apply fix (use Edit tool)"
        - "Record in changelog"

    - step: "3.2 Apply Fix Patterns"
      use_reference: "fix_patterns"
      for_each_issue:
        - "Match issue type to fix pattern"
        - "Apply pattern"
        - "Record change"

  output_format: |
    ## Phase 3: FIX — DONE
    ### Changes Applied
    | # | Issue | Fix Applied | Status |
    |---|-------|-------------|--------|
    | 1 | ...   | ...         | ✅     |

    ### Changelog
    ```diff
    - old content
    + new content
    ```

  exit_criteria: "All HIGH/CRITICAL fixed, changelog recorded"

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 4: VERIFY
# ════════════════════════════════════════════════════════════════════════════════
phase_4_verify:
  purpose: "Verify that the fixes work"

  steps:
    - step: "4.1 Re-check Quality"
      action: "Run the checklist from artifact-quality.md"
      format:
        columns: ["Criterion", "Before", "After"]
      output: "quality_delta"

    - step: "4.2 Verify Each Fix"
      format:
        columns: ["#", "Issue", "Fixed", "Verified"]
      action: "Verify that each fix actually resolves the issue"

  output_format: |
    ## Phase 4: VERIFY — DONE
    ### Quality Score
    - Before: [X/5]
    - After: [Y/5]

    ### Verification
    | # | Issue | Fixed | Verified |
    |---|-------|-------|----------|
    | 1 | ...   | ✅    | ✅       |

  exit_criteria: "Quality score improved, all fixes verified"

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 5: OUTPUT
# ════════════════════════════════════════════════════════════════════════════════
phase_5_output:
  purpose: "Generate the fix report"

  steps:
    - step: "5.1 Generate Report"
      sections:
        - "Issues Fixed (table)"
        - "Changelog (diff format)"
        - "Quality Score (before/after)"
        - "Status: FIXED / PARTIAL / BLOCKED"

    - step: "5.2 Determine Next Action"
      decision:
        if_fixed: "→ Phase 6 (INTEGRATE)"
        if_blocked: "→ Stop and report to user"
        if_partial: "→ Report partial + continue to Phase 6"

  output_format: |
    ## Phase 5: OUTPUT — DONE
    ### Summary
    - Issues Fixed: [N/M]
    - Quality: [before] → [after]
    - Status: [FIXED/PARTIAL/BLOCKED]

  exit_criteria: "Report generated, next action determined"

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 6: INTEGRATE
# ════════════════════════════════════════════════════════════════════════════════
phase_6_integrate:
  purpose: "Automatically perform integration after FIXED status"
  rule: "Executed automatically, without user confirmation"

  steps:
    - step: "6.1 Update CLAUDE.md"
      action: "Add/update entry in the corresponding section"
      sections:
        command: "commands section"
        skill: "skills section"
        rule: "path rules section"
        agent: "agents section"

    - step: "6.2 Update settings.json"
      when: "artifact requires permissions"
      format: "permissions.allow: [Skill(<name>)]"

    - step: "6.3 Update Related Artifacts"
      actions:
        - "Add @<name> reference in related skills"
        - "Add to pipeline description if part of a pipeline"
        - "Update triggers in description of related artifacts"

    - step: "6.4 Integration Checklist"
      verify:
        - "CLAUDE.md updated (section)"
        - "settings.json updated (if needed)"
        - "Related artifacts updated"

  output_format: |
    ## Phase 6: INTEGRATE — DONE
    - CLAUDE.md: ✅ [section]
    - settings.json: ✅/➖
    - Related: ✅ [list]

  exit_criteria: "All integration steps completed and verified"

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 7: SAVE TO MEMORY
# ════════════════════════════════════════════════════════════════════════════════
phase_7_memory:
  purpose: "Save artifact information to MCP memory"
  rule: "Knowledge persistence between sessions"

  steps:
    - step: "7.1 Create Entity"
      tool: "mcp__memory__create_entities"
      entity:
        type: "claude-artifact-<type>"
        name: "<artifact-name>"
        observations:
          - "Type: command|skill|rule|agent"
          - "File: .claude/<type>s/<name>.md"
          - "Purpose: <brief description>"
          - "Created: <YYYY-MM-DD>"
          - "Triggers: <when to use>"
          - "Related: <related artifacts>"

    - step: "7.2 Create Relations"
      tool: "mcp__memory__create_relations"
      relation_types:
        uses: "Artifact uses another (@skill reference)"
        triggers: "Artifact invokes another (NEXT: /command)"
        extends: "Artifact extends functionality of another"
        part_of: "Artifact is part of a pipeline"

  output_format: |
    ## Phase 7: MEMORY — DONE
    - Entity: ✅ <name>
    - Relations: ✅ [N] created

  exit_criteria: "Entity and relations created in MCP memory"

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 8: LESSONS LEARNED
# ════════════════════════════════════════════════════════════════════════════════
phase_8_lessons:
  purpose: "Save lessons for self-improvement"
  integration: "→ meta-agent.md#self_improvement — self-improvement integration"

  capture_when:
    - "Fix required multiple iterations"
    - "Issue was recurring (seen before)"
    - "Fix revealed a pattern worth remembering"

  lesson_format:
    trigger: "What caused the issue"
    mistake: "What was wrong in artifact"
    fix: "How it was fixed"
    artifact_type: "command | skill | rule | agent"
    date: "YYYY-MM-DD"

  save_to_memory:
    tool: "mcp__memory__add_observations"
    entity: "meta-agent-lesson-{date}"

  output_format: |
    ## Phase 8: LESSONS — DONE
    - Lessons captured: {N}
    - Saved to MCP memory: ✅

  exit_criteria: "Lessons saved to MCP memory"

# ════════════════════════════════════════════════════════════════════════════════
# PHASE 9: FINAL OUTPUT
# ════════════════════════════════════════════════════════════════════════════════
phase_9_final:
  purpose: "Final result output"

  format: |
    # Artifact Fix Complete: [Name]

    ## Summary
    - Type: [type]
    - File: [path]
    - Status: INTEGRATED

    ## Issues Fixed
    | # | Issue | Status |
    |---|-------|--------|
    | 1 | ...   | ✅     |

    ## Integration
    - CLAUDE.md: ✅ Added to [section]
    - settings.json: ✅/➖
    - Related: ✅ [list]

    ## Memory
    - Entity: ✅ [name]
    - Relations: ✅ [N]
    - Lessons: ✅ [N] saved

    ## Next Steps
    - Test invocation: `/<command>` or load `@<skill>`
    - Verify in new session

  exit_criteria: "Final report output"

# ════════════════════════════════════════════════════════════════════════════════
# REFERENCE: Severity Levels
# ════════════════════════════════════════════════════════════════════════════════
severity_levels:
  - level: "CRITICAL"
    description: "Blocks artifact usage"
    must_fix: true
    examples:
      - "Missing required YAML field"
      - "Syntax error in YAML"
      - "No workflow defined"

  - level: "HIGH"
    description: "Violates quality criteria"
    must_fix: true
    examples:
      - "No examples section"
      - "No trigger phrases in description"
      - "Missing autonomy rule (for agent)"

  - level: "MEDIUM"
    description: "Quality improvement"
    must_fix: false
    examples:
      - "Too long (>500 lines)"
      - "No forbidden section"
      - "Missing recommended fields"

  - level: "LOW"
    description: "Nice to have"
    must_fix: false
    examples:
      - "Formatting issues"
      - "Minor typos"
      - "Could add more examples"

# ════════════════════════════════════════════════════════════════════════════════
# REFERENCE: Fix Patterns
# ════════════════════════════════════════════════════════════════════════════════
fix_patterns:
  - issue: "Missing YAML field"
    fix: "Add field with correct value"
    tool: "Edit"
    example:
      before: |
        meta:
          description: "..."
      after: |
        meta:
          name: artifact-name
          description: "..."

  - issue: "Missing section"
    fix: "Add section with content from research"
    tool: "Edit"
    template: |
      section_name:
        - item1
        - item2

  - issue: "Wrong structure"
    fix: "Restructure per artifact-quality.md template"
    tool: "Write (full rewrite)"

  - issue: "No examples"
    fix: "Add 2-3 examples from codebase"
    tool: "Edit"
    template: |
      examples:
        pattern_name:
          bad: "wrong code"
          good: "correct code"
          why: "explanation"

  - issue: "No trigger phrases in description"
    fix: "Add trigger phrases — format depends on artifact type"
    tool: "Edit"
    note: |
      Skills use Anthropic standard format (frontmatter description).
      Commands/agents use YAML description field.
    template_skill: |
      # In YAML frontmatter (--- delimiters):
      description: What this skill does. Use when user asks about "trigger phrase 1",
        "trigger phrase 2", or works with [domain]. Keywords: kw1, kw2.
    template_other: |
      # In YAML description field:
      description: |
        Purpose...

        Load when:
        - Condition 1
        Keywords: keyword1, keyword2

  - issue: "Integration missing"
    fix: "Add INTEGRATION section"
    tool: "Edit"
    template: |
      integration:
        claude_md: "section"
        settings_json: "if needed"
        related: ["@skill1"]

  - issue: "Error handling missing"
    fix: "Add ERROR HANDLING section"
    tool: "Edit"
    template: |
      errors:
        fatal:
          - "condition → stop"
        recoverable:
          - "condition → retry"

# ════════════════════════════════════════════════════════════════════════════════
# PRINCIPLES
# ════════════════════════════════════════════════════════════════════════════════
principles:
  - id: 1
    name: "Targeted edits"
    rule: "Only what is specified in issues — do not refactor the entire file"

  - id: 2
    name: "Verify after fix"
    rule: "Verify that the fix works before moving on"

  - id: 3
    name: "Document all"
    rule: "Record everything in changelog for audit"

  - id: 4
    name: "Escalate blockers"
    rule: "If you cannot fix it — report it, do not stay silent"

  - id: 5
    name: "Linear workflow"
    rule: "Phases are sequential, do not skip"

# ════════════════════════════════════════════════════════════════════════════════
# FORBIDDEN
# ════════════════════════════════════════════════════════════════════════════════
forbidden:
  - action: "Adding new functionality"
    why: "Only what is specified in issues"

  - action: "Refactoring unrelated code"
    why: "Targeted edits, minimal scope"

  - action: "Changing structure if not requested"
    why: "Minimal changes for the fix"

  - action: "Deleting existing content without reason"
    why: "Preserve everything that works"
