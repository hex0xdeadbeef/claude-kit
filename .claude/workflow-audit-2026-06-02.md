# Workflow Pipeline Speed Audit — 2026-06-02

```yaml
meta:
  scope: "/workflow pipeline hot path only (planner → plan-reviewer → coder → code-reviewer + designer + load-bearing hooks/scripts/skills)"
  excluded: [meta-agent CRUD, project-researcher, db-explorer, observability-only scripts (latency-noted), security hooks (change-frozen)]
  claude_code_version: 2.1.160
  method: "direct empirical recon (orchestrator) + 7-group coverage deep-read (80 artifacts) + adversarial verification of every candidate"
  approved_axes: [parallelize-fanout, hook-turn-latency, token-context-cost]   # GATE 1; phase-restructuring OFF the table
  workflow_run: "22 agents, 1.16M tokens, 301 tool-uses, 6.3 min"
  verification: "14 verified / 1 rejected / 0 needs-more (raw 15 candidates, deduped to 10 unique)"
  hard_constraints_honored:
    - "no handoff JSON shape / VERDICT / VERDICT_JSON / discriminator change"
    - "canonical issue ID sha256(category|location|problem)[:8] byte-stable"
    - "caveman boundaries verbatim"
    - "no new env vars"
    - "security hooks (block-dangerous-commands, protect-files) untouched"
```

## Phase 1 — Inventory & Selection

```yaml
selected_in_scope:
  commands: [workflow.md, planner.md, coder.md, designer.md]
  agents: [plan-reviewer.md, code-reviewer.md, code-researcher.md, verdict-recovery.md]
  skills: [workflow-protocols (17 files), planner-rules, coder-rules, plan-review-rules, code-review-rules, design-rules, tdd-rules, caveman]
  scripts_contract: [validate-handoff, save-review-checkpoint, save-progress-before-compact, verify-state-after-compact, sync-agent-memory, inject-review-context, enrich-context]
  scripts_latency: [caveman-activate, caveman-suspend-for-reviewer, track-task-lifecycle, check-uncommitted, auto-fmt, pre-commit-build, mcp-preload-warn]
  wiring: [settings.json, rules/workflow.md, templates/(plan,spec,agent)]

excluded_with_reason:
  meta_agent_proj_db: "user-specified; not on /workflow runtime path"
  observability_scripts: "non-blocking telemetry; measured for latency only, not contract"
  security_scripts: "hot path but CHANGE-FROZEN (defence-in-depth)"
  boundary_case: "verify-phase-completion / check-references / check-plan-drift / yaml-lint / check-artifact-size live under meta-agent/scripts but wire into global Stop + PostToolUse(.claude/**) — latency-noted, CRUD logic out of scope"

discrepancies_found:   # stale self-knowledge = findings per audit spec
  D-1: ".claude/WORKFLOW-ANALYSIS.md referenced in auto-memory MEMORY.md — file does not exist (ls → No such file)"
  D-2: "auto-memory workflow-architecture.md lists sonnet models for planner/coder/reviewers — stale; all-opus since v1.9.0 (rules/workflow.md)"
  D-3: "code-researcher agent-memory says '24 hook scripts' — actual 28 (.claude/scripts/*.sh)"
```

## Phase 2 — Deep-Read Coverage (80 artifacts, 7 groups)

```yaml
groups: { orchestrator: 5, planner: 10, coder: 13, designer: 6, reviewers: 14, workflow-protocols: 17, hot-path-scripts: 15 }

key_contracts_confirmed:
  handoff: "4 typed payloads (planner_to_plan_review, plan_review_to_coder, coder_to_code_review, code_review_verdict); validated by validate-handoff.sh on PostToolUse(*-handoff.json)"
  verdict: "VERDICT: enum + VERDICT_JSON envelope; canonical issue id sha256(category|location|problem)[:8]; gated by save-review-checkpoint.sh on SubagentStop"
  loading: "workflow-protocols on-demand (SKILL.md:27-28); upfront ≈19.6KB (SKILL+autonomy+orchestration-core); rest event-triggered"
  isolation: "code-reviewer = worktree(baseRef:fresh); its SubagentStart hook does NOT fire → context via --sidecar-only file, not hook stdout"

already_optimized_no_finding:   # false positives avoided via empirical check
  enrich_context: "hash-guard skips re-injection on unchanged checkpoint (.enrich-last-hash) + 6KB cap"
  inject_review_context: "drops embedded issue text (keeps referenceable IDs), PK slot-extraction not blind-prefix, delta-review mode, 6KB cap"
  workflow_protocols: "event-driven on-demand loading already in place"
  check_references_8_entries: "hooks run in PARALLEL + identical handlers dedupe (docs); per-path if: gating → ≤1 fires; if: cannot OR / cannot be bare path-glob → 8-entry form is the only expressible shape. NOT a latency cost."
  hook_latency: "warm 24-79ms/script, parallel, dwarfed by LLM inference"
```

