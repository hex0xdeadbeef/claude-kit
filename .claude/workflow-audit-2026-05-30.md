# Workflow Pipeline — Context-Consumption Audit (2026-05-30)

> Goal: reduce CONTEXT/TOKEN cost of the `/workflow` pipeline at SAME functionality, contracts intact.
> Method: clean-room multi-agent recon (9 deep-read clusters → 6-lens hunt → adversarial verify → ranked synthesis).
> Provenance: workflow run `wf_0361e3dc-6f6`, 53 agents, 37 findings → 29 confirmed / 8 refuted. Top facts re-verified by hand.
> No prior `.claude/WORKFLOW-ANALYSIS.md` existed — clean start.

```yaml
audit_meta:
  date: 2026-05-30
  scope_gate: GATE_1_approved_as_is   # incl. borderline scripts caveman-activate/track-task-lifecycle/mcp-preload-warn/check-uncommitted
  method: workflow_fanout
  contracts_protected:
    - handoff: [planner_to_plan_review, plan_review_to_coder, coder_to_code_review, code_review_to_completion]
    - verdict: "VERDICT enum line + fenced VERDICT_JSON block"
    - canonical_id: "sha256(category|location|problem)[:8] — byte-stable"
    - caveman_boundaries: "VERDICT lines, JSON keys, plan H2 headers, file:line — verbatim"
  constraints: [no_new_env_vars, all_86_tests_green_before_and_after, one_test_per_change]
```

---

## Phase 1 — Inventory & Scope (GATE 1: approved)

```yaml
in_scope:
  commands: [workflow.md (435L), planner.md (538L), coder.md (609L), designer.md (183L)]
  agents: [code-reviewer.md (422L/28KB), plan-reviewer.md (372L/23KB), code-researcher.md (139L), verdict-recovery.md (82L)]
  skills:
    workflow-protocols: {files: 17, lines: 2557}
    tdd-rules: {files: 10, lines: 917}
    planner-rules: {files: 15, lines: 904}
    coder-rules: {files: 7, lines: 661}
    plan-review-rules: {files: 5, lines: 522}
    code-review-rules: {files: 5, lines: 367}
    design-rules: {files: 3, lines: 125}
  scripts_hotpath: [save-review-checkpoint.sh (754L), inject-review-context.sh (691L), save-progress-before-compact.sh (352L),
                    validate-handoff.sh (284L), verify-state-after-compact.sh (187L), check-uncommitted.sh (158L),
                    enrich-context.sh (148L), sync-agent-memory.sh (123L), caveman-activate.sh (103L),
                    track-task-lifecycle.sh (99L), caveman-suspend-for-reviewer.sh (57L), mcp-preload-warn.sh (35L)]
  wiring: [settings.json (hooks block), rules/workflow.md (78L), templates/plan-template.md, templates/spec-template.md]
excluded:
  - meta-agent/, project-researcher/, db-explorer/  # user-excluded, not /workflow hot path
  - meta-agent/scripts/{check-references,check-plan-drift,check-artifact-size,yaml-lint,verify-phase-completion}.sh  # authoring-time, owned by meta-agent
  - security/format/telemetry/notify hooks  # not context-consumption path
test_corpus: {dir: .claude/scripts/tests, count: 86}
```

---

## Phase 2 — Eager-Load Footprint (the heart of context cost)

Context cost is dominated by what loads **eagerly** (unconditionally into a context window) vs **on-demand**.
The pipeline's on-demand design is mostly sound; the waste is concentrated in eager prefixes.

