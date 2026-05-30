---
feature: ctx-audit-5-coder-speccheck-defer
task_type: refactor
complexity: M
backlog_ref: ".claude/workflow-audit-2026-05-30.md #7"
sequential_thinking_used: false
---

# Plan — Defer coder-rules/spec-check.md from /coder STARTUP to a Phase-3.5 just-in-time load (backlog #7)

## Scope

IN:
- `.claude/commands/coder.md` STARTUP `immediate_actions` (was L216-219) — the unconditional
  "Load Spec Check protocol" action eager-loaded coder-rules/spec-check.md (76 lines) into the
  startup prefix, even though spec-check is consumed ONLY at Phase 3.5 (the final sub-phase). It sat
  in the eager prefix through all of EVALUATE + IMPLEMENT where it is never read.
- `.claude/commands/coder.md` WORKFLOW `phase: 3.5` (L545+) — add an explicit just-in-time Load step
  for spec-check.md as the first step of the SPEC CHECK phase.
- NEW test `.claude/scripts/tests/test-coder-speccheck-deferred.sh`.

OUT (with reason):
- `.claude/skills/coder-rules/spec-check.md` — UNCHANGED (its content + retry/PASS-PARTIAL-FAIL
  semantics are untouched; only WHEN /coder loads it moves). Guards the two spec-check content tests.
- The conditional Review Response load (the in-file pattern this mirrors) — untouched.

## Architecture Decision

Decision: remove the unconditional STARTUP load action and add a just-in-time Load step at the
Phase-3.5 SPEC CHECK sub-phase, mirroring the existing conditional Review Response load.

Rationale:
1. coder.md has no `disable-model-invocation`, so the whole 609-line command loads eagerly per /coder
   run. spec-check.md's own header says it runs "After VERIFY passes, before forming handoff output"
   (Phase 3.5) — it is dead weight in the eager prefix during EVALUATE + IMPLEMENT.
2. The deferral pattern already exists ONE action above in the same file: the Review Response load
   carries a `condition:` key (loads only on re-entry). Spec-check is deferred analogously — loaded at
   the point of use (Phase 3.5) rather than at startup. Saves ~600 tokens out of the eager startup
   prefix per /coder run.
3. Phase 3.5 always runs, so a startup `condition:` would not defer; the correct just-in-time hook is
   a Load step inside the Phase-3.5 block itself (where `reference:` already names the file).

Contract surface: NONE. Moving WHEN the skill loads does not change the coder_to_code_review handoff
schema, the spec_check sub-object field names (status/coverage_pct/deviations_confirmed/ac_coverage/
issues), or the PASS/PARTIAL/FAIL semantics. No handoff payload, VERDICT/VERDICT_JSON envelope, or
canonical issue-ID hash is touched.

## Tests

TDD — write the test FIRST (RED), then implement (GREEN).

New test `test-coder-speccheck-deferred.sh` asserts:
- SC-1: spec-check.md is NOT loaded in the eager STARTUP region (`## STARTUP` → before `## WORKFLOW`).
- SC-2: the Phase-3.5 block contains an explicit just-in-time Load step naming spec-check.md.
- SC-3: spec-check.md is still reachable at Phase 3.5 (skill not orphaned — the `reference:` stays).
- SC-4 (regression): the mirrored Review Response conditional gate (`condition:` + review-response.md)
  in STARTUP is intact.

Regression: the two spec-check content tests (test-codereview-spec-check-iter2-spotcheck.sh,
test-spec-check-failure-after-retry-blocker.sh) stay green; full suite green.

## Acceptance Criteria

- [ ] 4 handoff payloads + VERDICT enum + fenced VERDICT_JSON block unchanged in shape.
- [ ] Canonical issue ID sha256(category|location|problem)[:8] byte-stable.
- [ ] All existing tests pass BEFORE and AFTER; both spec-check content tests stay green.
- [ ] New test test-coder-speccheck-deferred.sh exists and passes (SC-1..SC-4).
- [ ] No new env vars. Caveman boundaries verbatim. spec-check.md content UNCHANGED.
- [ ] The spec_check handoff sub-object field names + PASS/PARTIAL/FAIL semantics unchanged.

## Parts

Part 1: Write test-coder-speccheck-deferred.sh (RED) — SC-1..SC-4.
Part 2: Remove the STARTUP "Load Spec Check protocol" action (replace with a short comment noting the
        just-in-time deferral, WITHOUT the literal spec-check.md path so the eager-region check stays
        clean); add a "Load .claude/skills/coder-rules/spec-check.md (just-in-time …)" first step to
        the Phase-3.5 block (GREEN).
Part 3: VERIFY — new test + both spec-check content tests + full suite green.
