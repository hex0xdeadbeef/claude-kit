---
name: project-researcher-agent-research
description: Complete research on project-researcher agent architecture, subagents, state contracts, and workflow integration
type: reference
---

# PROJECT-RESEARCHER AGENT — COMPREHENSIVE RESEARCH

## EXECUTIVE SUMMARY

**Project Researcher** is an autonomous orchestrator agent (v4.3.0) for deep analysis of ANY codebase and generation of `.claude/` configuration. It coordinates 7 specialized subagents across 10 phases using a formal typed state contract.

**Key Facts:**
- **Model routing:** opus (orchestrator) → sonnet/haiku (subagents)
- **Invocation:** via Task tool (subagent_type: general-purpose)
- **Standalone:** Not called by /workflow orchestrator directly; triggered when user mentions "bootstrap claude", "research project", "analyze project"
- **Autonomy:** Full execution without user confirmation until completion
- **Output:** CLAUDE.md (≤200 lines), PROJECT-KNOWLEDGE.md, skills/, rules/, memory.json

---

## ARCHITECTURE: Orchestrator + 7 Subagents + 1 Inline Phase

```
DISCOVERY (haiku)
    ↓
DETECTION (sonnet) ──┐
GRAPH (sonnet) ──────┼─→ Parallel per-module (if monorepo)
ANALYSIS (opus) ─────┘
    ↓
CRITIQUE (opus, inline, blocking gate)
    ↓
GENERATION (sonnet)
    ↓
VERIFICATION (sonnet, blocking gate)
    ↓
REPORT (haiku)
```

**Total Phases:** 10 (VALIDATE, DISCOVER, DETECT, GRAPH, ANALYZE, MAP, DATABASE, CRITIQUE, GENERATE, VERIFY)

**Monorepo Modes:**
- **single:** Sequential DETECT→GRAPH→ANALYSIS (no monorepo)
- **pipeline:** ≤3 modules → compound DETECT+GRAPH+ANALYZE per module in parallel
- **batch:** 4+ modules → 3-wave batch (all DETECT → all GRAPH → all ANALYZE)

---

## SUBAGENT REGISTRY

| Subagent | File | Model | Phases | Parallelizable |
|----------|------|-------|--------|---|
| **discovery** | subagents/discovery.md | haiku | VALIDATE + DISCOVER | No (first) |
| **detection** | subagents/detection.md | sonnet | DETECT | Per-module |
| **graph** | subagents/graph.md | sonnet | GRAPH | Per-module |
| **analysis** | subagents/analysis.md | opus | ANALYZE + MAP + DATABASE | Per-module |
| **generation** | subagents/generation.md | sonnet | GENERATE | No |
| **verification** | subagents/verification.md | sonnet | VERIFY | No (blocking gate) |
| **report** | subagents/report.md | haiku | REPORT | No |

**Inline Phase:**
- **CRITIQUE** (phases/critique.md, opus, blocking gate) — not a subagent; loaded inline in orchestrator

---

## PHASE BREAKDOWN

### Phase 1: DISCOVERY (haiku)
**Output:** state.validate + state.discover

**Two sub-phases:**
1. **VALIDATE** — Project baseline, mode detection (CREATE/UPDATE/AUGMENT)
   - Directory structure check
   - Source file detection (count by extension)
   - Git repository check (is_git_repo, git_root, git_remote, commit_count)
   - Claude directory audit (.claude/ artifacts inventory)
   - Mode detection logic
   - Conditional git analysis (UPDATE mode only)
   - Conditional artifact audit (AUGMENT mode only)

2. **DISCOVER** — Project structure mapping, monorepo detection, strategy selection
   - Manifest file scanning (go.mod, package.json, Cargo.toml, etc.)
   - Module classification (language, type: service/library/internal_library/command_line_tool/root_module/tool)
   - Inter-module dependency detection
   - Root module detection (fan-out calculation)
   - Monorepo detection (>1 manifest OR >3 cmd/ entries OR >1 services/ entry)
   - Strategy selection: single → per-module-with-shared-context → per-module
   - Analysis targets definition (list of modules to analyze)

**Quality Checklist:** Path exists, ≥1 source file, mode determined, strategy selected, analysis_targets non-empty

