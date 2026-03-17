# Workflow Fixes — Safety Review

**Date:** 2026-03-18
**Input:** `workflow-test-execution-fixes.md` (6 fixes)
**Scope:** Deep safety analysis of each proposed fix against the full workflow artifact graph
**Status:** Complete

---

## Methodology

Each fix was traced through **every artifact it touches** (direct and transitive) to verify:

1. **Contract integrity** — does the change break any producer/consumer contract?
2. **Rule conflicts** — does it contradict existing CRITICAL/HIGH rules?
3. **Edge case safety** — TDD mode, session recovery, loop iterations (max 3), worktree isolation, --minimal mode, re-routing
4. **Graceful degradation** — what happens when the new field/behavior is absent?
5. **Transitive effects** — does it change behavior of artifacts not directly modified?

---

## FIX-1: Add `verify_status` to Handoff Contract

### Artifacts directly modified

| Artifact              | Change                                                       |
| --------------------- | ------------------------------------------------------------ |
| `handoff-protocol.md` | Add `verify_status` field to `coder_to_code_review`          |
| `workflow.md`         | Add verify_status to `context_to_pass` + delegation template |
| `coder.md`            | Add verify_status to handoff example                         |

### Safety Analysis

#### 1.1 Contract Integrity

**Producer side (coder.md):**

- Coder Phase 3 VERIFY already runs `make fmt && make lint && make test` (line 320-322)
- The fix asks coder to **report results it already has** — no new computation needed
- Risk: Coder might forget to populate `verify_status` → FIX-2 has fallback (re-run)
- **SAFE**: Additive field, existing data flow unchanged

**Consumer side (code-reviewer.md):**

- Code-reviewer receives handoff via delegation prompt, not direct contract read
- The verify_status arrives as text in the delegation prompt: `"Verify: lint PASS, test PASS (command: make fmt && make lint && make test)"`
- Code-reviewer must **parse natural language** to extract verify_status → depends on FIX-2 to define parsing behavior
- **Risk: LOW** — even if parsing fails, FIX-2's fallback triggers re-run

**Orchestrator side (workflow.md):**

- Orchestrator forms the delegation prompt using template (line ~225)
- Template change is **additive** — adds one line to existing template
- **SAFE**: No existing behavior removed

#### 1.2 Rule Conflicts

| Rule                                               | Conflict?                    | Analysis                                                                                                                       |
| -------------------------------------------------- | ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Code-reviewer RULE_3 "Tests First"                 | **YES — addressed by FIX-2** | RULE_3 says "Do NOT start review without LINT && TEST passing" — FIX-1 alone doesn't change RULE_3. Must be paired with FIX-2. |
| Coder RULE_5 "Tests Pass"                          | No                           | Coder still must pass tests before forming verify_status                                                                       |
| Handoff protocol "every phase MUST create handoff" | No                           | Field is additive within existing handoff                                                                                      |

#### 1.3 Edge Cases

| Edge Case                     | Safe? | Reason                                                                                                                                                                         |
| ----------------------------- | ----- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **TDD mode**                  | YES   | TDD affects Part-level workflow, not VERIFY phase. VERIFY still runs at the end. verify_status is populated after VERIFY regardless of TDD.                                    |
| **Session recovery**          | YES   | Checkpoint stores `handoff_payload` (line 30 of checkpoint-protocol.md). If verify_status is in the handoff, it's automatically persisted in checkpoint. Recovery restores it. |
| **Loop iteration 2/3 or 3/3** | YES   | On CHANGES_REQUESTED, coder re-implements and re-runs VERIFY. New verify_status overwrites old. No stale data risk.                                                            |
| **--minimal mode**            | YES   | Minimal mode affects planner, not coder. Coder always has VERIFY phase.                                                                                                        |
| **Re-routing (M→L)**          | YES   | Re-routing changes complexity label, not VERIFY behavior.                                                                                                                      |
| **Worktree**                  | YES   | verify_status describes main-workspace results. Worktree gets this via delegation prompt text, not via shared state.                                                           |

