# Workflow Architecture (global — loaded every session)

> Note: the kit's `/workflow` (singular) command below is the dev pipeline — distinct from Claude Code's native `/workflows` (plural) dynamic-workflows feature + `Workflow` tool (2.1.154).


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

Model Routing (all workflow pipeline agents: opus + effort:xhigh):
- opus (effort: xhigh): /workflow, /planner, /designer, /coder, /meta-agent, /project-researcher, plan-reviewer, code-reviewer
- haiku (effort: medium): code-researcher — fast read-only codebase exploration
- haiku (effort: low): verdict-recovery — minimal fallback agent for missing verdicts

Context (v2.1.94+):
- Claude Code default effort changed from `medium` → `high` for API-key/Team/Enterprise users in v2.1.94
- `effort: xhigh` is the top frontmatter/settings effort tier on Opus 4.8 (which defaults to `high`). `max` is a session-only `/effort` value and is NOT honored in agent/skill frontmatter or settings — an `effort: max` frontmatter silently degrades to the default `high`. Valid frontmatter values: `low|medium|high|xhigh` (Claude Code 2.1.154+; CHANGELOG `2.1.154`, `2.1.111` introduced `xhigh`).
- Reviewers and coder migrated sonnet → opus in v1.9.0 (09acec9) to satisfy the maximum-effort (`xhigh`) constraint
- Pair with `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1` (set globally) to prevent mid-task adaptive throttling

## Maintenance Conventions

Hook stderr label convention + canonical path conventions (kit-authoring docs) are
path-scoped in `.claude/rules/kit-authoring-conventions.md` — they auto-load when
editing kit `.claude/**` files instead of every session.
