# Claude Kit Skills Research — Complete Inventory

**Date:** 2026-03-29
**Scope:** All skill packages in `.claude/skills/`
**Total Packages:** 6 skill packages with 36 supporting files

---

## Skill Package Inventory

### 1. workflow-protocols (Orchestration & State Management)

**Purpose:** Orchestration protocols for `/workflow` pipeline. Load at startup (step 0.1), then event-driven per trigger.

**When Loaded:**
- STARTUP: Phase 0.1 of /workflow (core deps: autonomy.md, orchestration-core.md)
- ON_DEMAND: Event-triggered loading per phase completions

**Files in Package:** 8

| File | Lines | Purpose |
|------|-------|---------|
| SKILL.md | 98 | Main entry point: protocol overview, loading strategy, event triggers |
| autonomy.md | 26 | 3 execution modes (INTERACTIVE/AUTONOMOUS/RESUME), stop/continue conditions |
| orchestration-core.md | 143 | Pipeline phases (0.5→1→2→3→4→5), loop limits (3x per cycle), session recovery |
| handoff-protocol.md | 112 | 4 phase-to-phase contracts + code-researcher tool contract, narrative casting |
| checkpoint-protocol.md | 124 | State persistence format (12 YAML fields), recovery, mid-phase auto-save for L/XL |
| re-routing.md | 39 | Self-correcting: downgrade/upgrade route on mismatch, tracking, learning |
| pipeline-metrics.md | ~50 | Completion phase metrics: format, storage (JSONL), analysis, anomaly detection |
| examples-troubleshooting.md | ~60 | Execution examples, common mistakes, troubleshooting scenarios |
| agent-memory-protocol.md | 62 | Memory behavior for all `memory: project` agents (code-researcher, code-reviewer, plan-reviewer) |

**Components Using It:**
- `/workflow` command (orchestrator) — primary consumer
- All phases (0.5, 1, 2, 3, 4, 5) reference protocols per phase

**Key Protocols Defined:**

1. **Handoff Protocol (CRITICAL):** Every phase MUST create handoff payload for next phase
   - planner → plan-review: artifact + metadata + key_decisions + known_risks
   - plan-review → coder: artifact + verdict + issues_summary
   - coder → code-review: branch + parts_implemented + verify_status + deviations
   - code-review → completion: verdict + issues (BLOCKER/MAJOR/MINOR/NIT)
   - code-researcher (tool): research_question → structured summary ≤2000 tokens

2. **Checkpoint Protocol (HIGH):** Proactive state saving in `.claude/workflow-state/{feature}-checkpoint.yaml`
   - Format: 12 fields (feature, phase_completed, iteration counters, verdict, etc.)
   - Auto-save for L/XL: cron job saves parts_completed during Phase 3
   - Recovery: mid-phase resume with completed Parts skipped

3. **Re-routing (MEDIUM):** Self-correcting on complexity mismatch
   - Triggers: plan-review finds wrong complexity → upgrade/downgrade
   - Tracks: original_route, new_route, reason, phase
   - Data: captured in checkpoint + pipeline-metrics for learning

4. **Agent Memory Protocol:** Shared behavior for code-researcher, code-reviewer, plan-reviewer
   - Startup: read MEMORY.md from `.claude/agent-memory/{agent_name}/`
   - Completion: save patterns (NON_CRITICAL — skip if budget exhausted)
   - Freshness: stale (30-90d warn), expired (>90d suggest delete)

5. **Autonomy Modes:** 3 execution styles with stop/continue gates
   - INTERACTIVE (default): ask at checkpoints
   - AUTONOMOUS (--auto): proceed through all phases
   - RESUME: continue from checkpoint after interruption

6. **Orchestration Core:** Pipeline state machine
   - Phases: 0.5 (classify) → 1 (plan) → 2 (review) → 3 (code) → 4 (review) → 5 (complete)
   - Loop limits: plan_review max 3x, code_review max 3x, total max 12 phases
   - Failure threshold: 3 iterations max per cycle → STOP + request intervention

**Dependencies:**
- rules/architecture.md (import matrix validation)
- rules/go-conventions.md (error handling, concurrency)
- rules/testing.md (test patterns)
- Templates: plan-template.md, commit message format

