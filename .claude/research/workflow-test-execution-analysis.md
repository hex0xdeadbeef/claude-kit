# Workflow Test Execution Analysis

**Date:** 2026-03-18
**Scope:** Why Code Reviewer gets stuck running tests — root cause analysis
**Complexity:** XL
**Status:** Research complete

---

## 1. Artifact Catalog

All artifacts involved in the Workflow pipeline:

| # | Artifact | Type | Path | Role |
|---|----------|------|------|------|
| 1 | workflow.md | Command | `.claude/commands/workflow.md` | Orchestrator — coordinates full pipeline |
| 2 | planner.md | Command | `.claude/commands/planner.md` | Phase 1 — creates implementation plan |
| 3 | coder.md | Command | `.claude/commands/coder.md` | Phase 3 — implements code per plan |
| 4 | plan-reviewer.md | Agent | `.claude/agents/plan-reviewer.md` | Phase 2 — validates plan |
| 5 | code-reviewer.md | Agent | `.claude/agents/code-reviewer.md` | Phase 4 — reviews code |
| 6 | code-researcher.md | Agent | `.claude/agents/code-researcher.md` | Tool-assist — codebase exploration |
| 7 | orchestration-core.md | Protocol | `.claude/skills/workflow-protocols/orchestration-core.md` | Pipeline phases, loop limits, recovery |
| 8 | handoff-protocol.md | Protocol | `.claude/skills/workflow-protocols/handoff-protocol.md` | 4 phase-to-phase contracts |
| 9 | checkpoint-protocol.md | Protocol | `.claude/skills/workflow-protocols/checkpoint-protocol.md` | State persistence format |
| 10 | autonomy.md | Protocol | `.claude/skills/workflow-protocols/autonomy.md` | Stop/continue conditions |
| 11 | re-routing.md | Protocol | `.claude/skills/workflow-protocols/re-routing.md` | Complexity mismatch handling |
| 12 | pipeline-metrics.md | Protocol | `.claude/skills/workflow-protocols/pipeline-metrics.md` | Completion metrics collection |
| 13 | coder-rules/SKILL.md | Skill | `.claude/skills/coder-rules/SKILL.md` | 5 critical rules, evaluate protocol |
| 14 | code-review-rules/SKILL.md | Skill | `.claude/skills/code-review-rules/SKILL.md` | Severity classification, decision matrix |
| 15 | settings.json | Config | `.claude/settings.json` | Hooks, permissions, MCP servers |
| 16 | CLAUDE.md | Config | `CLAUDE.md` | Language profile, VERIFY/FMT/LINT/TEST commands |
| 17 | plan-template.md | Template | `.claude/templates/plan-template.md` | Plan structure template |
| 18 | auto-fmt-go.sh | Hook Script | `.claude/scripts/auto-fmt-go.sh` | PostToolUse — auto-format Go files |
| 19 | save-review-checkpoint.sh | Hook Script | `.claude/scripts/save-review-checkpoint.sh` | SubagentStop — review completion marker |
| 20 | check-uncommitted.sh | Hook Script | `.claude/scripts/check-uncommitted.sh` | Stop — blocks if uncommitted changes |
| 21 | project-researcher/AGENT.md | Agent | `.claude/agents/project-researcher/AGENT.md` | Generates PROJECT-KNOWLEDGE.md (indirect) |

---

## 2. Interaction Graph

```
                        ┌─────────────────────────────────┐
                        │  /workflow (orchestrator, opus)  │
                        └────────────┬────────────────────┘
                                     │
                    ┌────────────────┼────────────────────┐
                    ▼                ▼                     ▼
             ┌──────────┐    ┌──────────────┐    ┌────────────────┐
             │ /planner  │    │  /coder       │    │  Completion    │
             │  (opus)   │    │  (sonnet)     │    │  (orchestrator)│
             └─────┬─────┘    └──────┬────────┘    └────────────────┘
                   │                 │
          ┌────────┘         ┌───────┴─────────┐
          ▼                  ▼                  ▼
   ┌──────────────┐  ┌──────────────┐  ┌───────────────────┐
   │ plan-reviewer │  │ code-reviewer │  │ code-researcher   │
   │ (sonnet,agent)│  │ (sonnet,agent)│  │ (haiku, Task tool)│
   └──────────────┘  │ isolation:    │  └───────────────────┘
                     │ worktree      │
                     └───────────────┘
```