---

### Phase 2: DETECTION (sonnet)
**Output:** state.detect

**Three-Tier Fallback Chain:**
1. tree-sitter MCP (primary, register_project step)
2. ast-grep CLI (with auto-install attempt)
3. grep (last resort)

**Steps:**
1. Analysis method check + tree-sitter MCP project registration
2. Language detection (file count analysis, confidence calc: ≥0.7 definite, ≥0.3 strong, <0.3 multi-language)
3. Framework detection (3-tier: manifest parsing → AST confirmation → grep fallback)
   - Confidence modifiers: baseline 1.0, -0.05 (AST), 0.00 (manifest+grep agree), -0.15 (heuristic only)
4. Build tools detection (Dockerfile, Makefile, CI/CD pipelines, linters)
5. Testing infrastructure detection (frameworks, mock tools, test files, table-driven tests)

**Known Framework Patterns:**
- Go: gin, echo, fiber, gorm, sqlc, grpc, protobuf, cobra, urfave/cli
- JavaScript: react, vue, angular, next.js, express, fastify, nestjs, apollo
- Python: django, fastapi, flask, sqlalchemy, pydantic
- Rust: actix, tokio, serde, diesel, sqlx
- Java: spring, hibernate, junit, gradle

**Quality Checklist:** Analysis method determined, primary language ≥0.3 confidence, ≥1 framework or empty list OK, ≥1 build tool, testing framework found, all methods recorded

---

### Phase 3: GRAPH (sonnet, v4.2 NEW)
**Output:** state.graph

**Three Core Artifacts:**
1. **Symbol Table** — all functions, types, interfaces with metadata
2. **Dependency Graph** — file/package dependency edges with weights
3. **Repo-Map** — ranked (PageRank) symbol list, compressed to token budget

**Steps:**
1. Analysis method selection (tree-sitter MCP preferred; fallback to ast-grep or grep)
2. Symbol extraction (functions, classes, structs, interfaces, imports)
   - Excludes: test files (*_test.go), generated code (*_gen.go, *.pb.go)
   - Filters to exported symbols for ranking
3. Dependency graph construction
   - Nodes: files
   - Edges: import/call/type_reference with weight (count of references)
   - External packages marked separately (not ranked)
4. PageRank computation (or fan-in approximation for simplicity)
   - Damping factor: 0.85
   - Personalization weights: entry_points=1.5, interfaces=1.3, domain_layer=1.2, default=1.0
5. Token budget & repo-map generation
   - Scaling: <50 files→2k tokens, 50-200→4k, 200-500→6k, >500→8k
   - Format: hierarchical (Hub files → Important → Other)
   - Sections: marked ## Hub Files, ## Important Files, ## Other Files

**Quality Checklist:** Total_symbols > 0, exported_symbols > 0, dependency_graph edges > 0 (or justified), hub files ≥1, circular deps documented, repo-map ≤token_budget, test files excluded

---

### Phase 4-5: ANALYSIS (opus)
**Output:** state.analyze + state.map (+ state.database if MCP available)

**Sub-phases:**
1. **ANALYZE** — Architecture pattern detection + layer analysis
   - Uses repo-map context (v4.2 optimization): hub files → domain layer, interface files → ports layer
   - Detects pattern: clean | hexagonal | mvc | layered | ddd | microservices | modular_monolith | standard_go
   - Confidence calculation: repo-map+dir+AST (0.90+) → dir+AST (0.85+) → repo-map+dir (0.80-0.89) → dir only (0.60-0.84) → AST only (0.60-0.84) → weak (0.60)
   - Layer analysis: package count, interface count, struct count, function count, method count, import analysis per layer
   - Evidence recording: {indicator, weight 0.0-1.0, detail}

2. **MAP** — Entry points, domain entities, interfaces, call flow
   - Entry points: main(), handler functions, exported services
   - Domain entities: core business types (models, aggregates)
   - Interfaces: contracts, ports
   - Call flow: request → handler → service → repository → domain

3. **DATABASE** (optional, if MCP available)
   - Uses PostgreSQL MCP (mcp__postgres__list_tables, describe_table, query)
   - Extracts schema: tables, columns, types, relationships
   - Maps to code: repository methods ↔ queries

