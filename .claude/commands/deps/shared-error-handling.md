# Shared: Error Handling

Common error scenarios and recovery strategies for Claude Code commands.

---

## MCP Tool Errors

### Memory MCP Unavailable

**Symptoms:**
- `mcp__memory__search_nodes` fails
- `mcp__memory__create_entities` fails

**Recovery:**
```yaml
severity: NON_CRITICAL
action:
  - "Warn user: 'Memory MCP unavailable, proceeding without search'"
  - "Continue without memory check"
  - "Skip saving to memory at completion"
note: "Memory is enhancement, not requirement"
```

**Prevention:** Check MCP availability at START with try-catch

---

### Sequential Thinking MCP Unavailable

**Symptoms:**
- `mcp__sequential-thinking__sequentialthinking` fails
- MCP connection error

**Recovery:**
```yaml
severity: NON_CRITICAL (can degrade gracefully)
action:
  - "Warn user: 'Sequential Thinking unavailable, using manual analysis'"
  - "Perform alternatives analysis manually (simpler, less structured)"
  - "Continue with degraded analysis"
note: "Sequential Thinking improves quality but is not mandatory"
```

**When to use Sequential Thinking:**
- 3+ architectural alternatives
- Complex trade-off analysis
- Multi-step reasoning required

**When to skip:**
- Only 1 clear approach
- Simple decision
- MCP unavailable

---

### Context7 MCP Unavailable

**Symptoms:**
- `mcp__plugin_context7_context7__resolve-library-id` fails
- `mcp__plugin_context7_context7__query-docs` fails

**Recovery:**
```yaml
severity: NON_CRITICAL
action:
  - "Warn user: 'Context7 unavailable, using fallback'"
  - "Fallback 1: Web search for library documentation"
  - "Fallback 2: Search project memory for library patterns"
  - "Fallback 3: Use general knowledge (if library is common)"
note: "Context7 is nice-to-have for external libraries"
```

**Example:**
```
# Context7 unavailable
→ Fallback to: WebSearch "{library} usage pattern {year}"
→ Or: search_nodes "{library} integration patterns"
```

---

### PostgreSQL MCP Unavailable

**Symptoms:**
- `mcp__postgres__list_tables` fails
- `mcp__postgres__describe_table` fails
- `mcp__postgres__query` fails

**Recovery:**
```yaml
severity: NON_CRITICAL (alternative exists)
action:
  - "Warn user: 'PostgreSQL MCP unavailable, using migration files'"
  - "Read migrations: ls migrations/*.sql"
  - "Read SQL query files"
  - "Infer schema from existing code"
note: "PostgreSQL MCP is convenience, not requirement"
```

**When PostgreSQL MCP is critical:**
- Schema reverse-engineering task
- Data analysis task
- No migrations available

**When alternatives work:**
- Schema documented in migrations
- SQL query files show schema usage
- Entity structs reflect schema

---

## File/Resource Errors

### Plan Not Found

**Symptoms:**
- `/coder` started but `.claude/prompts/{feature}.md` doesn't exist
- User forgot to run `/planner` first

**Recovery:**
```yaml
severity: FATAL
action:
  - "ERROR: Plan not found at .claude/prompts/{feature}.md"
  - "Suggest: Run /planner first to create plan"
  - "EXIT immediately (cannot code without plan)"
note: "Plan is mandatory for /coder"
```

---

### Plan Not Approved

**Symptoms:**
- `/coder` started but plan was REJECTED or NEEDS_CHANGES

**Recovery:**
```yaml
severity: FATAL
action:
  - "ERROR: Plan not approved (status: {status})"
  - "Suggest: Run /plan-review to approve plan first"
  - "EXIT immediately (cannot implement unapproved plan)"
note: "Approval gate prevents implementing rejected designs"
```

---

### Template Missing

**Symptoms:**
- `templates/plan-template.md` not found
- Template file corrupted

**Recovery:**
```yaml
severity: NON_CRITICAL
action:
  - "Warn: Template not found, using minimal format"
  - "Use built-in minimal template (Context, Parts, Acceptance)"
  - "Continue with degraded output quality"
note: "Template improves structure but is not mandatory"
```

---

### Git Repository Issues

**Symptoms:**
- `git status` fails
- Not in git repository
- Detached HEAD state

**Recovery:**
```yaml
severity: WARNING (depends on command)
action:
  - "/planner, /coder: Can proceed (git not required for planning/coding)"
  - "/workflow: Warn but continue (may affect commit phase)"
  - "Warn user: 'Not in git repository, commit phase will be skipped'"
```

---

## Validation Errors

