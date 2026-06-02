---
feature: adversarial-design-critique
title: "Adversarial Design Critique (design-stage red-team / multi-perspective viewpoints)"
date: 2026-06-02
status: implemented            # design_proposal | parts_approved | implemented
complexity: XL
author: /workflow (orchestrator)
implemented: [Part 1, Part 2, Part 4]   # GATE 2 selection; Part 3 (clean-context agent) not selected
gates:
  gate_1_inventory: APPROVED    # user approved full-exploration inventory
  gate_2_parts: APPROVED        # user selected Part 1 + 2 + 4
scope_note: >
  Improve the /designer stage + spec-writing phase so the pipeline examines each task
  from critical and unexpected viewpoints, surfacing more cases BEFORE planning. Extends
  contracts additively; does not change the shape of the 4 schema-locked handoffs or the
  canonical issue-ID hash.
---

# Workflow Feature — Adversarial Design Critique

> Research + design artifact. Phases 1–5 = recon + design (this file). Phase 6 = implementation
> of GATE-2-approved parts, each a full XL cycle (planner → plan-reviewer → coder → code-reviewer)
> with TDD. >80% YAML/tables by intent.

---

## Phase 1 — Inventory & Selection  `(GATE 1: APPROVED)`

### 1.1 Self-knowledge reconciliation

```yaml
sources_read:
  - path: ".claude/WORKFLOW-ANALYSIS.md"
    status: ABSENT
    note: "Referenced by task brief + auto-memory as a verification source; file does not exist. Used agent-memory + auto-memory instead."
  - path: ".claude/agent-memory/{plan-reviewer,code-reviewer,code-researcher}/MEMORY.md"
    status: READ
    note: "Confirm: config-as-code layers; review priorities = handoff byte-stability, test-corpus green, caveman boundaries, canonical-ID stability."
  - path: "auto-memory MEMORY.md"
    status: READ (in context)
    note: "Pipeline diagram confirmed; designer = Phase 0.7, L/XL only."
discrepancies:
  - "code-researcher MEMORY says templates=6; actual=7 .md + git-hooks/ dir (cosmetic)."
  - "WORKFLOW-ANALYSIS.md missing (above)."
key_constraint_discovered:
  - id: KC-1
    text: "designer_to_planner is the ONLY handoff with NO $handoff_contract discriminator — NOT schema-validated by validate-handoff.sh. The 4 other contracts are const-locked in handoff.schema.json. This is the safe additive-extension surface."
  - id: KC-2
    text: "save-review-checkpoint.sh (SubagentStop) fires ONLY for matcher plan-reviewer|code-reviewer|verdict-recovery (settings.json:385). Canonical issue-ID hash sha256(category|location|problem) is computed ONLY there. Any critic NOT in that matcher never touches the hash → caveman boundary #5 / IMP-03 untouched."
  - id: KC-3
    text: "/designer runs in orchestrator (command) context — it fires NO SubagentStart/Stop hooks itself. A sub-phase inside /designer touches zero hook wiring."
  - id: KC-4
    text: "code-researcher pattern proves a clean-context agent can be invoked via Agent/Task tool from a command, firing SubagentStart (track-task-lifecycle + caveman-suspend) but NOT SubagentStop save-review-checkpoint. De-anchoring WITHOUT verdict/canonical-ID involvement is achievable."
```

### 1.2 Critical challenge — do we need this?  (verdict requested by user)

