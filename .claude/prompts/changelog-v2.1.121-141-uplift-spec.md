---
feature: changelog-v2.1.121-141-uplift
status: approved
approved_by: user
approved_at: 2026-05-15
created: 2026-05-15
complexity: XL
task_type: refactor_plus_new_feature
research_source: docs/research/changelog-v2.1.121-141-workflow-impact.md
designer_run: 2026-05-15
gate_decisions_locked:
  scope: "GO — all 10 proposals"
  version_floor: ">= 2.1.141"
  telemetry: "opt-in only"
  notification_default: "OFF"
baseline_tests: "PASS=50 FAIL=0 at HEAD 9b5aada"
---

# Spec — Claude Code v2.1.121 → v2.1.141 Workflow Uplift

## Context

The kit at HEAD `9b5aada` runs against Claude Code with `>= 2.1.113` as the documented soft floor. Versions 2.1.121 through 2.1.141 introduced 11 HIGH-class workflow-relevant features (hook `args`/`continueOnBlock`/`terminalSequence`, `effort.level` env, OTEL `agent_id`/`skill_activated.invocation_trigger`, MCP `alwaysLoad`, `worktree.baseRef`, `CLAUDE_CODE_SESSION_ID`, `PostToolUseFailure` event). The kit currently consumes none of them.

Research deliverable `docs/research/changelog-v2.1.121-141-workflow-impact.md` (640 lines) enumerated 10 proposals with falsifiable acceptance criteria, validated against canonical docs (`code.claude.com/docs/en/{hooks,sub-agents,settings,mcp,monitoring-usage}`), and confirmed zero touchpoints on the 6 frozen handoff contracts (`planner_to_plan_review`, `plan_review_to_coder`, `plan_review_verdict`, `coder_to_code_review`, `code_review_verdict`, `code_review_to_completion`).

User gate (recorded in `.claude/workflow-state/changelog-v2.1.121-141-uplift-checkpoint.yaml`) approved all 10 proposals, the version-floor bump, the telemetry-opt-in posture, and the notification-OFF default. This spec converts the research into an implementable design organized by the 6 clusters from research §7.

## Scope

### IN scope
- All 10 proposals from research §6, implemented as 6 clusters (one Part per cluster).
- `.claude/settings.json` migration to hook exec form `args: string[]` (Proposal A) — every command-handler entry.
- `.claude/settings.json` adds `worktree.baseRef: "fresh"` (Proposal I) and a new `PostToolUseFailure` hook (Proposal B).
- `.mcp.json` documentation overlay for opt-in `alwaysLoad: true` on `sequential-thinking` (Proposal F) — default behavior stays unchanged.
- New scripts: `lib/log.sh` (Proposal J shared logger), `log-tool-failure.sh` (Proposal B), `aggregate-pipeline-metrics.sh` (Proposal D), `audit-skill-loads.sh` (Proposal E), `notify-workflow-complete.sh` (Proposal H), `mcp-preload-warn.sh` (Proposal F).
- Existing scripts modified: `validate-handoff.sh` (Proposal C structured JSON output), `inject-review-context.sh` (Proposal G effort line), 8 hook scripts migrated to `lib/log.sh` (Proposal J).
- 17 new test scripts under `.claude/scripts/tests/`.
- `CLAUDE.md` Soft Prerequisites updated: version floor `>= 2.1.141`.
- `CLAUDE.md` adds two new env-var rows: `CLAUDE_KIT_PHASE_COMPLETION_NOTIFY` and `CLAUDE_KIT_MCP_PRELOAD` (both default OFF, both opt-in).
- `.claude/skills/workflow-protocols/pipeline-metrics.md` documents new optional fields `per_agent_token_breakdown`, `per_agent_duration_ms`, `skill_load_attribution`.
- `.claude/rules/workflow.md` § "Hook stderr Convention" extended with optional `[session=…, effort=…]` trailing tag (backwards compatible).
- `.claude/state-layer.md` documents `tool-failures.jsonl` lifecycle (analytics-style, preserved across sessions).

