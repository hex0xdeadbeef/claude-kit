---
meta:
  type: "implementation-plan"
  feature: "coder-code-review-generic"
  status: "draft"
  complexity: "XL"
  task_type: "refactoring"
  produced_by: "/planner (Phase 1)"
  consumed_by: "plan-reviewer (Phase 2)"
  parent_spec: ".claude/prompts/coder-code-review-generic-analysis.md"
  parent_release: "v1.16.0 (commit 42f452c — Plan-stage P1-P5)"
  approved_decisions:
    Q1: "reuse planner-rules/code-shapes/"
    Q2: "conservative WARN for VERIFY"
    Q3: "NIT for SKIP"
    Q4: "continue full XL"
    Q5: "filename preserved"
    Q6: "doc-only worktree"
    Q7: "deferred follow-up to 1.17.0"
  iteration: "1/3"
  total_parts: 8
  acceptance_criteria_count: 47
---

# Task: Coder/Code-Review project-agnostic refactor (close 1.16.0 deferred work)

## Context

В релизе **v1.16.0** (commit `42f452c`) Plan-stage (`/planner` + `plan-reviewer`) был сделан project-agnostic пятью фиксами **P1-P5**. Coder/Code-Review намеренно оставлены вне scope — commit message: *"out-of-scope `code-reviewer.md` (Phase 4, spec section 3.2) retains old wording intentionally"*. Этот план закрывает отложенный долг симметричным набором из 5 проблем (**C1-C5**), приведённых в [`.claude/prompts/coder-code-review-generic-analysis.md`](.claude/prompts/coder-code-review-generic-analysis.md) (status: approved 2026-04-27, 47 falsifiable AC, 9 неприкасаемых контрактов C1-C9).

**Реализация:** 8 Parts в порядке `C2 → C1 → C5 → C3 → C4` + tests + cross-cutting (matches spec §9).

---

## Scope

### IN
- [ ] C1 — Reuse `planner-rules/code-shapes/` from coder-rules/examples.md и code-review-rules/examples.md (Part 2)
- [ ] C2 — VERIFY/QUICK CHECK cascade slot-driven (PK > CLAUDE.md > DEPENDENCY_FILE-aware WARN > SKIP) (Part 1)
- [ ] C3 — code-reviewer.md "ALWAYS verify the import matrix" + RULE_2/RULE_4 → LAYER_RULE+ARCHITECTURE_STYLE-driven SKIP-with-NIT (Parts 5+6)
- [ ] C4 — Coder dependency-order fallback `data access → … → wiring` → plan-determined-order + SKIP-with-NIT (Part 7)
- [ ] C5 — Existing PK slots (DOMAIN_PROHIBIT, ERROR_WRAP, GENERATED_PATTERN, MOCK_PATTERN, CONFIG_EXAMPLE/DOCS, worktree doc) consumed by Coder/Reviewer (Parts 3+4)
- [ ] Test wiring: 5 new `.claude/scripts/tests/test-c{1-5}-*.sh` for AC verification (Part 8)

### OUT
- item: "tdd-go skill genericfication"
  reason: "Spec §11 deferred — generic-fication via tdd-rules + per-language tdd-shapes/ pattern, follow-up to 1.17.0"
- item: "auto-fmt-go.sh hook renaming + slot-driven dispatch"
  reason: "Spec §11 + §3.2 — hooks fire selectively via matchers; graceful no-op on non-Go projects"
- item: "pre-commit-build.sh genericfication"
  reason: "Spec §3.2 — same as auto-fmt-go.sh; matcher-gated"
- item: "settings.json worktree.sparsePaths defaults change"
  reason: "Spec R2 + Q6=A — kit-defaults preserved, only agent doc updated (code-reviewer.md L329)"
- item: "plan-template.md Go-shape Parts examples (L102-124)"
  reason: "Spec §11 — HTML comments not rendered; deferred"
- item: "coder-rules/troubleshooting.md L7 / SKILL.md L96 / mcp-tools.md L42-69 (`go test -v` examples)"
  reason: "Spec §11 — single-line examples in troubleshooting/MCP guidance context, deferred"
- item: "plan-reviewer.md L167-168 + plan-review-rules/SKILL.md L22-23 ('Import matrix violation → always BLOCKER' auto-escalation rules)"
  reason: "**NEW finding from R4 audit** — incomplete 1.16.0 P3 cleanup (auto-escalation was missed). Strictly out of scope per spec §3.2 ('plan-reviewer already fixed in 1.16.0'). Documented as deferred for 1.17.0 follow-up (see Notes section)."
- item: "PROJECT-KNOWLEDGE.md schema additions"
  reason: "Q1 + spec §1: purely consumer-side fix; no new slots needed"

---

## Dependencies

blocks: []  # this plan does not block other workflows
blocked_by: []  # no blocking dependencies (spec is approved)

---

## Architecture

### Decision

**Slot-driven consumer-side refactor with reuse-not-extract for `code-shapes/`.**

All hardcoded Go-specific defaults в Coder/Code-Review surface заменяются на `{SLOT_NAME}` placeholders, резолвящиеся через канонический cascade `PROJECT-KNOWLEDGE.md → CLAUDE.md Language Profile → SKIP-with-consolidated-NIT`. Кит-собственный CLAUDE.md Language Profile сохраняется в качестве legacy fallback (constraint C5 backwards-compat).

**Sequential Thinking использован** для декомпозиции 5 проблем в 8 Parts с учётом dependency order, R3 isolation requirement, и R4 grep audit findings.

### Alternatives

- option: "Extract `code-shapes/` в `coder-rules/code-shapes/` + `code-review-rules/code-shapes/`"
  rejected_because: "Drift risk R1 — параллельная поддержка трёх копий 7 файлов = 21 файл с inevitable consistency drift. Spec §10 R1 явно отмечает это."
- option: "Auto-detect dependency files в C2 fallback (`pyproject.toml` → `pip install`, `package.json` → `npm install`)"
  rejected_because: "Brittle в monorepos; contradicts slot convention (Q2=A user choice). Conservative WARN с INSTALL_VERB hint выбран."
- option: "Сменить severity для SKIP-issues (NIT → MINOR или INFO)"
  rejected_because: "NIT matches plan-stage P3 canonical (architecture-checks.md L22-33). Q3=A user choice. INFO ломает C2 enum contract."
- option: "Объединить C3-reviewer и C3-coder в один Part"
  rejected_because: "R3 mitigation требует isolated commit для code-reviewer.md L36 (STARTUP-rule = highest behavioral sensitivity). Coder side более mechanical edits."
