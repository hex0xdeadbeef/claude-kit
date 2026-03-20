# Workflow Hooks Research Report

**Date:** 2026-03-20
**Scope:** Hooks automation analysis — Co-Authored-By stripping, go vet, go build pre-commit
**Complexity:** XL
**Status:** Research complete

---

## 1. Executive Summary

This report analyzes all workflow-related artifacts in Claude Kit, maps their interaction graph, and identifies issues related to hooks automation. The original problem statement highlighted two missing hooks:

1. **Post-commit hook** for `Co-Authored-By` stripping
2. **Pre-commit validation** with `go build ./...`

Research revealed that the problem is deeper than two missing hooks — there are **9 issues** spanning hook gaps, documentation inconsistencies, and cross-artifact misalignment.

---

## 2. Artifact Inventory

### 2.1 Hook Scripts (14 registered + 2 unregistered)

| # | Script | Event | Matcher | Blocking | Purpose |
|---|--------|-------|---------|----------|---------|
| 1 | `scripts/protect-files.sh` | PreToolUse | Write\|Edit | YES | Block edits to protected files |
| 2 | `meta-agent/scripts/check-artifact-size.sh` | PreToolUse | Write | YES | SIZE_GATE limits |
| 3 | `scripts/block-dangerous-commands.sh` | PreToolUse | Bash | YES | Prevent destructive commands |
| 4 | `scripts/auto-fmt-go.sh` | PostToolUse | Write\|Edit | NO | gofmt on .go files |
| 5 | `meta-agent/scripts/yaml-lint.sh` | PostToolUse | Edit | NO | YAML syntax validation |
| 6 | `meta-agent/scripts/check-references.sh` | PostToolUse | Write | NO | Verify file refs |
| 7 | `meta-agent/scripts/check-plan-drift.sh` | PostToolUse | Write\|Edit | NO | Detect unplanned changes |
| 8 | `scripts/save-progress-before-compact.sh` | PreCompact | (all) | NO | Preserve state before compaction |
| 9 | `scripts/save-review-checkpoint.sh` | SubagentStop | plan-reviewer\|code-reviewer | YES | Record review completion |
| 10 | `scripts/enrich-context.sh` | UserPromptSubmit | (all) | NO | Inject workflow state |
| 11 | `meta-agent/scripts/verify-phase-completion.sh` | Stop | (all) | NO | Check meta-agent phases |
| 12 | `scripts/check-uncommitted.sh` | Stop | (all) | YES | Block stop if uncommitted |
| 13 | `scripts/session-analytics.sh` | SessionEnd | (all) | NO | Log session metrics |
| 14 | `scripts/notify-user.sh` | Notification | (all) | NO | Desktop notifications |
| — | `scripts/sync-to-github.sh` | *(unregistered)* | — | — | One-way .claude/ sync |
| — | `meta-agent/templates/onboarding/sync-to-github.sh` | *(unregistered)* | — | — | Bi-directional sync template |

### 2.2 Commands & Agents (Pipeline)

| Component | Type | Model | Role |
|-----------|------|-------|------|
| `/workflow` | Command | opus | Orchestrator (Phases 0-5) |
| `/planner` | Command | opus | Research + plan creation (Phase 1) |
| `/coder` | Command | sonnet | Implementation (Phase 3) |
| `plan-reviewer` | Agent | sonnet | Plan validation (Phase 2) |
| `code-reviewer` | Agent | sonnet | Code validation (Phase 4, worktree) |
| `code-researcher` | Agent (Task) | haiku | Read-only codebase exploration |

### 2.3 Workflow Protocols (7 files)

| Protocol | File | Loaded When |
|----------|------|-------------|
| Orchestration Core | `orchestration-core.md` | Startup (core dep) |
| Autonomy | `autonomy.md` | Startup (core dep) |
| Beads | `beads.md` | Startup (core dep) |
| Handoff | `handoff-protocol.md` | Before phase transitions |
| Checkpoint | `checkpoint-protocol.md` | After each phase |
| Re-routing | `re-routing.md` | On complexity mismatch |
| Pipeline Metrics | `pipeline-metrics.md` | Completion phase only |

### 2.4 Project Researcher (standalone agent)