```yaml
verdict: "BUILD IT — but only the non-theater form. The naive 'add: consider edge cases' is negative value."
the_real_gap:
  - "Kit philosophy = clean-context adversarial review (plan-reviewer challenges plan, code-reviewer challenges code, both de-anchored)."
  - "Design has NO adversary. /designer Phase 3 self-generates 2-3 approaches + self-recommends; 'risks' = >=1 per approach (shallow self-assessment by the anchored author-context)."
  - "Architectural asymmetry: the two cheapest-to-fix-early defect classes (missed cases, false assumptions) are the ONLY ones with no challenge gate. Shift-left: design defects caught at code-review trigger full re-plan loops (most expensive path)."
challenge_against:
  - id: CH-1  # biggest
    risk: "Theater — generic boilerplate ('consider concurrency/security') burns tokens, zero task-specific insight."
    mitigation_required: "Force CONCRETE task-bound findings, each with an explicit disposition: addressed | accepted-risk | out-of-scope. Gate on dispositions, not on 'did you think about it'."
  - id: CH-2
    risk: "Redundant with plan-reviewer (which can see the spec)."
    finding: "DISPROVEN as duplication. plan-reviewer (required-sections.md) validates that alternatives were DOCUMENTED ('Architecture Decision: >=2 approaches considered') + plan conformance to an ALREADY-FIXED design frame. It never challenges whether the spec missed viewpoints."
    mitigation_required: "Scope critique strictly to DESIGN-level concerns (unexamined cases, false assumptions, unexplored alternatives). Explicitly NOT plan-level (layer allocation, code shape)."
  - id: CH-3
    risk: "Cost + blast radius — /designer is opus/xhigh, runs every L/XL."
    mitigation_required: "Cheapest effective form = structured self-critique sub-phase inside /designer (no new agent, no hook). Max-value form = clean-context critic via Agent tool. Avoid the full pipeline-agent form (touches canonical-ID + schema)."
conditions_to_proceed:
  - "(a) anti-theater forcing function (dispositions) present."
  - "(b) design-level scope only (no plan-review overlap)."
  - "(c) additive extension of the NON-schema-validated designer_to_planner surface + spec YAML; 4 locked contracts + canonical-ID hash untouched."
  - "If (a)-(c) cannot all hold → DO NOT build."
```

### 1.3 Artifact inventory  `R=read  M=modify  X=extend-additively  N=new`

```yaml
core_always:        # touched by any non-trivial approach
  - {id: A1,  path: ".claude/commands/designer.md",                         touch: M, why: "Insert critique sub-phase (Phase 3.5); extend handoff_output (designer.md:64-76)."}
  - {id: A2,  path: ".claude/skills/design-rules/SKILL.md",                 touch: M, why: "Add critique phase-driven loading trigger."}
  - {id: A3,  path: ".claude/skills/design-rules/critique-lenses.md",       touch: N, why: "The multi-lens / red-team criteria (the viewpoints) + disposition forcing-function. Lazy-loaded."}
  - {id: A4,  path: ".claude/templates/spec-template.md",                   touch: X, why: "Add design_critique: YAML block (findings + disposition). Additive; existing keys unchanged."}
  - {id: A5,  path: ".claude/skills/design-rules/design-checklist.md",      touch: M, why: "Add critique self-verification items."}
  - {id: A6,  path: ".claude/skills/design-rules/spec-quality.md",          touch: M, why: "Add critique-completeness gate (dispositions present; accepted-risk needs rationale)."}
core_contract_carry_forward:
  - {id: A7,  path: ".claude/skills/workflow-protocols/handoff-contracts.md", touch: X, why: "Extend designer_to_planner payload (non-schema-validated → safe) with optional critique summary fields."}
  - {id: A8,  path: ".claude/commands/planner.md",                          touch: M, why: "Phase 4 DESIGN consumes critique dispositions from spec; surface unresolved ones into areas_needing_attention (planner.md:424-426)."}
  - {id: A9,  path: ".claude/schemas/handoff.schema.json",                  touch: "X (conditional)", why: "ONLY if critique must flow into the schema-locked planner_to_plan_review. Additive optional field + version bump. DEFAULT: avoid."}
conditional_clean_context_critic:   # tool-agent path (Approach C) — like code-researcher
  - {id: B1,  path: ".claude/agents/design-critic.md",                      touch: N, why: "Clean-context design adversary, invoked by /designer via Agent/Task tool (NOT a pipeline phase, NOT in SubagentStop matcher)."}
  - {id: B2,  path: ".claude/scripts/caveman-suspend-for-reviewer.sh",      touch: "M (optional)", why: "Add design-critic to allowlist so its output is prose. Output is NOT contract-bearing (no canonical IDs) → quality nice-to-have, not correctness."}
  - {id: B3,  path: ".claude/settings.json",                               touch: "M (optional)", why: "Add SubagentStart matcher for design-critic (track-task-lifecycle + caveman-suspend). NO SubagentStop entry (keeps it out of save-review-checkpoint)."}
  - {id: B4,  path: ".claude/agent-memory/design-critic/MEMORY.md",         touch: "N (conditional)", why: "Agent memory baseline if B1 declares memory: project."}
  - {id: B5,  path: ".claude/rules/workflow.md",                            touch: "M (conditional)", why: "Model-routing + component-map entry for design-critic."}
full_pipeline_agent:                # Approach D — NOT recommended (see Phase 4 ranking)
  - {id: C1,  path: ".claude/commands/workflow.md",                         touch: M, why: "New Phase 0.8 delegation."}
  - {id: C2,  path: ".claude/scripts/inject-review-context.sh",            touch: M, why: "Inject design context for the new reviewer."}
  - {id: C3,  path: ".claude/scripts/save-review-checkpoint.sh",            touch: M, why: "Add to REVIEW_AGENTS → TOUCHES canonical-ID hash path (caveman boundary #5). HIGH RISK."}
  - {id: C4,  path: ".claude/skills/workflow-protocols/delegation-templates.md", touch: M, why: "Delegation template + verdict envelope."}
  - {id: C5,  path: ".claude/schemas/handoff.schema.json",                  touch: X, why: "New design_review_verdict contract. Schema risk."}
cross_cutting_any:
  - {id: T1,  path: ".claude/scripts/tests/test-*.sh",                      touch: N, why: "TDD per Part: critique section present, handoff additive, caveman boundary stable, full suite green before+after."}
  - {id: D1,  path: "CLAUDE.md + auto/agent memory",                       touch: M, why: "Document new sub-phase/agent + counts. Light."}
excluded:
  - "meta-agent, project-researcher, db-explorer — out of scope per brief."
  - "verdict-recovery — touched ONLY by Approach D (verdict envelope). Recommended approaches feed the existing designer user-gate → verdict-recovery untouched."
```