---

### Phase 6: CRITIQUE (opus, inline, blocking gate)
**Purpose:** Self-adversarial review BEFORE generation

**Checklist:**
- Completeness: all layers mapped, entry points documented, deps captured, database analyzed, dependency graph built
- Accuracy: confidence realistic, language correct, framework versions match, no unjustified assumptions, edge cases considered
- Quality: CLAUDE.md ≤200 lines, skills focus on real patterns, rules match structure, no duplication
- Relevance: artifacts match needs, skills target pain points, rules cover operations, no over/under-engineering

**Adversarial Questions:**
1. "Name 3 things a senior dev would find inaccurate"
2. "What important aspect may I have missed?"
3. "If my architecture were wrong, what's the alternative?"
4. "Which conventions did I assume on <5 occurrences?"
5. "Which artifacts am I generating out of inertia?"

**Gate Outcome:** blocking — if fails, re-run ANALYSIS with adjustments or FATAL

---

### Phase 7: GENERATION (sonnet)
**Output:** state.generate (artifacts dict)

**Generates:**
1. **CLAUDE.md** (≤200 lines)
   - Header: one-line description, project role
   - Architecture: summary of pattern + key layers
   - Key Rules: table of conventions (testing, errors, logging, etc.)
   - Project Structure: core directory tree
   - Quick Start: entry points + test command
   - Skills Reference: list with triggers
   - Rules Reference: layer rule paths

2. **Skills** (6 packages, ≤600 lines each)
   - From detected patterns: architecture, testing, logging, errors, DI, HTTP, gRPC, database, config, middleware
   - YAML frontmatter: name, description, triggers, related_skills
   - Content: pattern explanation, examples, edge cases

3. **Rules** (YAML files per layer/domain)
   - YAML frontmatter: name, paths (glob), triggers
   - Active when file glob matches

4. **PROJECT-KNOWLEDGE.md** (comprehensive)
   - Executive summary, module map, architecture deep-dive, dependency topology, conventions, database schema

5. **memory.json** (MCP persistent context)
   - Key findings, architecture snapshot, patterns for future sessions

---

### Phase 8: VERIFICATION (sonnet, blocking gate)
**Output:** state.verify

**Checks:**
1. YAML syntax validation (all frontmatter)
2. Required fields present (name, description, triggers, paths)
3. Field type validation (strings, arrays, floats, ints)
4. Reference validation (@skill-name paths, file paths, cross-references)
5. CLAUDE.md line count (warn if ≥150, fail if >200)
6. Skill/rule file sizes (warn if >600 lines)
7. Markdown link integrity

**Gate Outcome:** blocking — if fails, re-run GENERATION with fixes or FATAL

---

### Phase 9: REPORT (haiku)
**Output:** Markdown report (no state updates)

**Mode-Specific Reports:**
- **CREATE:** Full analysis from scratch
- **AUGMENT:** What's new/changed
- **UPDATE:** Incremental refresh since last analysis

**Sections:**
1. Executive Summary (≤400 words)
2. Project at a Glance (metadata table)
3. Analysis Confidence (confidence table with evidence)
4. Detailed Findings (architecture, layers, patterns, violations, conventions)
5. Entity Map (core domain types)
6. Dependency Graph (hub packages, circular deps)
7. Generated Artifacts (skills, rules, CLAUDE.md preview)
8. Recommendations (for configuration, next steps)
9. Confidence Score Justification (weighted average)

---

## STATE CONTRACT

**Global State Structure:**

