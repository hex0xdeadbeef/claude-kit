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

Model Routing (all workflow pipeline agents: opus + effort:max):
- opus (effort: max): /workflow, /planner, /designer, /coder, /meta-agent, /project-researcher, plan-reviewer, code-reviewer
- haiku (effort: medium): code-researcher — fast read-only codebase exploration
- haiku (effort: low): verdict-recovery — minimal fallback agent for missing verdicts

Context (v2.1.94+):
- Claude Code default effort changed from `medium` → `high` for API-key/Team/Enterprise users in v2.1.94
- `effort: max` is Opus 4.6 exclusive — enables maximum extended thinking budget
- Reviewers and coder migrated sonnet → opus in v1.9.0 (09acec9) to satisfy `effort: max` constraint
- Pair with `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1` (set globally) to prevent mid-task adaptive throttling
