# Changelog

**Load when:** Historical reference only.

---

## v4.3.0: YAML-first refactoring (2026-02-24)
- Converted orchestration algorithm from 217-line prose to structured YAML steps
- Converted architecture ASCII diagram to YAML pipeline definition
- Moved changelog to deps/changelog.md
- Progress section converted to YAML keys
- YAML ratio: 52% → ~90%

## v4.2.0: Tree-Sitter MCP + GRAPH Phase + Repo-Map (2026-02-23)
- NEW: tree-sitter MCP as primary analysis method (replaces ast-grep as default)
  - 31 languages supported via tree-sitter-language-pack
  - Full API: symbols, usage, dependencies, queries, similar code
  - Fallback chain: tree-sitter-mcp → ast-grep → grep
- NEW: GRAPH subagent (sonnet) between DETECTION and ANALYSIS
  - Builds symbol table (functions, types, interfaces)
  - Constructs file-level dependency graph
  - Applies PageRank (or fan-in approximation) for symbol ranking
  - Generates token-budgeted repo-map for ANALYSIS context
- ANALYSIS subagent now receives repo-map as pre-computed context
  - Faster architecture detection (hub files → domain layer)
  - Higher confidence scores (+5-10% with repo-map)
- Pipeline updated: 10 phases (was 9)
- Compound subagents: DETECT+GRAPH+ANALYZE (was DETECT+ANALYZE)
- state.graph added to state contract
- deps/tree-sitter-patterns.md created (replaces ast-analysis.md)
- Batch mode: 3 waves (DETECT → GRAPH → ANALYZE) instead of 2

## v4.1.0: Pipeline Parallelism for Monorepos (2026-02-23)
- Added pipeline parallelism: compound subagents (DETECT+ANALYZE per module)
- ≤3 modules: pipeline mode (no inter-phase barrier, ~40% faster)
- 4+ modules: batch mode (classic v4.0 approach for concurrency control)
- Compound subagent protocol in orchestration.md
- Per-module state lifecycle and partial failure handling in state-contract.md
- Updated merge validation: per-module status tracking

## v4.0.0: Multi-Agent Orchestration (2026-02-23)
- Refactored from monolithic pipeline to orchestrator + 6 subagents
- Subagents: discovery (haiku), detection (sonnet), analysis (opus),
  generation (sonnet), verification (sonnet), report (haiku)
- CRITIQUE remains inline in orchestrator (blocking gate, needs full state)
- Added parallel execution for monorepo modules
- Added tiered model selection (~40% cost reduction)
- Added retry logic and graceful degradation
- State contract updated with subagent interface protocol
- Created deps/orchestration.md — subagent interaction protocol

## v3.0.0: AST analysis, dependency graph, structured state (2026-02-23)

## v2.2.0: YAML-first restructure (2026-01-20)

## v2.1.0: Size optimization via progressive offloading (2026-01-18)

## v2.0.0: Major quality upgrade (2026-01-18)

## v1.0.0: Initial modular implementation with phases/
