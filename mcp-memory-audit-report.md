# MCP Memory Audit Report: Full Revision

**Date:** 2026-03-28
**Goal:** Verify (A) native memory works, (B) all MCP Memory integrations identified
**Scope:** All `.claude/` artifacts (146 files)

---

## Executive Summary

| Zone | Status | Detail |
|------|--------|--------|
| **Workflow Pipeline** (15 core artifacts) | CLEAN | All `mcp__memory` refs removed in prior iteration |
| **Native Memory** (Claude Code Project Memory) | INTACT | `autoMemoryEnabled: true`, file-based Agent Memory Protocol works |
| **Residual MCP Memory** | 43 points | meta-agent (35), project-researcher (8) |

---

## 1. Workflow Pipeline Verification (CLEAN)

### settings.json — MCP Servers

```json
"enabledMcpjsonServers": ["sequential-thinking", "context7", "tree_sitter"]
```
**"memory" is ABSENT** from the list.

### Per-artifact verification

| Artifact | `mcp__memory` | `MCP Memory` | `server-memory` | Status |
|----------|:---:|:---:|:---:|--------|
| commands/workflow.md | 0 | 0 | 0 | CLEAN |
| commands/planner.md | 0 | 0 | 0 | CLEAN |
| commands/coder.md | 0 | 0 | 0 | CLEAN |
| agents/plan-reviewer.md | 0 | 0 | 0 | CLEAN |
| agents/code-reviewer.md | 0 | 0 | 0 | CLEAN |
| agents/code-researcher.md | 0 | 0 | 0 | CLEAN* |
| skills/workflow-protocols/*.md | 0 | 0 | 0 | CLEAN |
| skills/planner-rules/*.md | 0 | 0 | 0 | CLEAN |
| skills/coder-rules/*.md | 0 | 0 | 0 | CLEAN |
| skills/plan-review-rules/*.md | 0 | 0 | 0 | CLEAN |
| skills/code-review-rules/*.md | 0 | 0 | 0 | CLEAN |
| rules/*.md | 0 | 0 | 0 | CLEAN |
| CLAUDE.md | 0 | 0 | 0 | CLEAN |
| PROJECT-KNOWLEDGE.md | 0 | 0 | 0 | CLEAN |
| README.md | 0 | 0 | 0 | CLEAN** |

\* code-researcher.md:81 has stale comment: `"Memory (past solutions) -> parent calls in STARTUP"`. Planner/coder no longer call MCP Memory. Recommend: remove line.

\*\* README.md:255 has mermaid label `S1["Memory search"]` in STARTUP section. Ambiguous. Recommend: rename to `S1["Session recovery"]`.

### Native Memory Verification

| Component | File | Status |
|-----------|------|--------|
| `autoMemoryEnabled: true` | settings.json:3 | ACTIVE |
| Agent Memory Protocol | agent-memory-protocol.md | INTACT |
| plan-reviewer `memory: project` | plan-reviewer.md:17 | INTACT |
| code-reviewer `memory: project` | code-reviewer.md:16 | INTACT |
| code-researcher `memory: project` | code-researcher.md:11 | INTACT |
| Agent Memory dirs | .claude/agent-memory/{agent}/ | EXIST |
| Worktree sync hook | save-review-checkpoint.sh | INTACT |

---

## 2. Residual MCP Memory (43 points in 2 ecosystems)

### 2.1. meta-agent ecosystem (35 points in 17 files)

| ID | File | What to remove | Justification |
|----|------|----------------|---------------|
| META-01 | meta-agent.md:11 | 5 mcp__memory tools from allowed-tools | Server disabled, tools unavailable |
| META-02 | meta-agent.md:434 | `storage: "mcp__memory"` | Storage unavailable |
| META-03 | meta-agent.md:482 | `"persistent (mcp__memory)"` | Incorrect documentation |
| META-04 | self-improvement.md (5 pts) | All mcp__memory refs | Entire module non-functional |
| META-05 | artifact-analyst.md:75 | mcp__memory__search_nodes | Tool unavailable |
| META-06 | artifact-fix.md (3 pts) | MCP Memory save sections | Tools unavailable |
| META-07 | eval-optimizer.md (2 pts) | mcp__memory storage | Storage unavailable |
| META-08 | artifact-quality.md:595 | `"Search mcp__memory for similar"` | Tool unavailable, Grep fallback exists |
| META-09 | artifact-archive.md:228 | mcp_memory line | Non-functional |
| META-10 | context-management.md:27 | `storage: "mcp__memory"` | Incorrect documentation |
| META-11 | blocking-gates.md:68 | `"No critical duplicates (mcp__memory)"` | Check impossible |
| META-12 | troubleshooting.md (2 pts) | MCP Memory scenarios | Dead documentation |
| META-13 | subagents.md (3 pts) | mcp__memory from tools/storage | Tools unavailable |
| META-14 | phases-onboard.md (2 pts) | MCP Memory check block | Server not in system |
| META-15 | phases-create.md:88 | mcp__memory__read_graph | Tool unavailable |
| META-16 | phases-enhance.md (5 pts) | All mcp__memory refs | Tools unavailable |
| META-17 | observability.md:40 | mcp__memory__add_observations | Tool unavailable |
| META-18 | templates/onboarding/mcp.json | memory server block | Propagates MCP Memory to new projects |
| META-19 | templates/onboarding/settings.json:5 | `"memory"` from enabledMcpjsonServers | Propagates disabled server |

### 2.2. project-researcher ecosystem (8 points in 7 files)

| ID | File | What to remove | Justification |
|----|------|----------------|---------------|
| PR-01 | generation.md:387-468 | Section 5.6 memory.json Generation | Generates for non-existent service |
| PR-02 | generation.md:468 | UPDATE memory.json line | File not generated |
| PR-03 | generation.md:9 | `"and memory.json"` | Artifact not generated |
| PR-04 | report.md:125 | Memory row in table | File not generated |
| PR-05 | verification.md:23 | memory.json line | File not verified |
| PR-06 | reflexion.md (entire file) | Rewrite or remove | Fully depends on MCP Memory |
| PR-07 | critique.md, README.md, sample-report.md | memory.json references | Stale references |

---

## 3. What NOT to remove

| Component | File | Why KEEP |
|-----------|------|----------|
| `autoMemoryEnabled: true` | settings.json:3 | Claude Code native memory — ACTIVE |
| `memory: project` frontmatter | all 3 agents | Claude Code native agent memory — ACTIVE |
| Agent Memory Protocol | agent-memory-protocol.md | File-based protocol — ACTIVE |
| Memory sections in agents | plan-reviewer, code-reviewer, code-researcher | Describe file-based memory, NOT MCP |
| SKILL.md Agent Memory row/link | workflow-protocols/SKILL.md:17,98 | File-based agent memory |
| .claude/agent-memory/ dirs | (empty dirs) | Storage for agent memory |
| save-review-checkpoint.sh | scripts/ | Syncs file-based memory from worktree |

---

## 4. Recommended execution order

```
Step 1: REM-01, REM-02          (stale refs in workflow, minimal risk)
Step 2: META-18, META-19        (onboarding templates, prevent propagation)
Step 3: META-01..03             (meta-agent command, targeted edits)
Step 4: META-04..17             (meta-agent deps, 14 files)
Step 5: PR-01..07               (project-researcher, 7 points)
Step 6: Grep verification       (final check: 0 results)
```

**Verification command:**
```bash
grep -rn "mcp__memory\|server-memory\|memory\.json\|MCP Memory" \
  .claude/commands/ .claude/agents/ .claude/skills/ .claude/rules/ \
  CLAUDE.md README.md .claude/PROJECT-KNOWLEDGE.md \
  --include="*.md" --include="*.json" --include="*.sh" | \
  grep -v "reports/" | grep -v "CHANGELOG"
```
