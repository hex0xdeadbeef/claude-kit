# Workflow Architecture (global — loaded every session)

Commands (`.claude/commands/` — shared context with orchestrator):
- `/workflow` — full dev cycle (orchestrator)
- `/planner` — codebase research + plan creation
- `/coder` — implementation per approved plan

Agents (`.claude/agents/` — isolated context, clean review):
- `plan-reviewer` — architecture compliance + completeness validation
- `code-reviewer` — code review: architecture, security, tests, style
- `code-researcher` — read-only codebase exploration (haiku, Agent/Task tool, supports background mode)

Design Decision — Commands vs Agents:
- Commands run INSIDE orchestrator context → shared task analysis, memory, handoffs
- Agents run in CLEAN context → unbiased review, no creation history bias
- This split is intentional. Do NOT migrate commands to agents.

Model Routing (opus → sonnet → haiku):
- opus: planning + orchestration (/workflow, /planner) — deep reasoning, architecture
- sonnet: execution + review (/coder, plan-reviewer, code-reviewer) — implementation per plan, pattern matching
- haiku: exploration (code-researcher) — fast read-only search