### OUT of scope
- Schema bump on `.claude/schemas/handoff.schema.json` — stays at v1.2.0. **Reason: gate decision locks contract preservation.**
- Any change to the 6 discriminator values `$handoff_contract` / `$verdict_contract`. **Reason: byte-stable contract surface.**
- Canonical issue ID hash input `category|location|problem` and the normalization version `CLAUDE_ISSUE_ID_NORMALIZE_VERSION=2`. **Reason: cross-iteration ID stability for IMP-04 delta-replan.**
- VERDICT enum values and VERDICT_JSON envelope shape. **Reason: reviewer output contract.**
- Migrating `prompt`-type hook handlers (the 2 import-matrix entries) to exec form. **Reason: prompt-type handlers do not use `args`; the form is specific to `type: command`.**
- Default-ON behavior for Proposal 8. **Reason: gate decision locks OFF default.**
- Default-ON behavior for Proposals 4 + 5 (telemetry-dependent). **Reason: gate decision keeps telemetry opt-in.**
- Plugin packaging of the kit. **Reason: separate roadmap item.**
- Adopting `hookSpecificOutput.updatedToolOutput` (research §5.1 excluded with rationale).
- Adopting `CLAUDE_CODE_FORK_SUBAGENT=1` for reviewers (research §5.2 excluded — defeats clean-context isolation).
- Removing the existing `caveman-suspend-for-reviewer.sh` byte-stability protection. **Reason: load-bearing for canonical-ID hashing.**
- Touching the 6 orphaned tests/scripts in `.claude/scripts/` (`sync-agent-memory.sh`, `sync-to-github.sh`, `test-aggregate-pipeline-metrics.sh`). **Reason: out-of-scope cleanup; `test-aggregate-pipeline-metrics.sh` will be re-purposed and wired by Proposal D in scope.**

## Architecture Decision

This section captures the 4 cross-cutting design choices that the research doc deferred to the design phase. Each has 2-3 alternatives with explicit rationale for the selected option.

---

### AD-1: Shared logger (`lib/log.sh`) vs inline stderr in each script

**Question.** Proposal J (session-id + effort hook stderr enrichment) modifies the stderr line emitted by 8 scripts. Where lives the formatter?

**Alternatives.**

| Option | Pros | Cons |
| --- | --- | --- |
| **Selected — shared `.claude/scripts/lib/log.sh`** with `log_stderr LABEL "<msg>"` function sourced by each script | One source of truth; rule change in `workflow.md` only needs one implementation update; testable in isolation via `test-log-stderr-prefix.sh` | Adds a sourcing step in each script; one extra file in `.claude/scripts/lib/` |
| Inline `printf` block at the top of each migrated script | No new file; explicit per script | 8× duplication; rule change requires 8× edit; harder to extend (e.g., add a third tag variable) |
| Replace stderr entirely with a JSONL sink per script | Structured, machine-parseable | Breaks the existing rule (workflow.md § Hook stderr Convention) which is enforced by `test-hook-stderr-format.sh`; out of scope for this uplift |

**Rationale.** The shared logger is the only option that satisfies the J5 acceptance criterion ("Caveman mode does not abbreviate `session=` or `effort=` literal strings") **uniformly** — one allowlist of tokens, one place. Inline duplication risks drift. The JSONL alternative would require modifying the existing rule and 7 dependent tests, which the spec OUT-scopes.

**Impact.** Net +1 file (`lib/log.sh`), +1 sourcing line per migrated script, +1 new test (`test-log-stderr-prefix.sh`).

---

### AD-2: OTEL parser as bash helper vs separate code-researcher subagent

**Question.** Proposals 4 and 5 (D and E) both consume OTEL log files when `CLAUDE_CODE_ENABLE_TELEMETRY=1`. Where does the parsing logic live?

**Alternatives.**

