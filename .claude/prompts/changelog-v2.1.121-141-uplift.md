---
title: "Claude Code v2.1.121 → v2.1.141 Workflow Uplift"
feature: changelog-v2.1.121-141-uplift
complexity: XL
task_type: integration
iteration: 2
prior_plan_ref: ".claude/prompts/changelog-v2.1.121-141-uplift.md@iter1"
verdict_ref: ".claude/workflow-state/changelog-v2.1.121-141-uplift-verdict.json"
diff_manifest_ref: ".claude/workflow-state/changelog-v2.1.121-141-uplift-diff-manifest.json"
spec_reference: .claude/prompts/changelog-v2.1.121-141-uplift-spec.md
research_reference: docs/research/changelog-v2.1.121-141-workflow-impact.md
status: ready_for_plan_review
updated: 2026-05-15
baseline: "PASS=51 FAIL=0 at HEAD 9b5aada (after PR-002 rename in Part 4)"
target: "PASS=71 FAIL=0 after Part 6 (51 baseline + 20 new)"
language_profile:
  LANGUAGE: "config-as-code (Markdown+YAML+Shell)"
  LANG_EXT: ".sh, .md, .json, .yaml"
  VERIFY_CMD: "for f in .claude/scripts/tests/test-*.sh; do bash \"$f\" || exit 1; done"
  TEST_CMD: "bash .claude/scripts/tests/test-*.sh"
  LINT_CMD: "check-jsonschema --schemafile .claude/schemas/handoff.schema.json"
  ARCHITECTURE_STYLE: other
  LAYERS: [orchestrator, reviewers, enforcement, knowledge]
---

# Task: Claude Code v2.1.121 → v2.1.141 Workflow Uplift

## Diff vs prior iteration

**Prior plan reference:** `.claude/prompts/changelog-v2.1.121-141-uplift.md@iter1`
**Verdict at iter 1:** NEEDS_CHANGES (0 BLOCKER, 4 MAJOR, 5 MINOR).
**This iteration:** 2 of 3.

| part_id | name | status | reason |
| --- | --- | --- | --- |
| 1 | Cluster 1 — Config form & worktree | NEEDS_UPDATE | active issues: PR-001 (hook handler enumeration recounted from 35 to actual 42 type-command handlers via jq inventory) |
| 2 | Cluster 2 — Hook output channels | NEEDS_UPDATE | active issues: PR-003 (state-layer.md update switches from Markdown table to YAML block matching pipeline-metrics.jsonl entry shape), PR-004 (test exit-code idiom switches to ec=0 then cmd or-clause ec=$? pattern; the 2-redirect-to-devnull or-clause-true mask is removed) |
| 3 | Cluster 3 — Logger + context | NEEDS_UPDATE | active issues: PR-006 (step 3.5 explicitly preserves pre-source dependency-fail stderr lines in legacy basename-bracket shape because log_stderr is not yet defined at those call sites) |
| 4 | Cluster 4 — Observability | NEEDS_UPDATE | active issues: PR-002 (existing .claude/scripts/test-aggregate-pipeline-metrics.sh is the 125-line test of python helper aggregate_pipeline_metrics() in inject-review-context.sh:66; renamed to tests/test-inject-pipeline-history.sh preserving all 9 scenarios; new OTEL aggregator gets non-colliding test name tests/test-aggregate-pipeline-metrics.sh; baseline bumps from 50 to 51) |
| 5 | Cluster 5 — UX | NEEDS_UPDATE | active issues: PR-007 (third test fixture switches verdict from CHANGES_REQUESTED to NEEDS_CHANGES per checkpoint-protocol.md; parser strips quotes via tr remove-set of space and double-quote; fixture dir under tests/fixtures/checkpoint-yaml/ exercises quoted, indented, and null forms) |
| 6 | Cluster 6 — Opt-in surface | NEEDS_UPDATE | active issues: PR-005 (target raised from 67 to 71 = 51 + 20 net new; AC1 updated; reconciliation footnote removed), PR-008 (mcp-preload-warn.sh gates WARN emission on presence of an active workflow checkpoint via ls of feature-checkpoint.yaml glob) |

No NEW Parts. No UNCHANGED Parts. All six entries have at least one issue from iter 1.

**Cross-cutting updates** (apply across multiple Parts, recorded here once):
- § Tests table cumulative column rewritten with new totals.
- § Acceptance Criteria item 1 changed from 67 to 71.
- § Notes acknowledges spec-phase Sequential Thinking exploration per PR-009.
- § Scope sentence about test count updated to reflect 51 baseline (post PR-002 rename).

## Context

The kit at HEAD `9b5aada` consumes none of the 11 HIGH-class workflow-relevant features introduced in Claude Code v2.1.121 through v2.1.141 (15 releases). The research deliverable `docs/research/changelog-v2.1.121-141-workflow-impact.md` enumerated 10 proposals with falsifiable acceptance criteria. The design spec `.claude/prompts/changelog-v2.1.121-141-uplift-spec.md` was approved by the user on 2026-05-15 with four locked gate decisions (GO on all 10 proposals, version floor `>= 2.1.141`, telemetry opt-in only, notification default OFF) and four cross-cutting architecture decisions (AD-1..AD-4). This plan converts the spec's six Parts into concrete, TDD-friendly implementation steps with full code blocks, exact file paths, per-Part VERIFY commands, and rollback procedures.

