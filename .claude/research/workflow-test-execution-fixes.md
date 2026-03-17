# Workflow Test Execution — Proposed Fixes

**Date:** 2026-03-18
**Research:** `workflow-test-execution-analysis.md`
**Status:** Fixes proposed + self-reviewed

---

## Fix Overview

| Fix   | Targets Issue    | Artifact(s)                                  | Severity | Risk                               |
| ----- | ---------------- | -------------------------------------------- | -------- | ---------------------------------- |
| FIX-1 | ISSUE-5, ISSUE-1 | handoff-protocol.md                          | HIGH     | LOW — additive contract change     |
| FIX-2 | ISSUE-6, ISSUE-1 | code-reviewer.md, code-review-rules/SKILL.md | HIGH     | MEDIUM — changes blocking behavior |
| FIX-3 | ISSUE-2          | coder.md, coder-rules/SKILL.md               | HIGH     | LOW — adds negative instruction    |
| FIX-4 | ISSUE-7          | checkpoint-protocol.md                       | MEDIUM   | LOW — additive field               |
| FIX-5 | ISSUE-3          | workflow.md                                  | MEDIUM   | LOW — adds delegation instruction  |
| FIX-6 | ISSUE-8          | coder-rules/SKILL.md                         | LOW      | LOW — clarification only           |

---
## FIX-2: Conditional QUICK CHECK in Code-Reviewer

**Targets:** ISSUE-6 (no skip mechanism), ISSUE-1 (double test execution)
**Depends on:** FIX-1 (verify_status must exist in handoff)

### Change 2a: code-reviewer.md — Step 2 QUICK CHECK

**Current (line ~58-67):**
```
2. **QUICK CHECK (blocking)**
   - Run: `make lint` — if FAIL → STOP, return to author with lint errors
   - Run: `make test` — if FAIL → STOP, return to author with test failures
   - Rule: Do NOT proceed to review if QUICK CHECK fails
   - Output:
     ```
     ## QUICK CHECK ✓
     - Lint: [PASS/FAIL]
     - Test: [PASS/FAIL]
     ```
```

**Proposed:**
```
2. **QUICK CHECK (blocking)**
   - Check handoff verify_status:
     - If verify_status.lint == PASS AND verify_status.test == PASS:
       - TRUST coder verification — skip redundant test execution
       - Output: `## QUICK CHECK ✓ (trusted from coder VERIFY)`
     - If verify_status missing OR any FAIL:
       - Run: `make lint` — if FAIL → STOP, return to author with lint errors
       - Run: `make test` — if FAIL → STOP, return to author with test failures
   - Rule: Do NOT proceed to review if QUICK CHECK fails (whether trusted or re-run)
   - Output:
     ```
     ## QUICK CHECK ✓
     - Lint: [PASS/FAIL] [(trusted/re-run)]
     - Test: [PASS/FAIL] [(trusted/re-run)]
     ```
```

### Change 2b: code-reviewer.md — RULE_3 update

**Current (line ~33):**
```
- RULE_3 Tests First: Do NOT start review without LINT && TEST passing
```

**Proposed:**
```
- RULE_3 Tests First: Do NOT start review without LINT && TEST passing (trusted from coder VERIFY if verify_status in handoff, otherwise re-run)
```

### Change 2c: code-review-rules/SKILL.md — Step 1 update

**Current (line ~27-28):**
```
### Step 1: Run Quick Check — lint + test (blocking)
Run `make lint` and `make test`. If EITHER fails → STOP, return to coder.
Do NOT proceed to review if Quick Check fails.
```

**Proposed:**
```
### Step 1: Quick Check — lint + test (blocking)
If coder handoff includes verify_status with lint=PASS and test=PASS → trust coder verification, skip re-run.
Otherwise: run `make lint` and `make test`. If EITHER fails → STOP, return to coder.
Do NOT proceed to review if Quick Check fails (whether trusted or re-run).
```

### Self-Review: FIX-2

| Criterion             | Assessment                                                          |
| --------------------- | ------------------------------------------------------------------- |
| Safety preserved?     | YES — fallback to full re-run if verify_status missing              |
| Trust model sound?    | YES — coder VERIFY runs in same commit, worktree reflects same code |
| False positive risk?  | LOW — verify_status only set when coder VERIFY actually passed      |
| Breaks existing flow? | NO — graceful degradation (missing field = re-run as before)        |
| Worktree concern?     | VALID — worktree has same code but different env. See note below.   |

**Note on worktree trust:** The worktree is created from the committed state. The coder committed code that passed VERIFY. The only risk is environment difference (different Go cache, different binary state). For `make lint` + `make test` with source-only inputs, this risk is negligible.

**Edge case:** If the coder's VERIFY used a different version of linter/compiler than the worktree... This is theoretically possible but practically never happens (same machine, same session). If needed, a future enhancement could compare `go version` or linter version in the handoff.

**Verdict: APPROVED with note** — the trust model is sound for same-machine same-session workflows. The fallback guarantees safety.

---

## FIX-4: Add `verify_result` to Checkpoint Format

**Targets:** ISSUE-7 (no verify state in checkpoint)

### Change: checkpoint-protocol.md — format section

**Current format fields (line ~13-31):**
```yaml
format:
  feature: "{feature-name}"
  phase_completed: "0.5|1|2|3|4|5"
  # ... other fields ...
  handoff_payload: "{ ... }"
  issues_history: [...]
