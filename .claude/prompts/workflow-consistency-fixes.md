# Plan: Workflow Consistency Fixes (Batch A — F4 + F2) — iter 2

```yaml
feature: workflow-consistency-fixes
complexity: M
source: ".claude/workflow-audit-2026-06-02.md findings F4, F2 (GATE-2 approved)"
type: doc-consistency-fix
iteration: "2/3 (addresses plan-review PR-001 MAJOR, PR-002/PR-003 MINOR)"
```

## Diff vs prior iteration

```yaml
PR-001 (MAJOR, resolved): "F2 reframed to Option B. Original 'extend workflow.md to 0.7|1-5' would contradict README.md:266/268 (Phase 5 marked not-resumable). Independent verification: workflow.md:55 (0.7|1-4) and README.md:266/268 ALREADY AGREE Phase 5 is not a --from-phase target; orchestration-core.md:186 resumes INTO Phase 5 from a phase_completed:4 checkpoint (auto, no CLI arg). The ONLY real defect is state_render.py:371 emitting `Resume: /workflow --from-phase {phase_completed}` which prints `--from-phase 5` for a COMPLETED run (out-of-range + meaningless). Fix = the emitter, NOT the docs. workflow.md + README now UNCHANGED (already consistent)."
PR-002 (MINOR, resolved): "Part 1 now also aligns the paired CAUSE lines (planner-rules/SKILL.md:77, troubleshooting.md:5 'has 5+ parts') so each troubleshooting entry is internally consistent with its edited fix line."
PR-003 (MINOR, resolved): "ACs reworded to content-token assertions (not line numbers); both new tests use content grep, not sed line addressing."
```

## Scope

```yaml
in:
  - "F4: canonicalize Sequential-Thinking trigger thresholds to (layers >= 3, Parts >= 4) across the 4 planner-author sites (planner.md use_when, planner-rules/SKILL.md fix+cause lines, troubleshooting.md fix+cause lines) to match the reviewer-grader files + the routing table that already use 4/3."
  - "F2 (Option B): fix state_render.py _render_checkpoint_ref so a completed-run checkpoint (phase_completed=5 / phase_name=completion) emits a completion marker, NOT an out-of-range `--from-phase 5` resume hint."
out:
  - "workflow.md --from-phase range and README.md phase table: UNCHANGED. They already agree Phase 5 is not independently resumable; the prior plan's range-extension is withdrawn."
  - "Reviewer-side ST files (sequential-thinking-guide.md, plan-review-rules/SKILL.md, plan-reviewer.md): UNCHANGED (already 4/3)."
  - "No resume-semantics change for phases 0.7-4 (emitter behaviour for non-completion checkpoints is preserved verbatim)."
  - "No handoff JSON / VERDICT / VERDICT_JSON / discriminator / canonical issue-ID hash / caveman boundary / env var / security hook change."
```

## Architecture Decision

```yaml
decision_F4: "Canonicalize DOWN to (layers >= 3, Parts >= 4). The plan-reviewer ENFORCES missing-ST-on-4+Parts/3+layers as MAJOR (plan-reviewer.md:84, plan-review-rules/SKILL.md:77); planner-rules/SKILL.md:24-27 routing table already states L=4-6 Parts/3+ layers => ST RECOMMENDED. planner.md:476/478 (layers>=4, Parts>=5) currently contradicts BOTH the reviewer and the planner's own routing table. Aligning the planner-author side to 4/3 closes the planner-vs-reviewer divergence that triggers a spurious NEEDS_CHANGES iteration."
decision_F2: "Option B (emitter fix). The authoritative user-facing contract (README.md:266/268) and workflow.md:55 already agree Phase 5 is not independently resumable; recovery into Phase 5 is orchestrator-auto from a phase_completed:4 checkpoint (orchestration-core.md:186), needing no `--from-phase 5` CLI arg. The single defect is state_render.py:_render_checkpoint_ref emitting `--from-phase {phase_completed}` unconditionally, so a phase_completed:5 (completed) checkpoint prints an out-of-range, meaningless resume hint. Guard the terminal case; preserve the hint for all resumable phases."
contract_safety: "All edits are prose/YAML-value (F4) or a localized Python guard in a render helper (F2). No handoff/verdict/caveman/env/security surface. F2 guard is additive (new branch) — behaviour for phase_completed in {0.7,1,2,3,4} is byte-identical to today (golden test test-state-render-golden.sh:118 uses phase_completed=1 → unaffected)."
```