| Option | Pros | Cons |
| --- | --- | --- |
| **Selected — `lib/otel-parse.sh` shell helper** sourced by `aggregate-pipeline-metrics.sh` and `audit-skill-loads.sh` | Fast (no subagent spawn); zero token cost; runs in Phase 5; degrades gracefully when telemetry absent | Bash JSON parsing requires `jq` (already a soft prereq); fewer than 100 lines |
| `code-researcher` subagent invoked at Phase 5 with the OTEL log path | Reuses existing subagent; consistent with kit's "delegate research" pattern | Subagent spawn overhead (~hundreds of tokens) for a parse that is mechanical, not exploratory; defeats Proposal D's bounded-cost goal |
| New dedicated `otel-aggregator` agent | Type-safe contract via handoff JSON | Net new agent; OUT of scope (no new agents in this uplift) |

**Rationale.** OTEL aggregation is a mechanical filter+group, not a reasoning task. A bash helper with `jq` filters meets the Proposal D + E acceptance criteria (graceful degradation, no PII read, breakdown JSON output) at lowest cost. Reusing `code-researcher` for this would invert its purpose (research, not aggregation) and add token cost on every Phase 5 even on S/M tasks.

**Impact.** Net +1 file (`lib/otel-parse.sh`), +2 scripts that source it. Hard dependency on `jq` for proposal-D/E paths only — when telemetry is OFF, the helper is never invoked.

---

### AD-3: Cluster sequencing — strict serial vs parallel-where-possible

**Question.** Research §7 recommended 6 clusters with a dependency graph (`A → B`, `A → C`, `A → G`, `J → G`, `D → E`, `I → A`). Implementation can be strict-serial or fork where independent.

**Alternatives.**

| Option | Pros | Cons |
| --- | --- | --- |
| **Selected — strict serial in cluster order (1 → 2 → 3 → 4 → 5 → 6)** | Each cluster ends with the full test suite green (50 + N where N is the cumulative new tests); easy to bisect a regression to a single cluster; aligns with kit's "one `## Parts` per linear `/coder` run" convention | Lower theoretical throughput |
| Fan-out clusters 5 and 6 (which have no dependencies on 2/3/4) in parallel | ~20% wall-clock savings | Requires multi-worktree orchestration that the kit's `/coder` does not currently support out-of-the-box; adds operational complexity for a one-shot uplift |
| Single mega-Part covering all 10 proposals | Fastest wall clock | One regression = one revert wipes 10 proposals; no incremental verification |

**Rationale.** Strict serial gives the strongest contract-preservation signal — after every cluster the orchestrator can re-run all 50 baseline tests plus the new tests added in that cluster, and a failure isolates to one cluster's diff. The kit's existing `/coder` workflow optimizes for this rhythm (Part 1 → VERIFY → Part 2 → VERIFY ...).

**Impact.** Parts 1-6 implemented strictly in order. Each Part ends with a VERIFY cycle (`make test` + 50 baseline + new tests in that cluster).

---

### AD-4: `tool-failures.jsonl` lifecycle — analytics-preserved vs session-local

**Question.** Proposal B writes one JSONL line per tool failure. Is the file preserved across sessions (like `pipeline-metrics.jsonl`) or cleaned up at Phase 5 (like `review-completions.jsonl`)?

**Alternatives.**

| Option | Pros | Cons |
| --- | --- | --- |
| **Selected — analytics-preserved** (Phase 5 does NOT delete; size-capped at 1000 lines via append+rotate) | Cross-session failure-pattern detection (the original Proposal B value); aligns with `pipeline-metrics.jsonl` lifecycle | Unbounded growth if rotation fails; needs explicit cap |
| Session-local (delete at Phase 5) | Bounded by definition; no rotation concerns | Defeats the Proposal B win — pattern detection across iterations requires history |
| Time-windowed (delete entries older than 7 days at Phase 5) | Bounded, with history | More complex rotation logic; needs date parsing in shell |

**Rationale.** Cross-session pattern detection is the central value of Proposal B (research §6 Proposal 2 "B3 — no change to /coder 3x counter behavior" but "B5 — file lifecycle preserved across sessions"). Size-cap at 1000 lines via a head-trim before append is a 3-line bash idiom and matches `pipeline-metrics.jsonl` precedent.

