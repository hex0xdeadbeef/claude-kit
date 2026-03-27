# Workflow Agent Memory Research

> Date: 2026-03-27 | Complexity: XL | Status: Complete

## Problem Statement

При переносе конфигурации claude-kit в новый проект, директория `.claude/agent-memory/code-researcher/` заполняется во время работы Workflow, а `.claude/agent-memory/code-reviewer/` и `.claude/agent-memory/plan-reviewer/` — нет. Память code-reviewer была обнаружена в git-истории (3 файла: MEMORY.md, feedback-regex-anchoring.md, project-conventions.md), но после удаления из working tree не восстанавливается при последующих запусках Workflow.

---

## 1. Inventory: Workflow Artifacts

### 1.1 Commands (shared context with orchestrator)

| Artifact | File | Model | Role |
|----------|------|-------|------|
| workflow | `.claude/commands/workflow.md` (380 lines) | opus | Orchestrator — координация полного цикла |
| planner | `.claude/commands/planner.md` (433 lines) | opus | Research + plan creation |
| coder | `.claude/commands/coder.md` (484 lines) | sonnet | Implementation per approved plan |

### 1.2 Agents (isolated context, clean review)

| Artifact | File | Model | Isolation | Tools | Memory Key |
|----------|------|-------|-----------|-------|------------|
| code-reviewer | `.claude/agents/code-reviewer.md` (246 lines) | sonnet | **worktree** | Read, Grep, Glob, Bash, TodoWrite | `memory: project` |
| code-researcher | `.claude/agents/code-researcher.md` (135 lines) | haiku | **none** | Read, Grep, Glob, Bash | `memory: project` |
| plan-reviewer | `.claude/agents/plan-reviewer.md` (197 lines) | sonnet | **none** | Read, Grep, Glob, TodoWrite | `memory: project` |

### 1.3 Skills (loaded by commands/agents)

| Skill | Loaded By | Files |
|-------|-----------|-------|
| workflow-protocols | /workflow (startup) | SKILL.md, autonomy.md, beads.md, orchestration-core.md, handoff-protocol.md, checkpoint-protocol.md, re-routing.md, pipeline-metrics.md, examples-troubleshooting.md |
| planner-rules | /planner (startup) | SKILL.md, mcp-tools.md, task-analysis.md, sequential-thinking-guide.md |
| coder-rules | /coder (startup) | SKILL.md, mcp-tools.md |
| code-review-rules | code-reviewer (auto) | SKILL.md, examples.md, security-checklist.md, checklist.md, troubleshooting.md |
| plan-review-rules | plan-reviewer (auto) | SKILL.md + supporting files |

### 1.4 Scripts & Hooks (workflow-specific)

| Script | Hook Event | Matcher | Blocking | Purpose |
|--------|-----------|---------|----------|---------|
| `enrich-context.sh` | UserPromptSubmit | all | no | Context enrichment + budget visualization |
| `save-review-checkpoint.sh` | SubagentStop | plan-reviewer\|code-reviewer | **yes** | Saves verdict to review-completions.jsonl |
| `prepare-worktree.sh` | WorktreeCreate | all | no | Worktree env setup (.env, go mod download) |
| `save-progress-before-compact.sh` | PreCompact | all | no | Checkpoint → additionalContext |
| `verify-state-after-compact.sh` | PostCompact | all | no | Verify checkpoint integrity |
| `check-uncommitted.sh` | Stop | all | **yes** | Block stop if uncommitted + active workflow |
| `session-analytics.sh` | SessionEnd | all | no | Session metrics collection |

### 1.5 State Files

| File | Location | Written By | Purpose |
|------|----------|-----------|---------|
| `{feature}-checkpoint.yaml` | `.claude/workflow-state/` | Orchestrator (phase-end) | Pipeline progress (12 YAML fields) |
| `review-completions.jsonl` | `.claude/workflow-state/` | save-review-checkpoint.sh | Agent verdicts (JSONL markers) |
| `session-analytics.jsonl` | `.claude/workflow-state/` | session-analytics.sh | Session metrics |
| `worktree-events.jsonl` | `.claude/workflow-state/` | prepare-worktree.sh | Worktree creation events |

