# Shared: Autonomy Patterns

Reusable autonomy patterns for Claude Code commands.

---

## Common Autonomy Modes

### INTERACTIVE (default)
- **Trigger:** Normal invocation
- **Behavior:** Ask for confirmation at checkpoints
- **When:** User needs control over workflow

### AUTONOMOUS
- **Trigger:** `--auto` flag or "без подтверждений"
- **Behavior:** Execute all phases automatically without asking
- **When:** Trusted workflow, batch processing

### RESUME
- **Trigger:** Existing progress detected (e.g., `.claude/prompts/*.md` exists)
- **Behavior:** Continue from last checkpoint
- **When:** Session interrupted and restarted

### MINIMAL
- **Trigger:** `--minimal` flag
- **Behavior:** Minimal research, only critical checks
- **When:** Quick tasks, familiar codebase

---

## Common Stop Conditions

**FATAL_ERROR** — Stop immediately
- Plan/file not found
- Critical dependency missing
- Unrecoverable validation failure

**USER_INTERVENTION** — Stop and wait for user
- Scope unclear or ambiguous
- Multiple valid approaches exist
- User explicitly says "stop"
- Conflict with existing architecture

**TOOL_UNAVAILABLE** — Warn and adapt
- MCP tool critically unavailable → proceed with limitations
- Optional tool unavailable → skip that feature
- Context7 unavailable → use web search or memory

**FAILURE_THRESHOLD** — Stop after N attempts
- Tests fail 3x in a row → request manual fix
- Lint fails 3x in a row → report unfixable issues
- Operation retries exhausted → escalate

---

## Common Continue Conditions (autonomous mode)

**PHASE_COMPLETED** — Proceed automatically
- Phase completed successfully → next phase
- Part completed → next part
- Step verified → next step

**AUTO_FIXABLE** — Fix and retry
- `make lint` fails → `make fmt` + retry
- Import order wrong → `goimports` + retry
- Minor validation issue → auto-correct + retry

**PARTIAL_SUCCESS** — Acknowledge and proceed
- Non-critical tool unavailable → proceed with limitations
- Optional check failed → warn and continue
- Minor issues detected → log and proceed

---

## Usage in Commands

**In command YAML:**
```yaml
autonomy:
  modes:
    - name: INTERACTIVE  # or AUTONOMOUS, RESUME, MINIMAL
      default: true
      trigger: "Normal invocation"
      behavior: "Ask at checkpoints"

  stop_conditions:
    - condition: {Specific to command}
      action: "Stop/Wait/Warn"

  continue_conditions:  # autonomous mode only
    - condition: {Specific to command}
      action: "Proceed/Retry/Fix"
```

**Reference from command:**
```
## AUTONOMY RULE

SEE: `deps/shared-autonomy.md` for common patterns

Command-specific autonomy:
{specific modes, stop conditions, continue conditions for this command}
```

---

## Examples

### Example 1: Research Command (planner)

```yaml
# Reference shared autonomy, add specific
SEE: deps/shared-autonomy.md

Specific to planner:
  stop_conditions:
    - condition: Scope неясен после 2x clarification
      action: "Ждать scope definition от пользователя"

  continue_conditions:
    - condition: Minor alternatives identified
      action: "Document and proceed with recommended approach"
```

### Example 2: Implementation Command (coder)

```yaml
# Reference shared autonomy, add specific
SEE: deps/shared-autonomy.md

Specific to coder:
  stop_conditions:
    - condition: Plan not found or not approved
      action: "ERROR → exit (cannot code without plan)"

    - condition: Tests fail 3x подряд
      action: "Stop, request user help (auto-fix exhausted)"

  continue_conditions:
    - condition: Part completed
      action: "Verify → next Part"
```

### Example 3: Review Command (code-review)

```yaml
# Reference shared autonomy, add specific
SEE: deps/shared-autonomy.md

Specific to code-review:
  stop_conditions:
    - condition: No git changes detected
      action: "ERROR → nothing to review"

  continue_conditions:
    - condition: Minor issues found
      action: "Log issues, continue review (non-blocking)"
```

---

## Anti-Patterns

❌ **DON'T duplicate entire autonomy section in each command**
```yaml
# BAD: Full autonomy definition duplicated in every command
autonomy:
  modes:
    - name: INTERACTIVE
      default: true
      trigger: "Normal invocation"
      behavior: "..."
    - name: AUTONOMOUS
      trigger: "--auto"
      behavior: "..."
  stop_conditions: [... 10 common conditions ...]
  continue_conditions: [... 10 common conditions ...]
```

✅ **DO reference shared patterns, add command-specific**
```yaml
# GOOD: Reference shared, only document command-specific
SEE: deps/shared-autonomy.md (common modes, conditions)

Command-specific:
  stop_conditions:
    - condition: {unique to this command}
      action: "..."
```

---

## SEE ALSO

- `shared-error-handling.md` — Common error scenarios
- `shared-mcp.md` — MCP tool availability handling
- Individual commands for command-specific autonomy rules
