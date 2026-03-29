# Task: SA-2 Two-Stage Review (Spec Compliance + Quality)

## Context

Currently /coder pipeline runs EVALUATE → IMPLEMENT → SIMPLIFY → VERIFY → handoff to code-reviewer. Code-reviewer performs a single-pass review mixing plan compliance ("right thing?") with code quality ("well built?"). There is no explicit spec compliance check — "wrong feature built" defects surface only at code-review CHANGES_REQUESTED, consuming a full review iteration.

Cross-review with Superpowers v5.0.6 validated that splitting these concerns catches different defect categories. Superpowers removed subagent spec review in v5.0.6 in favor of inline self-review (~25min savings, comparable defect rate). We adopt the inline approach.

**Spec:** `.claude/prompts/sa2-two-stage-review-spec.md` (approved)

## Scope

### IN
- Phase 3.5 SPEC CHECK inline in /coder (after VERIFY, before handoff)
- New supporting file `spec-check.md` with protocol + checklist
- `spec_check` field in coder→code-reviewer handoff contract
- code-reviewer QUICK CHECK awareness of `spec_check.status`
- code-review-rules trust note (quality focus when spec check PASS)
- Pipeline diagram updates (orchestration-core, workflow-architecture)
- workflow.md delegation template update

### OUT
- New spec-reviewer agent (reason: Superpowers v5.0.6 dropped this for overhead)
- New loop limit counters (reason: inline fix, no new cycle)
- plan-reviewer changes (reason: spec compliance is post-implementation)

## Architecture Decision

**Chosen:** Inline SPEC CHECK in /coder (Phase 3.5 after VERIFY)

**Rationale:** /coder already has plan context loaded. Mechanical checklist minimizes self-review bias. No new agent/worktree/loop. Superpowers v5.0.6 empirically validated inline over subagent.

**Rejected alternative 1:** Split code-reviewer into spec-reviewer + quality-reviewer — ~25min overhead per run.
**Rejected alternative 2:** Add plan compliance category (4f) to code-reviewer REVIEW — defeats two-stage purpose.

## Part 1: Create spec-check.md (NEW)

**File:** `.claude/skills/coder-rules/spec-check.md` (CREATE)

```markdown
# Spec Check Protocol

purpose: "Inline spec compliance self-check in /coder Phase 3.5"
when: "After VERIFY passes, before forming handoff output"

---

## Overview

Verifies "Did we build the right thing?" before code-reviewer checks "Did we build it well?"
Runs ALWAYS after VERIFY. S complexity: lightweight mode. M/L/XL: full checklist.

## Checklist

### 1. Parts Coverage (ALL complexities)
- Count Parts in plan → compare to parts_implemented list
- Each Part maps to at least one changed file
- coverage_pct = parts_covered / parts_in_plan * 100
- FAIL if coverage_pct < 100 (missing Part)

### 2. Scope Boundary (M+ only)
- `git diff --name-only`: all changed files traceable to a plan Part?
- Files outside plan scope → flag as potential gold-plating
- PARTIAL if extra files exist but are justified (auto-generated, imports)

### 3. Deviations Confirmed (M+ only)
- Read evaluate output (`.claude/prompts/{feature}-evaluate.md`)
- Verify listed deviations are still accurate
- Any NEW deviations discovered during implementation? Add to list
- PARTIAL if new deviations found (document, not necessarily bad)

### 4. Acceptance Criteria Spot-Check (L/XL only)
- For each AC in plan: identify code path or test that covers it
- Not running tests (VERIFY already passed) — just traceability
- PARTIAL if any AC cannot be mapped to implementation

### 5. Interface Contracts (L/XL only)
- Public function signatures match plan examples?
- Return types and error handling match?
- PARTIAL if minor differences (document reason)

## Output

spec_check:
  status: "PASS|PARTIAL|FAIL"
  coverage_pct: 100
  deviations_confirmed:
    - "Part N: adjustment description (from evaluate)"
  ac_coverage:
    - "AC 1: covered by TestXxx"
    - "AC 2: covered by code path in service.go:42"
  issues: []

## Inline Fix Protocol

- FAIL (missing Part): implement missing Part → re-run VERIFY → re-run SPEC CHECK
- **Max 1 inline fix retry.** If still FAIL after retry → set status: PARTIAL, proceed
- PARTIAL: document gaps, proceed to handoff. code-reviewer treats gaps as MINOR
- PASS: proceed to handoff

## Lightweight Mode (S complexity)

- Run ONLY check #1 (Parts Coverage)
- Skip checks #2-5
- Fast: single comparison, no git diff analysis

## Common Issues

### Spec check finds missing Part after VERIFY
**Cause:** Part was in plan but not implemented.
**Fix:** Implement inline, re-run VERIFY once. If tests pass → re-run SPEC CHECK.

### Extra files outside plan scope
**Cause:** Auto-generated files, go.sum updates, or gold-plating.
**Fix:** Justified extras (auto-gen, dependency updates) → PASS with note. Unjustified → remove or document as deviation.
```