```yaml
state:
  validate:        # DISCOVERY subagent output
    path, mode, is_git_repo, git_root, git_remote, commit_count
    source_file_count, extension_distribution, has_claude_dir
    claude_artifacts, existing_artifacts (if AUGMENT/UPDATE)
    git_analysis (if UPDATE mode only)

  discover:        # DISCOVERY subagent output
    is_monorepo, modules[], manifests[], internal_dependencies
    root_module, strategy, strategy_rationale, analysis_targets

  detect:          # DETECTION subagent output
    analysis_method, primary_language, primary_confidence
    secondary_languages[], language_counts, frameworks[]
    build_tools (files, ci_cd, linters), testing (frameworks, mock_tools, patterns)

  graph:           # GRAPH subagent output (v4.2)
    analysis_method, method_confidence, symbol_table (total_symbols, by_kind)
    dependency_graph (total_nodes, edges, hub_files[], isolated_files, circular_deps)
    pagerank (algorithm, top_files[], convergence)
    repo_map (content, token_count, token_budget, files_included, coverage, sections)

  analyze:         # ANALYSIS subagent output
    architecture (primary_pattern, confidence, reasoning)
    architecture_evidence[], layers[]
    domain_entities[], interfaces[]
    violations[], conventions[]

  map:             # ANALYSIS subagent output (continued)
    entry_points[], call_flow, dependency_graph (hub_packages)

  database:        # ANALYSIS subagent output (optional, if MCP available)
    tables[], schema_diagram, relationships

  critique:        # CRITIQUE inline phase output
    completeness_check, accuracy_check, quality_check, relevance_check
    adversarial_questions[], issues[], plan_adjustments[]

  generate:        # GENERATION subagent output
    artifacts:
      claude_md, project_knowledge_md, memory_json
      skills: {skill_name: content}
      rules: {rule_name: content}

  verify:          # VERIFICATION subagent output
    gate_passed: bool, errors[], warnings[], validated_artifacts[]
```

**State Serialization Rules:**
- Subagents receive ONLY required fields (not full state)
- Subagents return ONLY their section (delta, not full state)
- Orchestrator merges per-subagent results into global state
- Monorepo: per-module state → orchestrator aggregates

---

## SUBAGENT CALL PROTOCOL

### Via Task Tool

```
Task:
  subagent_type: "general-purpose"
  model: "{model_from_registry}"
  prompt: |
    # SUBAGENT: {name}

    Read the subagent instructions:
    Read file: {agent_root}/subagents/{name}.md

    ## INPUT STATE
    ```yaml
    {serialized_required_fields_only}
    ```

    ## OUTPUT FORMAT
    ```yaml
    subagent_result:
      status: "success" | "failure" | "partial"
      state_updates:
        {phase_name}:
          {field}: {value}
      progress_summary: "{one-line}"
      error:  # if status != success
        code, message, recovery
    ```
```

### Result Parsing

Orchestrator:
1. Parses `subagent_result` YAML
2. Validates `state_updates` against state contract
3. Merges state per rules (simple replacement for single, aggregation for monorepo)
4. Logs `progress_summary`
5. On failure: retry once with reduced scope, else FATAL

---

## OPERATION MODES

| Mode | Condition | Behavior |
|------|-----------|----------|
| **CREATE** | .claude/ does not exist | Full analysis from scratch |
| **AUGMENT** | .claude/ exists, no PROJECT-KNOWLEDGE.md | Adds missing parts, preserves existing |
| **UPDATE** | PROJECT-KNOWLEDGE.md exists + git repo | Incremental refresh, tracks changes |

---

## ERROR HANDLING

| Error | Severity | Action |
|-------|----------|--------|
| NO_DIR | FATAL | Path doesn't exist |
| EMPTY_PROJECT | FATAL | No source files |
| UNKNOWN_LANG | FATAL | Can't detect language |
| SUBAGENT_FAILURE | FATAL | After retry fails |
| CRITIQUE_GATE | FATAL | After 2 attempts |
| VERIFY_GATE | FATAL | After 2 attempts |
| Tree-sitter MCP unavailable | NON_CRITICAL | Fall back to ast-grep, then grep |
| ast-grep unavailable | NON_CRITICAL | Fall back to grep |

---

## KEY DESIGN DECISIONS

### 1. Orchestrator + Subagents Split
- **Orchestrator** (this AGENT.md): state management, phase routing, gate enforcement
- **Subagents** (7 files): specialized analysis, isolated context, parallelizable
- **Rationale:** Isolation prevents context bias, parallelism improves performance, clean separation of concerns

### 2. Tree-Sitter MCP as Primary (v4.2)
- **Primary:** tree-sitter MCP (31 languages, full AST, symbol queries)
- **Fallback 1:** ast-grep CLI (pattern matching, no net API)
- **Fallback 2:** grep (text search, lowest confidence)
- **Rationale:** Tree-sitter is the standard (Aider, Cline, Cursor), MCP server removes CLI dependencies

