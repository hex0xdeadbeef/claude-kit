# ════════════════════════════════════════════════════════════════════════════════
# ARTIFACT ARCHIVE — ADAS Pattern (P3.2)
# Evolving library of successful patterns
# v9.0.0
# ════════════════════════════════════════════════════════════════════════════════

purpose: "Extract, compose, evaluate, and promote patterns from successful artifacts"
principle: "Meta-agent improves not just from mistakes (Reflexion) but from successes (ADAS)"
pattern_source: "ADAS — Automated Design of Agentic Systems (Hu et al., 2024)"

# ════════════════════════════════════════════════════════════════════════════════
# STORAGE
# ════════════════════════════════════════════════════════════════════════════════

storage:
  location: ".meta-agent/archive/"
  structure:
    patterns_dir: "patterns/"
    by_type: "patterns/{artifact_type}/"
    pattern_file: "patterns/{artifact_type}/pattern-{id}.yaml"
    index_file: "index.yaml"
  note: "Separate from .claude/archive/ (which stores artifact backups for rollback)"

# ════════════════════════════════════════════════════════════════════════════════
# PATTERN STRUCTURE
# ════════════════════════════════════════════════════════════════════════════════

pattern_structure:
  pattern_id: "string (unique: {artifact_type}-{short_desc}-{timestamp})"
  artifact_type: "command | skill | rule | agent"
  source_artifact: "string (.claude/<type>/<name>.md — where extracted from)"
  pattern_description: "string (what this pattern solves, 1-2 sentences)"
  pattern_content: "string (YAML block or section snippet, self-contained)"
  quality_score: "float 0.0-1.0 (from eval-optimizer final score)"
  usage_count: "int (0 initially, incremented on reuse)"
  domain_tags: "list[string] (e.g., ['api', 'validation', 'auth'])"
  created_at: "date (YYYY-MM-DD)"
  last_used: "date (YYYY-MM-DD or null)"
  success_rate: "float (% of uses that led to quality >= 0.85)"

# ════════════════════════════════════════════════════════════════════════════════
# OPERATIONS
# ════════════════════════════════════════════════════════════════════════════════

operations:
  extract:
    trigger: "CLOSE phase, after successful VERIFY"
    condition: "eval final_score >= 0.85"
    process:
      - "Identify self-contained reusable sections in artifact"
      - "Patterns = sections/examples/flows that work independently"
      - "Examples: error_handling structure, auth flow, async pattern, validation block"
      - "For each pattern: create pattern-{id}.yaml with full metadata"
      - "Update index.yaml with new entries"
    guidelines:
      - "Pattern must be ≥ 10 lines and ≤ 100 lines"
      - "Pattern must be self-contained (no unresolved references)"
      - "Pattern must have clear purpose/description"
      - "Max 5 patterns per artifact (focus on best)"
    fallback: "If < 3 clear patterns found, skip extraction (log to observability)"
    output: |
      🗃️ Archive: Extracted {N} patterns from {artifact_name}
      - {pattern_1}: {description} (score: {score})
      - {pattern_2}: {description} (score: {score})

  compose:
    trigger: "DRAFT phase during CREATE mode"
    condition: "Archive exists AND has patterns for target artifact_type"
    process:
      - "Query archive: patterns matching artifact_type + domain_tags"
      - "Sort by: quality_score * 0.6 + usage_count * 0.2 + recency * 0.2"
      - "Retrieve top 5 patterns"
      - "Present to generator: 'Consider reusing these patterns'"
      - "Generator composes new artifact incorporating relevant patterns"
      - "Increment usage_count for each pattern used"
      - "Update last_used date"
    benefit: "New artifacts inherit battle-tested structures"
    output: |
      🗃️ Archive: Composed from {N} patterns
      - {pattern_1}: {description} (used {usage_count} times, score {score})

  evaluate:
    trigger: "After each artifact lifecycle where archive patterns were used"
    metric: "Did the final artifact score >= 0.85?"
    update: "Adjust pattern success_rate based on outcome"
    output: |
      🗃️ Archive: Updated success_rate for {N} patterns

  prune:
    trigger: "Periodic (during /meta-agent cleanup or manual)"
    conditions:
      - "quality_score < 0.6 AND usage_count == 0 AND age > 90 days"
    action: "Move to patterns/archive/ (soft delete, recoverable)"
    output: |
      🗃️ Archive: Pruned {N} low-value patterns (moved to patterns/archive/)

  promote:
    trigger: "Periodic review or after high-performing patterns detected"
    conditions:
      - "usage_count >= 5 AND quality_score >= 0.9 AND success_rate >= 0.8"
    action: "Integrate pattern into templates/{type}.md as recommended section"
    output: |
      🗃️ Archive: Promoted {N} patterns to templates/
      - {pattern}: now part of {template}

# ════════════════════════════════════════════════════════════════════════════════
# INDEX FILE FORMAT
# ════════════════════════════════════════════════════════════════════════════════

index_format:
  path: ".meta-agent/archive/index.yaml"
  structure: |
    patterns:
      - id: "command-workflow-20260208"
        type: "command"
        source: ".claude/commands/workflow.md"
        description: "Full development pipeline orchestrator"
        quality_score: 0.92
        usage_count: 3
        domain_tags: ["orchestration", "pipeline"]
        created_at: "2026-02-08"
        last_used: "2026-02-10"
        success_rate: 1.0

    stats:
      total_patterns: 47
      by_type: { command: 12, skill: 23, rule: 8, agent: 4 }
      avg_quality_score: 0.87
      last_extraction: "2026-02-08"
      last_prune: "2026-01-15"

# ════════════════════════════════════════════════════════════════════════════════
# INTEGRATION
# ════════════════════════════════════════════════════════════════════════════════

integration:
  phases:
    CLOSE: "Extract patterns (always for successful runs)"
    DRAFT_CREATE: "Compose from patterns (CREATE mode only)"
    CLEANUP: "Prune old patterns"
  load_tier: "Tier 3 (loaded in CLOSE and DRAFT/CREATE, unloaded after)"
  mcp_memory: "Archive metadata also saved to mcp__memory for cross-session access"