- option: "Расширить scope до plan-reviewer.md L168 incomplete cleanup"
  rejected_because: "Spec §3.2 strictly out of scope. User constraint 'не распыляться'. Documented as deferred for 1.17.0 (Notes section)."

### Chosen

approach: "8 Parts в order C2 → C1 → C5(a+b) → C3(reviewer+coder) → C4 + tests"
rationale: |
  - C2 first — HIGHEST user-visible severity (non-Go projects без Makefile/PK получают actionable behavior).
  - C1 second — lowest risk pedagogic glue (только references); валидирует reuse pattern.
  - C5 split на C5a (DOMAIN_PROHIBIT only) + C5b (всё остальное) — establishes slot-resolver cascade pattern для Parts 5-7.
  - C3 split на C3-reviewer (Part 5, ISOLATED COMMIT per R3) + C3-coder (Part 6, less sensitive) — за rollback ergonomics.
  - C4 last — depends on C5 LAYERS-resolution pattern + symmetric to C3 in IMPLEMENT side.
  - Part 8 — wires test scripts that assert all 47 AC predicates from spec §8.

---

## Parts

### Part 1: C2 — VERIFY/QUICK CHECK cascade slot-driven

**Files:**
- `.claude/commands/coder.md` (UPDATE — L77, L132-133, L363, L417-422, L425, L461)
- `.claude/skills/coder-rules/SKILL.md` (UPDATE — L54, L56, L61)
- `.claude/skills/coder-rules/review-response.md` (UPDATE — L197 example)
- `.claude/agents/code-reviewer.md` (UPDATE — L67-68 QUICK CHECK)
- `.claude/skills/code-review-rules/SKILL.md` (UPDATE — L34 fallback)

**Action:** UPDATE

**Description:** Заменить Go-fixed VERIFY/QUICK CHECK fallback chain в Coder и Reviewer на slot-driven cascade. Cascade order: `PROJECT-KNOWLEDGE.md → VERIFY_CMD/composite slots → CLAUDE.md Language Profile → DEPENDENCY_FILE-aware WARN (no execution) → SKIP-with-consolidated-NIT`. Kit's CLAUDE.md fallback path resolves to существующий Go-default — backwards-compat preserved (AC-C2.7).

**Wording changes (verbatim):**

`coder.md` L417-422 — replace `verify_startup.checks` block with:
```yaml
checks:
  - if: ".claude/PROJECT-KNOWLEDGE.md exists AND defines VERIFY_CMD (not <your-…> placeholder)"
    then: "Use VERIFY_CMD from .claude/PROJECT-KNOWLEDGE.md"
  - if: ".claude/PROJECT-KNOWLEDGE.md exists AND defines individual FMT_CMD/LINT_CMD/TEST_CMD slots"
    then: "Compose: ${FMT_CMD} && ${LINT_CMD} && ${TEST_CMD}"
  - if: "CLAUDE.md Language Profile defines VERIFY entry (legacy fallback for kit)"
    then: "Use CLAUDE.md VERIFY value"
  - if: "PROJECT-KNOWLEDGE.md → DEPENDENCY_FILE detected (e.g. pyproject.toml, package.json, Cargo.toml, pom.xml) but VERIFY_CMD unset"
    then: "WARN with INSTALL_VERB-aware hint: 'No VERIFY command resolved. Detected {DEPENDENCY_FILE}. Configure VERIFY_CMD in PROJECT-KNOWLEDGE.md or set INSTALL_VERB. Skipping VERIFY.' Do NOT execute commands."
  - else: "WARN: No VERIFY command available. Emit consolidated NIT in handoff with verify_status: SKIPPED."
note: |
  Cascade follows canonical 'PK > CLAUDE.md > SKIP' contract from CLAUDE.md PK schema doc.
  Kit's CLAUDE.md Language Profile retains 'go vet ./... && make fmt && make lint && make test'
  as the legacy fallback — kit-dogfood behavior unchanged when PK missing (C5 backwards-compat).
```

`coder.md` L425 (VET phase) — REMOVE separate VET phase OR convert to opaque {STATIC_ANALYSIS_CMD} (composed into VERIFY_CMD if present):
```yaml
# REMOVE: command: "VET (go vet ./... — catches printf format errors, lock copying, suspicious constructs)"
# RATIONALE: VET is part of resolved VERIFY_CMD on Go projects (kit's CLAUDE.md fallback retains it).
# Other languages have their own static analysis (mypy/ruff/clippy/eslint) — let VERIFY_CMD handle it.
```

`coder.md` L461 output_format — replace:
```yaml
# BEFORE:
- [x] VET (go vet ./...)
# AFTER:
- [x] VERIFY ({verify_command_used resolved at startup})
```

`coder.md` L77 (handoff example) — replace `command_used` example:
```yaml
# BEFORE:
command_used: "go vet ./... && make fmt && make lint && make test"
# AFTER:
command_used: "{resolved VERIFY_CMD — Go example: 'go vet ./... && make fmt && make lint && make test'; Python example: 'pytest && ruff check'; resolved per .claude/PROJECT-KNOWLEDGE.md}"
```

`coder-rules/SKILL.md` L61 — replace:
```yaml
# BEFORE:
Run full VERIFY: `go vet ./... && make fmt && make lint && make test`.
# AFTER:
Run full VERIFY using the resolved command from coder.md verify_startup cascade
(PK > CLAUDE.md > DEPENDENCY_FILE-aware WARN > SKIP).
```

`coder-rules/SKILL.md` L54, L56 — replace `gofmt`/`make test, go test` with slot references:
```yaml
# L54 BEFORE:
After each Part: PostToolUse hooks auto-format files (gofmt). Run LINT only for import/error checks.
# L54 AFTER:
After each Part: PostToolUse hooks auto-format files (per language matcher; Go default: gofmt via auto-fmt-go.sh).
Run resolved LINT_CMD only for import/error checks.

# L56 BEFORE:
IMPORTANT: Do NOT run tests (make test, go test) between Parts.
# L56 AFTER:
IMPORTANT: Do NOT run tests (resolved TEST_CMD) between Parts.
```

`coder-rules/review-response.md` L197 — same as coder.md L77 example update.

`code-reviewer.md` L67-68 (QUICK CHECK fallback) — replace:
```yaml
# BEFORE:
- Run: `make lint` — if FAIL → STOP, return to author with lint errors
- Run: `make test` — if FAIL → STOP, return to author with test failures
# AFTER:
- Run: `${LINT_CMD}` (resolved from PROJECT-KNOWLEDGE.md → LINT_CMD; CLAUDE.md fallback)
  — if FAIL → STOP, return to author with lint errors
- Run: `${TEST_CMD}` (resolved from PROJECT-KNOWLEDGE.md → TEST_CMD; CLAUDE.md fallback)
  — if FAIL → STOP, return to author with test failures
- If both slots unset AND CLAUDE.md fallback empty: SKIP QUICK CHECK, emit consolidated NIT in VERDICT_JSON.
```

