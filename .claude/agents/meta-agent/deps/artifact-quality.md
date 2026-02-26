# artifact-quality — Quality Criteria for Claude Code Artifacts (YAML-first)

meta:
  name: artifact-quality
  description: |
    Quality criteria for Claude Code artifacts (commands, skills, rules, agents).
    YAML-first approach for maximum LLM parsing efficiency.

    Load when:
    - Auditing .claude/ infrastructure
    - Creating commands, skills, rules, agents
    - Reviewing artifact quality
    - Keywords: quality, audit, review

ai_first_principles:
  core_rule: "All files are for LLM, not for humans"

  format_priority:
    - format: "pure YAML"
      when: "commands, agents — configuration, structured data"
      why: "maximum structure, no ambiguity"

    - format: "YAML frontmatter (---) + Markdown body"
      when: "skills (Anthropic standard) AND rules (Claude Code standard)"
      why: |
        Skills: Claude loads frontmatter (name, description) into system prompt, body when skill is active.
        Rules: Claude loads frontmatter (paths:) for conditional scoping, body as instructions.
      note: "Skills and rules are EXCEPTIONS to YAML-only — they follow their respective platform specs"

    - format: "AVOID pure markdown prose"
      when: "commands, agents (NOT skills, NOT rules)"
      why: "ambiguous, poorly parsed by LLM for command/agent artifact types"

  structure_rules:
    - rule: "triggers with if/then"
      example: |
        triggers:
          - if: "condition"
            then: "action"

    - rule: "examples with bad/good/why"
      example: |
        examples:
          pattern_name:
            bad: "wrong code"
            good: "correct code"
            why: "explanation"

    - rule: "forbidden with action/why"
      example: |
        forbidden:
          - action: "what not to do"
            why: "reason"

  metrics:
    yaml_structure: "> 80% content in YAML structure"
    prose_max: "< 10% prose text"
    applies_to: "commands, agents only (skills and rules use Markdown body — different metrics)"
    code_examples: "always bad/good pairs"
    triggers: "explicit if/then patterns"

  size_effectiveness:
    principle: "Smaller is better IF quality preserved"
    critical_insight: |
      Size alone is NOT the metric.
      EFFECTIVENESS = Quality / Size
      High-value sections (examples, lessons_learned) should NEVER be removed.
      Low-value duplication SHOULD be removed.

    baselines:
      command:
        median: "~300 lines / ~12k bytes"
        warning: "> 500 lines OR > 20k bytes"
        critical: "> 800 lines OR > 35k bytes"
      skill:
        median: "~450 lines / ~13k bytes"
        warning: "> 600 lines OR > 18k bytes"
        critical: "> 700 lines OR > 25k bytes"
      rule:
        median: "~100 lines / ~4k bytes"
        warning: "> 200 lines OR > 8k bytes"
        critical: "> 400 lines OR > 15k bytes"

    token_budget:
      single_artifact: "< 10k tokens"
      with_claude_md: "< 15k tokens total"
      why: "Artifacts load together, total context matters"
      formula: "tokens ≈ bytes / 4 (for YAML/code)"

    high_value_sections:
      preserve_always:
        - section: "examples (bad/good/why)"
          why: "Teaches LLM correct patterns"
        - section: "lessons_learned"
          why: "Real project experience, prevents repeated mistakes"
        - section: "forbidden"
          why: "Critical guardrails"
      can_optimize:
        - section: "decision_trees"
          how: "Reference @skill for details, keep unique logic"
        - section: "skills_by_layer"
          how: "Reference CLAUDE.md triggers, avoid duplication"
        - section: "mcp_by_phase"
          how: "Inline into phases, remove separate section"

