# QW-4: Review Response Protocol

## Metadata
- **Task:** Adapt Superpowers' receiving-code-review skill for Claude Kit /coder
- **Type:** enhancement
- **Complexity:** XL
- **Source:** `superpowers-main/skills/receiving-code-review/SKILL.md`
- **Target:** `.claude/skills/coder-rules/review-response.md` (new supporting file)
- **Sequential Thinking:** Used (5 thoughts — architecture, integration, structure, changes, risks)

## Scope

### In Scope
- Create `review-response.md` — review feedback handling protocol for /coder
- Adapt Superpowers concepts: response pattern, forbidden responses, YAGNI check, push-back protocol
- Source-specific handling: code-reviewer (CHANGES_REQUESTED) vs plan-reviewer (approved_with_notes)
- Integration with existing handoff protocol (iteration-aware response → handoff payload)
- Update `coder-rules/SKILL.md`, `coder.md`, `checklist.md` with references and triggers

### Out of Scope
- Modifying `handoff-protocol.md` (use existing fields)
- Modifying `orchestration-core.md` (routing already correct)
- Modifying `workflow.md` (delegation already passes iteration)
- Human-facing review responses (GitHub PR comments — agent-to-agent context)

## Architecture Decision

**Adapt as supporting file in coder-rules, NOT standalone skill.**

Why: review-response is invoked only when /coder re-enters after CHANGES_REQUESTED. It's a sub-protocol of /coder, not an independent workflow phase. Consistent with QW-2 (verification-discipline.md) approach.

**Key adaptation from Superpowers:**
| Superpowers Concept | Claude Kit Adaptation |
|---|---|
| Human partner (trusted source) | Plan = authority, code-reviewer = structured feedback |
| External reviewer (skeptical) | N/A — both reviewers are pipeline agents |
| Forbidden responses (anti-sycophancy) | Anti-patterns for implementation behavior (verify before fix) |
| YAGNI check (grep for usage) | RULE_1 alignment (is it in the plan?) |
| Push-back (tell human partner) | Document as deviation + technical reasoning in handoff |
| Implementation order | Severity-based triage (BLOCKER → MAJOR → MINOR → NIT) |
| GitHub thread replies | N/A (agent-to-agent, not PR) |
| Source-specific handling | code-reviewer issues vs plan-reviewer approved_with_notes |

## Parts

### Part 1: Create `review-response.md`

**File:** `.claude/skills/coder-rules/review-response.md`

**Structure (YAML-first):**

```yaml
# Review Response Protocol
purpose: "..."
---

response_protocol:
  trigger: ...
  iron_law: ...

  response_pattern:
    # 5-step: TRIAGE → VERIFY → EVALUATE → IMPLEMENT → DOCUMENT

  forbidden_patterns:
    # Anti-patterns for handling review feedback

  source_handling:
    code_reviewer:
      # Primary — structured issues with severity from code_review_to_completion contract
    plan_reviewer_notes:
      # Secondary — approved_with_notes from plan_review_to_coder contract

  push_back_protocol:
    # When to challenge issues, how to document

  yagni_check:
    # Aligned with RULE_1 (Plan Only)

  implementation_order:
    # Severity-based triage

  handoff_integration:
    # Iteration-aware handoff payload for next code-review round

  examples:
    # Good/Bad patterns adapted for pipeline context

  common_mistakes:
    # Table format consistent with other supporting files
```

**Content details:**

1. **Iron Law:** "VERIFY before implementing. No issue is accepted without checking against codebase reality."

2. **Response Pattern (5-step):**
   - TRIAGE: Parse issues[] from code-reviewer handoff by severity
   - VERIFY: Check each issue against actual code state
   - EVALUATE: Per issue → ACCEPT (fix) / PUSH_BACK (technical reasoning) / CLARIFY (need more context)
   - IMPLEMENT: Fix in order: BLOCKER → MAJOR → MINOR → NIT (skip NIT if iteration 2+)
   - DOCUMENT: Update handoff with issues_resolved, push_backs, remaining

3. **Forbidden Patterns (adapted):**
   - "Accepting all issues without verification" (blind implementation)
   - "Implementing BLOCKER + NIT simultaneously" (batch without testing)
   - "Adding code not in plan because reviewer suggested it" (RULE_1 violation)
   - "Skipping verification after fix" (each fix tested individually)