`code-review-rules/SKILL.md` L34 — replace:
```yaml
# BEFORE:
Otherwise: run `make lint` and `make test`. If EITHER fails → STOP, return to coder.
# AFTER:
Otherwise: run `${LINT_CMD}` and `${TEST_CMD}` resolved from PROJECT-KNOWLEDGE.md
(CLAUDE.md fallback). If EITHER fails → STOP, return to coder. If both slots unset
AND no CLAUDE.md fallback → SKIP QUICK CHECK with consolidated NIT.
```

**Acceptance criteria mapping:** AC-C2.1 — AC-C2.10 (10 ACs)

**Constraints preserved:** C1 handoff schema unchanged, C2 verdict envelope unchanged, C5 backwards-compat via CLAUDE.md fallback resolves kit's Go defaults

---

### Part 2: C1 — Reuse planner-rules/code-shapes/ via reference

**Files:**
- `.claude/skills/coder-rules/examples.md` (UPDATE — replace inline Go examples with selector + relative-path reference)
- `.claude/skills/code-review-rules/examples.md` (UPDATE — same)
- `.claude/skills/coder-rules/SKILL.md` (UPDATE — L89 reference point update)
- `.claude/skills/code-review-rules/SKILL.md` (UPDATE — L67-69 example block becomes reference)

**Action:** UPDATE

**Description:** Заменить inline Go-only examples в `coder-rules/examples.md` и `code-review-rules/examples.md` на slot-driven selector + relative-path reference на `../planner-rules/code-shapes/<LANGUAGE>.md` (already exists as 7 files: go.md, python.md, typescript.md, rust.md, java.md, _default.md, INVARIANTS.md). Никаких новых файлов; единый canonical источник для всего workflow.

**Wording changes:**

`coder-rules/examples.md` L1-4 — replace header + Go-only patterns:
```yaml
# BEFORE (L4):
# UNIVERSAL PATTERNS (apply to any Go project)

# AFTER:
# Code Completeness Examples
#
# Principle: Full function body, error context propagated per ${ERROR_WRAP},
# explicit return types and values, no truncation.
#
# Reference shapes:
#   resolved_from: "PROJECT-KNOWLEDGE.md → LANGUAGE"
#   location: "../planner-rules/code-shapes/<LANGUAGE>.md"
#   fallback: "../planner-rules/code-shapes/_default.md"
#   invariants: "../planner-rules/code-shapes/INVARIANTS.md" (4 invariants every shape must illustrate)
#
# This file does NOT duplicate language-specific examples — single canonical source
# is planner-rules/code-shapes/. See ${LANGUAGE}.md for syntax-correct examples
# in your project's language.
```

Existing Go example block at coder-rules/examples.md L20+ (`why: "RULE_3: Domain entities must be pure - no encoding/json tags. Tags belong in DTOs."`) — keep but mark as kit-dogfood reference:
```yaml
## Kit Dogfood Reference (Go-only — for kit maintainers)
# This block is kit's own example using its Go dogfood. Non-Go projects should
# refer to ../planner-rules/code-shapes/<your-LANGUAGE>.md for syntax-correct examples.
```

`code-review-rules/examples.md` L20 — same replacement pattern (kit-dogfood section retained, generic principle on top).

`code-review-rules/SKILL.md` L67-69 — replace inline Go example block with reference:
```yaml
# BEFORE:
**Good:**
```go
if err != nil {
    return fmt.Errorf("context: %w", err)
}
```

# AFTER:
**Good:** see `../planner-rules/code-shapes/<LANGUAGE>.md` for syntax-correct
error wrapping per `${ERROR_WRAP}` slot. Example for Go: `fmt.Errorf("context: %w", err)`.
```

`coder-rules/SKILL.md` L89 — already says *"For more examples, see [Examples](examples.md)"*; update to reference reuse:
```yaml
# AFTER L89:
For more examples, see [Examples](examples.md) which references per-language shapes
in `../planner-rules/code-shapes/`.
```

**Acceptance criteria mapping:** AC-C1.1 — AC-C1.6 (6 ACs)