progressive_offloading:
  purpose: "Split large artifacts to reduce base context load"
  when: "artifact exceeds WARNING threshold"
  principle: "Core file stays small, details loaded on demand via Read"

  skill_pattern:
    note: |
      Skills use Anthropic standard format: YAML frontmatter (---) + Markdown body.
      NOT the YAML-only format used by commands/agents.
      See: templates/skill.md, "The Complete Guide to Building Skills for Claude"

    structure:
      - file: "SKILL.md"
        max_lines: 300
        format: "YAML frontmatter (---) + Markdown body"
        contains:
          frontmatter: ["name (kebab-case)", "description ([What]+[When]+[Capabilities])"]
          body: ["# Title", "## Instructions (steps)", "## Rules", "## Examples (good/bad/why)", "## Common Issues"]
      - dir: "references/"
        max_lines: 300
        purpose: "detailed docs — linked from SKILL.md Markdown body via relative path"
      - dir: "scripts/"
        purpose: "EXECUTED by Bash, NOT loaded into context"
        examples: ["validate.sh", "check-style.py"]
      - dir: "assets/"
        purpose: "templates, fonts, icons — used in output"

    reference_syntax_in_skill: |
      In Markdown body of SKILL.md:
        For detailed API patterns, see `references/api-patterns.md`.
        Run `scripts/validate.sh` to check output format.

    example_before: |
      my-skill/
      └── SKILL.md (700 lines) ← exceeds critical

    example_after: |
      my-skill/
      ├── SKILL.md (300 lines)          # frontmatter + Instructions + Rules + Examples + Common Issues
      ├── references/
      │   └── advanced-patterns.md       # detailed docs, linked from SKILL.md
      └── scripts/
          └── validate.sh               # executed, not loaded

  command_pattern:
    structure:
      - file: "commands/<name>.md"
        max_lines: 300
        contains: ["workflow", "output", "references to deps/"]
      - file: "agents/<name>/deps/"
        purpose: "patterns, checklists, templates — loaded via Read"

    reference_syntax_in_command: |
      references:
        patterns: ".claude/agents/<name>/deps/patterns.md"
        checklist: ".claude/agents/<name>/deps/checklist.md"

    example_before: |
      commands/
      └── my-command.md (1000 lines) ← exceeds critical

    example_after: |
      commands/
      └── my-command.md (300 lines)  # workflow, references

      agents/my-command/
      └── deps/
          ├── patterns.md (400 lines)   # detection patterns
          └── checklist.md (200 lines)  # validation checklist

  key_distinction:
    reference_md: "Loaded into context via Read tool when needed"
    scripts: "EXECUTED via Bash, output returned, file NOT in context"

    duplication_detection:
      check_against:
        - "CLAUDE.md triggers section"
        - "Related @skills"
        - "Other artifacts in same domain"
      threshold: "< 10% overlap acceptable"
      action_on_duplication: |
        1. Identify duplicated content
        2. Keep in PRIMARY location (usually CLAUDE.md or specific skill)
        3. Replace in artifact with reference: "see @skill-name" or "see CLAUDE.md"
        4. Verify reference is clear and findable