### 1.6 Agent Memory Directories

| Directory | Current State | Git History |
|-----------|--------------|-------------|
| `.claude/agent-memory/code-researcher/` | MEMORY.md + 1 analysis file | Had `project-researcher-research.md` (deleted) |
| `.claude/agent-memory/code-reviewer/` | **EMPTY** | Had MEMORY.md, feedback-regex-anchoring.md, project-conventions.md (all deleted) |
| `.claude/agent-memory/plan-reviewer/` | **EMPTY** | Never had files |

---

## 2. Interaction Graph

```
                            /workflow (opus)
                           ┌──────────────────┐
                           │  ORCHESTRATOR     │
                           │  ─────────────    │
                           │  Loads:           │
                           │  • workflow-      │
                           │    protocols      │
                           │  Writes:          │
                           │  • checkpoint.yaml│
                           │  Hooks:           │
                           │  • enrich-context │
                           │  • check-uncommit │
                           └─────┬───────┬─────┘
                                 │       │
                    Phase 1      │       │     Phase 3
                  ┌──────────────┘       └──────────────┐
                  ▼                                      ▼
       ┌───────────────────┐                  ┌───────────────────┐
       │  /planner (opus)  │                  │  /coder (sonnet)  │
       │  ───────────────  │                  │  ───────────────  │
       │  Loads:           │                  │  Loads:           │
       │  • planner-rules  │                  │  • coder-rules    │
       │  Calls (optional):│                  │  Calls (optional):│
       │  • code-researcher│                  │  • code-researcher│
       │  Output:          │                  │  Output:          │
       │  • {feature}.md   │                  │  • Source code    │
       │  • handoff YAML   │                  │  • handoff YAML   │
       └────────┬──────────┘                  └────────┬──────────┘
                │                                      │
                │ Phase 2                              │ Phase 4
                ▼                                      ▼
  ┌──────────────────────────┐          ┌──────────────────────────┐
  │ plan-reviewer (sonnet)   │          │ code-reviewer (sonnet)   │
  │ ─────────────────────    │          │ ─────────────────────    │
  │ Isolation: NONE          │          │ Isolation: WORKTREE ◄────┤── ROOT CAUSE
  │ Tools: Read,Grep,Glob,   │          │ Tools: Read,Grep,Glob,   │
  │        TodoWrite         │          │        Bash, TodoWrite   │
  │ NO Write/Edit/Bash ◄────┤── ISSUE  │ NO Write/Edit     ◄────┤── ISSUE
  │ memory: project          │          │ memory: project          │
  │ maxTurns: 40             │          │ maxTurns: 45             │
  │ Skills: plan-review-rules│          │ Skills: code-review-rules│
  │ Output: VERDICT + handoff│          │ Output: VERDICT + handoff│
  └──────────┬───────────────┘          └──────────┬───────────────┘
             │                                     │
             │  SubagentStop hook                   │  SubagentStop hook
             ▼                                     ▼
  ┌──────────────────────────────────────────────────────────────────┐
  │                save-review-checkpoint.sh                         │
  │  Extracts: verdict via regex from last_assistant_message         │
  │  Writes: review-completions.jsonl (agent, timestamp, verdict)    │
  │  Does NOT: copy agent memory files to main directory             │
  └──────────────────────────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────────────────────────┐
  │                    code-researcher (haiku)                        │
  │  Isolation: NONE (runs in main working directory)                │
  │  Tools: Read, Grep, Glob, Bash                                  │
  │  Invoked by: planner (Phase 3) / coder (Phase 1.5) via Agent    │
  │  SubagentStop: does NOT fire (Agent/Task tool subagent)          │
  │  Memory writes: persist naturally (no worktree) via Bash ◄──── WORKS │
  └──────────────────────────────────────────────────────────────────┘
```