**Key Design Decisions:**
- Checkpoint-first recovery: YAML files at `.claude/workflow-state/` for instant resume
- Handoff-first: Every phase transition requires structured payload (MetaGPT pattern)
- Event-driven loading: Core deps at startup, others on-demand per trigger (performance optimization)
- Non-critical MCPs: All workflow tools (ST, Context7, PostgreSQL) warn on failure, continue

---

### 2. planner-rules (Task Analysis & Planning)

**Purpose:** Task analysis and planning rules for `/planner` command. Load at startup (step 0) or Phase 1.

**When Loaded:**
- STARTUP: /planner startup (step 0)
- WORKFLOW: /workflow Phase 1 (planning phase)

**Files in Package:** 7

| File | Lines | Purpose |
|------|-------|---------|
| SKILL.md | 102 | Classification rules, complexity routing, research instructions, code completeness |
| task-analysis.md | ~120 | Full classification matrix: 7 task types × S/M/L/XL complexity, auto-escalation rules |
| data-flow.md | ~100 | Data origin/path analysis, layer placement rules (skip for S, load for M+) |
| sequential-thinking-guide.md | ~80 | When/how to use ST: complex trade-offs (3+ approaches), 4+ interacting parts, L/XL only |
| mcp-tools.md | 18 | Shared pattern (sync with coder-rules): Sequential Thinking, Context7, PostgreSQL + fallbacks |
| examples.md | ~80 | Good vs bad code examples: full function bodies required (RULE), incomplete snippets bad |
| checklist.md | ~60 | Self-verification at each planner phase: research, design, documentation |
| troubleshooting.md | ~80 | Common planner issues: incomplete code examples, skipped ST, scope creep |

**Components Using It:**
- `/planner` command (primary)
- `/workflow` Phase 1
- Task analysis gate (determines complexity routing)

**Task Classification (7 Types):**

| Type | Keywords | Typical Complexity | Route |
|------|----------|-------------------|-------|
| new_feature | add, create, implement, new endpoint | M-XL | standard→full |
| bug_fix | fix, bug, broken, not working | S-M | minimal→standard |
| refactoring | refactor, rewrite, extract, split | M-L | standard |
| config_change | config, parameter, environment variable | S | minimal |
| documentation | documentation, README, describe | S | minimal |
| performance | optimization, slow, N+1, cache | M-L | standard |
| integration | external service, API call, client | L-XL | full |

**Complexity Routing Matrix:**

| Complexity | Parts | Layers | Route | Sequential Thinking | Plan Review |
|------------|-------|--------|-------|---------------------|-------------|
| S | 1 | 1 | minimal | NOT needed | SKIP |
| M | 2-3 | 2 | standard | as needed | standard |
| L | 4-6 | 3+ | standard | RECOMMENDED | standard |
| XL | 7+ | 4+ | full | REQUIRED | standard |

**Auto-Escalation Rules:**
- plan-review finds more Parts than expected → upgrade complexity
- coder evaluate finds 3+ adjustments → upgrade + return to planner
- plan-review finds fewer Parts → downgrade complexity

**Critical Rule (RULE):** Code examples in plan MUST be FULL (complete function bodies with error handling, context propagation). Signatures-only examples are REJECTED.

**MCP Tools Pattern (shared with coder-rules):**
- Sequential Thinking: 3+ alternatives OR 4+ interacting parts
- Context7: External library API unclear (max 3 calls per question)
- PostgreSQL: Schema unclear, no migrations (READ-ONLY)
- Fallbacks: manual analysis, migrations, entity structs

**Code-Researcher Delegation:**
- S/M: use Grep/Glob directly
- L/XL: delegate to code-researcher agent via Task tool for multi-package research
- Research question format: specific question + focus areas + context (task type + complexity + need)

**Dependencies:**
- workflow-protocols (handoff format, complexity signals)
- code-researcher agent (Task tool for L/XL research)
- templates/plan-template.md

---

### 3. coder-rules (Implementation & Execution)

**Purpose:** Implementation rules for `/coder` command. Load at startup (step 0) or Phase 3.

**When Loaded:**
- STARTUP: /coder startup (step 0)
- WORKFLOW: /workflow Phase 3 (implementation phase)

**Files in Package:** 5