artifact_quality:
  constitution_ref: "deps/artifact-constitution.md"  # P1-P5 universal principles, P6-P7 domain-specific per type

  command:
    required:
      - field: "description"
        in: "YAML frontmatter"
      - field: "workflow"
        format: "numbered steps"
      - field: "output"
        format: "expected result"

    recommended:
      - "examples with arguments"
      - "NEXT command reference"
      - "@skill references"

    domain_principles:
      P6: "executability — every workflow step has explicit tool/action"
      P7: "composability — output format + NEXT + @skills + exit codes"
      ref: "deps/artifact-constitution.md#domain_principles.per_type.command"  # command domain principles

    template: |
      ---
      description: What this command does
      ---

      workflow:
        - step: 1
          action: "do X"
        - step: 2
          action: "do Y"

      output:
        format: "description"
        example: "sample output"

  skill:
    note: |
      Skills use Anthropic standard format: YAML frontmatter (---) + Markdown body.
      This is DIFFERENT from commands/agents/rules which use YAML-only.
      Source: "The Complete Guide to Building Skills for Claude" (Anthropic, 2026)
      Template: templates/skill.md

    required:
      - field: "name"
        in: "YAML frontmatter (--- delimiters)"
        format: "kebab-case, no spaces, no capitals, matches folder name"
      - field: "description"
        in: "YAML frontmatter (--- delimiters)"
        format: "[What it does] + [When to use it] + [Key capabilities]"
        note: "Include trigger phrases users would actually say. Under 1024 chars."
      - field: "## Instructions"
        in: "Markdown body"
        format: "Step-by-step with ### Step N headers"
      - field: "## Examples"
        in: "Markdown body"
        format: "Good/Bad code blocks with **Why:** explanation"

    recommended:
      - "< 600 lines (warning threshold)"
      - "## Rules section (MUST-DO / MUST-NOT-DO)"
      - "## Common Issues section (troubleshooting)"
      - "references/ dir for detailed docs (progressive disclosure)"

    domain_principles:
      P6: "trigger_coverage — all use-cases + negative triggers + overlap"
      P7: "example_depth — bad/good/why for every non-trivial pattern"
      ref: "deps/artifact-constitution.md#domain_principles.per_type.skill"  # skill domain principles

    template: |
      ---
      name: skill-name
      description: What this skill does. Use when user asks about "trigger phrase 1",
        "trigger phrase 2", or works with [domain]. Keywords: kw1, kw2.
      ---

      # Skill Name

      ## Instructions

      ### Step 1: Identify what's needed
      Clear explanation of what happens.

      ### Step 2: Apply the pattern
      Concrete, actionable instructions.

      ## Rules

      - ALWAYS do X
      - NEVER do Y

      ## Examples

      ### Pattern Name

      **Good:**
      ```lang
      correct code
      ```

      **Bad:**
      ```lang
      wrong code
      ```
      **Why:** explanation

      ## Common Issues

      ### Error or problem
      **Cause:** why it happens
      **Fix:** how to resolve

      forbidden:
        - action: "what not to do"
          why: "reason"

  rule:
    note: |
      Rules use Claude Code standard format: YAML frontmatter (---) + Markdown body.
      This is DIFFERENT from commands/agents which use YAML-only.
      Rules WITHOUT frontmatter are loaded globally for all files.
      Source: https://code.claude.com/docs/en/memory
      Template: templates/rule.md

    required:
      - field: "paths"
        in: "YAML frontmatter (--- delimiters) — OPTIONAL, omit for global rules"
        format: "YAML list with QUOTED glob patterns"
        note: "Glob patterns MUST be quoted (YAML parsing issue with * and {})"
      - field: "## Checklist"
        in: "Markdown body"
        format: "3-7 actionable, verifiable items"
      - field: "# Title + description"
        in: "Markdown body"
        format: "H1 heading + 1-2 sentence description"

    recommended:
      - "## Forbidden section with Bad/Good code examples"
      - "## References with @skill links"
      - "## Exceptions (when rule does NOT apply)"

    domain_principles:
      P6: "specificity — precise paths, clear scope boundary, no overlap"
      P7: "enforcement — automatable checks, hook-ready"
      ref: "deps/artifact-constitution.md#domain_principles.per_type.rule"  # rule domain principles

    template: |
      ---
      paths:
        - "internal/{layer}/**/*.go"
      ---

      # Rule Name

      Brief description of what these rules cover.

      ## Checklist

      - Specific, actionable check item 1
      - Specific, actionable check item 2

      ## Forbidden

      ### What not to do
      **Why:** reason

      **Bad:**
      ```go
      wrong code
      ```

      **Good:**
      ```go
      correct code
      ```

      ## References

      - See `@skill-name` for detailed patterns

  agent:
    required:
      - field: "name, description, tools"
        in: "YAML frontmatter"
      - field: "autonomy_rule"
        format: "when to stop"
      - field: "input/output"
        format: "expected formats"
      - field: "workflow"
        format: "phases"

    recommended:
      - "error handling"
      - "progress tracking"

    domain_principles:
      P6: "autonomy_bounds — explicit stop conditions, escalation, failure modes"
      P7: "observability — every phase produces visible progress output"
      ref: "deps/artifact-constitution.md#domain_principles.per_type.agent"  # agent domain principles

    template: |
      ---
      name: agent-name
      description: What agent does
      tools: [Read, Write, Bash]
      ---

      autonomy_rule: "Run until: condition"

      input:
        format: "expected arguments"

      output:
        format: "what agent produces"

      workflow:
        - phase: 1
          name: "Phase Name"
          steps: ["step1", "step2"]

      errors:
        fatal: ["condition1"]
        recoverable: ["condition2"]