### Memory Write Flow Comparison

```
code-researcher (WORKS):
  Agent/Task invocation (no worktree)
  → runs in MAIN working directory
  → has Bash tool → can write files via shell
  → writes to .claude/agent-memory/code-researcher/
  → files persist on disk ✓
  → SubagentStop does NOT fire (not a native agent)

code-reviewer (BROKEN):
  Native agent delegation (with worktree)
  → runs in TEMPORARY worktree
  → has Bash tool → CAN write files
  → writes to WORKTREE/.claude/agent-memory/code-reviewer/
  → agent finishes (read-only, no source changes)
  → worktree cleaned up automatically
  → ALL memory files LOST ✗
  → SubagentStop fires → saves verdict only (not memory)

plan-reviewer (BROKEN):
  Native agent delegation (no worktree)
  → runs in MAIN working directory
  → tools: Read, Grep, Glob, TodoWrite ONLY
  → NO Write, NO Edit, NO Bash
  → CANNOT write any files at all ✗
  → SubagentStop fires → saves verdict only (not memory)
```

---

## 3. Root Cause Analysis

### ROOT CAUSE 1: Worktree Isolation Destroys code-reviewer Memory (CRITICAL)

**Problem:** code-reviewer runs with `isolation: worktree` (code-reviewer.md:16). Temporary git worktree is created per review. Agent operates in worktree directory. All file writes go to worktree filesystem.

**Why memory is lost:** code-reviewer is read-only by design (RULE_1: "Do NOT fix code, only recommend"). Since it makes NO source code changes, Claude Code classifies the worktree as "no changes made" and **automatically cleans it up** when the agent finishes. Any memory files written in the worktree are deleted with it.

**Evidence:**
- `isolation: worktree` in code-reviewer.md frontmatter (line 16)
- `.claude/agent-memory/code-reviewer/` is empty despite `memory: project` being set
- Git history shows files WERE there (manually committed), proving the directory structure works
- code-researcher (no worktree) successfully writes memory

**Affected:** code-reviewer only (plan-reviewer has no worktree)

### ROOT CAUSE 2: plan-reviewer Has No File Write Capability (CRITICAL)

**Problem:** plan-reviewer's tool list explicitly includes only Read, Grep, Glob, TodoWrite. Write, Edit, and Bash are all absent. Bash is even in `disallowedTools` (plan-reviewer.md:16-17).

**Why memory is lost:** The agent physically cannot create or modify files. Despite having `memory: project` in frontmatter and Memory instructions telling it to save patterns on completion, it has no tool to perform the write operation.

**Evidence:**
- `tools: [Read, Grep, Glob, TodoWrite]` + `disallowedTools: [Write, Edit, Bash]`
- `.claude/agent-memory/plan-reviewer/` has been empty since creation (never had files in git)
- Memory section (lines 172-179) instructs saving patterns — impossible with current tools

**Affected:** plan-reviewer only

### ROOT CAUSE 3: No Memory Sync Mechanism Between Worktree and Main Directory (STRUCTURAL)

**Problem:** No hook or script exists to copy agent memory files from a worktree back to the main working directory before cleanup.

**Evidence:**
- `prepare-worktree.sh` (WorktreeCreate hook) copies .env, runs go mod download — **does NOT handle agent memory**
- `save-review-checkpoint.sh` (SubagentStop hook) extracts verdict only — **does NOT copy memory files**
- No WorktreeDestroy/WorktreeCleanup hook exists in settings.json
- Worktree cleanup is internal to Claude Code — no user-accessible hook point

**Impact:** Even if code-reviewer successfully writes memory in the worktree, there's no mechanism to preserve it.

### ROOT CAUSE 4: RULE_5 Deprioritizes Memory to End of Turn Budget (CONTRIBUTING)

**Problem:** Both code-reviewer (RULE_5, line 34) and plan-reviewer (Rules, line 35) have "Output First" rules:
> "ALWAYS form verdict + handoff output BEFORE any memory save. Memory is OPTIONAL; output is MANDATORY. If you have used 35+ tool calls, IMMEDIATELY skip to VERDICT and form output — do NOT start memory operations."