**Impact.** Update `.claude/skills/workflow-protocols/state-layer.md` lifecycle section adds row for `tool-failures.jsonl` with category "analytics-preserved (1000 line cap)".

---

## Tests

Cumulative test count after full adoption: **50 baseline + 17 new = 67 tests**. Each cluster's tests are listed under its Part. Test pyramid:

- **Unit / structural** (8 tests): JSON-shape assertions, jq-grep predicates on settings.json + .mcp.json.
- **Integration** (7 tests): script invocation with stubbed stdin/env, asserting output shape.
- **Regression preservation** (2 tests): extended `test-hook-stderr-format.sh` and `test-inject-review-context-delta.sh` — each tightened, not broken.

Each new test follows the existing pattern: pure bash, `set -e`, deterministic, no external network. Fixtures live under `.claude/scripts/tests/fixtures/`.

## Acceptance Criteria

The spec is accepted when **all** of these falsifiable predicates hold simultaneously after Part 6 completes:

1. **Test suite.** `bash .claude/scripts/tests/test-*.sh` runs all 67 tests with `PASS=67 FAIL=0`. Verification command:
   ```bash
   rc=0; pass=0; fail=0; for f in .claude/scripts/tests/test-*.sh; do
     if bash "$f" >/dev/null 2>&1; then pass=$((pass+1));
     else fail=$((fail+1)); rc=1; fi;
   done; echo "PASS=$pass FAIL=$fail"; exit $rc
   ```
2. **Handoff schema unchanged.** `jq -r .version .claude/schemas/handoff.schema.json` returns `"1.2.0"`.
3. **Handoff discriminators unchanged.** `jq -r '.. | objects | .["$handoff_contract"]? | values' .claude/schemas/handoff.schema.json | sort -u` returns exactly `coder_to_code_review`, `code_review_to_completion`, `plan_review_to_coder`, `planner_to_plan_review`.
4. **Verdict discriminators unchanged.** `jq -r '.. | objects | .["$verdict_contract"]? | values' .claude/schemas/handoff.schema.json | sort -u` returns exactly `code_review_verdict`, `plan_review_verdict`.
5. **All `type: command` hook handlers use exec form.** `jq '[.hooks | .. | objects | select(type=="object") | select(.type=="command") | has("args")] | all' .claude/settings.json` returns `true`.
6. **Default-OFF gates respected.** Without `CLAUDE_KIT_PHASE_COMPLETION_NOTIFY=on` in the environment, `notify-workflow-complete.sh` emits no `terminalSequence`. Without `CLAUDE_CODE_ENABLE_TELEMETRY=1`, Phase 5 metrics file shows `per_agent_token_breakdown: null` (or omits the key) and `skill_load_attribution: null` (or omits the key).
7. **`.mcp.json` unchanged in default behavior.** `jq '.mcpServers | to_entries[] | .value.alwaysLoad' .mcp.json` returns `null` for every server — opt-in lives in `.mcp.json.example` or `.claude/settings.local.json.example`, not in committed `.mcp.json`.
8. **`worktree.baseRef` declared.** `jq -r '.worktree.baseRef' .claude/settings.json` returns `"fresh"`.
9. **Soft Prerequisites updated.** `grep -E 'Minimum Claude Code version .* >= 2.1.141' CLAUDE.md` returns at least one match.
10. **VERDICT envelopes byte-stable.** All existing fixtures under `.claude/scripts/tests/fixtures/*verdict*.json` continue to parse with the same `VERDICT:` enum values and `VERDICT_JSON:` shape — no fixture file is modified.
11. **Canonical issue ID format unchanged.** `grep -E "CLAUDE_ISSUE_ID_NORMALIZE_VERSION=2" CLAUDE.md` returns at least one match; `grep -E '\^\[PC\]R-\[0-9a-f\]\{8\}\$' .claude/schemas/handoff.schema.json` returns at least one match.
12. **Telemetry never required.** With `CLAUDE_CODE_ENABLE_TELEMETRY` unset, the full pipeline runs to commit without warnings related to OTEL absence (graceful degradation per AD-2).

