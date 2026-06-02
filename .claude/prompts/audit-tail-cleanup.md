# Plan: Audit Tail Cleanup (Batch D — F9 + F8 + F6; F10 deferred to user)

```yaml
feature: audit-tail-cleanup
complexity: M
source: ".claude/workflow-audit-2026-06-02.md findings F9, F8, F6, F10 (GATE-2 approved low-value tail)"
type: mixed (token / reliability-nit / parallelize) + 1 user-action item
```

## Scope

```yaml
in:
  - "F9 (token): scope workflow-protocols/SKILL.md handoff-read triggers so the Phase-2/4 delegation path does NOT also pull handoff-contracts.md + handoff-protocol.md (their shapes are already inlined in delegation-templates.md, loaded via the existing Phase-2/4 trigger). handoff-protocol.md becomes the deep-reference for net-new IMP envelope authoring only."
  - "F8 (reliability-nit): remove verdict-recovery.md step-2 dead read of review-completions.jsonl (gitignored + absent in its fresh worktree); state prior context arrives via the orchestrator launch prompt (filtered main-repo-side)."
  - "F6 (parallelize, low): add an OPTIONAL Phase-1 note to designer.md — for L/XL where CLARIFY will run, MAY launch ONE background code-researcher during the human-gated wait, integrate before PROPOSE. Mirrors planner's single-researcher background_mode (NOT N-way)."
out:
  - "F10 (latency, negligible): DEFERRED TO USER. The async:true fix edits .claude/settings.json, which protect-files.sh:86 actively denies for agent edits. Exact diff is documented below; user applies it. Not implemented or tested in this batch."
  - "No change to the 4 handoff contract SHAPES (handoff-contracts.md / delegation-templates.md bodies untouched) — F9 only rewords WHICH file loads WHEN."
  - "No handoff JSON / VERDICT / VERDICT_JSON / discriminator / canonical issue-ID hash / caveman boundary / env var / security hook change."
```

## Architecture Decision

```yaml
decision_F9: "delegation-templates.md (mandatory-loaded on Phase-2/4 via SKILL.md:91) already inlines the full handoff JSON shapes + IMP-03/04 logic. The SKILL.md 'common path' triggers (:30-31, :84-85) + Step 3 (:37-38) tell the orchestrator to ALSO read handoff-contracts.md (6KB) + handoff-protocol.md (22KB) on every handoff — a ~28KB triple-carry on the delegation path, re-incurred per loop iteration. Reword to: read handoff-contracts.md for handoffs OUTSIDE Phase-2/4 delegation; on the delegation path the shapes are already in delegation-templates.md; read handoff-protocol.md ONLY when authoring a net-new IMP-02/03/04 envelope. Pure load-trigger wording — no contract shape change."
decision_F8: "verdict-recovery runs isolation:worktree baseRef:fresh; review-completions.jsonl is gitignored + not in .worktreeinclude, so the step-2 read ALWAYS misses. The orchestrator (incomplete-output-recovery.md) already filters that file main-repo-side BEFORE launching verdict-recovery, so the agent-side read is redundant. Replace with: prior context is provided in the launch prompt; do NOT read the file directly. Preserves RULE_1 diff-only verdict."
decision_F6: "designer runs in orchestrator/command context (can dispatch Agent like planner). Phase-1 EXPLORE is serial; Phase-2 CLARIFY is human-gated (the free overlap window). Add an OPTIONAL note (gated on CLARIFY actually running) to launch ONE background researcher and integrate before PROPOSE. Single-researcher pattern (mirrors planner background_mode), NOT the N-way fan-out. Read-only; no contract surface."
contract_safety: "F9/F8/F6 edit .claude/skills + .claude/agents + .claude/commands prose only. No contract shapes, no verdict/handoff envelopes, no caveman boundaries, no env vars, no security hooks. F10 (settings.json) is NOT applied by the agent (protect-files.sh:86) — handed to user."
```

## Tests