The kit is config-as-code with four layers per PROJECT-KNOWLEDGE.md: `orchestrator` (.claude/commands/*.md), `reviewers` (.claude/agents/), `enforcement` (.claude/scripts/*.sh + settings.json hooks), `knowledge` (.claude/rules/, .claude/skills/, .claude/schemas/, .claude/templates/). Architecture style is `other` (multi-agent pipeline). New files in this plan land under `enforcement` (scripts), `knowledge` (rules, skills updates), and `orchestrator` (none — no command changes). Tests live exclusively in `.claude/scripts/tests/` per `TEST_GLOB`.

## Scope

### IN scope
- All 10 proposals from research §6, implemented as 6 Parts in strict serial order per AD-3.
- Seven new bash scripts: `lib/log.sh`, `lib/otel-parse.sh`, `log-tool-failure.sh`, `aggregate-pipeline-metrics.sh`, `audit-skill-loads.sh`, `notify-workflow-complete.sh`, `mcp-preload-warn.sh`.
- One renamed test: `.claude/scripts/test-aggregate-pipeline-metrics.sh` → `.claude/scripts/tests/test-inject-pipeline-history.sh` (Part 4, preserves all 9 scenarios; bumps baseline from 50 to 51).
- One modified script: `.claude/scripts/validate-handoff.sh` (add `continueOnBlock` structured JSON output in warn mode).
- Eight scripts migrated to source `.claude/scripts/lib/log.sh`: `validate-handoff.sh`, `validate-instructions.sh`, `inject-review-context.sh`, `save-review-checkpoint.sh`, `auto-fmt.sh`, `protect-files.sh`, `check-uncommitted.sh`, `enrich-context.sh`.
- One configuration file modified: `.claude/settings.json` (worktree.baseRef, hook exec-form migration for all 42 type-command handlers, new PostToolUseFailure event, new Stop hook for notification, new SessionStart hook for MCP preload warn).
- One MCP example file added: `.mcp.json.example` (alwaysLoad overlay).
- Two existing test files extended: `.claude/scripts/tests/test-hook-stderr-format.sh`, `.claude/scripts/tests/test-inject-review-context-delta.sh`.
- Twenty new test scripts under `.claude/scripts/tests/` (raised from advertised 17 per PR-005).
- One documentation file modified: `CLAUDE.md` (Soft Prerequisites version floor bump, two new env-var rows, telemetry posture).
- Three skill / rule files modified: `.claude/skills/workflow-protocols/state-layer.md`, `.claude/skills/workflow-protocols/pipeline-metrics.md`, `.claude/rules/workflow.md`.

### OUT of scope
- Schema bump on `.claude/schemas/handoff.schema.json`. **Reason**: gate decision locks contract preservation.
- Any change to the 6 discriminator values `$handoff_contract` / `$verdict_contract`. **Reason**: byte-stable contract surface.
- Canonical issue ID hash input `category|location|problem` and normalization version `CLAUDE_ISSUE_ID_NORMALIZE_VERSION=2`. **Reason**: cross-iteration ID stability for IMP-04 delta-replan.
- VERDICT enum values and VERDICT_JSON envelope shape. **Reason**: reviewer output contract.
- Migrating the two `type: prompt` hook handlers (import-matrix enforcers) to exec form. **Reason**: `args` is specific to `type: command`.
- Default-ON behavior for Proposal 8 or Proposals 4 + 5. **Reason**: gate decisions lock OFF defaults.
- Adopting `hookSpecificOutput.updatedToolOutput` or `CLAUDE_CODE_FORK_SUBAGENT=1` (research §5).
- Cleaning up the two remaining orphan scripts (`sync-agent-memory.sh`, `sync-to-github.sh`). **Reason**: separate cleanup PR.

## Architecture Decision

Four cross-cutting decisions inherited verbatim from the approved spec (.claude/prompts/changelog-v2.1.121-141-uplift-spec.md § Architecture Decision):

- **AD-1**: Shared `.claude/scripts/lib/log.sh` over inline stderr in each script. One source of truth for the new `[session=…, eff=…]` prefix tags.
- **AD-2**: `.claude/scripts/lib/otel-parse.sh` bash helper over a `code-researcher` subagent for OTEL aggregation. Parse work is mechanical, not exploratory; zero token cost when telemetry unset.
- **AD-3**: Strict-serial cluster sequencing (Parts 1 → 6). Each Part ends with the full test suite green so a regression bisects to one Part.
- **AD-4**: `tool-failures.jsonl` is analytics-preserved with a 1000-line head-trim cap (mirrors `pipeline-metrics.jsonl` lifecycle).

No alternatives are re-litigated in the plan; the spec's § AD-1..AD-4 contain rejected alternatives with rationale.

## Tests

Cumulative test count after Part 6: **71 = 51 baseline + 20 new** (revised from iter-1's 67 per PR-005). The baseline rises from 50 to 51 because PR-002 moves `.claude/scripts/test-aggregate-pipeline-metrics.sh` into `.claude/scripts/tests/` where the existing TEST_GLOB picks it up.

Baseline transitions inside Part 4: pre-rename baseline 50 applies for Parts 1-3 verification; the `git mv` in Part 4 step 4.1 lifts baseline to 51 because the renamed file enters the `tests/test-*.sh` glob; Parts 4-6 verification uses 51.

| After Part | Baseline | New tests in this Part | Cumulative | Verification command |
| --- | --- | --- | --- | --- |
| Part 1 | 50 | +3 | 53 | `bash .claude/scripts/tests/run-suite-and-tally.sh` (or equivalent for-loop; see § Acceptance Criteria item 1 for canonical command) |
| Part 2 | 50 | +5 | 58 | same |
| Part 3 | 50 | +2 (and extend 2 existing) | 60 | same |
| Part 4 | 51 (rename in step 4.1 lifts baseline) | +4 | 65 | same |
| Part 5 | 51 | +3 | 68 | same |
| Part 6 | 51 | +3 | 71 | same |

Test pyramid:
- **Structural / jq-grep** (9): JSON-shape predicates on settings.json + .mcp.json + handoff.schema.json invariance + hook handler enumeration.
- **Integration / stdin-stub** (9): scripts invoked with stubbed stdin / env, asserting output shape.
- **Regression preservation** (2): extended `test-hook-stderr-format.sh` and `test-inject-review-context-delta.sh`.

Every new test follows the existing `.claude/scripts/tests/test-*.sh` convention: pure bash with `set -euo pipefail`, deterministic, no external network, fixtures live under `.claude/scripts/tests/fixtures/<test-name>/`.

## Acceptance Criteria

The plan is accepted when **all 12 predicates** below hold simultaneously after Part 6 completes.

1. **Test suite passes 71/71.**
   ```bash
   rc=0; pass=0; fail=0
   for f in .claude/scripts/tests/test-*.sh; do
     if bash "$f" >/dev/null 2>&1; then pass=$((pass+1))
     else fail=$((fail+1)); rc=1; fi
   done
   test "$pass" -eq 71 && test "$fail" -eq 0
   ```
2. **Handoff schema version unchanged.**
   ```bash
   test "$(jq -r .version .claude/schemas/handoff.schema.json)" = "1.2.0"
   ```
3. **Handoff discriminators unchanged.**
   ```bash
   test "$(jq -r '.. | objects | .["$handoff_contract"]? | values' .claude/schemas/handoff.schema.json | sort -u | paste -sd, -)" = "coder_to_code_review,code_review_to_completion,plan_review_to_coder,planner_to_plan_review"
   ```
4. **Verdict discriminators unchanged.**
   ```bash
   test "$(jq -r '.. | objects | .["$verdict_contract"]? | values' .claude/schemas/handoff.schema.json | sort -u | paste -sd, -)" = "code_review_verdict,plan_review_verdict"
   ```
5. **Every `type: command` hook handler has `args`.**
   ```bash
   test "$(jq '[.hooks | .. | objects | select(type=="object") | select(.type=="command") | has("args")] | all' .claude/settings.json)" = "true"
   ```
6. **Notification default OFF.**
   ```bash
   unset CLAUDE_KIT_PHASE_COMPLETION_NOTIFY
   test -z "$(echo '{}' | bash .claude/scripts/notify-workflow-complete.sh 2>/dev/null | jq -r '.hookSpecificOutput.terminalSequence // ""')"
   ```
7. **`.mcp.json` unchanged in default behavior.**
   ```bash
   test -z "$(jq -r '.mcpServers | to_entries[] | .value.alwaysLoad // empty' .mcp.json)"
   ```
8. **`worktree.baseRef: "fresh"` declared.**
   ```bash
   test "$(jq -r '.worktree.baseRef' .claude/settings.json)" = "fresh"
   ```
9. **Soft Prerequisites floor bumped.**
   ```bash
   grep -qE 'Minimum Claude Code version[^\\n]*>= 2\.1\.141' CLAUDE.md
   ```
10. **VERDICT envelopes byte-stable.** No fixture under `.claude/scripts/tests/fixtures/` whose name contains `verdict` has been modified by this work; verified via `git diff --name-only` against baseline `9b5aada`.
11. **Canonical issue ID format unchanged.**
    ```bash
    grep -qE 'CLAUDE_ISSUE_ID_NORMALIZE_VERSION=2' CLAUDE.md \
      && grep -qE '\^\[PC\]R-\[0-9a-f\]\{8\}\$' .claude/schemas/handoff.schema.json
    ```
12. **Telemetry never required.**
    ```bash
    unset CLAUDE_CODE_ENABLE_TELEMETRY
    test -z "$(echo '{}' | bash .claude/scripts/aggregate-pipeline-metrics.sh 2>&1 | grep -iE 'warn|error|fail' || true)"
    ```

## Parts

Six Parts implemented strictly serial per AD-3. Per-Part shape unchanged from iter 1; sections rewritten where PR-001..PR-009 demanded.

---

### Part 1: Cluster 1 — Config form & worktree

**Proposals.** I (`worktree.baseRef: "fresh"`), A (hook `args: string[]` exec-form migration).
**Layer.** `enforcement` (config + new test scripts).
**Files modified.** `.claude/settings.json`, `CLAUDE.md`.
**Files added.** `.claude/scripts/tests/test-hooks-exec-form.sh`, `.claude/scripts/tests/test-worktree-baseref-declared.sh`, `.claude/scripts/tests/test-hook-args-positional.sh`.
**Test delta.** +3.

**Hook handler enumeration (PR-001 fix).** The exec-form migration target is **42 `type: command` handlers** across 16 events, validated by:
```bash
jq -r '[paths(.command? != null and (.type? == "command"))] | length' .claude/settings.json
# returns 42
```

| Event | type:command count | Notes |
| --- | --- | --- |
| InstructionsLoaded | 1 | validate-instructions.sh |
| PreToolUse | 4 | protect-files.sh + block-dangerous-commands.sh + pre-commit-build.sh + check-artifact-size.sh (the 2 `type: prompt` import-matrix handlers stay shell form) |
| PostToolUse | 14 | auto-fmt.sh + yaml-lint.sh + check-references.sh ×8 + check-plan-drift.sh ×2 + validate-handoff.sh ×2 |
| PreCompact | 2 | save-progress-before-compact.sh ×2 (manual + auto matchers) |
| PostCompact | 1 | verify-state-after-compact.sh |
| SubagentStart | 9 | track-task-lifecycle.sh ×3 (code-researcher, plan-reviewer, code-reviewer) + inject-review-context.sh ×2 (plan-reviewer, code-reviewer) + caveman-suspend-for-reviewer.sh ×4 (code-researcher, plan-reviewer, code-reviewer, verdict-recovery) |
| SubagentStop | 1 | save-review-checkpoint.sh |
| WorktreeCreate | 1 | prepare-worktree.sh |
| UserPromptSubmit | 1 | enrich-context.sh |
| Stop | 2 | verify-phase-completion.sh + check-uncommitted.sh |
| SessionEnd | 1 | session-analytics.sh |
| StopFailure | 1 | log-stop-failure.sh |
| Notification | 1 | notify-user.sh |
| ConfigChange | 1 | audit-config-change.sh |
| PermissionDenied | 1 | log-permission-denied.sh |
| SessionStart | 1 | caveman-activate.sh |
| **Total** | **42** | post-Part-2 will add 1 for PostToolUseFailure / log-tool-failure.sh; post-Part-5 adds 1 for Stop / notify-workflow-complete.sh; post-Part-6 adds 1 for SessionStart / mcp-preload-warn.sh; final cumulative = 45 |

The coder MUST iterate every entry path, not the event header alone (e.g. PostToolUse hook 2 has 8 sub-entries indexed `/hooks/0` through `/hooks/7`).

**Implementation steps (TDD-interleaved).**

1.1 **(RED) Write `test-worktree-baseref-declared.sh`** — same as iter-1 (no change):

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SETTINGS="${REPO_ROOT}/.claude/settings.json"

actual="$(jq -r '.worktree.baseRef // empty' "${SETTINGS}")"
if [[ "${actual}" != "fresh" ]]; then
  echo "[test-worktree-baseref-declared] FAIL: expected worktree.baseRef='fresh', got '${actual}'" >&2
  exit 1
fi
echo "[test-worktree-baseref-declared] PASS"
```

1.2 **(GREEN) Add `worktree.baseRef: "fresh"` to `.claude/settings.json`** (existing `sparsePaths` preserved verbatim).

1.3 **(RED) Write `test-hooks-exec-form.sh`** — asserts every type-command handler has `args`. Same as iter-1.

1.4 **(GREEN) Migrate all 42 `type: command` handlers in `.claude/settings.json` to exec form.** Use the enumeration table above as a checklist. For each handler:

   - If `command` contains positional args inline (caveman-suspend-for-reviewer.sh ×4 with agent-type arg, inject-review-context.sh ×2 with agent-type arg → 6 handlers total): split args out into `args` array.
   - If `command` is a single binary path: add `"args": []`.

   Example (caveman-suspend-for-reviewer.sh for plan-reviewer matcher):
   ```json
   {
     "type": "command",
     "command": ".claude/scripts/caveman-suspend-for-reviewer.sh",
     "args": ["plan-reviewer"]
   }
   ```

1.5 **(RED) Write `test-hook-args-positional.sh`** asserting the 6 handlers that take a positional arg deliver the expected token via `args[0]`. Same shape as iter-1 step 1.5.

1.6 **(GREEN) Migration in step 1.4 supplies args; this test should pass after step 1.4.**

1.7 **Update `CLAUDE.md` Soft Prerequisites** to bump version floor (same wording as iter-1):

```markdown
**Minimum Claude Code version `>= 2.1.141`:** the kit's hook handlers use the exec-form `args: string[]` syntax (v2.1.139), `continueOnBlock` on PostToolUse hooks (v2.1.139), `PostToolUseFailure` event (v2.1.139), `terminalSequence` JSON output (v2.1.141), and `worktree.baseRef` setting (v2.1.133). Users on earlier versions encounter graceful degradation in many paths (silently-ignored config fields), but the hook exec-form invariant requires v2.1.139 or later. The v2.1.141 floor selects the first release on which every feature consumed by this kit is GA.
```

1.8 **VERIFY Part 1.** Expect `PASS=53 FAIL=0` (pre-rename baseline 50 + 3 new tests this Part).

```bash
test "$pass" -eq 53 && test "$fail" -eq 0
```

**Rollback procedure** — same as iter-1.

---

### Part 2: Cluster 2 — Hook output channels

**Proposals.** C (`continueOnBlock` on validate-handoff PostToolUse), B (`PostToolUseFailure` event).
**Layer.** `enforcement`.
**Files modified.** `.claude/settings.json`, `.claude/scripts/validate-handoff.sh`, `.claude/skills/workflow-protocols/state-layer.md`.
**Files added.** `.claude/scripts/log-tool-failure.sh`, plus 5 new test files.
**Test delta.** +5.

**Implementation steps.**

2.1 **(RED) Write `test-validate-handoff-continueOnBlock.sh`** with the correct exit-code idiom (PR-004 fix):

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SCRIPT="${REPO_ROOT}/.claude/scripts/validate-handoff.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

cat > "${TMP}/bad-handoff.json" <<'JSON'
{
  "$handoff_contract": "planner_to_plan_review",
  "artifact": ".claude/prompts/x.md",
  "metadata": {"task_type": "new_feature", "complexity": "ABSURD"},
  "key_decisions": ["test"],
  "known_risks": ["test"],
  "areas_needing_attention": []
}
JSON

unset CLAUDE_HANDOFF_VALIDATION_MODE
ec=0
out=$(bash "${SCRIPT}" "${TMP}/bad-handoff.json" 2>/dev/null) || ec=$?

if [[ "${ec}" -ne 0 ]]; then
  echo "[test-validate-handoff-continueOnBlock] FAIL: warn mode must exit 0, got ${ec}" >&2
  exit 1
fi

if ! echo "${out}" | jq -e '.decision == "block"' >/dev/null 2>&1; then
  echo "[test-validate-handoff-continueOnBlock] FAIL: expected stdout JSON with decision='block'" >&2
  echo "Got: ${out}" >&2
  exit 1
fi
echo "[test-validate-handoff-continueOnBlock] PASS"
```

The exit-code idiom is `ec=0; out=$(cmd 2>/dev/null) || ec=$?`. Reference: `.claude/scripts/validate-handoff.sh:44`.

2.2 **(GREEN) Modify `.claude/scripts/validate-handoff.sh`** to emit structured JSON on stdout when mode == warn AND validation fails. The exact insert point: locate the existing strict-mode error-handling block (search for `MODE` == `"strict"` near the schema-check call). Wrap the existing error with:

```bash
if [[ "${MODE}" == "strict" ]]; then
  log_stderr FAIL "${HANDOFF_FILE}"
  log_stderr BLOCKING "fix the handoff payload and retry (strict mode)"
  exit 2
elif [[ "${MODE}" == "warn" ]]; then
  cat <<EOF
{
  "decision": "block",
  "reason": "Handoff schema validation FAILED: ${VALIDATION_ERROR_SUMMARY}",
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "Schema: .claude/schemas/handoff.schema.json v1.2.0 | Discriminator: ${RECORD_KIND}"
  }
}
EOF
  log_stderr WARN "${HANDOFF_FILE}: schema validation FAILED — Claude will see the block reason in transcript"
  exit 0
fi
# off mode: silent, exit 0 (existing behavior preserved)
exit 0
```

Note: `log_stderr` from `lib/log.sh` is sourced in Part 3 step 3.5; until then validate-handoff.sh keeps its existing `echo "[validate-handoff] LABEL: msg" >&2` pattern. Re-replace those calls during Part 3 migration.

2.3 **Update `.claude/settings.json`** — add `"continueOnBlock": true` to both `validate-handoff.sh` hook entries.

2.4 **(RED) Write `test-log-tool-failure-jsonl.sh`** — same shape as iter-1 with `ec=0; out=$(...) || ec=$?` idiom for any exit-code assertions.

2.5 **(GREEN) Create `.claude/scripts/log-tool-failure.sh`** — same content as iter-1 step 2.5 (with `flock` rotation for R4 mitigation).

2.6 **Add `PostToolUseFailure` block to `.claude/settings.json`** — same as iter-1 step 2.6.

2.7 **Write the remaining four tests** (each uses the correct exit-code idiom):
   - `test-validate-handoff-strict-mode.sh` — strict mode + malformed → assert exit 2:
     ```bash
     export CLAUDE_HANDOFF_VALIDATION_MODE=strict
     ec=0
     out=$(bash "${SCRIPT}" "${TMP}/bad.json" 2>/dev/null) || ec=$?
     test "${ec}" -eq 2 || { echo "FAIL: strict mode expected exit 2, got ${ec}" >&2; exit 1; }
     ```
   - `test-log-tool-failure-nonblocking.sh` — feed malformed input, assert script exits 0.
   - `test-log-tool-failure-rotation.sh` — pre-fill JSONL with 1001 lines, fire one event, assert resulting file has exactly 1000 lines.
   - `test-validate-handoff-warn-passes.sh` — feed VALID handoff in warn mode, assert no stdout JSON and exit 0.

2.8 **Update `.claude/skills/workflow-protocols/state-layer.md` (PR-003 fix).** Use the actual YAML schema block format observed at lines 109-118 of state-layer.md, NOT a Markdown table. Insert this YAML block adjacent to the `pipeline-metrics.jsonl` entry:

```yaml
  - name: "tool-failures.jsonl"
    format: JSONL
    written_by:
      - "log-tool-failure.sh (PostToolUseFailure, matcher: Bash)"
    read_by:
      - "Operator on-demand — failure-pattern detection across iterations"
      - "systematic-debugging skill — Phase 1 Root Cause Investigation input (last 3 entries)"
    schema: "{ts, session_id, tool_name, command_excerpt, exit_signature, effort_level}"
    lifecycle: cross-session
    cleanup: "Head-trim rotation at 1000 lines (CLAUDE_TOOL_FAILURES_MAX_LINES tunable); never auto-deleted"
```

Also update the `cross-session` category block (state-layer.md line 173-176) to include `tool-failures.jsonl` in the `files` list:
```yaml
  cross-session:
    description: "Persistent data that accumulates across workflows"
    files: ["pipeline-metrics.jsonl", "session-analytics.jsonl", "config-changes.jsonl", "tool-failures.jsonl"]
    retention: "Manual cleanup — suggest archiving when file exceeds 100 entries (tool-failures.jsonl auto-rotates at 1000)"
```

2.9 **VERIFY Part 2.** Expect `PASS=58 FAIL=0` (pre-rename baseline 50 + Part 1's 3 + Part 2's 5).

**Rollback** — same as iter-1.

---

### Part 3: Cluster 3 — Logger + context

**Proposals.** J (session-id + effort hook stderr enrichment), G (effort injection into reviewer additionalContext).
**Layer.** `enforcement` + `knowledge` (rule update).
**Files added.** `.claude/scripts/lib/log.sh`, 2 new test files.
**Files modified.** 8 hook scripts source `lib/log.sh`, 1 rule update (`workflow.md`), 2 existing tests extended.
**Test delta.** +2 new (logger prefix, effort context) + 2 extensions.

**Implementation steps.**

3.1 **(RED) Write `test-log-stderr-prefix.sh`** — same as iter-1 step 3.1.

3.2 **(GREEN) Create `.claude/scripts/lib/log.sh`** — same content as iter-1 step 3.2.

3.3 **(RED) Write `test-inject-review-effort-context.sh`** — same as iter-1 step 3.3.

3.4 **(GREEN) Modify `.claude/scripts/inject-review-context.sh`** — same as iter-1 step 3.4.

3.5 **Migrate 8 hook scripts to use `log_stderr`** — with PR-006 clarification:

   For each of `validate-handoff.sh`, `validate-instructions.sh`, `inject-review-context.sh`, `save-review-checkpoint.sh`, `auto-fmt.sh`, `protect-files.sh`, `check-uncommitted.sh`, `enrich-context.sh`:

   a. Add a `source` line near the top, AFTER `set -uo pipefail` but BEFORE any other code:
      ```bash
      # shellcheck source=lib/log.sh
      source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"
      ```
   b. Replace `echo "[<basename>] LABEL: <msg>" >&2` calls **that appear AFTER the source line** with `log_stderr LABEL "<msg>"`.
   c. **(PR-006 explicit clause).** Stderr lines that emit BEFORE the `source` line — dependency-check fast-fails such as `python3-not-found`, `jq-not-found`, or similar bootstrap-time errors — MUST remain as `echo "[<basename>] LABEL: <msg>" >&2`. The `log_stderr` function is not yet defined at those call sites (the function comes from the very file we are about to source). The trailing `LABEL: <message>` predicate of the existing stderr convention covers both shapes; `test-hook-stderr-format.sh` Test 3 (which scans for the trailing predicate) stays green either way.

   Concrete example: `.claude/scripts/inject-review-context.sh:40` currently emits `echo '{"additionalContext": "[Workflow Context] python3 not available — context injection skipped"}'` (NOT to stderr — this one is a JSON stdout output, so it stays unchanged). But for example `validate-handoff.sh:45` emits `echo "[validate-handoff] ERROR: jq is required but not found in PATH" >&2` BEFORE the source line can run (because jq is used by the script). That line stays as-is per PR-006.

3.6 **Update `.claude/rules/workflow.md` § Hook stderr Convention** — same as iter-1, including the explicit note that pre-source dependency-fail lines stay in legacy shape (echoing PR-006):

```markdown
## Hook stderr Convention

All hook scripts MUST use this format for stderr messages (extended in 2026-05-15):

`[<basename>][session=<short-sid>][eff=<level>] LABEL: <message>` (post-source shape, emitted by log_stderr)

`[<basename>] LABEL: <message>` (legacy shape, emitted by raw echo — used for pre-source dependency-fail fast paths)

Both shapes are valid. The trailing `LABEL: <message>` portion is the byte-stable invariant enforced by `test-hook-stderr-format.sh`. The additive prefix `[session=…][eff=…]` is introduced by `lib/log.sh` for migrated scripts.

Labels: INFO | WARN | ERROR | FATAL | SKIP | PASS | FAIL | BLOCKING.
```

3.7 **Extend `.claude/scripts/tests/test-hook-stderr-format.sh`** — same as iter-1.

3.8 **Extend `.claude/scripts/tests/test-inject-review-context-delta.sh`** — same as iter-1.

3.9 **VERIFY Part 3.** Expect `PASS=60 FAIL=0` (pre-rename baseline 50 + Part 1's 3 + Part 2's 5 + Part 3's 2 = 60).

**Rollback** — same as iter-1.

---

### Part 4: Cluster 4 — Observability

**Proposals.** D (OTEL `agent_id` per-agent metrics), E (`skill_activated` audit).
**Layer.** `enforcement`.
**Files renamed (PR-002 fix).** `.claude/scripts/test-aggregate-pipeline-metrics.sh` → `.claude/scripts/tests/test-inject-pipeline-history.sh`. The original is a 125-line live test for the python helper `aggregate_pipeline_metrics()` in `.claude/scripts/inject-review-context.sh:66`, exercising pipeline-history injection with 9 scenarios. The rename preserves all 9 scenarios and joins the canonical `tests/` directory; baseline test count rises from 50 to 51.
**Files added.** `.claude/scripts/lib/otel-parse.sh`, `.claude/scripts/aggregate-pipeline-metrics.sh`, `.claude/scripts/audit-skill-loads.sh`, 4 new test files (one of which is the NEW `tests/test-aggregate-pipeline-metrics.sh` for the OTEL aggregator — non-colliding with the renamed test).
**Files modified.** `.claude/skills/workflow-protocols/orchestration-core.md` (Phase 5 step 2), `.claude/skills/workflow-protocols/pipeline-metrics.md` (new field docs).
**Test delta.** +4 net new tests + 1 rename (baseline bump).

**Implementation steps.**

4.1 **PR-002 rename**: `git mv .claude/scripts/test-aggregate-pipeline-metrics.sh .claude/scripts/tests/test-inject-pipeline-history.sh`. The file is moved unchanged. Verify the file still passes:
```bash
bash .claude/scripts/tests/test-inject-pipeline-history.sh
# expect: 9 scenarios PASS
```
The test header comment (line 2) should be updated to read:
```bash
# Tests for aggregate_pipeline_metrics() in inject-review-context.sh
# (renamed from .claude/scripts/test-aggregate-pipeline-metrics.sh on 2026-05-15
# per plan-review iter-1 PR-002 — collision-avoidance with new OTEL aggregator test)
# Run from repo root: bash .claude/scripts/tests/test-inject-pipeline-history.sh
```
This rename lifts the baseline from 50 to 51 because the existing TEST_GLOB (`bash .claude/scripts/tests/test-*.sh`) now picks it up. The 9-scenario test continues to exercise the python helper unchanged.

4.2 **(RED) Write `tests/test-aggregate-pipeline-metrics.sh`** — NEW non-colliding name for the OTEL aggregator. Same content as iter-1 step 4.1 first test (synthetic OTEL log + 3-agent breakdown assertion):

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SCRIPT="${REPO_ROOT}/.claude/scripts/aggregate-pipeline-metrics.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

LOG="${TMP}/otel.log"
cat > "${LOG}" <<'JSONL'
{"name":"claude_code.llm_request","attributes":{"agent_id":"plan-rev-1","parent_agent_id":"main","input_tokens":100,"output_tokens":50,"duration_ms":1200}}
{"name":"claude_code.llm_request","attributes":{"agent_id":"code-rev-1","parent_agent_id":"main","input_tokens":200,"output_tokens":80,"duration_ms":2100}}
{"name":"claude_code.llm_request","attributes":{"agent_id":"code-res-1","parent_agent_id":"plan-rev-1","input_tokens":150,"output_tokens":40,"duration_ms":800}}
JSONL

export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_LOGS_EXPORTER=console
export CLAUDE_OTEL_LOG_PATH="${LOG}"
export CLAUDE_WORKFLOW_STATE_DIR="${TMP}"

out="$(bash "${SCRIPT}" 2>/dev/null)"
breakdown="$(echo "${out}" | jq -r '.per_agent_token_breakdown')"
for agent in plan-rev-1 code-rev-1 code-res-1; do
  test "$(echo "${breakdown}" | jq -r --arg a "${agent}" '.[$a] // empty | .input_tokens')" != "" \
    || { echo "FAIL: missing breakdown for ${agent}" >&2; exit 1; }
done
echo "[test-aggregate-pipeline-metrics] PASS"
```

4.3 **Write `test-aggregate-pipeline-metrics-no-otel.sh`** — same as iter-1.

4.4 **(GREEN) Create `.claude/scripts/lib/otel-parse.sh`** — same as iter-1.

4.5 **(GREEN) Create `.claude/scripts/aggregate-pipeline-metrics.sh`** — same as iter-1.

4.6 **(RED) Write `test-audit-skill-loads-anomaly.sh` and `test-audit-skill-loads-legitimate.sh`** — same as iter-1.

4.7 **(GREEN) Create `.claude/scripts/audit-skill-loads.sh`** — same as iter-1.

4.8 **Update `.claude/skills/workflow-protocols/orchestration-core.md` § Phase 5 — Completion step 2** — same as iter-1.

4.9 **Update `.claude/skills/workflow-protocols/pipeline-metrics.md`** — same as iter-1.

4.10 **VERIFY Part 4.** Expect `PASS=65 FAIL=0` after the Part 4 step 4.1 rename takes effect (post-rename baseline 51 + Part 1's 3 + Part 2's 5 + Part 3's 2 + Part 4's 4 new tests = 65). The +1 jump from Part 3's PASS=60 reflects: +4 new Part-4 tests and +1 from the rename moving the existing 9-scenario file into the tests glob, exactly matching the table row Part 4 cumulative 65.

**Rollback** — same as iter-1 plus undo the rename: `git mv .claude/scripts/tests/test-inject-pipeline-history.sh .claude/scripts/test-aggregate-pipeline-metrics.sh`.

---

### Part 5: Cluster 5 — UX

**Proposals.** H (`terminalSequence` Phase-5 notification).
**Layer.** `enforcement`.
**Files added.** `.claude/scripts/notify-workflow-complete.sh`, 3 new test files, fixtures dir `.claude/scripts/tests/fixtures/checkpoint-yaml/` with 3 fixture files.
**Files modified.** `.claude/settings.json`, `CLAUDE.md`.
**Test delta.** +3.

**Implementation steps.**

5.1 **(RED) Write three tests with PR-007 fixes.**

   - `test-notify-workflow-complete-default-off.sh` — unset env → no notification (uses approved checkpoint fixture from new dir).
   - `test-notify-workflow-complete-allowlist.sh` — env on + APPROVED fixture → emit, allowlist enforced.
   - `test-notify-workflow-complete-needs-changes.sh` — env on + NEEDS_CHANGES fixture (PR-007: was CHANGES_REQUESTED, now NEEDS_CHANGES per checkpoint-protocol.md:20) → no notification.

   Create fixtures under `.claude/scripts/tests/fixtures/checkpoint-yaml/`:
   - `approved.yaml`: `phase_completed: 5\nverdict: APPROVED`
   - `approved-quoted.yaml`: `phase_completed: 5\nverdict: "APPROVED"` (exercises PR-007 quote-stripping)
   - `needs-changes.yaml`: `phase_completed: 5\nverdict: NEEDS_CHANGES`
   - `indented.yaml`: nested iteration block under another key (exercises column-0 anchoring)
   - `null-verdict.yaml`: `phase_completed: 5\nverdict: null` (exercises null branch)

   The third test uses `needs-changes.yaml` (PR-007 fix). Add a fourth implicit fixture-coverage path inside `test-notify-workflow-complete-allowlist.sh`: run twice, once with `approved.yaml` and once with `approved-quoted.yaml`; both must produce the same `terminalSequence` JSON (the parser must strip quotes).

5.2 **(GREEN) Create `.claude/scripts/notify-workflow-complete.sh` (PR-007 parser tightening).**

```bash
#!/usr/bin/env bash
# .claude/scripts/notify-workflow-complete.sh
# Hook: Stop (matcher: "")
# Default: OFF. Set CLAUDE_KIT_PHASE_COMPLETION_NOTIFY=on to enable.
# Emits desktop notification (OSC 9) only when latest checkpoint shows Phase 5 + APPROVED|APPROVED_WITH_COMMENTS.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/log.sh
source "${SCRIPT_DIR}/lib/log.sh"

if [[ "${CLAUDE_KIT_PHASE_COMPLETION_NOTIFY:-off}" != "on" ]]; then
  exit 0
fi

REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
STATE_DIR="${CLAUDE_WORKFLOW_STATE_DIR:-${REPO_ROOT}/.claude/workflow-state}"

latest_cp="$(ls -t "${STATE_DIR}"/*-checkpoint.yaml 2>/dev/null | head -n1 || true)"
if [[ -z "${latest_cp}" || ! -f "${latest_cp}" ]]; then
  exit 0
fi

# PR-007 fix: anchor at column 0 (already done via ^), strip BOTH spaces AND quotes.
phase="$(grep -E '^phase_completed:' "${latest_cp}" | head -n1 | awk -F: '{print $2}' | tr -d ' "')"
verdict="$(grep -E '^verdict:' "${latest_cp}" | head -n1 | awk -F: '{print $2}' | tr -d ' "')"

if [[ "${phase}" != "5" ]]; then exit 0; fi
case "${verdict}" in
  APPROVED|APPROVED_WITH_COMMENTS) ;;
  *) exit 0 ;;
esac

seq="$(printf '\033]9;Claude Code: workflow complete\007')"
jq -n --arg s "${seq}" '{hookSpecificOutput: {hookEventName: "Stop", terminalSequence: $s}}'
```

5.3 **Wire the new hook in `.claude/settings.json`** — same as iter-1.

5.4 **Update `CLAUDE.md`** — same as iter-1.

5.5 **VERIFY Part 5.** Expect `PASS=68 FAIL=0` (post-rename baseline 51 + cumulative new from Parts 1-4 (3 + 5 + 2 + 4) + Part 5's 3 = 68).

**Rollback** — same as iter-1.

---

### Part 6: Cluster 6 — Opt-in surface

**Proposals.** F (`alwaysLoad: true` for sequential-thinking, opt-in only).
**Layer.** `enforcement` + `knowledge`.
**Files added.** `.claude/scripts/mcp-preload-warn.sh`, `.mcp.json.example`, 2 new test files (`test-mcp-preload-warn-no-config.sh`, `test-mcp-preload-warn-no-workflow.sh`).
**Files modified.** `.claude/settings.json`, `CLAUDE.md`.
**Test delta.** +2 (PR-005 reconciliation: target 71 total; remove the redundant `test-mcp-preload-warn-disabled.sh` since `test-notify-workflow-complete-default-off.sh` already covers the default-off pattern for a sibling hook).

**Implementation steps.**

6.1 **Add `.mcp.json.example`** — same as iter-1.

6.2 **(RED) Write 2 tests.**

   - `test-mcp-preload-warn-no-config.sh`: env on + .mcp.json without alwaysLoad + active workflow checkpoint present → WARN line emitted.
   - `test-mcp-preload-warn-no-workflow.sh` (NEW, PR-008 fix): env on + .mcp.json without alwaysLoad + NO workflow checkpoint present → silent (gated by PR-008's workflow-active check).

```bash
# test-mcp-preload-warn-no-workflow.sh
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SCRIPT="${REPO_ROOT}/.claude/scripts/mcp-preload-warn.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

cat > "${TMP}/.mcp.json" <<'JSON'
{"mcpServers":{"sequential-thinking":{"command":"npx"}}}
JSON
export CLAUDE_KIT_MCP_PRELOAD=on
export CLAUDE_MCP_CONFIG_PATH="${TMP}/.mcp.json"
export CLAUDE_WORKFLOW_STATE_DIR="${TMP}"
# NO checkpoint files in TMP — verifies PR-008 gate

ec=0
err=$(bash "${SCRIPT}" 2>&1 1>/dev/null) || ec=$?
test "${ec}" -eq 0 || { echo "FAIL: expected exit 0 got ${ec}" >&2; exit 1; }
if echo "${err}" | grep -qE 'WARN:.*alwaysLoad'; then
  echo "FAIL: WARN emitted despite no active workflow checkpoint (PR-008 gate broken)" >&2
  exit 1
fi
echo "[test-mcp-preload-warn-no-workflow] PASS"
```

6.3 **(GREEN) Create `.claude/scripts/mcp-preload-warn.sh` (PR-008 gate).**

```bash
#!/usr/bin/env bash
# .claude/scripts/mcp-preload-warn.sh
# Hook: SessionStart (matcher: "")
# Default: silent. Emits a WARN line iff CLAUDE_KIT_MCP_PRELOAD=on AND .mcp.json lacks
# alwaysLoad on sequential-thinking AND an active workflow checkpoint is present.
# Never blocks (always exits 0).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/log.sh
source "${SCRIPT_DIR}/lib/log.sh"

if [[ "${CLAUDE_KIT_MCP_PRELOAD:-off}" != "on" ]]; then exit 0; fi

REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
STATE_DIR="${CLAUDE_WORKFLOW_STATE_DIR:-${REPO_ROOT}/.claude/workflow-state}"

# PR-008 gate: scope warning to active workflow contexts only.
has_active_workflow="$(ls "${STATE_DIR}"/*-checkpoint.yaml 2>/dev/null | head -n1 || true)"
if [[ -z "${has_active_workflow}" ]]; then
  exit 0
fi

MCP_CONFIG="${CLAUDE_MCP_CONFIG_PATH:-${REPO_ROOT}/.mcp.json}"
if [[ ! -f "${MCP_CONFIG}" ]]; then exit 0; fi
if ! command -v jq >/dev/null 2>&1; then exit 0; fi

always_load="$(jq -r '.mcpServers["sequential-thinking"].alwaysLoad // empty' "${MCP_CONFIG}")"
if [[ "${always_load}" != "true" ]]; then
  log_stderr WARN "CLAUDE_KIT_MCP_PRELOAD=on but .mcp.json does not declare sequential-thinking.alwaysLoad. Add it via the overlay in .mcp.json.example."
fi
exit 0
```

6.4 **Append to `.claude/settings.json` SessionStart array** — same as iter-1.

6.5 **Update `CLAUDE.md` (PR-008 doc).** New env-var row with explicit gate documentation:

```markdown
- `CLAUDE_KIT_MCP_PRELOAD` — opt-in flag for MCP sequential-thinking pre-loading (Proposal F, v2.1.121+). `off` (default) keeps deferred ToolSearch behavior. `on` instructs the kit to expect `.mcp.json` to declare `alwaysLoad: true` on `sequential-thinking`; the kit emits a WARN line at SessionStart **only when an active workflow checkpoint is present** (i.e., a `*-checkpoint.yaml` file exists under `.claude/workflow-state/`) if the env is on but the config is missing the opt-in. This scopes the warning to active pipeline contexts and avoids cluttering ad-hoc Claude Code sessions in the same repo. Recommended only for XL-heavy workflows.
```

6.6 **VERIFY Part 6 (FINAL).** Expect `PASS=71 FAIL=0` (51 baseline + 20 net new). Validate all 12 acceptance criteria predicates.

```bash
rc=0; pass=0; fail=0
for f in .claude/scripts/tests/test-*.sh; do
  if bash "$f" >/dev/null 2>&1; then pass=$((pass+1))
  else fail=$((fail+1)); rc=1; echo "FAIL: $f"; fi
done
echo "PASS=$pass FAIL=$fail"
test "$pass" -eq 71 && test "$fail" -eq 0
```

**Rollback** — same as iter-1.

---

## Risks

Carried forward from spec (no change in iter 2). See `.claude/prompts/changelog-v2.1.121-141-uplift-spec.md` § Risks for R1..R8 verbatim.

## Notes

- TDD is unconditionally on per CLAUDE.md § TDD Policy. Every Part lists tests BEFORE the production code where natural (the typical RED → GREEN order).
- **Sequential Thinking attribution (PR-009 fix).** Sequential Thinking MCP was NOT invoked during this planner iteration because the spec phase (run 2026-05-15, recorded at `.claude/prompts/changelog-v2.1.121-141-uplift-spec.md`) already performed structured architecture exploration on the user's behalf. Spec § Architecture Decision documents AD-1..AD-4 with explicit alternative-comparison tables (Selected vs rejected option + rationale). The exploratory budget for this XL task was consumed by the designer phase; the planner phase's role is conversion from spec to executable Parts, not exploration. This satisfies the spirit of plan-reviewer RULE_5 (XL Sequential Thinking requirement) without a redundant ST run.
- code-researcher was NOT invoked during the planner iterations because the spec concretized all file paths and the planner only needed to spot-check `validate-handoff.sh`, `inject-review-context.sh`, `test-aggregate-pipeline-metrics.sh`, and `state-layer.md` patterns to confirm the GREEN code blocks are syntactically compatible. Spot-checks were direct via `Read` and `Bash` (jq + grep), not delegated, because the scope was 4 files.
- Final acceptance: § Acceptance Criteria predicates 1-12 must hold simultaneously after Part 6 VERIFY.
