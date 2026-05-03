# Task: Native Claude Code Memory Mechanism — Fix

## Context

Claude Code v2.1.118 ships two independent native memory mechanisms — auto-memory
(`~/.claude/projects/<slug>/memory/`, machine-local, written by main session) and
subagent memory (`.claude/agent-memory/<name>/`, project-shared, written by
agents declaring `memory: project`). The kit has both partially wired but has 5
defects that produce the observed "memoization not working" symptom plus 2
unrelated pre-existing test failures that block the "all tests pass" constraint.

Fixes are additive and strictly narrowing on the contract surface. Phase
handoff schemas (`handoff.schema.json` 1.2.0), verdict envelope, canonical
issue ID hash, and Caveman boundary clauses are NOT touched.

Source artifacts:

- Approved spec: `.claude/prompts/native-memory-mechanism-spec.md`
- Research: `.claude/prompts/native-memory-mechanism-research.md`

## Scope

### IN

- [ ] P-PRE-1 — `export CLAUDE_WORKFLOW_STATE_DIR` after `mktemp -d` in 3 test files (test fixture isolation)
- [ ] P-PRE-2 — `validate-handoff.sh` `full_output` 800-char + suffix cap with `CLAUDE_VALIDATION_DETAIL_FULL_OUTPUT_CAP` env override
- [ ] P1 — 3 baseline `.claude/agent-memory/<agent>/MEMORY.md` files + `agent-memory-protocol.md` updates (first_run trigger + 3-question rubric)
- [ ] P2 — `.claude/commands/workflow.md` step 0.06 (memory freshness scan) + `CLAUDE.md` env-var entry for `CLAUDE_MEMORY_FRESHNESS_MODE`
- [ ] P3 — Remove `/Users/dmitriym` paths from `.claude/settings.json` lines 50-51
- [ ] P4 — Reconcile tool permissions on `code-researcher.md` (drop allowlist) and `plan-reviewer.md` (remove Edit from disallowedTools); reconcile RULE prose
- [ ] P5 — `## Memory Mechanisms` section (≤30 lines) added to `CLAUDE.md`

### OUT

- Override auto-memory location project-wide (`autoMemoryDirectory` rejected from project settings by design — Claude Code feature, not kit config)
- Schema changes to `handoff.schema.json` / `verdict.schema.json` (constraint: byte-stable contracts)
- Migrating existing artifacts under `.claude/prompts/` (user instruction: ignore existing plans/specs)
- Touching content inside `~/.claude/projects/<slug>/memory/` (auto-memory is owned by main session, not kit)
- Removing custom worktree round-trip scripts (`prepare-worktree.sh`, `sync-agent-memory.sh`) — required for code-reviewer's `isolation: worktree`; native does not propagate writes out of cleaned-up worktrees
- Renaming `.claude/agent-memory/` to a non-canonical path — would break native loader

## Architecture Decision

**Selected approach: Hybrid — native primitives + targeted custom infra**

Keep `memory: project` frontmatter as the canonical declaration. Trust Claude
Code's native loader to inject the first 200 lines / 25 KB of
`.claude/agent-memory/<name>/MEMORY.md` into each subagent's system prompt and
to auto-grant Read/Write/Edit on that dir per the official
`/sub-agents#enable-persistent-memory` docs. Keep the existing custom
worktree round-trip scripts because native does not handle the worktree-cleanup
edge case that code-reviewer triggers (`isolation: worktree`). Fix the 5
defects in place: create baselines, add freshness check, remove hardcoded
paths, align tool permissions with the auto-grant, document the dual-mechanism
split.

### Alternatives considered (3, rejected 2)

- **Pure native (remove custom protocol + worktree scripts).** Rejected: code-reviewer runs with `isolation: worktree`; native does not propagate memory writes back to main repo on worktree cleanup → memory updates from code-reviewer would be silently discarded. Existing tests assert custom-protocol behavior (worktree sync, freshness modes).
- **Tests-only (only fix the 4 failing tests, skip P3/P4/P5).** Rejected: Leaves hardcoded `/Users/dmitriym` paths in committed config (user-stated constraint violation), leaves tool-permission conflicts that silently block agent memory updates via Edit, leaves CLAUDE.md doc gap that caused the user's diagnosis question.

### Key decisions (6)

1. **Author static baseline `MEMORY.md` files at the canonical native paths.** Native creates the dir on first write; absent baselines, every first run sees empty injection. Tests already gate the structure (specific H2 sections per agent, ≤80 lines).
2. **Add `step: 0.06` after `step: 0.05` (PK sanity) and before `step: 0` (Task Analysis).** Mirrors the existing PROJECT-KNOWLEDGE.md pre-flight pattern. Default `warn` non-blocking; opt-in `strict` via env var.
3. **Generalize the `git tag --list` permission rule to `Bash(git tag *)` and remove the self-referential grep diagnostic.** Permission widening is strictly more permissive; never blocks pipeline. The grep rule was a one-shot debug utility.
4. **Drop `tools` allowlist on code-researcher (inherit all) AND remove `Edit` from plan-reviewer's `disallowedTools`.** Native auto-grants R/W/E for the memory dir; explicit denylist almost certainly overrides the auto-grant. Role discipline (RULE prose) keeps codebase off-limits while permitting memory updates.
5. **Add a `## Memory Mechanisms` section to CLAUDE.md (≤30 lines) cross-referencing both native paths.** User's diagnosis question ("is this `memory: project` frontmatter?") is direct evidence of the doc gap.
6. **Sequence pre-condition cleanups (P-PRE-1, P-PRE-2) BEFORE memory fixes (P1..P5).** Test-pass count is monotonic (47 → 48 → 49 → 50 → 51); no test ever flips green→red mid-implementation.

