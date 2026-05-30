---
feature: ctx-audit-4-workflow-hooks-collapse
task_type: refactor
complexity: M
backlog_ref: ".claude/workflow-audit-2026-05-30.md #3"
sequential_thinking_used: false
---

# Plan — Collapse commands/workflow.md ## HOOKS section to a pointer + load-bearing rationale (backlog #3)

## Scope

IN:
- `.claude/commands/workflow.md#L373-L435` — the `## HOOKS` section (63 lines / ~3619 chars). The
  whole 435-line orchestrator command loads eagerly on every /workflow run; this section restates
  hook wiring that already lives authoritatively in settings.json (L376 itself declares settings.json
  "authoritative source — 12 event types, 18 scripts + 2 prompt hooks"). The orchestrator never reads
  or edits settings.json at runtime — hooks fire deterministically regardless.
- NEW test `.claude/scripts/tests/test-workflow-hooks-collapsed.sh`.

OUT (with reason):
- settings.json — UNCHANGED. It is the authoritative wiring; this change only trims the duplicate
  human-readable restatement in workflow.md. No hook is added/removed/re-wired.
- The PRESERVED load-bearing rationale (see Architecture Decision) stays — only the redundant
  `also_active_during_workflow` block + verbose per-hook restatement are dropped.

## Architecture Decision

Decision: collapse the section to (a) a 2-3 line pointer to settings.json + (b) a short
`pipeline_load_bearing` list of the ~4 hooks whose pipeline rationale is NOT obvious from the wiring
alone. Drop the `also_active_during_workflow` block (L427-435, pure wiring duplication of
non-workflow-specific hooks) and the verbose per-hook `behavior/blocking` restatement.

Rationale:
1. The `also_active_during_workflow` block (InstructionsLoaded, UserPromptSubmit, PreToolUse,
   PostToolUse, SessionEnd, StopFailure, Notification, ConfigChange) is a static mirror of
   settings.json with ZERO orchestrator value — these fire deterministically; the orchestrator does
   nothing with the knowledge that they are wired.
2. KEEP the load-bearing rationale (the WHY that a reader cannot infer from the wiring): PreCompact +
   PostCompact persist/verify checkpoint+review state across compaction (recovery contract);
   SubagentStart inject-review-context.sh injects review context; SubagentStop save-review-checkpoint.sh
   is BLOCKING (captures the verdict); Stop check-uncommitted.sh is BLOCKING (commit before completion).
   These four shape orchestrator flow, so they stay as one-liners.
3. KEEP the conditional-`if` + security-unconditional note and the WorktreeCreate-removed note (F1) —
   both are non-obvious operational facts.

Contract surface: NONE. The ## HOOKS section is descriptive prose. Hooks fire from settings.json
regardless of whether the orchestrator's window restates them. No handoff payload, VERDICT/VERDICT_JSON
envelope, or canonical issue-ID hash is touched. No hook is re-wired.

## Tests

TDD — write the test FIRST (RED), then implement (GREEN).

New test `test-workflow-hooks-collapsed.sh` asserts:
- HK-1 (duplication dropped): the workflow.md ## HOOKS section no longer contains the
  `also_active_during_workflow` block.
- HK-2 (materially smaller): the ## HOOKS section (heading → EOF) is < 25 lines (was 63).
- HK-3 (pointer present): the section names `.claude/settings.json` as the authoritative source.
- HK-4 (real wiring intact in settings.json — the finding's required guard): every hook the collapsed
  section references is STILL wired in settings.json — save-progress-before-compact.sh (PreCompact),
  verify-state-after-compact.sh (PostCompact), inject-review-context.sh (SubagentStart),
  save-review-checkpoint.sh (SubagentStop), check-uncommitted.sh (Stop), validate-handoff.sh
  (PostToolUse). Proves the collapse loses no real wiring.
- HK-5 (load-bearing rationale kept): the section still mentions PreCompact/PostCompact checkpoint
  persistence AND the BLOCKING Stop check-uncommitted hook.

Regression: the 5 tests that reference commands/workflow.md (simplify-semantics, disambiguation,
install-update-restore, imp04-diff-based-replan, memory-freshness) stay green; full suite green.

## Acceptance Criteria

- [ ] 4 handoff payloads + VERDICT enum + fenced VERDICT_JSON block unchanged in shape.
- [ ] Canonical issue ID sha256(category|location|problem)[:8] byte-stable (no hashed text moved).
- [ ] All existing tests pass BEFORE and AFTER; the 5 workflow.md-referencing tests stay green.
- [ ] New test test-workflow-hooks-collapsed.sh exists and passes (HK-1..HK-5).
- [ ] No new env vars. Caveman boundaries verbatim. settings.json UNCHANGED (no hook re-wired).
- [ ] No real hook wiring lost — HK-4 proves every referenced hook still lives in settings.json.

## Parts

Part 1: Write test-workflow-hooks-collapsed.sh (RED) — HK-1..HK-5.
Part 2: Replace commands/workflow.md L373-EOF (## HOOKS section) with the collapsed version:
        authoritative pointer to settings.json + a short pipeline_load_bearing list (PreCompact/
        PostCompact/SubagentStart-inject/SubagentStop-checkpoint/Stop-check-uncommitted) + the
        conditional-if + WorktreeCreate-removed notes. Anchor the cut to the `## HOOKS` heading
        through EOF (it is the last section). (GREEN)
Part 3: VERIFY — new test + full suite + the 5 workflow.md-referencing tests green; confirm
        settings.json byte-unchanged (git diff --quiet settings.json).
