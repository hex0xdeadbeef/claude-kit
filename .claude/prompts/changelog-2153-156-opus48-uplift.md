---
status: plan
type: implementation
complexity: XL
feature: changelog-2153-156-opus48-uplift
date: 2026-05-29
source_backlog: .claude/workflow-audit-2026-05-29.md (§5, GATE 2 approved set)
approved_set: [IMP-1, IMP-2, IMP-4, IMP-7, IMP-5]
new_env_vars: 0
contract_changes: 0
handoff_output:
  $handoff_contract: planner_to_plan_review
  artifact: .claude/prompts/changelog-2153-156-opus48-uplift.md
  metadata: { task_type: config_doc_uplift, complexity: XL, sequential_thinking_used: true }
  key_decisions:
    - "Migrate effort frontmatter max to xhigh because max is session-only and rejected in frontmatter on Claude Code 2.1.154 with Opus 4.8 (valid set low, medium, high, xhigh)."
    - "Re-align Phase 2.5 SIMPLIFY docs to the 2.1.154 cleanup-only definition of /simplify (reuse, simplification, efficiency, altitude) and drop the stale 2.1.152 identity with /code-review --fix."
    - "All five improvements are documentation or frontmatter edits plus one test each, leaving every handoff JSON, VERDICT envelope, and canonical issue-ID input byte-stable."
  known_risks:
    - "Broad test-effort-xhigh-frontmatter.sh could fail on the off-hot-path meta-agent and project-researcher commands, so Part 1 also migrates those two files for a consistent invariant."
    - "test-simplify-semantics-doc.sh already exists and asserts the 2.1.152 wording, so Part 2 must rewrite that test rather than only adding a new one."
---

# Plan: Claude Code 2.1.153–2.1.156 (Opus 4.8) Workflow Uplift

## Scope

Implement the GATE-2-approved improvements IMP-1, IMP-2, IMP-4, IMP-7, IMP-5 from
`.claude/workflow-audit-2026-05-29.md` §5. Each Part is test-first (TDD Red→Green), one at a
time, with the full `.claude/scripts/tests` suite green before and after. No `settings.json`
permission/hook edits. No new environment variables. No data-contract changes.

## Architecture Decision

- **Effort frontmatter (IMP-1):** Claude Code 2.1.154 + Opus 4.8 accept frontmatter `effort`
  values `low|medium|high|xhigh` only; `max` is a session-only `/effort` value and is not honored
  in frontmatter/settings, so pipeline agents silently degrade to default `high`. Correct value
  for "maximum reasoning" on Opus 4.8 is `xhigh`. This is a value swap, not a contract change.
- **SIMPLIFY semantics (IMP-2):** `/simplify` on 2.1.154+ is a cleanup-only review
  (reuse/simplification/efficiency/altitude) that applies fixes — NOT the bug-hunting
  `/code-review --fix` it aliased on 2.1.152. Re-align prose + mermaid; keep the
  `simplify_applied: true|false|skipped` handoff field unchanged.
- **Docs (IMP-4, IMP-7):** additive CLAUDE.md / workflow.md sections; no behavior change.
- **Defense-in-depth (IMP-5):** `code-researcher` is read-only (output ≤2000-token summary),
  so `disallowed-tools: [Write, Edit, NotebookEdit]` adds a platform-level guarantee. Reviewers
  are NOT touched (they need Write for agent-memory sync).

## Tests

One test per Part; all must be Red before the edit and Green after. Full suite
(`rc=0; for f in .claude/scripts/tests/test-*.sh; do bash "$f" || rc=1; done; exit $rc`) green
before and after every Part.

- Part 1 → `test-effort-xhigh-frontmatter.sh` (new): no pipeline frontmatter contains
  `effort: max`; every `effort:` value ∈ {low,medium,high,xhigh}.
- Part 2 → `test-simplify-semantics-doc.sh` (rewrite existing): asserts 2.1.154 cleanup-only
  wording across coder.md / workflow.md / orchestration-core.md / CLAUDE.md; cross-consistent.
- Part 3 → `test-platform-guarantees-doc.sh` (new): CLAUDE.md has the section + ≥6 version rows.
- Part 4 → `test-workflow-disambiguation-doc.sh` (new): the /workflow-vs-/workflows note exists.
- Part 5 → `test-code-researcher-readonly.sh` (new): code-researcher.md frontmatter contains the
  disallowed-tools list.

## Acceptance Criteria

- All AC in `.claude/workflow-audit-2026-05-29.md` §5 per IMP are met.
- `.claude/scripts/tests` suite green before AND after each Part (exit-code-safe runner).
- Handoff JSON shapes, `VERDICT:`/`VERDICT_JSON:` envelopes, and the
  `sha256(category|location|problem)[:8]` canonical-ID input are byte-stable.
- No new env-vars; `settings.json` permissions/hooks unchanged; commits exclude `settings.json`.

## Parts

Part 1: Migrate `effort: max` → `effort: xhigh` in pipeline frontmatter
(code-reviewer.md, plan-reviewer.md, planner.md, coder.md, designer.md, workflow.md; plus
off-hot-path meta-agent.md, project-researcher.md for a consistent invariant) and refresh the
model-routing doc in rules/workflow.md + CLAUDE.md (Opus 4.8 default high, xhigh top frontmatter
level, max is session-only). Test-first: `test-effort-xhigh-frontmatter.sh`.

Part 2: Re-align Phase 2.5 SIMPLIFY to 2.1.154 cleanup-only semantics in coder.md (purpose,
step_2, guard note), workflow.md simplify_note, orchestration-core.md mermaid label, and the
CLAUDE.md SIMPLIFY sub-phase note. Test-first: rewrite `test-simplify-semantics-doc.sh`.

Part 3: Add "Platform Guarantees Relied Upon" section to CLAUDE.md (≥6 feature→version→reliance
rows, including 2.1.154 worktree-isolation guard for background subagents and the 1M-context
premature-out-of-context notification fix). Test-first: `test-platform-guarantees-doc.sh`.

Part 4: Add a `/workflow` (kit pipeline) vs native `/workflows` (dynamic-workflows / Workflow
tool, 2.1.154) disambiguation note to CLAUDE.md + workflow.md. Test-first:
`test-workflow-disambiguation-doc.sh`.

Part 5: Add `disallowed-tools: [Write, Edit, NotebookEdit]` to code-researcher.md frontmatter
(read-only defense-in-depth; reviewers untouched). Test-first: `test-code-researcher-readonly.sh`.