### Sequential Thinking validation

| Question | Answer |
|---|---|
| Does any Part touch `.claude/schemas/*.json`? | NO — verified by file-touch matrix below |
| Does any Part touch `handoff-protocol.md` IMP-02/03/04 sections? | NO |
| Does any Part touch caveman boundary clauses? | NO |
| Are Parts mutually independent? | YES — disjoint files; no Part depends on a later Part |
| Is the 7-step order necessary? | Operational only (test-pass monotonicity) — semantic correctness independent of order |

## Tests

Before any Part: `for f in .claude/scripts/tests/test-*.sh; do bash "$f" >/dev/null 2>&1 || { rc=1; echo "FAIL: $(basename "$f")"; }; done` → expect 4 FAIL (47/51 PASS).

After each Part: rerun the same loop. Expected progression:

| After Part | New PASS count | Newly green test |
|---|---|---|
| Baseline (none) | 47/51 | — |
| Part 1 (P-PRE-1) | 48/51 | `test-test-fixture-isolation.sh` |
| Part 2 (P-PRE-2) | 49/51 | `test-validate-handoff-detail-log-cap.sh` |
| Part 3 (P1) | 50/51 | `test-agent-memory-baseline-exists.sh` |
| Part 4 (P2) | 51/51 | `test-memory-freshness-warn.sh` |
| Part 5 (P3) | 51/51 | (no new test; constraint check via grep) |
| Part 6 (P4) | 51/51 | (no new test; agents continue to pass existing tests) |
| Part 7 (P5) | 51/51 | (no new test; doc-only) |

After all Parts: full corpus passes 51/51.

## Acceptance Criteria

### Functional (per-Part, falsifiable)

- AC-PRE-1: `bash .claude/scripts/tests/test-test-fixture-isolation.sh` exits 0.
- AC-PRE-2: `bash .claude/scripts/tests/test-validate-handoff-detail-log-cap.sh` exits 0.
- AC-P1.1..AC-P1.7: `bash .claude/scripts/tests/test-agent-memory-baseline-exists.sh` exits 0; baseline structure verified (3 files × specific H2 sections × ≤80 lines + protocol updates).
- AC-P2.1..AC-P2.7: `bash .claude/scripts/tests/test-memory-freshness-warn.sh` exits 0; step 0.06 placement, scan paths, WARN format, env modes, default `warn`, CLAUDE.md env-var entry verified.
- AC-P3.1: `grep -c '/Users/dmitriym' .claude/settings.json` returns 0.
- AC-P3.2: Permission semantics for `git tag --list` preserved through generic rule (`Bash(git tag *)` or equivalent).
- AC-P3.3: Self-referential grep rule (settings.json line 51) removed.
- AC-P4.1..AC-P4.5: code-researcher.md and plan-reviewer.md tool permissions reconciled with `memory: project` auto-grant.
- AC-P5.1..AC-P5.6: CLAUDE.md has a `## Memory Mechanisms` section ≤30 lines, both paths verbatim, 3-row table, cross-references to docs.

### Final (cross-cutting)

- AC-FINAL-1: All 51 tests under `.claude/scripts/tests/` pass; loop exit code 0.
- AC-FINAL-2: `git diff` does NOT modify any file under `.claude/schemas/`, NOR `handoff-protocol.md` core IMP-02/03/04 sections, NOR `verdict.schema.json`-related code in `save-review-checkpoint.sh:365-370`.
- AC-FINAL-3: `git diff` does NOT modify the Boundaries section of `.claude/skills/caveman/SKILL.md`.
- AC-FINAL-4: `wc -l CLAUDE.md` returns ≤200.

### Architectural

- Phase handoff contracts (planner → plan-review → coder → code-review → completion) byte-stable.
- Verdict envelope (`VERDICT_JSON:`) format unchanged.
- Canonical issue ID hash (`sha256(category|location|problem)[:8]`) unchanged.
- `memory: project` agent frontmatter format remains canonical Claude Code native.
- Hook contract for SubagentStart/SubagentStop unchanged.

## Parts

### Part 1: P-PRE-1 — Test fixture isolation

**Files:** 3× UPDATE
- `.claude/scripts/tests/test-coder-to-codereview-handoff-write.sh`
- `.claude/scripts/tests/test-code-review-to-completion-handoff.sh`
- `.claude/scripts/tests/test-spec-check-failure-after-retry-blocker.sh`

**Description.** Each test creates a sandbox via `FIXTURE_DIR="$(mktemp -d)"`
but never points `CLAUDE_WORKFLOW_STATE_DIR` at it. As a result the
`validate-handoff.sh` invocations during these tests append to the production
`.claude/workflow-state/handoff-validation-detail.log`. Test
`test-test-fixture-isolation.sh:21-27` requires the export within 5 lines
after `mktemp`; the production log line count must remain unchanged after
running each test in sandbox (line 44).

**Snippet to add (verbatim, immediately after the `trap 'rm -rf "$FIXTURE_DIR"' EXIT` line in each file):**

```bash
export CLAUDE_WORKFLOW_STATE_DIR="$FIXTURE_DIR"
```

**Before/after expectation per file.**

`test-coder-to-codereview-handoff-write.sh` line 39-41:

```bash
# BEFORE
FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT
VALID_FIXTURE="$FIXTURE_DIR/valid-handoff.json"

# AFTER
FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT
export CLAUDE_WORKFLOW_STATE_DIR="$FIXTURE_DIR"
VALID_FIXTURE="$FIXTURE_DIR/valid-handoff.json"
```

