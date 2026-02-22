# Shared: MCP Tool Usage Patterns

Common patterns for using MCP (Model Context Protocol) tools in Claude Code commands.

---

## Available MCP Tools

| MCP Server | Tools | Purpose |
|------------|-------|---------|
| **Memory** | create_entities, search_nodes, add_observations, create_relations | Long-term project memory |
| **Sequential Thinking** | sequentialthinking | Multi-step reasoning and analysis |
| **Context7** | resolve-library-id, query-docs | Library documentation lookup |
| **PostgreSQL** | list_tables, describe_table, query | Database schema exploration |

---

## MCP: Memory

### When to Use

**Use memory for:**
- Architectural decisions (after `/planner`)
- Lessons learned (after `/workflow`)
- Non-trivial troubleshooting solutions
- Integration patterns with external systems

**DON'T use memory for:**
- Trivial changes (typos, formatting)
- Standard CRUD operations
- Already known patterns
- Temporary solutions

### Mandatory Sequence

```yaml
ALWAYS follow this sequence:
1. search_nodes({ query: "keywords" })
2. IF 0 results → create_entities
   IF 1 result → add_observations
   IF 2+ results → AskUserQuestion

3. create_relations (MANDATORY after create_entities)
```

**Why mandatory:** Prevents duplicate entities, maintains knowledge graph integrity.

### Integration Points

**In /planner:**
```yaml
STARTUP:
  - search_nodes (find similar decisions)
  - If found → inform current planning

PHASE 5 (MANDATORY):
  - create_entities (architectural decision)
  - create_relations (link to related decisions)
```

**In /workflow:**
```yaml
ЗАВЕРШЕНИЕ (optional):
  - IF non-trivial insights:
    - create_entities (lessons_learned)
    - create_relations (link to problems solved)
  - ELSE:
    - Skip (don't clutter memory with trivial)
```

**In /coder:**
```yaml
VERIFY (if troubleshooting):
  - create_entities (troubleshooting_solution)
  - create_relations (link to problem)
```

### Error Handling

```yaml
Memory MCP unavailable:
  severity: NON_CRITICAL
  action:
    - Warn: "Memory unavailable, proceeding without search"
    - Continue without memory check
    - Skip saving at completion
```

SEE: `deps/shared-error-handling.md#memory-mcp-unavailable`

---

## MCP: Sequential Thinking

### When to Use

Use Sequential Thinking when:
- **3+ architectural alternatives** exist (need structured comparison)
- **Complex trade-off analysis** required (multi-dimensional decisions)
- **Multi-step reasoning** needed (chain of dependent decisions)
- **Hypothesis generation + verification** pattern applies

**DON'T use when:**
- Only 1 clear approach exists (overkill)
- Simple decision (adds overhead)
- MCP unavailable (degrade gracefully)

### Usage Pattern

```yaml
Decision point → Use Sequential Thinking:

1. Problem: Multiple ways to implement feature X
2. Call mcp__sequential-thinking__sequentialthinking:
     thought: "Identify alternatives for feature X"
     totalThoughts: 10 (estimate)

3. Iterate through thoughts:
     - Generate hypotheses
     - Evaluate trade-offs
     - Verify against requirements
     - Reach conclusion

4. Output: Structured decision with rationale
```

### Example Scenarios

**Scenario 1: Plugin Architecture**
```yaml
Problem: How to implement plugin system?
Alternatives:
  - Runtime registration (reflection-based)
  - Compile-time registration (init() pattern)
  - Config-driven (yaml-based)

Use Sequential Thinking:
  - Thought 1-3: Identify alternatives
  - Thought 4-7: Evaluate (safety, performance, maintainability)
  - Thought 8-9: Compare trade-offs
  - Thought 10: Recommend approach with rationale
```

**Scenario 2: Concurrency Strategy**
```yaml
Problem: How to handle concurrent operations?
Alternatives:
  - Worker pool
  - Semaphore
  - Channel-based pipeline

Use Sequential Thinking:
  - Thought 1-2: Understand requirements (throughput, ordering, backpressure)
  - Thought 3-5: Evaluate alternatives against requirements
  - Thought 6-8: Analyze edge cases (shutdown, failure, scaling)
  - Thought 9: Recommend approach
```

### Integration Points

**In /planner (PHASE 2: EXPLORE):**
```yaml
IF multiple alternatives AND complex trade-offs:
  - Use Sequential Thinking for analysis
  - Document decision in plan
  - Save to memory (architectural_decision)

ELSE:
  - Simple analysis (bullet points)
  - Document in plan
```

### Error Handling

```yaml
Sequential Thinking unavailable:
  severity: NON_CRITICAL
  action:
    - Warn: "Sequential Thinking unavailable, using manual analysis"
    - Perform alternatives analysis (simpler, less structured)
    - Document in plan (less detailed rationale)
```

SEE: `deps/shared-error-handling.md#sequential-thinking-mcp-unavailable`

---

## MCP: Context7

### When to Use

Use Context7 when:
- **External library** integration (not standard library)
- **Unfamiliar API** usage patterns
- **Recent library changes** (post knowledge cutoff)

**DON'T use when:**
- Standard library (Go stdlib, net/http)
- Library already in project memory
- Context7 unavailable (use fallback)

### Usage Pattern

```yaml
1. resolve-library-id:
     libraryName: "{library-name}"
     query: "{library usage patterns}"
   → Returns: library ID (e.g., "/{org}/{library}")

2. query-docs:
     libraryId: "/{org}/{library}"
     query: "{specific API or pattern question}"
   → Returns: Documentation snippets + examples
```