## Phase 3 — Interaction Graph (directed; edges: ⟶H handoff · ⟶L load-dep · ⟶K hook-call)

```text
SPINE (⟶H, sequential — un-parallelizable backbone):
  [/designer]──spec.md+design_critique──▶[/planner]──planner_to_plan_review──▶[plan-reviewer]
     (L/XL)                                                                          │
  [code-reviewer]◀──coder_to_code_review──[/coder]◀────plan_review_to_coder──────────┘
        └──code_review_verdict──▶[/workflow]──▶ commit

DELEGATION (⟶L — the parallelizable surface):
  [/planner]╌╌Agent/Task╌╌▶[code-researcher]   single bg, bundled focus (parallel-dispatch UC1 unwired)
  [/coder]  ╌╌Task        ╌▶[code-researcher]   blocking
  [/coder]  ╌╌Task        ╌▶[test-runner]       ❌ DANGLING (agent absent)
  [plan-reviewer]╌╌Task   ╌▶[arch-checker]      ❌ DANGLING (agent absent; reviewer has no Task tool anyway)

HOOK-CALLS (⟶K, settings.json — parallel + deduped per event):
  UserPromptSubmit→enrich-context | SubagentStart[reviewers]→{track-task-lifecycle, inject-review-context, caveman-suspend}
  SubagentStop[reviewers]→save-review-checkpoint(BLOCKING) | PostToolUse[*-handoff.json]→validate-handoff
  PreCompact→save-progress | PostCompact→verify-state | Stop→{verify-phase-completion, check-uncommitted(BLOCKING), notify-complete}
  SessionStart→{caveman-activate, mcp-preload-warn} | PreToolUse[git commit]→pre-commit-build | PostToolUse[Write|Edit]→auto-fmt
```

## Phase 4 — Verified Findings (10 unique; all empirically reproduced)