`test-code-review-to-completion-handoff.sh` line 52-55: identical pattern.

`test-spec-check-failure-after-retry-blocker.sh` line 55-58: identical pattern.

**Verification.** `bash .claude/scripts/tests/test-test-fixture-isolation.sh && echo OK`
exits 0 with `OK` printed. Plus:
`bash .claude/scripts/tests/test-coder-to-codereview-handoff-write.sh`,
`...test-code-review-to-completion-handoff.sh`, and
`...test-spec-check-failure-after-retry-blocker.sh` all continue to pass
individually.

---

### Part 2: P-PRE-2 — `full_output` truncation cap in `validate-handoff.sh`

**File:** UPDATE — `.claude/scripts/validate-handoff.sh`

**Description.** Detail-log entries currently store the unbounded
`VALIDATION_OUTPUT` in the `full_output` field. Test
`test-validate-handoff-detail-log-cap.sh` requires:

- AC-P4.1: `full_output` length ≤ 900 chars (cap 800 + suffix headroom).
- AC-P4.2: Truncation suffix `[truncated — original NNNNN chars]` appended when capped.
- AC-P4.3: When length ≤ 800, suffix MUST be absent.
- AC-P4.4: `error_summary` continues to be capped at 300 chars (existing behavior).
- AC-P4.5: Cap is env-tunable via `CLAUDE_VALIDATION_DETAIL_FULL_OUTPUT_CAP` (test sets it to 400 and expects length ≤ 500).
- AC-P4.6: Existing `test-validate-handoff.sh` rotation tests still pass.
- AC-P4.7: Invalid env value (e.g. `abc`) falls back to default 800.

**Snippet to insert (after line 200, between `MAX_LOG_LINES` setup and the `VALIDATION_OUTPUT` definition is acceptable; concretely after line 153 inside the existing helper section):**

```bash
# ─── P-PRE-2: full_output truncation cap (env-tunable) ─────────────────────────
# Detail-log full_output field is bounded to limit per-line size. Default 800
# chars; override via CLAUDE_VALIDATION_DETAIL_FULL_OUTPUT_CAP. Invalid value
# falls back to default. Truncated output gets a clear suffix indicating original
# length so operators can grep for entries needing investigation.
DETAIL_FULL_OUTPUT_CAP_RAW="${CLAUDE_VALIDATION_DETAIL_FULL_OUTPUT_CAP:-800}"
if [[ ! "${DETAIL_FULL_OUTPUT_CAP_RAW}" =~ ^[0-9]+$ ]] || [[ "${DETAIL_FULL_OUTPUT_CAP_RAW}" -le 0 ]]; then
  DETAIL_FULL_OUTPUT_CAP=800
else
  DETAIL_FULL_OUTPUT_CAP="${DETAIL_FULL_OUTPUT_CAP_RAW}"
fi
```

**Snippet to modify (line 235-243, the `DETAIL_ENTRY=$(jq -n -c ...)` block):**

Replace the `--arg full "${VALIDATION_OUTPUT}"` line with logic that prepares a capped `FULL_OUTPUT_CAPPED` variable beforehand, and use it instead. Concrete diff:

```bash
# BEFORE (around line 231-243)
ERROR_SUMMARY=$(printf '%s\n' "${VALIDATION_OUTPUT}" \
  | tr '\n' ' ' \
  | tr -s ' ' \
  | cut -c1-300)
DETAIL_ENTRY=$(jq -n -c \
  --arg ts "${TIMESTAMP}" \
  --arg file "${HANDOFF_FILE}" \
  --arg kind "${RECORD_KIND}" \
  --argjson rc "${VALIDATION_RC}" \
  --arg summary "${ERROR_SUMMARY}" \
  --arg full "${VALIDATION_OUTPUT}" \
  '{timestamp: $ts, file: $file, record_kind: $kind, rc: $rc, error_summary: $summary, full_output: $full}' \
  2>/dev/null || echo "{}")

# AFTER
ERROR_SUMMARY=$(printf '%s\n' "${VALIDATION_OUTPUT}" \
  | tr '\n' ' ' \
  | tr -s ' ' \
  | cut -c1-300)

# P-PRE-2: cap full_output to DETAIL_FULL_OUTPUT_CAP chars with truncation suffix
FULL_OUTPUT_RAW="${VALIDATION_OUTPUT}"
FULL_OUTPUT_LEN=${#FULL_OUTPUT_RAW}
if [[ "${FULL_OUTPUT_LEN}" -gt "${DETAIL_FULL_OUTPUT_CAP}" ]]; then
  FULL_OUTPUT_CAPPED="${FULL_OUTPUT_RAW:0:${DETAIL_FULL_OUTPUT_CAP}}"$'\n'"[truncated — original ${FULL_OUTPUT_LEN} chars]"
else
  FULL_OUTPUT_CAPPED="${FULL_OUTPUT_RAW}"
fi

DETAIL_ENTRY=$(jq -n -c \
  --arg ts "${TIMESTAMP}" \
  --arg file "${HANDOFF_FILE}" \
  --arg kind "${RECORD_KIND}" \
  --argjson rc "${VALIDATION_RC}" \
  --arg summary "${ERROR_SUMMARY}" \
  --arg full "${FULL_OUTPUT_CAPPED}" \
  '{timestamp: $ts, file: $file, record_kind: $kind, rc: $rc, error_summary: $summary, full_output: $full}' \
  2>/dev/null || echo "{}")
```

