---
feature: ctx-audit-1-pk-injection-slim
task_type: refactor
complexity: M
backlog_ref: ".claude/workflow-audit-2026-05-30.md #1 + #4"
sequential_thinking_used: false
---

# Plan — Slim the PROJECT-KNOWLEDGE.md reviewer injection (backlog #4; #1 dropped with evidence)

## Scope

IN:
- `.claude/scripts/inject-review-context.sh#L584-L596` — replace the blind raw `pk_content[:4096]`
  whole-file prefix with an extraction of ONLY the slot blocks reviewers actually consume.
- `.claude/scripts/inject-review-context.sh#L590` — fix the stale comment that says "8KB
  additionalContext cap" to reflect the enforced `CAP=6000` (#L671).
- New test: `.claude/scripts/tests/test-inject-review-context-pk-guard.sh`.

OUT (with reason):
- Backlog #1 (suppress PK on iter>=2 / iteration-gate): DROPPED. Evidence below in Architecture
  Decision. Each reviewer SubagentStart is a fresh, isolated context (no parent history — see
  workflow.md delegation_protocol.isolation_guarantee), so cross-iteration injection is NOT
  within-context redundancy; suppression would starve the iter>=2 delta-reviewer of slot data.
  After #4 the PK block no longer dominates the 6000 cap, so #1's cap-headroom justification also
  dissolves. Plan-reviewer to confirm the drop.
- The `pk_missing_at_inject` telemetry branch (#L605-L629): unchanged.
- The sidecar / effort-level / delta blocks: unchanged.

## Architecture Decision

Decision: extract the consumed slot blocks rather than slice a raw byte prefix.

Rationale (evidence-backed):
1. Reviewers reference exactly these slots: LAYER_RULE, ERROR_WRAP, LINT_CMD, TEST_CMD, VERIFY_CMD,
   DOMAIN_PROHIBIT, GENERATED_PATTERN, MOCK_PATTERN, ARCHITECTURE_STYLE, SOURCE_GLOB, LANG_EXT,
   DEPENDENCY_FILE (code-reviewer.md#L36/L69/L70/L145/L147/L152/L169/L170, plan-reviewer.md#L34/L81/L83).
2. PK lines 1-32 (~1121 bytes: `---` frontmatter, H1 `# Project Knowledge`, 16-line HTML comment,
   metadata) carry ZERO consumed slots — pure dead injection in the current prefix.
3. Verified slot offsets: all 12 slots live at chars 1185-3952, so the current `[:4096]` prefix DOES
   capture them all today (no latent drop bug claimed). The waste is the dead prefix + the non-slot
   prose interleaved between slots. Extraction yields ~1.5-2.5KB vs 4096 chars.
4. Extraction is also future-proof: if PK grows and a slot moves past char 4096, the raw-prefix
   approach WOULD silently drop it; slot-extraction never does.
5. LAYER_RULE (PK#L71) and DOMAIN_PROHIBIT (PK#L85) are multi-line `|` block scalars; extraction
   MUST capture their indented continuation lines (and trailing `#` comment lines belonging to a slot)
   so no slot value is truncated.

Why #1 is dropped (not merely deferred):
- The finding's "redundant re-injection" premise holds for enrich-context.sh (UserPromptSubmit, same
  ongoing main-session context, hash-guarded at #L43-L60) but NOT for inject-review-context.sh
  (SubagentStart, fresh agent context each fire). Confirming facts over false-positives.
- Suppressing the slot block on iter>=2 trades functionality (delta-reviewer loses inline slots,
  must Read on demand) for a saving that #4 already captures. Net-negative once #4 lands.

Contract surface: NONE. PK is reviewer reference data injected as additionalContext. It is not a
field in any of the 4 handoff payloads, not part of the VERDICT enum / VERDICT_JSON envelope, and not
an input to the canonical issue ID sha256(category|location|problem)[:8]. Changing WHICH PK bytes are
injected changes no hashed byte and no contract shape.

## Tests

TDD — write the test FIRST, watch it fail (RED), then implement (GREEN).

New test `test-inject-review-context-pk-guard.sh` asserts, against a fixture PK containing all 12
consumed slots plus dead-prefix frontmatter/HTML-comment + a multi-line `|` slot + a non-consumed
slot (e.g. BUILD_CMD):
- AC-1 (slot presence): the injected PK block contains every consumed slot key (LAYER_RULE,
  VERIFY_CMD, ERROR_WRAP, DOMAIN_PROHIBIT, LANG_EXT, ...).
- AC-2 (multi-line capture): the LAYER_RULE `|` block's continuation line text is present (multi-line
  slot not truncated to its `|` header).
- AC-3 (dead-prefix dropped): the injected PK block does NOT contain the H1 `# Project Knowledge`
  title nor the `pk_schema_version` frontmatter key (dead prefix removed).
- AC-4 (smaller): the injected PK block is materially smaller than a 4096-char slice of the fixture
  (assert byte length < 4096 and < the old slice length).
- AC-5 (comment fixed): `grep -c "8KB" inject-review-context.sh` for the PK-cap comment region is 0;
  the comment references 6000 (or "CAP").
- AC-6 (no-PK unchanged): when PK is absent, the existing `[Project Knowledge — NOT INJECTED]` hint
  + `pk_missing_at_inject` telemetry path still fires (regression guard on the untouched branch).

Regression: all 86 existing tests pass, including the 3 sibling inject-review tests
(test-inject-review-context-{delta,shape}.sh, test-inject-review-effort-context.sh).

## Acceptance Criteria

- [ ] 4 handoff payloads + VERDICT enum + fenced VERDICT_JSON block unchanged in shape.
- [ ] Canonical issue ID sha256(category|location|problem)[:8] byte-stable (PK text not in hash input).
- [ ] All 86 .claude/scripts/tests/*.sh pass BEFORE and AFTER (exit codes propagated, no `|| break`).
- [ ] New test test-inject-review-context-pk-guard.sh exists and passes (AC-1..AC-6).
- [ ] No new env vars. Caveman boundaries verbatim.
- [ ] Every consumed slot still injected (functionality preserved); only dead prefix + non-slot prose removed.
- [ ] Stale "8KB" comment corrected to the real CAP=6000.

## Parts

Part 1: Write test-inject-review-context-pk-guard.sh (RED) — fixture + AC-1..AC-6 assertions.
Part 2: Add `extract_pk_slots(pk_text, CONSUMED_SLOTS)` to inject-review-context.sh; replace the
        `pk_content[:4096]` prefix with the extracted slot blocks; fix the L590 comment (GREEN).
Part 3: VERIFY — run the new test + full 86-test suite; confirm sibling inject tests green.