```

**Proposed — add after `handoff_payload`:**
```yaml
format:
  feature: "{feature-name}"
  phase_completed: "0.5|1|2|3|4|5"
  # ... existing fields ...
  handoff_payload: "{ ... }"
  verify_result:
    status: "PASS|FAIL|null"
    command: "make fmt && make lint && make test"
    timestamp: "ISO 8601 | null"
  issues_history: [...]
```

### Self-Review: FIX-4

| Criterion                           | Assessment                                                                  |
| ----------------------------------- | --------------------------------------------------------------------------- |
| Backward compatible?                | YES — new field, null default                                               |
| Useful for recovery?                | YES — session recovery can skip re-testing                                  |
| Checkpoint format consistent?       | YES — follows existing field patterns                                       |
| Requires checkpoint reader changes? | NO — orchestration-core.md recovery table can use it but doesn't require it |

**Verdict: APPROVED** — low-risk additive improvement

---

## FIX-5: Pass Verify Status in Delegation Instruction

**Targets:** ISSUE-3 (worktree overhead — partial mitigation)

### Change: workflow.md — `code_review_delegation.isolation` comment

**Current (line ~216):**
```yaml
isolation: "worktree — agent sees only committed changes. Ensure git commit before delegating."
```

**Proposed:**
```yaml
isolation: "worktree — agent sees only committed changes. Ensure git commit before delegating."
optimization: "Pass verify_status in handoff to allow code-reviewer to skip QUICK CHECK re-run (see FIX-1). Worktree overhead is unavoidable but test overhead is not."
```

### Self-Review: FIX-5

| Criterion         | Assessment                                          |
| ----------------- | --------------------------------------------------- |
| Actionable?       | YES — reminds orchestrator to include verify_status |
| Risk?             | NONE — documentation-level change                   |
| Depends on FIX-1? | YES — requires verify_status field to exist         |

**Verdict: APPROVED** — documentation reinforcement

---


## Implementation Order

```
FIX-1 (handoff contract)      ← foundation, no dependencies
   │
   ├─→ FIX-2 (conditional QUICK CHECK)  ← depends on FIX-1
   │      │
   │      └─→ FIX-5 (delegation instruction)  ← depends on FIX-1+2
   │
   └─→ FIX-4 (checkpoint verify_result)  ← depends on FIX-1 concepts

FIX-3 (test frequency policy)  ← independent, can go first
FIX-6 (formatting clarity)     ← independent, can go first
```

**Recommended order:** FIX-3 → FIX-6 → FIX-1 → FIX-2 → FIX-4 → FIX-5

**Rationale:** FIX-3 and FIX-6 are independent, low-risk, and address the immediate user pain (coder over-testing). FIX-1→2→4→5 form a chain that addresses the structural double-execution problem.

---

## Expected Impact After All Fixes

| Metric                            | Before                  | After                                 | Improvement     |
| --------------------------------- | ----------------------- | ------------------------------------- | --------------- |
| Test runs during implementation   | 5-8× per Part           | 0× (tests at VERIFY only)             | -95%            |
| Test runs at VERIFY               | 1×                      | 1× (unchanged)                        | —               |
| Test runs at QUICK CHECK          | 1× (always)             | 0× (trusted) or 1× (fallback)         | -100% typical   |
| Format runs per Part              | 3× (hook+manual+VERIFY) | 1× (hook only) + 1× (VERIFY)          | -33%            |
| Worktree test overhead            | ~20s+                   | ~0s (trusted)                         | -100% typical   |
| **Total time saved per workflow** | —                       | **~120-195s** (M project, ~100 tests) | **Significant** |

---

## Risk Assessment

| Risk                            | Probability | Impact | Mitigation                                        |
| ------------------------------- | ----------- | ------ | ------------------------------------------------- |
| Tests not caught between Parts  | LOW         | LOW    | LINT catches compile errors, VERIFY catches logic |
| Stale verify_status in handoff  | VERY LOW    | MEDIUM | Same commit, same session, same machine           |
| Code-reviewer trusts false PASS | VERY LOW    | HIGH   | Fallback: re-run if verify_status missing         |
| TDD workflow conflict           | LOW         | LOW    | TDD skill overrides per-part behavior explicitly  |
