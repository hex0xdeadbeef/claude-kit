---
name: coder-rules
description: 5 CRITICAL implementation rules, evaluate protocol, and coding patterns for coder command
disable-model-invocation: true
---

# Coder Rules

## 5 CRITICAL Rules

- RULE_1 Plan Only: Implement ONLY what's in the plan. No improvements.
- RULE_2 Import Matrix: NEVER violate the import matrix.
- RULE_3 Clean Domain: NEVER add encoding/json tags to domain entities (tags belong in DTOs).
- RULE_4 No Log+Return: NEVER log AND return error simultaneously.
- RULE_5 Tests Pass: Code NOT ready until tests pass.

## Evaluate Protocol

Before implementation, critically evaluate plan (Phase 1.5):
- PROCEED: Plan is implementable as-is → start implementation
- REVISE: Minor gaps, can fix inline → note adjustments, proceed
- RETURN: Major gaps or feasibility issues → return to /plan-review with feedback

Evaluate checks: feasibility, hidden complexities, edge cases, performance, dependencies.
Output: `.claude/prompts/{feature}-evaluate.md`

## Core Deps (loaded at startup)
- [MCP Tools](mcp-tools.md) — Memory, Sequential Thinking, Context7, PostgreSQL patterns and fallbacks

## References
For detailed checks, read the supporting files in this skill directory:
- [Examples](examples.md) — bad/good code patterns, layer import rules
- [Checklist](checklist.md) — self-verification at each coder phase
- [Troubleshooting](troubleshooting.md) — common coder issues and fixes