**Limit:** Call each tool max 3 times per question (avoid excessive calls)

### Integration Points

**In /planner (PHASE 1: RESEARCH):**
```yaml
IF external library research needed:
  - resolve-library-id (find correct library version)
  - query-docs (get usage patterns)
  - Document in plan (reference sections)
```

**In /coder (during implementation):**
```yaml
IF library API unclear:
  - query-docs (specific API usage)
  - Apply pattern from documentation
```

### Error Handling

```yaml
Context7 unavailable:
  severity: NON_CRITICAL
  action:
    - Warn: "Context7 unavailable, using fallback"
    - Fallback 1: WebSearch for library docs
    - Fallback 2: Search project memory (search_nodes)
    - Fallback 3: Use general knowledge (if common library)
```

SEE: `deps/shared-error-handling.md#context7-mcp-unavailable`

---

## MCP: PostgreSQL

### When to Use

Use PostgreSQL MCP when:
- **Schema exploration** needed (new to project)
- **Table structure** unclear (no migrations available)
- **Data analysis** required (understanding existing data)

**DON'T use when:**
- Schema documented in migrations (use `ls migrations/*.sql`)
- SQL query files available (check project's query directory)
- Entity structs reflect schema (use `grep "type.*struct"`)

### Usage Pattern

```yaml
1. list_tables:
     sql: "SELECT tablename FROM pg_tables WHERE schemaname = 'public'"
   → Returns: List of tables

2. describe_table:
     sql: "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = '{table_name}'"
   → Returns: Table schema

3. query (read-only):
     sql: "SELECT DISTINCT status FROM {table_name} LIMIT 10"
   → Returns: Sample data
```

**Safety:** Only read-only queries (SELECT). NO INSERT/UPDATE/DELETE.

### Integration Points

**In /planner (PHASE 1: RESEARCH):**
```yaml
IF database schema unclear:
  - list_tables (find relevant tables)
  - describe_table (understand structure)
  - query (sample data for understanding)
  - Document in plan (schema details)
```

**In /db-explorer command:**
```yaml
All phases use PostgreSQL MCP:
  - TABLES phase: list_tables
  - SCHEMA phase: describe_table
  - RELATIONSHIPS phase: query for foreign keys
  - SAMPLE_DATA phase: query for examples
```

### Error Handling

```yaml
PostgreSQL MCP unavailable:
  severity: NON_CRITICAL (alternative exists)
  action:
    - Warn: "PostgreSQL MCP unavailable, using migration files"
    - Alternative 1: Read migration files
    - Alternative 2: Read SQL query files
    - Alternative 3: grep entity structs
```

SEE: `deps/shared-error-handling.md#postgresql-mcp-unavailable`

---

## MCP Availability Check Pattern

**At command START:**
```yaml
# Don't pre-check all MCPs (wastes time)
# Use try-catch pattern when calling MCP

try:
  result = mcp__memory__search_nodes(...)
except MCPError:
  # Handle unavailability (see error handling)
  warn_and_continue()
```

**DON'T:**
```yaml
# BAD: Pre-check all MCPs at startup
if memory_available() and seqthinking_available() and ...:
  proceed()
```

**Reason:** Most MCPs are available most of the time. Check on use, not preemptively.

---

## Usage in Commands

**In command MCP TOOLS section:**
```yaml
## MCP TOOLS

SEE: `deps/shared-mcp.md` for patterns

Command-specific MCP usage:
  - tool: {MCP tool name}
    when: "{specific use case in this command}"
    integration_point: "{which phase}"
```

**Example (planner):**
```yaml
## MCP TOOLS

SEE: `deps/shared-mcp.md`

/planner specific:
  - Memory: STARTUP (search), PHASE 5 (save decision)
  - Sequential Thinking: PHASE 2 (if 3+ alternatives)
  - Context7: PHASE 1 (external library research)
  - PostgreSQL: PHASE 1 (schema exploration if needed)
```

---

## Anti-Patterns

❌ **DON'T fail hard on MCP unavailability**
```yaml
# BAD
if not memory_available():
  raise Error("Memory MCP required!")
```

✅ **DO degrade gracefully**
```yaml
# GOOD
if not memory_available():
  warn("Memory unavailable, proceeding without search")
  # Continue with core workflow
```

---

❌ **DON'T use Sequential Thinking for simple decisions**
```yaml
# BAD: Overkill for obvious choice
Decision: Use standard project library for database access
→ Don't use Sequential Thinking (obvious choice)
```

✅ **DO use for complex trade-offs**
```yaml
# GOOD: Multiple valid approaches
Decision: Worker pool vs Pipeline vs Semaphore
→ Use Sequential Thinking (3+ alternatives with trade-offs)
```

---

❌ **DON'T call Context7 repeatedly for same library**
```yaml
# BAD: Multiple calls for same library in same session
query-docs("{library} transaction")
query-docs("{library} connection pool")  # Use same session's context!
```

✅ **DO save to memory and reuse**
```yaml
# GOOD: Query once, save pattern, reuse
query-docs("{library} patterns")
create_entities({ name: "{library} Integration Pattern", ... })
# Later: search_nodes("{library} patterns")
```

---

## SEE ALSO

- `shared-error-handling.md` — MCP error scenarios
- `shared-autonomy.md` — MCP unavailability as stop condition
- mcp__memory MCP server — Detailed memory usage patterns (SEE: shared-mcp.md)
- /db-explorer command — PostgreSQL MCP full workflow example
