# code-researcher Memory

Persistent project-shared memory for the `code-researcher` agent.
Native loader injects the first 200 lines / 25 KB at SubagentStart.

## Package Locations

- `.claude/agents/` — agent frontmatter + role docs (5 standalone agents + 3 complex agent dirs: meta-agent, project-researcher, db-explorer).
- `.claude/commands/` — slash commands (workflow, planner, coder, designer, project-researcher, meta-agent, review-checklist).
- `.claude/skills/` — 8 skill packages (workflow-protocols, planner-rules, coder-rules, plan-review-rules, code-review-rules, design-rules, systematic-debugging, tdd-rules). design-rules includes `critique-lenses.md` (the Phase 3.5 adversarial design-critique lens set).
- `.claude/scripts/` — 24 hook scripts + 1 test dir (`tests/test-*.sh`).
- `.claude/templates/` — 6 templates (plan, spec, agent, command, rule, skill, project-claude-md).
- `.claude/rules/` — 8 path-scoped rules (architecture, go-conventions, testing, workflow, handler/service/repository/models layer rules).

## Key Entry Points

- Pipeline orchestrator: `.claude/commands/workflow.md`.
- Plan output: `.claude/prompts/{feature}.md`.
- Spec output: `.claude/prompts/{feature}-spec.md`.
- Handoff payloads: `.claude/workflow-state/{feature}-handoff.json`.
- Pipeline metrics: `.claude/workflow-state/pipeline-metrics.jsonl`.
- Verdict checkpoint: `.claude/workflow-state/review-completions.jsonl`.

## Codebase Topology

- Top-level: `CLAUDE.md`, `README.md`, `install.sh`, `.claude/`, `.mcp.json`, `caveman/` (vendored upstream skill).
- Native memory: `~/.claude/projects/<slug>/memory/` (auto-memory) vs `.claude/agent-memory/<name>/` (subagent memory).
- Agent isolation: `code-reviewer` runs with `isolation: worktree`; others run in-tree.
- Hook layers: 16 event types in `settings.json`; security hooks unconditional, others use `if:` predicates from v2.1.85.
