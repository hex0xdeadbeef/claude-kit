---
name: issues-catalog
description: Catalog of recurring issue types found across plan reviews
type: project
---

# Issues Catalog

## Cascade-miss (MAJOR pattern)
**Type:** Completeness — fix applied to primary file but mirror location missed
**Seen in:** fix-problematic-workflow-issues.md (iteration 1 + 2)

Iteration 1:

- Part 4 (M-4): planner-rules/SKILL.md line 50 fixed but line 92 still says MANDATORY
- Part 5 (N-3): autonomy.md MINIMAL removed but workflow.md line 83 MINIMAL still present

Iteration 2:

- Part 7 (N-10): planner + coder checklists fixed for bd sync, but plan-review-rules/checklist.md:34 and code-review-rules/checklist.md:29 missed
- Part 5 (N-3): autonomy.md + commands/workflow.md fixed, but README.md lines 44, 52, 162 still reference /workflow --minimal

Iteration 3:

- Part 5 (N-3): Plan adds autonomy.md + workflow.md line 83 fixes, but still misses:
  - README.md lines 44, 52, 162 (user-facing docs with /workflow --minimal) — MAJOR
  - workflow-protocols/SKILL.md line 86 ("4 modes ... MINIMAL") — MINOR
  - code-researcher.md line 36 (MINIMAL → always skip) — MINOR
- Part 7 (N-10): Plan adds planner + coder checklist fixes, but still misses:
  - plan-review-rules/checklist.md line 34 ("bd sync executed") — MAJOR
  - code-review-rules/checklist.md line 29 ("bd sync executed (if beads)") — MINOR
- Part 4 (M-4): Plan fixes SKILL.md lines 50+92, but misses:
  - planner-rules/troubleshooting.md line 11 ("STARTUP phase is MANDATORY") — MINOR

**Why:** Planner searches for the problem in the primary file but doesn't search ALL files for the same string.
**How to apply:** When reviewing a fix, grep the target string across the ENTIRE repo (not just .claude/) to find all locations. Especially watch README.md for user-facing docs that mirror internal doc content.

## Research/Documentation plan review patterns (2026-03-14): meta-agent-research

**Plan type:** XL research task (read-only analysis, no Go code)
**Verdict:** APPROVED (0 blocker, 0 major, 3 minor)

Key patterns:

- For documentation plans, import matrix / clean domain checks are N/A — focus on issue accuracy + completeness
- Accepted issues list should be verified against actual files (spot-check at least critical + 3-4 major issues)
- Cascade-miss risk is HIGH for rename-type issues (e.g., CRITIQUE→CONSTITUTE) — must grep ALL files
- Research plans often lack formal Acceptance Criteria sections — flag as MINOR
- Sequential Thinking not required for research plans even at XL — the complexity is in the subject domain, not the plan execution layers

## Impact-review plan (2026-03-14): meta-agent-impact-review

**Plan type:** M review/audit task (no code changes — verifies doc fixes don't break behavior)
**Verdict:** APPROVED with notes (0 blocker, 0 major, 4 minor)

Key patterns for future reviews of this type:

- For documentation impact reviews, check that gate recovery_strategies sections are updated when new gates are promoted to first-class (FIX-08 omission)
- Script guard conditions should be verified directly by reading the script, not just trusting the fix doc description (FIX-03: actual guard is `.claude/` path check, not `.meta-agent/runs/` as implied)
- CRITIQUE→CONSTITUTE cascade check: artifact-constitution.md line 9 (`replaces: "Ad-hoc CRITIQUE phase questions"`) is a defensible historical reference — intentional, not a miss
- Runtime change fixes (FIX-03, FIX-04) benefit from explicit rollback instructions; their absence is MINOR not MAJOR for doc-only plans
- FIX-17 completeness claim "Last remaining CRITIQUE reference" is inaccurate — line 9 still exists in same file but is intentional

## Final-review verification (2026-03-14): Groups G-L

Fixes reviewed against actual files. Issues found:

### SAFE fixes (applied as-is): N-8, N-5, N-7, N-10, m-2, N-9, N-11, m-3, m-4

### NEEDS_CHANGES — 3 minor issues

- N-3: workflow.md line 230 `skip_when: "S/M complexity, --minimal mode"` — needs "planner mode" qualifier after MINIMAL removed as workflow mode
- N-12: Conditional YAML comment for Phase 0 is ambiguous — Phase 0 is always completed by step 1, so always mark completed
- M-3 (hooks note): claims "11 scripts" but README shows 13 scripts — introduces new inaccuracy

### Cascade miss NOT in fixes report — MAJOR

Fix N-6 (base branch hardcoding) was revised with 2 cascade targets (code-reviewer.md GET CHANGES + Error Handling).
Two additional locations still have hardcoded `git diff master...HEAD`:

1. `.claude/skills/code-review-rules/SKILL.md` line 32 — loaded at agent startup
2. `.claude/skills/workflow-protocols/orchestration-core.md` line 97 — used by workflow orchestrator session recovery

These are significant: SKILL.md is loaded at code-reviewer startup (contradicts updated agent instructions), and orchestration-core session recovery fails silently on non-master repos.