---

## Phase 2 — Deep-Read (role / in-out / contract / hook-triggers of each touched artifact)

```yaml
designer.md:
  role: "Solution Architect (command, orchestrator-context). Phase 0.7, L/XL only."
  pipeline: "EXPLORE(1) → CLARIFY(2) → PROPOSE(3) → WRITE SPEC(4) → USER GATE(5)."
  current_critique_surface: "Phase 3 PROPOSE = 2-3 approaches, pros/cons, self-recommend. risks >=1/approach (spec-quality.md). NO adversarial pass."
  output_contract: "{feature}-spec.md + designer_to_planner handoff (NON-schema-validated)."
  hook_triggers: "NONE fired by designer itself (runs in orchestrator context)."
  attach_point: "New Phase 3.5 CRITIQUE between PROPOSE (selected approach) and WRITE SPEC (documents it)."

spec-template.md:
  role: "Output of /designer, input to /planner, validated by plan-reviewer."
  shape: "YAML (meta:, spec:). Keys: context, requirements, approach{selected,alternatives}, key_decisions, risks, acceptance_criteria, notes."
  extension: "Add spec.design_critique: (NEW key). YAML key, NOT an H2 header → does not collide with caveman-protected H2 set."

design-rules (SKILL.md / design-checklist.md / spec-quality.md):
  role: "Loaded at /designer startup; phase-driven supporting files."
  extension: "Add critique trigger (SKILL), critique checklist items (design-checklist), critique completeness gate (spec-quality)."

handoff-contracts.md → designer_to_planner:
  current_payload: "spec_artifact, metadata{task_type,complexity,approaches_considered,sequential_thinking_used}, key_decisions[], known_risks[], acceptance_criteria_count."
  discriminator: NONE  # KC-1 — not schema-validated
  extension: "Add OPTIONAL critique_summary{total, addressed, accepted_risk, out_of_scope, unresolved_high[]}. Backward-compatible (consumer SKIPs if absent)."

planner.md:
  consumes_spec: "startup step 0.5 (load spec); phase_4_design ('use spec selected approach + key decisions as starting point')."
  extension: "phase_4_design: also read spec.design_critique; map unresolved/accepted-risk HIGH findings into areas_needing_attention[] (carry-forward into the schema-locked planner_to_plan_review — but as free-text strings in an EXISTING array field, NOT a shape change)."

plan-reviewer.md + required-sections.md:
  role: "Phase 2 agent. Validates plan required sections + architecture + spec alignment (sees spec for L/XL)."
  overlap_finding: "Validates alternatives DOCUMENTED + conformance. Does NOT adversarially test design viewpoints. NO overlap if critique stays design-level (CH-2 mitigation)."
  hook_triggers: "SubagentStart inject-review-context.sh + caveman-suspend; SubagentStop save-review-checkpoint.sh (BLOCKING, canonical-ID)."

save-review-checkpoint.sh:
  role: "SubagentStop BLOCKING; appends VERDICT marker + canonical_issue_ids to review-completions.jsonl. Computes sha256(category|location|problem)[:8]."
  matcher: "plan-reviewer|code-reviewer|verdict-recovery (settings.json:385)."
  implication: "Critic NOT in matcher ⇒ never runs this ⇒ canonical-ID hash + caveman boundary #5 untouched (KC-2). This is the contract-safety pivot."

inject-review-context.sh:
  role: "SubagentStart for plan-reviewer|code-reviewer. Emits additionalContext (checkpoint, prior verdicts, delta-focus, PK slots). CAP=6000 chars."
  agent_dispatch: "Behavior keyed on $1 agent_type. New agent_type would need a branch (Approach D only)."

caveman-suspend-for-reviewer.sh:
  role: "SubagentStart. Allowlist plan-reviewer|code-reviewer|verdict-recovery|code-researcher → injects 'caveman OFF' so contract-bearing output stays prose."
  extension_C: "Add design-critic to allowlist (optional — output not contract-bearing)."

settings.json:
  role: "Authoritative hook wiring. SubagentStart matchers (304-382), SubagentStop matcher (383-394)."
  extension_C: "Optional SubagentStart matcher for design-critic. NO SubagentStop matcher (deliberate)."
```

