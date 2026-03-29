# Plan Reviewer — Agent Memory

## Project Identity
- Config framework for Claude Code — artifacts are Markdown/YAML, not Go application code
- "Architecture" checks = pipeline ordering, command vs agent convention, handoff contract structure
- No Go import matrix to check; validate config pipeline conventions instead

## Key Review Patterns
- See [config-pipeline-conventions.md](config-pipeline-conventions.md) — what passes/fails in this project type
- See [common-issues.md](common-issues.md) — recurring mistakes found in plans

## Review Checklist Priorities (this project)
1. Commands vs Agents convention (commands = shared context; agents = clean isolated context)
2. Handoff contract completeness — all new fields in handoff_output must appear in the contract schema
3. Session recovery table integrity — never remove existing columns/rows when adding new ones
4. Skip/routing logic placement — always at orchestrator level, not inside the command/agent
5. Cross-reference consistency — all 12+ files that reference each other must be updated together
