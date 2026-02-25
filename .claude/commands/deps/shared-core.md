# Shared Core — Compact Reference

Consolidated reference for all shared patterns. Commands reference specific sections via SEE links.

---

## MCP Tools

| Tool | Use When | Fallback |
|------|----------|----------|
| Memory (search_nodes, create_entities, create_relations) | Search before planning; save non-trivial decisions after | Skip — memory is enhancement |
| Sequential Thinking | 3+ alternatives OR 4+ interacting parts | Manual analysis (bullet points) |
| Context7 (resolve-library-id, query-docs) | External library API unclear | WebSearch → memory → general knowledge |
| PostgreSQL (list_tables, describe_table, query) | Schema unclear, no migrations | Migration files → SQL queries → entity structs |

**Pattern:** try-catch at use time. All MCPs are NON_CRITICAL — warn and continue.

**Memory sequence:** search_nodes → 0 results: create_entities + create_relations | 1 result: add_observations | 2+ results: ask user.

**Sequential Thinking criteria:** Use for complex trade-offs with 3+ approaches. Skip for obvious/simple decisions.

**Context7 limit:** Max 3 calls per question. Save patterns to memory for reuse.

**PostgreSQL safety:** Read-only queries only (SELECT). No INSERT/UPDATE/DELETE.

---

## Autonomy

**Modes:**
- INTERACTIVE (default): Ask at checkpoints
- AUTONOMOUS (--auto): Execute all phases without asking
- RESUME: Continue from last checkpoint (session interrupted)
- MINIMAL (--minimal): Minimal research, only critical checks

**Stop conditions:**

| Condition | Action |
|-----------|--------|
| FATAL_ERROR (plan/file not found, critical dep missing) | Stop immediately |
| USER_INTERVENTION (scope unclear, multiple approaches, user says stop) | Stop, wait for user |
| TOOL_UNAVAILABLE (MCP unavailable) | Warn, adapt, continue |
| FAILURE_THRESHOLD (tests/lint fail 3x) | Stop, request manual fix |

**Continue conditions (autonomous mode):**

| Condition | Action |
|-----------|--------|
| Phase completed | → next phase |
| Auto-fixable (lint fail → make fmt) | Fix → retry |
| Non-critical tool unavailable | Warn → continue |

---

## Beads Integration

**Core commands:**
```
bd show <id>       — view task details
bd update <id> --status=in_progress  — claim task
bd ready           — show ready issues (no blockers)
bd close <id>      — close issue (NEVER auto-close, remind user)
bd sync            — sync to remote (MANDATORY at workflow end)
bd dep add <A> <B> — A depends on B (B blocks A)
bd create --title="..." --type=task|bug|feature --priority=0-4
bd blocked          — show blocked issues
bd stats            — open/closed/blocked counts
bd doctor           — check sync, hooks, issues
```

**Priority values:** 0=Critical, 1=High, 2=Medium (default), 3=Low, 4=Backlog.

**Bulk creation:** For many issues — spawn parallel Task subagents (more efficient than sequential bd create).

**Integration by command:**

| Command | Start | End |
|---------|-------|-----|
| /planner | bd show (if beads task), check deps | No beads action |
| /coder | Task already claimed | No auto-close (wait for review) |
| /plan-review | No beads action | No beads action |
| /code-review | No beads action | If APPROVED → remind bd close |
| /workflow | bd show + bd update in_progress | bd sync (MANDATORY) + remind bd close |

**Rule:** Beads is NON_CRITICAL. If `bd` unavailable → warn, skip beads phases, continue core workflow.

---

## Error Handling

| Error | Severity | Action |
|-------|----------|--------|
| Memory MCP unavailable | NON_CRITICAL | Warn, proceed without memory |
| Sequential Thinking unavailable | NON_CRITICAL | Warn, manual analysis |
| Context7 unavailable | NON_CRITICAL | Fallback: WebSearch → memory → general knowledge |
| PostgreSQL MCP unavailable | NON_CRITICAL | Use migration files → SQL queries → entity structs |
| Beads unavailable | NON_CRITICAL | Skip beads phases |
| Beads sync failed | WARNING | Continue with local state, remind manual sync later |
| Plan not found | FATAL | EXIT — run /planner first |
| Plan not approved | FATAL | EXIT — run /plan-review first |
| Template missing | NON_CRITICAL | Use minimal format |
| Git repo issues | WARNING | Continue (may skip commit phase) |
| Tests fail 3x | STOP_AND_WAIT | Show errors, request manual fix |
| Lint fail 3x | STOP_AND_WAIT | Show issues, request decision (manual fix / nolint / config) |
| Import violation | STOP_AND_FIX | Fix before proceeding |
| Scope unclear after 2x clarification | STOP_AND_WAIT | Wait for clear requirements |
| User not responding | STOP_AND_WAIT | Wait, do NOT proceed with assumptions |

