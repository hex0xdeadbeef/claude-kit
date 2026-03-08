# Error Handling

| Error | Severity | Action |
|-------|----------|--------|
| Memory MCP unavailable | NON_CRITICAL | Warn, proceed without memory |
| Sequential Thinking unavailable | NON_CRITICAL | Warn, manual analysis |
| Context7 unavailable | NON_CRITICAL | Fallback: WebSearch → memory → general knowledge |
| PostgreSQL MCP unavailable | NON_CRITICAL | Use migration files → SQL queries → entity structs |
| Beads unavailable | NON_CRITICAL | Skip beads phases |
| Beads sync failed | WARNING | Continue with local state, remind manual sync later |
| Plan not found | FATAL | EXIT — run /planner first |
| Plan not approved | FATAL | EXIT — run /plan-review first |
| Template missing | NON_CRITICAL | Use minimal format |
| PROJECT-KNOWLEDGE.md missing | NON_CRITICAL | Heuristic fallback (SEE: deps/core/project-knowledge.md) |
| Git repo issues | WARNING | Continue (may skip commit phase) |
| Tests fail 3x | STOP_AND_WAIT | Show errors, request manual fix |
| Lint fail 3x | STOP_AND_WAIT | Show issues, request decision (manual fix / nolint / config) |
| Import violation | STOP_AND_FIX | Fix before proceeding |
| Scope unclear after 2x clarification | STOP_AND_WAIT | Wait for clear requirements |
| User not responding | STOP_AND_WAIT | Wait, do NOT proceed with assumptions |