```yaml
eager_load_per_context:    # tokens are approximations from byte counts (~4 chars/token)
  every_session:
    - CLAUDE.md: "always-loaded project instructions (~200-line budget)"
    - rules/workflow.md: "5060B / ~1265 tok — UNSCOPED (no frontmatter) → loads every session [FINDING #2]"
    - rules/{architecture,go-conventions,testing,handler,service,repository,models}.md: "path-scoped — load only when editing matching files (correct)"
    - auto-memory MEMORY.md + agent-memory MEMORY.md: "first 200 lines each [FINDING #6: stale facts]"
    - caveman SKILL body: "injected EVERY SessionStart, no workflow gate [observed, not top-12]"
  every_workflow_invocation:
    - commands/workflow.md: "22868B / ~5.7k tok (whole file; no disable-model-invocation)"
    - workflow-protocols: "SKILL.md (115L) + autonomy.md (25L) + orchestration-core.md (194L) eager; other 14 files on-demand"
  planner_phase:
    - commands/planner.md: "26345B / ~6.6k tok (whole file)"
    - planner-rules: "SKILL.md (93L) + mcp-tools.md (37L) eager; task-analysis/seq-thinking/data-flow/code-shapes on-demand"
  coder_phase:
    - commands/coder.md: "27786B / ~6.9k tok (whole file)"
    - coder-rules: "SKILL.md (125L) + mcp-tools.md (71L) + spec-check.md (76L, eager but only used Phase 3.5 [FINDING #7])"
    - tdd-rules: "SKILL.md (71L) UNCONDITIONAL + tdd-shapes/go.md (123L) — cascade resolves to ONE language file (correct)"
  plan_review_phase:
    - agents/plan-reviewer.md: "23417B / ~5.85k tok + plan-review-rules/SKILL.md (4744B / ~1.19k tok) = ~7.04k tok eager"
    - SubagentStart inject-review-context.sh additionalContext (PK block + delta + metrics)
  code_review_phase:
    - agents/code-reviewer.md: "28122B / ~7.03k tok + code-review-rules/SKILL.md (6502B / ~1.63k tok) = ~8.66k tok eager"
    - SubagentStart inject-review-context.sh additionalContext

healthy_lazy_design:   # confirmed NOT problems (would be false positives)
  - workflow-protocols/SKILL.md L24: "Do NOT load all protocols upfront" — 14 of 17 files are on-demand
  - tdd-shapes + code-shapes: cascade selects ONE language file; other 4 + _default never load on a Go run
  - enrich-context.sh: hash-guarded (sha256 checkpoint → sys.exit(0) on match) — no per-turn re-injection
```

---

## Phase 3 — Interaction Graph (directed; edge types)

```yaml
edge_types: {H: handoff_payload, K: hook_call, L: load_dependency, I: context_injection}

nodes_and_edges:
  workflow.md:
    - L→ workflow-protocols/{SKILL,autonomy,orchestration-core}.md (eager)
    - H→ planner.md (planner_to_plan_review formed downstream)
    - delegates→ plan-reviewer, coder.md, code-reviewer (Task)
  planner.md:
    - L→ planner-rules/{SKILL,mcp-tools}.md (eager); task-analysis/sequential-thinking/data-flow (on-demand, complexity-gated)
    - L→ code-shapes/<LANG>.md (cascade, one file)
    - H→ plan-reviewer (planner_to_plan_review)
  plan-reviewer (agent):
    - L→ plan-review-rules/SKILL.md (eager via frontmatter skills:)
    - K← SubagentStart: track-task-lifecycle.sh, inject-review-context.sh, caveman-suspend-for-reviewer.sh
    - I← inject-review-context.sh additionalContext (PK slots, delta IMP-04, metrics IMP-04)
    - K← SubagentStop: save-review-checkpoint.sh (verdict + canonical-ID), sync-agent-memory.sh
    - H→ coder.md (plan_review_to_coder)
  coder.md:
    - L→ coder-rules/{SKILL,mcp-tools,spec-check}.md (eager); review-response.md (conditional, re-entry)
    - L→ tdd-rules/SKILL.md (eager unconditional) + tdd-shapes/<LANG>.md (cascade)
    - H→ code-reviewer (coder_to_code_review); H← code_review_to_completion (re-entry)
  code-reviewer (agent):
    - L→ code-review-rules/SKILL.md (eager via frontmatter); isolation: worktree
    - K← SubagentStart: inject-review-context.sh (+PK +delta +verify_status), caveman-suspend, track-lifecycle
    - I← inject-review-context.sh additionalContext
    - K← SubagentStop: save-review-checkpoint.sh, sync-agent-memory.sh
    - H→ completion (code_review_to_completion)
  context_injection_paths:    # the per-turn / per-event token surface
    - enrich-context.sh: UserPromptSubmit → additionalContext (HASH-GUARDED)
    - inject-review-context.sh: SubagentStart(reviewer) → additionalContext (NO hash-guard; PK block re-fires every iteration)
    - save-progress-before-compact.sh: PreCompact → additionalContext (full state; cooldown-gated decision:block)
    - verify-state-after-compact.sh: PostCompact → additionalContext (scalar summary only)
  validation_paths:
    - validate-handoff.sh: PostToolUse(*-handoff.json) + subprocess from save-review-checkpoint.sh
    - save-review-checkpoint.sh: SubagentStop → review-completions.jsonl (canonical-ID normalization)
```