---

## Phase 3 — Interaction Graph (directed; node = artifact, edge = typed relation)

```yaml
edge_types: {H: handoff-payload, K: hook-call, L: load-dependency, F: file-read/write, N: NEW-or-changed-by-feature}

current_graph:
  - "task-analysis --H--> designer.md            (complexity L/XL → Phase 0.7)"
  - "designer.md   --L--> design-rules/SKILL.md  (startup step 0)"
  - "design-rules  --L--> spec-quality.md, design-checklist.md (phase-driven)"
  - "designer.md   --F--> spec-template.md        (Phase 4 write)"
  - "designer.md   --F--> {feature}-spec.md       (output)"
  - "designer.md   --H--> planner.md              (designer_to_planner, NON-validated)"
  - "planner.md    --F--> {feature}-spec.md       (startup 0.5 + phase_4 read)"
  - "planner.md    --H--> plan-reviewer           (planner_to_plan_review, SCHEMA-LOCKED)"
  - "plan-reviewer <--K-- inject-review-context.sh (SubagentStart)"
  - "plan-reviewer --K--> save-review-checkpoint.sh (SubagentStop, canonical-ID)"

feature_attach_points:
  new_nodes:
    - "design-rules/critique-lenses.md            [N] — the viewpoints + disposition forcing-function"
    - "(Approach C) agents/design-critic.md       [N] — clean-context critic (tool-agent)"
  new_edges:
    - "designer.md --L--> critique-lenses.md       [N,L]  (loaded at Phase 3.5)"
    - "designer.md --(Phase 3.5)--> design_critique findings  [N]"
    - "design_critique --F--> spec-template.md (design_critique: block)  [N,F]"
    - "(Approach C) designer.md --Agent/Task--> design-critic.md  [N]  (clean-context, fires SubagentStart only)"
    - "(Approach C) design-critic <--K-- caveman-suspend (optional allowlist add)  [N,K]"
  changed_edges:
    - "designer.md --H--> planner.md : payload GAINS optional critique_summary  [X]  (still NON-validated)"
    - "planner.md phase_4 : READS spec.design_critique → maps HIGH-unresolved into areas_needing_attention[]  [X]  (existing array field, free-text)"
  explicitly_NOT_touched:
    - "planner_to_plan_review / plan_review_to_coder / coder_to_code_review / code_review_to_completion JSON SHAPE"
    - "save-review-checkpoint.sh canonical-ID hash (no critic in SubagentStop matcher)"
    - "caveman boundaries #1-#7 (VERDICT lines, JSON sentinels, protected H2 set, file:line, Part ids)"
```