## Part 2: Update coder-rules/SKILL.md

**File:** `.claude/skills/coder-rules/SKILL.md` (UPDATE)

**Change 1:** Add Spec Check Protocol section after Evaluate Protocol:

```markdown
## Spec Check Protocol

After VERIFY passes, run spec compliance self-check (Phase 3.5):
- PASS: all Parts covered, scope respected, AC traceable → proceed to handoff
- PARTIAL: minor gaps documented → proceed with gaps noted in handoff
- FAIL: missing Part → inline fix (max 1 retry) → re-run VERIFY → re-check

Full checklist: [Spec Check](spec-check.md)
```

**Change 2:** Update Instructions Step 4 — split into Step 4 (VERIFY) and Step 5 (SPEC CHECK + handoff):

Current Step 4:
> Run full VERIFY: `go vet ./... && make fmt && make lint && make test`.
> If tests fail 3x → load systematic-debugging skill, run Phase 1 root cause investigation.
> On success → form handoff payload for code-review.

New Step 4:
> Run full VERIFY: `go vet ./... && make fmt && make lint && make test`.
> If tests fail 3x → load systematic-debugging skill, run Phase 1 root cause investigation.
> On success → proceed to Step 5.

New Step 5:
> Run SPEC CHECK (see [Spec Check](spec-check.md)). S complexity: lightweight (coverage only).
> If FAIL: inline fix → re-run VERIFY → re-check (max 1 retry).
> On PASS/PARTIAL → form handoff payload for code-review, including spec_check.

**Change 3:** Add to References section:
```markdown
- [Spec Check](spec-check.md) — spec compliance self-check protocol (Phase 3.5, after VERIFY)
```

## Part 3: Update coder.md

**File:** `.claude/commands/coder.md` (UPDATE)

**Change 1:** Update `workflow.summary`:
```yaml
summary: "STARTUP → READ PLAN → EVALUATE → IMPLEMENT PARTS → SIMPLIFY (optional, L/XL) → VERIFY → SPEC CHECK → DONE"
summary_reentry: "STARTUP → READ PLAN → REVIEW RESPONSE → IMPLEMENT FIXES → VERIFY → SPEC CHECK → DONE"
```

**Change 2:** Add Phase 3.5 section after Phase 3 (VERIFY) in `workflow.phases`:

```yaml
    - phase: 3.5
      name: "SPEC CHECK"
      purpose: "Verify implementation matches plan before code-review handoff"
      reference: ".claude/skills/coder-rules/spec-check.md"
      steps:
        - "Run spec compliance checklist against plan"
        - "S complexity: lightweight mode (Parts coverage only)"
        - "M/L/XL: full checklist (coverage + scope + deviations + AC + interfaces)"
        - "If FAIL: inline fix → re-run VERIFY → re-run SPEC CHECK (max 1 retry)"
        - "If PASS/PARTIAL: proceed to handoff"
      output: |
        spec_check:
          status: "PASS|PARTIAL|FAIL"
          coverage_pct: N
          deviations_confirmed: [...]
          ac_coverage: [...]
          issues: [...]
```

**Change 3:** Update `handoff_output.narrative_for_reviewer` — add spec check line:
```yaml
    narrative_for_reviewer: |
      [Context from coder]:
      - Coder implemented {N} Parts per plan {feature}.md
      - Evaluate phase: {PROCEED|REVISE|RETURN} — adjustments: {list}
      - Deviations from plan: {list or "none"}
      - Spec check: {PASS|PARTIAL|FAIL} (coverage: {pct}%)
      - High-risk areas: {list}
```