**Impact:** Memory saves happen LAST, when the agent is most likely to be out of turns. Combined with maxTurns: 45 (code-reviewer) / 40 (plan-reviewer), complex reviews consume most turns on the actual review, leaving no budget for memory writes.

**This is by design** — output is more important than memory. But it means memory writes are the first thing cut when resources are tight, making the problem worse.

### ROOT CAUSE 5: `memory: project` Frontmatter Does Not Grant Implicit Write Access

**Problem:** The `memory: project` key in agent frontmatter creates the agent-memory subdirectory and instructs the agent to use memory, but **does not add Write/Edit to the agent's tool list**. The agent must have Write, Edit, or Bash in its explicit tools list to actually write memory files.

**Evidence:**
- code-researcher: has `memory: project` + Bash tool → CAN write via Bash
- plan-reviewer: has `memory: project` + no write tools → CANNOT write
- code-reviewer: has `memory: project` + Bash tool + worktree → writes are lost

---

## 4. Detailed Problem Chain

```
[Transfer to new project]
    │
    ├─ .claude/agent-memory/code-researcher/ = EMPTY
    ├─ .claude/agent-memory/code-reviewer/   = EMPTY
    └─ .claude/agent-memory/plan-reviewer/   = EMPTY
    │
    ▼
[Run /workflow]
    │
    ├─► /planner invokes code-researcher (Agent tool)
    │     → No worktree, has Bash
    │     → Memory section: "save newly discovered codebase structure"
    │     → Writes MEMORY.md + topic files via Bash
    │     → Files persist in main directory
    │     → RESULT: code-researcher memory POPULATED ✓
    │
    ├─► plan-reviewer (native agent)
    │     → No worktree, but NO Write/Edit/Bash
    │     → Memory section: "save newly discovered patterns"
    │     → Cannot execute write operations
    │     → RESULT: plan-reviewer memory EMPTY ✗
    │
    ├─► /coder may invoke code-researcher
    │     → Same as above → memory continues accumulating ✓
    │
    └─► code-reviewer (native agent, worktree)
          → Worktree created → prepare-worktree.sh fires
          → Agent reviews code, reaches Memory phase
          → Has Bash → writes to WORKTREE/.claude/agent-memory/code-reviewer/
          → Agent finishes (read-only, no source changes)
          → Worktree cleaned up → memory files DESTROYED
          → save-review-checkpoint.sh fires → saves verdict only
          → RESULT: code-reviewer memory EMPTY ✗
```

---

## 5. Improvement Proposals

### IMP-01: Add Memory Sync to SubagentStop Hook (PRIORITY: P0)

**What:** Extend `save-review-checkpoint.sh` to copy agent memory files from the worktree to the main working directory before the worktree is cleaned up.

**Implementation:**
```bash
# In save-review-checkpoint.sh, after verdict extraction:
# Sync agent memory from worktree to main repo
worktree_path = data.get("worktree_path", "")
agent_type = data.get("agent_type", "")
if worktree_path and agent_type:
    src = os.path.join(worktree_path, ".claude", "agent-memory", agent_type)
    dst = os.path.join(".claude", "agent-memory", agent_type)
    if os.path.isdir(src):
        os.makedirs(dst, exist_ok=True)
        for f in os.listdir(src):
            shutil.copy2(os.path.join(src, f), os.path.join(dst, f))
```