| Component | Files | Role |
|-----------|-------|------|
| Orchestrator | `AGENT.md` | 10-phase pipeline |
| Subagents | 7 files in `subagents/` | DISCOVER→DETECT→GRAPH→ANALYZE→GENERATE→VERIFY→REPORT |
| Critique | `phases/critique.md` | Inline quality gate |
| Dependencies | 5 files in `deps/` | State contracts, patterns, edge cases |

---

## 3. Interaction Graph

```
                                    ┌─────────────────────────────────────┐
                                    │         settings.json               │
                                    │   (8 events, 14 hook registrations) │
                                    └───┬───┬───┬───┬───┬───┬───┬───────┘
                                        │   │   │   │   │   │   │
                    ┌───────────────────┘   │   │   │   │   │   └──────────────┐
                    ▼                       ▼   │   ▼   │   ▼                  ▼
              PreToolUse              PostToolUse│ PreCompact Stop        SessionEnd
              ┌─────────┐            ┌──────────┐│ ┌──────┐ ┌───────────┐ ┌──────────┐
              │protect   │            │auto-fmt  ││ │save  │ │verify-    │ │session-  │
              │files.sh  │            │go.sh     ││ │prog. │ │ phase.sh  │ │analytics │
              ├─────────┤            ├──────────┤│ └──────┘ ├───────────┤ │.sh       │
              │artifact  │            │yaml-lint ││         │check-     │ └──────────┘
              │size.sh   │            │.sh       ││SubagentStop│uncommit│
              ├─────────┤            ├──────────┤│ ┌──────┐ │.sh       │
              │block-   │            │check-refs││ │save  │ └───────────┘
              │danger.sh │            │.sh       ││ │review│
              └─────────┘            ├──────────┤│ │ckpt  │
                                     │plan-drift││ │.sh   │
                                     │.sh       ││ └──────┘
                                     └──────────┘│
                                                 │
                            UserPromptSubmit     │Notification
                            ┌────────────┐       │┌───────────┐
                            │enrich-     │       ││notify-    │
                            │context.sh  │       ││user.sh    │
                            └────────────┘       │└───────────┘
                                                 │
          ┌──────────────────────────────────────┘
          │
          ▼
    ┌─────────────────── WORKFLOW PIPELINE ────────────────────────┐
    │                                                              │
    │  Phase 0.5         Phase 1          Phase 2                  │
    │  ┌──────────┐     ┌──────────┐     ┌──────────────┐         │
    │  │Task      │────▶│/planner  │────▶│plan-reviewer  │         │
    │  │Analysis  │     │(opus)    │     │(sonnet,agent) │         │
    │  └──────────┘     └──────────┘     └───────┬──────┘         │
    │                        ▲                    │                │
    │                        │   NEEDS_CHANGES    │                │
    │                        └────────────────────┘ (max 3x)      │
    │                                             │ APPROVED       │
    │                                             ▼                │
    │  Phase 5           Phase 4          Phase 3                  │
    │  ┌──────────┐     ┌──────────────┐ ┌──────────┐             │
    │  │Completion│◀────│code-reviewer  │◀│/coder    │             │
    │  │(commit)  │     │(sonnet,agent) │ │(sonnet)  │             │
    │  └──────────┘     └──────┬───────┘ └──────────┘             │
    │                          │                ▲                  │
    │                          │ CHANGES_REQ    │                  │
    │                          └────────────────┘ (max 3x)        │
    │                                                              │
    └──────────────────────────────────────────────────────────────┘
                    │                           │
                    │  (Tool-assist, not phase)  │
                    ▼                           ▼
              ┌──────────────┐          ┌──────────────┐
              │code-researcher│          │code-researcher│
              │(haiku, Task)  │          │(haiku, Task)  │
              │via /planner   │          │via /coder     │
              └──────────────┘          └──────────────┘

    ┌─────────── PROJECT RESEARCHER (standalone) ──────────────┐
    │                                                           │
    │  VALIDATE → DISCOVER → DETECT → GRAPH → ANALYZE          │
    │       → CRITIQUE (gate) → GENERATE → VERIFY (gate)       │
    │            → REPORT                                       │
    │                                                           │
    │  Output: CLAUDE.md, PROJECT-KNOWLEDGE.md, skills/, rules/ │
    │  Consumed by: /planner, /coder, plan-reviewer,            │
    │               code-reviewer (via generated rules)         │
    └───────────────────────────────────────────────────────────┘
```