#### 1.4 Graceful Degradation

- **verify_status missing from handoff?** → FIX-2 defines fallback: re-run tests (current behavior)
- **Coder crashes before forming handoff?** → Orchestrator doesn't delegate to code-reviewer (Phase 3 incomplete)
- **Handoff contains verify_status but coder lied?** → Extremely unlikely (same automated process), but FIX-2's fallback handles this edge case if verify_status.lint != PASS or verify_status.test != PASS

#### 1.5 Transitive Effects

- **pipeline-metrics.md** — Not affected. Metrics track phases/iterations, not verify state.
- **plan-reviewer.md** — Not affected. Different handoff contract (`planner_to_plan_review`).
- **code-researcher.md** — Not affected. Not in the verify path.
- **checkpoint-protocol.md** — **Positive transitive effect**: checkpoint stores `handoff_payload`, so verify_status is automatically persisted without changing checkpoint format.

### Verdict: SAFE

- **Risk: LOW** — purely additive
- **Dependency: FIX-2** — without FIX-2, this field exists but is unused (harmless)
- **Recommendation: Apply as-is**

---

## FIX-2: Conditional QUICK CHECK in Code-Reviewer

### Artifacts directly modified

| Artifact                     | Change                                          |
| ---------------------------- | ----------------------------------------------- |
| `code-reviewer.md`           | QUICK CHECK becomes conditional + RULE_3 update |
| `code-review-rules/SKILL.md` | Step 1 update                                   |

### Safety Analysis

#### 2.1 Contract Integrity

**Critical change:** QUICK CHECK goes from **always run** to **conditionally skip**.

This is the **highest-risk fix** in the set. Analysis:

- **Current contract:** code-reviewer ALWAYS runs `make lint` + `make test` before review
- **New contract:** code-reviewer trusts coder's verify_status IF it says PASS; else re-runs
- **Fallback:** verify_status missing → re-run as before (backward compatible)

**Worktree isolation concern:**
The worktree reflects the **committed** state. The coder committed code that passed VERIFY. So the code in the worktree is **identical** to what passed tests. The only theoretical risk:

- Different Go version in worktree (impossible — same machine)
- Different module cache (possible but Go resolves from `go.sum` deterministically)
- Environment variables differ (unlikely — same shell session)

**Conclusion:** The worktree contains bit-identical source code. If tests passed on this code in main workspace, they will pass on this code in worktree. **SAFE** for source-only test suites.

**Exception case:** Integration tests that depend on external state (database, network) could differ. But:

- The time between coder VERIFY and code-reviewer QUICK CHECK is seconds (same session)
- External state is extremely unlikely to change in this window
- This is a theoretical, not practical, concern

#### 2.2 Rule Conflicts

| Rule                                  | Conflict?     | Analysis                                                                                                                                                                                                                                                                      |
| ------------------------------------- | ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| RULE_3 "Tests First"                  | **MODIFIED**  | The fix changes RULE_3 from absolute to conditional. This is the most sensitive change. The new wording preserves the safety guarantee: "trusted from coder VERIFY if verify_status in handoff, otherwise re-run". Tests always pass before review — just sometimes by trust. |
| RULE_1 "No Fix"                       | No            | Not affected                                                                                                                                                                                                                                                                  |
| RULE_2 "No Approve Blockers"          | No            | Not affected                                                                                                                                                                                                                                                                  |
| "Do NOT proceed if QUICK CHECK fails" | **Preserved** | The fix adds "whether trusted or re-run" — explicit preservation                                                                                                                                                                                                              |

**CRITICAL SAFETY QUESTION:** Can verify_status be PASS when tests actually fail?

Scenarios:

1. Coder runs VERIFY → tests pass → forms handoff → commits → code-reviewer starts → **tests haven't changed** → SAFE
2. Coder runs VERIFY → tests pass → **another process modifies files** → code-reviewer starts → tests might fail → BUT code-reviewer runs in **worktree from committed state** (not modified files) → SAFE
3. Coder lies about verify_status → This requires the **model itself** to hallucinate test results. VERIFY is a Bash command with visible output. The risk is **negligible**.

#### 2.3 Edge Cases

| Edge Case                      | Safe?         | Reason                                                                                                                                                                                                                                                                                                                                       |
| ------------------------------ | ------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Loop iteration 2/3**         | PARTIALLY     | On CHANGES_REQUESTED, coder re-implements and re-runs VERIFY. New verify_status is generated. But if the **second iteration's coder** has a bug and claims PASS... the fallback in QUICK CHECK would catch it. However, FIX-2 trusts verify_status=PASS. **Risk: VERY LOW** — coder VERIFY is automated (Bash command), not model-generated. |
| **Worktree cold cache**        | YES           | If QUICK CHECK is skipped, the cold cache problem is avoided entirely. This is the intended benefit.                                                                                                                                                                                                                                         |
| **Hooks in worktree**          | YES           | PostToolUse hooks fire on Write/Edit. Code-reviewer doesn't Write/Edit (RULE_1: No Fix). So hooks are irrelevant during code review.                                                                                                                                                                                                         |
| **Session recovery → Phase 4** | **EDGE CASE** | If session recovers directly to Phase 4 via heuristic (code exists, tests pass), verify_status may not be in the recovery context. FIX-2's fallback handles this: missing verify_status → re-run. **SAFE.**                                                                                                                                  |
| **SubagentStop hook**          | YES           | `save-review-checkpoint.sh` fires when code-reviewer stops. It saves review completion marker. Not affected by QUICK CHECK behavior.                                                                                                                                                                                                         |

#### 2.4 Graceful Degradation

