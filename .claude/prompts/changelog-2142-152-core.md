---
feature: changelog-2142-152-core
status: pending_review
complexity: XL
task_type: config_change
research_artifact: .claude/prompts/changelog-2121-2152-workflow-analysis.md
prior_research_used: .claude/prompts/changelog-2121-2152-workflow-analysis.md
created: 2026-05-27
iteration: 1
sequential_thinking_used: true
alternatives_considered: 3
---

# Task: Changelog 2.1.142–152 core uplift (I-01..I-05)

## Context

Continuation of the kit's Claude Code changelog uplift. The prior run
(`changelog-v2.1.121-141-uplift`, commits `ac6deca`/`4e69f5f`) shipped 2.1.121–141.
The research artifact
[`changelog-2121-2152-workflow-analysis.md`](.claude/prompts/changelog-2121-2152-workflow-analysis.md)
analysed `2.1.142 → 2.1.152` (plus 121–141 items the prior 6 clusters missed) and
selected 10 improvements. The user approved the **Core P0+P1 subset (I-01..I-05)** for
this PR; I-06..I-10 (P2 docs/UX/DiD) are deferred to a follow-up.

This is a **kit-infrastructure** change (`.claude/` scripts/commands/skills + `CLAUDE.md` +
`settings.json`). It does not touch Go `internal/**` layers, so layer-allocation / import-matrix
checks are N/A (plan-reviewer SKIPs them — canonical SKIP, no `internal/**/*.go` in diff).

**Standing constraints (load-bearing):** 0 inter-phase contract changes; 0 new env vars
(`feedback_env_vars_restraint`, 2026-05-22); TDD RGR per Part; baseline 75/75 tests stays green.

## Scope

**In scope (exactly 5 improvements):**
- **I-01** (P0, correctness): reconcile Phase 2.5 SIMPLIFY with the `/simplify` →
  `/code-review --fix` churn (removed @2.1.147, restored as alias @2.1.152).
- **I-02** (P1, regression-prevention): document + invariant-lock `STOP_BLOCK_MAX < 8`
  against the platform's `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP` (default 8, @2.1.143).
- **I-03** (P1, edge correctness): `notify-workflow-complete.sh` reads Stop-payload
  `background_tasks` (@2.1.145) and suppresses emission when non-empty.
- **I-04** (P1, robustness): defensive `subagent_type` normalization in
  `save-review-checkpoint.sh` agent-type resolution (@2.1.140).
- **I-05** (P1, cost): `skillOverrides: name-only` for 8 internal-only skills (@2.1.129).

**Out of scope:**
- I-06..I-10 (deferred follow-up) — reason: P2 tier; user selected core P0+P1.
- Any change to `handoff.schema.json`, the VERDICT/VERDICT_JSON envelope, or the
  canonical-ID hash input — reason: hard contract-preservation requirement.
- Any new `CLAUDE_*` env var or `settings.local.json.example` entry — reason: env-var restraint.
- Changing `STOP_BLOCK_MAX`'s value (stays 5) — reason: I-02 is an invariant lock, not a retune.
- The unrelated `docs/slides/claude-kit-workflow.html` working-tree deletion — reason: not ours;
  must NOT be staged (commit stages only the files in `## Files Summary`).

## Architecture Decision

**Chosen approach.** Five surgical, additive edits — each independently revertable, each
backed by ≥1 new test, none touching an inter-phase contract. Sequential Thinking was used
in the research phase (10→5 selection + false-positive/contract pressure-test, 5 thoughts).

**Per-item approach + key alternative rejected:**

1. **I-01.** Make Phase 2.5 `step_2` version-robust (graceful skip → `simplify_applied: skipped`
   when `/simplify` absent on 2.1.147–2.1.151) and recalibrate the purpose/guard prose to the
   new `/code-review --fix` semantics (now applies reuse/simplification/efficiency + minor
   correctness fixes, not just NIT/MINOR). *Alternative rejected:* bump the global version floor
   to `>= 2.1.152` — rejected because it would force ALL kit users to upgrade for a single
   optional sub-phase; graceful degradation is strictly less disruptive.
