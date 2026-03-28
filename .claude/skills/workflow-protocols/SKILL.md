---
name: workflow-protocols
description: Orchestration protocols for /workflow pipeline. Load at /workflow startup (step 0.1), then load individual protocols on-demand per event triggers. Covers: handoff contracts (4 phase-to-phase contracts + narrative casting), checkpoint format (session recovery), re-routing (complexity mismatch), pipeline metrics (completion tracking).
disable-model-invocation: true
---

# Workflow Protocols

## Protocol Overview

| Protocol | When to Load | Purpose |
|----------|-------------|---------|
| Handoff | BEFORE forming handoff between phases | 4 pipeline contracts + 1 tool contract (code-researcher) + narrative casting |
| Checkpoint | AFTER completing each phase | Format (12 YAML fields), recovery (5 steps), state persistence |
| Re-routing | On complexity mismatch signal | Downgrade/upgrade route + tracking + learning |
| Pipeline Metrics | At completion phase only | Format (12 fields), storage (JSONL file), analysis, anomaly detection |
| Agent Memory | Agent startup + completion | Shared memory behavior for all `memory: project` agents |

## Instructions

### Step 1: Load at /workflow startup (step 0.1)
Read this SKILL.md for protocol overview. Then load Core Deps files:
[Autonomy](autonomy.md), [Orchestration Core](orchestration-core.md).

### Step 2: Use event-driven protocol loading
Do NOT load all protocols upfront. Load on-demand per Event Triggers below:
- Completing a phase → read [Checkpoint Protocol](checkpoint-protocol.md)
- Forming handoff → read [Handoff Protocol](handoff-protocol.md)
- Mismatch signal → read [Re-routing](re-routing.md)
- All phases done → read [Pipeline Metrics](pipeline-metrics.md)

### Step 3: Always form handoff payload
CRITICAL: Every phase MUST produce a structured handoff payload (context + artifact + metadata) for the next phase.
Read [Handoff Protocol](handoff-protocol.md) for the 4 pipeline contracts (+ 1 tool contract for code-researcher) before forming any handoff.

## Example

### Handoff payload — complete vs missing

**Good — full handoff payload (planner → plan-review):**
```yaml
artifact: ".claude/prompts/add-user-endpoint.md"
metadata:
  task_type: "new_feature"
  complexity: "L"
  sequential_thinking_used: true
key_decisions:
  - "Repository pattern over direct SQL — testability"
known_risks:
  - "N+1 queries in list endpoint"
```

**Bad — skipping handoff, jumping to code:**
```yaml
# No plan created, no review requested
# → jump directly to /coder
```
**Why:** Skipping phases leads to unvalidated code without architectural review. Every phase MUST produce a handoff payload for the next phase (see [Handoff Protocol](handoff-protocol.md)).

For more examples, see [Examples & Troubleshooting](examples-troubleshooting.md).

## Common Issues

### Stuck in Phase 1 → Phase 2 loop
**Cause:** Requirements unclear or task too broad.
**Fix:** Ask user to clarify scope, break task into smaller pieces.

### Session interrupted mid-workflow
**Cause:** Connection lost, timeout, or manual stop.
**Fix:** Check `.claude/prompts/{feature}.md` for saved plan, use `--from-phase` to resume.

### Phase 2 keeps returning NEEDS_CHANGES
**Cause:** Plan missing critical sections (Scope, Architecture Decision, Tests).
**Fix:** Check plan against `templates/plan-template.md`, ensure all sections filled.

For all troubleshooting cases, see [Examples & Troubleshooting](examples-troubleshooting.md).

## Event Triggers
- Phase completed → write checkpoint (see [Checkpoint Protocol](checkpoint-protocol.md))
- Forming handoff → read handoff contract (see [Handoff Protocol](handoff-protocol.md))
- plan-review or coder signals mismatch → re-route (see [Re-routing](re-routing.md))
- All phases done → collect metrics (see [Pipeline Metrics](pipeline-metrics.md))
- Problem encountered → see [Examples & Troubleshooting](examples-troubleshooting.md)

## Core Deps (workflow-only, loaded at startup)
These files define fundamental workflow behavior and are loaded at pipeline startup (step 0.1):
- [Autonomy](autonomy.md) — 3 modes (INTERACTIVE/AUTONOMOUS/RESUME), stop/continue conditions
- [Orchestration Core](orchestration-core.md) — pipeline phases, loop limits (max 3), session recovery

## Protocol References
For detailed protocol specifications, read the supporting files in this skill directory:
- [Handoff Protocol](handoff-protocol.md) — 4 contracts + narrative casting template
- [Checkpoint Protocol](checkpoint-protocol.md) — format, recovery, example
- [Re-routing](re-routing.md) — 3 triggers + tracking fields + learning
- [Pipeline Metrics](pipeline-metrics.md) — format, storage, analysis, anomaly detection
- [Examples & Troubleshooting](examples-troubleshooting.md) — execution examples, common mistakes, troubleshooting
- [Agent Memory Protocol](agent-memory-protocol.md) — shared memory behavior for all `memory: project` agents