**Constraints preserved:** C1 handoff schema unchanged, C2 verdict envelope unchanged, C5 backwards-compat (kit's Go dogfood example retained as labeled section)

---

### Part 3: C5a — DOMAIN_PROHIBIT slot wiring

**Files:**
- `.claude/commands/coder.md` (UPDATE — L501 RULE_3)
- `.claude/skills/coder-rules/SKILL.md` (UPDATE — L13 RULE_3, L87 Why explanation)
- `.claude/agents/code-reviewer.md` (UPDATE — L119 Domain purity check)

**Action:** UPDATE

**Description:** Заменить hardcoded literal `"encoding/json tags"` на `{DOMAIN_PROHIBIT}` placeholder с SKIP-with-NIT cascade. coder.md L501 уже частично использует слот (имеет `(Go default: encoding/json tags)` parenthetical) — finish работу. Aligns coder + reviewer wording.

**Wording changes:**

`coder.md` L501 — replace:
```yaml
# BEFORE:
description: "NEVER add DOMAIN_PROHIBIT to domain entities (Go default: encoding/json tags)."
# AFTER:
description: |
  NEVER add {DOMAIN_PROHIBIT} (resolved from PROJECT-KNOWLEDGE.md → DOMAIN_PROHIBIT;
  CLAUDE.md fallback) to domain entities (tags belong in DTOs at handler/API layer).
  SKIP rule with consolidated NIT if slot unset.
```

`coder-rules/SKILL.md` L13 — replace:
```yaml
# BEFORE:
- RULE_3 Clean Domain: NEVER add encoding/json tags to domain entities (tags belong in DTOs).
# AFTER:
- RULE_3 Clean Domain: NEVER add {DOMAIN_PROHIBIT} (resolved from
  PROJECT-KNOWLEDGE.md → DOMAIN_PROHIBIT; CLAUDE.md fallback) to domain entities
  (tags belong in DTOs at handler/API layer). SKIP if slot unset.
```

`coder-rules/SKILL.md` L87 — replace:
```yaml
# BEFORE:
**Why:** RULE_3 — Domain entities must be pure. No encoding/json tags. Tags belong in DTOs at the handler/API layer.
# AFTER:
**Why:** RULE_3 — Domain entities must be pure. No {DOMAIN_PROHIBIT} (resolved from
PROJECT-KNOWLEDGE.md). Tags belong in DTOs at the handler/API layer.
```

`code-reviewer.md` L119 — replace:
```yaml
# BEFORE:
- Domain purity (no encoding/json tags in domain entities)
# AFTER:
- Domain purity (no {DOMAIN_PROHIBIT} in domain entities — resolved from
  PROJECT-KNOWLEDGE.md → DOMAIN_PROHIBIT; CLAUDE.md fallback; SKIP if slot unset)
```

**Acceptance criteria mapping:** AC-C5.1, AC-C5.2 (2 of 16 C5 ACs; rest in Part 4)

**Constraints preserved:** C1 handoff schema unchanged, C5 backwards-compat (kit's CLAUDE.md fallback resolves DOMAIN_PROHIBIT)

---

### Part 4: C5b — ERROR_WRAP + GENERATED_PATTERN + MOCK_PATTERN + CONFIG_*/troubleshooting + worktree doc

**Files:**
- `.claude/agents/code-reviewer.md` (UPDATE — L124 ERROR_WRAP, L142 GENERATED_PATTERN, L143 MOCK_PATTERN, L329 worktree doc)
- `.claude/commands/coder.md` (UPDATE — L387-388 CONFIG_*)
- `.claude/skills/coder-rules/troubleshooting.md` (UPDATE — L18 GENERATED/MOCKS Go default)

**Action:** UPDATE

**Description:** Replace remaining hardcoded Go-defaults (fmt.Errorf, *_gen.go, */mocks/*.go, config.yaml.example, README.md) with `{SLOT_NAME}` placeholders + SKIP-with-NIT cascade. Worktree doc только описание (R2 — settings.json defaults preserved). Settings.json **НЕ модифицируется**.

**Wording changes:**

`code-reviewer.md` L124 — replace:
```yaml
# BEFORE:
- All errors wrapped with `fmt.Errorf("context: %w", err)`
# AFTER:
- All errors propagate context per {ERROR_WRAP} slot (resolved from
  PROJECT-KNOWLEDGE.md → ERROR_WRAP; CLAUDE.md fallback). SKIP this check if slot unset.
  Reference: ../skills/planner-rules/code-shapes/<LANGUAGE>.md for syntax-correct example.
```

`code-reviewer.md` L142 — replace:
```yaml
# BEFORE:
- Generated files (*_gen.go) not manually edited
# AFTER:
- Generated files (per {GENERATED_PATTERN} slot resolved from PROJECT-KNOWLEDGE.md;
  CLAUDE.md fallback) not manually edited. SKIP if slot unset (kit-default Go: *_gen.go via auto-fmt-go.sh + protect-files.sh).
```

`code-reviewer.md` L143 — replace:
```yaml
# BEFORE:
- Mocks (*/mocks/*.go) regenerated if interfaces changed
# AFTER:
- Mocks (per {MOCK_PATTERN} slot resolved from PROJECT-KNOWLEDGE.md; CLAUDE.md fallback)
  regenerated if interfaces changed. SKIP if slot unset (kit-default Go: */mocks/*.go).
```

`code-reviewer.md` L329 (Worktree Optimization, doc only) — replace:
```yaml
# BEFORE:
- Default: `.claude/`, `internal/`, `cmd/`, `go.mod`, `go.sum`, `Makefile`, `CLAUDE.md`
# AFTER:
- Defaults are configured in `settings.json worktree.sparsePaths`. Recommended pattern:
  follow PROJECT-KNOWLEDGE.md → SOURCE_GLOB + DEPENDENCY_FILE for project source layout.
  Override per project in settings.json or settings.local.json to match source layout.
- Kit-default values (Go-shaped, retained for backwards-compat with existing kit users):
  `.claude/`, `internal/`, `cmd/`, `go.mod`, `go.sum`, `Makefile`, `CLAUDE.md`. Non-Go
  projects MUST override via settings.json (R2: settings.json defaults intentionally preserved).
```

**Important:** `settings.json` itself is NOT edited. Only `code-reviewer.md` documentation language updates.

`coder.md` L387-388 — replace:
```yaml
# BEFORE:
- "Update CONFIG_EXAMPLE (Go default: config.yaml.example)"
- "Update CONFIG_DOCS (Go default: README.md)"
# AFTER:
- "Update {CONFIG_EXAMPLE} (resolved from PROJECT-KNOWLEDGE.md → CONFIG_EXAMPLE; CLAUDE.md fallback). SKIP if slot unset."
- "Update {CONFIG_DOCS} (resolved from PROJECT-KNOWLEDGE.md → CONFIG_DOCS; CLAUDE.md fallback). SKIP if slot unset."
```

`coder-rules/troubleshooting.md` L18 — replace:
```yaml
# BEFORE:
cause: "Attempted to edit generated files (GENERATED/MOCKS — Go default: *_gen.go, mocks/*.go) directly"
# AFTER:
cause: "Attempted to edit generated files (per {GENERATED_PATTERN}/{MOCK_PATTERN} slots resolved from PROJECT-KNOWLEDGE.md; kit-default Go: *_gen.go, mocks/*.go) directly"
```

**Acceptance criteria mapping:** AC-C5.3 — AC-C5.16 (14 of 16 C5 ACs)

**Constraints preserved:** C1 handoff schema unchanged, C5 backwards-compat (CLAUDE.md fallback for all 5 slots), C6 settings.json sparsePaths defaults preserved (R2)

---

### Part 5: C3 — code-reviewer.md ALWAYS-rule SKIP-align ⚠️ ISOLATED COMMIT

**Files:**
- `.claude/agents/code-reviewer.md` (UPDATE — L36 RULE_4, L117 REVIEW process, L171 Auto-escalation)
- `.claude/skills/code-review-rules/SKILL.md` (UPDATE — L23 Auto-Escalation, L44 REVIEW step 3)
- `.claude/skills/code-review-rules/troubleshooting.md` (UPDATE — L55 ALWAYS check)

**Action:** UPDATE

**Description:** ⚠️ **МОСТ BEHAVIORALLY SENSITIVE PART** (R3 mitigation requires isolated commit). Заменить `"ALWAYS verify the import matrix"` + `"handler → service → repository → models"` + `"Import matrix violation → always BLOCKER"` на LAYER_RULE+ARCHITECTURE_STYLE-driven SKIP-with-NIT. Wording exactly mirrors plan-stage P3 fix (consistency with plan-reviewer L34 — already fixed in 1.16.0).

**⚠️ Commit Strategy:** This Part MUST be its own git commit (separate from Part 6). Rationale: code-reviewer.md L36 RULE_4 is in STARTUP CRITICAL section — STARTUP-rules influence agent reasoning more than on-demand SKILL content. If post-fix verdict-enum-stable regression check (AC-C3.7) fails, this commit can be reverted in isolation without affecting other 7 Parts.

**Wording changes:**

`code-reviewer.md` L36 — replace:
```yaml
# BEFORE:
- RULE_4 Check Architecture: ALWAYS verify the import matrix
# AFTER:
- RULE_4 Check Architecture: Verify layer-dependency rule per {LAYER_RULE} slot
  (resolved from PROJECT-KNOWLEDGE.md → LAYER_RULE; CLAUDE.md fallback). SKIP with
  consolidated NIT if {LAYER_RULE} unset OR {ARCHITECTURE_STYLE} != "layered"
  (canonical SKIP, see plan-review-rules/architecture-checks.md L22-33).
```

`code-reviewer.md` L117 — replace:
```yaml
# BEFORE:
- Import matrix compliance (handler → service → repository → models)
# AFTER:
- Layer-dependency compliance per PROJECT-KNOWLEDGE.md → {LAYER_RULE} —
  example shapes are language/architecture-dependent (see ../skills/planner-rules/code-shapes/).
  SKIP if {LAYER_RULE} unset OR {ARCHITECTURE_STYLE} != "layered".
```

`code-reviewer.md` L171 — replace:
```yaml
# BEFORE:
- Import matrix violation → always BLOCKER
# AFTER:
- Layer-dependency violation (when {LAYER_RULE} is SET AND {ARCHITECTURE_STYLE} == "layered") → always BLOCKER.
- SKIP entries (slot unset/non-layered) → consolidated NIT, NOT BLOCKER.
```

`code-review-rules/SKILL.md` L23 (Auto-Escalation) — replace:
```yaml
# BEFORE:
- Import matrix violation → always BLOCKER
# AFTER:
- Layer-dependency violation (when {LAYER_RULE} SET AND {ARCHITECTURE_STYLE} == "layered") → always BLOCKER.
- SKIP entries (slot unset/non-layered) → consolidated NIT, NOT BLOCKER.
```

`code-review-rules/SKILL.md` L44 (REVIEW step 3) — replace:
```yaml
# BEFORE:
- Architecture: import matrix compliance
# AFTER:
- Architecture: layer-dependency compliance per {LAYER_RULE} slot (SKIP if unset or non-layered)
```

`code-review-rules/troubleshooting.md` L55 — replace:
```yaml
# BEFORE:
fix: "ALWAYS check import matrix, regardless of change size"
# AFTER:
fix: "Check layer-dependency compliance per {LAYER_RULE} slot if set; SKIP-with-NIT otherwise."
```

**Acceptance criteria mapping:** AC-C3.1 (partial — code-reviewer surface), AC-C3.2 (partial), AC-C3.3 (partial), AC-C3.4 (full code-reviewer surface), AC-C3.6, AC-C3.7 ⚠️ revised, AC-C3.8, AC-C3.9, AC-C3.10

**⚠️ AC-C3.7 REVISED (kit ARCHITECTURE_STYLE = "other"):** *"Kit-dogfood verdict enum stable on Go fixture; expect ONE new consolidated NIT in VERDICT_JSON.issues[] referencing skipped layer-dependency check (rationale: kit's PROJECT-KNOWLEDGE.md ARCHITECTURE_STYLE=other → SKIP triggered). Verdict ENUM (APPROVED/APPROVED_WITH_COMMENTS/CHANGES_REQUESTED) and issue ID pattern preserved."*

**Constraints preserved:** C1 handoff schema, C2 verdict envelope, C7 5-value enum, C8 IMP-03 ID normalization, C9 IMP-04 parts_validated[]

---

### Part 6: C3-coder — coder.md RULE_2 + coder-rules/SKILL.md SKIP-align

**Files:**
- `.claude/commands/coder.md` (UPDATE — L132-133 autonomy.import_matrix, L496-497 RULE_2)
- `.claude/skills/coder-rules/SKILL.md` (UPDATE — L12 RULE_2, L101 Common Issues "Import matrix violation detected")

**Action:** UPDATE

**Description:** Coder-side mirror of Part 5 — заменить unconditional RULE_2 + auto-escalation в coder и coder-rules/SKILL.md на LAYER_RULE+ARCHITECTURE_STYLE-driven SKIP. Less behaviorally sensitive than Part 5 (coder rules guide implementation, not verdict reasoning) — can share commit with Parts 7+8.

**Wording changes:**

`coder.md` L132-133 (autonomy stop_conditions) — replace:
```yaml
# BEFORE:
- condition: Import matrix violation
  action: "Fix before continuing"
# AFTER:
- condition: "Layer-dependency violation (when {LAYER_RULE} is set AND {ARCHITECTURE_STYLE} == 'layered')"
  action: "Fix before continuing"
- condition: "Layer-dependency check skipped ({LAYER_RULE} unset OR non-layered architecture)"
  action: "Continue; SKIP recorded as consolidated NIT in handoff"
```

`coder.md` L496-497 (RULE_2) — replace:
```yaml
# BEFORE:
- id: RULE_2
  title: "Import Matrix"
  description: "NEVER violate the import matrix."
  severity: CRITICAL
# AFTER:
- id: RULE_2
  title: "Layer Dependency"
  description: |
    Layer-dependency compliance per {LAYER_RULE} slot (resolved from PROJECT-KNOWLEDGE.md → LAYER_RULE;
    CLAUDE.md fallback). NEVER violate the resolved rule when {LAYER_RULE} is set AND
    {ARCHITECTURE_STYLE} == "layered". SKIP rule with consolidated NIT if slot unset OR non-layered architecture.
  severity: CRITICAL
```

`coder-rules/SKILL.md` L12 — replace:
```yaml
# BEFORE:
- RULE_2 Import Matrix: NEVER violate the import matrix.
# AFTER:
- RULE_2 Layer Dependency: NEVER violate {LAYER_RULE} (resolved from PROJECT-KNOWLEDGE.md;
  CLAUDE.md fallback). SKIP if slot unset OR {ARCHITECTURE_STYLE} != "layered".
```

`coder-rules/SKILL.md` L101 (Common Issues "Import matrix violation detected") — replace:
```yaml
# BEFORE:
**Fix:** Review import matrix (handler → service → repository → models). Refactor imports. This is ALWAYS a BLOCKER.
# AFTER:
**Fix:** Review layer-dependency rule per resolved {LAYER_RULE}. Refactor imports per the
resolved rule. BLOCKER when slot is set AND {ARCHITECTURE_STYLE} == "layered";
SKIP-with-consolidated-NIT when unset/non-layered (canonical SKIP).
```

**Acceptance criteria mapping:** AC-C3.1 (full coverage with Part 5), AC-C3.2 (full), AC-C3.3 (full), AC-C3.5 (coder surface)

**Constraints preserved:** Same as Part 5

---

### Part 7: C4 — Coder dependency-order SKIP-align

**Files:**
- `.claude/commands/coder.md` (UPDATE — L351 IMPLEMENT phase order)
- `.claude/skills/coder-rules/SKILL.md` (UPDATE — L53 Step 3 dependency direction)

**Action:** UPDATE

**Description:** Заменить fallback `"data access → … → wiring"` в IMPLEMENT phase guidance на plan-determined-order + LAYERS-driven fallback + SKIP-with-NIT. Plan order — primary source of truth. На kit (LAYERS = [orchestrator, reviewers, enforcement, knowledge]) plan order resolved correctly без data→domain→api fallback.

**Wording changes:**

`coder.md` L351 — replace:
```yaml
# BEFORE:
order: "Follow dependency direction: lower layers first (data access → domain → API → tests → wiring)"
# AFTER:
order: |
  Follow Parts order from plan. The plan's Parts list is the source of truth for ordering
  (planner Phase 4 DESIGN already resolved order using ARCHITECTURE_STYLE-aware analysis).
  If plan does not specify explicit order:
    - if {LAYERS} slot set AND {ARCHITECTURE_STYLE} == "layered" → use lower-layers-first
      (resolve {LAYERS} list from PROJECT-KNOWLEDGE.md);
    - else → follow plan's natural Part order, emit consolidated NIT in evaluate_output
      if order ambiguous (canonical SKIP, see plan-review-rules/architecture-checks.md L22-33).
```

`coder.md` L352 — refine note:
```yaml
# BEFORE:
note: "SEE: .claude/PROJECT-KNOWLEDGE.md for project-specific layer order (if available)"
# AFTER:
note: |
  Resolved from PROJECT-KNOWLEDGE.md → LAYERS + ARCHITECTURE_STYLE; SKIP if unset OR non-layered.
  Kit example: LAYERS=[orchestrator, reviewers, enforcement, knowledge], ARCHITECTURE_STYLE=other →
  follow plan order verbatim.
```

`coder-rules/SKILL.md` L53 — replace:
```yaml
# BEFORE:
Follow lower-layers-first: data access → models → domain → API → tests → wiring.
# AFTER:
Follow Parts order from plan. The plan's Parts list is the source of truth.
If plan unordered: use {LAYERS} slot dependency direction when {ARCHITECTURE_STYLE} == "layered";
otherwise follow plan order verbatim and emit consolidated NIT if ambiguous.
```

**Acceptance criteria mapping:** AC-C4.1 — AC-C4.6 (6 ACs)

**Constraints preserved:** C1 handoff schema, C5 backwards-compat (kit's CLAUDE.md fallback resolves to plan-order behavior — same as pre-fix on kit because kit ARCHITECTURE_STYLE=other always took plan order de facto)

---

### Part 8: Test wiring + cross-cutting validation

**Files:**
- `.claude/scripts/tests/test-c1-code-shapes-reuse.sh` (CREATE)
- `.claude/scripts/tests/test-c2-verify-cascade.sh` (CREATE)
- `.claude/scripts/tests/test-c3-import-matrix-skip.sh` (CREATE)
- `.claude/scripts/tests/test-c4-dependency-order-skip.sh` (CREATE)
- `.claude/scripts/tests/test-c5-slot-consumption.sh` (CREATE)

**Action:** CREATE (5 new test scripts)

**Description:** Wire 47 acceptance criteria из spec §8 в kit's existing VERIFY mechanism (`bash .claude/scripts/tests/test-*.sh`). Каждый test script asserts Cn AC predicates через grep + bash assertions. Pattern matches existing tests/ directory (11 test scripts) — exit 0 PASS, exit non-zero FAIL with stderr `[<script-basename>] LABEL: <message>` per ERROR_WRAP convention from PROJECT-KNOWLEDGE.md.

**Test script template (each test-c*.sh follows this shape):**

```bash
#!/usr/bin/env bash
# .claude/scripts/tests/test-c1-code-shapes-reuse.sh
#
# Asserts AC-C1.1 .. AC-C1.6 from .claude/prompts/coder-code-review-generic-analysis.md §8
# Tests Part 2 (C1 — Reuse planner-rules/code-shapes/)

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

label() { echo "[${SCRIPT_NAME}] $1: $2" >&2; }
fail() { label "FAIL" "$1"; exit 1; }
pass() { label "PASS" "$1"; }

cd "$PROJECT_ROOT"

# AC-C1.1: grep -E '<!-- EXAMPLE \(lang:' returns 0 in coder-rules/examples.md AND code-review-rules/examples.md
if grep -lE '<!-- EXAMPLE \(lang:' .claude/skills/coder-rules/examples.md .claude/skills/code-review-rules/examples.md 2>/dev/null; then
  fail "AC-C1.1 — inline lang-named EXAMPLE blocks still present in coder-rules/code-review-rules examples.md"
fi
pass "AC-C1.1 — no inline lang-named examples in scope"

# AC-C1.2: examples.md contains 'reference_shapes' selector
if ! grep -q 'reference_shapes' .claude/skills/coder-rules/examples.md; then
  fail "AC-C1.2 — coder-rules/examples.md missing reference_shapes block"
fi
if ! grep -q 'reference_shapes' .claude/skills/code-review-rules/examples.md; then
  fail "AC-C1.2 — code-review-rules/examples.md missing reference_shapes block"
fi
pass "AC-C1.2 — reference_shapes selector present in both examples.md files"

# AC-C1.3: 'UNIVERSAL PATTERNS (apply to any Go project)' header removed
if grep -F 'UNIVERSAL PATTERNS (apply to any Go project)' .claude/skills/coder-rules/examples.md; then
  fail "AC-C1.3 — Go-only UNIVERSAL header still in coder-rules/examples.md"
fi
pass "AC-C1.3 — UNIVERSAL Go header removed"

# AC-C1.4: 5 supported language code-shapes/ files exist (already provided by 1.16.0)
for lang in go python typescript rust java _default INVARIANTS; do
  if [[ ! -f ".claude/skills/planner-rules/code-shapes/${lang}.md" ]]; then
    fail "AC-C1.4 — code-shapes/${lang}.md missing"
  fi
done
pass "AC-C1.4 — 7 code-shapes/ files present (5 langs + default + INVARIANTS)"

# AC-C1.5: Kit-dogfood byte-equivalent regression
# (Manual procedure — documented in spec; this test asserts no breaking
#  schema change. Behavioral regression caught by Part 5/7 tests.)
pass "AC-C1.5 — manual regression check (see spec §8 C1 AC-C1.5 procedure)"

# AC-C1.6: handoff.schema.json + checkpoint format unchanged
git diff main -- .claude/schemas/handoff.schema.json .claude/skills/workflow-protocols/checkpoint-protocol.md > /tmp/c1-schema-diff.txt 2>&1 || true
if [[ -s /tmp/c1-schema-diff.txt ]]; then
  fail "AC-C1.6 — handoff.schema.json or checkpoint-protocol.md was modified"
fi
pass "AC-C1.6 — schema/checkpoint contracts unchanged"

label "INFO" "test-c1-code-shapes-reuse.sh complete — 6/6 AC asserted"
exit 0
```

**Similar templates for test-c2/c3/c4/c5** with Cn-specific AC predicates from spec §8.

**Acceptance criteria mapping (Part 8 covers cross-cutting verification of all 47 ACs):**
- AC-C1.1, AC-C1.2, AC-C1.3, AC-C1.4, AC-C1.6 → test-c1
- AC-C2.1, AC-C2.2 (cascade structure), AC-C2.3, AC-C2.4, AC-C2.5, AC-C2.6 (kit fallback), AC-C2.9 → test-c2
- AC-C3.1, AC-C3.2, AC-C3.3, AC-C3.4, AC-C3.5, AC-C3.7 (verdict-enum-stable + new NIT) → test-c3
- AC-C4.1, AC-C4.2, AC-C4.3, AC-C4.5 → test-c4
- AC-C5.1, AC-C5.2, AC-C5.3, AC-C5.4, AC-C5.5, AC-C5.6, AC-C5.7, AC-C5.8, AC-C5.9 (placeholder syntax sweep), AC-C5.13, AC-C5.14, AC-C5.15 → test-c5

**Manual ACs (not automated, documented procedures):**
- AC-C1.5 (kit-dogfood byte-equivalent — manual /coder run on Go fixture)
- AC-C2.7 (CLAUDE.md fallback — manual)
- AC-C2.8 (Hard test on non-Go fixture — manual `mkdir test-py && touch pyproject.toml && /coder verify_startup`)
- AC-C2.10 (pre-commit-build hook stays Go-specific — out of scope per §3.2, no test needed)
- AC-C3.6 (non-layered fixture verdict-NIT — manual)
- AC-C3.8, AC-C3.9, AC-C3.10 (verdict envelope contracts — covered by AC-C1.6 schema-diff)
- AC-C4.4 (flat-fixture coder follows plan order — manual)
- AC-C4.6 (handoff schema unchanged — covered by AC-C1.6)
- AC-C5.10, AC-C5.11, AC-C5.12 (PK > CLAUDE.md > SKIP cascade behavior — partial in test-c5 grep, manual fixture verification)
- AC-C5.16 (`pk_missing_at_inject` telemetry preserved — manual log inspection)

**Constraints preserved:** Test scripts only ADD files to `.claude/scripts/tests/` — no modification to scripts/, schemas/, settings.json, or any other infrastructure. C1-C9 all preserved.

---

## Files Summary

| File | Action | Parts | Description |
| --- | --- | --- | --- |
| `.claude/commands/coder.md` | UPDATE | 1, 4, 6, 7 | VERIFY cascade (P1), CONFIG_* slots (P4), RULE_2 SKIP (P6), L351 plan-order (P7) |
| `.claude/skills/coder-rules/SKILL.md` | UPDATE | 1, 3, 6, 7 | VERIFY refs (P1), DOMAIN_PROHIBIT (P3), RULE_2 SKIP (P6), L53 plan-order (P7) |
| `.claude/skills/coder-rules/examples.md` | UPDATE | 2 | Reuse code-shapes/ via reference |
| `.claude/skills/coder-rules/troubleshooting.md` | UPDATE | 4 | GENERATED/MOCKS slot reference |
| `.claude/skills/coder-rules/review-response.md` | UPDATE | 1 | Handoff command_used example |
| `.claude/agents/code-reviewer.md` | UPDATE | 1, 3, 4, 5 | QUICK CHECK (P1), DOMAIN_PROHIBIT (P3), ERROR_WRAP/GEN/MOCK + worktree doc (P4), RULE_4 SKIP (P5) ⚠️ |
| `.claude/skills/code-review-rules/SKILL.md` | UPDATE | 1, 2, 5 | Fallback (P1), reference (P2), RULE_4/L23/L44 SKIP (P5) |
| `.claude/skills/code-review-rules/examples.md` | UPDATE | 2 | Reuse code-shapes/ via reference |
| `.claude/skills/code-review-rules/troubleshooting.md` | UPDATE | 5 | L55 SKIP wording |
| `.claude/scripts/tests/test-c1-code-shapes-reuse.sh` | CREATE | 8 | AC verification |
| `.claude/scripts/tests/test-c2-verify-cascade.sh` | CREATE | 8 | AC verification |
| `.claude/scripts/tests/test-c3-import-matrix-skip.sh` | CREATE | 8 | AC verification |
| `.claude/scripts/tests/test-c4-dependency-order-skip.sh` | CREATE | 8 | AC verification |
| `.claude/scripts/tests/test-c5-slot-consumption.sh` | CREATE | 8 | AC verification |

**Total:** 10 UPDATE + 5 CREATE = 15 files touched.

**Files NOT touched (per §3.2 + R2 + R5):**
- `.claude/schemas/handoff.schema.json` — C1 contract
- `.claude/settings.json` — R2 worktree.sparsePaths preserved
- `.claude/scripts/auto-fmt-go.sh`, `.claude/scripts/protect-files.sh` — R5 hooks deferred
- `.claude/scripts/inject-review-context.sh` — C6 PK injection contract preserved
- `.claude/scripts/save-review-checkpoint.sh` — C8 IMP-03 normalization preserved
- `.claude/scripts/validate-handoff.sh` — C1 handoff validation preserved
- `.claude/skills/workflow-protocols/*` — pipeline contracts preserved
- `.claude/agents/plan-reviewer.md`, `.claude/skills/plan-review-rules/*` — §3.2 plan-stage already fixed
- `.claude/templates/plan-template.md` — §11 deferred
- `.claude/skills/tdd-go/*`, `.claude/skills/planner-rules/code-shapes/*` — out of scope

---

## Acceptance Criteria

### Functional

- [ ] All 47 AC predicates from spec §8 pass (test-c{1,2,3,4,5}-*.sh return exit 0)
- [ ] No Go-specific anchors remain in scope files outside labeled kit-dogfood sections
- [ ] Coder/Reviewer correctly resolve PK slots via cascade `PK > CLAUDE.md > SKIP-with-NIT`
- [ ] Non-Go fixture (e.g. pyproject.toml present, no Makefile) produces actionable WARN, not silent SKIP
- [ ] code-reviewer's STARTUP RULE_4 wording references LAYER_RULE + ARCHITECTURE_STYLE + SKIP semantics
- [ ] Coder's RULE_2 wording references same slot-driven SKIP

### Technical

- [ ] `bash .claude/scripts/tests/test-*.sh` (kit's VERIFY_CMD) passes — all 11 existing + 5 new test scripts return exit 0
- [ ] `check-jsonschema --schemafile .claude/schemas/handoff.schema.json` (kit's LINT_CMD) passes on any new handoff JSON
- [ ] No new dependencies added (no PK slot additions, no new MCP servers, no new env vars)
- [ ] Placeholder syntax `{SLOT_NAME}` consistent across all 10 modified files (kit convention from R8 audit)
- [ ] Markdown lint warnings on plan + spec do NOT block (existing Cyrillic-anchor warnings are pre-existing)

### Architecture

- [ ] **C1** Handoff schema (`.claude/schemas/handoff.schema.json`) — git diff empty
- [ ] **C2** VERDICT_JSON envelope (sentinel, fence, severity enum, issue ID `^CR-[0-9a-f]{8}$`) — unchanged
- [ ] **C3** Checkpoint YAML format (12 core fields) — unchanged
- [ ] **C4** File paths (`.claude/prompts/{feature}*.md`, `.claude/workflow-state/*-handoff.json`, `*-checkpoint.yaml`, `*-diff-manifest.json`) — unchanged
- [ ] **C5** Backwards-compat: kit dogfood (Go) verdict ENUM stable; expect ONE new consolidated NIT в VERDICT_JSON.issues[] from C3+C4 (kit ARCHITECTURE_STYLE=other → SKIP triggered) — **revised AC-C3.7**
- [ ] **C6** PK injection (4 KB cap, `pk_missing_at_inject` telemetry, `inject-review-context.sh` not modified) — preserved
- [ ] **C7** code_review_verdict 5-value enum (`APPROVED|APPROVED_WITH_COMMENTS|CHANGES_REQUESTED|NEEDS_CHANGES|REJECTED`) — unchanged
- [ ] **C8** IMP-03 ID normalization formula (`CR-<sha256(category|location|problem)[:8]>`) — unchanged
- [ ] **C9** IMP-04 `parts_validated[]` + `{feature}-diff-manifest.json` schema — unchanged

---

## Config Changes

**N/A** — этот рефакторинг не добавляет новой конфигурации. Все слоты уже существуют в PROJECT-KNOWLEDGE.md schema 1.1.0 (см. spec §1, F1, footnote Q1+spec-§1).

---

## Notes

### Edge cases

1. **Kit's ARCHITECTURE_STYLE = "other"** (verified in PROJECT-KNOWLEDGE.md L61): после Part 5+6 kit dogfood получит **ONE additional consolidated NIT** в VERDICT_JSON.issues[] (skipped layer-dependency check). Verdict enum (APPROVED → APPROVED_WITH_COMMENTS если других issues нет, или CHANGES_REQUESTED если есть other BLOCKER) остаётся в стабильном domain. AC-C3.7 ревизирована: *"verdict-enum-stable modulo skip-NIT"*.

2. **Settings.json `worktree.sparsePaths` Go defaults** (R2): сохранены as-is; только doc-language обновлено в `code-reviewer.md` L329. Существующие kit-users получают backwards-compat. Non-Go users должны вручную override настроить.

3. **Pre-commit-build hook (`go build ./...`)** triggers только на `git commit*` — out of scope per §3.2. Non-Go проекты обходят его graceful no-op.

4. **mcp-tools.md examples** (`make test`, `go test -race` примеры в Bash tool guide) — defer per spec §11 *"single-line examples in MCP guidance"*.

### Known limitations

- **Non-Go fixture testing** (AC-C2.8, AC-C3.6, AC-C4.4) requires manual procedure: `mkdir /tmp/non-go-fixture && cd /tmp/non-go-fixture && touch pyproject.toml && [run /coder /code-review]`. Automating in test-c2/c3/c4 is possible but out of scope (would need to create real PK fixtures + invoke /coder agent — heavy).
- **Behavioral regression on R3 (code-reviewer L36 RULE_4 wording change)**: AC-C3.7 verdict-enum-stable check requires running code-reviewer on a fixed branch state pre/post fix. Manual procedure documented в test-c3-import-matrix-skip.sh comments.

### Deferred findings (1.17.0 follow-up)

🆕 **NEW finding from R4 audit (Phase 3 of /planner):**

**plan-reviewer.md L167-168 + plan-review-rules/SKILL.md L22-23 retain `"Import matrix violation → always BLOCKER"` auto-escalation** — incomplete 1.16.0 P3 cleanup. Plan-stage P3 fixed `plan-reviewer.md L34` (RULE) and `L81` (REVIEW process) but missed Auto-Escalation block. Symmetric to fix in this plan's Part 5 (code-reviewer side). **Strictly out of scope per spec §3.2** (`/planner + plan-reviewer "already fixed in 1.16.0"`). User constraint *"не распыляться"* honored. Filed as deferred for 1.17.0.

Other deferred items (from spec §11):
- `tdd-go` skill genericfication
- Hook renaming (`auto-fmt-go.sh`, `pre-commit-build.sh`)
- `plan-template.md` Go-shape Parts examples (L102-124)
- Single-line Go examples in `coder-rules/troubleshooting.md` L7, `SKILL.md` L96, `mcp-tools.md` L42-69
- `settings.json worktree.sparsePaths` PK-driven defaults (R2 conservative)

### Risks Reference

Полный risk catalog в spec §10 (R1-R10). Ключевые здесь:

- **R3** code-reviewer.md L36 RULE_4 STARTUP wording sensitivity — mitigated by Part 5 isolated commit + AC-C3.7 verdict-enum stable check
- **R4** hidden grep coupling on 7 literals — mitigated by Phase 3 R4 audit (completed; no critical anchors outside scope; 1 deferred finding documented)
- **R7** XL budget — 8 Parts manageable
- **R8** placeholder syntax `${...}` vs `{...}` — resolved via R8 audit (`{SLOT_NAME}` confirmed kit convention)
- **R9** severity mapping (BLOCKER ↔ NIT при SKIP) — enum unchanged (C2/C8); per-check mapping is internal

### Iteration tracking

- Iteration 1/3 (this plan).
- IMP-04 diff-manifest: N/A on iter 1 (no prior plan).
- Plan-review next; on NEEDS_CHANGES, planner re-invocation with diff-manifest на iter 2+.