### Data Flow (Test Execution Path)

```
CLAUDE.md                    settings.json
  │                              │
  │ VERIFY=make fmt &&           │ PostToolUse hooks:
  │   make lint && make test     │   auto-fmt-go.sh (Write|Edit)
  │                              │
  ▼                              ▼
┌─────────────────────────────────────────────────────┐
│ /coder Phase 2: IMPLEMENT PARTS                      │
│                                                       │
│  for each Part:                                       │
│    Write/Edit code                                    │
│      └─→ PostToolUse: auto-fmt-go.sh [gofmt]    ①  │
│    "Hooks auto-run formatter + linter"                │
│    (no explicit test instruction per-part)             │
│                                                       │
│  /coder Phase 3: VERIFY                               │
│    make fmt                                       ②  │
│    make lint                                      ③  │
│    make test                                      ④  │
│                                                       │
│  Output: "Ready for code review"                      │
│  Handoff: NO verify_status / tests_passed field       │
└─────────────────────┬───────────────────────────────┘
                      │
                      ▼ (git commit → delegate to agent)
┌─────────────────────────────────────────────────────┐
│ code-reviewer (in worktree)                          │
│                                                       │
│  QUICK CHECK (blocking):                              │
│    make lint                                      ⑤  │
│    make test                                      ⑥  │
│                                                       │
│  Then: git diff, review, verdict                      │
└─────────────────────────────────────────────────────┘
```

**Key observation:** Steps ②③④ and ⑤⑥ are **identical operations on the same code**. Additionally, step ① runs formatting that step ② will re-run.

### In the User's Actual Session (worse than designed)

The user observed the coder running verification commands **after each individual change**, not just at VERIFY:

```
Part 1 → make check (fmt+lint+test)
Part 2 → make check
Part 3 → make check
Part 4 → go test (separate)
Part 5-6 → go test
deficit addition → go test
mirror tests → go test
final → make check (VERIFY)
code-reviewer → make lint + make test (QUICK CHECK)
```

**Total test runs: ~8-10× instead of 1-2×**

---

## 3. Issues Found

### ISSUE-1: Double Test Execution Between Coder VERIFY and Code-Reviewer QUICK CHECK

**Severity:** HIGH
**Artifacts involved:**
- `coder.md` — Phase 3 VERIFY: `FMT && LINT` + `TEST`
- `code-reviewer.md` — Step 2 QUICK CHECK: `make lint` + `make test`
- `handoff-protocol.md` — `coder_to_code_review` contract: no `verify_status` field
- `orchestration-core.md` — Phase 3 → Phase 4 transition: no state transfer for test results
- `workflow.md` — `code_review_delegation`: no verify_status in `context_to_pass`

**Problem:**
The coder's VERIFY phase runs the complete `make fmt && make lint && make test` suite. The code is then committed. The code-reviewer starts in a worktree and immediately re-runs `make lint` + `make test` as QUICK CHECK. These are **identical operations on identical code** (the worktree reflects the committed state).

**Root cause:**
The `coder_to_code_review` handoff contract in `handoff-protocol.md` includes: `branch`, `parts_implemented`, `evaluate_adjustments`, `risks_mitigated`, `deviations_from_plan`, `iteration` — but **no `verify_status` or `tests_passed` field**. The code-reviewer has no way to know tests already passed. Its RULE_3 ("Tests First: Do NOT start review without LINT && TEST passing") forces re-execution.

**Impact on Project-Researcher:**
The project-researcher generates `PROJECT-KNOWLEDGE.md` which can override `VERIFY`, `TEST`, `FMT`, `LINT` commands. If these commands are heavy (integration tests, database tests), the double-execution overhead is amplified proportionally. The project-researcher itself doesn't run tests, but its output **defines the cost of the redundancy**.

