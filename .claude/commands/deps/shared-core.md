# Shared Core — Compact Reference

Consolidated reference for all shared patterns. Commands reference specific sections via SEE links.

---

## MCP Tools

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

---

## Autonomy

**Modes:**
- INTERACTIVE (default): Ask at checkpoints
- AUTONOMOUS (--auto): Execute all phases without asking
- RESUME: Continue from last checkpoint (session interrupted)
- MINIMAL (--minimal): Minimal research, only critical checks

**Stop conditions:**

| Condition | Action |
|-----------|--------|
| FATAL_ERROR (plan/file not found, critical dep missing) | Stop immediately |
| USER_INTERVENTION (scope unclear, multiple approaches, user says stop) | Stop, wait for user |
| TOOL_UNAVAILABLE (MCP unavailable) | Warn, adapt, continue |
| FAILURE_THRESHOLD (tests/lint fail 3x) | Stop, request manual fix |

**Continue conditions (autonomous mode):**

| Condition | Action |
|-----------|--------|
| Phase completed | → next phase |
| Auto-fixable (lint fail → FMT) | Fix → retry |
| Non-critical tool unavailable | Warn → continue |

---

## Beads Integration

**Core commands:**
```
bd show <id>       — view task details
bd update <id> --status=in_progress  — claim task
bd ready           — show ready issues (no blockers)
bd close <id>      — close issue (NEVER auto-close, remind user)
bd sync            — sync to remote (MANDATORY at workflow end)
bd dep add <A> <B> — A depends on B (B blocks A)
bd create --title="..." --type=task|bug|feature --priority=0-4
bd blocked          — show blocked issues
bd stats            — open/closed/blocked counts
bd doctor           — check sync, hooks, issues
```

**Priority values:** 0=Critical, 1=High, 2=Medium (default), 3=Low, 4=Backlog.

**Bulk creation:** For many issues — spawn parallel Task subagents (more efficient than sequential bd create).

**Integration by command:**

| Command | Start | End |
|---------|-------|-----|
| /planner | bd show (if beads task), check deps | No beads action |
| /coder | Task already claimed | No auto-close (wait for review) |
| /plan-review | No beads action | No beads action |
| /code-review | No beads action | If APPROVED → remind bd close |
| /workflow | bd show + bd update in_progress | bd sync (MANDATORY) + remind bd close |

**Rule:** Beads is NON_CRITICAL. If `bd` unavailable → warn, skip beads phases, continue core workflow.

---

## Error Handling

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
| PROJECT-KNOWLEDGE.md missing | NON_CRITICAL | Heuristic fallback (SEE: #project-knowledge) |
| Git repo issues | WARNING | Continue (may skip commit phase) |
| Tests fail 3x | STOP_AND_WAIT | Show errors, request manual fix |
| Lint fail 3x | STOP_AND_WAIT | Show issues, request decision (manual fix / nolint / config) |
| Import violation | STOP_AND_FIX | Fix before proceeding |
| Scope unclear after 2x clarification | STOP_AND_WAIT | Wait for clear requirements |
| User not responding | STOP_AND_WAIT | Wait, do NOT proceed with assumptions |

---

## Review Verdict
# MOVED → deps/shared-review.md#review-verdict
# Loaded by: plan-review, code-review. Referenced from: review-checklist.md.

---

## Project Knowledge

**File:** PROJECT-KNOWLEDGE.md (project root or .claude/)
**Status:** NON_CRITICAL — workflow continues without it, but with reduced precision.
**Created by:** Manual analysis or /planner onboarding phase.

language_profile:
  description: "Language-specific patterns. Agents use aliases (VERIFY, FMT, LINT, TEST, EXT, etc.) from PK or Go defaults below."

  commands:
    format: "make fmt"            # alias: FMT
    lint: "make lint"             # alias: LINT
    test: "make test"             # alias: TEST
    verify: "make fmt && make lint && make test"  # alias: VERIFY

  error_pattern:
    wrap: "%w"                    # alias: ERROR_WRAP
    example: 'fmt.Errorf("context: %w", err)'
    anti_patterns: ["log AND return same error"]

  domain_rules:
    prohibited_annotations: ["encoding/json tags in domain entities"]  # alias: DOMAIN_PROHIBIT
    note: "Domain entities must be pure — no serialization annotations. Tags belong in DTOs."

  file_patterns:
    source_ext: ".go"             # alias: EXT
    generated: ["*_gen.go"]       # alias: GENERATED
    mocks: ["*/mocks/*.go"]       # alias: MOCKS
    source_glob: "internal/**/*.go"  # alias: SOURCE_GLOB

  config_convention:
    example_file: "config.yaml.example"    # alias: CONFIG_EXAMPLE
    docs_file: "README.md"                 # alias: CONFIG_DOCS
    note: "When config changes → update CONFIG_EXAMPLE + CONFIG_DOCS"

  concurrency:
    primitives: ["goroutines", "channels", "mutex", "sync primitives"]
    race_check: "go test -race"

fallback_protocol:
  step_1_check: "Read PROJECT-KNOWLEDGE.md from project root, then .claude/"
  step_2_if_missing:
    warn: "PROJECT-KNOWLEDGE.md not found. Using Go defaults from language_profile above."
    actions:
      import_matrix: "Infer from project structure: ls internal/ (or src/) → identify layers → grep import patterns"
      layer_naming: "Detect via directory naming: controller|service|usecase|handler|repository|storage"
      layer_order: "Default: data-access → domain/models → business-logic → api/handler → tests → wiring"
      test_command: "Use language_profile.commands.test (Go default: make test)"
      error_pattern: "Use language_profile.error_pattern (Go default: wrap with %w, no log+return)"
      domain_structure: "Infer: ls internal/*/models/ (or src/*/models/)"
    language_profile: "Use Go defaults from schema above. Override in PROJECT-KNOWLEDGE.md for non-Go projects."

heuristic_discovery:
  description: "When PROJECT-KNOWLEDGE.md is missing, agent SHOULD attempt auto-discovery"
  commands:
    - "ls -la internal/ (or src/)"
    - "head -20 Makefile (or package.json, pyproject.toml, Cargo.toml)"
    - "grep -r 'import' internal/*/handler*/ | head -10"
    - "grep -r 'import' internal/*/service*/ | head -10"
  output: "Use discovered structure as runtime substitute. Note in handoff: 'PK missing, used heuristic discovery.'"

save_recommendation:
  when: "Planner successfully discovers project structure via heuristic"
  action: "Recommend user: 'Consider creating PROJECT-KNOWLEDGE.md to improve precision. Run /planner --analyze to generate.'"

---

## Pipeline & Phases
# MOVED → deps/workflow/orchestration-core.md#pipeline--phases
# Loaded by: workflow only

---

## Loop Limits
# MOVED → deps/workflow/orchestration-core.md#loop-limits
# Loaded by: workflow only

---

## Context Isolation

**Rule:** Review phases (plan-review, code-review) MUST run with clean context.

**Preferred:** Launch via Task tool (subagent) — reviewer does NOT see creation process.

**Fallback:** If same context — MUST re-read artifact from file, not rely on memory.

**Narrative casting:** Pass reviewer WHAT was done (key decisions, risks, focus areas) without HOW (debug sessions, rejected approaches, intermediate thoughts). Source: `handoff_output` from previous phase.

**What reviewer receives:**
- plan-review: `.claude/prompts/{feature}.md` + narrative context block
- code-review: `git diff master...HEAD` + narrative context block

---

## Session Recovery
# MOVED → deps/workflow/orchestration-core.md#session-recovery
# Loaded by: workflow only