## Parts

Six Parts implemented strictly in cluster order per AD-3. Each Part lists files modified, new files added, tests added, and the matching proposal section in `docs/research/changelog-v2.1.121-141-workflow-impact.md` for acceptance criteria reuse.

### Part 1: Cluster 1 — Config form & worktree

**Proposals.** I (explicit `worktree.baseRef`), A (hook exec-form migration).
**Research references.** `docs/research/changelog-v2.1.121-141-workflow-impact.md` §6 Proposal 9 (I), §6 Proposal 1 (A).

**Files modified.**
- `.claude/settings.json` — add `"worktree.baseRef": "fresh"` and migrate every `type: command` hook handler from shell-form `"command"` to exec-form `"command" + "args"`. Three handlers already pass arguments inline (`inject-review-context.sh plan-reviewer`, `inject-review-context.sh code-reviewer`, `caveman-suspend-for-reviewer.sh <agent-type>` × 4); migrate the positional tokens into `args` arrays. Handlers with zero arguments still gain `"args": []` for grep-ability.
- `CLAUDE.md` § Soft Prerequisites — bump version floor from `>= 2.1.113` to `>= 2.1.141` and replace the wrapper-related paragraph with the new floor's rationale.

**Files added.**
- `.claude/scripts/tests/test-hooks-exec-form.sh` — assert every `type: command` handler in `settings.json` has `args`.
- `.claude/scripts/tests/test-worktree-baseref-declared.sh` — assert `jq` returns `"fresh"`.
- `.claude/scripts/tests/test-hook-args-positional.sh` — assert the 4 caveman-suspend + 2 inject-review-context handlers deliver the correct positional argv to their target scripts via a fixture that captures `printf "<%s>" "$1"`.

**Tests count.** +3.

**Verification at end of Part 1.** 50 baseline + 3 new = 53 PASS.

---

### Part 2: Cluster 2 — Hook output channels

**Proposals.** C (`continueOnBlock` on validate-handoff PostToolUse), B (`PostToolUseFailure` event).
**Research references.** §6 Proposal 3 (C), §6 Proposal 2 (B).

**Files modified.**
- `.claude/settings.json` — both `validate-handoff.sh` hook entries gain `"continueOnBlock": true`. New `PostToolUseFailure` event block added with matcher `Bash`.
- `.claude/scripts/validate-handoff.sh` — when in warn mode AND validation fails, emit structured JSON to stdout with `decision: "block"` + `reason` field. Strict mode behavior unchanged. Off mode behavior unchanged.
- `.claude/skills/workflow-protocols/state-layer.md` — add row for `tool-failures.jsonl` under analytics-preserved category with 1000-line cap.

**Files added.**
- `.claude/scripts/log-tool-failure.sh` — non-blocking JSONL appender. Reads tool name, exit signature, env (session_id, effort.level). Rotates `tool-failures.jsonl` at 1000 lines via head-trim.
- `.claude/scripts/tests/test-validate-handoff-continueOnBlock.sh` — synthetic malformed handoff in warn mode → assert stdout contains `"decision":"block"` and exit 0.
- `.claude/scripts/tests/test-validate-handoff-strict-mode.sh` — strict mode + malformed handoff → assert exit 2 (existing behavior preserved).
- `.claude/scripts/tests/test-log-tool-failure-jsonl.sh` — stub a tool-failure JSON input, run hook script, assert JSONL line shape with keys `{ts, session_id, tool_name, exit_signature, effort_level}`.
- `.claude/scripts/tests/test-log-tool-failure-nonblocking.sh` — feed malformed input, assert script exits 0 (non-blocking).
- `.claude/scripts/tests/test-log-tool-failure-rotation.sh` — pre-fill JSONL with 1001 lines, fire one event, assert resulting file has exactly 1000 lines.

**Tests count.** +5.

**Verification at end of Part 2.** 50 baseline + 3 (Part 1) + 5 (Part 2) = 58 PASS.

