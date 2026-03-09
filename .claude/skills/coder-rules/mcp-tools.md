# MCP Tools

| Tool | Use When | Fallback |
|------|----------|----------|
| Memory (search_nodes, create_entities, create_relations) | Search before planning; save non-trivial decisions after | Skip — memory is enhancement |
| Sequential Thinking | 3+ alternatives OR 4+ interacting parts | Manual analysis (bullet points) |
| Context7 (resolve-library-id, query-docs) | External library API unclear | WebSearch → memory → general knowledge |
| PostgreSQL (list_tables, describe_table, query) | Schema unclear, no migrations | Migration files → SQL queries → entity structs |

**Pattern:** try-catch at use time. All MCPs are NON_CRITICAL — warn and continue.

**Memory sequence:** search_nodes → 0 results: create_entities + create_relations | 1 result: add_observations | 2+ results: ask user.

**Sequential Thinking criteria:** Use for complex trade-offs with 3+ approaches. Skip for obvious/simple decisions.

**Context7 limit:** Max 3 calls per question. Save patterns to memory for reuse.

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

**Memory health check (onboarding / first run):**
Run `mcp__memory__search_nodes — query: 'health_check'`.
- If responds → Memory available, proceed normally.
- If fails → warn user: "Memory MCP not configured. Copy template: `cp .claude/agents/meta-agent/templates/onboarding/mcp.json ~/.claude/mcp.json` and replace `${USERNAME}`, `${DB_USER}`, `${DB_PASSWORD}`, `${DB_NAME}` placeholders. Then restart Claude."
- Do NOT block workflow — Memory is NON_CRITICAL.

**Memory query patterns:**
- By feature: `'{feature name} {domain}'` — e.g. `'auth middleware'`
- By file/package: `'{package name} {layer}'` — e.g. `'user repository'`
- By problem: `'{error type} lesson'` — e.g. `'race condition lesson'`
- By decision: `'{pattern name} architecture decision'` — e.g. `'caching strategy architecture decision'`
- Tips: use 2-4 keywords, include domain/package for precision, add `lesson` or `decision` suffix for entity type filtering.

**Memory boundary (MCP Memory vs Auto-memory):**
- MCP Memory: architectural decisions, lessons learned, pipeline metrics (structured, cross-project, explicit save/search)
- Auto-memory: build commands, debugging insights, preferences (free-form, per-project, auto-saved)
- Rule: Do NOT duplicate. If saving architectural decision → use MCP Memory. If noting "this build flag is needed" → let auto-memory handle it.
