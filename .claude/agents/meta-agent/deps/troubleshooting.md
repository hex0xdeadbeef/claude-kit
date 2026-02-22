# ════════════════════════════════════════════════════════════════════════════════
# TROUBLESHOOTING & COMMON MISTAKES
# Offloaded from meta-agent.md v9.0.0
# ════════════════════════════════════════════════════════════════════════════════

troubleshooting:
  - problem: "Claude skips CONSTITUTE (formerly CRITIQUE)"
    cause: "Plan seems good → rushed to CHECKPOINT"
    fix: "ALWAYS run constitutional evaluation (P1-P5), even if plan seems perfect"
    lesson: "Self-review catches issues before user sees them"
  - problem: "Claude skips CHECKPOINT"
    cause: "Obvious solution → rushed to APPLY"
    fix: "ALWAYS show PLAN + CONSTITUTE, even if solution is obvious"
    lesson: "Checkpoint prevents wasted work on wrong solution"
  - problem: "Changes too large (size threshold exceeded)"
    cause: "Trying to add too much in one enhance"
    fix: |
      Option 1: Split into multiple enhance calls
      Option 2: Move details to deps/ files (progressive loading)
    recovery: "SEE: deps/blocking-gates.md#recovery_strategies → SIZE_GATE"
  - problem: "Artifact broken after APPLY"
    cause: "Bad edit or missing section"
    fix: "/meta-agent rollback"
  - problem: "Lost changes between sessions"
    cause: "Forgot mcp__memory__add_observations in CLOSE"
    fix: "Always save key findings to MCP memory"
  - problem: "Gate fails with no recovery"
    cause: "Blocking gate rejects but no clear next step"
    fix: "Use gate recovery strategies: SEE deps/blocking-gates.md#recovery_strategies"
    lesson: "Every gate failure should have an auto-recovery or escalation path"
  - problem: "Context budget exceeded mid-phase"
    cause: "Too many deps loaded simultaneously"
    fix: "Check budget before loading; unload lowest-tier files first"
    recovery: "SEE: deps/context-management.md#budget_tracking"

common_mistakes:
  - mistake: "Skip EXPLORE, jump to PLAN"
    why_bad: "Missing context leads to wrong changes"
    fix: "Always read artifact + PROJECT-KNOWLEDGE.md first"

  - mistake: "Not saving to MCP memory"
    why_bad: "Lost knowledge between sessions"
    fix: "CLOSE phase MUST include mcp__memory__add_observations"

  - mistake: "Hardcode code examples instead of search patterns"
    why_bad: "Code changes, examples become stale"
    fix: "Use grep/glob patterns, let Claude find current examples"

  - mistake: "Ask partial questions, not full plan approval"
    why_bad: "User approves one thing, Claude changes another"
    fix: "Show COMPLETE plan before any APPLY"

  - mistake: "Evaluator sees generation process (sunk cost bias)"
    why_bad: "Self-evaluation is biased toward justifying own work"
    fix: "Use separated evaluator subagent that only sees draft output, not process"

  - mistake: "Ignore gate recovery, just STOP"
    why_bad: "User frustrated by dead-end failures"
    fix: "Always attempt auto-recovery, then fallback, then escalate with options"