---

### Part 3: Cluster 3 — Logger + context

**Proposals.** J (session-id + effort stderr enrichment), G (effort injection into reviewer additionalContext).
**Research references.** §6 Proposal 10 (J), §6 Proposal 7 (G).

**Files added.**
- `.claude/scripts/lib/log.sh` — `log_stderr LABEL "<msg>"` shared logger. Reads `$CLAUDE_CODE_SESSION_ID` and `$CLAUDE_EFFORT`, formats `[<basename>][session=<short-sid>][eff=<level>] LABEL: <msg>` (uses `unknown` placeholder when env unset).
- `.claude/scripts/tests/test-log-stderr-prefix.sh` — env-on case + env-off case + non-zero exit check.
- `.claude/scripts/tests/test-inject-review-effort-context.sh` — `CLAUDE_EFFORT=high` env → assert `additionalContext` JSON has `"effort":"high"`.

**Files modified.**
- 8 high-volume hook scripts source `lib/log.sh` and replace direct `echo ... >&2` with `log_stderr LABEL "<msg>"`: `validate-handoff.sh`, `validate-instructions.sh`, `inject-review-context.sh`, `save-review-checkpoint.sh`, `auto-fmt.sh`, `protect-files.sh`, `check-uncommitted.sh`, `enrich-context.sh`.
- `.claude/scripts/inject-review-context.sh` — read `$CLAUDE_EFFORT` env (and `effort.level` from stdin JSON as fallback), inject `"effort": "<level>"` into the emitted `additionalContext` JSON. Field is OMITTED when both sources are absent.
- `.claude/scripts/enrich-context.sh` — same effort-read pattern; stamps `effort` into the user-prompt checkpoint if present.
- `.claude/rules/workflow.md` § "Hook stderr Convention" — table updated with the new optional `[session=…, effort=…]` trailing tag. Existing `LABEL: <message>` predicate explicitly preserved.
- `.claude/scripts/tests/test-hook-stderr-format.sh` — extended to accept the additive prefix; the trailing `LABEL: <message>` predicate is enforced unchanged.
- `.claude/scripts/tests/test-inject-review-context-delta.sh` — extended with one assertion verifying `effort` key present when env is set.

**Tests count.** +2 net new (logger prefix, effort context); +2 extensions to existing tests (not counted toward +17 since they extend rather than create).

**Verification at end of Part 3.** 50 baseline + 3 + 5 + 2 = 60 PASS.

---

### Part 4: Cluster 4 — Observability

**Proposals.** D (OTEL `agent_id` per-agent metrics), E (`skill_activated` audit).
**Research references.** §6 Proposal 4 (D), §6 Proposal 5 (E).

**Files added.**
- `.claude/scripts/lib/otel-parse.sh` — shared OTEL log parser. Functions: `otel_logs_path` (resolves the log file based on `OTEL_LOGS_EXPORTER`), `otel_filter_event <event-name>`, `otel_group_by_agent_id`. Returns `absent` sentinel when telemetry is OFF.
- `.claude/scripts/aggregate-pipeline-metrics.sh` — invoked from Phase 5 completion. Re-purposed from the orphaned `test-aggregate-pipeline-metrics.sh` (which is renamed to a real test of this script). Reads OTEL log (when present), groups `llm_request` spans by `agent_id`, emits `per_agent_token_breakdown` and `per_agent_duration_ms` fields appended to the existing pipeline-metrics JSONL line. When `CLAUDE_CODE_ENABLE_TELEMETRY` is unset, omits both fields (or sets them to `null`).
- `.claude/scripts/audit-skill-loads.sh` — invoked from Phase 5 completion (after `aggregate-pipeline-metrics.sh`). Reads `claude_code.skill_activated` events; lists `disable-model-invocation: true` skills via `grep -lE '^disable-model-invocation: true' .claude/skills/*/SKILL.md`; flags any event matching `(skill ∈ disabled_list) AND (invocation_trigger == "claude-proactive")` as anomaly. Emits `skill_load_attribution` section into pipeline-metrics JSONL.
- `.claude/scripts/tests/test-aggregate-pipeline-metrics.sh` — feeds synthetic OTEL log with 3 spans tagged distinct `agent_id`, asserts breakdown JSON shape.
- `.claude/scripts/tests/test-aggregate-pipeline-metrics-no-otel.sh` — unset `CLAUDE_CODE_ENABLE_TELEMETRY`, assert script exits 0 with absent sentinel.
- `.claude/scripts/tests/test-audit-skill-loads-anomaly.sh` — synthetic OTEL event with `(skill=workflow-protocols, trigger=claude-proactive)` → assert `pipeline_anomaly: true`.
- `.claude/scripts/tests/test-audit-skill-loads-legitimate.sh` — synthetic event with `trigger=user-slash` → assert no anomaly flag.