2. **I-02.** Add an invariant comment in `check-uncommitted.sh` + doc note; assert
   `STOP_BLOCK_MAX < 8` via test. *Alternative rejected:* adopt `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`
   as a kit-set env var — rejected per env-var restraint AND because our breaker (5) is already
   correctly below the platform default (8); we design under the default, not against it.
3. **I-03.** Best-effort drain stdin in `notify-workflow-complete.sh`; suppress when
   `background_tasks` length > 0. *Alternative rejected:* gate on `session_crons` too — rejected
   because crons are our own auto-checkpoint (expected during a run); only `background_tasks`
   indicates genuinely-pending work.
4. **I-04.** Normalize `agent_type` → canonical form for the comparison/resolution path only;
   keep `agent_raw` = raw payload value. *Alternative rejected:* normalize at every comparison
   site — rejected as more error-prone than a single normalized `effective_agent_type` assignment
   that is identity-stable on already-canonical inputs.
5. **I-05.** `skillOverrides: "name-only"` for the 8 internal skills; never `off`; never list
   user-invocable skills. *Alternative rejected:* `user-invocable-only` — rejected because it
   hides skills from the model entirely, which could interfere with command-driven Skill-tool
   loading; `name-only` only collapses the description and preserves invocation.

**Contract-Safety Audit (reproduced from research doc §10 — load-bearing).**
None of the 5 items touches the protected surface. Protected entities: 4 handoff discriminators
(`planner_to_plan_review`, `plan_review_to_coder`, `coder_to_code_review`,
`code_review_to_completion`), 2 verdict discriminators (`plan_review_verdict`,
`code_review_verdict`), the `VERDICT:`/`VERDICT_JSON:` envelope, and the canonical-ID hash
input `sha256(category|location|problem)`. See `## Contract Preservation Analysis`.

## Tests

Baseline at branch HEAD: **75 test files PASS** (includes the `test-protect-files.sh` write-lock
hotfix already in the working tree). Target after this PR: **80** (+5).

| ID | Test | What it asserts | Part | New/Existing | Cum. count |
|---|---|---|---|---|---|
| T1 | `test-simplify-semantics-doc.sh` | `coder.md` Phase 2.5 `step_2` contains a graceful-skip branch and `simplify_applied: skipped`; `coder.md`+`workflow.md`+`orchestration-core.md` all reference `/code-review --fix` identity; `CLAUDE.md` Soft Prereq names `>= 2.1.152` for SIMPLIFY. Fails if any of the 4 files is out of sync. | 1 | NEW | 76 |
| T2 | `test-stop-block-cap-invariant.sh` | Extracts `STOP_BLOCK_MAX` from `check-uncommitted.sh`; asserts it is numeric AND `< 8`. Asserts an invariant comment referencing `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP` is present. Fails if `STOP_BLOCK_MAX >= 8` or comment missing. | 2 | NEW | 77 |
| T3 | `test-notify-background-tasks-suppress.sh` | With `CLAUDE_KIT_PHASE_COMPLETION_NOTIFY=on` + a phase-5 APPROVED checkpoint: empty/absent `background_tasks` → `terminalSequence` emitted; non-empty `background_tasks` → NO emission, exit 0. | 2 | NEW | 78 |
| T4 | `test-subagent-type-normalize.sh` | Payloads `"Code Reviewer"`, `"code_reviewer"`, `"PLAN-REVIEWER"` resolve to canonical `effective_agent_type`; canonical `"code-reviewer"`/`"plan-reviewer"` produce byte-identical marker fields (`agent`, `agent_raw`, `effective_agent_type`, `verdict_source`) to pre-change output. | 3 | NEW | 79 |
| T5 | `test-skilloverrides-internal-name-only.sh` | `settings.json` `skillOverrides` marks the 8 internal skills `name-only`; asserts NO skill is `off`; asserts no user-invocable skill (`workflow`,`planner`,`coder`,`designer`,`meta-agent`,`project-researcher`) appears in the block. | 4 | NEW | 80 |
| EX-1 | `test-stop-circuit-breaker.sh` (existing) | Still PASS — I-02 adds only a comment + invariant test; `STOP_BLOCK_MAX=5` value and block payload unchanged. | 2 | regression watch | — |
| EX-2 | `test-notify-workflow-complete-allowlist.sh` + `-default-off.sh` + `-needs-changes.sh` (existing) | Still PASS — I-03 adds a pre-emission suppress gate; allowlist + default-OFF behaviour unchanged. | 2 | regression watch | — |
| EX-3 | `test-subagent-stop-backfill-agent-type.sh` + `test-canonical-id-normalization.sh` (existing) | Still PASS — proves I-04 normalization does NOT alter canonical-ID hashing or backfill on canonical inputs. | 3 | regression watch | — |
| EX-4 | `test-hook-stderr-format.sh` + `test-hooks-exec-form.sh` + `test-hook-args-positional.sh` (existing) | Still PASS — settings.json edit (I-05) preserves exec-form `args` on all hooks; any new stderr follows kit convention. | 4 | regression watch | — |
| EX-5 | `test-protect-files.sh` (hotfix, in tree) | Still PASS — untouched by this PR. | — | regression watch | — |
| EX-6 | Full kit suite | All 75 existing + 5 new = **80** PASS, `rc=0`. | all | regression watch | 80 |