**Verification.**

```bash
bash .claude/scripts/tests/test-validate-handoff-detail-log-cap.sh    # exits 0
bash .claude/scripts/tests/test-validate-handoff.sh                   # still passes (rotation regression)
```

---

### Part 3: P1 — Subagent memory baselines + protocol updates

**Files:** 3× CREATE + 1× UPDATE
- CREATE `.claude/agent-memory/code-reviewer/MEMORY.md` (≤80 lines)
- CREATE `.claude/agent-memory/plan-reviewer/MEMORY.md` (≤80 lines)
- CREATE `.claude/agent-memory/code-researcher/MEMORY.md` (≤80 lines)
- UPDATE `.claude/skills/workflow-protocols/agent-memory-protocol.md`

**Description.** Native Claude Code creates the memory dir on first write, but
without seed content the first invocation of each agent runs cold. The test
asserts (1) baseline file presence, (2) specific H2 sections per agent,
(3) ≤80 lines, (4) protocol first_run.trigger covers "missing OR empty",
(5) protocol completion.what_to_save_template carries 3 questions
(novel-this-iteration / user-pushed-back-on-default / non-obvious-project-fact).

**`code-reviewer/MEMORY.md` content (full file, idiomatic seed):**

```markdown
# code-reviewer Memory

Persistent project-shared memory for the `code-reviewer` agent.
Native loader injects the first 200 lines / 25 KB of this file into the
agent system prompt at SubagentStart. Update via Edit; create new topic
files in this dir for detail beyond the 200-line/25KB head.

## Project Conventions

- All agent artifacts under `.claude/agents/` use YAML-first frontmatter; H2 prose follows.
- Hook stderr format: `[<script-basename>] <LABEL>: <message>` (see `.claude/rules/workflow.md`).
- Tests live at `.claude/scripts/tests/test-*.sh`; one assertion per AC-ID.
- Permission denials in `settings.json` are deny-overrides-allow; do not assume auto-grants override denylists.

## Anti-patterns Catalog

- Modifying `handoff.schema.json` for additive fields without bumping schema version (breaks fixture replay).
- Touching Caveman boundary clauses (verbatim contract — IMP-03 ID hash stability depends on it).
- Hardcoding `/Users/<name>/...` paths in committed config files (kit is shared with other users).
- Editing files outside `.claude/agent-memory/code-reviewer/` from this agent — role is read-only on codebase.

## Patterns Catalog

- Small mechanical fixes (test fixture exports, log cap tweaks) bundle well into a single Part with grep predicates.
- New observability signals (WARN at startup, telemetry records) go to stderr / JSONL — never to stdout (would break hook contracts).
- When a fix has a corresponding pre-authored test, the test is the source of truth — derive the implementation from the test predicates, not vice versa.
```

**`plan-reviewer/MEMORY.md` content:**

```markdown
# plan-reviewer Memory

Persistent project-shared memory for the `plan-reviewer` agent.
Native loader injects the first 200 lines / 25 KB at SubagentStart.

## Project Layer Structure

This kit is config-as-code (Markdown + Shell + YAML + JSON). Logical "layers"
correspond to artifact roles:

- Commands (`.claude/commands/`) — orchestrator-context entry points (workflow, planner, coder, designer).
- Agents (`.claude/agents/`) — clean-context review/research workers (plan-reviewer, code-reviewer, code-researcher, verdict-recovery).
- Skills (`.claude/skills/`) — phase-specific protocols loaded on demand.
- Rules (`.claude/rules/`) — path-scoped instructions auto-loaded by Claude Code.
- Hooks/Scripts (`.claude/scripts/`) — deterministic event-fired automation.
- Schemas (`.claude/schemas/`) — JSON Schema contracts for handoff/verdict envelopes.

## Review Checklist Priorities

1. Phase-handoff contract preservation (planner→plan-review→coder→code-review→completion) — byte-stable.
2. Test corpus integrity — every change must keep `.claude/scripts/tests/test-*.sh` green.
3. Project portability — no `/Users/<name>/...` hardcodes; no writes under `~/.claude/`.
4. Caveman boundary preservation (VERDICT lines, JSON sentinels, H2 plan/spec headers).
5. CLAUDE.md size budget ≤200 lines; per-section concision.

## Common Section Gaps

- Plan missing `## Architecture Decision` block when complexity ≥ M.
- Plan missing per-Part verification snippets (test command or grep predicate).
- Spec missing OUT scope items with explicit reasons.
- Plan missing diff-vs-prior-iteration block on iter 2+ (IMP-04 contract).
```

**`code-researcher/MEMORY.md` content:**

```markdown
# code-researcher Memory

Persistent project-shared memory for the `code-researcher` agent.
Native loader injects the first 200 lines / 25 KB at SubagentStart.

## Package Locations

- `.claude/agents/` — agent frontmatter + role docs (5 standalone agents + 3 complex agent dirs: meta-agent, project-researcher, db-explorer).
- `.claude/commands/` — slash commands (workflow, planner, coder, designer, project-researcher, meta-agent, review-checklist).
- `.claude/skills/` — 8 skill packages (workflow-protocols, planner-rules, coder-rules, plan-review-rules, code-review-rules, design-rules, systematic-debugging, tdd-rules).
- `.claude/scripts/` — 24 hook scripts + 1 test dir (`tests/test-*.sh`).
- `.claude/templates/` — 6 templates (plan, spec, agent, command, rule, skill, project-claude-md).
- `.claude/rules/` — 8 path-scoped rules (architecture, go-conventions, testing, workflow, handler/service/repository/models layer rules).