| File | Lines | Purpose |
|------|-------|---------|
| SKILL.md | 101 | 5 CRITICAL rules, evaluate protocol (PROCEED/REVISE/RETURN), dependency-ordered implementation |
| mcp-tools.md | 34 | Shared pattern (sync with planner-rules): Sequential Thinking, Context7, PostgreSQL + Context7 workflow |
| examples.md | ~80 | Bad/good code patterns: import matrix violations, domain purity, log+return, layer violations |
| checklist.md | ~60 | Self-verification at each coder phase: pre-code, mid-code, verify |
| troubleshooting.md | ~80 | Common coder issues: tests fail 3x, import violations, unused library without Context7 |

**Components Using It:**
- `/coder` command (primary)
- `/workflow` Phase 3
- Evaluate protocol gate (Phase 1.5 before implementation)

**5 CRITICAL Rules (Blockers):**

1. **RULE_1 — Plan Only:** Implement ONLY what's in approved plan. No improvements, no scope creep.
2. **RULE_2 — Import Matrix:** NEVER violate architecture rules (handler→service→repository→models).
3. **RULE_3 — Clean Domain:** NEVER add encoding/json tags to domain entities (tags belong in DTOs at handler layer).
4. **RULE_4 — No Log+Return:** NEVER log AND return error simultaneously (duplicate logs in chain).
5. **RULE_5 — Tests Pass:** Code NOT ready until tests pass (exit criteria, enforced by VERIFY phase).

**Evaluate Protocol (Phase 1.5):** CRITICAL validation before any code writing

| Decision | Action |
|----------|--------|
| PROCEED | Plan is implementable as-is → start implementation |
| REVISE | Minor gaps, fixable inline → note adjustments, proceed |
| RETURN | Major gaps or feasibility issues → return to plan-review with feedback |

Evaluate checks: feasibility, hidden complexities, edge cases, performance, dependencies.
Output: `.claude/prompts/{feature}-evaluate.md`
Budget: Exploration budget per phase (see CLAUDE.md error table) — when exhausted, decide with available info.

**Implementation Order (Dependency-First):**
1. Data access (repository/models layer)
2. Models (domain entities)
3. Domain/service (business logic)
4. Handler/API (HTTP layer)
5. Tests (separate part UNLESS TDD skill active)
6. Wiring (dependency injection, integration)

**Verification Step (Phase 3.4):**
```
go vet ./... && make fmt && make lint && make test
```
If fails 3x → STOP, request manual help (integration with Sequential Thinking).

**Context7 Requirement:**
- ALWAYS use Context7 for external dependencies (new library, unfamiliar API)
- Pattern: resolve-library-id → query-docs (2-step workflow)
- Common: integration tests, authentication libraries, HTTP clients

**Error Handling Pattern (Go-specific):**
- Wrap errors with `fmt.Errorf("context: %w", err)`
- Return with context, never log+return (RULE_4)
- Error propagation through layers: repository → service → handler

**Dependencies:**
- workflow-protocols (handoff format)
- CLAUDE.md (VERIFY command, language profile)
- rules/architecture.md (import matrix)
- code-researcher agent (Task tool for evaluate phase on L/XL)
- tdd-go skill (if plan contains "## TDD" section)

**TDD Integration:**
- Check for `## TDD` heading in plan at startup
- If present: load tdd-go skill, apply RED-GREEN-REFACTOR cycles per Part
- Tests are woven into implementation (NOT a separate part)

---

### 4. plan-review-rules (Plan Validation)

**Purpose:** Review standards for plan-reviewer agent. Auto-loaded via agent frontmatter.

**When Loaded:**
- AGENT STARTUP: plan-reviewer agent Phase 2 (auto-loaded via frontmatter)
- WORKFLOW: /workflow Phase 2 (plan review phase)

**Files in Package:** 5

| File | Lines | Purpose |
|------|-------|---------|
| SKILL.md | 87 | Severity classification, decision matrix (APPROVED/NEEDS_CHANGES/REJECTED), auto-escalation |
| required-sections.md | ~100 | Plan structure validation: Context, Scope (IN/OUT), Dependencies, Parts with code examples, Acceptance criteria, Testing plan |
| architecture-checks.md | ~120 | Import matrix compliance, domain purity, layer violations, security checks, concurrency patterns |
| checklist.md | ~60 | Self-verification at each review phase: structure, architecture, code examples |
| troubleshooting.md | ~80 | Common review issues: import violations missed, security as MAJOR (not BLOCKER), missing ST |

**Components Using It:**
- plan-reviewer agent (Phase 2)
- /workflow Phase 2

**Severity Classification (4 Levels):**