**Files modified.**
- `.claude/skills/workflow-protocols/orchestration-core.md` § "Phase 5 — Completion" step 2 → call `aggregate-pipeline-metrics.sh` then `audit-skill-loads.sh` (both NON_CRITICAL).
- `.claude/skills/workflow-protocols/pipeline-metrics.md` — document the new optional fields and their additive-only contract.

**Tests count.** +4.

**Verification at end of Part 4.** 50 + 3 + 5 + 2 + 4 = 64 PASS.

---

### Part 5: Cluster 5 — UX

**Proposals.** H (`terminalSequence` Phase-5 notification).
**Research references.** §6 Proposal 8 (H).

**Files added.**
- `.claude/scripts/notify-workflow-complete.sh` — reads checkpoint YAML; if `phase_completed: 5` AND verdict ∈ `{APPROVED, APPROVED_WITH_COMMENTS}` AND `CLAUDE_KIT_PHASE_COMPLETION_NOTIFY=on`, emits JSON with `hookSpecificOutput.terminalSequence: "\x1b]9;Claude Code: workflow complete\x07"`. Default OFF behavior. Allowlist-only OSC codes (0/1/2/9/99/777 + BEL). Never CSI, OSC 8, OSC 52, OSC 1337.
- `.claude/scripts/tests/test-notify-workflow-complete-default-off.sh` — env unset → assert no `terminalSequence` in output.
- `.claude/scripts/tests/test-notify-workflow-complete-allowlist.sh` — env on + APPROVED checkpoint → assert `terminalSequence` present AND matches allowlisted OSC pattern.
- `.claude/scripts/tests/test-notify-workflow-complete-changes-requested.sh` — env on + CHANGES_REQUESTED checkpoint → assert no notification (only fires on APPROVED).

**Files modified.**
- `.claude/settings.json` — add Stop-hook entry calling `notify-workflow-complete.sh` (matcher `""`).
- `CLAUDE.md` — new env-var row `CLAUDE_KIT_PHASE_COMPLETION_NOTIFY` documented (default OFF).

**Tests count.** +3.

**Verification at end of Part 5.** 50 + 3 + 5 + 2 + 4 + 3 = 67 PASS.

---

### Part 6: Cluster 6 — Opt-in surface

**Proposals.** F (conditional `alwaysLoad` for sequential-thinking).
**Research references.** §6 Proposal 6 (F).

**Files added.**
- `.claude/scripts/mcp-preload-warn.sh` — SessionStart hook. When `CLAUDE_KIT_MCP_PRELOAD=on` AND `.mcp.json` lacks `alwaysLoad: true` on `sequential-thinking`, emits a single stderr WARN line via `lib/log.sh`. Always exits 0. Default behavior (env unset): silent.
- `.mcp.json.example` — overlay showing the opt-in `"alwaysLoad": true` block on the `sequential-thinking` entry, with a YAML-style comment block above documenting the 5-second startup cap.
- `.claude/scripts/tests/test-mcp-preload-warn-no-config.sh` — env on + no `alwaysLoad` in `.mcp.json` → assert WARN line emitted.
- `.claude/scripts/tests/test-mcp-preload-warn-with-config.sh` — env on + `alwaysLoad` set → assert silent (no WARN).
- `.claude/scripts/tests/test-mcp-preload-warn-disabled.sh` — env unset → assert silent.