## Acceptance Criteria

Reproduced byte-for-byte falsifiable from research doc §6 (per-item AC), plus cross-cutting.

**I-01 (SIMPLIFY reconciliation):**
- **AC-1.1.** `coder.md` Phase 2.5 `step_2` contains a graceful-skip branch that sets
  `simplify_applied: skipped` when `/simplify` is unavailable (v2.1.147–2.1.151).
- **AC-1.2.** `coder.md` purpose + `workflow.md` `simplify_note` + `orchestration-core.md`
  mermaid SMP node all reference the `/simplify == /code-review --fix` identity.
- **AC-1.3.** `CLAUDE.md` Soft Prerequisites states the SIMPLIFY sub-phase needs `>= 2.1.152`
  for native `/simplify`, with graceful degradation below.
- **AC-1.4.** `coder_to_code_review` handoff still accepts `simplify_applied: skipped` (already
  legal per `coder.md` Phase 2.5 `step_4`) — no schema change.

**I-02 (Stop-block-cap invariant):**
- **AC-2.1.** `check-uncommitted.sh` retains `STOP_BLOCK_MAX=5` (value unchanged) with a new
  comment stating it MUST stay `<` platform `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP` (default 8).
- **AC-2.2.** `CLAUDE.md` documents the `5 < 8` interaction and that the kit does NOT set
  `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP` (env-restraint; designed under the platform default).
- **AC-2.3.** `test-stop-block-cap-invariant.sh` fails if `STOP_BLOCK_MAX >= 8`.
- **AC-2.4.** No new env var; block payload byte-stable (existing `test-stop-circuit-breaker.sh` PASS).

**I-03 (notify background_tasks-aware):**
- **AC-3.1.** notify stays default-OFF (`CLAUDE_KIT_PHASE_COMPLETION_NOTIFY` gate unchanged).
- **AC-3.2.** `on` + phase-5 + APPROVED + `background_tasks == []`/absent → `terminalSequence` emitted.
- **AC-3.3.** `on` + phase-5 + APPROVED + `background_tasks` non-empty → no emission, exit 0.
- **AC-3.4.** OSC-9/BEL allowlist unchanged (`test-notify-workflow-complete-allowlist.sh` PASS).

**I-04 (subagent_type normalization):**
- **AC-4.1.** `_normalize_agent_type` applied to the agent-type resolution path; `"Code Reviewer"`,
  `"code_reviewer"`, `"PLAN-REVIEWER"` resolve to the canonical agent.
- **AC-4.2.** For already-canonical inputs, marker fields (`agent`, `agent_raw`,
  `effective_agent_type`, `verdict_source`, `canonical_issue_ids`) are byte-identical to pre-change.
- **AC-4.3.** `agent_type` is NOT in the canonical-ID hash; `test-canonical-id-normalization.sh`
  + `test-subagent-stop-backfill-agent-type.sh` PASS unchanged.

