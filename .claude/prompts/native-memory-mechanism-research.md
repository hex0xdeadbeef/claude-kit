---
title: "Native Claude Code Memory Mechanism — Workflow Artifact Audit"
status: research
date: 2026-05-03
author: orchestrator (workflow XL run)
scope: "Native auto-memory + subagent `memory: project` integration with workflow pipeline"
constraints:
  - "Phase handoff contracts (planner → plan-review → coder → code-review) MUST remain intact"
  - "Release tags v1.16 → v1.22.1 carry pipeline edits — schema changes additive only"
  - "All tests under .claude/scripts/tests/ MUST pass after fixes"
  - "Project MUST NOT be tied to /Users/dmitriym filesystem (kit is reused by other people)"
references:
  docs:
    - "https://code.claude.com/docs/en/memory — auto-memory canonical reference"
    - "https://code.claude.com/docs/en/sub-agents#enable-persistent-memory — subagent memory canonical reference"
  code:
    - ".claude/skills/workflow-protocols/agent-memory-protocol.md"
    - ".claude/scripts/sync-agent-memory.sh"
    - ".claude/scripts/prepare-worktree.sh"
    - ".claude/scripts/save-review-checkpoint.sh"
    - ".claude/scripts/inject-review-context.sh"
---

# Executive Summary

The user reported "native Claude Code memoization is not working" and asked
whether `~/.claude/projects/<slug>/memory/` accumulates fresh records. Investigation
confirms two distinct native memory mechanisms exist in Claude Code v2.1.118; both
are partially wired in this kit but have **5 concrete defects** that produce the
observed symptom. Of 51 tests under `.claude/scripts/tests/`, 4 currently FAIL —
2 are direct evidence of memory defects (P1, P2 below); 2 are unrelated pipeline
issues (P-PRE-1, P-PRE-2) that block the "all tests must pass" constraint and
must be cleared as pre-conditions before commit, but are not part of the focused
5 problems.

The fixes are additive (no contract breakage) and produce a deterministic,
machine-verifiable improvement: 4 → 0 failing tests, 3 missing baseline files
created, 2 hardcoded user paths removed, 1 documentation gap closed.

# 1 Native Claude Code memory model — canonical

Claude Code ships **two independent** memory mechanisms. Both write a `MEMORY.md`
index file that loads the first 200 lines / 25 KB into context at session/agent
start. They are NOT the same feature.

