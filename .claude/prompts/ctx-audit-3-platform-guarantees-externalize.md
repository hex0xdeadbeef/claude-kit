---
feature: ctx-audit-3-platform-guarantees-externalize
task_type: refactor
complexity: M
backlog_ref: ".claude/workflow-audit-2026-05-30.md #5"
sequential_thinking_used: false
---

# Plan — Externalize CLAUDE.md Platform Guarantees table to an on-demand doc (backlog #5)

## Scope

IN:
- `CLAUDE.md#L54-L70` — the `## Platform Guarantees Relied Upon` section (preamble + 9-row table,
  ~2050 chars) loads into EVERY session as always-on project instructions, yet its own preamble says
  it is consulted only "when changing the version floor or rolling back a reliance" (rare maintenance).
- NEW `.claude/docs/platform-guarantees.md` — holds the section (heading + preamble + 9-row table)
  byte-identical, loaded on-demand.
- `CLAUDE.md` — replace the moved body with the `## Platform Guarantees Relied Upon` heading + a
  one-line pointer to the doc. The `>= 2.1.141` version floor is INDEPENDENTLY stated at CLAUDE.md#L32
  and stays inline there (unchanged).
- `.claude/scripts/tests/test-platform-guarantees-doc.sh` — UPDATE the canonical consumer test to
  assert the heading + >=6 distinct versions live in the new DOC (was: in CLAUDE.md), plus a CLAUDE.md
  pointer check.
- NEW `.claude/scripts/tests/test-platform-guarantees-externalized.sh` — guards the externalization
  invariant (table out of CLAUDE.md, pointer present, floor preserved at L32).

OUT (with reason):
- CLAUDE.md#L32 `>= 2.1.141` floor statement — unchanged; it is the canonical floor declaration and is
  independent of the table.
- Two archival prompt docs (changelog-*.md) that mention "Platform Guarantees" — historical plans,
  not load-bearing, untouched.
- The 9 rows' text — moved byte-identical; no rewording.

## Architecture Decision

Decision: move the section to `.claude/docs/platform-guarantees.md` (a plain doc, NOT a rule) behind a
heading + one-line pointer in CLAUDE.md.

Rationale:
1. CLAUDE.md is always-loaded project instructions every session. The 9-row guarantee table is a
   maintenance reference (consulted only when changing the version floor) — no per-turn orchestrator
   decision reads it. No pipeline command references it (grep "Platform Guarantees" against
   workflow.md/coder.md/planner.md = no match); only a test + two archival plans consume it.
2. A plain doc (not a path-scoped rule) is correct here because the table is consulted rarely and
   deliberately (a human or agent changing the version floor reads it on demand) — it does not need to
   auto-load on any edit. The pointer + the test keep it discoverable and enforced.
3. The `>= 2.1.141` floor stays inline at CLAUDE.md#L32, so externalizing the table loses no
   load-bearing floor information. Saving ~410-500 tokens every session across ALL sessions.

Contract surface: NONE. The table is descriptive version-rationale documentation. It is not parsed by
the orchestrator at runtime, not a field in any of the 4 handoff payloads, not part of the
VERDICT/VERDICT_JSON envelope, and not an input to the canonical issue ID hash.

## Tests

TDD — write tests FIRST (RED), then implement (GREEN).

UPDATE `test-platform-guarantees-doc.sh` (canonical consumer, must stay meaningful + green):
- TG-1: `.claude/docs/platform-guarantees.md` exists and contains `## Platform Guarantees Relied Upon`.
- TG-2: the DOC body lists >=6 distinct `2.1.x` versions (table moved intact).
- TG-3: CLAUDE.md contains a pointer to `.claude/docs/platform-guarantees.md`.

NEW `test-platform-guarantees-externalized.sh`:
- EX-1: CLAUDE.md no longer carries the full table — its `## Platform Guarantees Relied Upon` section
  body lists < 6 distinct `2.1.x` versions (the body is now heading + pointer, not the 9-row table).
- EX-2: CLAUDE.md still states the `>= 2.1.141` floor inline (the L32 region `Minimum Claude Code
  version` statement is preserved).
- EX-3: the doc's 9-row table is byte-identical to the original CLAUDE.md L60-70 table rows.

Regression: all existing tests pass (incl. the updated test-platform-guarantees-doc.sh); full suite green.

## Acceptance Criteria

- [ ] 4 handoff payloads + VERDICT enum + fenced VERDICT_JSON block unchanged in shape.
- [ ] Canonical issue ID sha256(category|location|problem)[:8] byte-stable (no hashed text moved).
- [ ] All existing tests pass BEFORE and AFTER; updated test-platform-guarantees-doc.sh green.
- [ ] New test test-platform-guarantees-externalized.sh exists and passes (EX-1..EX-3).
- [ ] No new env vars. Caveman boundaries verbatim (the H2 heading text preserved).
- [ ] The 9 guarantee rows move byte-identical (no rewording); the `>= 2.1.141` floor stays at CLAUDE.md#L32.

## Parts

Part 1: Write/UPDATE tests (RED) — update test-platform-guarantees-doc.sh to target the doc + pointer;
        add test-platform-guarantees-externalized.sh (EX-1..EX-3).
Part 2: Create .claude/docs/platform-guarantees.md = `# Platform Guarantees Relied Upon` title +
        the preamble + 9-row table copied BYTE-IDENTICAL from CLAUDE.md L56-70 (no re-flow). Replace
        CLAUDE.md L54-70 with the `## Platform Guarantees Relied Upon` heading + a one-line pointer to
        the doc (mention the `>= 2.1.141` floor for continuity, do not restate the table) (GREEN).
Part 3: VERIFY — both tests + full suite green; confirm CLAUDE.md L32 floor untouched and the moved
        table is byte-identical (diff original rows vs doc rows).