### 3.1 Hook-to-Pipeline Interaction Map

| Hook Script | Pipeline Phase(s) Affected | Interaction Type |
|-------------|---------------------------|------------------|
| `auto-fmt-go.sh` | Phase 3 (coder writes .go) | Auto-format after every write/edit |
| `check-uncommitted.sh` | Phase 5 (completion) | Gate: block stop without commit |
| `save-review-checkpoint.sh` | Phase 2, 4 (review agents stop) | State: record verdict to JSONL |
| `enrich-context.sh` | All phases (every prompt) | Context: inject checkpoint state |
| `save-progress-before-compact.sh` | All phases (on compaction) | Recovery: preserve state |
| `session-analytics.sh` | Phase 5+ (session end) | Metrics: exploration loop detection |
| `protect-files.sh` | Phase 3 (coder writes) | Gate: block writes to protected files |
| `check-artifact-size.sh` | Phase 1 (planner writes plan) | Gate: SIZE_GATE on .claude/ artifacts |
| `check-plan-drift.sh` | Phase 3 (coder writes) | Monitoring: drift from plan |
| `verify-phase-completion.sh` | Stop (meta-agent only) | Info: warn about incomplete phases |

---

## 4. Issues Identified

### ISSUE-01: Missing Pre-Commit Build Validation Hook

**Severity:** HIGH
**Category:** Hook gap
**Components:** `settings.json`, `orchestration-core.md`, `coder.md`

**Problem:**
No hook validates that code compiles (`go build ./...`) before `git commit`. The VERIFY phase in `/coder` runs `make fmt && make lint && make test` which implicitly includes compilation via `go test`. However:
- If the user commits manually (outside `/coder`), no compilation check fires
- If `make test` passes but `go build ./...` for non-test targets fails (e.g., `cmd/main.go` has build errors not covered by test packages), the gap is real
- `go vet` is allowed in `settings.json` permissions but never called automatically

**Affected artifacts:**
- `settings.json` — no PreToolUse hook on `Bash(git commit *)`
- `orchestration-core.md` Phase 5 — "Create git commit (MANDATORY)" without build gate
- `coder.md` VERIFY phase — runs `make test` but not standalone `go build ./...`

**Impact on Project Researcher:**
LOW — Project Researcher does NOT commit code. It generates .claude/ artifacts (Markdown/YAML). However, the generated `CLAUDE.md` and rules reference `make test` as the VERIFY command. If VERIFY doesn't catch build failures, downstream `/coder` runs may produce uncompilable commits.

---

### ISSUE-02: No Co-Authored-By Management Strategy

**Severity:** MEDIUM
**Category:** Hook gap
**Components:** `settings.json`, `orchestration-core.md`, `check-uncommitted.sh`

**Problem:**
The report recommends a post-commit hook for `Co-Authored-By` stripping. Current state:
- Claude Code appends `Co-Authored-By: Claude ...` to commit messages (per system prompt)
- No hook exists to strip or manage this trailer
- `check-uncommitted.sh` validates uncommitted changes but doesn't inspect commit message content
- The workflow's Phase 5 (Completion) says "Create git commit (MANDATORY)" but gives no commit message template

**Two sub-problems:**
1. **Stripping:** Some teams don't want AI attribution in history — no mechanism to remove it
2. **Consistency:** No commit message template → inconsistent formatting across workflow runs

