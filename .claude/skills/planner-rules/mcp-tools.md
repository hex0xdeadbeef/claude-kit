# MCP Tools

<!-- SYNC: Core MCP patterns shared with coder-rules/mcp-tools.md. Update both on change. -->

| Tool | Use When | Fallback |
|------|----------|----------|
| Sequential Thinking | 3+ alternatives OR 4+ interacting parts | Manual analysis (bullet points) |
| Context7 (resolve-library-id, query-docs) | External library API unclear | WebSearch → memory → general knowledge |
| PostgreSQL (list_tables, describe_table, query) | Schema unclear, no migrations | Migration files → SQL queries → entity structs |

**Pattern:** try-catch at use time. All MCPs are NON_CRITICAL — warn and continue.

**Sequential Thinking criteria:** Use for complex trade-offs with 3+ approaches. Skip for obvious/simple decisions.

**Context7 limit:** Max 3 calls per question.

**PostgreSQL safety:** Read-only queries only (SELECT). No INSERT/UPDATE/DELETE.
