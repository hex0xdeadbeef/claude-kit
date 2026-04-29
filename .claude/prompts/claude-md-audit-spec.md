meta:
  type: "spec"
  purpose: "Design spec for CLAUDE.md audit — research + balanced cleanup"
  usage: "Approved by user, consumed by /planner"

spec:
  title: "CLAUDE.md Audit and Balanced Cleanup"
  status: "approved"

  context:
    current_state: |
      CLAUDE.md (project root) is 205 lines spanning 10 H2 sections (Language Profile,
      PROJECT-KNOWLEDGE.md Schema, Soft Prerequisites, TDD Policy, Prompt Cache Policy,
      Caveman Token Compression Policy, Error Handling, Rules, Enforcement, Conventions).
      The Caveman section alone is 65 lines (lines 100-164) and contains detailed
      changelog-style content (Files added, Tests, Empirical validation).
      The Enforcement section (lines 191-198) re-narrates settings.json hooks and
      permissions list, which is the authoritative source.
      The Prompt Cache Policy (lines 64-98) embeds env-var explanations that belong
      in settings.local.json.example as comments.
      The Rules table (lines 182-189) duplicates information already living in
      .claude/rules/*.md files.
    motivation: |
      Claude Code official documentation (docs.claude.com/en/docs/claude-code/memory)
      recommends CLAUDE.md "target under 200 lines per CLAUDE.md file. Longer files
      consume more context and reduce adherence." The current file exceeds the
      threshold (205 vs 200). Several sections duplicate content from authoritative
      sources (settings.json for hooks/permissions, SKILL.md files for skill bodies,
      .claude/rules/ for path-scoped rules). Per docs:
      "Settings.json is authoritative and binding; CLAUDE.md is advisory and contextual."
      Workflow + Project-Researcher operation depends only on a small subset of facts
      that need to be in every session. The rest is changelog-style narrative.
    business_value: |
      - Reduce token cost on every Claude Code session
      - Improve adherence (shorter files → better instruction following per docs)
      - Cleaner separation of concerns (config vs. instructions vs. rules vs. skills)
      - Zero risk to phase contracts: handoff schemas, verdict envelopes, issue ID hashing
        all live in their own files (handoff.schema.json, save-review-checkpoint.sh,
        SKILL.md boundary clauses) — CLAUDE.md does NOT participate in those contracts.

  requirements:
    in_scope:
      - "Produce .claude/prompts/claude-md-audit.md — full research report with: (a) artifact graph, (b) per-section verdict + justification, (c) prioritized improvement list, (d) doc-citations to docs.claude.com sources"
      - "Apply all balanced-tier edits to CLAUDE.md after the research is approved by plan-reviewer + code-reviewer"
      - "Move displaced-but-load-bearing content into proper homes (settings.local.json.example comments, existing .claude/rules/, existing SKILL.md files); do NOT create new top-level directories"
      - "Verify all 27 tests in .claude/scripts/tests/ still pass after changes"
      - "Verify phase-handoff contracts remain intact (handoff.schema.json validation, VERDICT_JSON envelopes, canonical issue ID hashing) — these do not depend on CLAUDE.md prose"
      - "Verify check-references.sh PostToolUse hook still passes on the edited CLAUDE.md (canonical .claude/PROJECT-KNOWLEDGE.md path enforcement)"
    out_of_scope:
      - item: "Touch .claude/rules/ files"
        reason: "Rules are path-scoped via Claude Code rules mechanism; modifying them is out of audit scope"
      - item: "Touch .claude/skills/*/SKILL.md bodies"
        reason: "Skills are independent contracts; only the CLAUDE.md narrative referring to them is in scope"
      - item: "Modify settings.json hook list or permissions"
        reason: "Authoritative source; only its summary in CLAUDE.md is in scope"
      - item: "Aggressive cleanup (target ~100 lines)"
        reason: "User selected Balanced; aggressive option deferred to a future workflow"
      - item: "Restructure project layout, agent files, or PROJECT-KNOWLEDGE.md"
        reason: "Audit narrowly targets CLAUDE.md and the displaced-content destinations"
    constraints:
      - "MUST NOT modify .claude/schemas/handoff.schema.json (load-bearing for phase contracts)"
      - "MUST NOT change canonical issue ID hash inputs (`sha256(category|location|problem)[:8]` in save-review-checkpoint.sh)"
      - "MUST NOT alter caveman SKILL.md boundary clauses (verbatim VERDICT_JSON, $handoff_contract, $verdict_contract preservation)"
      - "MUST NOT reduce CLAUDE.md content if removal would break the cascade (PROJECT-KNOWLEDGE.md → CLAUDE.md Language Profile → SKIP). The Language Profile section is consumed at runtime by .claude/scripts/inject-review-context.sh and planner cascade resolution"
      - "All 27 tests in .claude/scripts/tests/ MUST pass post-edit (TEST_CMD: bash .claude/scripts/tests/test-*.sh)"
      - "check-references.sh hook (PostToolUse, fires on Edit(CLAUDE.md)) MUST emit zero PK_PATH bare-reference warnings on the edited file"
      - "Final CLAUDE.md MUST be under 200 lines (Claude Code docs recommendation)"

  approach:
    selected:
      name: "Audit-then-Balanced-Migrate (two-phase write)"
      description: |
        Phase 3a (research): Write .claude/prompts/claude-md-audit.md. Contents:
          (1) Methodology + doc citations
          (2) Inventory: 10 sections × line counts × content-type classification
              (load-bearing fact | duplicated config | changelog | path-scoped rule)
          (3) Artifact interaction graph (CLAUDE.md ↔ settings.json/PK/skills/rules/scripts)
          (4) Per-section verdict (KEEP / TRIM / MIGRATE / DELETE) with justification
              citing docs.claude.com URLs
          (5) Prioritized improvement list with risk classification (LOW/MED/HIGH)
          (6) Contract-preservation checklist
        Phase 3b (apply): Edit CLAUDE.md using Edit tool (one Edit per section). Move
        displaced content to existing files (settings.local.json.example comments for
        Prompt Cache config; the kit-default-template Caveman policy stays in CLAUDE.md
        but trimmed to a load-bearing summary; settings.json reference replaces hook
        and permission narration). Keep the cascade-load-bearing Language Profile
        section intact (it is consumed by inject-review-context.sh).
        Phase 3c (verify): Run all 27 tests, run check-references.sh manually, count
        final lines, check no SKILL.md boundary regressions.
      rationale: |
        Two-phase split (research first, then apply) lets plan-reviewer validate the
        research justification independently from the diff. Research file is permanent
        documentation that survives this PR (lives in .claude/prompts/ alongside other
        spec artifacts). Doc citations make every cut auditable. Balanced tier is
        empirically aligned with the <200 line docs target without aggressive risk to
        load-bearing slots.
    alternatives:
      - option: "Research-only, no edits"
        pros: ["Zero diff risk", "User reviews list at leisure"]
        cons: ["Defers value", "Workflow's coder/reviewer phases run on a no-op"]
        rejected_because: "User explicitly chose Research + apply edits in clarification step"
      - option: "Aggressive cleanup (~100 lines)"
        pros: ["Maximum token savings", "Cleanest separation of concerns"]
        cons: ["High risk of breaking the cascade for Language Profile slots", "Caveman boundary clauses risk losing verbatim narrative needed for cross-iteration ID stability"]
        rejected_because: "User chose Balanced; aggressive removal of Caveman policy section risks subtle byte-stability regression in canonical issue IDs"
      - option: "Inline edits without research file"
        pros: ["Faster", "One artifact"]
        cons: ["No durable rationale for future contributors", "plan-reviewer cannot validate cuts independently"]
        rejected_because: "User explicitly required a detailed research .md with justification per cut"

  key_decisions:
    - decision: "Keep Language Profile section intact (lines 7-15)"
      rationale: "Cascade-load-bearing — consumed by inject-review-context.sh and planner-rules cascade for projects without PROJECT-KNOWLEDGE.md"
      impact: "No reduction in this section; the docs note about kit-vs-consumer is preserved"
    - decision: "Trim PROJECT-KNOWLEDGE.md Schema (lines 17-29) to 5-7 lines"
      rationale: "Implementation detail of /project-researcher governance. The cascade rule (PK > CLAUDE.md > SKIP) is the only fact needed every session. Slot table is reference material for project-researcher agent runs (loaded on-demand, not every session)"
      impact: "Saves ~12 lines. Information preserved in .claude/PROJECT-KNOWLEDGE.md.example header + project-researcher AGENT.md governance"
    - decision: "Trim Soft Prerequisites prose (lines 38-46) but keep tools table"
      rationale: "Strict-mode env paragraph (CLAUDE_HANDOFF_VALIDATION_MODE, CLAUDE_VERDICT_VALIDATION_MODE, CLAUDE_ISSUE_ID_VALIDATION_MODE, CLAUDE_DELTA_REVIEW_MODE) duplicates settings.local.json.example comments. Tools table is needed every session for soft-prerequisite checks"
      impact: "Saves ~25 lines. Move full env-var explanations to settings.local.json.example as block comments"
    - decision: "Compress Prompt Cache Policy (lines 64-98) from 35 lines → ~10 lines"
      rationale: "Most content is config rationale (1H vs 5min cost trade-off). Belongs in settings.local.json.example. CLAUDE.md keeps only the platform-default table and the hash-guard fact"
      impact: "Saves ~25 lines"
    - decision: "Compress Caveman Token Compression Policy (lines 100-164) from 65 lines → ~15 lines"
      rationale: "Multi-paragraph rationale (lite-only justification, files added, test list, empirical validation, references). All these belong in caveman SKILL.md or design docs at .claude/prompts/caveman-skill-integration-spec.md. CLAUDE.md keeps: off-switch + boundaries-verbatim summary + project-local invariant"
      impact: "Saves ~50 lines. Risk: MUST verify caveman SKILL.md still contains full boundary clauses (it does — verified at lines 116-128 of SKILL.md)"
    - decision: "Compress Enforcement section (lines 191-198) from 8 lines → ~3 lines"
      rationale: "Hook list and permission list duplicate settings.json verbatim. CLAUDE.md should reference settings.json as authoritative source"
      impact: "Saves ~5 lines. Reader navigates to settings.json for full list"
    - decision: "Convert ad-hoc maintainer notes to HTML comments where useful"
      rationale: "docs.claude.com confirms <!-- ... --> block comments are stripped before context injection — costs zero tokens but documents intent for human contributors"
      impact: "Optional zero-line-count maintainer notes for displaced content rationale"

  risks:
    - risk: "Removing Caveman boundary content breaks canonical issue ID hash stability across iterations"
      severity: "HIGH"
      mitigation: "Keep the boundaries-verbatim summary block in CLAUDE.md. Run test-caveman-no-regression.sh after edit. The full boundary clauses live in caveman SKILL.md (.claude/skills/caveman/SKILL.md lines 116-128) which is the authoritative source"
    - risk: "Trimming Language Profile breaks plan-reviewer cascade for non-Go projects"
      severity: "HIGH"
      mitigation: "Do NOT trim Language Profile section. Preserve Go-default verbatim — it is the documented kit-default per PROJECT-KNOWLEDGE.md.example"
    - risk: "check-references.sh triggers PK_PATH violations on edited CLAUDE.md"
      severity: "MEDIUM"
      mitigation: "Use only .claude/PROJECT-KNOWLEDGE.md (canonical) — never bare PROJECT-KNOWLEDGE.md. Run check-references.sh manually post-edit"
    - risk: "Test suite regression from reformatting"
      severity: "LOW"
      mitigation: "27 tests in .claude/scripts/tests/ are scoped to scripts and skills, not CLAUDE.md prose. Run full suite at Phase 3c verify step"
    - risk: "User auto-memory references stale CLAUDE.md content"
      severity: "LOW"
      mitigation: "Memory entries reference behavior, not CLAUDE.md prose. No mitigation needed beyond standard practice"

  acceptance_criteria:
    - "AC1: .claude/prompts/claude-md-audit.md exists with 6 required sections (methodology, inventory, graph, per-section verdict, improvement list, contract checklist)"
    - "AC2: Each removal/migration in claude-md-audit.md cites at least one docs.claude.com URL or repo file:line reference"
    - "AC3: CLAUDE.md final line count is under 200 (Claude Code docs threshold) and above 130 (Balanced tier floor)"
    - "AC4: All 27 .claude/scripts/tests/test-*.sh pass with rc=0 after edit (run individually with rc=1 propagation per feedback memory feedback_verify_loop_exit_code.md)"
    - "AC5: check-references.sh emits zero PK_PATH violations on edited CLAUDE.md"
    - "AC6: Caveman boundaries-verbatim summary remains in CLAUDE.md (greppable for at least one of: $handoff_contract, $verdict_contract, VERDICT_JSON)"
    - "AC7: Language Profile section retains LANGUAGE, VERIFY, BUILD, FMT, LINT, TEST, VET, DEPENDENCY_FILE, INSTALL_VERB, ARCHITECTURE_STYLE, LAYER_RULE slot references"
    - "AC8: handoff.schema.json untouched (git diff shows no change)"
    - "AC9: save-review-checkpoint.sh untouched (canonical issue ID hash preserved)"

  notes: |
    Doc citations to use in research file:
      - <https://code.claude.com/docs/en/memory> ("target under 200 lines", "Settings.json is authoritative")
      - <https://code.claude.com/docs/en/skills> (skill body should not be inlined in CLAUDE.md)
      - <https://code.claude.com/docs/en/settings> (settings.json is authoritative for hooks/permissions)
    Block-level HTML comments are stripped before context injection — useful for maintainer notes.
    The kit's own architecture (per PROJECT-KNOWLEDGE.md) is config-as-code, not Go. The Go Language Profile in CLAUDE.md is a kit-default-template for consumer projects. This kit-vs-consumer distinction MUST be preserved in any edits.
    Phase contracts that are NOT in CLAUDE.md (and therefore safe to refactor CLAUDE.md):
      - .claude/schemas/handoff.schema.json (handoff JSON contract)
      - VERDICT_JSON envelopes (defined inline by reviewer agents)
      - Canonical issue ID: `sha256(category|location|problem)[:8]` (save-review-checkpoint.sh)
      - $handoff_contract / $verdict_contract discriminators (validate-handoff.sh)
      - Caveman boundary verbatim clauses (caveman SKILL.md lines 116-128)
