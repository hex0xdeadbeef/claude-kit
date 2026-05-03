---
title: "Native Claude Code Memory Mechanism — Fix"
status: approved
date: 2026-05-03
author: designer (workflow XL run)
complexity: XL
task_type: pipeline_fix
research_source: ".claude/prompts/native-memory-mechanism-research.md"
---

meta:
  type: "spec"
  feature: "native-memory-mechanism-fix"
  purpose: "Fix 5 defects in the native Claude Code memory integration so subagent `memory: project` accumulation works end-to-end and auto-memory staleness is surfaced"

spec:
  title: "Native Claude Code Memory Mechanism — Fix"
  status: "approved"

  context:
    current_state: |
      Claude Code v2.1.118 ships two independent native memory mechanisms:
      (a) auto-memory at `~/.claude/projects/<slug>/memory/` (machine-local,
      written by main session per `autoMemoryEnabled: true`) and (b) subagent
      memory at `.claude/agent-memory/<name>/` (project-shared via VCS, written
      by subagents declaring `memory: project`).
      The kit has both mechanisms partially wired:
      - 3 agents (code-researcher, code-reviewer, plan-reviewer) declare `memory: project`.
      - Custom worktree round-trip exists (`prepare-worktree.sh`, `sync-agent-memory.sh`) for code-reviewer's `isolation: worktree`.
      - Hooks correctly skip agent-memory paths to avoid amplification loops.
      But `.claude/agent-memory/` directory does not exist; 4 of 51 tests FAIL;
      committed `settings.json` contains hardcoded `/Users/dmitriym` paths;
      tool allow/deny lists collide with the native R/W/E auto-grant for
      memory dirs; CLAUDE.md does not document the dual-mechanism split.

    motivation: |
      User reports the native memory mechanism appears not to work
      (no fresh records observed, unclear which "memory" is being debugged).
      Investigation confirmed the mechanism is partially configured but has
      5 concrete defects. Fixing them satisfies the user-stated requirements:
      (a) memoization works for project-scoped subagent memory,
      (b) configuration is portable (no `/Users/dmitriym` hardcodes),
      (c) phase handoff contracts remain byte-stable,
      (d) all 51 tests pass.

    business_value: |
      - Subagents (code-reviewer, plan-reviewer, code-researcher) accumulate
        project knowledge across iterations — fewer redundant rediscoveries,
        faster review iterations on repeat patterns.
      - Auto-memory staleness is surfaced at workflow startup (warn-only by
        default) so the user knows when records may be out of date.
      - Kit becomes shareable (no user-specific paths in committed config).
      - 4 failing tests → 0 failing tests; documents canonical state.

  requirements:
    in_scope:
      - "P1: Create 3 baseline `.claude/agent-memory/<agent>/MEMORY.md` files (code-reviewer, plan-reviewer, code-researcher) with required H2 sections, ≤80 lines each."
      - "P1: Update `agent-memory-protocol.md` first_run.trigger to handle 'missing OR empty' and add `what_to_save_template:` 3-question rubric."
      - "P2: Add `step: 0.06` (memory freshness check) to `.claude/commands/workflow.md` between `step: 0.05` and `step: 0`. Document `CLAUDE_MEMORY_FRESHNESS_MODE` env var (off|warn|strict, default warn). Add env var entry in `CLAUDE.md`."
      - "P3: Remove hardcoded `/Users/dmitriym` paths from `.claude/settings.json` lines 50–51. Generalize the `git tag` permission rule; remove the self-referential grep rule."
      - "P4: Reconcile tool permissions on memory-enabled agents — drop the `code-researcher` `tools` allowlist (or add Write/Edit) and remove `Edit` from `plan-reviewer` `disallowedTools`. Reconcile `code-researcher` role text so `memory: project` does not contradict 'Read Only'."
      - "P5: Add a `## Memory Mechanisms` section to `CLAUDE.md` documenting the two paths and cross-referencing the protocol skill + canonical docs URLs."
      - "P-PRE-1 (test cleanup): Add `export CLAUDE_WORKFLOW_STATE_DIR` after `mktemp -d` in 3 test files (test-coder-to-codereview-handoff-write.sh, test-code-review-to-completion-handoff.sh, test-spec-check-failure-after-retry-blocker.sh)."
      - "P-PRE-2 (test cleanup): Tighten log truncation in `validate-handoff.sh` to satisfy the 800-char + suffix-headroom cap probed by `test-validate-handoff-detail-log-cap.sh`."

    out_of_scope:
      - item: "Override auto-memory location project-wide via autoMemoryDirectory in project settings"
        reason: "Claude Code rejects autoMemoryDirectory from project settings by design (security: prevents shared projects from redirecting writes). Auto-memory is machine-local."
      - item: "Remove agent-memory-protocol.md custom layer in favor of pure native"
        reason: "Custom worktree round-trip (prepare-worktree.sh + sync-agent-memory.sh) is required because code-reviewer runs with isolation: worktree; native does not propagate memory updates out of cleaned-up worktrees."
      - item: "Migrate existing artifacts under .claude/prompts/ (memory-handoff-cleanup-spec.md, etc.)"
        reason: "User explicit instruction: ignore existing plans/specs, do it cleanly."
      - item: "Schema changes (handoff.schema.json, verdict.schema.json)"
        reason: "Constraint: phase handoff contracts must remain byte-stable. Tags v1.16→v1.22.1 carry the current schemas; touching them would break existing fixtures."
      - item: "Touching MEMORY.md content inside ~/.claude/projects/<slug>/memory/"
        reason: "Auto-memory is owned by Claude (the main session), not by the kit. We add the freshness signal but never write the content."
      - item: "Renaming .claude/agent-memory/ to a non-canonical path"
        reason: "Path is canonical per Claude Code docs (sub-agents.md: 'memory: project → .claude/agent-memory/<name-of-agent>/'). Renaming would break native loading."

    constraints:
      - "Phase handoff contracts MUST remain byte-stable (planner→plan-review, plan-review→coder, coder→code-review, code-review→completion)"
      - "Verdict envelope (`VERDICT_JSON:`) and canonical issue ID hash unchanged"
      - "Caveman boundary clauses preserved verbatim"
      - "All 51 tests under `.claude/scripts/tests/` MUST pass after fixes (currently 4 FAIL; target 0 FAIL)"
      - "Zero `/Users/dmitriym` references in `.claude/settings.json` after fix (kit is shared with other users)"
      - "No file under `~/.claude/` modified by the kit (project-local invariant)"
      - "Release tags v1.16 → v1.22.1 carry pipeline edits — no regression to those features"
      - "CLAUDE.md size ≤200 lines after additions (per Claude Code docs guidance)"
      - "Each agent's primary output contract (verdict + structured issues + handoff) byte-identical to current behavior"

  approach:
    selected:
      name: "Hybrid — native primitives + targeted custom infra"
      description: |
        Keep `memory: project` frontmatter as the canonical declaration.
        Trust Claude Code's native loader to inject the first 200 lines /
        25 KB of `.claude/agent-memory/<name>/MEMORY.md` and to auto-grant
        Read/Write/Edit on that dir. Keep the existing custom worktree
        round-trip scripts (`prepare-worktree.sh`, `sync-agent-memory.sh`)
        because native does not handle the worktree-cleanup edge case
        that code-reviewer triggers. Fix the 5 defects in place:
        create baselines, add freshness check, remove hardcoded paths,
        align tool permissions with the auto-grant, document the
        dual-mechanism split. All changes are additive or strictly
        narrowing (no contract surface touched).

      rationale: |
        - Existing tests already gate the exact end-state being proposed
          (e.g., test-agent-memory-baseline-exists.sh asserts the 3 baseline
          files with specific H2 sections; test-memory-freshness-warn.sh
          asserts step 0.06 with verbatim WARN format).
        - Existing scripts (sync-agent-memory.sh, prepare-worktree.sh) cover
          the worktree edge case that pure-native cannot. Removing them
          would regress code-reviewer.
        - Smallest diff that fully satisfies the user-stated 5 problems
          and the "all tests pass" constraint.

    alternatives:
      - option: "Approach A — Pure native (remove custom protocol + worktree scripts)"
        pros:
          - "Smallest custom code surface — easier maintenance"
          - "Exact native semantics, no kit-specific divergence"
        cons:
          - "Code-reviewer runs with isolation: worktree; native does not propagate memory writes back to main repo on worktree cleanup"
          - "Memory updates from code-reviewer would be silently discarded"
          - "Existing tests assert custom protocol behavior (worktree sync, freshness modes)"
        rejected_because: "Regresses the worktree-isolated agent's memory persistence — the very mechanism the user is trying to fix."

      - option: "Approach C — Tests-only (only fix the 4 failing tests, skip P3/P4/P5)"
        pros:
          - "Smallest diff"
          - "Zero risk of contract drift"
        cons:
          - "Leaves hardcoded /Users/dmitriym paths in committed config (constraint violation)"
          - "Leaves tool-permission conflicts that silently block agent memory updates via Edit"
          - "Leaves CLAUDE.md doc gap that caused user's diagnosis question"
        rejected_because: "Does not satisfy user-stated requirement to address 5 problems; leaves the portability and silent-drift defects in place."

  key_decisions:
    - decision: "Author static baseline `MEMORY.md` files at the canonical native paths (`.claude/agent-memory/<name>/MEMORY.md`)"
      rationale: "Native creates the dir on first write; absent baselines, every first run sees an empty injection. Tests already gate the structure (specific H2 sections per agent, ≤80 lines)."
      impact: "3 new files, total ≤240 lines. Files are idiomatic agent-memory entries: agent-specific bootstrap content. They are NEVER referenced by any handoff schema."

    - decision: "Add `step: 0.06` after `step: 0.05` (PK sanity) and before `step: 0` (Task Analysis) in `workflow.md`"
      rationale: "Mirrors the existing PROJECT-KNOWLEDGE.md pre-flight pattern. Off|warn|strict mode env var follows the established kit convention (CLAUDE_PK_PATH_MODE, CLAUDE_VERDICT_VALIDATION_MODE, etc.). Default `warn` is non-blocking."
      impact: "Workflow startup gains one read-only filesystem scan and at most one stderr WARN line per session. Zero impact on phase handoffs."

    - decision: "Generalize the `git tag --list 'v1.*'` permission rule to `Bash(git tag *)` and remove the self-referential grep diagnostic"
      rationale: "The git-tag rule's intent (allow listing version tags) is preserved by the wildcard. The grep rule on settings.json:51 was a one-shot debug utility that does not belong in a shared kit."
      impact: "Permission allow-list widens from one specific path-pinned command to the whole `git tag *` family — strictly more permissive, never blocks pipeline. The grep rule removal narrows."

    - decision: "Drop `tools` allowlist on code-researcher (inherit all tools) AND remove `Edit` from plan-reviewer's `disallowedTools`"
      rationale: "Native auto-grants R/W/E for the memory dir; explicit denylist almost certainly overrides the auto-grant. Role discipline (not hard tool-deny) keeps code-researcher read-only on the codebase via its RULE_1 prose. Plan-reviewer's `Bash` denial preserved (memory updates do not need Bash)."
      impact: "Agent capability surface changes: code-researcher now nominally has Write/Edit (used only for `.claude/agent-memory/code-researcher/`); plan-reviewer can Edit (used only for `.claude/agent-memory/plan-reviewer/`). Output contracts (verdict, summary, handoff) unchanged."

    - decision: "Add a 'Memory Mechanisms' section to CLAUDE.md (≤30 lines) cross-referencing both native paths"
      rationale: "User's diagnosis question ('is this `memory: project` frontmatter?') is direct evidence of the doc gap. CLAUDE.md is the file every contributor reads first."
      impact: "CLAUDE.md grows by ≤30 lines (current ~140; new ~170). Stays under the docs-recommended 200-line budget."

    - decision: "Sequence pre-condition cleanups (P-PRE-1, P-PRE-2) BEFORE memory fixes (P1..P5) so the test pass-count is monotonic (47 → 49 → 51)"
      rationale: "Avoids ever flipping a green test red mid-implementation. P-PRE-1/P-PRE-2 are unrelated to memory; their ordering is purely operational."
      impact: "Small ordering constraint in the plan's Parts list; no semantic coupling between cleanups and memory fixes."

  risks:
    - risk: "Native auto-grant for memory dir tools may NOT additively combine with explicit `tools` allowlist"
      severity: "MEDIUM"
      mitigation: "Decision above drops the allowlist on code-researcher entirely (inherit all). Mitigates by removing the conflict surface, not by relying on undocumented behavior. Plan-reviewer also has the conflict removed (Edit dropped from disallowedTools)."

    - risk: "Hardcoded path removal could revoke a permission the developer relied on"
      severity: "LOW"
      mitigation: "Generalized rule (`Bash(git tag *)`) is strictly broader than the specific path-pinned rule it replaces. Removed grep rule was one-shot debug utility, not pipeline. All currently-passing tests must continue to pass — verified by full test corpus run before commit."

    - risk: "CLAUDE.md additions may push file past 200-line budget and reduce adherence"
      severity: "LOW"
      mitigation: "Target ≤30 lines for the new section; current size leaves ~60-line headroom. Verified by `wc -l CLAUDE.md` post-edit."

    - risk: "Baseline `MEMORY.md` content drift if agents update it inconsistently"
      severity: "LOW"
      mitigation: "Baselines are seed content — agents are expected to overwrite/edit. Test asserts structural presence (H2 sections + line cap), not exact content. This is by design per the agent-memory-protocol."

    - risk: "Step 0.06 freshness scan could WARN noisily on a fresh clone with no agent-memory yet"
      severity: "LOW"
      mitigation: "Default mode `warn` (non-blocking); a missing dir is treated as 'not yet bootstrapped' rather than 'stale'. Strict mode is opt-in via `CLAUDE_MEMORY_FRESHNESS_MODE=strict`."

    - risk: "Plan-reviewer regaining Edit on memory dir could be misused to edit other files"
      severity: "LOW"
      mitigation: "Plan-reviewer's role identity (`Architecture Reviewer`, `does_not_own: Creating/modifying plans, writing code`) is the policy layer. Native memory auto-grant scopes Edit to the memory dir. The agent's RULE block can add an explicit 'Edit only in `.claude/agent-memory/plan-reviewer/`' clause for defense-in-depth."

  acceptance_criteria:
    - "AC-P1.1..AC-P1.7: `bash .claude/scripts/tests/test-agent-memory-baseline-exists.sh` exits 0; baseline structure verified."
    - "AC-P2.1..AC-P2.7: `bash .claude/scripts/tests/test-memory-freshness-warn.sh` exits 0; step 0.06 placement, scan paths, WARN format, env modes, and CLAUDE.md env-var entry verified."
    - "AC-P3.1: `grep -c '/Users/dmitriym' .claude/settings.json` returns 0."
    - "AC-P3.2..AC-P3.5: `git tag --list` permission semantics preserved; no permission-related test regressions; no new user-path requirements introduced in `settings.local.json.example`."
    - "AC-P4.1..AC-P4.5: code-researcher.md and plan-reviewer.md tool permissions reconciled with `memory: project` auto-grant; all currently-passing tests continue to pass."
    - "AC-P5.1..AC-P5.6: CLAUDE.md has a `## Memory Mechanisms` section ≤30 lines, with both paths verbatim, a 3-row table, cross-references; CLAUDE.md total ≤200 lines."
    - "AC-PRE-1: `bash .claude/scripts/tests/test-test-fixture-isolation.sh` exits 0."
    - "AC-PRE-2: `bash .claude/scripts/tests/test-validate-handoff-detail-log-cap.sh` exits 0."
    - "AC-FINAL-1: All 51 tests under `.claude/scripts/tests/` pass (run via `for f in .claude/scripts/tests/test-*.sh; do bash \"$f\" || rc=1; done; exit ${rc:-0}` — exits 0)."
    - "AC-FINAL-2: `git diff` over the implementation does NOT touch `.claude/schemas/`, `.claude/skills/workflow-protocols/handoff-protocol.md`, `.claude/skills/workflow-protocols/handoff-contracts.md`, or any verdict-envelope-related code (proves contract bytes unchanged)."
    - "AC-FINAL-3: `git diff` does NOT touch `.claude/skills/caveman/SKILL.md` Boundaries section."
    - "AC-FINAL-4: `wc -l CLAUDE.md` returns ≤200."

  notes: |
    - The research file `.claude/prompts/native-memory-mechanism-research.md`
      contains the full evidence trail (workflow artifact graph, current vs
      expected state per artifact, official Claude Code docs citations).
    - Implementation order: P-PRE-1 → P-PRE-2 → P1 → P2 → P3 → P4 → P5,
      so the test-pass count is monotonically increasing (47 → 48 → 49 → 50 → 51).
    - Tests ARE the source of truth for AC-P1.* and AC-P2.* — the test
      bodies prescribe exact section names, line caps, and message formats.
    - Tool-conflict fix (P4) is the most subtle. Even after committing
      this fix, observe a real /workflow run to confirm that agents actually
      use Edit on their MEMORY.md files. This is observability, not a contract.