---

### ISSUE-2: No Test Frequency Policy for Coder Implementation Phase

**Severity:** HIGH
**Artifacts involved:**
- `coder.md` — Phase 2 `after_each_part`: "Hooks auto-run formatter + linter" (ambiguous — no explicit test prohibition)
- `coder.md` — Phase 3 VERIFY: full test suite run
- `coder-rules/SKILL.md` — Step 3: "After each Part: run FMT + LINT" (says FMT + LINT, but not TEST)
- `CLAUDE.md` — VERIFY=`make fmt && make lint && make test` (combined command that includes tests)

**Problem:**
While `coder.md` Phase 2 `after_each_part` says "Hooks auto-run formatter + linter" and `coder-rules/SKILL.md` Step 3 says "After each Part: run FMT + LINT", neither explicitly prohibits running tests between parts. The model may interpret `VERIFY` (which includes tests) as the per-part check, or independently decide to "verify progress" by running tests.

The user's session confirmed this: tests ran after nearly every change, not just at VERIFY. The coder has no explicit rule like "Do NOT run `make test` between Parts — tests run ONCE at VERIFY."

**Root cause:**
Missing negative instruction. The artifacts specify *what to do* at VERIFY but not *what NOT to do* between parts. LLMs tend to be conservative — running tests frequently "just to be safe."

**Impact on Project-Researcher:**
If `PROJECT-KNOWLEDGE.md` defines a heavy test suite (e.g., `make test` includes integration tests taking 30+ seconds), the per-part test execution multiplies the overhead. The project-researcher doesn't control test frequency — it only defines the command. The coder artifact is responsible but lacks the guard.

---

### ISSUE-3: Worktree Overhead Compounds Test Redundancy

**Severity:** MEDIUM
**Artifacts involved:**
- `code-reviewer.md` — frontmatter: `isolation: worktree`
- `workflow.md` — `code_review_delegation.isolation`: "worktree — agent sees only committed changes"
- `settings.json` — hooks that fire inside worktree context

**Problem:**
`isolation: worktree` creates a full `git worktree` copy of the repository. This operation itself takes time (especially for large repos with many files). Then inside the worktree, `make lint` + `make test` run — which may need to download dependencies, compile, etc. from a cold state. The worktree doesn't share Go module cache or build cache with the main workspace in all configurations.

**Root cause:**
The worktree isolation is architecturally correct (reviewer gets a clean, unbiased view). But combined with ISSUE-1 (redundant tests), the overhead stacks: worktree creation time + cold-cache test execution.

**Impact on Project-Researcher:**
No direct impact — project-researcher uses `Task` tool subagents (not worktree isolation). However, project-researcher's detection of heavy test suites doesn't trigger any warning about workflow overhead.

---

### ISSUE-4: PostToolUse Formatting Hooks Duplicate VERIFY Formatting

**Severity:** LOW
**Artifacts involved:**
- `settings.json` — PostToolUse hook: `auto-fmt-go.sh` fires on every `Write|Edit`
- `auto-fmt-go.sh` — runs `gofmt -w` on each edited Go file
- `coder.md` — Phase 3 VERIFY: `make fmt` (runs gofmt + goimports on all files)
- `coder-rules/SKILL.md` — Step 3: "After each Part: run FMT + LINT"

**Problem:**
Go files are formatted 3 times:
1. PostToolUse hook runs `gofmt` after each Write/Edit (automatic)
2. Coder runs `FMT` after each Part (per coder-rules)
3. Coder runs `make fmt` at VERIFY phase (final check)

The `auto-fmt-go.sh` script explicitly notes: "NOT goimports — goimports can remove imports that coder hasn't finished using yet. goimports runs later as part of `make fmt` in VERIFY phase." This acknowledges the duplication but frames it as intentional.

**Root cause:**
The hook was designed for real-time formatting feedback, while VERIFY is the authoritative final check. The intermediate `FMT after each Part` is the actual redundancy — it's neither the real-time hook nor the final verify.