rating_scale:
  - rating: "5/5 Excellent"
    criteria: "All REQUIRED + all RECOMMENDED + YAML-first"

  - rating: "4/5 Good"
    criteria: "All REQUIRED + 50% RECOMMENDED"

  - rating: "3/5 Acceptable"
    criteria: "All REQUIRED"

  - rating: "2/5 Needs Work"
    criteria: "Missing 1-2 REQUIRED"

  - rating: "1/5 Poor"
    criteria: "Missing 3+ REQUIRED or prose-heavy"

audit_format:
  template: |
    artifact_audit:
      name: "[artifact name]"
      type: "command | skill | rule | agent"
      file: ".claude/[path]"
      rating: "[1-5]/5"

      checklist:
        - item: "YAML frontmatter"
          status: "pass | fail"
        - item: "triggers/if-then"
          status: "pass | fail"
        - item: "examples bad/good"
          status: "pass | fail"

      issues:
        - issue: "description"
          severity: "HIGH | MEDIUM | LOW"
          fix: "how to fix"

      recommendations:
        - "recommendation 1"
        - "recommendation 2"

common_issues:
  all_types:
    - issue: "Prose-heavy (> 20%)"
      severity: "HIGH"
      fix: "Convert to YAML structure with triggers/examples"

    - issue: "No bad/good examples"
      severity: "MEDIUM"
      fix: "Add examples section with bad/good/why"

    - issue: "Markdown headers instead of YAML keys"
      severity: "MEDIUM"
      applies_to: "commands, agents (NOT skills, NOT rules)"
      fix: "Use YAML structure, not ## headers"
      note: "Skills and rules are exempt — they use frontmatter + Markdown body format"

    - issue: "Artifact too large (> critical threshold)"
      severity: "HIGH"
      fix: |
        1. Run baseline comparison: wc -l .claude/{type}s/*.md | sort -n
        2. Identify duplication with CLAUDE.md/skills
        3. Remove duplicated sections, add references
        4. Keep examples and lessons_learned (high-value)
        5. Consider splitting if > 800 lines

    - issue: "Duplication with CLAUDE.md triggers"
      severity: "MEDIUM"
      fix: "Replace duplicated triggers with: 'see CLAUDE.md triggers section'"

    - issue: "Duplication with related skills"
      severity: "MEDIUM"
      fix: "Replace duplicated patterns with: 'see @skill-name for details'"

    - issue: "Removed high-value sections (examples, lessons_learned)"
      severity: "CRITICAL"
      fix: "RESTORE immediately — these sections teach LLM correct patterns"

    - issue: "Added content without measuring impact"
      severity: "MEDIUM"
      fix: "Always measure before/after: wc -l && wc -c"

  commands:
    - issue: "No description"
      severity: "HIGH"
      fix: "Add YAML frontmatter with description:"

  skills:
    - issue: "No trigger phrases in description"
      severity: "HIGH"
      fix: |
        Description must follow: [What it does] + [When to use it] + [Key capabilities].
        Include phrases users would actually say. Example:
          description: Go error handling patterns. Use when user asks about
            "wrap errors", "error types". Keywords: error, wrap, sentinel.

    - issue: "Missing --- frontmatter delimiters"
      severity: "CRITICAL"
      fix: "SKILL.md MUST have --- delimiters. Without them Claude won't load the skill."

    - issue: "YAML-only without Markdown body"
      severity: "HIGH"
      fix: |
        Skills use Anthropic standard format: YAML frontmatter + Markdown body.
        Body must have: ## Instructions (steps), ## Examples (good/bad/why).
        See templates/skill.md for correct format.

    - issue: "Too long (> 600 lines)"
      severity: "HIGH"
      fix: "Move detailed docs to references/ dir, keep SKILL.md under 300 lines"

  rules:
    - issue: "Missing --- frontmatter delimiters (for path-scoped rules)"
      severity: "CRITICAL"
      fix: "Add --- delimiters with paths: YAML list. Glob patterns MUST be quoted."

    - issue: "YAML body instead of Markdown"
      severity: "HIGH"
      fix: |
        Rules use Claude Code format: frontmatter (paths:) + Markdown body.
        Body must have: ## Checklist (actionable items), ## Forbidden (Bad/Good examples).
        See templates/rule.md for correct format.

    - issue: "Unquoted glob patterns in paths:"
      severity: "HIGH"
      fix: "Quote all glob patterns: '\"src/**/*.ts\"' not 'src/**/*.ts' (YAML parsing issue)"

    - issue: "No checklist or vague items"
      severity: "MEDIUM"
      fix: "Add ## Checklist with 3-7 specific, verifiable items"

  agents:
    - issue: "No autonomy rule"
      severity: "HIGH"
      fix: "Add autonomy_rule: when to stop"

