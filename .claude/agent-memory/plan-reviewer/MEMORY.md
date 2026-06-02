# plan-reviewer Memory

Persistent project-shared memory for the `plan-reviewer` agent.
Native loader injects the first 200 lines / 25 KB at SubagentStart.

## Project Layer Structure

This kit is config-as-code (Markdown + Shell + YAML + JSON). Logical "layers"
correspond to artifact roles:

- Commands (`.claude/commands/`) — orchestrator-context entry points (workflow, planner, coder, designer).
- Agents (`.claude/agents/`) — clean-context review/research workers (plan-reviewer, code-reviewer, code-researcher, verdict-recovery).
- Skills (`.claude/skills/`) — phase-specific protocols loaded on demand.
- Rules (`.claude/rules/`) — path-scoped instructions auto-loaded by Claude Code.
- Hooks/Scripts (`.claude/scripts/`) — deterministic event-fired automation.
- Schemas (`.claude/schemas/`) — JSON Schema contracts for handoff/verdict envelopes.

## Review Checklist Priorities

1. Phase-handoff contract preservation (planner→plan-review→coder→code-review→completion) — byte-stable.
2. Test corpus integrity — every change must keep `.claude/scripts/tests/test-*.sh` green.
3. Project portability — no `/Users/<name>/...` hardcodes; no writes under `~/.claude/`.
4. Caveman boundary preservation (VERDICT lines, JSON sentinels, H2 plan/spec headers).
5. CLAUDE.md size budget ≤200 lines; per-section concision.

## Common Section Gaps

- Plan missing `## Architecture Decision` block when complexity ≥ M.
- Plan missing per-Part verification snippets (test command or grep predicate).
- Spec missing OUT scope items with explicit reasons.
- Plan missing diff-vs-prior-iteration block on iter 2+ (IMP-04 contract).

## Design Critique (Phase 3.5)

- L/XL specs may carry a `design_critique` block (findings + dispositions: addressed | accepted-risk | out-of-scope); unresolved HIGH findings appear in the planner's `areas_needing_attention`. These are design-stage observations, not plan defects — do not auto-escalate them.