| Level | Blocks Approval? | Examples |
|-------|-----------------|----------|
| BLOCKER | YES | Architecture/security violation, import matrix violation |
| MAJOR | YES | Error handling issues, missing critical sections, 5+ MINOR escalated |
| MINOR | NO | Code style, naming, small documentation gaps |
| NIT | NO | Stylistic preference, trivial improvements |

**Decision Matrix (Final Verdict):**

| Verdict | BLOCKER | MAJOR | Min Issues |
|---------|---------|-------|-----------|
| APPROVED | 0 | 0 | (any MINOR/NIT OK) |
| NEEDS_CHANGES | 0 | 1+ | OR 3+ MINOR |
| REJECTED | 1+ | — | — |

**Auto-Escalation Rules:**
- 5+ MINOR in same Part → escalate to MAJOR
- Security issue (ANY severity) → ALWAYS BLOCKER
- Import matrix violation → ALWAYS BLOCKER

**Required Plan Sections (Validation):**
1. **Context:** Task background, why it matters
2. **Scope (IN/OUT):** What's included, what's not, why boundaries
3. **Dependencies:** External services, libraries, database changes
4. **Parts (Code examples required):** Each Part must have full function bodies with error handling
5. **Acceptance Criteria:** How to verify implementation success
6. **Testing Plan:** Unit/integration test approach

