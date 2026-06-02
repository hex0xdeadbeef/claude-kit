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
| State Layer | On-demand (debugging state issues, Phase 5 cleanup) | File contracts, lifecycle rules, cleanup protocol for .claude/workflow-state/ |
| Re-routing | On complexity mismatch signal | Downgrade/upgrade route + tracking + learning |
| Pipeline Metrics | At completion phase only | Format (12 fields), storage (JSONL file), analysis, anomaly detection |
| Agent Memory | Agent startup + completion | Shared memory behavior for all `memory: project` agents |
| Parallel Dispatch | 2+ independent tasks identified (L/XL) | Multi-agent dispatch patterns (research + future debugging) |

## Instructions

### Step 1: Load at /workflow startup (step 0.1)
Read this SKILL.md for protocol overview. Then load Core Deps files:
[Autonomy](autonomy.md), [Orchestration Core](orchestration-core.md).

### Step 2: Use event-driven protocol loading
Do NOT load all protocols upfront. Load on-demand per Event Triggers below:
- Completing a phase → read [Checkpoint Protocol](checkpoint-protocol.md)
- Forming handoff OUTSIDE Phase-2/4 delegation (e.g. designer→planner) → read [Handoff Contracts](handoff-contracts.md) (5 KB, core contracts only)
  On the Phase-2/4 delegation path the contract shapes are already inlined in [Delegation Templates](delegation-templates.md) — do NOT also load handoff-contracts.md or handoff-protocol.md there. Read [Handoff Protocol](handoff-protocol.md) ONLY when authoring a net-new IMP-02/03/04 envelope.
- Mismatch signal → read [Re-routing](re-routing.md)
- All phases done → read [Pipeline Metrics](pipeline-metrics.md)

### Step 3: Always form handoff payload
CRITICAL: Every phase MUST produce a structured handoff payload (context + artifact + metadata) for the next phase.
Read [Handoff Contracts](handoff-contracts.md) for the 5 pipeline contracts before forming a handoff OUTSIDE Phase-2/4 delegation. On the Phase-2/4 delegation path the shapes are already inlined in [Delegation Templates](delegation-templates.md) — do NOT also load handoff-contracts.md or handoff-protocol.md there.
For IMP-02/03/04 implementation details (verdict envelopes, ID normalization, diff-based replan), read [Handoff Protocol](handoff-protocol.md) ONLY when authoring a net-new envelope.

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
- Forming handoff OUTSIDE Phase-2/4 delegation (e.g. designer→planner) → read [Handoff Contracts](handoff-contracts.md) (5 KB, core contracts only)
  On the Phase-2/4 delegation path the contract shapes are already inlined in [Delegation Templates](delegation-templates.md) — do NOT also load handoff-contracts.md or handoff-protocol.md there. Read [Handoff Protocol](handoff-protocol.md) ONLY when authoring a net-new IMP-02/03/04 envelope.
- plan-review or coder signals mismatch → re-route (see [Re-routing](re-routing.md))
- All phases done → collect metrics (see [Pipeline Metrics](pipeline-metrics.md))
- Phase 5 cleanup → read cleanup protocol (see [State Layer](state-layer.md))
- Multiple independent tasks identified (L/XL planner research, or independent failures) → read [Parallel Dispatch](parallel-dispatch.md)
- Problem encountered → see [Examples & Troubleshooting](examples-troubleshooting.md)
- Entering Phase 2 or Phase 4 delegation → read [Delegation Templates](delegation-templates.md) (IMP-01/03/04 protocol details)
- INCOMPLETE verdict detected → read [Incomplete Output Recovery](incomplete-output-recovery.md) AND [Unknown Verdict Recovery](unknown-verdict-recovery.md) (IMP-06 UNKNOWN resolution rules + IMP-02 filter predicates)
- Checkpoint missing (heuristic session recovery) OR loop limit reached (3/3) → read [Counter Recovery](counter-recovery.md) (counter_recovery heuristic + iteration_summary_on_stop format)

## Core Deps (workflow-only, loaded at startup)
These files define fundamental workflow behavior and are loaded at pipeline startup (step 0.1):
- [Autonomy](autonomy.md) — 3 modes (INTERACTIVE/AUTONOMOUS/RESUME), stop/continue conditions
- [Orchestration Core](orchestration-core.md) — pipeline phases, loop rules (max 3), session recovery tables. Heavy recovery paths (IMP-06 UNKNOWN verdict, counter heuristics, loop-limit summary) are extracted to on-demand files (see Protocol References).

## Protocol References
For detailed protocol specifications, read the supporting files in this skill directory:
- [Handoff Contracts](handoff-contracts.md) — 5 core contracts, lightweight (5 KB); use for common-path handoff formation
- [Handoff Protocol](handoff-protocol.md) — full protocol: 5 contracts + IMP-02/03/04 implementation details (22 KB)
- [Diff Manifest](diff-manifest.md) — diff-based re-plan algorithm (STEP 0.5) + planner re-invocation template; load on iter 2+ only
- [Delegation Templates](delegation-templates.md) — full delegation prompts + pre/post_delegation for plan-review and code-review (IMP-01/03/04); load ONLY before Phase 2 or Phase 4 delegation
- [Incomplete Output Recovery](incomplete-output-recovery.md) — output_validation checks + step_0..step_5 INCOMPLETE verdict fallback chain; load ONLY on INCOMPLETE verdict
- [Checkpoint Protocol](checkpoint-protocol.md) — format, recovery, example
- [State Layer](state-layer.md) — file contracts, lifecycle categories, cleanup protocol for .claude/workflow-state/
- [Re-routing](re-routing.md) — 3 triggers + tracking fields + learning
- [Pipeline Metrics](pipeline-metrics.md) — format, storage, analysis, anomaly detection
- [Examples & Troubleshooting](examples-troubleshooting.md) — execution examples, common mistakes, troubleshooting
- [Agent Memory Protocol](agent-memory-protocol.md) — shared memory behavior for all `memory: project` agents
- [Parallel Dispatch](parallel-dispatch.md) — decision flowchart, research multi-dispatch, failure isolation, conflict detection
- [Unknown Verdict Recovery](unknown-verdict-recovery.md) — IMP-06 UNKNOWN verdict resolution rules + IMP-02 filter predicates + anti-patterns + cost comparison; load ONLY on INCOMPLETE verdict
- [Counter Recovery](counter-recovery.md) — counter_recovery heuristic (missing checkpoint) + iteration_summary_on_stop format (3/3 limit hit); load ONLY when the trigger fires