---

## Phase 4 — Feature Design

### 4.1 Design elements  (each: attach point · what · contract-preservation · integration impact)

```yaml
DE-1_critique_subphase:
  attach: "designer.md — new Phase 3.5 'CRITIQUE / RED-TEAM' (between PROPOSE Phase 3 and WRITE SPEC Phase 4)."
  what: >
    Take the Phase-3 SELECTED approach. Run it through N fixed adversarial lenses
    (critique-lenses.md). Each lens MUST yield either a concrete task-bound finding OR an
    explicit 'no finding — reason' line. Every finding gets a disposition:
    addressed | accepted-risk | out-of-scope. Output = design_critique findings list.
  contract_preservation: "designer runs in orchestrator context — no hook, no schema, no canonical-ID. Pure new sub-phase."
  integration: "Feeds Phase 4 WRITE SPEC (DE-3). User gate (Phase 5) now also surfaces unresolved-HIGH findings."

DE-2_critique_lenses:
  attach: "design-rules/critique-lenses.md [N]"
  what: >
    Fixed lens set forcing breadth + anti-theater. Proposed lenses (tunable):
    (1) Failure-mode / unhappy-path  (2) Hidden-assumption inversion ('what if the core
    assumption is false?')  (3) Boundary & scale (empty/huge/concurrent/partial)
    (4) Adversarial misuse / security  (5) Operability & recovery (failure, rollback,
    observability)  (6) Contract & integration blast-radius (esp. for kit-meta tasks:
    handoff/verdict/caveman/canonical-ID)  (7) Cost / second-order effects.
    Each lens: prompt + 'concrete-finding-or-explicit-skip' rule + disposition enum.
  contract_preservation: "Lazy-loaded skill file; no runtime contract."
  integration: "Loaded by designer.md Phase 3.5 + (Approach C) read by design-critic.md."

DE-3_spec_critique_block:
  attach: "spec-template.md — new spec.design_critique: YAML key [X]"
  what: |
    design_critique:
      lenses_applied: [failure_mode, assumptions, boundary, misuse, operability, contracts, cost]
      findings:
        - id: "DC-1"                 # local id; NOT hashed, NOT a verdict envelope
          lens: "boundary"
          finding: "Complete sentence describing the missed case."   # caveman: full sentence
          severity: "HIGH|MEDIUM|LOW"
          disposition: "addressed|accepted-risk|out-of-scope"
          rationale: "Required when disposition != addressed."
          influences: "approach.selected | key_decisions[N] | acceptance_criteria[N] | out_of_scope"
      summary: {total: N, addressed: N, accepted_risk: N, out_of_scope: N, unresolved_high: 0}
  contract_preservation: "Additive YAML key under spec:. Not an H2 header (caveman H2 set untouched). DC-* ids are local, never hashed."
  integration: "Written by designer Phase 4; read by planner phase_4 + plan-reviewer (already reads spec for L/XL)."

DE-4_handoff_carry_forward:
  attach: "handoff-contracts.md designer_to_planner [X] + planner.md phase_4 [M]"
  what: >
    designer_to_planner gains OPTIONAL critique_summary (mirror of DE-3 summary +
    unresolved_high[] findings). planner phase_4 reads spec.design_critique and maps each
    HIGH finding with disposition in {accepted-risk, out-of-scope-but-risky} into the EXISTING
    areas_needing_attention[] array of planner_to_plan_review (free-text strings).
  contract_preservation: >
    designer_to_planner is non-schema-validated (KC-1) — adding a key is safe.
    planner_to_plan_review SHAPE is unchanged: we only append strings to an existing array
    (areas_needing_attention[]) that already accepts free-text. Caveman boundary #5: these are
    full sentences in a JSON free-text array — compliant.
  integration: "Design findings become visible to plan-reviewer through the standard channel it already consumes."

DE-5_clean_context_critic:   # Approach C — opt-in escalation
  attach: "agents/design-critic.md [N], invoked by designer.md Phase 3.5 via Agent/Task tool"
  what: >
    A de-anchored critic (separate context, like code-researcher) that receives the selected
    approach + spec draft and returns findings in the DE-3 shape (bounded output, e.g. <=2000
    tokens). designer merges/dedups into design_critique. Synchronous (designer needs findings
    before WRITE SPEC).
  contract_preservation: >
    Invoked via Agent/Task tool → fires SubagentStart (track-task-lifecycle + optional
    caveman-suspend) but NOT SubagentStop save-review-checkpoint (not in matcher, KC-2/KC-4).
    No verdict envelope, no canonical-ID, no schema. Output is advisory data, not a gate.
  integration: "Optional. Graceful fallback: if Agent tool unavailable/fails → designer falls back to inline DE-1 self-critique. Recommend XL-only (or opt-in) to bound cost."
  unverified: "[UNVERIFIED] exact token/latency cost of an extra opus/sonnet critic per XL run — measure before defaulting on. Mitigation: default to inline (DE-1), make DE-5 opt-in."
```

