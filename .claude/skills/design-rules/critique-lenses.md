---
name: design-critique-lenses
description: Adversarial design-critique lens set for /designer Phase 3.5. Load just-in-time at Phase 3.5. Forces concrete, task-bound, multi-perspective findings with explicit dispositions (anti-theater).
disable-model-invocation: true
---

# Design Critique Lenses (Phase 3.5)

## Purpose

Stress-test the SELECTED approach (from Phase 3 PROPOSE) from critical and unexpected
viewpoints BEFORE the spec is written. Goal: surface missed cases, false assumptions,
and unexplored angles while they are cheapest to fix.

## Scope discipline (anti-overlap)

Critique DESIGN-level concerns only: missed cases, false assumptions, unexplored
alternatives, integration blast-radius. Do NOT critique plan-level concerns (layer
allocation, code shape, file-by-file structure) — that is plan-reviewer's job in Phase 2.

## The Forcing Function (anti-theater — MANDATORY)

For EACH lens below, produce EITHER:

- a concrete, task-bound finding (names the specific case/assumption/risk for THIS task), OR
- an explicit `no finding — <one-line reason>` line.

Generic boilerplate ("consider concurrency", "think about security") with no task-specific
content is NOT a finding — it counts as a skipped lens and fails the spec-quality gate.

Every finding MUST carry a disposition:

- `addressed`     — the design is changed to handle it (note how, in `influences`).
- `accepted-risk` — knowingly not handled now; `rationale` REQUIRED.
- `out-of-scope`  — outside this task's boundary; `rationale` REQUIRED.

## Lenses

1. **Failure-mode / unhappy-path** — what happens when the normal path does not hold?
   (errors, missing inputs, partial state, retries.)
2. **Hidden-assumption inversion** — list the load-bearing assumptions; for each ask
   "what if this is FALSE?" Surface the ones that would break the design.
3. **Boundary & scale** — empty / single / huge / concurrent / slow / repeated inputs;
   limits, ordering, idempotency.
4. **Adversarial misuse / security** — how could a hostile or careless actor abuse this?
   (injection, escalation, data exposure, resource exhaustion.)
5. **Operability & recovery** — how is failure detected, rolled back, observed? Migration,
   backward-compatibility, and "what does on-call see?"
6. **Contract & integration blast-radius** — what other components does this touch? For
   kit-meta tasks: handoff/verdict envelopes, caveman boundaries, canonical-ID hash stability.
7. **Cost & second-order effects** — token/latency/maintenance cost; incentives it creates;
   what it makes harder later.

## Coverage rule

Apply ALL lenses. Skipping a lens requires the explicit `no finding — reason` line.
At minimum, surface findings for the lenses most relevant to the task type.

## Output

Write results into the spec's `design_critique:` block (see spec-template.md). Local finding
ids (`DC-1`, `DC-2`, …) are for in-spec reference ONLY — they are NOT the canonical issue ID
(`sha256(category|location|problem)[:8]`) and never enter any verdict envelope or hook.