**Why:** SubagentStop fires BEFORE worktree cleanup (it's a blocking hook). The hook already receives agent metadata. Adding memory sync here is the natural extension point — no new hooks needed, minimal change to existing infrastructure.

**Benefit:** code-reviewer memory persists across sessions. Accumulated review patterns (anti-patterns, project conventions, regex issues) survive worktree cleanup and inform future reviews.

**Risk:** Low. Additive change. Failure is non-blocking (memory is NON_CRITICAL per CLAUDE.md).

---

### IMP-02: Add Write Tool to plan-reviewer (PRIORITY: P0)

**What:** Add `Write` to plan-reviewer's tools list (or at minimum, add `Bash`). Remove `Write` from `disallowedTools`.

**Implementation:**
```yaml
# In .claude/agents/plan-reviewer.md frontmatter:
tools:
  - Read
  - Grep
  - Glob
  - TodoWrite
  - Write          # ADD: enables memory writes
disallowedTools:
  - Edit           # Still blocked (no code modification)
  - Bash           # Still blocked (no command execution)
```

**Why:** plan-reviewer has `memory: project` and explicit Memory instructions to save patterns, but physically cannot write files. This is a configuration contradiction — the intent is clear, the capability is missing.

**Benefit:** plan-reviewer accumulates review patterns over time. Recurring plan issues (missing sections, architecture violations) are remembered, making subsequent reviews faster and more consistent.

**Risk:** Low. Write tool is scoped — plan-reviewer instructions (RULE_1: "NEVER modify the plan") prevent misuse. The Write tool would only be used for memory directory writes.

**Alternative:** Add `Bash` instead of `Write` for consistency with code-researcher. However, `Write` is more explicit about intent and doesn't open shell access.

---

### IMP-03: Add Write Tool to code-reviewer (PRIORITY: P1)

**What:** Add `Write` to code-reviewer's tools list.

**Implementation:**
```yaml
# In .claude/agents/code-reviewer.md frontmatter:
tools:
  - Read
  - Grep
  - Glob
  - Bash
  - TodoWrite
  - Write          # ADD: enables memory writes
```

**Why:** Currently code-reviewer relies on Bash for memory writes (indirect, less reliable). Adding Write makes the intent explicit and gives the agent a direct file creation tool. Combined with IMP-01 (memory sync), this ensures memory files are created AND preserved.

**Benefit:** More reliable memory writes. Write tool is the natural way to create files in Claude Code. Bash workaround (`echo > file`) is fragile and may be blocked by `protect-files.sh` hook.

**Risk:** Low. code-reviewer RULE_1 prevents source modification. Memory writes target `.claude/agent-memory/` only.

---

### IMP-04: Verify SubagentStop Hook Receives worktree_path (PRIORITY: P0)

**What:** Verify that the SubagentStop hook event payload includes `worktree_path` for worktree-isolated agents. If not available, add fallback detection.

**Implementation:**
```python
# Fallback: detect worktree path from agent context
if not worktree_path:
    # Check if agent_type is a known worktree agent
    worktree_agents = {"code-reviewer"}
    if agent_type in worktree_agents:
        # Scan for recent worktree in .git/worktrees/
        worktrees_dir = os.path.join(".git", "worktrees")
        if os.path.isdir(worktrees_dir):
            # Find most recent worktree
            entries = sorted(os.listdir(worktrees_dir),
                           key=lambda d: os.path.getmtime(os.path.join(worktrees_dir, d)),
                           reverse=True)
            if entries:
                gitdir = os.path.join(worktrees_dir, entries[0], "gitdir")
                if os.path.isfile(gitdir):
                    worktree_path = open(gitdir).read().strip().rsplit("/.git", 1)[0]
```

**Why:** SubagentStop hook contract (`save-review-checkpoint.sh`) currently extracts `agent_type`, `session_id`, `last_assistant_message`. It's unclear if `worktree_path` is included. Without this field, IMP-01 cannot work.

**Benefit:** Enables IMP-01. Also useful for other worktree-related post-processing.

**Risk:** Medium. SubagentStop payload contract is not fully documented. Fallback via `.git/worktrees/` scanning is heuristic. Should be logged to `worktree-events-debug.jsonl` for contract discovery.

---

### IMP-05: Dedicated Memory Sync Script (PRIORITY: P1)

**What:** Create a standalone `sync-agent-memory.sh` script that can be called from SubagentStop or as a utility.

**Implementation:** New file `.claude/scripts/sync-agent-memory.sh`:
```bash
#!/bin/bash
# Syncs agent memory from worktree to main repository
# Args: $1=agent_type, $2=worktree_path
# Called from save-review-checkpoint.sh or manually
```

**Why:** Separating memory sync from verdict extraction follows single-responsibility principle. Makes memory sync testable independently. Reusable if other worktree-isolated agents are added in the future.

**Benefit:** Clean separation of concerns. Easier debugging when memory sync fails. Can be tested independently of SubagentStop hook.

**Risk:** Low. Additive. Non-blocking by design (memory is NON_CRITICAL).

---

### IMP-06: Memory Budget Reservation in RULE_5 (PRIORITY: P2)

**What:** Modify RULE_5 in code-reviewer and plan-reviewer to reserve 2-3 turns for memory operations.

**Current (code-reviewer.md:34):**
> "If you have used 35+ tool calls, IMMEDIATELY skip to VERDICT..."

**Proposed:**
> "If you have used 33+ tool calls, IMMEDIATELY skip to VERDICT... Reserve last 2 turns after output for memory save. If turns exhausted after output — skip memory."

**Why:** Current threshold (35 out of 45 maxTurns) leaves 10 turns for verdict + handoff + memory. In practice, verdict formatting and handoff consume 5-8 turns, leaving 2-5 for memory. But the instruction says to skip memory entirely at 35+. Lowering the threshold by 2 and explicitly reserving turns makes memory more likely to happen.

**Benefit:** Higher probability of memory writes completing before turn limit. Memory accumulates faster across workflow runs.

**Risk:** Low. 2-turn reduction in review budget is negligible for review quality. Memory saves are fast (1-2 tool calls).

---

### IMP-07: Add Edit Tool to code-reviewer (PRIORITY: P2)

**What:** Add `Edit` to code-reviewer's tools list for incremental memory file updates.

**Why:** When code-reviewer already has memory files (from previous runs), it needs to UPDATE them — not overwrite. Write creates new files; Edit modifies existing ones. Without Edit, the agent must read the full file, then Write the entire content — wasting turns.

**Benefit:** More efficient memory updates. Agent can append to MEMORY.md index or update a topic file without rewriting the whole thing.

**Risk:** Low. RULE_1 prevents source code editing. Edit would target `.claude/agent-memory/` only.

**Dependency:** IMP-01 must be implemented first (memory must persist to be editable).

---

### IMP-08: Memory Instructions Parity Across All Three Agents (PRIORITY: P2)

**What:** Standardize memory instructions across code-researcher, code-reviewer, and plan-reviewer to follow the same pattern.

**Current state:**
| Agent | Startup Memory | Completion Memory | First Run Init | MEMORY.md Limit |
|-------|---------------|-------------------|----------------|-----------------|
| code-researcher | Read topology | Save structure | Save package summary | 200 lines |
| code-reviewer | Read patterns | Save patterns (AFTER output) | Save conventions | 200 lines |
| plan-reviewer | Read patterns | Save patterns (AFTER output) | Save layer structure | 200 lines |

**Issue:** Instructions are similar but not identical. code-researcher doesn't have the "AFTER output" ordering constraint. All three would benefit from a shared memory protocol.

**Implementation:** Add a shared memory protocol section to workflow-protocols skill:
```yaml
agent_memory_protocol:
  startup: "Read .claude/agent-memory/{agent_name}/MEMORY.md for context"
  completion: "AFTER primary output — save discovered patterns"
  first_run: "Initialize MEMORY.md with project structure summary"
  limit: "MEMORY.md under 200 lines"
  ordering: "Output FIRST, memory SECOND (NON_CRITICAL)"
```

**Benefit:** Single source of truth for memory behavior. Changes propagate to all agents. Easier to maintain and debug.

**Risk:** Very low. Documentation/instruction change only.

---

### IMP-09: Add prepare-worktree.sh Memory Pre-seeding (PRIORITY: P3)

**What:** Extend `prepare-worktree.sh` to copy agent memory from the main directory INTO the worktree, so the agent starts with existing memory.

**Implementation:**
```python
# In prepare-worktree.sh, section 3:
# 3c. Pre-seed agent memory into worktree
agent_memory_src = os.path.join(original_repo_dir, ".claude", "agent-memory")
agent_memory_dst = os.path.join(worktree_path, ".claude", "agent-memory")
if os.path.isdir(agent_memory_src):
    shutil.copytree(agent_memory_src, agent_memory_dst, dirs_exist_ok=True)
    setup_actions.append("agent_memory_seeded")
```

**Why:** Even with IMP-01 (sync back), the worktree starts empty. The agent reads memory at startup — if the worktree doesn't have memory files, the startup read fails silently. Pre-seeding ensures the agent has access to accumulated memory from the start.

**Benefit:** Bidirectional memory flow: main → worktree (pre-seed at start) → worktree → main (sync at end). Agent starts with full context and saves new findings.

**Dependency:** Requires `original_repo_dir` in WorktreeCreate hook payload (may need contract discovery).

**Risk:** Low. Non-blocking (prepare-worktree.sh always exits 0). Additive.

---

## 6. Implementation Priority Matrix

| ID | Title | Priority | Effort | Depends On | Impact |
|----|-------|----------|--------|------------|--------|
| IMP-01 | Memory sync in SubagentStop | P0 | M | IMP-04 | Fixes code-reviewer memory loss |
| IMP-02 | Write tool for plan-reviewer | P0 | S | — | Fixes plan-reviewer memory (complete fix) |
| IMP-04 | Verify worktree_path in SubagentStop | P0 | S | — | Enables IMP-01 |
| IMP-03 | Write tool for code-reviewer | P1 | S | — | More reliable memory writes |
| IMP-05 | Dedicated sync-agent-memory.sh | P1 | M | IMP-01 | Clean separation of concerns |
| IMP-06 | Memory budget reservation | P2 | S | — | Higher memory write success rate |
| IMP-07 | Edit tool for code-reviewer | P2 | S | IMP-01 | Efficient memory updates |
| IMP-08 | Memory instructions parity | P2 | S | — | Consistency, maintainability |
| IMP-09 | Memory pre-seeding in worktree | P3 | M | IMP-01 | Bidirectional memory flow |

### Recommended Implementation Order

```
Phase 1 (immediate fix):
  IMP-04 → IMP-01 → IMP-02
  Result: Both reviewers can write AND persist memory

Phase 2 (reliability):
  IMP-03 → IMP-05 → IMP-06
  Result: More reliable memory writes, clean architecture

Phase 3 (optimization):
  IMP-07 → IMP-08 → IMP-09
  Result: Efficient updates, consistency, full bidirectional flow
```

---

## 7. Summary

### Why code-researcher memory works

1. **No worktree** — runs in main working directory
2. **Has Bash** — can write files via shell commands
3. **No priority constraint** — no RULE_5 deprioritizing memory
4. **Invoked via Agent/Task tool** — SubagentStop doesn't fire (no hook interference, no hook benefit needed)

### Why code-reviewer memory is broken

1. **Worktree isolation** (ROOT CAUSE) — writes go to temporary directory that's destroyed
2. **No memory sync** — no mechanism to copy memory from worktree to main repo
3. **RULE_5** — memory writes happen last, often skipped due to turn budget
4. **No Write tool** — must use Bash workaround (less reliable)

### Why plan-reviewer memory is broken

1. **No write tools at all** (ROOT CAUSE) — cannot create/modify files on disk
2. **RULE_5** — same priority constraint as code-reviewer
3. **Configuration contradiction** — `memory: project` + Memory instructions exist, but no tool to execute them

### Minimum viable fix

**IMP-02** (add Write to plan-reviewer) + **IMP-04 + IMP-01** (verify worktree_path + memory sync in SubagentStop) = both reviewer agents accumulate memory across workflow runs.
