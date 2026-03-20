# Autonomy

**Modes:**
- INTERACTIVE (default): Ask at checkpoints
- AUTONOMOUS (--auto): Execute all phases without asking
- RESUME: Continue from last checkpoint (session interrupted)

**Stop conditions:**

| Condition | Action |
|-----------|--------|
| FATAL_ERROR (plan/file not found, critical dep missing) | Stop immediately |
| USER_INTERVENTION (scope unclear, multiple approaches, user says stop) | Stop, wait for user |
| TOOL_UNAVAILABLE (MCP unavailable) | Warn, adapt, continue |
| FAILURE_THRESHOLD (tests/lint fail 3x) | Stop, request manual fix |
| EXPLORATION_THRESHOLD (file reads exceed budget for complexity) | Summarize findings so far, transition to next sub-phase (DESIGN/IMPLEMENT) |

**Continue conditions (autonomous mode):**

| Condition | Action |
|-----------|--------|
| Phase completed | → next phase |
| Auto-fixable (lint fail → FMT) | Fix → retry |
| Non-critical tool unavailable | Warn → continue |
| Exploration within budget | Continue research |
