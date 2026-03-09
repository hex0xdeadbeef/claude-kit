---
name: planner-rules
description: Task analysis and planning rules for /planner command. Load at /planner startup (step 0) or when /workflow enters Phase 1. Covers: task classification (7 types), S/M/L/XL complexity routing, code-researcher delegation (L/XL), plan documentation with full code examples.
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

## Instructions

### Step 1: Classify the task
Use Task Classification above to determine type (new_feature, bug_fix, etc.)
and Complexity & Routing table for S/M/L/XL classification.
Output: task type + complexity + route + ST requirement.

### Step 2: Load required references
- ALWAYS load: [MCP Tools](mcp-tools.md)
- Complexity L/XL: also load [Sequential Thinking Guide](sequential-thinking-guide.md)
- Complexity M+: also load [Data Flow](data-flow.md)
- For full classification details: [Task Analysis](task-analysis.md)

### Step 3: Research with appropriate tools
- S/M: use Grep/Glob directly for codebase research
- L/XL: delegate to code-researcher agent via Task tool for multi-package research
- ALWAYS check Memory (mcp__memory__search_nodes) before research

### Step 4: Document plan with full code examples
Write plan to `.claude/prompts/{feature}.md` using plan template.
CRITICAL: Code examples must be FULL (complete function bodies), not just signatures.
Form handoff payload for plan-review.

## Example

### Code completeness in plans

**Good — full function body:**
```go
func (s *Service) Do(ctx context.Context, id string) error {
    result, err := s.repo.Get(ctx, id)
    if err != nil {
        return fmt.Errorf("get item: %w", err)
    }
    return nil
}
```

**Bad — signature only:**
```go
func (uc *UseCase) Do(ctx context.Context) error
```
**Why:** Incomplete example — only signature without body. Coder needs complete examples with function body, error wrapping, and context propagation.

For more examples, see [Examples](examples.md).

## Common Issues

### Plan has incomplete code examples
**Cause:** Planner shows function signature without body.
**Fix:** RULE: Full Examples — all code in plan must have complete function bodies, error handling, and context propagation.

### Sequential Thinking skipped for complex plan
**Cause:** Planner thinks plan is simple, but has 5+ parts.
**Fix:** ALWAYS use Sequential Thinking if Parts >= 5 or alternatives >= 3.

### Memory not checked before planning
**Cause:** Rushed directly to research phase.
**Fix:** STARTUP step 2 is MANDATORY — run mcp__memory__search_nodes before any research.

For all troubleshooting cases, see [Troubleshooting](troubleshooting.md).

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
- [code-researcher agent](../../agents/code-researcher.md) — available via Task tool for multi-package research (L/XL complexity, skip for S/M and --minimal)
