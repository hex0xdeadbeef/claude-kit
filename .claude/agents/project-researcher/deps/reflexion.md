# Reflexion (Self-Improvement)

**Purpose:** Learn from mistakes without fine-tuning.

**Pattern:** `trigger → context → mistake → consequence → fix → example`

**Storage:** MCP Memory (`meta-agent-lesson` entities)

**Load when:** Implementing self-improvement or investigating recurring failures.

---

## REFLEXION (SELF-IMPROVEMENT)

### How It Works

1. **Capture failures** during CRITIQUE or VERIFY phases
2. **Store as lessons** in MCP memory
3. **Auto-inject** in next run (VALIDATE phase)
4. **Decay mechanism**: Archive stale lessons after 30 days

### Example Lesson

```yaml
trigger: "Generic skills generated"
context: "CREATE mode, Go project with {codegen_tool} patterns"
mistake: "Generated 'error-handling' skill instead of project-specific"
consequence: "Low relevance, user had to manually adjust"
fix: "Detect {codegen_tool} → generate '{layer}-error-patterns' skill"
example: "internal/{repository_layer}/ → {codegen_tool} error patterns"
```

### Lesson Lifecycle

| Stage | Condition | Action |
|-------|-----------|--------|
| **Create** | VERIFY finds issue | Store to MCP memory |
| **Inject** | VALIDATE phase | Load top 5 relevant lessons |
| **Promote** | ≥5 occurrences | Move to TROUBLESHOOTING |
| **Archive** | 90 days, <3 uses | Remove from active pool |

### Integration Points

- **VALIDATE (Phase 1):** Load lessons, show warnings
- **CRITIQUE (Phase 6):** Check against known mistakes
- **VERIFY (Phase 8):** Detect new issues, create lessons
- **REPORT (Phase 9):** Save lessons to MCP memory

**SEE:** meta-agent v7.0 REFLEXION pattern for full implementation
