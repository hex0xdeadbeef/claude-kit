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

## Hook stderr Convention

All hook scripts MUST use this format for stderr messages:

```
[<script-basename>] LABEL: <message>
```

**Labels:**

| Label | Meaning | Typical exit |
|-------|---------|-------------|
| `INFO` | Informational / status (script succeeds) | 0 |
| `WARN` | Non-blocking issue (degraded behavior expected) | 0 |
| `ERROR` | Hook exits with failure (non-critical hook) | non-zero |
| `FATAL` | Blocks Claude action (security / critical hook) | non-zero |
| `SKIP` | Condition not met — action intentionally skipped | 0 |
| `PASS` | Validation succeeded | 0 |
| `FAIL` | Validation failed | non-zero |
| `BLOCKING` | Hard-block mode active | non-zero |

**FATAL vs ERROR rule:** Use `FATAL` for PreToolUse hooks whose primary role is to block Claude actions (security-critical path — `block-dangerous-commands.sh`, `protect-files.sh`). Use `ERROR` for all other hooks when they themselves fail.

**Rationale:** Claude Code v2.1.98 surfaces the first line of stderr in the agent
transcript — structured format makes label machine-parseable at a glance.

**Gold standard:** `validate-handoff.sh` (reference implementation — uses WARN, ERROR,
SKIP, PASS, FAIL, BLOCKING). INFO and FATAL are also valid labels used by other scripts.

**Scope:** applies to shell `echo ... >&2` lines and Python startup-error
`print(..., file=sys.stderr)` calls at script entry-point. Internal processing logs
in Python bodies (deep loop diagnostics) and stderr redirected to log files via
`2>>log` are out of scope — they serve internal-state tracking, not transcript output.
