---
name: workflow-protocols
description: Handoff contracts, checkpoint format, re-routing triggers, pipeline metrics, and workflow examples for workflow orchestrator
disable-model-invocation: true
---

# Workflow Protocols

## Protocol Overview

| Protocol | When to Load | Purpose |
|----------|-------------|---------|
| Handoff | BEFORE forming handoff between phases | 4 contracts (planner→plan-review, plan-review→coder, coder→code-review, code-review→completion) + narrative casting |
| Checkpoint | AFTER completing each phase | Format (12 YAML fields), recovery (5 steps), state persistence |
| Re-routing | On complexity mismatch signal | Downgrade/upgrade route + tracking + learning |
| Pipeline Metrics | At completion phase only | Format (12 fields), storage (MCP Memory), analysis, anomaly detection |

## Event Triggers
- Phase completed → write checkpoint (see checkpoint-protocol.md)
- Forming handoff → read handoff contract (see handoff-protocol.md)
- plan-review or coder signals mismatch → re-route (see re-routing.md)
- All phases done → collect metrics (see pipeline-metrics.md)
- Problem encountered → see examples-troubleshooting.md

## Core Deps (workflow-only, loaded at startup)
These files define fundamental workflow behavior and are loaded at pipeline startup (step 0.1):
- [Autonomy](autonomy.md) — 4 modes (INTERACTIVE/AUTONOMOUS/RESUME/MINIMAL), stop/continue conditions
- [Beads Integration](beads.md) — core commands, priority values, per-command integration matrix
- [Orchestration Core](orchestration-core.md) — pipeline phases, loop limits (max 3), session recovery

## Protocol References
For detailed protocol specifications, read the supporting files in this skill directory:
- [Handoff Protocol](handoff-protocol.md) — 4 contracts + narrative casting template
- [Checkpoint Protocol](checkpoint-protocol.md) — format, recovery, example
- [Re-routing](re-routing.md) — 3 triggers + tracking fields + learning
- [Pipeline Metrics](pipeline-metrics.md) — format, storage, analysis, anomaly detection
- [Examples & Troubleshooting](examples-troubleshooting.md) — execution examples, common mistakes, troubleshooting