```yaml
F1:
  axis: parallelize
  id_cluster: [C1, C5, C10]
  file_line: ".claude/commands/planner.md:345-366 (primary); parallel-dispatch.md:33; workflow.md:343 (secondary)"
  whats_wrong: "planner launches ONE background code-researcher with bundled focus areas. parallel-dispatch.md Use Case 1 (labelled 'EXISTING') documents N-way per-layer concurrent dispatch but no command references it (grep -rn parallel-dispatch .claude/commands → empty)."
  how_to_prove: "grep -rn parallel-dispatch .claude/commands/ .claude/skills/planner-rules/ → empty; grep -n EXISTING parallel-dispatch.md → :33; planner.md:356-365 = single bundled Agent."
  consequence: "L/XL multi-package research runs one bundled researcher instead of N concurrent; the 'EXISTING' label is self-contradicting (maintainer-misleading)."
  verdict: "VERIFIED. impact downgraded HIGH→MEDIUM: only L/XL with 3+ independent layers; ~1.5-2.5x on research sub-step (not clean Nx, shared warmup); partially hidden behind DESIGN; costs N× research tokens."
  contract_safe: true

F2:
  axis: reliability
  id_cluster: [C2]
  file_line: ".claude/commands/workflow.md:55-56"
  whats_wrong: "--from-phase format declared '0.7|1-4' but Phase 5 (Completion) is a real resumable phase. Contradicts checkpoint-protocol.md:15 (0.5|0.7|1|2|3|4|5), orchestration-core.md:82/186 (phase_completed:5, resume Phase 5), and state_render.py:367-371 which auto-emits `/workflow --from-phase {phase_completed}` → can literally print --from-phase 5 (outside its own range)."
  how_to_prove: "grep -n 'format: \"0.7|1-4\"' workflow.md:55; grep -n 'resume from Phase 5' orchestration-core.md:186; grep -n 'phase_completed: 5' orchestration-core.md:82; sed -n '367,371p' lib/state_render.py."
  consequence: "Post-APPROVED-pre-commit recovery (exactly the uncommitted-work case the Stop hook guards) has a self-emitted hint that violates the command's own documented arg domain → confusing/foot-gun recovery."
  verdict: "VERIFIED high-confidence; severity MODERATE (LLM-interpreted arg, not a hard parser error). 4-file self-contradiction + invalid self-emitted hint."
  contract_safe: true

F3:
  axis: reliability
  id_cluster: [C3]
  file_line: ".claude/commands/planner.md:371-372 (+ .claude/skills/coder-rules/mcp-tools.md:20,25)"
  whats_wrong: "context7 called via plugin-namespaced ids mcp__plugin_context7_context7__{resolve-library-id,query-docs}. .mcp.json registers project-scoped server 'context7' with no .claude-plugin/ manifest → real ids are mcp__context7__*. Sibling sequential-thinking uses the correct project form."
  how_to_prove: "python3 -c \"import json;print(list(json.load(open('.mcp.json'))['mcpServers']))\" → context7; ls .claude-plugin → absent; grep -n mcp__plugin_context7 planner.md → :371,:372."
  consequence: "tool-not-found → wasted turn or silent degrade to WebSearch (loses curated-docs path) on L/XL library-research plans."
  verdict: "VERIFIED high-confidence; severity LOW-MODERATE (bounded to lib-research step; Claude often self-corrects from registered tool list)."
  contract_safe: true

F4:
  axis: reliability   # de-facto a SPEED finding: causes a spurious extra review iteration
  id_cluster: [C4]
  file_line: ".claude/commands/planner.md:476,478 vs sequential-thinking-guide.md:11,17 (+ 4 more files below)"
  whats_wrong: "ST trigger thresholds diverge. Planner-author camp (planner.md:476/478, planner-rules/SKILL.md:78, planner-rules/troubleshooting.md:6) = layers≥4 / Parts≥5. Reviewer-grader camp (sequential-thinking-guide.md:11/17, plan-review-rules/SKILL.md:77, plan-reviewer.md:84/341) = layers≥3 / Parts≥4 and ENFORCES missing-ST as MAJOR. A 4-part/3-layer L plan: planner skips ST (its body says not required), reviewer flags MAJOR."
  how_to_prove: "grep -n 'Parts in plan\\|Architecture layers' planner.md sequential-thinking-guide.md; grep -n '4+ Parts, 3+ layers' plan-reviewer.md plan-review-rules/SKILL.md."
  consequence: "Deterministic divergence on borderline 4-part/3-layer L plans → forced NEEDS_CHANGES iteration = a full extra planner→reviewer round-trip (wall-clock + tokens). This is a parallelize/latency win wearing a reliability label."
  verdict: "VERIFIED high-confidence; severity MODERATE. Fix MUST align ALL 6 files (else divergence persists). Canonicalize to STRICTER (Parts≥4/layers≥3 = enforcement path + safer default)."
  contract_safe: true

F5:
  axis: reliability
  id_cluster: [C6, C12]
  file_line: ".claude/commands/coder.md:514-522 (subagent_type :519, model:'sonnet' :520)"
  whats_wrong: "VERIFY full_testing delegates Task(subagent_type:'test-runner', model:'sonnet', run_in_background:true). No .claude/agents/test-runner* exists; sonnet stale (all pipeline agents opus since v1.9.0). Correct mechanism already documented one file over: coder-rules/mcp-tools.md:37-53 Pattern A (Bash run_in_background, harness auto-notify)."
  how_to_prove: "find .claude/agents -iname '*test-runner*' → 0; sed -n '514,522p' coder.md; sed -n '37,53p' coder-rules/mcp-tools.md."
  consequence: "On 'Multi-session task, many tests' branch, Task dispatch dead-ends on unknown subagent → wasted turn + VERIFY stall; dead model:sonnet line."
  verdict: "VERIFIED high-confidence; severity MODERATE (gated EXAMPLE branch, LLM recovers to direct Bash)."
  contract_safe: true

F6:
  axis: parallelize
  id_cluster: [C7]
  file_line: ".claude/commands/designer.md:101-111"
  whats_wrong: "Phase 1 EXPLORE is serial read-only Grep/Glob (budget reads:10). designer runs in orchestrator context (can dispatch Agent/Task like planner) but never launches a researcher. Phase 2 CLARIFY (114-122) is human-gated — the human-wait is free overlap time."
  how_to_prove: "grep -n 'code-researcher\\|run_in_background\\|Agent(' designer.md → empty; designer.md:119 'ONE AT A TIME', :122 'Do NOT proceed without user answers'."
  consequence: "Codebase-context gathering that could run during human-clarify wait happens serially up front, lengthening time-to-spec for L/XL."
  verdict: "VERIFIED med-confidence; severity LOW. Conditional (skip_when CLARIFY unambiguous → no overlap window); small EXPLORE budget. Mirror planner's SINGLE-researcher pattern, not unbuilt N-way."
  contract_safe: true

F7:
  axis: reliability
  id_cluster: [C8]
  file_line: ".claude/skills/plan-review-rules/architecture-checks.md:107-131 (arch-checker @117); troubleshooting.md:10"
  whats_wrong: "automated_checks block dispatches Task(subagent_type:'arch-checker', model:'haiku'). No such agent; AND plan-reviewer.md:6-11 grants only Read/Grep/Glob/TodoWrite/Write with disallowedTools:[Bash] — it has NO Task/Agent tool, so it cannot launch any subagent. Path is doubly dead. Operative manual grep path already exists inline at SKILL.md:69/83."
  how_to_prove: "grep -rl 'name: arch-checker' .claude → empty; sed -n '6,15p' plan-reviewer.md (no Task/Agent); grep -rn arch-checker .claude/skills → only the 2 dead refs."
  consequence: "On 4+ Part L/XL plans a reviewer following the block attempts an unlaunchable dispatch → wasted turns vs maxTurns:50."
  verdict: "VERIFIED high-confidence; severity LOW-MEDIUM (on-demand loaded; only complex plans; arch-validation-as-whole still works via SKILL.md:69)."
  contract_safe: true

F8:
  axis: reliability   # nit
  id_cluster: [C9]
  file_line: ".claude/agents/verdict-recovery.md:41"
  whats_wrong: "verdict-recovery (isolation:worktree, baseRef:fresh) step 2 reads .claude/workflow-state/review-completions.jsonl 'if it exists'. That file is gitignored + untracked + NOT in .worktreeinclude (only code-reviewer-INJECTED-CONTEXT.md is) → always misses in fresh worktree. No inject-review-context hook wired for verdict-recovery (settings.json:371-378 = caveman-suspend only)."
  how_to_prove: "git check-ignore review-completions.jsonl → IGNORED; grep -c review-completions .worktreeinclude → 0; grep -n baseRef settings.json → fresh."
  consequence: "Dead recovery read; one wasted turn vs maxTurns:10 + misleading instruction. (Tolerable: orchestrator already filters main-repo-side before launch; diff-only verdict is by design.)"
  verdict: "VERIFIED med-confidence; severity LOW (maintainability nit, graceful degrade)."
  contract_safe: true

F9:
  axis: token
  id_cluster: [C11]
  file_line: ".claude/skills/workflow-protocols/SKILL.md:30-31 (mirrored :37-38, :84-85)"
  whats_wrong: "SKILL prose says 'Forming handoff (common path) → read handoff-contracts.md (6.3KB) ... also read handoff-protocol.md (22KB)'. But the actual handoff WRITE on Phase-2/4 happens inside delegation-templates.md (24.7KB, mandatory-loaded at workflow.md:301) which already inlines the full JSON shapes + IMP-03/04 logic. Triple-carry of the same contract shapes."
  how_to_prove: "wc -c handoff-contracts.md handoff-protocol.md delegation-templates.md = 6290/22229/24772; diff contract bodies handoff-contracts:41-102 vs handoff-protocol:28-103 vs delegation-templates:80-95 (same shapes); grep -rn 'Read.*handoff-contracts' .claude/commands → empty (advisory prose, not hard Read)."
  consequence: "On the common delegation path an orchestrator following SKILL prose can pull ~28KB (~7K tokens) duplicate contract text on top of mandatory delegation-templates.md, re-incurred each loop iteration → token waste + prompt-cache churn."
  verdict: "VERIFIED med-confidence; severity LOW-MEDIUM. PROBABILISTIC (advisory prose for LLM, not hard directive); absolute waste small vs 1M ctx; real concern = per-iteration cache churn."
  contract_safe: true

F10:
  axis: latency
  id_cluster: [C13, C14]
  file_line: ".claude/settings.json (track-task-lifecycle @310,327,351; mcp-preload-warn @500)"
  whats_wrong: "track-task-lifecycle.sh (writes only *.jsonl, zero stdout) and mcp-preload-warn.sh (stderr WARN only, default-off early-exit @16) are wired as SYNCHRONOUS hooks but are pure side-effect — stdout/exit ignored → valid `async: true` candidates (Claude Code docs + CHANGELOG)."
  how_to_prove: "grep -n 'print(' track-task-lifecycle.sh → 0 stdout; grep -nE 'log_stderr|printf|echo|print' mcp-preload-warn.sh → only stderr; grep -n async settings.json → none."
  consequence: "SubagentStart/SessionStart wait for these logging hooks. Impact NEGLIGIBLE: hooks already parallel (GT4), ~24ms/14ms dwarfed by inference (GT7)."
  verdict: "VERIFIED med-confidence; severity LOW/negligible (honest). Correctness/cleanliness signal > speed. Do NOT async sibling caveman-activate.sh (emits consumed additionalContext). NOTE: settings.json agent-edit is BLOCKED by protect-files.sh:86 → must be a user edit."
  contract_safe: true

rejected:
  R1:
    axis: reliability
    file_line: ".claude/commands/designer.md:146"
    whats_wrong: "spec-quality.md / design-checklist.md lack an explicit designer.md load directive (only SKILL.md prose routes them)."
    reason_rejected: "Evidence reproduces but impact overstated. Gate is advisory; load already routed via unconditionally-loaded SKILL.md:18-21; key anti-theater rule duplicated in command-loaded critique-lenses.md. Cosmetic symmetry nit, not reliability. Fix would be contract-safe but unwarranted at claimed severity."
```

