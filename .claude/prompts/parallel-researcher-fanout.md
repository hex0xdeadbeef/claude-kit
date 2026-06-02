# Plan: Wire N-way Parallel Code-Researcher Fan-out (Batch C — F1)

```yaml
feature: parallel-researcher-fanout
complexity: M
source: ".claude/workflow-audit-2026-06-02.md finding F1 (GATE-2 approved — the headline parallelize-axis item)"
type: parallelize (contract-safe, read-only fan-out)
```

## Scope

```yaml
in:
  - "Wire the EXISTING-but-dormant parallel-dispatch.md Use Case 1 (N-way concurrent code-researcher dispatch) into planner.md Phase 3 background_mode, so L/XL plans with 3+ INDEPENDENT research questions dispatch one run_in_background researcher PER layer in a single message instead of one bundled researcher."
  - "Correct the parallel-dispatch.md Use Case 1 self-label from '(EXISTING)' (untrue — no command referenced it) to a label that reflects the now-wired status + points back to planner.md."
out:
  - "No change to the single-bundled-researcher path — it remains the documented FALLBACK (coupled questions / single domain / background unsupported)."
  - "No N-way fan-out for /coder (parallel-dispatch Use Case 2 stays FUTURE — out of scope, edits files; F1 is read-only research only)."
  - "No handoff JSON / VERDICT / VERDICT_JSON / discriminator / canonical issue-ID hash / caveman boundary / env var / security hook change."
```

## Architecture Decision

```yaml
decision: "parallel-dispatch.md Use Case 1 already documents the exact N-way pattern (one Agent(...,run_in_background:true) per layer in a single message), marked '(EXISTING)', but grep proved NO command/agent referenced it — planner.md launched ONE bundled background researcher. The load-bearing fix is in planner.md (it loads only planner-rules/SKILL.md, never workflow-protocols, so the protocol was undiscoverable from the planner's own context): add a parallel_fanout sub-block to background_mode that (a) names the precondition (3+ independent, non-overlapping, read-only layer questions), (b) instructs loading parallel-dispatch.md Use Case 1 by path and dispatching N researchers in one message, (c) keeps the single bundled researcher as explicit fallback."
why_contract_safe: "code-researcher is a read-only tool-agent returning ≤2000-token summaries — it emits NO verdict/handoff JSON, so dispatching N instead of 1 cannot touch any contract surface. The edit is additive command prose + a doc relabel."
honest_impact: "MEDIUM, bounded: applies only to L/XL with 3+ genuinely-independent layers; realistic ~1.5-2.5x on the research sub-step (shared warmup, not clean Nx); planner already overlaps the single researcher with DESIGN, so the realized gain is N-concurrent vs 1-concurrent, and it costs N× research tokens. Keep the single-researcher fallback to degrade cleanly."
```

## Tests

```yaml
tdd: "Test-first, content-anchored. Fails red now (planner.md references parallel-dispatch nowhere), green after. Full suite 100 -> 101."
test_file: ".claude/scripts/tests/test-parallel-dispatch-wired.sh"
assertions:
  - "planner.md references parallel-dispatch.md (grep non-empty — closes the GT2 gap)."
  - "planner.md background_mode contains a parallel_fanout block with the per-layer / single-message dispatch instruction and an explicit fallback to the single researcher."
  - "parallel-dispatch.md Use Case 1 header no longer carries the bare '(EXISTING)' claim — it reflects the wired status (contains 'WIRED')."
```

## Acceptance Criteria

```yaml
- "AC-F1-1: grep -n parallel-dispatch .claude/commands/planner.md is non-empty (was empty)."
- "AC-F1-2: planner.md background_mode has a parallel_fanout key whose action says to dispatch one run_in_background code-researcher per independent layer in a single message, with a single-researcher fallback."
- "AC-F1-3: parallel-dispatch.md Use Case 1 line contains 'WIRED' and does not stand on the bare '(EXISTING)' label."
- "AC-F1-4: the single-bundled-researcher delegation_example + fallback line in planner.md are preserved (no regression to the existing path)."
- "AC-ALL: all .claude/scripts/tests/test-*.sh pass before and after (100 -> 101)."
```

## Parts

```yaml
Part 1:
  name: "F1 — wire parallel-dispatch UC1 into planner + relabel"
  test_first: ".claude/scripts/tests/test-parallel-dispatch-wired.sh (red)"
  edits:
    - "planner.md background_mode: insert a parallel_fanout sub-block (after mechanism, before skip_when) — when: L/XL with 3+ independent layer/package questions (no overlap); action: load .claude/skills/workflow-protocols/parallel-dispatch.md Use Case 1 and dispatch ONE run_in_background code-researcher per layer in a SINGLE message, integrate at async_integration_point; fallback: single bundled background researcher."
    - "parallel-dispatch.md:33 header: '(EXISTING)' -> '(WIRED — see planner.md Phase 3 background_mode.parallel_fanout)'"
  verify: "bash .claude/scripts/tests/test-parallel-dispatch-wired.sh (green); full suite green"
```