**Architecture Checks (Multi-Layer):**
- Layer imports: models (stdlib only) → service (imports repo + models) → handler (imports service)
- Domain purity: no encoding/json tags in entities
- Error handling: proper wrapping (fmt.Errorf %w), no log+return
- Protected files: no edits to *_gen.go, */mocks/*.go

**Security Checklist (API Endpoints):**
- SQL injection: parameterized queries (prepared statements)
- Authentication/authorization: token validation, scopes
- Input validation: no trusting user input
- Secrets: no hardcoded credentials

**Sequential Thinking Requirement:**
- Complex plans (4+ Parts, 3+ layers, 3+ alternatives) MUST use ST
- Missing ST for complex plan = MAJOR issue

**Dependencies:**
- workflow-protocols (handoff format, verdict mapping)
- rules/architecture.md (import matrix)
- templates/plan-template.md (structure reference)

---

### 5. code-review-rules (Code Review & Quality Gate)

**Purpose:** Review standards for code-reviewer agent. Auto-loaded via agent frontmatter.

**When Loaded:**
- AGENT STARTUP: code-reviewer agent Phase 4 (auto-loaded via frontmatter)
- WORKFLOW: /workflow Phase 4 (code review phase)

**Files in Package:** 5

| File | Lines | Purpose |
|------|-------|---------|
| SKILL.md | 91 | Severity classification, decision matrix (APPROVED/APPROVED_WITH_COMMENTS/CHANGES_REQUESTED), auto-escalation |
| examples.md | ~100 | Bad/good code patterns with grep search patterns for automated checks: log+return, import violations, error wrapping |
| security-checklist.md | ~100 | OWASP checks: SQL injection, XSS (if frontend), secrets, token leaks, CORS, rate limiting |
| checklist.md | ~60 | Self-verification at each review phase: quick checks (lint/test), scope assessment, concern areas |
| troubleshooting.md | ~80 | Common review issues: approved with blockers, log+return not caught, ST skipped on large diff |

**Components Using It:**
- code-reviewer agent (Phase 4)
- /workflow Phase 4

**Severity Classification (identical to plan-review):**

| Level | Blocks Approval? | Examples |
|-------|-----------------|----------|
| BLOCKER | YES | Architecture/security violation, import matrix violation |
| MAJOR | YES | Error handling issues, missing test coverage, 5+ MINOR escalated |
| MINOR | NO | Code style, naming, documentation |
| NIT | NO | Trivial preference |

**Decision Matrix (Final Verdict):**

| Verdict | BLOCKER | MAJOR | Details |
|---------|---------|-------|---------|
| APPROVED | 0 | 0 | Clean merge (no issues) |
| APPROVED_WITH_COMMENTS | 0 | 0 | Merge with notes (has MINOR/NIT) |
| CHANGES_REQUESTED | 1+ | 1+ | Return to coder OR 3+ MINOR |

**Review Process (4 Steps):**

1. **Quick Check (BLOCKING):**
   - If coder handoff has verify_status=PASS → trust it, skip re-run
   - Otherwise: run `make lint` and `make test`
   - If EITHER fails → STOP, return to coder (don't proceed to review)

2. **Scope Assessment:**
   - Run `git diff $BASE...HEAD` (detect base branch first)
   - Assess: files changed, lines changed, layers affected
   - If >100 lines OR >5 files OR 3+ layers → use Sequential Thinking

3. **Concern Areas (Grep-Based Checks):**
   - **Architecture:** import matrix compliance (grep layer imports)
   - **Error Handling:** log+return pattern (grep 'log\.(Error|Warn|Info).*\n.*return')
   - **Security:** hardcoded secrets (grep 'password|token|api.key')
   - **Tests:** new code has tests (check test coverage)

4. **Decision & Verdict:**
   - Apply Decision Matrix + Auto-Escalation rules
   - CRITICAL: NEVER approve with BLOCKER issues
   - Form handoff for completion phase

**Auto-Escalation (identical to plan-review):**
- 5+ MINOR in same file → escalate to MAJOR
- Security issue (ANY severity) → ALWAYS BLOCKER
- Import matrix violation → ALWAYS BLOCKER

**Automated Grep Patterns (examples.md):**
```bash
# Log AND return (BLOCKER)
grep -r 'log\.\(Error\|Warn\|Info\).*\n.*return' internal/

# Import violations (BLOCKER)
grep -r 'import.*repository' internal/handler/

# Missing error context (MAJOR)
grep -r 'return err$' internal/
```

**Security Checklist (M+ complexity only, SKIP for S):**
- SQL injection: parameterized queries
- XSS prevention (if frontend): input sanitization, output encoding
- Secrets: no hardcoded credentials, use environment/vault
- Token leaks: no logging sensitive data
- CORS: proper origin/method restrictions
- Rate limiting: API endpoints protected
- Dependency vulnerabilities: no known-bad versions

**Sequential Thinking Requirement:**
- Large changes (100+ lines, 5+ files, 3+ layers) MUST use ST
- Skipping ST for large diff = MAJOR issue

**Dependencies:**
- workflow-protocols (handoff format, verdict mapping)
- rules/architecture.md (import matrix)
- rules/go-conventions.md (error handling patterns)
- rules/testing.md (test coverage expectations)

---

### 6. tdd-go (Test-Driven Development for Go)

**Purpose:** Test-Driven Development workflow for Go backend. Red-Green-Refactor cycle.

**When Loaded:**
- CONDITIONAL: /coder at startup IF plan contains `## TDD` section
- NOT loaded: If no TDD section in plan, standard coder workflow applies

**Files in Package:** 3

| File | Lines | Purpose |
|------|-------|---------|
| SKILL.md | 153 | RED-GREEN-REFACTOR cycle, integration with coder Parts, rules, common issues |
| references/patterns.md | ~100 | Incremental table-driven TDD, test helpers, factory pattern, context helpers |
| references/examples.md | ~80 | Full handler/service/repository TDD workflows, benchmark TDD examples |

**Components Using It:**
- /coder command (conditional — only if TDD marker in plan)
- Triggered by: plan contains `## TDD` heading

**Red-Green-Refactor Cycle (Per Behavior Unit):**

### RED Phase
- Write ONE failing test describing expected behavior
- Run `go test ./path/to/package/...` → MUST FAIL
- If passes → test doesn't test new behavior, revise

```go
// EXAMPLE: RED phase
func TestCreateUser_ValidInput_ReturnsUser(t *testing.T) {
    svc := NewUserService(mockRepo)
    user, err := svc.Create(ctx, CreateUserInput{Name: "Alice", Email: "alice@example.com"})
    require.NoError(t, err)
    assert.Equal(t, "Alice", user.Name)
    assert.NotEmpty(t, user.ID)
}
// MUST fail — Create() doesn't exist or returns wrong result
```

### GREEN Phase
- Write MINIMUM code to make failing test pass
- Rules: NO extra functionality, NO optimization, NO refactoring
- Hard-coded values acceptable if they pass the test
- Run `go test ./path/to/package/...` → MUST PASS

### REFACTOR Phase
- With tests green, improve code quality
- Remove duplication, improve naming, extract helpers
- Run `go test ./path/to/package/...` → MUST STILL PASS
- Then return to RED for next behavior

**Integration with Coder Parts:**

Standard coder order (without TDD):
```
Part 1: Repository
Part 2: Models
Part 3: Domain/Service
Part 4: Handler/API
Part 5: Tests ← separate final part
Part 6: Wiring
```

TDD-mode order (with tdd-go skill):
```
Part 1: Repository [RED → GREEN → REFACTOR cycles per behavior]
Part 2: Models [tests woven in]
Part 3: Domain/Service [tests woven in]
Part 4: Handler/API [tests woven in]
Part 5: Wiring + Integration Tests [no separate "tests" part]
```

Key difference: Tests are NOT a separate part — they're woven into each Part via cycles.

**TDD Rules:**
- NEVER write production code without failing test (RED must precede GREEN)
- ONE test at a time — don't batch multiple test cases
- Run tests after EVERY step (RED: must fail, GREEN: must pass, REFACTOR: must pass)
- Table-driven tests: add ONE case at a time (not all upfront)
- Test names: `Test{Function}_{Scenario}_{Expected}`
- Use testify/assert (non-fatal), testify/require (fatal checks)
- Mock interfaces, not implementations
- Race detector: `go test -race ./path/...` if package has concurrency

**Complex Logic in TDD (3+ conditions, state machines):**
1. RED: Write failing test exercising complex scenario
2. ST (Sequential Thinking): Between RED and GREEN, design implementation strategy
3. GREEN: Write minimal implementation per ST analysis
4. REFACTOR: Clean up

ST is used INSIDE the GREEN phase — after test is written but before implementation.

**Relationship with coder-rules RULE_5:**
- RULE_5 ("Tests Pass"): exit gate — code NOT ready until tests pass
- TDD rule ("Tests First"): process gate — write test BEFORE production code
- Orthogonal: RULE_5 checks end state, TDD controls workflow order
- Both active simultaneously without conflict

**Table-Driven TDD Pattern (Incremental):**

Cycle 1: RED
```go
tests := []struct {
    name    string
    input   string
    want    int
    wantErr bool
}{
    {name: "simple number", input: "25", want: 25, wantErr: false},
}
// GREEN: implement ParseAge with strconv.Atoi
// REFACTOR: clean up
```

Cycle 2: RED
```go
// Add to tests slice:
{name: "negative", input: "-5", want: 0, wantErr: true},
// GREEN: add validation if age < 0 { return ErrInvalidAge }
```

Anti-pattern (BAD): All cases written upfront before any implementation.

**Test Helpers (Reduce Boilerplate):**

```go
func newTestUserService(t *testing.T) (*UserService, *mocks.UserRepository) {
    t.Helper()
    repo := mocks.NewUserRepository(t)
    svc := NewUserService(repo)
    return svc, repo
}

func testCtx(t *testing.T) context.Context {
    t.Helper()
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    t.Cleanup(cancel)
    return ctx
}
```

**Common TDD Issues:**

| Issue | Cause | Fix |
|-------|-------|-----|
| Test passes in RED (should fail) | Test doesn't cover new behavior | Verify test exercises NEW code path |
| Over-implementation in GREEN | Writing more than test requires | Check: any new code lacking test? Remove or add test first |
| Refactor breaks tests | Changed behavior, not structure | Revert — REFACTOR = structure only, not behavior |
| Multiple failing tests at once | Wrote tests before implementing | Comment out all but one, implement → pass → uncomment next |
| All table cases upfront | Batch all cases before code | Add ONE case at a time, use t.Skip() for planned cases |

**Dependencies:**
- coder-rules (RULE_5, evaluate protocol)
- rules/testing.md (test patterns, concurrency, race detector)
- stdlib: testing, testify (assert/require)

---

## Cross-Skill Dependency Map

```
workflow-protocols
├─ autonomy (execution modes, stop/continue)
├─ orchestration-core (pipeline phases, loop limits)
├─ handoff-protocol (phase contracts)
├─ checkpoint-protocol (state recovery)
├─ re-routing (complexity mismatch)
├─ pipeline-metrics (completion tracking)
├─ agent-memory-protocol (shared agent memory)
└─ examples-troubleshooting

planner-rules (Phase 1)
├─ task-analysis (classification, routing)
├─ data-flow (layer placement)
├─ sequential-thinking-guide (when/how to use ST)
├─ mcp-tools (ST, Context7, PostgreSQL)
├─ examples (full code completeness)
├─ checklist (self-verification)
├─ troubleshooting
└─ code-researcher agent (Task tool, L/XL research)

plan-review-rules (Phase 2 - agent)
├─ required-sections (structure validation)
├─ architecture-checks (import matrix, domain purity)
├─ checklist (review phases)
├─ troubleshooting
└─ templates/plan-template.md

coder-rules (Phase 3)
├─ mcp-tools (ST, Context7, PostgreSQL)
├─ examples (bad/good patterns)
├─ checklist (phases)
├─ troubleshooting
├─ rules/architecture.md (import matrix)
├─ rules/go-conventions.md (error handling)
├─ tdd-go skill (conditional: if ## TDD section)
└─ code-researcher agent (Task tool, evaluate phase)

code-review-rules (Phase 4 - agent)
├─ examples (grep patterns, bad/good)
├─ security-checklist (OWASP)
├─ checklist (phases)
├─ troubleshooting
└─ rules/architecture.md (import matrix)

tdd-go (Conditional - coder trigger)
├─ references/patterns (table-driven, helpers)
├─ references/examples (workflows)
└─ integrated with coder Part implementation order
```

---

## Command/Agent Routing to Skills

| Command/Agent | Phase | Skill Loaded | Trigger |
|---------------|-------|--------------|---------|
| /workflow | 0.1 | workflow-protocols | Startup (autonomy, orchestration-core) |
| /workflow | 0.5 | planner-rules | Task-analysis phase |
| /planner | 1 | planner-rules | Command startup |
| plan-reviewer (agent) | 2 | plan-review-rules | Agent startup (frontmatter) |
| /coder | 3 | coder-rules | Command startup |
| /coder | 1.5 | coder-rules | Evaluate protocol |
| /coder | 3 | tdd-go | Conditional: `## TDD` in plan |
| code-reviewer (agent) | 4 | code-review-rules | Agent startup (frontmatter) |
| /workflow | 5 | workflow-protocols | Completion (pipeline-metrics) |

---

## Key Loading Patterns

### 1. Event-Driven (workflow-protocols)
**Strategy:** Load only what's needed per event
- Startup: autonomy.md, orchestration-core.md
- Phase completion: checkpoint-protocol.md
- Handoff formation: handoff-protocol.md
- Mismatch signal: re-routing.md
- End of pipeline: pipeline-metrics.md

**Benefit:** Reduces upfront context load for simple tasks

### 2. Skill-First (planner-rules, coder-rules)
**Strategy:** Load entire skill package at command startup
- /planner: load all of planner-rules (task-analysis, ST guide, MCP tools, examples, checklist)
- /coder: load all of coder-rules (5 CRITICAL rules, evaluate protocol, MCP tools, examples, checklist)

**Benefit:** Consistent context throughout command execution

### 3. Agent-Embedded (plan-review-rules, code-review-rules)
**Strategy:** Load via agent frontmatter auto-loader
- plan-reviewer agent: auto-load plan-review-rules on startup
- code-reviewer agent: auto-load code-review-rules on startup

**Benefit:** Clean context isolation — agents see only review-specific rules

### 4. Conditional (tdd-go)
**Strategy:** Check for trigger in plan file
- /coder startup: read `.claude/prompts/{feature}.md`
- If contains `## TDD` heading → load tdd-go skill
- Otherwise → skip, use standard coder workflow

**Benefit:** Minimal context for non-TDD tasks, full skill when explicitly requested

---

## Summary

**6 skill packages, 36 files, 5 core protocols:**

1. **workflow-protocols** — Orchestration, state management, handoff contracts, recovery, re-routing
2. **planner-rules** — Task classification, complexity routing, code completeness, research delegation
3. **plan-review-rules** — Plan structure validation, architecture compliance, severity classification
4. **coder-rules** — 5 CRITICAL rules, evaluate protocol, implementation order, context7 workflow
5. **code-review-rules** — Code quality gate, severity classification, security checklist, grep patterns
6. **tdd-go** — Test-first workflow, RED-GREEN-REFACTOR cycles, integration with coder Parts

**Key Design Principles:**
- Typed handoffs between every phase (MetaGPT pattern)
- Severity-based decision making (BLOCKER/MAJOR/MINOR/NIT)
- Non-critical tools (ST, Context7, PostgreSQL) warn + continue on failure
- Event-driven loading for orchestration, skill-first for commands, agent-embedded for review
- Memory-backed (agent memory for patterns, checkpoints for state recovery)
- Loop limits: max 3x per cycle (plan-review and code-review), max 12 total phases