**I-05 (skillOverrides name-only):**
- **AC-5.1.** `settings.json` `skillOverrides` = `name-only` for the 8 internal skills.
- **AC-5.2.** NO skill mapped to `off`; NO user-invocable skill in the block.
- **AC-5.3.** Coder confirms the exact `skillOverrides` JSON shape against Claude Code docs
  (context7 / claude-code-guide) BEFORE writing — see Part 4 NEEDS_VALIDATION note.

**Cross-cutting:**
- **AC-X.1 (Contracts).** `git diff` shows zero changes to `.claude/schemas/handoff.schema.json`
  and zero changes to any VERDICT/VERDICT_JSON-emitting prose. See `## Contract Preservation Analysis`.
- **AC-X.2 (Env vars).** Zero new `CLAUDE_*` env vars; zero new `settings.local.json.example` entries;
  zero new lines in `CLAUDE.md` § "Strict-mode env vars".
- **AC-X.3 (Caveman boundaries).** `VERDICT:`, `VERDICT_JSON:`, the 5 H2 headers in this plan,
  file paths, and `file:line` references preserved verbatim.
- **AC-X.4 (Tests).** 80/80 PASS via `rc=0; for f in .claude/scripts/tests/test-*.sh; do bash "$f" || rc=1; done; exit $rc`.
- **AC-X.5 (No stray deletion).** Commit does NOT include `docs/slides/claude-kit-workflow.html`.

## Parts

Strict-serial execution. Each Part is RED→GREEN→REFACTOR (write the failing test first).

### Part 1: I-01 — SIMPLIFY ↔ `/code-review --fix` reconciliation

- **Files:** `.claude/commands/coder.md` (UPDATE), `.claude/commands/workflow.md` (UPDATE),
  `.claude/skills/workflow-protocols/orchestration-core.md` (UPDATE), `CLAUDE.md` (UPDATE),
  `.claude/scripts/tests/test-simplify-semantics-doc.sh` (CREATE).
- **coder.md Phase 2.5 (`phase: 2.5`, ~lines 461-477):**
  - `purpose`: append — "On v2.1.152+ `/simplify` is an alias for `/code-review --fix`, which
    applies reuse/simplification/efficiency and minor correctness fixes (broader than NIT/MINOR-only)."
  - `step_2`: "Run /simplify on changed files" → "Run `/simplify` on changed files (on Claude Code
    v2.1.152+ this is identical to `/code-review --fix`). If `/simplify` is unavailable (v2.1.147–
    2.1.151, where it was renamed to `/code-review` without the alias), SKIP gracefully: set
    `simplify_applied: skipped` and record `simplify skipped — /simplify unavailable on this version`."
  - `guard.note`: append — "Under the v2.1.152 `/code-review --fix` semantics the guard also bounds
    correctness-fix-driven diff expansion, not just stylistic restructuring."
- **workflow.md `simplify_note` (~line 246-250):** "Runs /simplify on changed files to eliminate
  NIT/MINOR issues before code-review." → "Runs `/simplify` (= `/code-review --fix` on v2.1.152+)
  on changed files to apply low-risk reuse/simplification/efficiency (and minor correctness) fixes
  before code-review; skips gracefully (`simplify_applied: skipped`) if `/simplify` is unavailable."
- **orchestration-core.md mermaid (~line 32):** `SMP[/simplify]` → `SMP["/simplify = /code-review --fix"]`
  (quote the label so the `=` and slash are mermaid-safe; verify mermaid still renders).
- **CLAUDE.md Soft Prerequisites:** add one sentence after the version-floor paragraph — "The
  optional Phase 2.5 SIMPLIFY sub-phase invokes `/simplify`, which Claude Code v2.1.152 restored
  as an alias for `/code-review --fix` (it was renamed to `/code-review` without an alias in
  v2.1.147). On v2.1.147–2.1.151 `/coder` degrades gracefully (skips SIMPLIFY, `simplify_applied:
  skipped`); native SIMPLIFY needs `>= 2.1.152`. This does not raise the kit's `>= 2.1.141` floor."
- **TEST (RED first):** `test-simplify-semantics-doc.sh` grep-asserts AC-1.1, AC-1.2, AC-1.3 across
  the 4 files; FAILS before edits, PASSES after.

