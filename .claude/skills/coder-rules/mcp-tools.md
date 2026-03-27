# MCP Tools

<!-- SYNC: Core MCP patterns shared with planner-rules/mcp-tools.md. Update both on change. -->

| Tool | Use When | Fallback |
|------|----------|----------|
| Sequential Thinking | 3+ alternatives OR 4+ interacting parts | Manual analysis (bullet points) |
| Context7 (resolve-library-id, query-docs) | External library API unclear | WebSearch → memory → general knowledge |
| PostgreSQL (list_tables, describe_table, query) | Schema unclear, no migrations | Migration files → SQL queries → entity structs |

**Pattern:** try-catch at use time. All MCPs are NON_CRITICAL — warn and continue.

**Sequential Thinking criteria:** Use for complex trade-offs with 3+ approaches. Skip for obvious/simple decisions.

**Context7 limit:** Max 3 calls per question.

**Context7 workflow:**
```yaml
# Step 1: Find library
mcp__plugin_context7_context7__resolve-library-id:
  libraryName: "{library-name}"
  query: "how to setup {library}"

# Step 2: Get documentation
mcp__plugin_context7_context7__query-docs:
  libraryId: "/{org}/{library}"
  query: "{specific usage question}"
```
Required when: new external dependency, unfamiliar library API, integration tests with external services.
Not needed when: standard library, already familiar API.
Warning: If used external library WITHOUT Context7 — explain why.

**PostgreSQL safety:** Read-only queries only (SELECT). No INSERT/UPDATE/DELETE.