## Phase 5 — Ranked Backlog (5-axis impact metric)

```yaml
metric: "each axis 1-5; Effort is INVERSE (lower effort → higher score); rank = sum (max 25). All items VERIFIED (no [UNVERIFIED] in backlog)."
axes: [contract_safety, reliability, token_cost, blast_radius, effort_inverse]

ranking:
  - id: F4
    title: "Align Sequential-Thinking trigger thresholds across planner-author + reviewer-grader (6 files)"
    scores: { contract_safety: 4, reliability: 4, token_cost: 4, blast_radius: 4, effort_inverse: 2 }
    sum: 18
    why: "Eliminates a deterministic spurious-NEEDS_CHANGES iteration = a full extra planner→reviewer round-trip. Best real SPEED win despite reliability label."
    acceptance:
      - "All 6 files (planner.md:476/478, sequential-thinking-guide.md:11/17, planner-rules/SKILL.md:78, planner-rules/troubleshooting.md:6, plan-review-rules/SKILL.md:77, plan-reviewer.md:84/341) state ONE threshold pair."
      - "Recommended canonical: Parts≥4 / layers≥3 (matches enforcement path)."
      - "grep proves no remaining ≥5/≥4 vs ≥4/≥3 split. All tests in .claude/scripts/tests green before+after."

  - id: F2
    title: "Extend --from-phase range 0.7|1-4 → 0.7|1-5 (+ '5=Completion')"
    scores: { contract_safety: 4, reliability: 4, token_cost: 2, blast_radius: 3, effort_inverse: 5 }
    sum: 18
    why: "Removes 4-file self-contradiction + state_render.py self-emitting an out-of-range arg in the post-APPROVED recovery path."
    acceptance:
      - "workflow.md:55-56 format='0.7|1-5' + description maps 5=Completion (commit + metrics)."
      - "Consistent with checkpoint-protocol.md:15 + orchestration-core.md:82/186. No script range-check regressions; tests green."

  - id: F3
    title: "Fix context7 MCP tool-ids → mcp__context7__* (planner.md + coder-rules/mcp-tools.md)"
    scores: { contract_safety: 2, reliability: 3, token_cost: 2, blast_radius: 2, effort_inverse: 5 }
    sum: 14
    acceptance:
      - "planner.md:371-372 and coder-rules/mcp-tools.md:20,25 use mcp__context7__resolve-library-id / mcp__context7__query-docs."
      - "grep -rn mcp__plugin_context7 .claude → empty. Matches .mcp.json server name + sequential-thinking convention."

  - id: F5
    title: "Replace coder test-runner dangling Task with Bash(run_in_background) Pattern A; drop model:sonnet"
    scores: { contract_safety: 2, reliability: 3, token_cost: 2, blast_radius: 2, effort_inverse: 4 }
    sum: 13
    acceptance:
      - "coder.md:514-522 uses {TEST_CMD} via Bash(run_in_background:true) per mcp-tools.md Pattern A; no subagent_type/model lines."
      - "grep -n test-runner coder.md → empty. Tests green."

  - id: F7
    title: "Replace plan-review arch-checker dangling dispatch with inline Grep guidance (+ troubleshooting.md:10)"
    scores: { contract_safety: 2, reliability: 3, token_cost: 2, blast_radius: 2, effort_inverse: 4 }
    sum: 13
    acceptance:
      - "architecture-checks.md:107-131 replaced with Grep/Glob-based manual import-vs-LAYER_RULE check (tools the reviewer actually has)."
      - "troubleshooting.md:10 repointed. grep -rn arch-checker .claude → empty. Tests green."

  - id: F9
    title: "Scope SKILL.md handoff-read trigger to exclude Phase-2/4 delegation path (de-dup triple-carry)"
    scores: { contract_safety: 2, reliability: 1, token_cost: 4, blast_radius: 3, effort_inverse: 3 }
    sum: 13
    acceptance:
      - "SKILL.md:30-31/37-38/84-85 reword: handoff-contracts.md only OUTSIDE delegation; on Phase-2/4 the shapes are already inlined in delegation-templates.md; handoff-protocol.md = deep-ref for net-new IMP authoring only."
      - "No change to the 4 handoff contract shapes themselves. Tests green; handoff validation unaffected."

  - id: F1
    title: "Wire N-way parallel code-researcher fan-out in planner (relabel parallel-dispatch UC1 + reference from planner.md)"
    scores: { contract_safety: 2, reliability: 2, token_cost: 2, blast_radius: 2, effort_inverse: 3 }
    sum: 11
    why: "Primary PARALLELIZE-axis ask. Honest: bounded subset of L/XL, ~1.5-2.5x research sub-step, costs N× tokens. Relabel resolves stale 'EXISTING' claim."
    acceptance:
      - "(a) parallel-dispatch.md:33 label corrected to reflect wiring status."
      - "(b) planner.md:345 background_mode references parallel-dispatch UC1 for L/XL with 3+ independent layers; single-researcher kept as fallback; integrate at async_integration_point."
      - "No handoff/verdict surface (code-researcher is read-only). Tests green."

  - id: F8
    title: "Remove verdict-recovery dead review-completions.jsonl read (state context arrives via orchestrator)"
    scores: { contract_safety: 2, reliability: 2, token_cost: 1, blast_radius: 1, effort_inverse: 5 }
    sum: 11
    acceptance:
      - "verdict-recovery.md:41 read removed; prose states prior context is provided by orchestrator launch prompt (filtered main-repo-side)."
      - "RULE_1 diff-only verdict preserved. Tests green."

  - id: F10
    title: "Mark track-task-lifecycle + mcp-preload-warn hooks async:true (user-applied — settings.json is protect-files-frozen)"
    scores: { contract_safety: 3, reliability: 2, token_cost: 1, blast_radius: 2, effort_inverse: 5 }
    sum: 13
    why: "Negligible wall-clock (honest). Cleanliness signal. Requires USER edit (protect-files.sh:86 blocks agent settings.json edits) OR working-tree protection already disabled."
    acceptance:
      - "async:true on the 2 pure-side-effect hook objects only; caveman-activate untouched. settings.json still valid JSON; tests green."

  - id: F6
    title: "Optional designer background researcher during human-gated CLARIFY"
    scores: { contract_safety: 2, reliability: 1, token_cost: 1, blast_radius: 1, effort_inverse: 4 }
    sum: 9
    acceptance:
      - "designer.md Phase 1 optional note: L/XL MAY launch ONE bg code-researcher, gated on CLARIFY running, integrate before PROPOSE."
      - "Mirrors planner single-researcher pattern. Tests green."

summary_by_axis:
  parallelize_fanout: [F1, F6]   # user's headline ask; honestly modest composite scores
  hook_turn_latency: [F10]       # negligible wall-clock — cleanliness only
  token_context_cost: [F9]
  reliability_bonus: [F4, F2, F3, F5, F7, F8]   # F4 + F2 are the highest-value; F4 is a de-facto speed win

docs_citations:
  - "Hooks run in parallel + identical handlers dedupe; if: no-OR / needs-tool-prefix — code.claude.com/docs/en/hooks"
  - "async:true / asyncRewake:true on command hooks — code.claude.com/docs/en/hooks + CHANGELOG (mature feature)"
  - "Subagent parallelism via single-message multi-Task; background agents separate — code.claude.com/docs/en/sub-agents"
  - "2.1.160 CHANGELOG: dynamic-workflow trigger keyword renamed workflow→ultracode"
```