### 4.2 Alternatives considered (ranked) + 5-axis metric

```yaml
axes: "Contract-safety, Reliability, Token/cost, Blast-radius, Effort(inverse). Each 1-5; rank = sum. Higher = better."

approaches:
  A_inline_freeform:
    desc: "Add a free-form 'critique the design' paragraph to designer Phase 4."
    contract_safety: 5
    reliability: 2     # same-context anchoring; no forcing function → theater
    token_cost: 4
    blast_radius: 5
    effort_inv: 5
    sum: 21
    impact: LOW
    rejected_because: "Fails CH-1 (theater). No disposition forcing function. Negative-value risk."

  B_inline_lenses_dispositions:
    desc: "Structured Phase 3.5 with fixed lenses (critique-lenses.md) + forced dispositions written to spec.design_critique. No new agent."
    contract_safety: 5
    reliability: 4     # forcing function reduces theater; no new failure modes
    token_cost: 4
    blast_radius: 5    # CORE only (A1-A8)
    effort_inv: 4
    sum: 22
    impact: MEDIUM-HIGH
    note: "Highest metric sum. Always-on for L/XL. Satisfies CH-1/CH-2/CH-3."

  C_tool_agent_critic:
    desc: "Clean-context design-critic via Agent/Task tool (like code-researcher). De-anchored. Feeds spec.design_critique."
    contract_safety: 5  # no SubagentStop, no schema, no canonical-ID (KC-2/KC-4)
    reliability: 4      # clean context = better critique; needs graceful fallback to B
    token_cost: 3       # extra agent spin-up; bounded output; XL-only mitigates
    blast_radius: 4     # +agent file +optional caveman allowlist +optional settings matcher
    effort_inv: 3
    sum: 19
    impact: HIGH
    note: "True de-anchoring without touching the hashed/locked path. Best impact-per-risk for XL."

  D_full_pipeline_agent:
    desc: "New design-reviewer pipeline agent (Phase 0.8), emits VERDICT_JSON, gated, via save-review-checkpoint."
    contract_safety: 2  # touches canonical-ID hash (caveman #5) + new schema verdict contract
    reliability: 3      # new loop, new verdict-recovery surface, new compaction edge-cases
    token_cost: 2       # full opus reviewer every L/XL + possible loop
    blast_radius: 1     # ~10 files incl hooks + schema
    effort_inv: 1
    sum: 9
    impact: HIGHEST-rigor
    rejected_because: "Dominated. Maximal contract risk for a gate the designer user-approval already provides. Violates CH-3 cost. Only justified if a hard machine-enforced design gate is a hard requirement (it is not)."

  E_hybrid_B_plus_C:
    desc: "B always-on for L/XL (foundation). C as opt-in escalation for XL (or flag-gated). Decomposed so B lands first; C is a later part."
    contract_safety: 5
    reliability: 4
    token_cost: 3
    blast_radius: 4
    effort_inv: 3
    sum: 19
    impact: HIGHEST achievable under constraints
    note: "Recommended. Captures B's safety/always-on value, adds C's de-anchoring only where it pays (XL), keeps C optional with fallback to B."

ranking: "B (22) ≈ E (19, but highest impact) > C (19) > A (21 sum but LOW impact) > D (9). Recommend E, delivered B-first."
```

