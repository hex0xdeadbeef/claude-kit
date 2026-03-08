# Autonomy

**Modes:**
- INTERACTIVE (default): Ask at checkpoints
- AUTONOMOUS (--auto): Execute all phases without asking
- RESUME: Continue from last checkpoint (session interrupted)
- MINIMAL (--minimal): Minimal research, only critical checks

**Stop conditions:**

| Condition | Action |
|-----------|--------|
| FATAL_ERROR (plan/file not found, critical dep missing) | Stop immediately |
| USER_INTERVENTION (scope unclear, multiple approaches, user says stop) | Stop, wait for user |
| TOOL_UNAVAILABLE (MCP unavailable) | Warn, adapt, continue |
| FAILURE_THRESHOLD (tests/lint fail 3x) | Stop, request manual fix |

**Continue conditions (autonomous mode):**

| Condition | Action |
|-----------|--------|
| Phase completed | → next phase |
| Auto-fixable (lint fail → FMT) | Fix → retry |
| Non-critical tool unavailable | Warn → continue |