**Affected artifacts:**
- `orchestration-core.md` Phase 5 — no commit message format spec
- `check-uncommitted.sh` — doesn't validate commit message structure
- `settings.json` — no hook event for post-commit (Claude Code hooks don't have `PostCommit` event)

**Impact on Project Researcher:**
NONE — Project Researcher doesn't create commits.

---

### ISSUE-03: `go vet` Never Called Automatically

**Severity:** MEDIUM
**Category:** Hook gap
**Components:** `auto-fmt-go.sh`, `settings.json`, `coder.md`

**Problem:**
`go vet` is a critical static analysis tool that catches:
- Unreachable code
- Incorrect format strings
- Suspicious constructs
- Struct tag errors

Current state:
- `auto-fmt-go.sh` (PostToolUse) only runs `gofmt` — does NOT run `go vet`
- `settings.json` has `Bash(go vet *)` in allow list but no hook invokes it
- `make lint` in VERIFY phase likely includes `go vet` (standard in Go linters like golangci-lint), but this is implicit and undocumented
- No PostToolUse hook runs `go vet` after writing `.go` files

**Gap:** Between PostToolUse (`gofmt` only) and VERIFY phase (`make lint`), there's no incremental `go vet` check. A developer writing 10 files sees issues only at VERIFY time.

**Affected artifacts:**
- `auto-fmt-go.sh` — could include `go vet` but intentionally doesn't
- `coder.md` VERIFY phase — relies on `make lint` which may or may not include `go vet`
- `CLAUDE.md` — defines `LINT=make lint` but doesn't specify what `make lint` contains

**Impact on Project Researcher:**
LOW — Project Researcher generates rules that reference `make lint` as the lint command. If `make lint` doesn't include `go vet`, the generated rules propagate the gap.

---

### ISSUE-04: `auto-fmt-go.sh` Silently Ignores gofmt Failures

**Severity:** LOW
**Category:** Error handling gap
**Components:** `auto-fmt-go.sh`

**Problem:**
Lines 98-101 of `auto-fmt-go.sh`:
```bash
if gofmt -w "$FILE_PATH" 2>/dev/null; then
    echo "... formatted ..." >> "$LOG_FILE"
fi
```
If `gofmt -w` fails (e.g., syntax error in `.go` file), the error is silently swallowed (`2>/dev/null`). The file remains unformatted, and no indication is given to Claude or the user.

**Rationale (documented):** PostToolUse hooks cannot block — the tool already executed. Errors here are informational only. This is a design decision, not a bug. However, not even logging the failure is a gap.

**Affected artifacts:**
- `auto-fmt-go.sh` — silent failure on gofmt errors
- `session-analytics.sh` — doesn't track formatting failures (only tracks tool calls)

**Impact on Project Researcher:**
NONE — Project Researcher writes Markdown/YAML, not Go files.

---

### ISSUE-05: Exploration Loop Detection Fragmentation

**Severity:** MEDIUM
**Category:** Cross-artifact inconsistency
**Components:** `enrich-context.sh`, `session-analytics.sh`, `pipeline-metrics.md`, `checkpoint-protocol.md`

**Problem (pre-FIX-05 state — thresholds updated by FIX-05, see workflow-hooks-fixes.md):**
Exploration loop detection was split across 4 artifacts with inconsistent thresholds:

| Artifact | Signal | Threshold (pre-FIX-05) | Threshold (post-FIX-05) | Action |
|----------|--------|------------------------|-------------------------|--------|
| `enrich-context.sh` | Last 20 tool calls: reads, writes == 0 | reads > 10 | reads > 15 | Suggest transition to action |
| `session-analytics.sh` | Session-wide read_write_ratio | ratio > 10 | ratio > 10 + session_type gate | Log `exploration_loop_signal` |
| `pipeline-metrics.md` | Session-wide exploration_reads | reads > 30 AND writes == 0 | + session_type != project-research | Warning: stuck in exploration |
| `checkpoint-protocol.md` | Sub-phase tool_calls/file_reads | *(no threshold)* | 20 reads/sub-phase | STOP_AND_TRANSITION |
| `CLAUDE.md` error table | Exploration budget exceeded | *(no threshold)* | 15/context, 20/sub-phase, ratio>10/session | STOP_AND_TRANSITION |

Problems (resolved by FIX-05):
1. ~~**Multiple independent detectors** with no coordination~~ — now aligned with 3-scope model
2. ~~**Inconsistent thresholds**~~ — unified: 15 (context) / 20 (sub-phase) / ratio>10 + 30 reads (session)
3. ~~**checkpoint-protocol.md** no threshold~~ — added budget_threshold + on_exceeded
4. ~~**CLAUDE.md** no threshold~~ — added all 3 scopes

**Affected artifacts:**
- All 4 listed + CLAUDE.md error handling table

**Impact on Project Researcher:**
HIGH — Project Researcher's DETECT and ANALYZE subagents perform extensive reads (potentially 30+ per module in monorepos). The `exploration_reads > 30` threshold in `pipeline-metrics.md` could trigger false positive warnings on Project Researcher output, since its read-heavy pattern is by design, not a loop.

---

### ISSUE-06: `check-uncommitted.sh` Doesn't Distinguish Workflow vs Non-Workflow Context

**Severity:** LOW
**Category:** Hook design gap
**Components:** `check-uncommitted.sh`, `enrich-context.sh`

**Problem:**
`check-uncommitted.sh` blocks session stop for ANY uncommitted changes, regardless of whether a workflow is active. This means:
- Editing a README without `/workflow` triggers the same block
- Research-only sessions (no code changes expected) may be blocked by unrelated unstaged files
- The hook has no way to check if a workflow is in progress

`enrich-context.sh` injects checkpoint state into context, but `check-uncommitted.sh` doesn't read this context — it only checks `git status`.

**Affected artifacts:**
- `check-uncommitted.sh` — no workflow awareness
- `enrich-context.sh` — provides state but hook doesn't consume it

**Impact on Project Researcher:**
MEDIUM — Project Researcher generates artifacts to `.claude/` directory. These files may appear as uncommitted changes, potentially blocking session stop even after successful generation + verification.

---

### ISSUE-07: No Hook Event for Post-Commit Actions

**Severity:** MEDIUM
**Category:** Platform limitation
**Components:** `settings.json`, Claude Code hook system

**Problem:**
Claude Code's hook system supports 8 events:
- PreToolUse, PostToolUse, PreCompact, SubagentStop, UserPromptSubmit, Stop, SessionEnd, Notification

There is **no PostCommit event**. This means:
- Cannot auto-strip `Co-Authored-By` after commit
- Cannot run `go build ./...` validation after commit
- Cannot auto-push after commit
- Cannot trigger external CI after commit

Any post-commit logic must be implemented as:
1. A git hook (`.git/hooks/post-commit`) — outside Claude Code's control
2. A PreToolUse hook on `Bash(git commit *)` — runs BEFORE commit, not after
3. Manual scripting within the workflow completion phase

**Affected artifacts:**
- `settings.json` — cannot register PostCommit hooks
- `orchestration-core.md` Phase 5 — must handle post-commit logic inline

**Impact on Project Researcher:**
NONE — Project Researcher doesn't commit.

---

### ISSUE-08: VERIFY Command Implicitly Assumes `make` Targets Exist

**Severity:** MEDIUM
**Category:** Documentation gap
**Components:** `CLAUDE.md`, `coder.md`, `handoff-protocol.md`, `checkpoint-protocol.md`

**Problem:**
VERIFY command in `CLAUDE.md`: `make fmt && make lint && make test`
This assumes the project has a Makefile with `fmt`, `lint`, and `test` targets. The `PROJECT-KNOWLEDGE.md` override mechanism exists but:
1. No validation that `make` targets exist before VERIFY runs
2. No fallback commands if `make` is unavailable
3. `coder.md` VERIFY phase doesn't check for Makefile existence
4. `handoff-protocol.md` hardcodes `command_used: "make fmt && make lint && make test"`
5. `checkpoint-protocol.md` example hardcodes the same command

**Affected artifacts:**
- `CLAUDE.md` — defines commands without existence check
- `coder.md` — uses commands without validation
- `handoff-protocol.md` — hardcodes in handoff payload example
- `checkpoint-protocol.md` — hardcodes in checkpoint example

**Impact on Project Researcher:**
HIGH — Project Researcher's GENERATION phase creates `CLAUDE.md` and `PROJECT-KNOWLEDGE.md` with project-specific commands. If it correctly detects the build system (Go module without Makefile → fallback to `go fmt/go vet/go test`), this issue is mitigated. But if it defaults to `make`-based commands without validating Makefile existence, downstream `/coder` runs will fail at VERIFY.

---

### ISSUE-09: `save-review-checkpoint.sh` Uses Unsafe JSON Embedding

**Severity:** HIGH
**Category:** Security/reliability
**Components:** `save-review-checkpoint.sh`

**Problem:**
Line 24 of `save-review-checkpoint.sh`:
```python
data = json.loads('''$INPUT''')
```
The `$INPUT` variable (raw stdin JSON) is embedded directly into a Python triple-quoted string via bash heredoc. If `INPUT` contains triple quotes (`'''`), the Python code breaks. If `INPUT` contains backticks or `$()`, bash performs command substitution before Python executes.

**Risk scenarios:**
1. Agent output contains `'''` (common in Python code discussions) → Python SyntaxError
2. Agent output contains `$(malicious)` → bash command injection (mitigated by `set -euo pipefail` but not eliminated)
3. Agent output contains `\n` followed by Python code → arbitrary code execution in Python context

**Contrast with other hooks:** `auto-fmt-go.sh`, `enrich-context.sh`, `session-analytics.sh` all use safe patterns:
- Pipe stdin to `python3 -c` via `echo "$INPUT" | python3 -c "import sys; data = json.loads(sys.stdin.read())"`
- Or use env var: `export _HOOK_INPUT="$INPUT"` + `os.environ.get("_HOOK_INPUT")`

**Affected artifacts:**
- `save-review-checkpoint.sh` — unsafe stdin handling
- All downstream consumers of `review-completions.jsonl` (enrich-context.sh, save-progress-before-compact.sh, pipeline-metrics.md)

**Impact on Project Researcher:**
LOW — Project Researcher doesn't trigger SubagentStop for this hook (it uses Task tool, not native agents). However, if Project Researcher's CRITIQUE or VERIFY phases were to be refactored into native agents, this hook would fire on their output and the vulnerability would apply.

---

## 5. Issue Priority Matrix

| Issue | Severity | Effort | Priority | Blocking? |
|-------|----------|--------|----------|-----------|
| ISSUE-09 | HIGH | S | P0 | Security risk in production |
| ISSUE-01 | HIGH | M | P1 | Build failures slip through |
| ISSUE-05 | MEDIUM | L | P2 | Fragmented detection logic |
| ISSUE-03 | MEDIUM | M | P2 | go vet not automated |
| ISSUE-07 | MEDIUM | M | P2 | Platform limitation |
| ISSUE-08 | MEDIUM | M | P2 | Implicit make dependency |
| ISSUE-02 | MEDIUM | S | P3 | Co-Authored-By management |
| ISSUE-06 | LOW | S | P3 | Non-workflow context block |
| ISSUE-04 | LOW | S | P4 | Silent format failure |

---

## 6. Impact on Project Researcher

| Issue | Direct Impact | Indirect Impact |
|-------|--------------|-----------------|
| ISSUE-01 | NONE | Generated CLAUDE.md propagates incomplete VERIFY spec |
| ISSUE-02 | NONE | N/A |
| ISSUE-03 | LOW | Generated rules may omit `go vet` from lint spec |
| ISSUE-04 | NONE | N/A |
| ISSUE-05 | **HIGH** | False positive exploration loop warnings on read-heavy analysis |
| ISSUE-06 | **MEDIUM** | Generated artifacts block session stop as "uncommitted" |
| ISSUE-07 | NONE | N/A |
| ISSUE-08 | **HIGH** | Generated CLAUDE.md may assume `make` without Makefile validation |
| ISSUE-09 | LOW | Would affect if subagents migrated to native agents |

**Key finding:** Issues 05, 06, and 08 directly affect Project Researcher's ability to function correctly within the broader workflow ecosystem.

---

## 7. Methodology

1. **Artifact collection:** Identified all 14 hook scripts + 6 pipeline components + 7 protocols + Project Researcher (24 files)
2. **Deep read:** Every script and protocol file read in full (not sampled)
3. **Cross-reference analysis:** Mapped all hook-to-pipeline interactions, settings.json registrations, and inter-artifact references
4. **Issue identification:** Each issue traced through affected artifacts with root cause analysis
5. **Impact assessment:** Each issue evaluated for direct and indirect impact on Project Researcher
6. **Priority matrix:** Combined severity × effort × blocking status