## Tests

```yaml
tdd: "Test-first, content-anchored (no line-number addressing). Both new tests fail red on current tree, pass green after edits. Full suite 97 -> 99, all green."
part1_test: ".claude/scripts/tests/test-st-trigger-threshold-alignment.sh — (a) planner-author sites use layers>=3/Parts>=4 and contain NO residual '>= 5' Parts / '>= 4' layers ST trigger nor '5+ parts' cause prose; (b) reviewer-side sites still state 4/3; (c) cross-file agreement asserted."
part2_test: ".claude/scripts/tests/test-from-phase-resume-hint.sh — (a) checkpoint_ref render of a completion checkpoint (phase_completed=5) does NOT contain '--from-phase 5' and DOES contain a completion marker; (b) regression: a mid-phase checkpoint (phase_completed=2) still emits 'Resume: /workflow --from-phase 2'; (c) consistency guard: workflow.md range still '0.7|1-4' and README still marks Phase 5 '—' (docs intentionally unchanged)."
```

## Acceptance Criteria

```yaml
- "AC-F4-1: planner.md use_when block contains the tokens 'Architecture layers >= 3' and 'Parts in plan >= 4'; the tokens 'Architecture layers >= 4' and 'Parts in plan >= 5' appear nowhere in planner.md."
- "AC-F4-2: planner-rules/SKILL.md and planner-rules/troubleshooting.md contain no residual 'Parts >= 5' / 'Parts ≥ 5' / '5+ parts' token; their ST-fix lines state Parts >= 4 (with layers >= 3, alternatives >= 3)."
- "AC-F4-3: reviewer-side files unchanged (sequential-thinking-guide.md 'layers >= 3' + 'Parts in plan >= 4'; plan-review-rules/SKILL.md '4+ Parts, 3+ layers'); planner-author and reviewer-grader thresholds AGREE."
- "AC-F2-1: checkpoint_ref render of a completion checkpoint emits no '--from-phase 5' substring and emits a completion/no-resume marker."
- "AC-F2-2: checkpoint_ref render of a non-completion checkpoint (phase_completed=2) still emits 'Resume: /workflow --from-phase 2' (behaviour preserved)."
- "AC-F2-3: workflow.md still declares format '0.7|1-4' and README.md still lists Phase 5 --from-phase as '—' (docs intentionally NOT changed; they already agree)."
- "AC-ALL: all .claude/scripts/tests/test-*.sh pass before and after (97 -> 99)."
```

## Parts

```yaml
Part 1:
  name: "F4 — ST trigger threshold alignment (+ cause-line alignment, PR-002)"
  test_first: ".claude/scripts/tests/test-st-trigger-threshold-alignment.sh (red)"
  edits:
    - "planner.md use_when: 'Architecture layers >= 4' -> '>= 3'; 'Parts in plan >= 5' -> '>= 4'"
    - "planner-rules/SKILL.md: cause 'but has 5+ parts.' -> 'but has 4+ parts.'; fix 'Parts >= 5 or alternatives >= 3.' -> 'Parts >= 4, layers >= 3, or alternatives >= 3.'"
    - "planner-rules/troubleshooting.md: cause 'has 5+ parts' -> 'has 4+ parts'; fix 'Parts ≥ 5 or alternatives ≥ 3' -> 'Parts ≥ 4, layers ≥ 3, or alternatives ≥ 3'"
  verify: "bash .claude/scripts/tests/test-st-trigger-threshold-alignment.sh (green)"

Part 2:
  name: "F2 — emitter guard for terminal (completion) checkpoint (Option B)"
  test_first: ".claude/scripts/tests/test-from-phase-resume-hint.sh (red)"
  edits:
    - "state_render.py _render_checkpoint_ref (~367-372): if str(phase_completed)=='5' or phase_name=='completion' -> emit 'Status: complete (Phase 5) — nothing to resume' instead of 'Resume: /workflow --from-phase {phase}'. Preserve the Resume hint for all other phases verbatim."
  verify: "bash .claude/scripts/tests/test-from-phase-resume-hint.sh (green)"
```
