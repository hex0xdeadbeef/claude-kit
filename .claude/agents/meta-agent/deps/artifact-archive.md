# ════════════════════════════════════════════════════════════════════════════════
# ARTIFACT ARCHIVE — ADAS Pattern
# Evolving library of successful patterns
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
    trigger: "DRAFT phase, step 0 (BOTH enhance and create modes)"
    condition: "Archive exists AND has patterns for target artifact_type"
    process:
      - "Query archive: patterns matching artifact_type + domain_tags"
      - "Sort by: quality_score * 0.6 + usage_count * 0.2 + recency * 0.2"
      - "Filter: success_rate >= 0.7 (exclude unreliable patterns)"
      - "Retrieve top 5 patterns"
      - "Format as structural_hints (see active_composition section below)"
      - "Present to generator as context before draft generation"
      - "Generator decides which patterns to incorporate (not forced)"
      - "Track: record pattern_ids considered + pattern_ids used"
      - "Increment usage_count for each pattern used"
      - "Update last_used date"
    benefit: "Both new and enhanced artifacts inherit battle-tested structures"
    output: |
      🗃️ Archive: Queried {Q} patterns, presenting {N} hints
      - {pattern_1}: {description} (score {score}, used {usage_count}x)

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
# ACTIVE COMPOSITION (ADAS)
# Step 0 in DRAFT phase: query archive → structural hints → track usage
# ════════════════════════════════════════════════════════════════════════════════

active_composition:
  purpose: "Transform archive from passive storage to active design advisor"
  principle: "Successful patterns from past artifacts accelerate and improve new generation"

  query_api:
    input:
      artifact_type: "command | skill | rule | agent"
      domain_tags: "list[string] (from PLAN phase output)"
      mode: "enhance | create"
    filters:
      - "artifact_type matches exactly"
      - "domain_tags overlap >= 1 tag (fuzzy: partial match counts)"
      - "success_rate >= 0.7"
      - "quality_score >= 0.6"
    sorting: "quality_score * 0.6 + usage_count * 0.2 + recency * 0.2"
    limit: 5
    fallback: "If < 2 patterns found → expand: drop domain_tags filter, keep type + quality"

  structural_hints_format:
    purpose: "Compact representation of patterns for generator context"
    note: "NOT full pattern content — only structure + description to minimize token cost"
    per_hint:
      pattern_id: "string"
      description: "string (1-2 sentences: what this pattern solves)"
      structure_outline: "string (section names / key fields, max 5 lines)"
      quality_score: "float"
      usage_count: "int"
      relevance: "string (why this pattern matched: which tags, similar artifact)"
    total_budget: "max 50 lines for all hints combined (10 lines per hint × 5 hints)"
    example: |
      ## Archive Hints (3 patterns found)
      1. [command-error-handling-20260201] Error recovery with retry logic
         Structure: error_types → retry_policy → fallback_action → user_message
         Score: 0.91, Used: 4x, Tags: [error-handling, resilience]
      2. [command-workflow-20260208] Multi-step orchestration pipeline
         Structure: steps[] → gates[] → rollback → progress_output
         Score: 0.92, Used: 3x, Tags: [orchestration, pipeline]

  usage_tracking:
    purpose: "Know which patterns were actually used vs just presented"
    tracked_fields:
      patterns_queried: "int (total matching archive query)"
      patterns_presented: "int (top N shown as hints)"
      patterns_used: "list[pattern_id] (generator explicitly incorporated)"
      patterns_skipped: "list[pattern_id] (presented but not used)"
    storage: "progress.json → phases.DRAFT.archive_composition"
    feedback_loop: "patterns_used → update success_rate in CLOSE phase → deps/artifact-archive.md#feedback"

  when_no_archive:
    condition: "Archive empty OR no patterns match"
    action: "Skip step 0 silently, proceed to generation"
    output: "🗃️ Archive: No matching patterns (proceeding without hints)"

  cost_analysis:
    token_overhead: "~200-500 tokens for 5 hints (structural outlines only)"
    benefit: "Reduces DRAFT iterations by providing proven structures upfront"
    net_effect: "Positive ROI when archive has ≥3 patterns for artifact type"

# ════════════════════════════════════════════════════════════════════════════════
# FEEDBACK LOOP (post-VERIFY success_rate update)
# ════════════════════════════════════════════════════════════════════════════════

feedback:
  purpose: "Close the loop: track whether archive-sourced patterns led to good outcomes"
  trigger: "CLOSE phase, after successful VERIFY (same as extract)"
  condition: "patterns_used is non-empty in progress.json"
  process:
    - "Read patterns_used from progress.json → phases.DRAFT.archive_composition"
    - "Read final eval_score from progress.json → phases.DRAFT.eval_history"
    - "For each pattern_id in patterns_used:"
    - "  If final_score >= 0.85: success_rate = (success_rate * usage_count + 1) / (usage_count + 1)"
    - "  If final_score < 0.85: success_rate = (success_rate * usage_count + 0) / (usage_count + 1)"
    - "Update pattern in archive index"
  decay:
    note: "Old outcomes weighted less over time"
    method: "EMA (exponential moving average) with alpha=0.3"
    formula: "success_rate = alpha * new_outcome + (1 - alpha) * old_success_rate"
  output: |
    🗃️ Archive: Updated success_rate for {N} patterns
    - {pattern_id}: {old_rate} → {new_rate} (outcome: {pass|fail})

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
    DRAFT: "Step 0 — Active composition: query → hints → track (BOTH enhance and create modes)"
    CLOSE_extract: "Extract patterns (always for successful runs)"
    CLOSE_feedback: "Update success_rate for patterns used in DRAFT"
    CLEANUP: "Prune old patterns"
  load_tier: "Tier 3 (loaded in DRAFT step 0 and CLOSE, unloaded after)"
  mcp_memory: "Archive metadata also saved to mcp__memory for cross-session access"
  phase_refs:
    DRAFT_enhance: "→ deps/phases-enhance.md#phase_6_draft — step 0 archive composition"
    DRAFT_create: "→ deps/phases-create.md#other_phases — step 0 archive composition"
    CLOSE: "→ deps/phases-enhance.md#phase_9_close — steps 3a-3d + 3e feedback"