integration_checklist:
  - "Added to CLAUDE.md (appropriate section)"
  - "Cross-references (@skill links from related artifacts)"
  - "settings.json (if tools/permissions needed)"
  - "Tested (invoke and verify)"
  - "beads: bd create → bd close → bd sync"

# ════════════════════════════════════════════════════════════════════════════════
# EXTERNAL VALIDATION (merged from external-validation.md)
# When: VERIFY phase, after APPLY | Gate: EXTERNAL_VALIDATION_GATE (blocking)
# Principle: Intrinsic self-correction often fails — external feedback required
# ════════════════════════════════════════════════════════════════════════════════
external_validation:
  pipeline:
    yaml_validation:
      checks: ["valid YAML syntax", "frontmatter present with required fields", "spaces only (no tabs)", "consistent 2-space indent"]
      tool: "inline parse"
      on_fail: "❌ YAML VALIDATION FAILED — fix syntax before proceeding"

    reference_validation:
      checks: ["all .claude/**/*.md paths exist (Glob)", "@skill refs point to real skills (Grep)", "deps/ paths exist", "no broken internal links"]
      on_fail: "❌ BROKEN REFERENCES — list broken refs, suggest fixes"

    size_validation:
      thresholds: "See size_effectiveness.baselines above"
      token_estimate: "lines * 10 (rough)"
      on_warning: "⚠️ Consider split into deps/ (progressive loading)"
      on_critical: "❌ MUST split before proceeding → deps/artifact-quality.md#progressive_offloading"

    structure_validation:
      command: {required: ["description in frontmatter", "workflow section", "output section"]}
      skill: {required: ["name+description in frontmatter", "trigger keywords"], max: 700}
      rule:
        required: ["## Checklist in Markdown body (3-7 actionable items)", "# Title + description in Markdown body"]
        optional: ["paths in YAML frontmatter (omit for global rules)"]
        note: "Rules use frontmatter + Markdown body, NOT YAML-only. See templates/rule.md"
      agent: {required: ["name+description+tools in frontmatter", "autonomy rule", "workflow section"]}
      on_fail: "❌ STRUCTURE FAILED — list missing sections, reference template"

    duplicate_detection:
      method: ["Extract key terms", "Search mcp__memory for similar", "Grep .claude/ for patterns"]
      threshold: "70% term overlap = potential duplicate"
      on_found: "⚠️ POTENTIAL DUPLICATE — suggest merge or differentiate"

  summary_format: |
    | Check | Status | Details |
    |-------|--------|---------|
    | YAML Syntax | ✅/❌ | {details} |
    | References | ✅/❌ | {broken_count} broken |
    | Size | ✅/⚠️/❌ | {lines} lines |
    | Structure | ✅/❌ | {missing} |
    | Duplicates | ✅/⚠️ | {similar_count} |
    Overall: {PASSED/FAILED}