### Part 2: I-02 + I-03 — Stop-hook plane

- **Files:** `.claude/scripts/check-uncommitted.sh` (UPDATE), `.claude/scripts/notify-workflow-complete.sh`
  (UPDATE), `CLAUDE.md` (UPDATE), `.claude/scripts/tests/test-stop-block-cap-invariant.sh` (CREATE),
  `.claude/scripts/tests/test-notify-background-tasks-suppress.sh` (CREATE).

**I-02 (check-uncommitted.sh, ~line 12-14):** keep `STOP_BLOCK_MAX=5`; expand the comment:
```bash
# P3: hard-coded breaker threshold (no env var per user direction 2026-05-22).
# I-02 INVARIANT: STOP_BLOCK_MAX MUST stay < the platform's stop-hook block cap
# (CLAUDE_CODE_STOP_HOOK_BLOCK_CAP, default 8 since Claude Code v2.1.143). Our
# breaker must fire FIRST and save state, before the platform force-ends the turn
# mid-block. The kit deliberately does NOT set CLAUDE_CODE_STOP_HOOK_BLOCK_CAP
# (env-restraint) — it designs under the platform default. To tune, edit this line.
STOP_BLOCK_MAX=5
```
`CLAUDE.md` Error Handling (or the Stop note): add a sentence on the `5 < 8` relationship.

**I-03 (notify-workflow-complete.sh):** after the env gate (`CLAUDE_KIT_PHASE_COMPLETION_NOTIFY`
check) and BEFORE the jq emission, drain stdin and suppress on pending background tasks:
```bash
# I-03: read the Stop payload (v2.1.145+ includes background_tasks). Suppress the
# "workflow complete" notification while genuine background work is still running
# (e.g. a backgrounded code-researcher) — firing now would be premature.
STOP_INPUT="$(cat 2>/dev/null || echo "")"
if [[ -n "${STOP_INPUT}" ]] && command -v jq >/dev/null 2>&1; then
  bg_count="$(printf '%s' "${STOP_INPUT}" | jq -r '(.background_tasks // []) | length' 2>/dev/null || echo 0)"
  case "${bg_count}" in ''|*[!0-9]*) bg_count=0 ;; esac
  if [[ "${bg_count}" -gt 0 ]]; then exit 0; fi
fi
```
(PR-002 fix: keep the env-gate-first ordering. On the default-OFF path the script exits 0 immediately
without draining stdin — harmless, since each Stop hook receives its own stdin copy and the process
exits at once. The drain only needs to precede the jq emission on the `on` path; mirror
`check-uncommitted.sh:20` best-effort pattern. `session_crons` is intentionally NOT gated on — it is
our own auto-checkpoint cron, expected during a run.)

- **TESTS (RED first):** `test-stop-block-cap-invariant.sh` (extract+assert `<8` + comment present);
  `test-notify-background-tasks-suppress.sh` (sandbox `CLAUDE_WORKFLOW_STATE_DIR` + phase-5 APPROVED
  checkpoint fixture; assert emit vs suppress on empty/non-empty `background_tasks`).

### Part 3: I-04 — defensive `subagent_type` normalization

- **Files:** `.claude/scripts/save-review-checkpoint.sh` (UPDATE),
  `.claude/skills/workflow-protocols/delegation-templates.md` (UPDATE),
  `.claude/scripts/tests/test-subagent-type-normalize.sh` (CREATE).
- **save-review-checkpoint.sh:** add the helper near the top of the Python block, then normalize
  ONLY the resolution path (preserve `agent_type` raw for `agent_raw`):
```python
def _normalize_agent_type(s):
    # I-04: platform v2.1.140 normalizes Agent-tool subagent_type (case/separator-insensitive).
    # Harden our payload-side compare the same way. agent_type is NOT part of the canonical-ID
    # hash (sha256(category|location|problem)), so this cannot affect issue-ID byte-stability.
    if not s:
        return s
    return s.strip().lower().replace(" ", "-").replace("_", "-")
```
  Change `effective_agent_type = agent_type` (current ~line 136) →
  `effective_agent_type = _normalize_agent_type(agent_type)`. The `== "unknown"`/empty checks still
  hold (`_normalize_agent_type("unknown") == "unknown"`, `_normalize_agent_type("") == ""`). Marker
  `agent_raw` keeps `agent_type` (raw); for canonical inputs every marker field is byte-identical.