**Change 4:** Update `handoff_output.example` — add spec_check field:
```yaml
        spec_check:
          status: PASS
          coverage_pct: 100
          deviations_confirmed:
            - "Part 3: Simplified error handling — using sentinel instead of custom error type"
          ac_coverage:
            - "AC 1: covered by TestCreateUser"
            - "AC 2: covered by TestListUsers"
          issues: []
```

**Change 5:** Update `output.final_format` — add Spec Check line after TEST:
```
    Checks:
    - [x] FMT
    - [x] LINT
    - [x] TEST (or project test command)
    - [x] SPEC CHECK (coverage: 100%)
```

Also update the VERIFY phase `output_format` block (in Phase 3) to include SPEC CHECK:
```
        - [x] VET (go vet ./...)
        - [x] FMT
        - [x] LINT
        - [x] TEST (or test-runner subagent — adapt to project)
        - [x] SPEC CHECK (coverage: N%)
```

**Change 6:** Add startup action for spec-check.md loading:
```yaml
    - action: "Load Spec Check protocol"
      files:
        - ".claude/skills/coder-rules/spec-check.md"
      purpose: "Load spec compliance checklist for Phase 3.5"
```

## Part 4: Update handoff-protocol.md

**File:** `.claude/skills/workflow-protocols/handoff-protocol.md` (UPDATE)

**Change:** Add `spec_check` field to `coder_to_code_review.payload`:

After `verify_status` block, add:
```yaml
        spec_check:
          status: "PASS|PARTIAL|FAIL"
          coverage_pct: 100
          deviations_confirmed:
            - "Part N: adjustment description"
          ac_coverage:
            - "AC N: covered by TestXxx"
          issues: []
```

## Part 5: Update workflow.md

**File:** `.claude/commands/workflow.md` (UPDATE)

**Change 1:** Update `code_review_delegation.context_to_pass` — add spec_check:
```yaml
      - "Spec check result: status, coverage, issues (from coder Phase 3.5)"
```

**Change 2:** Update `code_review_delegation.delegation_prompt_template` — add spec check line:
```yaml
      - Spec check: {PASS|PARTIAL|FAIL} (coverage: {pct}%, issues: {N})
```

## Part 6: Update code-reviewer.md

**File:** `.claude/agents/code-reviewer.md` (UPDATE)

**Change:** Update QUICK CHECK section (Process item 2) to add spec_check handling after verify_status block:

```markdown
   - Check handoff spec_check:
     - If spec_check.status == PASS:
       - TRUST coder spec compliance — skip plan compliance re-check
       - Output: `- Spec compliance: PASS (trusted from coder Phase 3.5)`
     - If spec_check.status == PARTIAL:
       - Note gaps from spec_check.issues, factor into REVIEW as MINOR
       - Output: `- Spec compliance: PARTIAL ({N} gaps — see issues)`
     - If spec_check missing:
       - Backward compat: read plan file, verify Parts coverage manually during REVIEW
       - Output: `- Spec compliance: not checked (manual fallback during REVIEW)`
```

## Part 7: Update code-review-rules/SKILL.md

**File:** `.claude/skills/code-review-rules/SKILL.md` (UPDATE)

**Change 1:** Add Spec Check Trust section after Auto-Escalation:

```markdown
## Spec Check Trust
If coder handoff includes spec_check with status=PASS → trust spec compliance, skip plan compliance re-check during REVIEW. Focus REVIEW entirely on code quality (architecture, error handling, security, test coverage).
If spec_check.status=PARTIAL → note documented gaps as MINOR during REVIEW.
If spec_check missing → backward compat: check plan coverage during REVIEW.
```

**Change 2:** Update Step 1 (Quick Check) instructions to include spec_check reading:

After the existing verify_status paragraph, add:
```markdown
Also check spec_check from coder handoff. If status=PASS → note compliance trusted. If PARTIAL → note gaps. If missing → plan to check coverage during REVIEW (backward compat).
```

## Part 8: Update orchestration-core.md

**File:** `.claude/skills/workflow-protocols/orchestration-core.md` (UPDATE)