### 4.3 Recommendation + evidence

```yaml
recommended: "E (hybrid), delivered as B-first then C-as-opt-in."
rationale:
  - "B is the contract-safe, always-on foundation: forced lenses + dispositions in spec.design_critique. Closes the design-adversary gap with zero hook/schema/canonical-ID exposure."
  - "C adds genuine de-anchoring (clean context) for XL where missed-case cost is highest, WITHOUT entering the save-review-checkpoint matcher — so canonical-ID + caveman #5 stay byte-stable (KC-2)."
  - "D rejected: the only thing it adds over C is a machine-enforced verdict gate, which duplicates the existing designer user-approval gate while incurring maximal contract risk."
evidence:
  - "before/after structural: today design has 0 adversarial gates vs plan(1)/code(1). After: design gains 1 forced-lens critique (B) [+1 de-anchored critic for XL (C)]."
  - "plan-reviewer required-sections.md proves no design-viewpoint adversary exists today (only 'alternatives documented' conformance check) — CH-2 disproven by source."
  - "KC-2 verified against settings.json:385 (SubagentStop matcher) — critic outside matcher provably cannot mutate canonical IDs."
unverified_assumptions:
  - "[UNVERIFIED] per-run token/latency cost of C's extra critic — MEASURE in Phase 6 before defaulting on; ship C opt-in/XL-only."
  - "[UNVERIFIED] optimal lens count (7 proposed) — too many = token bloat, too few = blind spots. Tune empirically; lens list lives in one file (A3) for cheap iteration."
no_new_env_vars: "Default plan adds NONE. If C needs an on/off switch, prefer reusing complexity routing (XL-only) over a new env var (per env-restraint feedback). A flag is a LAST resort with separate justification."
```

---

## Phase 5 — Decomposition into Parts + Acceptance Criteria  `(GATE 2)`

> Each Part = one full XL cycle in Phase 6 (planner → plan-reviewer → coder → code-reviewer), TDD test-first.
> Parts ordered by dependency + value density. Part 1 is the contract-safe foundation; later parts are additive.