---

## Pipeline & Phases

```
task-analysis → /planner → /plan-review → /coder → /code-review
     ↓              ↓           ↓            ↓           ↓
  Classify        План    Валидация       Код       Ревью
  S → skip PR              ↓ FAIL         ↓ FAIL
                          ← назад ←      ← назад ←
                          (max 3x)       (max 3x)
```

**Phase 0.5 — Task Analysis:** Classify (type + S/M/L/XL) → Route. S: skip plan-review. L/XL: Sequential Thinking recommended/required.

**Phase 1 — Planning:** Execute /planner. Output: `.claude/prompts/{feature}.md`

**Phase 2 — Plan Review:** Execute /plan-review. APPROVED → Phase 3. NEEDS_CHANGES → Phase 1 (iteration N/3). REJECTED → Stop.

**Phase 3 — Implementation:** Execute /coder. Verify: `make fmt && make lint && make test`. PASS → Phase 4. FAIL → fix + retry.

**Phase 4 — Code Review:** Execute /code-review. APPROVED → Done. CHANGES_REQUESTED → Phase 3 (iteration N/3).

**Phase 0 — Get Task (optional):** If beads task → `bd show <id>` + `bd update <id> --status=in_progress`. Skip if ad-hoc.

**Завершение:** git commit (required) → bd sync (if beads) → remind bd close → save lessons if non-trivial.

**Lessons learned format (if saving):** create_entities with entityType="lessons_learned", observations: ["Проблема: X → Решение: Y", "Паттерн: Z работает хорошо для W"].

---

## Loop Limits

```yaml
plan_review_cycle: max 3 iterations (planner ↔ plan-review)
code_review_cycle: max 3 iterations (coder ↔ code-review)
total_phases: max 12 per /workflow run
on_exceeded: STOP → summary of each iteration → unresolved issues → request user intervention
```

---

## Context Isolation

**Rule:** Review phases (plan-review, code-review) MUST run with clean context.

**Preferred:** Launch via Task tool (subagent) — reviewer does NOT see creation process.

**Fallback:** If same context — MUST re-read artifact from file, not rely on memory.

**Narrative casting:** Pass reviewer WHAT was done (key decisions, risks, focus areas) without HOW (debug sessions, rejected approaches, intermediate thoughts). Source: `handoff_output` from previous phase.

**What reviewer receives:**
- plan-review: `.claude/prompts/{feature}.md` + narrative context block
- code-review: `git diff master...HEAD` + narrative context block

---

## Session Recovery

**Strategy:** Checkpoint-first, heuristic fallback.

**Quick check commands:**
```
ls .claude/workflow-state/*-checkpoint.yaml  # Checkpoint?
ls .claude/prompts/                          # Plan?
bd list --status=in_progress                 # Active beads?
git diff master...HEAD --stat                # Code changes?
make test                                    # Tests pass?
```

**Step 1:** Check `.claude/workflow-state/*-checkpoint.yaml`

**Step 2A — Checkpoint found:** Read → verify integrity → resume from `phase_completed + 1` → restore iteration counters.

**Step 2B — No checkpoint (heuristic):**

| Plan exists? | Code changes? | Tests pass? | Resume from |
|-------------|---------------|-------------|-------------|
| No | — | — | Phase 1: Planning |
| Yes | No | — | Phase 3: Implementation |
| Yes | Yes | No | Phase 3: Fix tests |
| Yes | Yes | Yes | Phase 4: Code Review |

**Warning:** Heuristic fallback loses iteration counters — assume iteration 1/3.

**Checkpoint format:** `{feature}-checkpoint.yaml` with fields: feature, phase_completed, phase_name, iteration (plan_review N/3, code_review N/3), verdict, timestamp, complexity, route, handoff_payload, issues_history.
