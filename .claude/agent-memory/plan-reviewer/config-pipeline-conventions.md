---
name: config-pipeline-conventions
description: What passes/fails architecture checks in this config framework project (Markdown/YAML artifacts, not Go code)
type: project
---

# Config Pipeline Conventions

**Why:** This project has no Go application code. Architecture validation must be adapted to the config pipeline, not the Go import matrix.

**How to apply:** When reviewing plans for this project, replace Go-layer checks with these config-layer checks.

## Import Matrix Equivalent (config pipeline)
- Commands run in orchestrator shared context (workflow-owned phases)
- Agents run in clean isolated context (review phases only)
- Skills are loaded on-demand by commands/agents, never by other skills
- Templates are consumed by commands/agents, never by other templates
- Violation: a command that calls another command directly (not via orchestrator delegation)
- Violation: an agent that modifies shared state (agents are read+verdict only)

## Handoff Contract Rules
- Every new field added to a command's handoff_output MUST appear in the corresponding contract in handoff-protocol.md
- Contract is the authoritative schema — producer and consumer must both match it
- When adding a new pipeline phase: add a new contract BEFORE the affected downstream contract

## Session Recovery Table Rules
- Never remove existing rows or columns from orchestration-core.md session recovery tables
- When adding pre-planning state (new phase), add rows at the TOP of the table or use a separate group
- Existing post-planning rows must remain intact — they cover the most common crash recovery scenarios

## Skip/Routing Logic Placement
- Skip conditions ALWAYS live in the orchestrator (workflow.md), not inside the command
- Commands may declare trigger hints (for documentation), but the routing decision is orchestrator-owned
- Example: /designer has TRIGGERS section for documentation, but workflow.md step 0.2 is what actually routes