**Change 1:** Update Pipeline diagram. In the ASCII art, change the Phase 3 line:
```
**Phase 3 — Implementation:** Execute /coder. Verify: `VERIFY` (Go default: go vet ./... && make fmt && make lint && make test). PASS → Spec Check (Phase 3.5). FAIL → fix + retry.

**Phase 3.5 — Spec Check:** Inline in /coder. Verifies plan compliance after VERIFY passes. PASS/PARTIAL → Phase 4. FAIL → inline fix (max 1 retry) → re-run VERIFY → re-check.
```

**Change 2:** Update the top pipeline ASCII diagram to include SPEC CHECK:
After `VERIFY` add `→ SPEC CHECK` before `→ code-reviewer`.

In the mermaid-style ASCII:
```
VRF -->|PASS| SC[SPEC CHECK\nPhase 3.5]
SC -->|PASS/PARTIAL| CR{code-reviewer\nagent\nworktree}
SC -->|FAIL + retry| VRF
```

## Part 9: Update workflow-architecture.md

**File:** `.claude/docs/workflow-architecture.md` (UPDATE)

**Change 1:** Update coder phases table (in "coder.md — Senior Developer" section):

Add row after Phase 3 (VERIFY):
```
| 3.5  | **Spec Check**  | Verify plan compliance: Parts coverage, scope, deviations, AC, interfaces |
```

**Change 2:** Update the "5 фаз работы" count to "6 фаз работы".

**Change 3:** In Core Pipeline Flow mermaid diagram, add SPEC CHECK node between VERIFY and code-reviewer:

```mermaid
    VRF -->|PASS| SC{SPEC CHECK\nPhase 3.5}
    SC -->|PASS/PARTIAL| CR{code-reviewer\nagent\nworktree}
    SC -->|FAIL\nmax 1 retry| IMP_FIX[Inline fix] --> VRF
```

Replace existing `VRF -->|PASS| CR{code-reviewer...}` with the above. Keep all other diagram nodes unchanged.

## Files Summary

| # | File | Action | Description |
|---|------|--------|-------------|
| 1 | `.claude/skills/coder-rules/spec-check.md` | CREATE | Spec check protocol + checklist (< 120 lines) |
| 2 | `.claude/skills/coder-rules/SKILL.md` | UPDATE | Add Spec Check Protocol section + Step 5 + reference |
| 3 | `.claude/commands/coder.md` | UPDATE | Phase 3.5, handoff, summary, startup |
| 4 | `.claude/skills/workflow-protocols/handoff-protocol.md` | UPDATE | Add spec_check to coder_to_code_review |
| 5 | `.claude/commands/workflow.md` | UPDATE | Delegation template + context_to_pass |
| 6 | `.claude/agents/code-reviewer.md` | UPDATE | QUICK CHECK spec_check awareness |
| 7 | `.claude/skills/code-review-rules/SKILL.md` | UPDATE | Spec Check Trust section + Step 1 update |
| 8 | `.claude/skills/workflow-protocols/orchestration-core.md` | UPDATE | Pipeline diagram |
| 9 | `.claude/docs/workflow-architecture.md` | UPDATE | Coder phases table + pipeline diagram |

## Acceptance Criteria

### Functional

- [ ] /coder Phase 3.5 SPEC CHECK runs after VERIFY, produces spec_check
- [ ] spec-check.md has 5-point checklist with lightweight mode for S complexity
- [ ] Handoff payload includes spec_check field (status, coverage_pct, issues)
- [ ] code-reviewer QUICK CHECK reads and trusts spec_check.status=PASS
- [ ] Backward compatible: missing spec_check → code-reviewer falls back

### Technical
- [ ] spec-check.md < 120 lines
- [ ] No new loop limit counters added
- [ ] All cross-references between files are consistent
- [ ] Pipeline diagrams in orchestration-core.md and workflow-architecture.md updated

### Architecture
- [ ] Two-stage separation: Stage 1 (/coder) = compliance, Stage 2 (code-reviewer) = quality
- [ ] code-review-rules explicitly documents trust relationship
- [ ] Inline fix capped at 1 retry (no infinite loop risk)

## Notes

- No Go code changes — all files are Markdown configuration artifacts
- VERIFY phase is N/A for this task (no compilation/tests)
- Validation: manual review of file contents and cross-references
- Superpowers v5.0.6 reference validates inline over subagent approach