### Tests Fail 3x Consecutively

**Symptoms:**
- `make test` fails
- Auto-fix attempted, still fails
- 3 retries exhausted

**Recovery:**
```yaml
severity: STOP_AND_WAIT
action:
  - "ERROR: Tests failed 3x consecutively"
  - "Last error: {show error}"
  - "Auto-fix exhausted, manual intervention required"
  - "STOP and wait for user fix"
note: "Prevents infinite retry loops"
```

---

### Lint Fails 3x Consecutively

**Symptoms:**
- `make lint` fails
- `make fmt` applied, still fails
- Issues not auto-fixable

**Recovery:**
```yaml
severity: STOP_AND_WAIT
action:
  - "WARN: Lint failed 3x consecutively"
  - "Issues: {list unfixable issues}"
  - "Options:"
  - "  1. Fix manually"
  - "  2. Add nolint comments (if justified)"
  - "  3. Update linter config (if false positive)"
  - "STOP and wait for user decision"
```

---

### Import Matrix Violation

**Symptoms:**
- Code imports violate Clean Architecture rules
- Example: `domain/` imports `repository/`

**Recovery:**
```yaml
severity: STOP_AND_FIX
action:
  - "ERROR: Import matrix violation detected"
  - "Violation: {show which import violates which rule}"
  - "Fix: Refactor imports to respect architecture boundaries"
  - "STOP until fixed (architecture violations are critical)"
note: "Cannot proceed with architecture violations"
```

---

## Beads Integration Errors

### Beads Unavailable

**Symptoms:**
- `bd` command not found
- `.beads/` directory missing

**Recovery:**
```yaml
severity: NON_CRITICAL
action:
  - "Warn: Beads unavailable, skipping task tracking"
  - "Continue without beads integration"
  - "Skip beads-related phases (bd show, bd update, bd close)"
note: "Beads is optional project management, not core functionality"
```

---

### Beads Sync Failed

**Symptoms:**
- `bd sync` returns error
- Network issues, remote unavailable

**Recovery:**
```yaml
severity: WARNING
action:
  - "Warn: Beads sync failed, continuing with local state"
  - "Remind user: Run 'bd sync --from-main' manually later"
  - "Continue workflow (don't block on sync failure)"
note: "Sync can be deferred, not blocking"
```

---

## User Communication Errors

### Scope Unclear After Clarification

**Symptoms:**
- User provides vague requirements
- 2+ rounds of clarification, still unclear

**Recovery:**
```yaml
severity: STOP_AND_WAIT
action:
  - "Cannot proceed: Scope still unclear after clarification"
  - "Suggest: Provide specific requirements (examples, acceptance criteria)"
  - "WAIT for clear scope definition"
note: "Better to wait than implement wrong solution"
```

---

### User Doesn't Respond

**Symptoms:**
- Asked question with AskUserQuestion
- No response from user
- Blocking decision needed

**Recovery:**
```yaml
severity: STOP_AND_WAIT
action:
  - "WAIT for user response"
  - "Do NOT proceed with assumptions"
  - "Do NOT make blocking decisions without user input"
note: "User approval required for blocking decisions"
```

---

## Quick Reference

| Error | Severity | Action |
|-------|----------|--------|
| **Memory MCP unavailable** | NON_CRITICAL | Warn, proceed without |
| **Sequential Thinking unavailable** | NON_CRITICAL | Warn, use manual analysis |
| **Context7 unavailable** | NON_CRITICAL | Fallback: WebSearch or memory |
| **PostgreSQL MCP unavailable** | NON_CRITICAL | Use migration files |
| **Plan not found** | FATAL | EXIT immediately |
| **Plan not approved** | FATAL | EXIT immediately |
| **Template missing** | NON_CRITICAL | Use minimal format |
| **Tests fail 3x** | STOP_AND_WAIT | Request manual fix |
| **Lint fails 3x** | STOP_AND_WAIT | Request manual decision |
| **Import violation** | STOP_AND_FIX | Fix before proceeding |
| **Beads unavailable** | NON_CRITICAL | Skip beads phases |
| **Scope unclear** | STOP_AND_WAIT | Wait for clear requirements |

---

## Usage in Commands

**In command ERROR HANDLING section:**
```yaml
## ERROR HANDLING

SEE: `deps/shared-error-handling.md` for common scenarios

Command-specific errors:
  - situation: {specific to this command}
    action: "..."
```

---

## SEE ALSO

- `shared-autonomy.md` — Autonomy stop conditions
- `shared-mcp.md` — MCP tool usage patterns
- Individual commands for command-specific error handling
