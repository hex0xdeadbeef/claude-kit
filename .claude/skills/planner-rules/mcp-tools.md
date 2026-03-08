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

**Memory entity templates:**

Architectural decision:
```yaml
name: "{Feature Name}"
entityType: "architectural_decision"
observations:
  - "Decision: {what was chosen}"
  - "Reason: {why}"
  - "Alternatives: {what was rejected and why}"
  - "Patterns: {patterns used}"
  - "Files: {key files}"
```

Lessons learned:
```yaml
name: "{Feature Name}"
entityType: "lessons_learned"
observations:
  - "PROBLEM: {problem encountered}"
  - "SOLUTION: {how resolved}"
  - "CONTEXT: {when applicable}"
  - "COMPLEXITY: estimated={X} actual={Y}"
  - "ITERATIONS: plan_review={N} code_review={N}"
  - "CREATED: {ISO date}"
```

Relations: `mcp__memory__create_relations` — `{"from": "New Feature", "to": "Existing Decision", "relationType": "extends"}`