- **FIX-1 not applied** (verify_status doesn't exist) → verify_status missing → fallback: re-run as before → **SAFE, zero behavior change**
- **FIX-1 applied but coder didn't populate field** → same fallback → **SAFE**
- **verify_status says FAIL** → re-run → **SAFE**
- **verify_status says PASS but env changed** → trusts and skips → **THEORETICAL RISK, see 2.1 analysis above** → practically safe

#### 2.5 Transitive Effects

- **orchestration-core.md** — Loop counter logic unchanged. Code-reviewer still returns verdict. Counter increments on CHANGES_REQUESTED regardless of QUICK CHECK behavior.
- **pipeline-metrics.md** — No impact. Metrics track iterations, not internal QUICK CHECK behavior.
- **Auto-fmt-go.sh** — Not triggered (code-reviewer doesn't Write/Edit).

### Verdict: SAFE WITH CAVEAT

- **Risk: MEDIUM** — changes a safety-critical rule (RULE_3)
- **Mitigation: STRONG** — fallback to full re-run when verify_status is missing
- **Caveat: Integration tests with external dependencies** — if the project uses `make test` to run integration tests that depend on DB/network state, the trust model has a theoretical (but practically negligible) gap
- **Recommendation: Apply as-is.** The fallback mechanism makes this safe. If the user has concerns about integration test state, they can add an exception note in PROJECT-KNOWLEDGE.md.

---

## FIX-3: Explicit Test Frequency Policy for Coder

### Artifacts directly modified

| Artifact               | Change                                                                               |
| ---------------------- | ------------------------------------------------------------------------------------ |
| `coder.md`             | Add "Do NOT run tests between Parts" to `after_each_part` + add note to VERIFY phase |
| `coder-rules/SKILL.md` | Add "IMPORTANT: Do NOT run tests between Parts" to Step 3                            |

### Safety Analysis

#### 3.1 Contract Integrity

**This fix adds a NEGATIVE instruction** — "Do NOT run tests between Parts."

**Current behavior (implicit):** Coder can run tests whenever it wants. VERIFY is the authoritative check.
**New behavior (explicit):** Coder MUST NOT run tests between Parts. Tests run ONCE at VERIFY.

**Compliance with existing rules:**

- `coder.md` Phase 2 `after_each_part`: says "Hooks auto-run formatter + linter" — **already implies only FMT+LINT per part, not TEST** → FIX-3 makes this explicit. No contradiction.
- `coder-rules/SKILL.md` Step 3: says "After each Part: run FMT + LINT" — **explicitly excludes TEST** → FIX-3 reinforces. No contradiction.
- `coder.md` Phase 3 VERIFY: "FMT && LINT" + TEST — **tests are supposed to run here** → FIX-3 aligns. No contradiction.

**No existing rule says "run tests between parts."** FIX-3 is purely an explicit prohibition of an unspecified behavior.

#### 3.2 Rule Conflicts

| Rule                                        | Conflict?     | Analysis                                                                                                                                                                                                                                                                                                                                                                               |
| ------------------------------------------- | ------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| RULE_5 "Tests Pass"                         | **NO**        | RULE_5 says "Code NOT ready until tests pass" — this means "before completion." VERIFY is the point where this is checked. FIX-3 doesn't change RULE_5.                                                                                                                                                                                                                                |
| Autonomy "Single test fails → Fix → retry"  | **POTENTIAL** | `coder.md` autonomy section (line 129-130) says if a single test fails, fix and retry. This implies tests CAN run between parts. But this is an autonomy **continue condition** (what to do IF tests run), not an instruction TO run tests. FIX-3 prevents the situation from occurring. **No conflict** — the continue condition becomes irrelevant if tests don't run between parts. |
| `CLAUDE.md` "Tests fail 3x → STOP_AND_WAIT" | **NO**        | This triggers at VERIFY, not between parts.                                                                                                                                                                                                                                                                                                                                            |

#### 3.3 Edge Cases

| Edge Case                        | Safe?                            | Reason                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| -------------------------------- | -------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **TDD mode**                     | **CRITICAL — MUST BE ADDRESSED** | TDD mode (coder.md Phase 2 `tdd_mode`, line 282-285) says: "Each Part follows RED-GREEN-REFACTOR instead of implement→test." This means tests run INSIDE each Part as the RED phase. FIX-3 says "Do NOT run tests between Parts." **These are different:** TDD runs tests WITHIN a Part, FIX-3 prohibits tests BETWEEN Parts. **BUT** the model might interpret "Do NOT run tests between Parts" as "Do NOT run tests at all during implementation." **This needs clarification in the fix text.** |
| **Session recovery**             | YES                              | Recovery resumes from a phase, not from a per-Part state. If recovery resumes at Phase 2 (IMPLEMENT), the prohibition applies. If at Phase 3 (VERIFY), tests run normally.                                                                                                                                                                                                                                                                                                                         |
| **Compile errors between parts** | YES                              | FIX-3 says LINT catches compile errors. `go vet` / `make lint` runs per part. Only logical errors (which need tests) are deferred to VERIFY.                                                                                                                                                                                                                                                                                                                                                       |
| **Large XL tasks (8+ parts)**    | **MINOR RISK**                   | If a bug introduced in Part 1 propagates to Part 5, it won't be caught until VERIFY. The fix acknowledges this: "logic errors are caught at VERIFY." For XL tasks, this means potentially more rework at VERIFY. **Acceptable trade-off** given the time savings.                                                                                                                                                                                                                                  |

#### 3.4 TDD Mode Conflict — Detailed Analysis

**coder.md lines 282-285:**

```yaml
tdd_mode:
  when: "TDD skill loaded (plan contains ## TDD)"
  behavior: "Each Part follows RED-GREEN-REFACTOR instead of implement→test"
  part_order: "Tests are NOT a separate Part — they are woven into each Part"
```

**FIX-3 proposed text:**
> "Do NOT run tests (make test / go test) between Parts — tests run ONCE at VERIFY phase"

**Conflict analysis:**

- TDD runs `go test` on **specific test files** within a Part (RED: write failing test → GREEN: make it pass)
- FIX-3 prohibits `make test / go test` between Parts
- TDD runs tests **within** a Part, not **between** Parts
- **Technically no conflict**, but the wording is ambiguous

**Recommendation:** Add exception clause: "Exception: TDD mode — if plan contains ## TDD, tests within RED-GREEN-REFACTOR cycles are part of implementation, not verification."

#### 3.5 Graceful Degradation

- **Model ignores the prohibition?** → Tests run more than needed (current behavior). No harm, just wasted time.
- **Model over-applies the prohibition?** → Could skip tests even at VERIFY. BUT Phase 3 VERIFY is a separate explicit instruction: "FMT && LINT" + TEST. FIX-3 note says "This is the ONLY phase where tests run" — reinforces VERIFY, doesn't weaken it.

#### 3.6 Transitive Effects

- **code-reviewer.md** — QUICK CHECK is unaffected (it's a separate agent in worktree)
- **orchestration-core.md** — Phase 3 definition unchanged. VERIFY still required.
- **Autonomy conditions** — "Single test fails → Fix → retry" becomes less likely to trigger during implementation (tests don't run). Still valid at VERIFY.

### Verdict: SAFE WITH TDD CLARIFICATION NEEDED

- **Risk: LOW** — negative instruction, no behavior change for compliant models
- **TDD conflict: Requires explicit exception clause** (see 3.4)
- **Recommendation: Apply with modified text:**

  ```
  Do NOT run tests (make test / go test) between Parts — tests run ONCE at VERIFY phase.
  Exception: TDD mode (plan contains ## TDD) — RED-GREEN-REFACTOR test runs within a Part are implementation, not verification.
  ```

---

## FIX-4: Add `verify_result` to Checkpoint Format

### Artifacts directly modified

| Artifact                 | Change                              |
| ------------------------ | ----------------------------------- |
| `checkpoint-protocol.md` | Add `verify_result` field to format |

### Safety Analysis

#### 4.1 Contract Integrity

**Checkpoint is a persistence format**, not a runtime contract. Changes are inherently low-risk.

- **Writers:** Orchestrator writes checkpoints after each phase (orchestration-core.md)
- **Readers:** Session recovery reads checkpoints (orchestration-core.md session recovery section)
- **New field:** `verify_result: { status, command, timestamp }`

**Writer impact:**

- Orchestrator already writes `handoff_payload` which (after FIX-1) contains `verify_status`
- `verify_result` is a dedicated top-level field — slightly redundant with handoff's verify_status
- Risk: Orchestrator forgets to populate → `null` default → recovery can't use it → falls back to heuristic → **SAFE (current behavior)**

**Reader impact:**

- Session recovery table (orchestration-core.md lines 116-122) has column "Tests pass?"
- Currently: recovery re-runs tests to check this
- With FIX-4: recovery COULD read `verify_result` instead of re-running tests
- BUT: FIX-4 doesn't modify the recovery table or logic — it only adds the field
- **The field exists but isn't consumed** → harmless (additive, no behavior change)

#### 4.2 Rule Conflicts

None. Checkpoint format is not governed by CRITICAL rules.

#### 4.3 Edge Cases

| Edge Case                                          | Safe? | Reason                                                           |
| -------------------------------------------------- | ----- | ---------------------------------------------------------------- |
| **Old checkpoints without verify_result**          | YES   | `null` default. Recovery logic unchanged.                        |
| **Checkpoint written after Phase 2 (plan-review)** | YES   | `verify_result: null` — VERIFY hasn't run yet                    |
| **Re-routing at Phase 3**                          | YES   | verify_result is set when Phase 3 completes, regardless of route |

#### 4.4 Transitive Effects

- **pipeline-metrics.md** — Could benefit from verify_result data but doesn't reference it. No change needed.
- **save-progress-before-compact.sh** — Saves checkpoint data to additionalContext. Automatically includes new fields.
- **save-review-checkpoint.sh** — Writes review completion markers, not full checkpoints. Not affected.

### Verdict: SAFE

- **Risk: VERY LOW** — additive field, null default, no consumer changes
- **Note:** Currently a "dead field" — useful only when session recovery logic is updated to read it (not in scope of current fixes)
- **Recommendation: Apply as-is, but consider if the complexity is justified given it has no consumer yet. Could defer to a future iteration.**

---

## FIX-5: Pass Verify Status in Delegation Instruction

### Artifacts directly modified

| Artifact      | Change                                                           |
| ------------- | ---------------------------------------------------------------- |
| `workflow.md` | Add `optimization` comment to `code_review_delegation.isolation` |

### Safety Analysis

This is a **documentation-only change** — adds a YAML comment explaining the optimization.

#### 5.1 Contract Integrity

No behavioral change. The `isolation` field still says "worktree." The `optimization` is a note for the orchestrator (opus model) to remind it to include verify_status.

#### 5.2 Rule Conflicts

None.

#### 5.3 Edge Cases

None — pure documentation.

#### 5.4 Transitive Effects

None.

### Verdict: SAFE

- **Risk: NONE** — documentation change
- **Recommendation: Apply as-is**

---

## FIX-6: Clarify After-Each-Part vs VERIFY Formatting

### Artifacts directly modified

| Artifact               | Change                                                                            |
| ---------------------- | --------------------------------------------------------------------------------- |
| `coder-rules/SKILL.md` | Step 3: change "run FMT + LINT" to "PostToolUse hooks auto-format. Run LINT only" |

### Safety Analysis

#### 6.1 Contract Integrity

**Current instruction (coder-rules Step 3):**
> "After each Part: run FMT + LINT. Check 5 CRITICAL Rules above continuously."

**Proposed instruction:**
> "After each Part: PostToolUse hooks auto-format files (gofmt). Run LINT only for import/error checks. Do NOT run FMT manually between Parts — hooks handle formatting, VERIFY handles final FMT+LINT."

**Change:** Removes manual `FMT` from per-Part obligation, relies on PostToolUse hooks.

**Risk analysis:**

- PostToolUse hooks fire on `Write|Edit` and run `gofmt` (auto-fmt-go.sh)
- **BUT** PostToolUse hooks run `gofmt` only — NOT `goimports` (see auto-fmt-go.sh line 94-96)
- `make fmt` typically runs `gofmt` + `goimports`
- If coder manually runs `FMT` per part → `goimports` removes unused imports → BUT coder may add imports in later parts → `goimports` would break in-progress code
- `auto-fmt-go.sh` explicitly acknowledges this: "NOT goimports — goimports can remove imports that coder hasn't finished using yet"

**Conclusion:** The proposed change is **consistent with the hook design intent**. Running manual `FMT` per part is actually harmful (goimports may remove in-progress imports). FIX-6 makes the implicit design choice explicit.

#### 6.2 Rule Conflicts

| Rule                                                   | Conflict?   | Analysis                                                                          |
| ------------------------------------------------------ | ----------- | --------------------------------------------------------------------------------- |
| Coder RULE_5 "Tests Pass"                              | No          | Formatting is not testing                                                         |
| `auto-fmt-go.sh` design                                | **Aligned** | Script explicitly says "goimports runs later as part of make fmt in VERIFY phase" |
| `coder.md` Phase 2 "Hooks auto-run formatter + linter" | **Aligned** | FIX-6 makes coder-rules match coder.md's description                              |

**WAIT — `coder.md` Phase 2 says "Hooks auto-run formatter + linter."** But PostToolUse hooks only run formatter (gofmt), not linter. The word "linter" in `coder.md` is misleading. FIX-6's change to coder-rules says "Run LINT only for import/error checks" which means running `make lint` per part. This is consistent with coder.md's (slightly inaccurate) claim that hooks run linter.

**Secondary observation:** If "Run LINT only" means `make lint` per part, this still runs the full linter after each Part. Combined with VERIFY's `make lint`, that's 2x linting for each Part's code. But linting is fast (~2-3s) and catches real issues (import violations). Keeping per-Part LINT is **justified safety**.

#### 6.3 Edge Cases

| Edge Case                     | Safe?    | Reason                                                                                                                                                                                                                |
| ----------------------------- | -------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Hook disabled/unavailable** | **RISK** | If PostToolUse hooks don't fire (e.g., user's settings.local.json overrides), and FIX-6 says "don't run FMT manually," formatting won't happen until VERIFY. **Minor risk** — code will still be formatted at VERIFY. |
| **Non-Go files**              | YES      | auto-fmt-go.sh only processes .go files. Non-Go files are unaffected.                                                                                                                                                 |
| **Generated files**           | YES      | auto-fmt-go.sh skips `*_gen.go`, `*/mocks/*.go`, `*/vendor/*`                                                                                                                                                         |

#### 6.4 Transitive Effects

- **coder.md Phase 2** — `after_each_part` still says "Hooks auto-run formatter + linter." FIX-6 changes coder-rules to match this. Aligned.
- **coder.md Phase 3 VERIFY** — Still runs `make fmt && make lint`. Unchanged.

### Verdict: SAFE

- **Risk: LOW** — aligns coder-rules with existing hook design
- **Minor risk if hooks disabled** — but VERIFY catches this at the end
- **Recommendation: Apply as-is**

---

## Cross-Fix Interaction Analysis

### Dependency Chain

```
FIX-3 (no tests between parts)     FIX-6 (no FMT between parts)
   │ independent                        │ independent
   │                                    │
FIX-1 (verify_status in handoff)  ←── foundation
   │
   ├─→ FIX-2 (conditional QUICK CHECK)  ← depends on FIX-1
   │
   ├─→ FIX-4 (checkpoint verify_result) ← conceptual dependency
   │
   └─→ FIX-5 (documentation)            ← depends on FIX-1
```

### Partial Application Safety

| Applied Subset        | Safe? | Behavior                                                                                    |
| --------------------- | ----- | ------------------------------------------------------------------------------------------- |
| FIX-3 only            | YES   | Coder stops over-testing. Code-reviewer still re-tests (current behavior). Net improvement. |
| FIX-6 only            | YES   | Formatting clarification. No behavioral change if hooks work.                               |
| FIX-1 only            | YES   | Handoff carries verify_status. Code-reviewer ignores it (no FIX-2). Zero impact.            |
| FIX-1 + FIX-2         | YES   | Full QUICK CHECK optimization. Biggest time savings.                                        |
| FIX-3 + FIX-1 + FIX-2 | YES   | Optimal combination. Both root cause clusters addressed.                                    |
| All 6                 | YES   | Full optimization with documentation and checkpoint improvements.                           |

### Conflict Matrix

| Fix   | FIX-1      | FIX-2   | FIX-3         | FIX-4      | FIX-5   | FIX-6         |
| ----- | ---------- | ------- | ------------- | ---------- | ------- | ------------- |
| FIX-1 | —          | Enables | None          | Conceptual | Enables | None          |
| FIX-2 | Requires   | —       | None          | None       | None    | None          |
| FIX-3 | None       | None    | —             | None       | None    | Complementary |
| FIX-4 | Conceptual | None    | None          | —          | None    | None          |
| FIX-5 | Requires   | None    | None          | None       | —       | None          |
| FIX-6 | None       | None    | Complementary | None       | None    | —             |

**No conflicts between any pair of fixes.**

---

## TDD Mode — Cross-Fix Impact

TDD mode is the most sensitive edge case. Analysis across all fixes:

| Fix   | TDD Impact                                                  | Safe?     |
| ----- | ----------------------------------------------------------- | --------- |
| FIX-1 | No impact — VERIFY still runs after all TDD parts           | YES       |
| FIX-2 | No impact — code-reviewer trusts VERIFY, not per-part tests | YES       |
| FIX-3 | **Needs exception clause** — TDD runs tests within parts    | NEEDS FIX |
| FIX-4 | No impact — checkpoint field is additive                    | YES       |
| FIX-5 | No impact — documentation                                   | YES       |
| FIX-6 | No impact — TDD doesn't change formatting                   | YES       |

**Only FIX-3 requires a TDD exception clause.**

---

## Session Recovery — Cross-Fix Impact

Session recovery is the second most sensitive area. Analysis:

| Fix   | Recovery Impact                                                 | Safe? |
| ----- | --------------------------------------------------------------- | ----- |
| FIX-1 | verify_status auto-persisted in checkpoint's handoff_payload    | YES   |
| FIX-2 | Recovery to Phase 4 may lack verify_status → fallback to re-run | YES   |
| FIX-3 | Recovery to Phase 2 (mid-implementation) → no tests to re-run   | YES   |
| FIX-4 | verify_result in checkpoint → recovery can read it (future use) | YES   |
| FIX-5 | Documentation only                                              | YES   |
| FIX-6 | Recovery to Phase 2 → hooks still auto-format                   | YES   |

**All fixes are safe for session recovery.**

---

## Final Safety Verdict

| Fix   | Safety             | Risk Level | Apply?   | Conditions                          |
| ----- | ------------------ | ---------- | -------- | ----------------------------------- |
| FIX-1 | SAFE               | LOW        | YES      | None                                |
| FIX-2 | SAFE with caveat   | MEDIUM     | YES      | Integration test note if applicable |
| FIX-3 | SAFE with TDD fix  | LOW        | YES      | Add TDD exception clause            |
| FIX-4 | SAFE but premature | VERY LOW   | OPTIONAL | No consumer yet — defer?            |
| FIX-5 | SAFE               | NONE       | YES      | None                                |
| FIX-6 | SAFE               | LOW        | YES      | None                                |

### Recommended Application Order (safety-first)

1. **FIX-3** (independent, low risk, immediate user pain relief) + add TDD exception
2. **FIX-6** (independent, clarification only)
3. **FIX-1** (foundation for FIX-2)
4. **FIX-2** (highest impact, depends on FIX-1)
5. **FIX-5** (documentation, depends on FIX-1)
6. **FIX-4** (optional, defer if not needed now)

### Minimum Viable Fix Set

For immediate improvement with minimal risk: **FIX-3 + FIX-1 + FIX-2**

These three fixes address both root cause clusters:

- FIX-3: Stops coder from over-testing during implementation
- FIX-1 + FIX-2: Eliminates redundant re-testing in code-reviewer

Expected time savings: **~120-195 seconds per workflow run** (based on analysis.md estimates)

---

## Appendix: Modified FIX-3 Text (with TDD exception)

### coder.md — Phase 2 `after_each_part`

```yaml
after_each_part:
  - "TodoWrite — mark Part as completed"
  - "Hooks auto-run formatter + linter (SEE: PROJECT-KNOWLEDGE.md)"
  - "Do NOT run tests (make test / go test) between Parts — tests run ONCE at VERIFY phase. Exception: TDD mode (plan ## TDD) — RED-GREEN-REFACTOR test runs within a Part are implementation, not verification."
```

### coder-rules/SKILL.md — Step 3

```
### Step 3: Implement parts in dependency order
Follow lower-layers-first: data access → models → domain → API → tests → wiring.
After each Part: run FMT + LINT. Check 5 CRITICAL Rules above continuously.
IMPORTANT: Do NOT run tests (make test, go test) between Parts. Tests run ONCE at Step 4 VERIFY.
Running tests after each Part wastes time — compile errors are caught by LINT, logic errors are caught at VERIFY.
Exception: If plan contains ## TDD section, RED-GREEN-REFACTOR test runs within a Part are allowed (they are implementation, not verification).
```