**Impact on Project-Researcher:**
None — formatting is fast and project-researcher doesn't edit Go files.

---

### ISSUE-5: Handoff Contract Missing Verification State

**Severity:** HIGH
**Artifacts involved:**
- `handoff-protocol.md` — `coder_to_code_review` contract
- `workflow.md` — `code_review_delegation.context_to_pass`
- `code-reviewer.md` — RULE_3 + QUICK CHECK process
- `orchestration-core.md` — Phase 3 → Phase 4 transition

**Problem:**
The `coder_to_code_review` handoff payload includes:
```yaml
branch: "feature/{name}"
parts_implemented: [...]
evaluate_adjustments: [...]
risks_mitigated: [...]
deviations_from_plan: [...]
iteration: "N/3"
```

Missing: `verify_status`, `tests_passed`, `lint_passed`, `verify_command_used`, `test_output_summary`.

Similarly, `workflow.md`'s `code_review_delegation.context_to_pass` lists:
- Branch
- Coder handoff narrative
- Complexity
- Iteration

But NOT verification status.

**Root cause:**
The handoff protocol was designed for *context* transfer (what was built, what decisions were made) but not for *state* transfer (what checks already passed). This is a contract gap — the assumption is that each phase independently validates, but this leads to redundant work.

**Impact on Project-Researcher:**
The project-researcher's `state-contract.md` includes typed inter-phase state schemas with explicit validation. The workflow's handoff protocol lacks equivalent rigor for verification state. If project-researcher were to generate workflow-aware configuration, it would need to account for this gap.

---

### ISSUE-6: Code-Reviewer QUICK CHECK Has No Skip Mechanism

**Severity:** MEDIUM
**Artifacts involved:**
- `code-reviewer.md` — Step 2 QUICK CHECK: "Run: `make lint` — if FAIL → STOP" + "Run: `make test` — if FAIL → STOP"
- `code-reviewer.md` — RULE_3: "Tests First: Do NOT start review without LINT && TEST passing"
- `code-review-rules/SKILL.md` — Step 1: "Run `make lint` and `make test`. If EITHER fails → STOP"

**Problem:**
QUICK CHECK is unconditional — there's no mechanism to skip or lighten it even when tests are known to pass. The instructions say "Do NOT proceed to review if QUICK CHECK fails" but don't allow "Skip QUICK CHECK if verify_status in handoff is PASSED."

Even if ISSUE-5 were fixed (adding verify_status to handoff), the code-reviewer has no instruction to use it. RULE_3 is absolute: "Do NOT start review without LINT && TEST passing."

**Root cause:**
RULE_3 was designed for safety (never review broken code) but doesn't distinguish between "must verify" and "already verified." The worktree isolation makes this worse — even if the coder verified in the main workspace, the worktree is a different context.

**Impact on Project-Researcher:**
None direct. But the architectural pattern of "unconditional re-verification" is a general anti-pattern that project-researcher could flag when analyzing workflow artifacts.

---

### ISSUE-7: Orchestration-Core Doesn't Track Verify State

**Severity:** MEDIUM
**Artifacts involved:**
- `orchestration-core.md` — Phase 3: "Verify: VERIFY. PASS → Phase 4. FAIL → fix + retry."
- `checkpoint-protocol.md` — Format includes `phase_completed`, `verdict`, `handoff_payload` — but no `verify_result`

**Problem:**
The orchestration core says VERIFY must PASS before Phase 4, but the checkpoint format doesn't record verify results. When Phase 4 starts, the orchestrator has no persisted record that VERIFY passed — it relies on the fact that Phase 3 completed (implicit).

If the session is interrupted between Phase 3 completion and Phase 4 start, the session recovery heuristic (orchestration-core.md) checks "Tests pass?" but this re-runs tests rather than reading a stored result.

**Root cause:**
The checkpoint was designed for phase-level tracking, not for sub-phase state like "verify passed." The session recovery table at line 116-122 even has a column "Tests pass?" — confirming that tests are re-run during recovery rather than read from state.

**Impact on Project-Researcher:**
None direct.

---

