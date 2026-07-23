meta:
  type: "plan-template"
  purpose: "Implementation plan template — output of /planner, input to /plan-review"
  usage: "Fill placeholders → save as plan.md → pass to /plan-review"
  language_resolution: |
    Concrete language is resolved from .claude/PROJECT-KNOWLEDGE.md via slots:
    LANG_EXT, LAYERS, DOMAIN_PROHIBIT, ERROR_WRAP, GENERATED_PATTERN, MOCK_PATTERN,
    CONFIG_EXAMPLE, CONFIG_DOCS, VERIFY_CMD, TEST_CMD, LINT_CMD, FMT_CMD.
    See .claude/PROJECT-KNOWLEDGE.md.example for the canonical schema.

plan:
  title: "{Feature Name}"

  context:
    summary: "{Brief description and business value}"

  # ===== IMP-04: optional iter 2+ only =====
  # diff_vs_prior_iteration is OMITTED on iter 1 (no prior plan exists).
  # Present on iter 2+ written by planner phase_0.8_prior_review_digest.
  # plan-reviewer uses this to determine Part-selective validation scope.
  # Section absent -> full validation (backward compat, AC-8).
  diff_vs_prior_iteration:  # OPTIONAL — iter 2+ only
    prior_plan_ref: ".claude/prompts/{feature}.md@iter{N-1}"
    parts_diff:
      - part_id: 1
        name: "{Part name}"
        status: "UNCHANGED"       # [UNCHANGED | NEEDS_UPDATE | NEW]
        reason: "no active issues"
      - part_id: 2
        name: "{Part name}"
        status: "NEEDS_UPDATE"
        reason: "active issues: PR-ab12cd34, PR-ef456789"
      - part_id: 3
        name: "{Part name}"
        status: "NEW"
        reason: "new Part added in iter 2"
  # ===== end IMP-04 =====

  scope:
    in:
      - "{Functionality 1}"
      - "{Functionality 2}"
    out:
      - item: "{What is excluded}"
        reason: "{Why}"

  dependencies:
    blocks: []                # tasks this blocks
    blocked_by: []            # tasks blocking this

  architecture:
    decision: "{Chosen approach — describe if Sequential Thinking was used}"
    alternatives:
      - option: "{Alternative 1}"
        rejected_because: "{Why not chosen}"
      - option: "{Alternative 2}"
        rejected_because: "{Why not chosen}"
    chosen:
      approach: "{Approach}"
      rationale: "{Rationale}"

  parts:
    - part: 1
      name: "{Name}"
      file: "{path/to/file{LANG_EXT}}"   # LANG_EXT resolved from PROJECT-KNOWLEDGE.md
      action: "CREATE"  # CREATE | UPDATE
      description: "{What this part does}"
      code: |
        # FULL implementation in your project's language.
        # See .claude/PROJECT-KNOWLEDGE.md → LANGUAGE for syntax.
        # Comments inside this block describe the code only — never the plan, the Part
        # number, an acceptance criterion, or a review issue. See coder-rules § Comment Policy.
        #
        # <!-- EXAMPLE (lang: go) — for reference only, replace with your language -->
        # package example
        #
        # func Example() {
        #     // ...
        # }
        # <!-- end EXAMPLE -->
        #
        # <!-- EXAMPLE (lang: python) — alternative shape -->
        # def example():
        #     ...
        # <!-- end EXAMPLE -->

    - part: 2
      name: "{Name}"
      file: "{path/to/file{LANG_EXT}}"
      action: "UPDATE"
      description: "{What this part does}"
      code: |
        # full code example in your project's language

    # ===== TDD-always-on note =====
    # /coder loads tdd-rules unconditionally; tests are interleaved per Part
    # via Red-Green-Refactor. Listing a separate "Part N: Tests" block (as
    # below) is OPTIONAL — planners may include it for legacy/documentation
    # purposes, but the actual coder behaviour weaves RGR cycles into earlier
    # Parts. See .claude/skills/tdd-rules/SKILL.md § 'Integration with
    # /coder Parts' for the full contract.
    # ===== end TDD-always-on note =====
    - part: N
      name: "Tests"
      file: "{path/to/{test-file-pattern}}"   # e.g. file_test.go (Go), test_file.py (Python)
      action: "CREATE"
      description: "Tests for new functionality (RGR-interleaved per Part is the default; this entry is OPTIONAL)"
      code: |
        # FULL test in your project's language.
        # See .claude/PROJECT-KNOWLEDGE.md → TEST_GLOB for naming convention.
        #
        # <!-- EXAMPLE (lang: go) — table-driven test pattern -->
        # func TestExample(t *testing.T) {
        #     tests := []struct {
        #         name    string
        #         input   string
        #         want    string
        #         wantErr bool
        #     }{
        #         // ...
        #     }
        #     for _, tt := range tests {
        #         t.Run(tt.name, func(t *testing.T) {
        #             // ...
        #         })
        #     }
        # }
        # <!-- end EXAMPLE -->
        #
        # <!-- EXAMPLE (lang: python) — pytest parametrize pattern -->
        # @pytest.mark.parametrize("input,want,want_err", [...])
        # def test_example(input, want, want_err):
        #     ...
        # <!-- end EXAMPLE -->

  files_summary:
    - file: "{path/to/file1{LANG_EXT}}"
      action: "CREATE"
      description: "{description}"
    - file: "{path/to/file2{LANG_EXT}}"
      action: "UPDATE"
      description: "{description}"

  acceptance_criteria:
    functional:
      - "{Criterion 1}"
      - "{Criterion 2}"
    technical:
      - "{VERIFY_CMD} passes"   # resolved from PROJECT-KNOWLEDGE.md → VERIFY_CMD
      - "{TEST_CMD} passes"
      - "Coverage >= 70%"       # adjust to project standard
      - "No security vulnerabilities"
    architecture:
      - "Import matrix respected (per PROJECT-KNOWLEDGE.md → LAYER_RULE)"
      - "Domain entities follow project's purity rules (per PROJECT-KNOWLEDGE.md → DOMAIN_PROHIBIT)"
      - "Error handling per project conventions (per PROJECT-KNOWLEDGE.md → ERROR_WRAP)"

  config_changes:
    - path: "{CONFIG_EXAMPLE}"  # resolved from PROJECT-KNOWLEDGE.md
      changes: |
        new_section:
          param: value  # description
    - path: "{CONFIG_DOCS}"     # resolved from PROJECT-KNOWLEDGE.md
      changes: "Update configuration table"

  notes: "{Additional notes, edge cases, known limitations}"
