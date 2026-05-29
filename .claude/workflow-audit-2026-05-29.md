---
status: research
type: analysis
complexity: XL
author: workflow orchestrator (audit + Workflow-tool deep-read run wu2c50ri9)
date: 2026-05-29
scope: CHANGELOG.md versions 2.1.153 → 2.1.156 (new surface above prior ceiling 2.1.152)
prior_artifacts:
  - ".claude/prompts/changelog-2189-2118-workflow-analysis.md (2.1.89→2.1.118)"
  - ".claude/prompts/changelog-2121-2152-workflow-analysis.md (2.1.121→2.1.152, I-01..I-10)"
  - ".claude/workflow-audit-2026-05-27.md (worktree-create-contract audit)"
artifact_under_study: "claude-kit /workflow pipeline (HEAD d252993 — 8 cmds/agents, 8 skill packages, 27 scripts, 80 tests)"
new_env_vars_introduced: 0
contract_changes: 0
deep_read_run: "Workflow tool run wu2c50ri9 — 8 agents, 7 artifact groups, 310 tool-uses"
---

# Workflow Pipeline Audit — Claude Code 2.1.153 → 2.1.156 (Opus 4.8 wave)

## 0. Executive Summary

- **Real CHANGELOG ceiling is `2.1.156`**, not 2.1.192. Earlier WebFetch calls fabricated
  2.1.157–2.1.192; the prior session summary also drifted. New surface above the last
  analysis (2.1.152) is exactly **`2.1.153`, `2.1.154` (Opus 4.8 GA), `2.1.156`** — a thin
  wave: Opus 4.8 + `/simplify` re-definition + dynamic-workflows + bug-fixes.
- **Prior backlog state:** I-01..I-04 from `changelog-2121-2152` are **implemented** (tests
  exist). I-05..I-10 were **proposed but never built** (no tests, no settings changes).
- **Two flagship findings carry the most impact and are both VERIFIED against authoritative
  docs + the local CHANGELOG:**
  1. `effort: max` is **invalid in agent/skill frontmatter** (valid set: `low|medium|high|xhigh`;
     `max` is session-only). 6 pipeline agents silently run at default `high`, not maximum
     reasoning, on Opus 4.8.
  2. Phase 2.5 SIMPLIFY docs describe `/simplify == /code-review --fix` (2.1.152), but
     **2.1.154 reverted `/simplify` to a cleanup-only review** (reuse/simplification/efficiency/
     altitude, no bug-hunting) — active doc-drift, mis-calibrated 30% guard note.
- **Contract safety:** every candidate in §5 leaves handoff JSON, VERDICT/VERDICT_JSON
  envelopes, and the `sha256(category|location|problem)[:8]` canonical-ID input byte-stable.
- **0 new env-vars** proposed (env-var restraint per feedback 2026-05-22).

---

## 1. Inventory & Scope (GATE 1)

Hot-path artifacts only. meta-agent / project-researcher / db-explorer excluded (off pipeline).