```yaml
part_1:
  name: "Part 1: Inline multi-lens design critique (Approach B core)"
  delivers: "DE-1 + DE-2 + DE-3"
  files: [A1 designer.md, A2 design-rules/SKILL.md, A3 critique-lenses.md (N), A4 spec-template.md, A5 design-checklist.md, A6 spec-quality.md, T1 tests]
  acceptance_criteria:
    - "AC1.1: designer.md has a Phase 3.5 CRITIQUE between PROPOSE and WRITE SPEC; runs for L/XL."
    - "AC1.2: critique-lenses.md defines the lens set; each lens forces a concrete finding OR explicit 'no finding — reason'."
    - "AC1.3: spec-template.md has spec.design_critique with findings[] + disposition enum {addressed,accepted-risk,out-of-scope} + summary."
    - "AC1.4: a finding with disposition != addressed without rationale is flagged by spec-quality gate (test asserts)."
    - "AC1.5 (contract): designer_to_planner + the 4 schema-locked handoffs unchanged in shape; validate-handoff tests green."
    - "AC1.6 (caveman): design_critique is a YAML key, not an H2; protected H2 set + canonical-ID hash untouched (test asserts no save-review-checkpoint change)."
    - "AC1.7: full .claude/scripts/tests suite green before AND after."
    - "AC1.8: a test exists per change and passes."

part_2:
  name: "Part 2: Critique carry-forward to planner + handoff"
  delivers: "DE-4"
  files: [A7 handoff-contracts.md, A8 planner.md, T1 tests]
  depends_on: part_1
  acceptance_criteria:
    - "AC2.1: handoff-contracts.md designer_to_planner gains OPTIONAL critique_summary (documented as optional/back-compat)."
    - "AC2.2: planner.md phase_4 reads spec.design_critique; HIGH unresolved/accepted-risk findings appended to areas_needing_attention[] (existing array)."
    - "AC2.3 (contract): planner_to_plan_review SHAPE unchanged — only free-text strings appended to existing array; schema validation green."
    - "AC2.4: back-compat — spec WITHOUT design_critique still planned correctly (test asserts SKIP path)."
    - "AC2.5: full test suite green before+after; test-per-change."

part_3:
  name: "Part 3: Clean-context design-critic (Approach C, opt-in / XL)"
  delivers: "DE-5"
  files: [B1 design-critic.md (N), B2 caveman-suspend (opt), B3 settings.json (opt), B4 agent-memory (cond), B5 rules/workflow.md, T1 tests]
  depends_on: part_1
  acceptance_criteria:
    - "AC3.1: design-critic.md exists; invoked by designer Phase 3.5 via Agent/Task tool; returns DE-3-shaped findings (bounded output)."
    - "AC3.2 (contract): design-critic is NOT in SubagentStop matcher → save-review-checkpoint never fires for it → canonical-ID hash untouched (test asserts matcher unchanged)."
    - "AC3.3: graceful fallback — Agent tool unavailable/failure → designer falls back to Part-1 inline critique (test asserts fallback)."
    - "AC3.4: cost bound — critic runs XL-only (or opt-in); NO new env var unless separately justified."
    - "AC3.5 (caveman): if added to caveman-suspend allowlist, allowlist test updated; design-critic emits prose."
    - "AC3.6: [UNVERIFIED] token/latency measured + recorded (before/after) in pipeline-metrics.jsonl; default-on only if net-positive."
    - "AC3.7: full test suite green before+after; test-per-change."

part_4:
  name: "Part 4: Docs + memory + counts"
  delivers: "D1"
  files: [CLAUDE.md, auto/agent memory, README if needed]
  depends_on: [part_1]   # can run after part_1; folds in part_2/3 docs if those landed
  acceptance_criteria:
    - "AC4.1: CLAUDE.md documents the critique sub-phase (+ critic if Part 3 landed); component counts updated."
    - "AC4.2: check-references.sh + check-artifact-size.sh green; CLAUDE.md within size budget."
    - "AC4.3: full test suite green."

global_acceptance_criteria:   # apply to EVERY part (from task brief)
  - "Contracts plan↔plan-reviewer↔coder↔code-reviewer keep their shape (handoff JSON, VERDICT/VERDICT_JSON)."
  - "Canonical issue ID sha256(category|location|problem)[:8] byte-stable (issue.problem/suggestion text not fragmented)."
  - "All .claude/scripts/tests/*.sh pass before AND after."
  - "Every change has a test, and it passes."

recommended_selection:
  must: [part_1]                  # the contract-safe, high-value foundation
  strong: [part_2]                # makes critique visible downstream (cheap, high leverage)
  optional: [part_3]             # de-anchoring for XL; measure cost first
  always_last: [part_4]          # docs
  suggested_topN: "Part 1 + Part 2 + Part 4 (safe high-value set). Add Part 3 if you want true de-anchoring and accept a measure-first cost check."
```