## Key Entry Points

- Pipeline orchestrator: `.claude/commands/workflow.md`.
- Plan output: `.claude/prompts/{feature}.md`.
- Spec output: `.claude/prompts/{feature}-spec.md`.
- Handoff payloads: `.claude/workflow-state/{feature}-handoff.json`.
- Pipeline metrics: `.claude/workflow-state/pipeline-metrics.jsonl`.
- Verdict checkpoint: `.claude/workflow-state/review-completions.jsonl`.

## Codebase Topology

- Top-level: `CLAUDE.md`, `README.md`, `install.sh`, `.claude/`, `.mcp.json`, `caveman/` (vendored upstream skill).
- Native memory: `~/.claude/projects/<slug>/memory/` (auto-memory) vs `.claude/agent-memory/<name>/` (subagent memory).
- Agent isolation: `code-reviewer` runs with `isolation: worktree`; others run in-tree.
- Hook layers: 12 event types in `settings.json`; security hooks unconditional, others use `if:` predicates from v2.1.85.
```

**`agent-memory-protocol.md` updates (UPDATE):**

Two surgical edits:

1. Replace the existing `first_run:` block (lines 26-32 in current file) with a version that handles "missing OR empty":

```yaml
# BEFORE (current)
  first_run:
    trigger: "MEMORY.md does not exist in agent memory dir"
    action: "Initialize MEMORY.md with brief project structure summary"
    what_to_save:
      code-researcher: "Package structure, key entry points"
      code-reviewer: "Project code conventions, common anti-patterns observed"
      plan-reviewer: "Project layer structure, review checklist priorities"

# AFTER
  first_run:
    trigger: "MEMORY.md does not exist in agent memory dir OR file is empty (size==0)"
    action: "Initialize MEMORY.md with brief project structure summary"
    what_to_save:
      code-researcher: "Package structure, key entry points"
      code-reviewer: "Project code conventions, common anti-patterns observed"
      plan-reviewer: "Project layer structure, review checklist priorities"
```

2. Add a `what_to_save_template:` block under `completion:` (after the existing `what_to_save:` block, before the `severity:` line). The block contains a 3-question rubric whose strings are tested verbatim:

```yaml
    what_to_save_template: |
      Self-check before writing:
      1. Was anything novel this iteration that future me should know?
      2. Did the user push back on a previous default or correct an assumption?
      3. Was a non-obvious project fact uncovered (cross-file invariant, hidden constraint)?
      If all three answer "no" → SKIP memory update for this run.
```

**Verification.**

```bash
bash .claude/scripts/tests/test-agent-memory-baseline-exists.sh && echo OK    # exits 0
wc -l .claude/agent-memory/code-reviewer/MEMORY.md      # ≤ 80
wc -l .claude/agent-memory/plan-reviewer/MEMORY.md      # ≤ 80
wc -l .claude/agent-memory/code-researcher/MEMORY.md    # ≤ 80
bash .claude/scripts/tests/test-decision-matrix-consistency.sh  # still 0 (no regression)
```

---

### Part 4: P2 — `workflow.md` step 0.06 + `CLAUDE.md` env-var entry

**Files:**
- UPDATE `.claude/commands/workflow.md`
- UPDATE `CLAUDE.md`

**Description.** Add a memory-freshness pre-flight scan as workflow startup
step 0.06, between step 0.05 (PROJECT-KNOWLEDGE.md sanity) and step 0
(Task Analysis). The step scans both auto-memory and agent-memory paths,
emits a single WARN line if any file is older than 30 days. Default mode
`warn` (non-blocking); opt-in `strict` blocks via exit 2 when complexity ≥ M.

**`workflow.md` insertion** (after the existing step 0.05 block ends, before `step: 0`):

```yaml
    - step: 0.06
      action: "Pre-flight: native memory freshness check"
      tool: "Bash (read-only)"
      check: |
        Scan both memory paths for file mtime:
          ~/.claude/projects/{slug}/memory/MEMORY.md (auto-memory; main session-owned)
          .claude/agent-memory/{plan-reviewer,code-reviewer,code-researcher}/MEMORY.md
        Count files where mtime > 30 days ago. Track oldest age in days.
      mode_env: "CLAUDE_MEMORY_FRESHNESS_MODE (off|warn|strict, default warn)"
      behavior:
        - if: "Mode is off"
          then: "PROCEED silently"
        - if: "Stale count == 0 (no files >30 days)"
          then: "PROCEED silently"
        - if: "Stale count >= 1 AND mode is warn"
          then: "[workflow] WARN: memory N file(s) stale/expired (oldest: NNNN days)"
        - if: "Stale count >= 1 AND mode is strict AND complexity >= M"
          then: "BLOCK; emit FATAL message [workflow] WARN: memory N file(s) stale/expired (oldest: NNNN days) and exit 2"
        - if: "Memory dirs missing entirely (fresh clone — never bootstrapped)"
          then: "PROCEED silently (treat as not-yet-bootstrapped, not stale)"
      exit_on_strict: 2
      probe_for_acceptance: |
        Falsifiable predicate: Touch a file's mtime to >60 days ago, run
        /workflow with default mode, observe exactly one stderr WARN line
        matching the template above.
      purpose: |
        Surfaces the silent staleness that auto-memory and subagent memory can
        accumulate. Default warn-only is non-blocking; opt-in strict is for
        environments where stale memory must be cleared before XL runs proceed.
        Mirrors the step 0.05 PROJECT-KNOWLEDGE.md pre-flight pattern.