- **delegation-templates.md:** add a note — platform normalizes the delegation input; the kit
  additionally normalizes the SubagentStop payload compare as defense-in-depth.
- **TEST (RED first):** `test-subagent-type-normalize.sh` — feed `_HOOK_INPUT` payloads via the
  same harness `save-review-checkpoint.sh` uses; assert canonical resolution for variant casing AND
  byte-stable marker fields for canonical inputs (sandbox `CLAUDE_WORKFLOW_STATE_DIR`).
- **NEEDS_VALIDATION (PR-003):** confirm the benign edge — for non-canonical NON-empty inputs the
  post-normalization condition `effective_agent_type != agent_type` makes BOTH the P1-2 registry
  backfill (`save-review-checkpoint.sh:157`, appends a `SubagentStop-backfill` entry) AND the P2-2
  anomaly line (line 177) reachable. Acceptable: non-canonical inputs do not occur in practice
  (canonical delegation + platform v2.1.140 normalization), both paths are try/except NON_CRITICAL
  and self-healing, and no marker field / verdict / contract is affected. Verify byte-stability on
  the existing canonical Scenario-B case before relying on EX-3. Documented in `## Risks & Mitigations`.

### Part 4: I-05 — `skillOverrides: name-only` for internal skills

- **Files:** `.claude/settings.json` (UPDATE), `.claude/scripts/tests/test-skilloverrides-internal-name-only.sh` (CREATE).
- **NEEDS_VALIDATION (do FIRST):** confirm the exact `skillOverrides` JSON shape (map vs array;
  key = skill `name` vs directory) via Claude Code docs (context7 `resolve-library-id` →
  `query-docs`, or claude-code-guide). Implement the confirmed shape.
- **settings.json:** add `skillOverrides` mapping the 8 internal skills to `"name-only"`:
  `workflow-protocols`, `planner-rules`, `coder-rules`, `plan-review-rules`, `code-review-rules`,
  `design-rules`, `systematic-debugging`, `tdd-rules`. Do NOT include user-invocable skills
  (`workflow`, `planner`, `coder`, `designer`, `meta-agent`, `project-researcher`). Never `off`.
- **TEST (RED first):** `test-skilloverrides-internal-name-only.sh` — `jq`-assert: every internal
  skill present = `name-only`; no value == `off`; no user-invocable skill key present.
- **Smoke (manual, documented):** confirm `/coder` still loads `coder-rules` via Skill tool after
  the change (invocation preserved under `name-only`).

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| I-05 `skillOverrides` shape wrong → setting ignored | Med | Low (no contract impact; just no token saving) | Part 4 NEEDS_VALIDATION step: confirm shape via docs first; test asserts our chosen invariants. |
| I-05 accidental `off` → model can't load skill | Low | High | Hard AC-5.2 + test asserts no `off`; user-invocable skills excluded. |
| I-04 non-canonical input triggers NON_CRITICAL P1-2 backfill (save-review-checkpoint.sh:157) + P2-2 anomaly (line 177) | Low | Low | Both NON_CRITICAL/self-healing; non-canonical inputs don't occur (canonical delegation + platform normalize); no marker field, verdict, or contract affected. |
| I-04 normalization alters a marker field on canonical input | Very Low | High | `_normalize_agent_type` is identity on canonical inputs; T4 + EX-3 assert byte-stability. |
| I-03 stdin drain changes early-exit timing | Low | Low | Best-effort `cat 2>/dev/null` (mirrors check-uncommitted.sh:20); drained after env gate so default-OFF path is untouched. |
| I-01 graceful-skip masks a real `/simplify` breakage | Low | Low | Skip sets `simplify_applied: skipped` + handoff note — visible to reviewer/transcript. |
| mermaid label edit (I-01) breaks diagram render | Low | Low | Quote the node label; visually confirm render in orchestration-core.md. |
| Commit accidentally includes docs/slides deletion | Low | Med | AC-X.5 + Implementation Order step: stage ONLY `## Files Summary` paths with `git add -f`; never `git add -A`. |