```yaml
tdd: "Test-first, content-anchored. One combined test (test-audit-tail-cleanup.sh) with F9/F8/F6 groups. Fails red now, green after. Full suite 101 -> 102. F10 has no test (not applied)."
F9: "SKILL.md handoff triggers scope out the Phase-2/4 delegation path (mention delegation-templates.md as the Phase-2/4 source + 'do NOT also' / 'OUTSIDE ... delegation' language)."
F8: "verdict-recovery.md no longer instructs a direct Read of review-completions.jsonl; states prior context comes from the orchestrator launch prompt."
F6: "designer.md Phase 1 has an optional background-researcher note (run_in_background code-researcher, gated on CLARIFY, integrate before PROPOSE)."
```

## Acceptance Criteria

```yaml
- "AC-F9: SKILL.md Step 2 + Event-Triggers handoff lines scope the handoff-contracts/handoff-protocol read OUTSIDE Phase-2/4 delegation and name delegation-templates.md as the delegation-path source; the 4 contract shapes (handoff-contracts.md / delegation-templates.md) are byte-unchanged."
- "AC-F8: verdict-recovery.md step 2 contains no direct 'Read .claude/workflow-state/review-completions.jsonl' instruction; it states prior context is supplied by the orchestrator launch prompt. RULE_1 (verdict from diff) preserved."
- "AC-F6: designer.md Phase 1 EXPLORE has an optional, CLARIFY-gated single-background-researcher note that integrates before PROPOSE."
- "AC-F10: exact settings.json async:true diff documented in this plan + surfaced to user (NOT applied by agent — protect-files.sh:86)."
- "AC-ALL: all .claude/scripts/tests/test-*.sh pass before and after (101 -> 102)."
```

## Parts

```yaml
Part 1:
  name: "F9 — scope handoff-read off the delegation path"
  edits:
    - "SKILL.md:30-31 and :84-85: reword 'Forming handoff (common path) → read handoff-contracts.md ... also handoff-protocol.md' to scope handoff-contracts.md to handoffs OUTSIDE Phase-2/4 delegation, note delegation-templates.md already inlines the shapes on the delegation path, and make handoff-protocol.md the net-new-IMP-authoring deep-reference only."
    - "SKILL.md:37-38 (Step 3): add the same delegation-path exception note."

Part 2:
  name: "F8 — remove verdict-recovery dead read"
  edits:
    - "verdict-recovery.md step 2 (CHECK PRIOR CONTEXT): replace the direct review-completions.jsonl read with: prior context is provided by the orchestrator launch prompt (filtered main-repo-side); do NOT read the gitignored file (absent in the fresh worktree)."

Part 3:
  name: "F6 — optional designer background researcher"
  edits:
    - "designer.md Phase 1 EXPLORE: add optional_background_research note — when L/XL AND CLARIFY will run, MAY launch ONE code-researcher (Agent run_in_background:true) over affected areas, proceed into CLARIFY, integrate before Phase 3 PROPOSE; skip_when S/M or CLARIFY skipped."

Part 4 (USER ACTION — F10, not agent-applied):
  name: "F10 — async:true on pure-logging hooks (settings.json)"
  status: "DEFERRED — protect-files.sh:86 denies agent edits to settings.json"
  user_diff: |
    In .claude/settings.json, add  "async": true  to TWO hook objects ONLY:
    1. track-task-lifecycle.sh — in EACH of the 3 SubagentStart matcher groups
       (code-researcher, plan-reviewer, code-reviewer):
         { "type": "command", "command": ".claude/scripts/track-task-lifecycle.sh", "args": [], "async": true }
    2. mcp-preload-warn.sh — in the SessionStart group:
         { "type": "command", "command": ".claude/scripts/mcp-preload-warn.sh", "args": [], "async": true }
    Do NOT add async to caveman-activate.sh / enrich-context.sh / inject-review-context.sh /
    save-review-checkpoint.sh / notify-* — those emit consumed output or are ordering-critical.
  note: "Negligible wall-clock (hooks already parallel, dwarfed by inference). Pure hygiene — pure side-effect hooks should not block."
```