4. **Source Handling:**
   - code-reviewer: issues[] with severity/category/location — structured, machine-parseable
   - plan-reviewer approved_with_notes: guidance notes, NOT fix requests — integrate during EVALUATE

5. **Push-Back Protocol:**
   - When: issue contradicts plan, breaks existing tests, YAGNI (not in plan), incorrect for this codebase
   - How: document in handoff `deviations_from_plan` with technical reasoning
   - Escalation: if architectural disagreement → note for orchestrator, don't silently ignore

6. **YAGNI Check (RULE_1 aligned):**
   ```
   IF reviewer suggests adding code/feature:
     CHECK: Is this in the approved plan?
     IF not in plan → push-back: "Outside plan scope per RULE_1"
     IF in plan but missed → accept, implement
   ```

7. **Handoff Integration:**
   - iteration field incremented by orchestrator
   - Add to deviations_from_plan: any push-backs with reasoning
   - Add to risks_mitigated: resolved issues from review
   - verify_status: must re-run full VERIFY after fixes

8. **NIT Handling Strategy:**
   - Iteration 1/3: fix all including NIT
   - Iteration 2/3: fix BLOCKER + MAJOR + MINOR, skip NIT
   - Iteration 3/3: fix BLOCKER + MAJOR only, escalate rest to user
   - Rationale: prevent infinite loops on stylistic disagreements

### Part 2: Update `coder-rules/SKILL.md`

**File:** `.claude/skills/coder-rules/SKILL.md`

**Change:** Add reference to References section (line ~100):

```markdown
## References
...existing references...
- [Review Response](review-response.md) — handling CHANGES_REQUESTED feedback from code-reviewer (loaded on re-entry iterations)
```

### Part 3: Update `coder.md`

**File:** `.claude/commands/coder.md`

**Change 1:** Add trigger:

```yaml
triggers:
  ...existing triggers...

  - if: "Re-entry after CHANGES_REQUESTED (code-review iteration > 1)"
    then: "Load review-response.md, follow response protocol before implementing fixes"
```

**Change 2:** Add conditional loading in STARTUP:

```yaml
startup:
  immediate_actions:
    ...existing actions...

    - action: "Conditional: Load Review Response protocol"
      condition: "Re-entry after CHANGES_REQUESTED (iteration > 1 in handoff context)"
      files:
        - ".claude/skills/coder-rules/review-response.md"
      purpose: "Load review feedback handling protocol. Triggers TRIAGE → VERIFY → EVALUATE before IMPLEMENT."
```

**Change 3:** Add phase 0.5 for review response (before EVALUATE on re-entry):

```yaml
    - phase: 0.5
      name: "REVIEW RESPONSE (re-entry only)"
      condition: "Active when /coder re-enters after CHANGES_REQUESTED"
      skip_when: "First run (no prior code-review)"
      reference: ".claude/skills/coder-rules/review-response.md"
      steps:
        - "TRIAGE: Parse issues by severity from code-reviewer handoff"
        - "VERIFY: Check each issue against current codebase"
        - "EVALUATE: ACCEPT / PUSH_BACK / CLARIFY per issue"
        - "Output: issues triage summary → feeds into IMPLEMENT phase"
      note: "Replaces EVALUATE (Phase 1.5) on re-entry — plan already validated, focus on review feedback"
```

**Change 4:** Add `skip_when` to Phase 1.5 (EVALUATE) for re-entry:

```yaml
    - phase: 1.5
      name: "EVALUATE"
      # ...existing content...
      skip_when: "Re-entry after CHANGES_REQUESTED — Phase 0.5 (REVIEW RESPONSE) handles feedback triage instead"
```

This ensures Phase 0.5 and Phase 1.5 are mutually exclusive:
- First run: Phase 1.5 (EVALUATE) runs, Phase 0.5 skipped
- Re-entry: Phase 0.5 (REVIEW RESPONSE) runs, Phase 1.5 skipped

**Change 5:** Update `workflow.summary` for re-entry variant:

```yaml
workflow:
  summary: "STARTUP → READ PLAN → EVALUATE → IMPLEMENT PARTS → SIMPLIFY (optional, L/XL) → VERIFY → DONE"
  summary_reentry: "STARTUP → READ PLAN → REVIEW RESPONSE → IMPLEMENT FIXES → VERIFY → DONE"
```

### Part 4: Update `checklist.md`

**File:** `.claude/skills/coder-rules/checklist.md`

**Change:** Add review_response section:

```yaml
  review_response:
    condition: "Active on re-entry after CHANGES_REQUESTED"
    checks:
      - "Issues triaged by severity (BLOCKER → MAJOR → MINOR → NIT)"
      - "Each issue verified against codebase before implementing"
      - "Push-backs documented with technical reasoning"
      - "Fixes implemented in severity order, tested individually"
      - "NIT handling follows iteration strategy (1/3: all, 2/3: skip NIT, 3/3: BLOCKER+MAJOR only)"
      - "Handoff includes resolution status per issue"
```

### Part 5: Verify consistency

- Verify all cross-references are valid (file paths, section names)
- Verify YAML-first format compliance
- Verify no conflicts with existing handoff-protocol.md contracts
- Verify RULE_1 alignment in YAGNI check section

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Scope creep into handoff-protocol.md | Medium | Use existing fields, document usage in review-response.md |
| Conflict with RULE_1 on reviewer suggestions | Low | YAGNI check explicitly references RULE_1 |
| Over-engineering forbidden responses for agent context | Low | Focus on implementation behavior, not communication style |
| Phase 0.5 confusion with existing Phase 1.5 (EVALUATE) | Medium | Clear condition: "re-entry only", explicitly replaces EVALUATE |

## Acceptance Criteria

### Functional

- review-response.md loaded by /coder on re-entry after CHANGES_REQUESTED
- 5-step response pattern (TRIAGE → VERIFY → EVALUATE → IMPLEMENT → DOCUMENT) documented and actionable
- Source-specific handling differentiates code-reviewer issues from plan-reviewer notes
- Push-back protocol produces structured reasoning in handoff deviations_from_plan
- NIT handling strategy prevents infinite review loops

### Technical

- YAML-first format (>80% YAML, minimal prose) — consistent with other supporting files
- All cross-references valid (handoff-protocol.md contracts, RULE_1, checklist sections)
- Phase 0.5 / Phase 1.5 mutual exclusion enforced via skip_when conditions

### Architecture

- No modifications to handoff-protocol.md (use existing fields only)
- No modifications to orchestration-core.md (routing already correct)
- RULE_1 alignment verified in YAGNI check section
- Supporting file pattern consistent with QW-2 (verification-discipline.md)

## Test Strategy

- Manual verification: read all modified files, check cross-references
- YAML lint: hooks auto-validate on edit
- Reference check: hooks auto-validate on write to .claude/

## Files Summary

| File | Action | Part |
|---|---|---|
| `.claude/skills/coder-rules/review-response.md` | CREATE | Part 1 |
| `.claude/skills/coder-rules/SKILL.md` | MODIFY (add reference) | Part 2 |
| `.claude/commands/coder.md` | MODIFY (trigger + startup + phase 0.5 + phase 1.5 skip_when + summary) | Part 3 |
| `.claude/skills/coder-rules/checklist.md` | MODIFY (add review_response section) | Part 4 |

## Context

- **Origin:** QW-4 from cross-review analysis (`.claude/docs/cross-review-superpowers.md`)
- **Source material:** Superpowers v5.0.6 `receiving-code-review` skill
- **Existing gap:** /coder receives CHANGES_REQUESTED but has no protocol for triaging, verifying, or pushing back on review issues
- **Related work:** QW-2 (verification-discipline.md) — same pattern (supporting file in coder-rules)
- **Research docs:** `.claude/docs/cross-review-superpowers.md`, `.claude/docs/workflow-architecture.md`

## Dependencies

- handoff-protocol.md: code_review_to_completion contract (read-only)
- orchestration-core.md: CHANGES_REQUESTED routing (read-only)
- coder-rules/SKILL.md: add reference (write)
- coder.md: add trigger + phase (write)
- checklist.md: add section (write)
