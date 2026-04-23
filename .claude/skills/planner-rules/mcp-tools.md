# MCP Tools

<!-- SYNC: Core MCP patterns shared with coder-rules/mcp-tools.md. Update both on change. -->

| Tool | Use When | Fallback |
|------|----------|----------|
| Sequential Thinking | 3+ alternatives OR 4+ interacting parts | Manual analysis (bullet points) |
| Context7 (resolve-library-id, query-docs) | External library API unclear | WebSearch → memory → general knowledge |
| Monitor | Streaming stdout line-by-line from a background process (v2.1.98+) | Single BashOutput after completion (for wait-until-done) |

**Pattern:** try-catch at use time. All MCPs are NON_CRITICAL — warn and continue.

**Sequential Thinking criteria:** Use for complex trade-offs with 3+ approaches. Skip for obvious/simple decisions.

**Context7 limit:** Max 3 calls per question.

**Monitor workflow (v2.1.98):**

```yaml
# Planner's typical background work — code-researcher via Agent tool self-notifies on completion.
# Monitor is NOT used for Agent/Task tool invocations.
Agent:
  subagent_type: "code-researcher"
  model: "haiku"
  run_in_background: true
  prompt: "..."
# (no Monitor — harness auto-notifies on Agent completion)

# Rare: Bash-based background analysis script. Two patterns apply:
#   Pattern A — wait-until-done: rely on Bash(run_in_background: true) auto-notification, read log once.
#   Pattern B — streaming progress: Monitor(command: "tail -f /tmp/log") emits one notification per output line.
# See coder-rules/mcp-tools.md for the full Pattern A / B example.
```

Required when: streaming progress from a Bash-based background command is needed (Pattern B case only).
Not needed when: Agent/Task tool invocations — those self-notify.
Warning: Do not wrap Agent/Task background invocations in Monitor — duplicate notification is a bug signal, not progress.
