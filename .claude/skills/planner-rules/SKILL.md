---
name: planner-rules
description: Task classification, complexity routing, data flow analysis, and planning patterns for planner command
disable-model-invocation: true
---

# Planner Rules

## Task Classification

Classify task type before any research:
- new_feature: add, create, implement, new endpoint → typical M-XL
- bug_fix: fix, bug, broken, not working → typical S-M
- refactoring: refactor, rewrite, extract, split → typical M-L
- config_change: config, parameter, environment variable → typical S
- documentation: documentation, README, describe → typical S
- performance: optimization, slow, N+1, cache → typical M-L
- integration: external service, API call, client → typical L-XL

## Complexity & Routing

| Complexity | Parts | Layers | Route | Sequential Thinking | Plan Review |
|------------|-------|--------|-------|---------------------|-------------|
| S | 1 | 1 | minimal | NOT needed | SKIP |
| M | 2-3 | 2 | standard | as needed | standard |
| L | 4-6 | 3+ | standard | RECOMMENDED | standard |
| XL | 7+ | 4+ | full | REQUIRED | standard |

## Auto-Escalation (re-routing)
- plan-review finds more Parts than expected → upgrade complexity
- coder finds hidden complexity (3+ adjustments) → upgrade + return to planner
- plan-review finds fewer Parts → downgrade complexity

## Core Deps (loaded at startup)
- [MCP Tools](mcp-tools.md) — Memory, Sequential Thinking, Context7, PostgreSQL patterns and fallbacks
- [Sequential Thinking Guide](sequential-thinking-guide.md) — when/how to use ST (complexity L/XL only, SKIP for S/M)

## References
For detailed checks, read the supporting files in this skill directory:
- [Task Analysis](task-analysis.md) — full classification matrix, routing rules, preconditions, re-routing mechanism, examples
- [Data Flow](data-flow.md) — data origin/path analysis, layer placement rules (SKIP for S, LOAD for M+)
- [Examples](examples.md) — good vs bad code examples for plans
- [Checklist](checklist.md) — self-verification at each planner phase
- [Troubleshooting](troubleshooting.md) — common planner issues and fixes