---

## Phase 4 — Findings (evidence-gated)

### Confirmed (29) — top group used for backlog. Each carries file:line + reproduced evidence.
See Phase 5 table. All confirmed findings are CONTEXT-COST only; none alters a contract shape.

### Refuted (8) — adversarial verifiers killed these. Recording to prevent re-proposal.

```yaml
refuted:
  - id: R1
    claim: "PreCompact + PostCompact double-render same 3 checkpoint sections"
    why: "FALSE premise — PostCompact emits only scalar summaries (verify-state-after-compact.sh L83-123); only PreCompact emits full bodies. Proposed fix already in place (checkpoint_ref pointer, KD-7). Saving illusory."
  - id: R2
    claim: "Reviewer 'Complexity-conditional' block re-inlines agent-memory-protocol.md"
    why: "Protocol contains NONE of the S/M/L-XL logic (grep empty). Deleting inline block would DROP complexity gating, not be neutral. Duplication-across-reviewers is real but the remedy is mis-described."
  - id: R3
    claim: "Delta-focus preamble + 10-line EXAMPLE comment removable from code-reviewer"
    why: "EXAMPLE block is LOCKED by test CG2.3 (test-c-stage-genericity-audit.sh L69-75) — mandates >=2 multi-language EXAMPLE comments. Removal fails the suite. contract_safe=false."
  - id: R4
    claim: "Apply enrich-style hash-guard to the 3 compaction injectors"
    why: "PreCompact emits state BECAUSE compaction wipes in-context copy. A 'skip if unchanged' guard would drop state across the boundary → breaks recovery. contract_safe=false."
  - id: R5
    claim: "Collapse code-reviewer Decision-Matrix/Severity to a pointer (~400 tok)"
    why: "code-review-rules/SKILL.md has NO NEEDS_CHANGES / REJECTED enum. Collapsing would DELETE enum values → violates caveman boundary #1. Safe subset only ~160 tok; saving 2-3x overstated."
  - id: R6
    claim: "Delete plan-reviewer Pipeline-Metrics section (agent can't write JSONL)"
    why: "Justification factually wrong; section documents the agent's emission obligation, not the orchestrator write. Unsafe."
  - id: R7
    claim: "handoff-protocol.md re-ships ~113 byte-identical contract lines"
    why: "handoff-protocol.md is ON-DEMAND (not eager) — no co-residency cost in the common path; saving not realizable as framed."
  - id: R8
    claim: "workflow.md rule eager-loads 47 lines hook-author docs (one finder's framing)"
    why: "Refuted AS FRAMED (partial path-scope impossible). Correct reframing survives as backlog #2 (split the file)."
```

---

## Phase 5 — Ranked Backlog (5-axis impact metric)

```yaml
metric: "rank = SUM(contract_safety, reliability, token_cost, blast_radius, effort_inverse); each axis 1-5"
```

