# MCP Tools

<!-- SYNC: Core MCP patterns shared with planner-rules/mcp-tools.md. Update both on change. -->

| Tool | Use When | Fallback |
|------|----------|----------|
| Sequential Thinking | 3+ alternatives OR 4+ interacting parts | Manual analysis (bullet points) |
| Context7 (resolve-library-id, query-docs) | External library API unclear | WebSearch → memory → general knowledge |
| Monitor | Streaming stdout line-by-line from a background process (v2.1.98+) | Single BashOutput after completion (for wait-until-done) |

**Pattern:** try-catch at use time. All MCPs are NON_CRITICAL — warn and continue.

**Sequential Thinking criteria:** Use for complex trade-offs with 3+ approaches. Skip for obvious/simple decisions.

**Context7 limit:** Max 3 calls per question.

**Context7 workflow:**
```yaml
# Step 1: Find library
mcp__context7__resolve-library-id:
  libraryName: "{library-name}"
  query: "how to setup {library}"

# Step 2: Get documentation
mcp__context7__query-docs:
  libraryId: "/{org}/{library}"
  query: "{specific usage question}"
```
Required when: new external dependency, unfamiliar library API, integration tests with external services.
Not needed when: standard library, already familiar API.
Warning: If used external library WITHOUT Context7 — explain why.

**Monitor workflow (v2.1.98):**

Two patterns — pick based on whether you need streaming progress or just completion.

**Pattern A — Wait-until-done (most common: test suites, builds):**

```yaml
# Start command in background — harness auto-notifies on process exit
Bash:
  command: "make test 2>&1 | tee /tmp/test-output.log"
  run_in_background: true

# (no Monitor, no polling — wait for the auto-notification from Bash)

# After completion notification, read result ONCE
Bash:
  command: "tail -20 /tmp/test-output.log"
```

Monitor is NOT used here. The harness already notifies on process exit for any
Bash with `run_in_background: true`.

**Pattern B — Streaming progress (watch tests tick through, debug flaky suites):**

```yaml
Bash:
  command: "make test 2>&1 | tee /tmp/test-output.log"
  run_in_background: true

# Monitor emits one notification per stdout line from tail -f
Monitor:
  command: "tail -f /tmp/test-output.log"
```

Use Pattern B when the agent needs to react to intermediate output (e.g. first FAIL → stop & diagnose).

Required when: Pattern A for VERIFY (`make test`, `go test -race`); Pattern B only when streaming visibility matters.
Not needed when: command completes in < 5 s — use blocking Bash.
Warning: Do NOT poll with repeated `BashOutput` while a background Bash runs — a single BashOutput call AFTER completion is fine, but N polls in a loop evict the prompt cache on every call.