```

**`CLAUDE.md` insertion** (in the `**Strict-mode env vars**` bullet list, after `CLAUDE_VERDICT_BLOCK_TTL_HOURS`):

```markdown
- `CLAUDE_MEMORY_FRESHNESS_MODE` — workflow startup step 0.06 memory-staleness scan (auto-memory + agent-memory dirs); values `off|warn|strict`, default `warn`. `strict` blocks runs of complexity ≥ M when any tracked memory file is older than 30 days.
```

**Verification.**

```bash
bash .claude/scripts/tests/test-memory-freshness-warn.sh && echo OK   # exits 0
grep -E 'step: 0\.06' .claude/commands/workflow.md                     # finds 1 line
grep CLAUDE_MEMORY_FRESHNESS_MODE CLAUDE.md                            # finds 1+ line
```

---

### Part 5: P3 — Remove all `/Users/dmitriym` paths from `settings.json`

**File:** UPDATE — `.claude/settings.json`

**Description.** Plan-review (PR-001) found that the file's actual state diverged from earlier reads:
no `git -C /Users/dmitriym/Desktop/claude-kit tag --list` or `grep -rn '/Users/dmitriym...'` rule
exists in the current working tree. Instead, three session-added entries carry user-specific paths
or are feature-specific transient permissions:

- Line 52: `"Bash(git -C /Users/dmitriym/Desktop/claude-kit diff .claude/settings.json)"` — contains `/Users/dmitriym`.
- Line 74: `"/Users/dmitriym/Desktop/claude-kit/.claude/workflow-state"` inside `additionalDirectories` — contains `/Users/dmitriym`.

Two further entries are feature-specific session artifacts that should be cleaned up to keep the
committed kit free of one-off rules:

- Line 50: `"Bash(bash .claude/scripts/validate-handoff.sh .claude/workflow-state/native-memory-mechanism-handoff.json)"`.
- Line 51: `"Bash(CLAUDE_HANDOFF_VALIDATION_MODE=strict bash .claude/scripts/validate-handoff.sh .claude/workflow-state/native-memory-mechanism-handoff.json)"`.

Generic patterns already cover the future need (`Bash(.claude/scripts/tests/*.sh)` is
sufficient; if a generic validate-handoff allow is desired, prefer
`Bash(bash .claude/scripts/validate-handoff.sh*)`).

**Edit specifications.**

1. **Remove lines 50-52** (both feature-specific entries plus the user-path diff command). They were
   added transiently for this session and do not belong in committed config.
2. **Remove the `additionalDirectories` block (lines 73-75)** — `.claude/workflow-state/` is
   inside the project root and accessible without an explicit allow entry. If a future scenario
   genuinely requires `additionalDirectories`, add it via `.claude/settings.local.json` (gitignored,
   per-machine), not the committed `settings.json`.
3. Verify the file is still valid JSON after the deletions (no trailing commas etc.).

**Before** (lines 47-75 in current working tree):

```json
      "Bash(git worktree:*)",
      "Bash(npx markdownlint-cli:*)",
      "Bash(.claude/scripts/tests/*.sh)",
      "Bash(bash .claude/scripts/validate-handoff.sh .claude/workflow-state/native-memory-mechanism-handoff.json)",
      "Bash(CLAUDE_HANDOFF_VALIDATION_MODE=strict bash .claude/scripts/validate-handoff.sh .claude/workflow-state/native-memory-mechanism-handoff.json)",
      "Bash(git -C /Users/dmitriym/Desktop/claude-kit diff .claude/settings.json)"
    ],
    "deny": [
      ...
    ],
    "additionalDirectories": [
      "/Users/dmitriym/Desktop/claude-kit/.claude/workflow-state"
    ]
```

**After:**

```json
      "Bash(git worktree:*)",
      "Bash(npx markdownlint-cli:*)",
      "Bash(.claude/scripts/tests/*.sh)"
    ],
    "deny": [
      ...
    ]
```

The trailing comma on `"Bash(.claude/scripts/tests/*.sh)"` must be removed when it becomes the last
array entry. The `additionalDirectories` array is dropped entirely — it is an OPTIONAL `permissions`
field; absence is the default. The `deny` block is unchanged.

**Updated acceptance criteria for this Part:**

- AC-P3.1: `grep -c '/Users/dmitriym' .claude/settings.json` returns `0`.
- AC-P3.2 (revised): All three session-added Bash permission entries (formerly lines 50-52) are removed.
  Generic rules (`Bash(.claude/scripts/tests/*.sh)`) preserve future test runs without per-feature allowlisting.
- AC-P3.3 (revised): The `additionalDirectories` block is removed. `python3 -c "import json,sys; d=json.load(open('.claude/settings.json')); assert 'additionalDirectories' not in d.get('permissions', {}), 'additionalDirectories still present'"` exits 0.
- AC-P3.4: All currently-passing tests continue to pass.
- AC-P3.5: `python3 -c "import json; json.load(open('.claude/settings.json'))"` succeeds (file is still valid JSON).

**Verification.**

```bash
test "$(grep -c '/Users/dmitriym' .claude/settings.json)" = "0" && echo OK
python3 -c "import json,sys; d=json.load(open('.claude/settings.json')); \
  assert 'additionalDirectories' not in d.get('permissions', {}), 'additionalDirectories still present'; \
  print('JSON valid + additionalDirectories absent')"
for f in .claude/scripts/tests/test-*.sh; do bash "$f" >/dev/null 2>&1 || { echo FAIL: $f; exit 1; }; done; echo ALL_PASS
```

---

### Part 6: P4 — Tool permission reconciliation on memory-enabled agents

**Files:**
- UPDATE `.claude/agents/code-researcher.md`
- UPDATE `.claude/agents/plan-reviewer.md`

**Description.** Per official docs (`/sub-agents#enable-persistent-memory`):
"When memory is enabled... Read, Write, and Edit tools are automatically
enabled so the subagent can manage its memory files." Two of three agents
have explicit tool restrictions that conflict with this auto-grant:

- `code-researcher.md` — `tools: [Read, Grep, Glob, Bash]` allowlist excludes Write+Edit; role text RULE_1 says "You have no Write/Edit tools".
- `plan-reviewer.md` — `disallowedTools: [Edit, Bash]` denies Edit; native deny-overrides-allow likely wins, blocking memory updates via Edit (only Write — overwrite-whole-file — would work).

`code-reviewer.md` already has Write+Edit in its allowlist — no change needed.

**`code-researcher.md` edits.**

1. Drop the explicit `tools` allowlist (the agent will inherit all tools from the main conversation, with the memory auto-grant adding Read/Write/Edit specifically scoped to the memory dir):

```yaml
# BEFORE (lines 6-10)
tools:
  - Read
  - Grep
  - Glob
  - Bash

# AFTER
# (block removed entirely; no tools field — agent inherits from session)
```

2. Update RULE_1 prose (line 26) to reconcile with the memory mechanism:

```markdown
# BEFORE (line 26)
- RULE_1 Read Only: Do NOT modify any files. You have no Write/Edit tools.

# AFTER (line 26)
- RULE_1 Codebase Read Only: Do NOT modify any project files. The only writable surface is `.claude/agent-memory/code-researcher/` (your persistent memory dir, auto-granted by Claude Code's `memory: project` mechanism). Do NOT call Write/Edit on any path outside that dir.
```

**`plan-reviewer.md` edits.**

1. Remove `Edit` from `disallowedTools` (Bash stays disallowed):

```yaml
# BEFORE (lines 14-16)
disallowedTools:
  - Edit
  - Bash

# AFTER
disallowedTools:
  - Bash
```

2. Add an explicit RULE clause scoping Edit to the memory dir. **The current file already has RULE_1..RULE_5** (RULE_5 = "Output First — Turn Budget"). Add the new rule as **`RULE_6 Edit Scope`** at the end of the `## Rules (STRICT)` section:

```markdown
- RULE_6 Edit Scope: Edit is permitted ONLY for files under `.claude/agent-memory/plan-reviewer/`. Any Edit attempt on other paths is a role violation; for plan-file annotations or feedback, use the verdict structure or handoff payload instead.
```

The structural test does not gate the rule number, only the presence of the Edit-scope clause; the
exact "RULE_6" label is chosen to avoid the existing-RULE_5 collision flagged by plan-review (PR-002).

**Verification (concrete, falsifiable per PR-004):**

```bash
# 1. tools allowlist removed from code-researcher.md
! grep -nE '^tools:$' .claude/agents/code-researcher.md && echo "OK: tools allowlist removed"

# 2. Edit absent from plan-reviewer.md disallowedTools block (scoped check)
awk '
  /^disallowedTools:$/ { in_block = 1; next }
  in_block && /^[a-zA-Z_]/ { in_block = 0 }
  in_block && /^\s*-\s*Edit\s*$/ { found = 1 }
  END { exit found ? 1 : 0 }
' .claude/agents/plan-reviewer.md && echo "OK: Edit absent under disallowedTools"

# 3. Role-prose updates (RULE_1 reconciled + RULE_6 added)
grep -q 'Codebase Read Only' .claude/agents/code-researcher.md && \
  grep -qE 'RULE_6 Edit Scope' .claude/agents/plan-reviewer.md && \
  echo "OK: rule prose updated"

# 4. Full test corpus regression check
for f in .claude/scripts/tests/test-*.sh; do bash "$f" >/dev/null 2>&1 || { echo FAIL: $f; exit 1; }; done; echo ALL_PASS
```

Each check exits 0 on success; any failing check is a hard pass/fail signal for the Part.

---

### Part 7: P5 — `## Memory Mechanisms` section in `CLAUDE.md`

**File:** UPDATE — `CLAUDE.md`

**Description.** Add a section that distinguishes auto-memory from subagent
memory. Place AFTER the `## Soft Prerequisites` table and the `**Strict-mode
env vars**` block (which already received the `CLAUDE_MEMORY_FRESHNESS_MODE`
entry in Part 4), BEFORE the `## TDD Policy` section. Total addition ≤ 30
lines. CLAUDE.md must remain ≤ 200 lines after edit.

**Snippet to insert (verbatim, ≤ 30 lines):**

```markdown
## Memory Mechanisms

Claude Code v2.1.118 ships two independent native memory mechanisms; both write a `MEMORY.md` index whose first 200 lines / 25 KB load into context at session/agent start. They are NOT the same feature.

| Scope | Path | Owner | Persistence |
| ----- | ---- | ----- | ----------- |
| Auto-memory | `~/.claude/projects/<slug>/memory/` | Main session (Claude itself) | Machine-local; not shared via VCS |
| Subagent (`memory: project`) | `.claude/agent-memory/<name>/` | Subagent declaring `memory: project` | Project-shared via VCS |
| Subagent (`memory: user`) | `~/.claude/agent-memory/<name>/` | Subagent declaring `memory: user` | User-local; all your projects |

**Auto-memory** (`autoMemoryEnabled: true` in `settings.json`) is owned by the main session: Claude decides when something is worth remembering and writes to the path above. Path includes a user-specific slug derived from git repo root; project-wide override is REJECTED by Claude Code by design.

**Subagent memory** at `project` scope is the kit's primary integration surface. Three agents declare `memory: project`: `code-reviewer`, `plan-reviewer`, `code-researcher`. The native loader injects the first 200 lines of `.claude/agent-memory/<name>/MEMORY.md` into the agent's system prompt at SubagentStart and auto-grants Read/Write/Edit on that dir. Worktree-isolated agents (`code-reviewer`) sync via `prepare-worktree.sh` (forward) and `sync-agent-memory.sh` (back) — see `.claude/skills/workflow-protocols/agent-memory-protocol.md`.

Workflow startup step 0.06 (see `.claude/commands/workflow.md`) scans both paths for staleness; the `CLAUDE_MEMORY_FRESHNESS_MODE` env var (above) toggles WARN/strict behavior.

Canonical references: <https://code.claude.com/docs/en/memory> (auto-memory), <https://code.claude.com/docs/en/sub-agents#enable-persistent-memory> (subagent memory).
```

**Verification.**

```bash
wc -l CLAUDE.md   # ≤ 200
grep -c '^## Memory Mechanisms$' CLAUDE.md         # = 1
grep -c '\.claude/agent-memory/<name>/' CLAUDE.md  # >= 1
grep -c '~/.claude/projects/<slug>/memory/' CLAUDE.md  # >= 1
```

---

## Files Summary

| File | Action | Part | Description |
|---|---|---|---|
| `.claude/scripts/tests/test-coder-to-codereview-handoff-write.sh` | UPDATE | 1 | +1 line `export CLAUDE_WORKFLOW_STATE_DIR` after `mktemp` |
| `.claude/scripts/tests/test-code-review-to-completion-handoff.sh` | UPDATE | 1 | +1 line `export CLAUDE_WORKFLOW_STATE_DIR` after `mktemp` |
| `.claude/scripts/tests/test-spec-check-failure-after-retry-blocker.sh` | UPDATE | 1 | +1 line `export CLAUDE_WORKFLOW_STATE_DIR` after `mktemp` |
| `.claude/scripts/validate-handoff.sh` | UPDATE | 2 | DETAIL_FULL_OUTPUT_CAP block + truncation logic |
| `.claude/agent-memory/code-reviewer/MEMORY.md` | CREATE | 3 | Baseline ≤80 lines, 3 H2 sections |
| `.claude/agent-memory/plan-reviewer/MEMORY.md` | CREATE | 3 | Baseline ≤80 lines, 3 H2 sections |
| `.claude/agent-memory/code-researcher/MEMORY.md` | CREATE | 3 | Baseline ≤80 lines, 3 H2 sections |
| `.claude/skills/workflow-protocols/agent-memory-protocol.md` | UPDATE | 3 | first_run trigger + what_to_save_template |
| `.claude/commands/workflow.md` | UPDATE | 4 | step 0.06 freshness check insertion |
| `CLAUDE.md` | UPDATE | 4 + 7 | env-var entry + Memory Mechanisms section |
| `.claude/settings.json` | UPDATE | 5 | Lines 50-51 cleaned (generic git tag rule, grep rule removed) |
| `.claude/agents/code-researcher.md` | UPDATE | 6 | Drop tools allowlist + reconcile RULE_1 |
| `.claude/agents/plan-reviewer.md` | UPDATE | 6 | Remove Edit from disallowedTools + add RULE_5 |

Total: 13 files; 7 UPDATE + 4 CREATE (3 baseline `MEMORY.md` + 0 new in other dirs); 0 DELETE.

## Files NOT touched (contract preservation evidence)

- `.claude/schemas/handoff.schema.json` — handoff contract bytes
- `.claude/schemas/verdict.schema.json` (if exists) — verdict envelope contract
- `.claude/skills/workflow-protocols/handoff-contracts.md` — 5 contracts
- `.claude/skills/workflow-protocols/handoff-protocol.md` — IMP-02/03/04
- `.claude/skills/caveman/SKILL.md` Boundaries section
- `.claude/scripts/save-review-checkpoint.sh:365-370` — canonical issue ID hash
- Any file under `~/.claude/` (project-local invariant)

## Notes

- The 7-Part order is operational (test-pass monotonicity), not semantic — Parts 1, 2, 3, 5, 7 are mutually independent; Parts 4 and 7 both touch CLAUDE.md but in disjoint sections.
- Part 6 has the highest residual risk: native auto-grant behavior with `tools` allowlist is not 100% documented (docs say R/W/E are auto-enabled; whether they merge into an explicit allowlist or get blocked is implementation-specific). The chosen approach (drop the allowlist on code-researcher entirely) avoids the question by removing the conflict surface.
- `code-reviewer.md` is intentionally NOT touched in Part 6 — its allowlist already includes Write+Edit and there is no conflicting denylist, so the auto-grant has nothing to fight.
- Test `test-test-fixture-isolation.sh` runs the 3 fixed tests in sandbox mode AND verifies the production log line count is unchanged — this is a strong invariant that catches accidental sandbox leakage.
- Plan does NOT add new tests; the 4 currently-failing tests are pre-existing and serve as gates for AC-PRE-1, AC-PRE-2, AC-P1.*, AC-P2.*.
- The agent memory baseline content is intentionally seed-level (≤ 80 lines, structurally complete) — agents will accumulate detail over real usage. The test gates STRUCTURE not CONTENT (H2 sections + line cap + non-empty), so future content drift is fine.
