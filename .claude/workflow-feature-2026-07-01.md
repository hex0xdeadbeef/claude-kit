# Workflow Feature — Eliminate stray `.claude/` directories in working projects (2026-07-01)

> Concrete Задача: during `/workflow` runs, `.claude/` directories appear in random
> places inside user projects (Go projects etc). Root-cause, design, fix.
> Empirical, no false-positives. Artifact for phases 1–5; phase 6 = per-part XL cycles.

## Scope

artifacts_touched:
  hook_scripts_relative_state_write:   # PRIMARY (proven, machine-level) defect surface
    - .claude/scripts/auto-fmt.sh
    - .claude/scripts/pre-commit-build.sh
    - .claude/scripts/protect-files.sh
    - .claude/scripts/check-uncommitted.sh
    - .claude/scripts/session-analytics.sh
    - .claude/scripts/save-review-checkpoint.sh
    - .claude/scripts/track-task-lifecycle.sh
    - .claude/scripts/inject-review-context.sh
    - .claude/scripts/enrich-context.sh
    - .claude/scripts/save-progress-before-compact.sh
    - .claude/scripts/verify-state-after-compact.sh
    - .claude/scripts/audit-config-change.sh
    - .claude/scripts/log-permission-denied.sh
    - .claude/scripts/log-stop-failure.sh
    - .claude/scripts/sync-agent-memory.sh
  reference_only_already_anchored:     # Class A — the blessed pattern, DO NOT touch
    - .claude/scripts/log-tool-failure.sh        # anchored + guarded (test-log-tool-failure-default-path.sh)
    - .claude/scripts/caveman-activate.sh
    - .claude/scripts/mcp-preload-warn.sh
    - .claude/scripts/notify-workflow-complete.sh
    - .claude/scripts/validate-handoff.sh
    - .claude/scripts/inject-kit-context.sh      # uses PROJECT_ROOT=${CLAUDE_PROJECT_DIR:-$PWD}
    - .claude/scripts/bootstrap-project-config.sh
  canonical_helper:
    - .claude/scripts/lib/paths.sh               # documents canonical anchor form (no code change needed)
  new_test_artifacts:
    - .claude/scripts/tests/test-*-default-path.sh    # per-part behavioral repro
    - .claude/scripts/tests/test-no-relative-claude-state-paths.sh   # global grep invariant
  secondary_vector_UNVERIFIED:
    - .claude/commands/{planner,coder,designer,workflow}.md   # model-driven Write to relative .claude/ (24+ refs)
    - .claude/skills/{coder-rules,planner-rules,workflow-protocols}/*.md

excluded_out_of_scope:
    - meta-agent, project-researcher, db-explorer   # not on hot path (per Scope constraint)
    - settings.json / hooks.json hook wiring        # NOT changed — contract-safe

## Architecture Decision

root_cause:
  statement: >
    ~15 hook scripts define their state/log/memory directory as a RELATIVE path
    (`.claude/workflow-state`, `.claude/prompts`, `.claude/agent-memory`) and never
    reference ${CLAUDE_PROJECT_DIR}. Claude Code runs hook handlers "in the current
    directory" (docs: code.claude.com/docs/en/hooks), NOT pinned to project root. When
    the coder or any Bash command `cd`s into a subdirectory, subsequent hooks fire with
    cwd=<subdir>, so `mkdir -p .claude/workflow-state` creates a stray `.claude/` there.
  origin: >
    Commit 4a51150 "feat(plugin): Part 2 — B2 path-awareness" introduced the canonical
    anchor `${CLAUDE_WORKFLOW_STATE_DIR:-${CLAUDE_PROJECT_DIR:-${REPO_ROOT}}/.claude/workflow-state}`
    but migrated only ~5-7 scripts. The migration was INCOMPLETE; ~15 scripts still relative.
  evidence_docs:
    - source: "code.claude.com/docs/en/hooks"
      quote: "Handlers run in the current directory with Claude Code's environment."
      quote2: "cwd: Current working directory when the hook is invoked."
      note: "CLAUDE_PROJECT_DIR is exported to the hook process; per docs not explicitly guaranteed for every event -> REPO_ROOT fallback covers the gap. [PARTIALLY VERIFIED]"
  evidence_empirical:
    repro_case1_bug:
      script: track-task-lifecycle.sh (relative)
      cwd: <proj>/internal/service
      CLAUDE_PROJECT_DIR: <proj>   # set CORRECTLY
      result: "stray <proj>/internal/service/.claude/workflow-state  <-- BUG CONFIRMED"
    repro_case2_fixed_pattern:
      script: log-tool-failure.sh (anchored)
      cwd: <proj>/internal/service
      CLAUDE_PROJECT_DIR: <proj>
      result: "correct <proj>/.claude/workflow-state  (no stray)"
    conclusion: "Relative-path scripts IGNORE a correctly-set CLAUDE_PROJECT_DIR and write to cwd. Deterministic, machine-level, model-independent."

chosen_approach: "Alt A — inline canonical anchor per script"
  form_bash: '${CLAUDE_WORKFLOW_STATE_DIR:-${CLAUDE_PROJECT_DIR:-${REPO_ROOT}}/.claude/workflow-state}'
  form_prompts_memory: '${CLAUDE_PROJECT_DIR:-${REPO_ROOT}}/.claude/{prompts,agent-memory}'
  repo_root_derivation: 'REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"  # add where missing'
  embedded_python_rule: "pass resolved absolute dir into python via env (STATE_DIR=\"$STATE_DIR\" python3 ...); python reads os.environ, never re-hardcodes \".claude/...\""
  why: >
    Byte-identical to the already-blessed Class-A pattern documented in lib/paths.sh.
    In project-mode CLAUDE_PROJECT_DIR==REPO_ROOT -> behavior unchanged. In plugin-mode
    the primary anchor is CLAUDE_PROJECT_DIR (user project); REPO_ROOT fallback = plugin
    cache (a lesser, pre-existing tradeoff already accepted by Class-A — strictly better
    than scattering into user source tree).

alternatives_rejected:
  Alt_B_cd_at_top:
    idea: "cd \"$CLAUDE_PROJECT_DIR\" at top of each hook"
    reject: "mutates cwd; breaks scripts that intentionally run git ops against the current repo; side-effect risk"
  Alt_C_shared_sourced_resolver:
    idea: "resolve_state_dir() in lib/paths.sh sourced by every hook"
    reject: "adds a runtime sourcing dependency on every hook event (paths.sh comment forbids this on hot path); larger blast radius"
  Alt_D_wiring_arg:
    idea: "pass ${CLAUDE_PROJECT_DIR} as an arg in settings.json for each hook"
    reject: "touches protected settings.json + hooks.json manifest; contract-sensitive; larger blast radius"

decision_matrix:   # axis 1-5 (higher better; Effort is inverse=lower-effort-higher); rank=sum
  axes: [contract_safety, reliability, token_cost, blast_radius_small, effort_inverse]
  Alt_A_inline_anchor: [5, 5, 5, 4, 4]   # sum=23  <-- CHOSEN
  Alt_C_shared_resolver: [4, 4, 3, 2, 3] # sum=16
  Alt_B_cd_top:         [3, 2, 5, 4, 4]  # sum=18
  Alt_D_wiring_arg:     [2, 4, 5, 2, 2]  # sum=15

## Tests

strategy:
  - per_part_behavioral: "clone test-log-tool-failure-default-path.sh shape: stage script in faux repo, fire with cwd=subdir + CLAUDE_PROJECT_DIR=root, assert state lands at root, assert NO stray .claude in subdir"
  - global_invariant: "test-no-relative-claude-state-paths.sh — grep every .claude/scripts/*.sh for a relative `.claude/{workflow-state,prompts,agent-memory}` path DEFINITION/write; allowlist prose-message strings + Class-A; FAIL if any unfixed site remains"
  - regression: "full suite (124 tests) green BEFORE and AFTER each part"
  - contract_stability: "canonical issue ID sha256(category|location|problem)[:8] byte-stable; VERDICT/VERDICT_JSON envelope unchanged; handoff JSON shape unchanged"

## Acceptance Criteria

per_part:
  - "Contracts plan <-> plan-reviewer <-> coder <-> code-reviewer unchanged in shape (handoff JSON, VERDICT/VERDICT_JSON envelope)."
  - "Canonical issue ID sha256(category|location|problem)[:8] byte-stable."
  - "No settings.json / hooks.json / hook-wiring change."
  - "Every changed script: state/log/memory dir anchors to ${CLAUDE_PROJECT_DIR:-${REPO_ROOT}}; NO relative `.claude/` write remains."
  - "Embedded python receives resolved absolute dir via env; no re-hardcoded relative path."
  - "New behavioral test proves no stray `.claude/` in a subdir cwd; test passes."
  - "Full test suite green before AND after."

## Parts

Part 1: Hot-path Pre/PostToolUse loggers (highest scatter frequency)
  scripts: [auto-fmt.sh, pre-commit-build.sh, protect-files.sh]
  pattern: P-simple (bash-only writer -> anchor var)
  rationale: "fire on every Write|Edit|Bash; most frequent stray source when coder cd's"
  acceptance: "+ behavioral repro test; suite green"

Part 2: Subagent lifecycle + checkpoint (canonical-ID load-bearing)
  scripts: [track-task-lifecycle.sh, save-review-checkpoint.sh, inject-review-context.sh]
  pattern: P-python-env (bash + heredoc python) / P-python-alreadysafe
  rationale: "save-review-checkpoint feeds canonical issue IDs — highest contract-risk; verify byte-stability of checkpoint fields"
  acceptance: "+ behavioral repro test; canonical-ID golden byte-stable; suite green"

Part 3: Session / compact / stop lifecycle (+ prompts_dir/pk_path anchoring)
  scripts: [enrich-context.sh, save-progress-before-compact.sh, verify-state-after-compact.sh, check-uncommitted.sh, session-analytics.sh]
  pattern: P-python-alreadysafe (fix bash default + anchor prompts_dir/pk_path reads)
  rationale: "compact/stop hooks + UserPromptSubmit; also fixes plan-context READ misses from wrong cwd"
  acceptance: "+ behavioral repro test; suite green"

Part 4: Low-frequency loggers + agent-memory sync
  scripts: [audit-config-change.sh, log-permission-denied.sh, log-stop-failure.sh, sync-agent-memory.sh]
  pattern: P-python-env + P-memory
  rationale: "complete the migration; sync-agent-memory anchors .claude/agent-memory"
  acceptance: "+ behavioral repro test; suite green"

Part 5: Global invariant guard + docs (+ optional command-vector)
  artifacts: [test-no-relative-claude-state-paths.sh, lib/paths.sh doc note, CLAUDE.md note]
  optional_UNVERIFIED: "verify Write-tool relative-path resolution; if it scatters, add absolute-path directive to planner/coder/designer/workflow command templates"
  rationale: "lock the invariant kit-wide so migration can never regress again"
  acceptance: "grep guard fails on any future relative site; suite green; +3 test count"

gate2_recommendation: "Implement all 5 parts in order (1->5). Part 1+2 are highest-value (hot-path + contract-risk). Part 5 makes regression impossible."

## Implementation Status (Phase 6 — shipped)

completed_2026-07-01:
  branch: fix/stray-claude-dirs-path-anchor
  parts:
    - "Part 1 (f807c1e): auto-fmt.sh, pre-commit-build.sh, protect-files.sh — code-review APPROVED"
    - "Part 2 (8b353db): track-task-lifecycle.sh, save-review-checkpoint.sh, inject-review-context.sh — APPROVED (2 NITs applied)"
    - "Part 3 (0852be2): enrich-context.sh, save-progress-before-compact.sh, verify-state-after-compact.sh, session-analytics.sh, check-uncommitted.sh — APPROVED_WITH_COMMENTS"
    - "Part 4 (66224c6): audit-config-change.sh, log-permission-denied.sh, log-stop-failure.sh, sync-agent-memory.sh — APPROVED"
    - "Part 5: test-no-relative-claude-state-paths.sh invariant guard + lib/paths.sh + CLAUDE.md docs — APPROVED_WITH_COMMENTS (CR-001 single-quote coverage, CR-002 tightened exclusion, CR-003 doc fix applied)"
  method: "each part = TDD (behavioral+structural test RED -> anchor fix GREEN) -> full suite -> formal code-reviewer agent -> commit"
  tests_added: [test-hotpath-hooks-state-anchor.sh, test-subagent-lifecycle-state-anchor.sh, test-lifecycle-compact-state-anchor.sh, test-lowfreq-loggers-state-anchor.sh, test-no-relative-claude-state-paths.sh]
  test_harnesses_updated: [test-auto-fmt-dispatch.sh, test-agent-type-namespace-strip.sh, test-stop-circuit-breaker.sh, test-stop-subagentstop-additional-context.sh, test-checkpoint-selection-mtime.sh]
  suite: "124 -> 129 tests, all green before AND after each part"
  contract_safety: "no handoff/VERDICT envelope change, no canonical-ID change, no new env vars, no settings.json/hook-wiring change — verified by 5 independent code-reviewer passes"
  deferred:
    - "cwd-relative .claude/prompts READS (inject-review-context prompts_dir/pk_path, enrich PROMPTS_DIR, save-progress load_state, check-uncommitted ls checkpoint selector) — a distinct context-miss bug (reviewer/selector reads wrong dir when cwd != root), NOT a stray-dir write. Out of scope for this Задача."
    - "Model-driven relative .claude/ writes via command/skill Write instructions (24+ refs) — [UNVERIFIED-impact]; orchestrator generally absolutizes via Write tool."
    - "test-aggregate-pipeline-metrics.sh (root orphan test-*.sh) still relative — a test harness (controls its own cwd), excluded from the guard scope; pre-existing independent failure on HEAD."