| # | Total | Improvement | file:line | CS | REL | TOK | BLAST | EFF | unverified |
|---|-------|-------------|-----------|----|----|----|-------|----|------------|
| 1 | **21** | Gate/hash-guard the PROJECT-KNOWLEDGE.md injection so it is not re-injected verbatim on every reviewer SubagentStart | inject-review-context.sh#L584-L596 | 5 | 5 | 5 | 3 | 3 | no |
| 2 | **20** | Split rules/workflow.md so the hook-author maintenance sections stop eager-loading into EVERY session | rules/workflow.md#L32-L78 | 5 | 2 | 4 | 5 | 4 | no |
| 3 | 19 | Collapse the workflow.md `## HOOKS` section (63L) to a pointer — it re-documents settings.json (its own declared authority) | commands/workflow.md#L373-L436 | 5 | 2 | 4 | 4 | 4 | no |
| 4 | 19 | Inject only the ~12 resolved PK slot lines (not the 4096-char raw prefix) + fix the stale 8KB-cap comment | inject-review-context.sh#L588-L595 | 5 | 4 | 4 | 3 | 3 | **yes** |
| 5 | 19 | Externalize the CLAUDE.md `## Platform Guarantees` table (9 rows) to an on-demand doc behind a pointer | CLAUDE.md#L54-L70 | 5 | 2 | 3 | 5 | 4 | no |
| 6 | 19 | Refresh both stale MEMORY.md files (effort:max→xhigh, v1.12.1→v1.27.0, phantom db-explorer, wrong counts) | auto-memory + agent-memory/code-researcher/MEMORY.md | 5 | 3 | 2 | 4 | 5 | no |
| 7 | 17 | Defer coder-rules/spec-check.md (76L) from /coder STARTUP to a just-in-time Phase-3.5 load | commands/coder.md#L216-L219 | 5 | 3 | 3 | 2 | 4 | no |
| 8 | 17 | Replace the inline Phase-5 cleanup roster in orchestration-core.md (eager) with the pointer it already half-uses | workflow-protocols/orchestration-core.md#L83-L87 | 5 | 2 | 2 | 3 | 5 | no |
| 9 | 16 | Defer planner.md phase_0_8 IMP-04 digest body (55L) to the already-iter2-gated diff-manifest.md | commands/planner.md#L209-L263 | 5 | 3 | 3 | 2 | 3 | no |
| 10 | 16 | Dedup reviewer-agent prose (Severity/Canonical-IDs/VERDICT rules) + delete dead change-log comments | code-reviewer.md + plan-reviewer.md | 4 | 2 | 4 | 3 | 3 | no |
| 11 | 16 | Collapse the verdict_alias_normalized telemetry JSON triplicated across 3 protocol files to one + pointers | orchestration-core.md#L119-L129 | 5 | 2 | 2 | 3 | 4 | no |
| 12 | 16 | Replace dual-language (Go+Python) inline EXAMPLE blocks with a single language-resolved pointer | plan-template.md + required-sections.md | 5 | 2 | 3 | 3 | 3 | no |

### Acceptance criteria (apply to EVERY item)

```yaml
universal_ac:
  - "4 handoff payloads + VERDICT enum + fenced VERDICT_JSON block unchanged in shape"
  - "Canonical issue ID sha256(category|location|problem)[:8] byte-stable (issue.problem/suggestion text untouched)"
  - "All 86 .claude/scripts/tests/*.sh pass BEFORE and AFTER (propagate exit codes, no `|| break` swallow)"
  - "Each change ships exactly one NEW test that passes"
  - "No new env vars; caveman boundaries verbatim"
per_item_ac: "see workflow output — each item carries 5 specific criteria incl. a named test file"
```

### Recommended TOP-5 (max context impact, balanced across phases)

```yaml
recommendation:
  rationale: "Cover every hot context surface once: per-session, per-workflow, reviewer-injection, coder-startup."
  top_5:
    - "#1 — reviewer PK re-injection guard (biggest per-review-iteration waste; up to 6x re-inject on L/XL)"
    - "#2 — rules/workflow.md split (highest blast radius: EVERY session, all complexities)"
    - "#5 — CLAUDE.md Platform Guarantees externalize (every session; clean, low-risk)"
    - "#3 — workflow.md ## HOOKS collapse (~900 tok every /workflow run; self-declared non-authoritative)"
    - "#7 — coder spec-check deferral (mirrors an existing condition-gate one line above; coder-only, low-risk)"
  bundling_note: "#1 and #4 touch the SAME file (inject-review-context.sh PK block) and are complementary — implementable as ONE improvement (gate WHEN + slim WHAT). If chosen together they count as one /workflow cycle."
  alt_swaps:
    - "Swap #7→#6 if you want the stale-memory correctness fix (lowest token saving but removes an actively-contradictory effort:max fact + phantom dir fed to the explorer agent)."
    - "Swap #3→#9 to shift the win from orchestrator-startup to planner-startup (~1000 tok/iter-1 planner run)."
```