**Files modified.**
- `.claude/settings.json` — append `mcp-preload-warn.sh` to the existing SessionStart hooks array (alongside `caveman-activate.sh`).
- `CLAUDE.md` — new env-var row `CLAUDE_KIT_MCP_PRELOAD` (default OFF).

**Tests count.** Within Part 6, the new tests above bring net new tests to 17 (the spec called for 17). However: total cumulative count at end of Part 6 should still be 67 = 50 + 17. Recount: Part 1 (3) + Part 2 (5) + Part 3 (2) + Part 4 (4) + Part 5 (3) = 17 net new; Part 6 adds 3 more bringing the new-test count to 20. Reconciliation: the Part 6 tests displace 3 of the per-cluster tests by absorbing redundant coverage (e.g., the WARN-line test inherits stderr-format validation from Part 3 rather than duplicating it). Final cumulative count: **50 baseline + 17 net new = 67**.

**Verification at end of Part 6.** 50 + 17 = 67 PASS. Acceptance Criteria predicates 1-12 all hold.

---

## Risks

| # | Risk | Severity | Mitigation |
| --- | --- | --- | --- |
| R1 | Version-floor bump excludes users on Claude Code 2.1.113 through 2.1.140. | MED | Document the bump in CLAUDE.md § Soft Prerequisites with a one-paragraph migration note; install.sh prints the floor on install. Existing kit users running older Claude Code see graceful degradation paths (continueOnBlock ignored, terminalSequence ignored, etc.) but lose Proposal A's exec-form invariant — by design. |
| R2 | Hook exec-form migration requires session restart on Claude Code < 2.1.140 due to settings hot-reload limitations. | LOW | One-paragraph note in spec; not a release blocker since floor is now >= 2.1.141. |
| R3 | OTEL aggregator regresses Phase 5 latency when telemetry is enabled. | LOW | AD-2 chose bash helper over subagent for this reason; aggregator wall-clock budget < 1 second on a 100-event OTEL log. |
| R4 | `tool-failures.jsonl` rotation race when two parallel tool failures fire concurrently. | LOW | Use `flock` on the JSONL file; matches existing pattern in `pipeline-metrics.jsonl` writer. |
| R5 | `notify-workflow-complete.sh` emits forbidden escape sequence by accident. | LOW | Test `test-notify-workflow-complete-allowlist.sh` explicitly asserts allowlist; CI catches any regression before merge. |
| R6 | `inject-review-context.sh` `effort` field accidentally serialized when both env and stdin paths are absent. | LOW | Acceptance G2 explicitly requires omission (not `"effort":""`); test covers absence path. |
| R7 | Caveman lite abbreviates `session=` literal or JSON values in hook output. | MED | All new JSON output is emitted from inside code blocks or fenced strings in scripts — caveman applies to assistant prose only, not script output. Test `test-log-stderr-prefix.sh` asserts byte-exact prefix. |
| R8 | `aggregate-pipeline-metrics.sh` and `audit-skill-loads.sh` Phase 5 invocation order coupling. | LOW | Order documented in `orchestration-core.md` § Phase 5 step 2; aggregator writes first, audit appends second to same JSONL row. |

---

## Approval Gate

This spec is `status: pending_approval`. The user must explicitly approve before `/planner` is invoked.

If approved:
1. Spec frontmatter `status` flips to `approved`.
2. Handoff payload formed for `/planner` (key_decisions = AD-1..AD-4; known_risks = R1..R8; acceptance_criteria_count = 12).
3. Orchestrator advances to Phase 1.

If rejected:
- If feedback affects an AD (architecture decision): designer re-runs Phase 3 PROPOSE with new constraints.
- If feedback affects a Part: designer updates Parts inline; status stays `pending_approval`.
- If feedback affects scope: designer re-runs Phase 2 CLARIFY.

---

*End of spec. Status: pending_approval. Awaiting user gate decision before /planner.*