### ISSUE-8: Coder VERIFY vs Coder-Rules After-Each-Part Ambiguity

**Severity:** LOW
**Artifacts involved:**
- `coder.md` — Phase 2 `after_each_part`: "Hooks auto-run formatter + linter"
- `coder-rules/SKILL.md` — Step 3: "After each Part: run FMT + LINT. Check 5 CRITICAL Rules above continuously."
- `coder.md` — Phase 3 VERIFY: `FMT && LINT` (again)

**Problem:**
`coder-rules/SKILL.md` says "After each Part: run FMT + LINT" explicitly. But `coder.md` Phase 2 says "Hooks auto-run formatter + linter" (referring to PostToolUse hooks that already handle formatting). Then Phase 3 runs `FMT && LINT` again.

This creates three layers:
1. PostToolUse hooks → per-file formatting (automatic, unavoidable)
2. After-each-Part → FMT + LINT per coder-rules (manual, per-part)
3. VERIFY → FMT + LINT as final check (manual, once)

Layer 2 is the ambiguous one — it overlaps with both Layer 1 (formatting already done) and Layer 3 (will be re-done).

**Root cause:**
Layer 2 was added for "continuous checking" safety, but its value is marginal given Layers 1 and 3 exist.

---

## 4. Issue Interaction Map

```
ISSUE-5 (no verify_status in handoff)
   │
   ├──→ enables ISSUE-1 (double test execution)
   │         │
   │         └──→ amplified by ISSUE-3 (worktree overhead)
   │
   └──→ enables ISSUE-6 (no skip mechanism in QUICK CHECK)
               │
               └──→ related to ISSUE-7 (no verify state in checkpoint)

ISSUE-2 (no test frequency policy)
   │
   └──→ independent root cause of over-testing in coder phase
         amplified by ISSUE-4 (PostToolUse formatting redundancy)
         amplified by ISSUE-8 (after-each-part ambiguity)
```

**Two root cause clusters:**
1. **Handoff gap cluster** (ISSUE-5 → ISSUE-1, ISSUE-3, ISSUE-6, ISSUE-7): The handoff protocol doesn't transfer verification state, causing redundant re-verification.
2. **Test policy gap cluster** (ISSUE-2, ISSUE-4, ISSUE-8): No explicit "when to test" policy causes over-testing during implementation.

---

## 5. Quantified Impact

Assuming a typical M/L Go project with ~100 tests taking ~15 seconds:

| Execution Point | Count | Cost |
|-----------------|-------|------|
| PostToolUse gofmt (per edit) | ~20-40× | ~0.5s each = 10-20s total |
| FMT+LINT after each Part (5 parts avg) | 5× | ~5s each = 25s total |
| Coder VERIFY (make fmt+lint+test) | 1× | ~20s |
| Worktree creation | 1× | ~5-15s |
| Code-Reviewer QUICK CHECK (lint+test) | 1× | ~20s |
| **Mid-part test runs (ISSUE-2, observed)** | **~5-8×** | **~15s each = 75-120s** |

**Total overhead from redundancy: ~120-195 seconds per workflow run**
**If tests are slow (integration, DB): multiply by 3-5×**

The user's specific complaint ("бесконечно запускал тесты") aligns with the worst case: heavy test suite + per-part test runs + final VERIFY + QUICK CHECK.

---

## 6. Summary

The Code Reviewer "getting stuck on tests" has **two independent root causes**:

1. **The coder over-tests during implementation** (ISSUE-2) — no explicit policy prevents running tests after every change, only at VERIFY.

2. **The code-reviewer redundantly re-tests after coder already verified** (ISSUE-1, ISSUE-5, ISSUE-6) — the handoff protocol doesn't communicate that tests passed, and the code-reviewer has no mechanism to skip QUICK CHECK.

Both are amplified by **worktree cold-cache overhead** (ISSUE-3) and **formatting redundancy** (ISSUE-4, ISSUE-8).

The fix requires changes to: `handoff-protocol.md`, `coder.md`, `code-reviewer.md`, `coder-rules/SKILL.md`, and `orchestration-core.md`.