### 3. GRAPH Phase (v4.2 NEW)
- **Purpose:** Pre-compute repo-map (ranked symbols, compressed to token budget)
- **Timing:** Between DETECTION and ANALYSIS (feeds repo-map to ANALYSIS context)
- **Benefit:** Architecture detection 5-10% more accurate, faster, better symbol prioritization
- **Fallback:** If GRAPH fails, ANALYSIS falls back to direct AST/grep (graceful degradation)

### 4. Monorepo Parallelism
- **Pipeline mode** (≤3 modules): compound DETECT+GRAPH+ANALYZE per module in parallel
- **Batch mode** (4+ modules): 3-wave (all DETECT → all GRAPH → all ANALYZE)
- **Rationale:** Balances context size (compound) with concurrency (batch), ~40% faster than sequential

### 5. Blocking Gates
- **CRITIQUE:** Blocks GENERATION until quality check passes
- **VERIFY:** Blocks artifact delivery until syntax/refs valid
- **Rationale:** Prevents bad artifacts from reaching users, forces quality checkpoints

### 6. Formal State Contract
- **Principle:** Typed data passed between phases, validated at every merge
- **Benefit:** Catches integration bugs early, enables programmatic validation
- **vs. Markdown:** Structured, parseable, versioned

---

## WORKFLOW INTEGRATION

**Invocation:** NOT called by /workflow orchestrator directly

**Triggers (user mentions):**
- "bootstrap claude"
- "research project"
- "analyze project"
- "project-researcher" (explicit)

**Input Arguments:**
- `path` (default: ".")
- `--dry-run` (default: false) — analysis only, no file writes

**Output Artifacts:**
- `.claude/CLAUDE.md` (main, ≤200 lines)
- `.claude/PROJECT-KNOWLEDGE.md` (deep analysis)
- `.claude/skills/{name}/SKILL.md` (reusable patterns)
- `.claude/rules/{name}.md` (layer-specific rules)
- `.claude/memory.json` (MCP persistent context)

**Downstream Usage:**
- `/planner` reads CLAUDE.md + PROJECT-KNOWLEDGE.md for context
- `/coder` reads generated skills + rules for implementation guidance
- plan-reviewer, code-reviewer agents use generated rules for validation

---

## SUPPORTED TECHNOLOGIES

**Languages (31 via tree-sitter):**
Go, Python, TypeScript, Rust, Java, JavaScript, C, C++, Ruby, PHP, Scala, Kotlin, Swift, etc.

**Go Frameworks:**
gin, echo, fiber, gorm, sqlc, grpc, protobuf, cobra, urfave/cli, chi, mux

**JavaScript/TypeScript:**
react, vue, angular, next.js, express, fastify, nestjs, apollo, webpack, vite

**Python:**
django, fastapi, flask, sqlalchemy, pydantic, pytest, celery

**Rust:**
actix, tokio, serde, diesel, sqlx, rocket, axum

**Java:**
spring-boot, hibernate, junit, gradle, maven

---

## HOOKS & SCRIPTS INTEGRATION

**PostToolUse Hook (auto-called after tool results):**
- Auto-format generated files (YAML, Markdown)
- Reference check (skill links, file paths)