| Group | Artifacts | Why in scope |
|-------|-----------|--------------|
| G1 commands | workflow.md, planner.md, coder.md, designer.md | Orchestrator + phase commands (shared ctx) |
| G2 agents | plan-reviewer.md, code-reviewer.md, code-researcher.md, verdict-recovery.md | Clean-context review/research agents |
| G3 protocols | skills/workflow-protocols/* (17 files) | Handoff/verdict/checkpoint/issue-id/worktree contracts |
| G4 rule-skills | planner-/coder-/plan-review-/code-review-/design-/tdd-rules | Phase rule loading + cascade |
| G5 pipeline hooks | validate-handoff, save-review-checkpoint, save-progress-before-compact, enrich-context, check-uncommitted, inject-review-context, sync-agent-memory, notify-workflow-complete | handoff/verdict/checkpoint/worktree/memory wiring |
| G6 security/settings | settings.json, block-dangerous-commands, protect-files, caveman-*, mcp-preload-warn | Hook wiring completeness + perimeter |
| G7 templates+rule | templates/*, rules/workflow.md | Template↔contract alignment, model-routing doc |

---

## 2. Deep-read (roles / IO / contracts / hooks) — condensed

```yaml
workflow.md:   { role: orchestrator, out: "handoff→plan-reviewer/code-reviewer", hooks: "PreCompact,PostCompact,SubagentStart/Stop,Stop" }
planner.md:    { role: architect-researcher, out: ".claude/prompts/{feature}.md + planner_to_plan_review handoff", iter2: "Phase 0.8 diff-replan" }
coder.md:      { role: implementer, out: "code + coder_to_code_review handoff", subphases: "0.5 review-response, 2.5 SIMPLIFY, 3 VERIFY, 3.5 spec-check", tdd: RGR }
designer.md:   { role: solution-architect, out: ".claude/prompts/{feature}-spec.md (L/XL only)" }
plan-reviewer: { ctx: clean-agent, out: "VERDICT + VERDICT_JSON (plan_review_verdict)", model: opus, effort_frontmatter: max }
code-reviewer: { ctx: clean-agent, isolation: worktree, out: "VERDICT + VERDICT_JSON (code_review_verdict)", memory: project }
code-researcher:{ ctx: tool-agent, model: haiku, effort: medium, output: "summary ≤2000 tokens", writes: none }
verdict-recovery:{ ctx: fallback-agent, model: haiku, effort: low }
save-review-checkpoint.sh: { event: SubagentStop, blocking: "IMP-H verdict-protect (once)", emits: review-completions.jsonl, canonical-id: sha256[:8] }
validate-handoff.sh: { event: PostToolUse(*-handoff.json), strict-mode: CLAUDE_HANDOFF_VALIDATION_MODE }
save-progress-before-compact.sh: { event: PreCompact, blocking: ".iteration-in-flight → decision:block (cooldown)" }
```

---

## 3. Interaction graph (directed; edge types: handoff | hook-call | load-dep)

```
workflow.md ─handoff→ designer.md ─handoff→ planner.md ─handoff→ plan-reviewer
plan-reviewer ─VERDICT/handoff→ workflow.md ─(NEEDS_CHANGES)loop→ planner.md
workflow.md ─handoff→ coder.md ─handoff→ code-reviewer (isolation:worktree)
code-reviewer ─VERDICT/handoff→ workflow.md ─(CHANGES_REQUESTED)loop→ coder.md ─→ commit
planner.md ─Agent/Task→ code-researcher (summary)
[hook-call] SubagentStart{plan-reviewer,code-reviewer} → inject-review-context.sh, track-task-lifecycle.sh
[hook-call] SubagentStop{plan-reviewer|code-reviewer|verdict-recovery} → save-review-checkpoint.sh (BLOCKING)
[hook-call] PreCompact{auto,manual} → save-progress-before-compact.sh (BLOCKING on .iteration-in-flight)
[hook-call] PostToolUse(*-handoff.json) → validate-handoff.sh
[hook-call] Stop → verify-phase-completion.sh, check-uncommitted.sh (STOP_BLOCK_MAX=5<8), notify-workflow-complete.sh
[hook-call] SessionEnd → session-analytics.sh   ← only 1 hook wired
[load-dep] coder.md → tdd-rules + tdd-shapes/<LANG>.md (unconditional); workflow.md → workflow-protocols/SKILL.md
[load-dep] all pipeline agents → effort:max frontmatter (INVALID on Opus 4.8 — see F-B)
```

---

## 4. Problems found (file:line · what · proof · consequence · severity)

```yaml
F-B (effort routing):
  file_line: ".claude/agents/code-reviewer.md:5, plan-reviewer.md:5, .claude/commands/{planner,coder,designer,workflow}.md:5"
  what: "Frontmatter effort: max — 'max' is not a valid frontmatter/settings effort value (session-only)."
  proof: "code.claude.com/docs/en/settings + model-config: effort accepts low|medium|high|xhigh; max/ultracode session-only, NOT accepted in settings/frontmatter. CHANGELOG:9 (Opus 4.8 default high, xhigh top), :993 (xhigh added 2.1.111). rules/workflow.md:25 says 'effort: max is Opus 4.6 exclusive' (stale)."
  consequence: "All pipeline reviewers + coder + planner silently run at default high, not maximum (xhigh) reasoning on Opus 4.8 — degraded review/plan/code quality across every phase."
  severity: high
F-A (simplify semantics):
  file_line: ".claude/commands/coder.md:465,468,476; .claude/commands/workflow.md:248; .claude/skills/workflow-protocols/orchestration-core.md:32; CLAUDE.md SIMPLIFY note"
  what: "Docs assert /simplify == /code-review --fix (2.1.152 bug-hunting). 2.1.154 reverted /simplify to cleanup-only (reuse/simplification/efficiency/altitude)."
  proof: "CHANGELOG:14 (2.1.154 cleanup-only, NOT /code-review --fix bug-hunting); :95 (2.1.152 alias); :169 (2.1.147 removed). coder.md:476 30%-guard note claims it bounds 'correctness-fix-driven diff expansion' — no longer true."
  consequence: "Coder applies wrong mental model of Phase 2.5; guard rationale mis-calibrated. Cleanup-only actually re-matches kit's original NIT/MINOR intent."
  severity: medium
F1 (hook timeouts — workflow wu2c50ri9):
  file_line: ".claude/settings.json:82-514"
  what: "ZERO timeout on 13+ command hooks doing git/external-tool/heavy-I-O work (only 2 prompt hooks have timeout:30)."
  proof: "44 command hooks, 2 timeout fields. Unbounded: check-uncommitted.sh (git), save-review-checkpoint.sh (worktree git), validate-handoff.sh (check-jsonschema), save-progress/verify-compact, inject-review-context.sh."
  consequence: "A hung git/jsonschema process stalls the turn at PreCompact/SubagentStart/Stop. Platform block-cap (8) cannot distinguish slow from hung without per-hook timeout."
  severity: high
F2 (SessionEnd underuse):
  file_line: ".claude/settings.json:425-436"
  what: "SessionEnd wires only session-analytics.sh; no end-of-session GC/sync/archive."
  proof: "verdict-block sentinels TTL-evicted only inside save-review-checkpoint.sh:63-95 (reactive); agent-memory JSONL has no rotation."
  consequence: "Sentinel/JSONL/checkpoint accumulation; missed non-blocking post-final-prompt cleanup."
  severity: medium
F3 (systemMessage surfacing):
  file_line: ".claude/scripts/* (43 hooks emit WARN/SKIP to stderr only)"
  what: "Only caveman-activate.sh emits user-visible systemMessage; load-bearing WARNs buried in stderr."
  proof: "grep systemMessage in scripts → only caveman-activate.sh. validate-handoff.sh/check-plan-drift.sh degrade silently to stderr."
  consequence: "Critical WARN (handoff oversize, no VERIFY resolved, jq parse fail) invisible until transcript review."
  severity: medium
F-D (/workflow vs native /workflows):
  file_line: "CLAUDE.md, .claude/commands/workflow.md (no disambiguation)"
  what: "Native dynamic-workflows /workflows + Workflow tool (2.1.154) collide namewise with kit /workflow pipeline."
  proof: "CHANGELOG:10 (dynamic workflows, /workflows). Kit has zero disambiguation note (grep)."
  consequence: "User/agent confusion; risk of invoking Workflow tool when kit /workflow pipeline is meant."
  severity: low
F-E (platform-guarantee drift):
  file_line: "CLAUDE.md (no 'Platform Guarantees Relied Upon' section)"
  what: "Kit relies on new platform fixes not documented as dependencies."
  proof: "CHANGELOG:36 (worktree-isolation guard for bg subagents — code-reviewer relies on it), :32 (1M-context premature out-of-context notif fix — session is Opus 4.8 1M), :39 (baseRef head fix), :44 (managed-settings resilience)."
  consequence: "Future floor-lowering / dependency rollback could silently break worktree isolation or 1M-context behavior."
  severity: low
F-F (code-researcher write-capability):
  file_line: ".claude/agents/code-researcher.md:1-7 (frontmatter)"
  what: "Read-only researcher has no disallowed-tools; write-prohibition rests on prompt only."
  proof: "CHANGELOG:96 (2.1.152 disallowed-tools frontmatter), :1708 (disallowedTools agent frontmatter). output_contract: summary ≤2000 tokens (no file writes needed)."
  consequence: "No platform-level guarantee researcher cannot mutate files."
  severity: low
```

---

## 5. Ranked improvement backlog (GATE 2)

Impact metric (each axis 1–5; rank = sum). CS=contract-safety, REL=reliability,
TOK=token/cost (higher=cheaper), BR=blast-radius, EFF=effort-inverse (5=trivial).

| ID | Improvement | CHANGELOG | CS | REL | TOK | BR | EFF | rank | verified |
|----|-------------|-----------|----|----|----|----|----|------|----------|
| IMP-1 | `effort: max` → `xhigh` (6 pipeline frontmatter) + routing doc refresh | 2.1.154:9 | 5 | 5 | 2 | 5 | 4 | **21** | yes |
| IMP-2 | Re-align Phase 2.5 SIMPLIFY to 2.1.154 cleanup-only semantics | 2.1.154:14 | 5 | 4 | 3 | 2 | 4 | **18** | yes |
| IMP-6 | Per-hook `timeout` on critical command hooks (F1) | docs(hooks) | 5 | 4 | 3 | 3 | 3 | **18** | yes (not new-ver) |
| IMP-4 | "Platform Guarantees Relied Upon" section incl. new 2.1.153/154/156 fixes (F-E) | 2.1.154:32,36,39 | 5 | 3 | 3 | 2 | 4 | **17** | yes |
| IMP-7 | `/workflow` (kit) vs native `/workflows` disambiguation (F-D) | 2.1.154:10 | 5 | 2 | 3 | 2 | 5 | **17** | yes |
| IMP-5 | `disallowed-tools` defense-in-depth for code-researcher (F-F) | 2.1.152:96 | 5 | 2 | 3 | 1 | 4 | **15** | needs-frontmatter-confirm |
| IMP-8 | systemMessage surfacing for load-bearing hook WARNs (F3) | docs(hooks) | 5 | 3 | 2 | 2 | 3 | **15** | yes (not new-ver) |
| IMP-9 | SessionEnd GC hook (sentinels/memory/checkpoint) (F2) | docs(hooks) | 5 | 2 | 3 | 1 | 3 | **14** | yes (not new-ver) |

> Honesty notes: IMP-1 TOK=2 because xhigh costs MORE than the degraded `high` it currently
> runs at — this is a quality/reliability win, NOT a cost saving (no false positive). IMP-6/8/9
> exploit hook features that predate the 2.1.153-156 window (flagged "not new-ver") but were
> surfaced as real gaps by deep-read run wu2c50ri9. New-version-anchored items: IMP-1, IMP-2,
> IMP-4, IMP-7 (2.1.154); IMP-5 (2.1.152, unbuilt).

### Acceptance criteria (per item — all preserve contracts; all `.claude/scripts/tests` green before+after; ≥1 new test each)

```yaml
IMP-1:
  - "effort: xhigh in code-reviewer.md, plan-reviewer.md, planner.md, coder.md, designer.md, workflow.md frontmatter."
  - "rules/workflow.md + CLAUDE.md model-routing updated: Opus 4.8 default high, xhigh = top frontmatter level (max is session-only)."
  - "New test-effort-xhigh-frontmatter.sh: asserts no pipeline frontmatter contains 'effort: max'; all are in {low,medium,high,xhigh}."
  - "Regression: VERDICT/VERDICT_JSON envelopes + handoff schema unchanged (effort is not a phase data field)."
IMP-2:
  - "coder.md:465,468,476 + workflow.md:248 + orchestration-core.md:32 + CLAUDE.md describe /simplify as cleanup-only (reuse/simplification/efficiency/altitude) on 2.1.154+; remove 'identical to /code-review --fix' + 'correctness-fix diff expansion' claims."
  - "test-simplify-semantics-doc.sh updated to assert 2.1.154 cleanup-only wording (replaces 2.1.152 assertion); still cross-consistent across the 4 locations."
  - "Regression: simplify_applied: true|false|skipped field + coder_to_code_review schema unchanged."
IMP-6:
  - "settings.json adds timeout to git/external-tool command hooks (check-uncommitted, save-review-checkpoint, validate-handoff, save-progress-before-compact, verify-state-after-compact, inject-review-context)."
  - "New test-hook-timeouts-present.sh: asserts each named hook has a numeric timeout > 0."
  - "Regression: test-hooks-exec-form.sh + test-hook-args-positional.sh stay green (args:[] form preserved)."
IMP-4:
  - "CLAUDE.md gains 'Platform Guarantees Relied Upon' subsection with ≥6 feature→version→reliance rows incl. 2.1.154 worktree-isolation guard + 1M-context notif fix."
  - "New test-platform-guarantees-doc.sh: grep-asserts section + ≥6 versions."
IMP-7:
  - "CLAUDE.md/workflow.md note distinguishing kit /workflow (pipeline) from native /workflows (dynamic-workflows, Workflow tool)."
  - "New test-workflow-disambiguation-doc.sh: grep-asserts the note."
IMP-5:
  - "code-researcher.md frontmatter adds disallowed-tools: [Write, Edit, NotebookEdit]; reviewers untouched (need Write for memory-sync)."
  - "New test-code-researcher-readonly.sh: asserts frontmatter contains the disallow list."
  - "Regression: track-task-lifecycle.sh matcher 'code-researcher' unchanged; agent still resolves."
```

---

## 6. GATE 2 — awaiting top-5 selection

Recommended new-version-anchored top-5 (max impact, contract-safe): **IMP-1, IMP-2, IMP-4,
IMP-7, IMP-5**. Reliability-weighted alternative swaps IMP-7→IMP-6 (per-hook timeout).
Implementation per item: full TDD cycle (test-first), one improvement at a time, contracts
re-verified after each. No implementation begins before user approval.