| Feature | Path | Owner | Loaded into | Setting | Docs |
|---|---|---|---|---|---|
| Auto-memory | `~/.claude/projects/<slug>/memory/MEMORY.md` | Main session (Claude itself) | Every main-session start | `autoMemoryEnabled: true` (project), `autoMemoryDirectory` (user/local/policy only) | [memory.md](https://code.claude.com/docs/en/memory#auto-memory) |
| Subagent memory (`memory: project`) | `.claude/agent-memory/<agent-name>/MEMORY.md` | Subagent (declared via frontmatter) | Subagent start when agent is invoked | `memory: user\|project\|local` in agent frontmatter | [sub-agents.md#enable-persistent-memory](https://code.claude.com/docs/en/sub-agents#enable-persistent-memory) |

Auto-memory is **machine-local** by design (path includes user-specific slug
derived from git repo root). The kit cannot relocate it project-wide:
`autoMemoryDirectory` is REJECTED from project settings to prevent shared
projects from redirecting writes to sensitive locations.

Subagent memory at `project` scope IS shareable through version control —
this is the kit's actual integration surface. When `memory: <scope>` is set
on an agent, Claude Code automatically:

1. Injects first 200 lines / 25 KB of `<dir>/MEMORY.md` into the agent's
   system prompt.
2. Auto-grants Read, Write, Edit on the memory dir (per docs verbatim:
   "Read, Write, and Edit tools are automatically enabled so the subagent
   can manage its memory files").
3. Creates the dir on first write (no explicit bootstrap required, BUT
   first-run agents have empty context until the first save).

# 2 Workflow artifact graph (memory-relevant slice)

Filtered to artifacts that participate in the memory mechanism. Excluded:
artifacts unrelated to memory (e.g., `.claude/skills/planner-rules/code-shapes/*`).

```
                                  ┌─────────────────────────────────────────┐
                                  │  CLAUDE.md (project-root)               │
                                  │  - autoMemoryEnabled: true (line 130)   │
                                  │  - documents memory in 1 line only      │
                                  └────────────┬────────────────────────────┘
                                               │ session start: full load
                                               ▼
┌─────────────────────────────┐         ┌────────────────────────────────────┐
│ ~/.claude/projects/         │         │ Main Claude Code session           │
│ <slug>/memory/MEMORY.md     │◀────────│ /workflow command                  │
│ AUTO-MEMORY (machine-local) │  loads  │                                    │
│ MEMORY.md, feedback_*.md,   │  200ln  │                                    │
│ workflow-architecture.md    │  25KB   │                                    │
└─────────────────────────────┘         └─────┬──────────────────────────────┘
                                              │ delegates
                                              ▼
                                   ┌──────────────────────────────────────────┐
                                   │ Subagents with `memory: project`         │
                                   │ - code-researcher.md   (memory: project) │
                                   │ - code-reviewer.md     (memory: project) │
                                   │ - plan-reviewer.md     (memory: project) │
                                   └──────────┬───────────────────────────────┘
                                              │ system-prompt inject + R/W/E grant
                                              ▼
                                   ┌──────────────────────────────────────────┐
                                   │ .claude/agent-memory/<agent>/MEMORY.md   │
                                   │ SUBAGENT MEMORY (project-shared via VCS) │
                                   │ ⚠ DIRECTORY MISSING IN REPO ⚠            │
                                   └──────────┬───────────────────────────────┘
                                              │ worktree round-trip (code-reviewer)
                                              ▼
                                   ┌──────────────────────────────────────────┐
                                   │ .claude/scripts/prepare-worktree.sh      │
                                   │   copies agent-memory/ → worktree        │
                                   │ .claude/scripts/sync-agent-memory.sh     │
                                   │   copies worktree → main repo            │
                                   │ (called by save-review-checkpoint.sh on  │
                                   │  SubagentStop)                           │
                                   └──────────────────────────────────────────┘

Skill / protocol layer:
  .claude/skills/workflow-protocols/agent-memory-protocol.md   (declares behavior)
  .claude/skills/workflow-protocols/SKILL.md                   (lists protocol)

Observability layer:
  .claude/scripts/inject-review-context.sh   (does NOT inject memory state)
  .claude/scripts/save-review-checkpoint.sh  (calls sync-agent-memory.sh)

Hook configuration:
  .claude/settings.json   (autoMemoryEnabled, SubagentStart/Stop hooks)
```

## 2.1 Artifact roles (table)

| Artifact | Role in memory mechanism |
|---|---|
| `CLAUDE.md` | Single-line mention of `autoMemoryEnabled`. No documentation of dual-mechanism split. |
| `.claude/settings.json` | Sets `autoMemoryEnabled: true`. Configures SubagentStart hook → `inject-review-context.sh`, SubagentStop → `save-review-checkpoint.sh` → `sync-agent-memory.sh`. **Contains hardcoded `/Users/dmitriym/...` paths in lines 50-51.** |
| `.claude/agents/code-researcher.md` | Declares `memory: project`; explicit `tools: [Read, Grep, Glob, Bash]` allowlist (NO Write/Edit). |
| `.claude/agents/code-reviewer.md` | Declares `memory: project`; `tools` allowlist includes Write/Edit. `isolation: worktree` triggers worktree round-trip. |
| `.claude/agents/plan-reviewer.md` | Declares `memory: project`; `tools: [Read, Grep, Glob, TodoWrite, Write]` PLUS `disallowedTools: [Edit, Bash]`. **Edit denial conflicts with native auto-grant.** |
| `.claude/skills/workflow-protocols/agent-memory-protocol.md` | Spec doc (`disable-model-invocation: true`). Declares storage `.claude/agent-memory/{agent_name}/`, freshness thresholds (30/90 days), worktree sync. |
| `.claude/scripts/sync-agent-memory.sh` | Worktree → main-repo copy-back. Skips files where main is newer (mtime check). |
| `.claude/scripts/prepare-worktree.sh` | Main-repo → worktree copy-forward (lines 161-165). Without source dir → no-op. |
| `.claude/scripts/save-review-checkpoint.sh` | SubagentStop hook; calls `sync-agent-memory.sh` after verdict capture. |
| `.claude/scripts/inject-review-context.sh` | SubagentStart hook for review agents; injects workflow context. **Does NOT inject memory freshness signal.** |
| `.claude/commands/workflow.md` | Orchestrator startup steps. Has step 0.05 (PK sanity) **but no step 0.06 (memory freshness).** |
| `.claude/agents/meta-agent/scripts/{yaml-lint,check-plan-drift,check-references}.sh` | All skip paths matching `agent-memory` to avoid hook amplification (already correct). |

# 3 Current state vs expected

## 3.1 Auto-memory (`~/.claude/projects/<slug>/memory/`)

Status: **partially working**.

Observable evidence:
- `MEMORY.md` exists, last mtime 2026-04-28 23:19 (5 days old at audit time).
- Topic files: `feedback_workflow_full_flow.md`, `feedback_verify_loop_exit_code.md`,
  `hooks-and-scripts.md`, `skills-and-rules.md`, `workflow-architecture.md`.
- Auto-memory is INJECTED at session start (visible in this run's system context).

Verdict: not broken, but staleness has no early-warning signal in workflow startup.
This is the user's perceived "no fresh records" symptom — it's WAI for files
Claude has not chosen to update, but a freshness check would surface it
proactively.

## 3.2 Subagent memory (`.claude/agent-memory/<agent>/`)

Status: **broken end-to-end**.

Observable evidence:
- Directory `.claude/agent-memory/` does NOT exist.
- Test `test-agent-memory-baseline-exists.sh` FAILS at first assertion:
  `AC-P1.1a — .claude/agent-memory/code-reviewer/MEMORY.md missing or empty`.
- Three agents declare `memory: project` but two have tool-permission conflicts
  with the native auto-grant (see Problem 4 below).
- Worktree round-trip scripts exist and work, but operate on an empty input dir.

Test corpus shows 4 FAIL of 51:
```
FAIL: test-agent-memory-baseline-exists.sh         (P1: missing baselines)
FAIL: test-memory-freshness-warn.sh                (P2: missing step 0.06)
FAIL: test-test-fixture-isolation.sh               (P-PRE-1: unrelated)
FAIL: test-validate-handoff-detail-log-cap.sh      (P-PRE-2: unrelated)
```

# 4 Five problems (focused)

Each problem has: symptom, root cause, acceptance criteria (falsifiable predicate),
contract impact (must be ZERO), and justification.

## P1 — Subagent memory baseline files missing

**Symptom.** `.claude/agent-memory/<agent>/MEMORY.md` does not exist for any of
the three agents that declare `memory: project`. Test
`test-agent-memory-baseline-exists.sh:16` fails at first assertion.

**Root cause.** Native Claude Code creates the dir on **first write**, but
agents have nothing project-specific to write on the first run because no
seed file exists. Until the agent makes a discovery worth saving, the dir
stays missing → agent's `MEMORY.md` injection is empty bytes → no project
context surfaces. The committed test documents the expected end-state but
no commit ever produced the baseline files.

**Acceptance criteria.**
- AC-P1.1: `.claude/agent-memory/code-reviewer/MEMORY.md` exists, ≤80 lines, contains H2 sections `## Project Conventions`, `## Anti-patterns Catalog`, `## Patterns Catalog`.
- AC-P1.2: `.claude/agent-memory/plan-reviewer/MEMORY.md` exists, ≤80 lines, contains H2 sections `## Project Layer Structure`, `## Review Checklist Priorities`, `## Common Section Gaps`.
- AC-P1.3: `.claude/agent-memory/code-researcher/MEMORY.md` exists, ≤80 lines, contains H2 sections `## Package Locations`, `## Key Entry Points`, `## Codebase Topology`.
- AC-P1.4: `agent-memory-protocol.md` first_run.trigger handles "MEMORY.md missing OR file is empty (size==0)" — both branches.
- AC-P1.5: `agent-memory-protocol.md` adds `what_to_save_template:` block with the 3-question rubric (novel-this-iteration / user-pushed-back-on-default / non-obvious-project-fact).
- AC-P1.6: `bash .claude/scripts/tests/test-agent-memory-baseline-exists.sh` exits 0.
- AC-P1.7: `bash .claude/scripts/tests/test-decision-matrix-consistency.sh` still exits 0 (no regression).

**Contract impact.** ZERO. Baselines are seed files written once; they do not
participate in handoff payloads, do not change schema, do not affect
verdict envelopes.

**Justification.** Without baselines, every first invocation of each agent
runs in the cold-start regime. This is the loudest signal of "memory not
working" — the very thing the user reported. The test is already authored
and gating; the fix is to author the missing artifacts.

## P2 — Workflow startup missing freshness check (step 0.06)

**Symptom.** No early-warning signal when memory files (auto-memory or
subagent) age past 30 days. Test `test-memory-freshness-warn.sh:16` fails:
`AC-P5.1 — workflow.md missing step 0.06`.

**Root cause.** Workflow orchestrator startup has step 0.05 (PROJECT-KNOWLEDGE.md
sanity) and step 0 (Task Analysis), but no step that scans memory dirs for
stale entries. Native auto-memory injection happens, but a stale MEMORY.md
silently mis-informs Claude about project state. The user's complaint —
"unclear if there are fresh records" — is precisely what this signal answers.

**Acceptance criteria.**
- AC-P2.1: `.claude/commands/workflow.md` has `step: 0.06` between `step: 0.05` and `step: 0` (verified by test line-ordering check).
- AC-P2.2: Step 0.06 documents both scan paths: `~/.claude/projects/{slug}/memory/MEMORY.md` AND `.claude/agent-memory/{plan-reviewer,code-reviewer,code-researcher}/MEMORY.md`.
- AC-P2.3: Step 0.06 specifies WARN format: `[workflow] WARN: memory N file(s) stale/expired (oldest: NNNN days)` (verbatim template per test:34).
- AC-P2.4: Step 0.06 documents env modes `CLAUDE_MEMORY_FRESHNESS_MODE (off|warn|strict, default warn)`; `CLAUDE.md` lists this env var in the strict-mode env table.
- AC-P2.5: Default mode is `warn` (non-blocking).
- AC-P2.6: `bash .claude/scripts/tests/test-memory-freshness-warn.sh` exits 0.

**Contract impact.** ZERO. Startup-step additions are observability-only.
They do not modify any handoff payload, do not change loop limits, do not
change agent invocation. WARN to stderr is the established hook-stderr
convention (`[workflow] WARN: ...`).

**Justification.** The user's primary complaint is staleness uncertainty.
A WARN signal at startup is the cheapest possible solution: zero contract
impact, runs once per session, surfaces the exact information requested.
The test is already authored.

## P3 — Hardcoded `/Users/dmitriym` paths in committed `settings.json`

**Symptom.** `.claude/settings.json:50-51` contain literal user-specific
paths embedded in permission rules. Other users cloning the kit see
permission strings that do not match their filesystem and may receive
unexpected approval prompts.

```json
"Bash(git -C /Users/dmitriym/Desktop/claude-kit tag --list 'v1.*' --sort=-version:refname)",
"Bash(grep -rn '/Users/dmitriym\\\\|$HOME\\\\|~/.claude\\\\|hardcoded.*path' /Users/dmitriym/Desktop/claude-kit/.claude/)"
```

**Root cause.** The two permission rules were appended during a prior
session and pin commands to one developer's working tree. The first
allows a `git -C <abs-path> tag --list ...`; the same intent is expressible
without the absolute path. The second is a self-referential grep that
never needs to run for end users.

**Acceptance criteria.**
- AC-P3.1: `.claude/settings.json` contains zero substrings matching `/Users/dmitriym` (verified by `grep -c '/Users/dmitriym' .claude/settings.json` returning 0).
- AC-P3.2: Permission semantics for `git tag --list` preserved through generic rule (e.g., `Bash(git tag *)` or `Bash(git tag --list *)`).
- AC-P3.3: The diagnostic grep rule (line 51) removed entirely (was a one-shot debug utility, not a recurring need).
- AC-P3.4: All currently-passing tests continue to pass (no permission-related regressions).
- AC-P3.5: `.claude/settings.local.json.example` does NOT introduce new user-path requirements.

**Contract impact.** ZERO. Permission allow-rules add capability; removing
or generalizing them does not affect any phase handoff. Phases use Bash
for `make`, `go test`, `git status/diff/log/commit/add` — those rules are
unchanged.

**Justification.** Direct violation of the user-stated constraint
"наш конфиг используется другими людьми" (config used by other people).
The `sync-to-github.sh` script also has a hardcoded path on line 16, BUT
that script is documented as user-edit-required (commented "EDIT THESE
VALUES"; opt-in tooling not in any pipeline). settings.json is committed
configuration loaded by every Claude Code session — that is a real defect.

## P4 — Tool allow/deny conflicts with `memory: project` auto-grant

**Symptom.** Two of three memory-enabled agents have tool restrictions
that overlap with the native R/W/E auto-grant for memory dirs:

| Agent | Frontmatter | Conflict |
|---|---|---|
| `code-researcher.md` | `tools: [Read, Grep, Glob, Bash]` (allowlist excludes Write+Edit) + `memory: project` | Native auto-grant adds Write+Edit per docs; explicit allowlist may shadow it. Even if auto-grant wins, the agent's role description says "Read Only" → memory writes are doctrinally blocked. |
| `plan-reviewer.md` | `tools: [Read, Grep, Glob, TodoWrite, Write]` + `disallowedTools: [Edit, Bash]` + `memory: project` | Edit is BOTH auto-granted (for memory dir) AND explicitly denied (for everything). Denylist almost certainly wins → cannot Edit `MEMORY.md` to refresh existing entries. Only Write (overwrite-whole-file) works. |
| `code-reviewer.md` | `tools: [Read, Grep, Glob, Bash, TodoWrite, Write, Edit]` + `memory: project` | OK — Write+Edit in allowlist, no denylist. |

Per official docs (sub-agents.md verbatim):
> When memory is enabled... Read, Write, and Edit tools are automatically
> enabled so the subagent can manage its memory files.

**Root cause.** The `memory: project` frontmatter was added on top of
pre-existing tool restrictions. The interaction was not audited. For
`code-researcher`, the role identity ("Read Only") still says "Do NOT modify
any files. You have no Write/Edit tools" (line 26) — internally inconsistent
with `memory: project`.

**Acceptance criteria.**
- AC-P4.1: `code-researcher.md` either (a) drops the explicit `tools` allowlist (inherits all + memory auto-grant) OR (b) adds `Write, Edit` to the allowlist scoped to the memory dir via the agent's own RULE block. Choice (a) is preferred for simplicity.
- AC-P4.2: `code-researcher.md` role section reconciles "memory writes allowed for `.claude/agent-memory/code-researcher/` only — codebase remains read-only".
- AC-P4.3: `plan-reviewer.md` removes `Edit` from `disallowedTools`. `Bash` denial preserved (plan-reviewer has no Bash need beyond memory, and memory does not require Bash).
- AC-P4.4: All currently-passing tests continue to pass.
- AC-P4.5: Plan-reviewer can call Edit for `.claude/agent-memory/plan-reviewer/MEMORY.md` only — codebase Edit remains forbidden by role discipline (not by hard tool-deny).

**Contract impact.** ZERO. Tool permissions affect what the agent CAN do
inside its sandboxed turn; they do not change the verdict envelope, the
handoff JSON schema, or the issue-ID hashing. The agent's output contract
(`VERDICT_JSON`, structured issues, handoff) is identical.

**Justification.** This is the single most subtle defect. Per docs the
auto-grant is supposed to make memory "just work" — but explicit denylists
likely defeat it (Claude Code's permission model defaults to
deny-overrides-allow). Without this fix, P1's baseline files exist but
agents cannot keep them refreshed via Edit, only via destructive Write.
Over time MEMORY.md drifts because incremental updates are blocked.

## P5 — `CLAUDE.md` does not document the dual memory mechanism

**Symptom.** `CLAUDE.md:130` mentions `autoMemoryEnabled: true` in a single
line. No paragraph, no table, no cross-reference distinguishes auto-memory
from subagent memory. The user's question — "is this about `memory: project`
frontmatter?" — is direct evidence of the documentation gap.

**Root cause.** Auto-memory and subagent memory were added to the kit at
different times. The `agent-memory-protocol.md` skill exists deep in
`.claude/skills/workflow-protocols/` but is not surfaced in CLAUDE.md.
A new contributor (or the user 2 weeks later) cannot tell which
mechanism they are debugging.

**Acceptance criteria.**
- AC-P5.1: `CLAUDE.md` has a section titled `## Memory Mechanisms` (or a clearly-named subsection under an existing section). Total addition ≤30 lines (within CLAUDE.md size budget).
- AC-P5.2: The new section names BOTH paths verbatim: `~/.claude/projects/<slug>/memory/` AND `.claude/agent-memory/<name>/`.
- AC-P5.3: The new section includes a 3-row table: scope, path, who-writes, persistence (machine-local vs VCS-shared).
- AC-P5.4: The new section cross-references `agent-memory-protocol.md` and `code.claude.com/docs/en/memory` + `code.claude.com/docs/en/sub-agents#enable-persistent-memory`.
- AC-P5.5: `CLAUDE.md` line count remains ≤200 (recommended budget per docs `# Write effective instructions`).
- AC-P5.6: All existing `CLAUDE.md` sections (Language Profile, TDD Policy, etc.) preserved unchanged in content.

**Contract impact.** ZERO. CLAUDE.md is loaded as user-message context;
documentation additions cannot affect handoffs, verdicts, or hooks.

**Justification.** Documentation gap is causal: the user could not tell
that the mechanism they were observing was auto-memory (machine-local)
vs subagent memory (project-shared). After this fix, anyone reading CLAUDE.md
can answer "where does this kind of memory live?" in 30 seconds without
external docs.

# 5 Pre-condition cleanup (NOT one of the 5 problems, but required for "all tests pass")

Two failing tests are unrelated to memory but block the constraint
"all tests must pass". They are listed here for transparency; their fixes
are small mechanical changes folded into the implementation phase.

| ID | Test | Symptom | Fix scope |
|---|---|---|---|
| P-PRE-1 | `test-test-fixture-isolation.sh` | 3 test files do not export `CLAUDE_WORKFLOW_STATE_DIR` within 5 lines after `mktemp -d` | Add 1 export line in `test-coder-to-codereview-handoff-write.sh`, `test-code-review-to-completion-handoff.sh`, `test-spec-check-failure-after-retry-blocker.sh` |
| P-PRE-2 | `test-validate-handoff-detail-log-cap.sh` | `full_output` length 4825 > 900 cap | Tighten log-line truncation in `validate-handoff.sh` (cap 800 + suffix headroom) |

These are not memory defects and not in the focused-5. They are
pre-existing pipeline cleanups that became unblocked by clearer test
fixtures. Plan will sequence them BEFORE memory fixes so the test corpus
goes 47/51 → 49/51 → 51/51 monotonically (no test ever flips green→red).

# 6 Contract preservation matrix

For each phase handoff, this matrix records what the fix touches and
proves no contract bytes change.

| Contract | Schema file | Fix surface | Bytes touched? |
|---|---|---|---|
| `planner_to_plan_review` | `handoff.schema.json` (oneOf branch) | none | NO |
| `plan_review_to_coder` | `handoff.schema.json` (oneOf branch) | none | NO |
| `coder_to_code_review` | `handoff.schema.json` (oneOf branch) | none | NO |
| `code_review_to_completion` | `handoff.schema.json` (oneOf branch, 1.2.0) | none | NO |
| Verdict envelope (`VERDICT_JSON:`) | `verdict.schema.json` | none | NO |
| Canonical issue ID (`sha256(category|location|problem)[:8]`) | `save-review-checkpoint.sh:365-370` | none | NO |
| Caveman boundaries (verbatim sections) | `caveman/SKILL.md` | none | NO |

Touched surface (each item explicitly in scope of one of P1..P5):

| Surface | Fix | Reason no contract impact |
|---|---|---|
| `.claude/agent-memory/<a>/MEMORY.md` (3 new files) | P1 | New files, not referenced by any schema |
| `.claude/skills/workflow-protocols/agent-memory-protocol.md` | P1 (first_run trigger + 3-question template) | `disable-model-invocation: true` skill body — no handoff data |
| `.claude/commands/workflow.md` (step 0.06 added) | P2 | Startup-side observability; no payload generation |
| `CLAUDE.md` (env var entry) | P2 (CLAUDE_MEMORY_FRESHNESS_MODE entry) | Documentation only |
| `.claude/settings.json` (lines 50-51 generalized/removed) | P3 | Permission allow-rules; widening scope, not narrowing — never blocks pipeline |
| `.claude/agents/code-researcher.md` (tools allowlist) | P4 | Tool list affects sandbox; agent output contract (verdict, summary, handoff) unchanged |
| `.claude/agents/plan-reviewer.md` (disallowedTools) | P4 | Same as above |
| `CLAUDE.md` (Memory Mechanisms section) | P5 | Documentation only |

# 7 Out of scope (explicit non-goals)

- Auto-memory location override (machine-local by Claude Code design; cannot be project-overridden anyway).
- Removing `agent-memory-protocol.md` in favor of native-only behavior — protocol carries the worktree-sync semantics that native does not provide; removal would regress code-reviewer worktree workflow.
- Changing `autoMemoryEnabled` default — already true.
- Migrating any existing prompt/spec under `.claude/prompts/` — user said ignore.
- Touching release-tag artifacts (v1.16+ pipeline edits) outside the contract surface above.
- Cosmetic refactor of `MEMORY.md` index format in `~/.claude/projects/.../memory/` — that is auto-memory's own concern, written by Claude.

# 8 Implementation ordering (preview for /planner)

1. P-PRE-1 (3-line additions to 3 test files) — clears 1 failing test.
2. P-PRE-2 (1 truncation tweak in `validate-handoff.sh`) — clears 1 failing test.
3. P1 (3 baseline `MEMORY.md` files + protocol updates) — clears `test-agent-memory-baseline-exists.sh`.
4. P2 (workflow.md step 0.06 + CLAUDE.md env var entry) — clears `test-memory-freshness-warn.sh`.
5. P3 (settings.json line 50-51 cleanup).
6. P4 (code-researcher.md tools, plan-reviewer.md disallowedTools, plus role doc reconciliation).
7. P5 (CLAUDE.md Memory Mechanisms section).
8. Final: `bash .claude/scripts/tests/test-*.sh` → 51/51 PASS.

Each step is verifiable in isolation (one test or one grep predicate).
No step depends on a later step. Reordering preserves correctness as long
as P1 precedes any subagent invocation that would otherwise tap an empty
memory dir, but nothing in this plan invokes such an agent before P1
completes.

# 9 Sources

- [Claude Code — Auto memory & CLAUDE.md](https://code.claude.com/docs/en/memory)
- [Claude Code — Subagents: Enable persistent memory](https://code.claude.com/docs/en/sub-agents#enable-persistent-memory)
- [Claude Code — Sub-agents docs (cached, full text)](https://code.claude.com/docs/en/sub-agents)
- Local sources: `.claude/skills/workflow-protocols/agent-memory-protocol.md`, `.claude/scripts/sync-agent-memory.sh`, `.claude/scripts/prepare-worktree.sh`, `.claude/scripts/tests/test-agent-memory-baseline-exists.sh`, `.claude/scripts/tests/test-memory-freshness-warn.sh`, `CLAUDE.md`, `.claude/settings.json`.