**No explicit integration with:**
- PreCompact hook (text summarization — not needed by this agent)
- Test execution hooks (this agent doesn't run tests)
- Commit hooks (artifacts written by Write tool, not via git)

**No Co-Authored-By or git commit operations:**
- project-researcher is READ-ONLY + WRITE-ONLY (artifacts)
- No git operations (no commits, no rebase)
- Artifacts are new files, not modifications to existing tracked code

---

## REFERENCES & DEPENDENCIES

**Internal:**
- `.claude/rules/architecture.md` — import matrix, domain purity
- `.claude/rules/workflow.md` — command routing, model selection
- `.claude/commands/planner.md` — research input consumer
- `.claude/commands/coder.md` — implementation consumer
- `.claude/agents/plan-reviewer.md` — uses generated rules for validation
- `.claude/agents/code-reviewer.md` — uses generated rules for validation

**External:**
- tree-sitter MCP server (if available)
- ast-grep CLI (fallback)
- PostgreSQL MCP (optional, for schema analysis)
- Memory MCP (for persistent context, non-critical)

---

## VERSION HISTORY

**v4.3.0** (2026-02-24): YAML-first refactoring, structured orchestration algorithm
**v4.2.0** (2026-02-23): Tree-sitter MCP + GRAPH phase + repo-map (10 phases, was 9)
**v4.1.0** (2026-02-23): Pipeline parallelism for monorepos (compound subagents)
**v4.0.0** (2026-02-23): Multi-agent orchestrator + 6 subagents + CRITIQUE gate
**v3.0.0** (2026-02-23): AST analysis, dependency graphs, structured state
**v2.2.0** (2026-01-20): YAML-first restructure
**v2.1.0** (2026-01-18): Size optimization, progressive offloading
**v2.0.0** (2026-01-18): Major quality upgrade
**v1.0.0**: Initial modular implementation with phases/

---

## FILES & DIRECTORY STRUCTURE

```
.claude/agents/project-researcher/
├── README.md                              # Meta summary (v4.3.0, architecture overview)
├── AGENT.md                               # Main agent spec (orchestrator algorithm, 403 lines)
├── subagents/
│   ├── discovery.md                       # VALIDATE + DISCOVER (haiku)
│   ├── detection.md                       # DETECT (sonnet) — 3-tier analysis method
│   ├── graph.md                           # GRAPH (sonnet, v4.2 NEW) — symbol table, repo-map
│   ├── analysis.md                        # ANALYZE + MAP + DATABASE (opus)
│   ├── generation.md                      # GENERATE (sonnet) — artifacts production
│   ├── verification.md                    # VERIFY (sonnet, blocking gate)
│   └── report.md                          # REPORT (haiku) — final summary
├── phases/
│   └── critique.md                        # CRITIQUE (opus, inline, blocking gate)
├── deps/
│   ├── orchestration.md                   # Subagent call protocol, state merging, parallelism
│   ├── state-contract.md                  # Typed state schema, validation rules
│   ├── tree-sitter-patterns.md            # v4.2 — MCP queries, fallback patterns
│   ├── ast-analysis.md                    # Legacy ast-grep patterns (deprecated fallback)
│   ├── edge-cases.md                      # Known limitations, edge case handling
│   ├── step-quality.md                    # Per-phase quality checks
│   ├── reflexion.md                       # Self-improvement pattern
│   └── changelog.md                       # Version history
├── templates/
│   └── project-knowledge.md               # Template for PROJECT-KNOWLEDGE.md output
├── reference/
│   ├── language-patterns.md               # Language-specific analysis patterns
│   └── scoring.md                         # Confidence scoring algorithm
├── examples/
│   ├── README.md                          # Overview
│   ├── sample-report.md                   # Example REPORT output
│   └── confidence-scoring.md              # Real-world scoring examples
└── skills/
    └── planner-rules/SKILL.md, coder-rules/SKILL.md  # Skills that use project-researcher
```

---

## CHECKLIST FOR ORCHESTRATOR

- [ ] Directory exists and is accessible (VALIDATE)
- [ ] Mode detected (CREATE/AUGMENT/UPDATE) (VALIDATE)
- [ ] Monorepo/module structure detected (DISCOVER)
- [ ] Language detected with ≥0.3 confidence (DETECT)
- [ ] Symbol graph built with repo-map (GRAPH)
- [ ] Architecture pattern identified with evidence (ANALYZE)
- [ ] Dependency graph built with metrics (ANALYZE)
- [ ] Domain entities mapped (ANALYZE)
- [ ] State contract validated at each subagent call
- [ ] CRITIQUE gate passed
- [ ] All artifacts generated and valid
- [ ] VERIFY gate passed
- [ ] Report includes confidence scores and topology

---

## NEXT STEPS FOR IMPLEMENTATION/USAGE

1. **To trigger:** User mentions "bootstrap claude" or calls `project-researcher .` explicitly
2. **To customize:** Modify orchestration.md for different parallelism strategies
3. **To extend:** Add new subagents following the protocol in orchestration.md
4. **To debug:** Check deps/edge-cases.md for known limitations; enable verbose logging in subagents