## Contract Preservation Analysis

| Contract / boundary | Affected? | Why preserved |
|---|---|---|
| `planner_to_plan_review` | No | No planner-handoff producer touched. |
| `plan_review_to_coder` | No | No plan-review-handoff producer touched. |
| `coder_to_code_review` | No | I-01 keeps `simplify_applied` field (value `skipped` already legal); no schema change. |
| `code_review_to_completion` | No | No code-review-handoff producer touched. |
| `plan_review_verdict` / `code_review_verdict` | No | I-04 touches agent-type resolution only; verdict extraction + `$verdict_contract` untouched. |
| Canonical-ID hash `sha256(category\|location\|problem)` | No | I-04 normalizes `agent_type`, which is NOT a hash input. EX-3 proves it. |
| VERDICT / VERDICT_JSON envelope | No | No agent prose / verdict-emission edited. |
| `handoff.schema.json` (v1.2.0) | No | `git diff` shows zero changes (AC-X.1). |
| Caveman boundaries (1–7) | No | Plan H2 headers, file paths, file:line refs verbatim; no fragment in JSON-bound text. |
| Stop hook output protocol | Tolerantly extended | I-02 comment-only; I-03 adds a pre-emission suppress gate (opt-in path); both exit cleanly. |
| settings.json hook schema | No | I-05 adds a top-level `skillOverrides` key; all hook `args` exec-form preserved (EX-4). |

## Rollback

`git revert <commit>` restores prior behaviour. No data migration. No env-var unset (none added).
I-05 is the only runtime-config change; reverting the `skillOverrides` block restores full skill
descriptions. The `test-protect-files.sh` hotfix is independent and stays.

## Implementation Order

1. **Part 1 (I-01)** — write `test-simplify-semantics-doc.sh` (RED) → edit 4 docs → GREEN.
2. **Part 2 (I-02+I-03)** — write both tests (RED) → edit `check-uncommitted.sh` comment +
   `notify-workflow-complete.sh` gate + `CLAUDE.md` note → GREEN.
3. **Part 3 (I-04)** — write `test-subagent-type-normalize.sh` (RED) → edit
   `save-review-checkpoint.sh` + `delegation-templates.md` → GREEN (run EX-3 regression).
4. **Part 4 (I-05)** — confirm `skillOverrides` shape (docs) → write test (RED) →
   edit `settings.json` → GREEN.
5. **VERIFY** — `rc=0; for f in .claude/scripts/tests/test-*.sh; do bash "$f" || rc=1; done; exit $rc` → expect 80/80.
6. **Commit (Phase 5)** — `git add -f` ONLY the `## Files Summary` paths (`.claude/` is gitignored);
   NEVER `git add -A` (keeps the unrelated `docs/slides/` deletion out). Then `code-reviewer` in worktree.

## Files Summary

| File | Action | Part |
|---|---|---|
| `.claude/commands/coder.md` | UPDATE | 1 |
| `.claude/commands/workflow.md` | UPDATE | 1 |
| `.claude/skills/workflow-protocols/orchestration-core.md` | UPDATE | 1 |
| `CLAUDE.md` | UPDATE | 1, 2 |
| `.claude/scripts/tests/test-simplify-semantics-doc.sh` | CREATE | 1 |
| `.claude/scripts/check-uncommitted.sh` | UPDATE | 2 |
| `.claude/scripts/notify-workflow-complete.sh` | UPDATE | 2 |
| `.claude/scripts/tests/test-stop-block-cap-invariant.sh` | CREATE | 2 |
| `.claude/scripts/tests/test-notify-background-tasks-suppress.sh` | CREATE | 2 |
| `.claude/scripts/save-review-checkpoint.sh` | UPDATE | 3 |
| `.claude/skills/workflow-protocols/delegation-templates.md` | UPDATE | 3 |
| `.claude/scripts/tests/test-subagent-type-normalize.sh` | CREATE | 3 |
| `.claude/settings.json` | UPDATE | 4 |
| `.claude/scripts/tests/test-skilloverrides-internal-name-only.sh` | CREATE | 4 |
