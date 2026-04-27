# Plan-Stage Genericity Fix — Implementation Plan

**Spec:** [`.claude/prompts/plan-stage-genericity-audit-2026-04-27.md`](.claude/prompts/plan-stage-genericity-audit-2026-04-27.md) (approved 2026-04-27, all 5 problems G1-G5)

**Type:** refactoring (text-only documentation/prompt edits)
**Complexity:** XL (per user instruction; effort matches L by mechanical metrics — 4 files modified, 1 file created, ~25 source lines changed, ~80 test lines added)
**Branch:** `main` (single bundled commit per approved spec)

## Context

Five Plan-stage genericity gaps in `/planner` + `plan-reviewer` + `planner-rules` skill. Each gap is a hardcoded Go-ism (path, layer name, MVC term, file extension) that bleeds through despite the v1.16.0/v1.17.0 slot scaffolding being correct. This plan addresses each gap with a minimal, slot-aware text replacement.

**Why** — see spec §1 (Goal) and §5 (per-problem justification). Short version: the slot abstraction (`PK > CLAUDE.md > SKIP`) only works if reference text in the audited surface uses slot syntax instead of literal Go tokens. The gaps are at the prompt-text level, not the schema level.

## Scope

### IN
- `.claude/commands/planner.md` — 3 edits (G1, G2, G3)
- `.claude/agents/plan-reviewer.md` — 1 edit (G4)
- `.claude/skills/planner-rules/task-analysis.md` — 1 edit (G5, multi-line)
- `.claude/scripts/tests/test-genericity-audit.sh` — NEW (5 problem predicates)

### OUT
- Schema (`handoff.schema.json`) — UNCHANGED, all 5 fixes are text-only.
- PROJECT-KNOWLEDGE.md / .example — UNCHANGED, no slot additions.
- Hooks (`inject-review-context.sh`, `validate-handoff.sh`, `save-review-checkpoint.sh`) — UNCHANGED.
- Files explicitly listed in spec §6 (Out of Scope) — `examples.md`, `required-sections.md` code blocks, `architecture-checks.md` pass_criteria text.
- C-stage artifacts (coder.md, code-reviewer.md, etc.) — covered by post-1.17 audit.

## Dependencies

None — text-only refactor on top of post-1.17 baseline (commit `bc2c2e8`). No prior-blocking issues.

## Architecture Decision

**Single bundled commit** approved per user — refactor is atomic (one audit, one fix, one PR). Splitting into 5 micro-commits would create review noise without isolation benefit (no logic/test risk per problem).

**Test strategy:** one new test script `test-genericity-audit.sh` with all 5 problem predicates. Mirrors existing `test-p3-plan-reviewer-skip.sh` AC-P3.2 pattern (grep-based with EXAMPLE comment-block exclusion). New tests are GREP-INVERSE assertions (file does NOT contain bad-token X), which is cheap and durable.

**No TDD step required** — text edits, no logic. Test predicate written alongside the text fix; predicate failure on `main` BEFORE fix demonstrates it gates correctly, then turns PASS once fix applied.

## Parts

### Part 1: G1 — De-bias layer-vocab clarifying question (planner.md)

**File:** `.claude/commands/planner.md` lines 284-289

**Operation:** Edit (full text replacement of the `question:` block)

**Old text (verbatim from current file):**
```
        question: |
          "Layer vocabulary: which layers does your project use, in dependency order
          (lowest → highest)? E.g., for Go Clean Architecture:
          [models, repository, service, handler]; for Django:
          [model, manager, view]; for Spring Boot:
          [entity, repository, service, controller]. Provide a comma-separated list."
```

**New text:**
```
        question: |
          "Layer vocabulary: which layers does your project use, in dependency order
          (lowest → highest)? Provide a comma-separated list. Examples from common
          stacks (illustrative — your project's vocabulary may differ):
            - Django:    [model, manager, view]
            - Go:        [models, repository, service, handler]
            - Spring:    [entity, repository, service, controller]
          Use what your codebase actually uses."
```

**Why this exact wording:**
- Examples reordered alphabetically by stack name (Django → Go → Spring) — removes Go-first position bias.
- "for Go Clean Architecture:" framing dropped — replaced with "Examples from common stacks (illustrative — your project's vocabulary may differ)".
- "Use what your codebase actually uses." reaffirms primacy of project's own vocabulary.
- Preserves the imperative "Provide a comma-separated list." (G1.4).

**ACs covered:** G1.1 (Go not first), G1.2 (no "for Go Clean Architecture"), G1.3 (3 stacks present), G1.4 (imperative preserved).

---

### Part 2: G2 — Slot-ify code-researcher delegation example (planner.md)

**File:** `.claude/commands/planner.md` lines 329-336

**Operation:** Edit (replacement of `delegation_prompt_example:` block content)

**Old text:**
```
          delegation_prompt_example: |
            Research the codebase for: API handler implementation patterns
            Focus areas:
            - error handling and response formatting in internal/handler/
            - middleware usage patterns
            - input validation approach
            Context: Planning new_feature task, complexity L
```

**New text:**
```
          delegation_prompt_example: |
            Research the codebase for: API/transport-layer implementation patterns
            Focus areas:
            - error handling and response formatting in <INPUT_LAYER>
              (resolve from PROJECT-KNOWLEDGE.md → LAYERS[N], or describe by role
              if LAYERS unset)
            - middleware / request-pipeline patterns
            - input validation approach
            Context: Planning new_feature task, complexity L
            <!-- EXAMPLE (lang: go) — concrete <INPUT_LAYER> = `internal/handler/` -->
            <!-- EXAMPLE (lang: python) — concrete <INPUT_LAYER> = `app/api/` or `<pkg>/views/` -->
            <!-- EXAMPLE (lang: typescript) — concrete <INPUT_LAYER> = `src/controllers/` or `src/routes/` -->
```

**Why this exact wording:**
- Active body uses `<INPUT_LAYER>` slot (consistent with `data-flow.md` L18-20 angle-slot convention).
- "API/transport-layer" phrasing matches `architecture-checks.md` L63 pass_criteria language ("API/transport layer").
- Concrete Go path moved into `<!-- EXAMPLE (lang: go) -->` comment block per kit standard (consistent with how `architecture-checks.md` L65-68 already handles language-specific examples).
- Two extra concrete examples (python, typescript) so kit dogfood is preserved AND non-Go users get visible reference.

**ACs covered:** G2.1 (no `internal/handler/` in active body), G2.2 (slot syntax), G2.3 (resolution rule documented), G2.4 (Go EXAMPLE preserved).

---

### Part 3: G3 — Slot-ify default parts_order pattern (planner.md)

**File:** `.claude/commands/planner.md` lines 459-462

**Operation:** Edit (replacement of `parts_order:` block)

**Old text:**
```
    parts_order:
      note: "Follow dependency direction — lower layers first. Adapt to project structure."
      pattern: "Data access → Models → Domain logic → API/Handlers → Tests → Wiring → Docs"
      reference: "SEE: .claude/PROJECT-KNOWLEDGE.md for project-specific layer order (if available)"
```

**New text:**
```
    parts_order:
      note: |
        Follow dependency direction — lower layers first. Concrete layer names
        resolve from PROJECT-KNOWLEDGE.md → LAYERS (lowest-to-highest).
      pattern_when_layers_set: "{LAYERS[0]} → {LAYERS[1]} → ... → {LAYERS[N]} → Tests → Setup → Docs"
      pattern_when_layers_unset: "<DATA_ACCESS_LAYER> → <BUSINESS_LAYER> → <INPUT_LAYER> → Tests → Setup → Docs"
      fallback_skip_rule: |
        If LAYERS unset AND ARCHITECTURE_STYLE != layered, planner SKIPS layer
        prefixes in Parts headings and uses functional grouping (input handling →
        core logic → output → tests → setup → docs). Plan-reviewer emits a
        consolidated NIT noting layer-allocation was skipped (canonical SKIP
        pattern, see plan-review-rules/architecture-checks.md § Layer-check predicate).
      reference: "SEE: .claude/PROJECT-KNOWLEDGE.md for project-specific layer order"
```

**Why this exact wording:**
- "Wiring" replaced with "Setup" (universal term across MVC, hexagonal, event-driven, functional stacks).
- Two patterns: when LAYERS set → curly-slot template; when LAYERS unset → angle-slot template (consistent with `data-flow.md` L18-20).
- `fallback_skip_rule:` documents the non-layered-architecture path explicitly, citing canonical SKIP rule.
- Note text references PROJECT-KNOWLEDGE.md for resolution, no hardcoded Go path.

**ACs covered:** G3.1 (no "Wiring"), G3.2 (slot syntax), G3.3 (Tests/Setup/Docs preserved), G3.4 (PK reference present), G3.5 (fallback_skip_rule documented).

---

### Part 4: G4 — Generic location-stability examples (plan-reviewer.md)

**File:** `.claude/agents/plan-reviewer.md` lines 308-310 (the `Location-stability guidance` paragraph)

**Operation:** Edit (replacement of the bulleted example list + addition of a slot-pointer note)

**Old text:**
```
**Location-stability guidance (IMP-03 KD-8):** prefer function / symbol name over line number in the `location` field. Line numbers shift when code is edited, which changes the hash → breaks ID continuity across iterations. Examples:
- PREFER: `"Part 3: UserHandler.Create"` or `"internal/service/user.go:Update"` (stable across edits)
- AVOID: `"handler.go:42"` alone (drift-prone)
```

**New text:**
```
**Location-stability guidance (IMP-03 KD-8):** prefer function / symbol name over line number in the `location` field. Line numbers shift when code is edited, which changes the hash → breaks ID continuity across iterations. File extensions and project-specific path prefixes also drift (refactors, language ports, monorepo restructuring). Examples (language-agnostic):
- PREFER: `"Part 3: UserHandler.Create"` (Part-anchored symbol — most stable)
- ACCEPT: `"<source-glob-relative-path>:Update"` (path + symbol — stable until file rename)
- AVOID: `"<filename>:42"` alone (line number only — drift-prone)

**Note:** match path conventions to the project's `SOURCE_GLOB` slot (PROJECT-KNOWLEDGE.md). Avoid hardcoding language-specific prefixes (`internal/`, `src/`, `lib/`) or file extensions (`.go`, `.py`, `.ts`) in the `location` string — those vary per project.
```

**Why this exact wording:**
- Three examples (was two) showing the gradient: symbol-only > path+symbol > line-only — teaches the lesson more clearly.
- Symbol-only example FIRST (G4.3) — canonical preferred form.
- All Go-isms removed: `.go`, `internal/`, `service/user.go`, `handler.go`.
- `SOURCE_GLOB` slot pointer added (G4.4) — directs reviewer to PK rather than hardcoded paths.
- Adds explicit warning ("Avoid hardcoding language-specific prefixes…") so future-LLM reviewers don't re-introduce extensions.

**ACs covered:** G4.1 (no Go-isms), G4.2 (3 examples ≥ 2), G4.3 (symbol-only first), G4.4 (SOURCE_GLOB note).

---

### Part 5: G5 — Architecture-neutral complexity examples (task-analysis.md)

**File:** `.claude/skills/planner-rules/task-analysis.md` lines 80-103 + 209-215 (multi-edit)

**Operation:** Edit (3 separate edits — L83-89 = L examples; L91-102 = XL examples; L204-215 = Example 2 rationale)

**Edit 5a — L complexity examples (lines ~83-89):**

Old:
```
  L:
    parts: "4-6"
    layers: "3+"
    files: "6-10"
    examples:
      - "New endpoint with database → domain → API"
      - "Refactor controller by splitting into services"
    indicators:
      - "Affects 3+ architecture layers"
      - "May require architectural decision"
      - "New SQL queries or migrations"
```

New:
```
  L:
    parts: "4-6"
    layers: "3+"
    files: "6-10"
    examples:
      - "New endpoint touching storage → domain → input/API layers"
      - "Refactor a layer by splitting concerns across modules"
    indicators:
      - "Affects 3+ architecture layers"
      - "May require architectural decision"
      - "New persistence schema or migration"
    note: "Concrete layer names per project — see PROJECT-KNOWLEDGE.md → LAYERS"
```

**Why:** removed "controller" + "service" (MVC-specific). "storage / domain / input" terminology widely understood across architectures. "SQL queries" → "persistence schema" (storage-neutral).

**Edit 5b — XL complexity examples (lines ~91-102):**

Old:
```
  XL:
    parts: "7+"
    layers: "4+"
    files: "10+"
    examples:
      - "New domain with full stack (DB → models → controller → API → tests)"
      - "Integration with external service"
      - "Plugin architecture"
    indicators:
      - "Cross-domain changes"
      - "New external system integration"
      - "Sequential Thinking needed for approach selection"
```

New:
```
  XL:
    parts: "7+"
    layers: "4+"
    files: "10+"
    examples:
      - "New domain with full stack (storage → entities → business → API → tests)"
      - "Integration with external service"
      - "Plugin or event-driven architecture across multiple boundaries"
    indicators:
      - "Cross-domain changes"
      - "New external system integration"
      - "Sequential Thinking needed for approach selection"
    note: "Layer terminology shown is illustrative; resolve concrete names from PROJECT-KNOWLEDGE.md → LAYERS"
```

**Why:** "DB → models → controller → API → tests" → "storage → entities → business → API → tests" (architecture-neutral). "Plugin architecture" → "Plugin or event-driven architecture across multiple boundaries" (acknowledges non-MVC).

**Edit 5c — Example 2 rationale (lines ~204-215):**

Old:
```
### Example 2: New API Endpoint

```
Input: "Add endpoint GET /api/v1/{resource}/:id"

Task Analysis:
  Type: new_feature
  Complexity: L (5 Parts: DB query + model + controller + handler + tests)
  Route: standard
  Sequential Thinking: recommended
  Plan Review: standard
  Rationale: "New endpoint through all layers, but follows existing pattern for this resource"
```
```

New:
```
### Example 2: New API Endpoint

```
Input: "Add endpoint GET /api/v1/{resource}/:id"

Task Analysis:
  Type: new_feature
  Complexity: L (5 Parts: data query + entity + business + API + tests)
  Route: standard
  Sequential Thinking: recommended
  Plan Review: standard
  Rationale: "New endpoint through all layers, but follows existing pattern for this resource"
```
```

**Why:** "DB query + model + controller + handler + tests" had BOTH "controller" AND "handler" (G5.3 violation — confusing duality). Replaced with "data query + entity + business + API + tests" — single API/output term, abstract throughout.

**ACs covered:** G5.1 (L examples no controller/service), G5.2 (XL examples no controller), G5.3 (Example 2 no controller+handler dual), G5.4 (LAYERS note added in 5a + 5b), G5.5 (terminology drawn from architecture-neutral set).

---

### Part 6: NEW test script (test-genericity-audit.sh)

**File:** `.claude/scripts/tests/test-genericity-audit.sh` (NEW)

**Operation:** Write (new file, executable bash script)

**Structure:** mirrors existing `test-p3-plan-reviewer-skip.sh` (set -euo pipefail, label/fail/pass helpers, scope file array, automated checks block, manual checks comment block).

**Test cases:**

```bash
#!/usr/bin/env bash
# test-genericity-audit.sh
#
# Asserts G1.1..G5.3 from .claude/prompts/plan-stage-genericity-audit-2026-04-27.md
# Tests 2026-04-27 fresh audit: 5 Plan-stage genericity gaps fixed in
# planner.md, plan-reviewer.md, task-analysis.md.

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

label() { echo "[${SCRIPT_NAME}] $1: $2" >&2; }
fail() { label "FAIL" "$1"; exit 1; }
pass() { label "PASS" "$1"; }

cd "$PROJECT_ROOT"

# ════════════════════════════════════════════════════════════════════════
# AUTOMATED
# ════════════════════════════════════════════════════════════════════════

# G1.1 — planner.md clarifying question: Go is not the FIRST stack mentioned
# Approach: find the question block, extract the example list, verify Django appears before Go.
if ! awk '/Layer vocabulary:/,/Use what your codebase/' .claude/commands/planner.md \
     | grep -nE 'Django|Spring|Go:' | head -3 \
     | awk 'NR==1{first=$0} END{exit (first ~ /Django/) ? 0 : 1}'; then
  fail "G1.1 — planner.md layer-vocab question does not have Django as first example"
fi
pass "G1.1 — planner.md layer-vocab question reordered alphabetically (Django first)"

# G1.2 — no "for Go Clean Architecture" framing
if grep -F 'for Go Clean Architecture' .claude/commands/planner.md 2>/dev/null; then
  fail "G1.2 — 'for Go Clean Architecture' framing still in planner.md"
fi
pass "G1.2 — Go-Clean-Architecture framing removed"

# G1.3 — all 3 stacks present in question block
for stack in 'Django' 'Go' 'Spring'; do
  awk '/Layer vocabulary:/,/Use what your codebase/' .claude/commands/planner.md \
    | grep -q "$stack" \
    || fail "G1.3 — stack '$stack' missing from layer-vocab question"
done
pass "G1.3 — all 3 stacks (Django, Go, Spring) present"

# G2.1 — no `internal/handler/` in delegation_prompt_example active body
# (allowed inside <!-- EXAMPLE (lang: go) --> comment lines starting with '<!--')
if awk '/delegation_prompt_example:/,/Context: Planning/' .claude/commands/planner.md \
     | grep -nE 'internal/handler/' \
     | grep -vE '^[0-9]+:[[:space:]]*<!--'; then
  fail "G2.1 — internal/handler/ found in active body of delegation_prompt_example"
fi
pass "G2.1 — internal/handler/ only in EXAMPLE comment blocks (or absent)"

# G2.2 — slot syntax used (<INPUT_LAYER> or {INPUT_LAYER})
grep -qE '<INPUT_LAYER>|\{INPUT_LAYER\}' .claude/commands/planner.md \
  || fail "G2.2 — no <INPUT_LAYER>/{INPUT_LAYER} slot syntax in planner.md"
pass "G2.2 — slot syntax present in delegation example"

# G3.1 — no literal "Wiring" in parts_order block (Go-isolated term)
if awk '/parts_order:/,/^[^ ]/' .claude/commands/planner.md | grep -F 'Wiring' 2>/dev/null; then
  fail "G3.1 — literal 'Wiring' still in parts_order block"
fi
pass "G3.1 — 'Wiring' removed from parts_order"

# G3.2 — slot syntax in parts_order
awk '/parts_order:/,/^[^ ]/' .claude/commands/planner.md \
  | grep -qE '<DATA_ACCESS_LAYER>|\{LAYERS\[' \
  || fail "G3.2 — no slot syntax (<DATA_ACCESS_LAYER> or {LAYERS[) in parts_order"
pass "G3.2 — parts_order uses slot-templated patterns"

# G3.5 — fallback_skip_rule documented
grep -q 'fallback_skip_rule' .claude/commands/planner.md \
  || fail "G3.5 — fallback_skip_rule key missing from parts_order block"
pass "G3.5 — fallback_skip_rule documented"

# G4.1 — no Go-specific path/extension in plan-reviewer location-stability section
# Locate the IMP-03 KD-8 paragraph and assert no .go / internal/
if awk '/Location-stability guidance/,/Iteration 2\+/' .claude/agents/plan-reviewer.md \
     | grep -nE 'internal/|handler\.go|service/user\.go|\.go:'; then
  fail "G4.1 — Go-specific path/extension found in location-stability guidance"
fi
pass "G4.1 — location-stability guidance is language-agnostic"

# G4.2 — at least 2 examples in the bulleted list
EXAMPLE_COUNT=$(awk '/Location-stability guidance/,/Iteration 2\+/' .claude/agents/plan-reviewer.md \
                 | grep -cE '^- (PREFER|ACCEPT|AVOID):' || true)
[[ "$EXAMPLE_COUNT" -ge 2 ]] \
  || fail "G4.2 — fewer than 2 examples ($EXAMPLE_COUNT) in location-stability bulleted list"
pass "G4.2 — at least 2 examples present (count: $EXAMPLE_COUNT)"

# G4.4 — SOURCE_GLOB slot pointer added
awk '/Location-stability guidance/,/Iteration 2\+/' .claude/agents/plan-reviewer.md \
  | grep -q 'SOURCE_GLOB' \
  || fail "G4.4 — SOURCE_GLOB slot pointer not added to location-stability guidance"
pass "G4.4 — SOURCE_GLOB slot pointer present"

# G5.1 — task-analysis L complexity examples have no "controller" / "service" outside EXAMPLE
# Use Awk to extract the L: block and grep
if awk '/^  L:/,/^  XL:/' .claude/skills/planner-rules/task-analysis.md \
     | grep -nE '\bcontroller\b|\bservice\b' \
     | grep -vE '^[0-9]+:[[:space:]]*<!--'; then
  fail "G5.1 — controller/service still in L complexity examples active body"
fi
pass "G5.1 — L complexity examples free of controller/service"

# G5.2 — XL complexity examples have no "controller" outside EXAMPLE
if awk '/^  XL:/,/^```$/' .claude/skills/planner-rules/task-analysis.md \
     | grep -nE '\bcontroller\b' \
     | grep -vE '^[0-9]+:[[:space:]]*<!--'; then
  fail "G5.2 — controller still in XL complexity examples active body"
fi
pass "G5.2 — XL complexity examples free of controller"

# G5.3 — Example 2 rationale doesn't have BOTH "controller" AND "handler"
EX2_LINE=$(awk '/Example 2:/,/Example 3:/' .claude/skills/planner-rules/task-analysis.md \
            | grep 'Complexity: L (5 Parts:' || echo '')
if echo "$EX2_LINE" | grep -q 'controller' && echo "$EX2_LINE" | grep -q 'handler'; then
  fail "G5.3 — Example 2 rationale still has BOTH 'controller' AND 'handler' (MVC duality)"
fi
pass "G5.3 — Example 2 rationale free of controller+handler duality"

# G5.4 — LAYERS note added to L or XL block
awk '/^  L:/,/^  XL:/' .claude/skills/planner-rules/task-analysis.md \
  | grep -q 'PROJECT-KNOWLEDGE.md.*LAYERS' \
  || awk '/^  XL:/,/^```$/' .claude/skills/planner-rules/task-analysis.md \
       | grep -q 'PROJECT-KNOWLEDGE.md.*LAYERS' \
  || fail "G5.4 — no PROJECT-KNOWLEDGE.md → LAYERS note in L/XL complexity blocks"
pass "G5.4 — LAYERS slot pointer present in complexity examples"

# ════════════════════════════════════════════════════════════════════════
# MANUAL
# ════════════════════════════════════════════════════════════════════════
# G1.4 — imperative "Provide a comma-separated list" preserved (visual review)
# G2.3 — resolution rule documented (visual review of the EXAMPLE comment list)
# G2.4 — concrete Go example preserved in EXAMPLE block (visual review)
# G3.3, G3.4 — Tests/Setup/Docs preserved + PK reference (visual review)
# G4.3 — symbol-only example FIRST (visual review of bullet ordering)
# G5.5 — replacement terminology drawn from architecture-neutral set (visual review)

label "INFO" "test-genericity-audit.sh complete — 13/19 ACs automated (manual: G1.4, G2.3-4, G3.3-4, G4.3, G5.5)"
exit 0
```

**Why this exact structure:**
- Header comment cites the spec file and lists which ACs are covered.
- Helper functions (label/fail/pass) match other test scripts in the directory.
- Each AC has its own `# G_.X — description` block + matching pass message.
- Visual-review-only ACs documented in MANUAL section (per kit convention from test-p1..p5).

**ACs covered (test predicates):** G1.1, G1.2, G1.3, G2.1, G2.2, G3.1, G3.2, G3.5, G4.1, G4.2, G4.4, G5.1, G5.2, G5.3, G5.4 (15 automated).

**ACs deferred to manual review:** G1.4 (imperative phrasing), G2.3 (resolution rule documentation quality), G2.4 (Go EXAMPLE preserved), G3.3, G3.4, G4.3, G5.5 (subjective wording quality — verified by reviewer reading the diff).

## Files Summary

| File | Action |
|---|---|
| `.claude/commands/planner.md` | UPDATE (3 edits — Parts 1, 2, 3) |
| `.claude/agents/plan-reviewer.md` | UPDATE (1 edit — Part 4) |
| `.claude/skills/planner-rules/task-analysis.md` | UPDATE (3 sub-edits — Part 5a/5b/5c) |
| `.claude/scripts/tests/test-genericity-audit.sh` | CREATE + chmod +x |

## Acceptance Criteria

### Functional
- AC-F1: After all 5 fixes, `bash .claude/scripts/tests/test-genericity-audit.sh` exits 0 with all 15 automated ACs PASS.
- AC-F2: All 21 existing test scripts in `.claude/scripts/tests/` retain current PASS/FAIL state (19/21 PASS; 2 pre-existing baseline failures unchanged).
- AC-F3: Spec ACs G1.1-G5.5 all satisfied (15 automated + 7 manual; manual ACs verified by code-reviewer agent on diff).

### Technical
- AC-T1: `git diff .claude/schemas/handoff.schema.json` is EMPTY — schema unchanged (preserves C1, C2, C8, C9).
- AC-T2: `git diff .claude/PROJECT-KNOWLEDGE.md.example` is EMPTY — slot schema unchanged (preserves C5).
- AC-T3: `git diff .claude/scripts/inject-review-context.sh` is EMPTY — 4 KB cap and PK injection logic preserved (preserves C7).
- AC-T4: `git diff .claude/scripts/save-review-checkpoint.sh` is EMPTY — IMP-03 ID normalization preserved (preserves C3).
- AC-T5: `git diff .claude/skills/workflow-protocols/checkpoint-protocol.md` is EMPTY — checkpoint format preserved.
- AC-T6: New test script has `chmod +x` (executable bit set).

### Architecture
- AC-A1: All ARCHITECTURE_STYLE values (`layered`, `flat`, `event_driven`, `hexagonal`, `other`) handled coherently — Part 3's `fallback_skip_rule` documents the non-layered path explicitly.
- AC-A2: Slot syntax consistent within edited blocks — angle-`<SLOT>` form used in `data-flow.md`-aligned contexts (Parts 2, 3, 4); curly-`{SLOT}` form used where existing kit doc uses it (none added in this fix).
- AC-A3: No new dependencies on hooks, no new env vars, no new scripts beyond the test.

## Config Changes

None. No `config.yaml` / `settings.json` / `settings.local.json` changes. No PROJECT-KNOWLEDGE.md schema bumps. Pure text refactor.

## TDD

Skipped — text-only refactor with no logic. Test predicate written alongside fixes (Part 6); test fails on `main` BEFORE Parts 1-5 are applied (verifies it gates correctly), then turns PASS once fixes land.

## Risks & Mitigations

| Risk | Severity | Mitigation |
|---|---|---|
| Awk-based test predicate is fragile to YAML formatting (whitespace, indentation) | LOW | Each predicate uses BOTH range delimiters AND content matching (e.g. `awk '/parts_order:/,/^[^ ]/'` — block delimited by next outdented line). If formatting drifts, test fails noisily, easy to fix. |
| `<INPUT_LAYER>` slot syntax in planner.md L332 conflicts with existing curly-`{}` convention elsewhere | LOW | Spec §6 explicitly defers slot-syntax-style cleanup. Within the edited blocks, angle-form is consistent with `data-flow.md` L18-20 (closest neighbor). Mixed-style is pre-existing kit state. |
| Adding `note: "Concrete layer names per project..."` to YAML in task-analysis.md may violate strict YAML schema | LOW | Inspected: task-analysis.md is plain Markdown wrapping illustrative YAML — no strict schema. `note:` is a kit convention used elsewhere in same file (e.g. SKILL.md). Verified compatible. |
| New test script `test-genericity-audit.sh` blocked by global `.gitignore` for `.claude/` | LOW | Will use `git add -f` consistent with existing pattern (test-p1..p5 force-added in commit `c55e9f5`). |

## Out-of-Scope (Repeating Spec §6 for Coder Awareness)

- `examples.md` Go+Python signature comparison — leave as-is (already shows two languages).
- `required-sections.md` L120-140 example_good_go/python code blocks — leave as-is (already has LANGUAGE-agnostic note at L140).
- `architecture-checks.md` pass_criteria text ("API/transport layer", etc.) — leave as-is (uses abstract role labels, gated on ARCHITECTURE_STYLE).
- Slot syntax inconsistency (`{X}` vs `<X>`) — defer to separate audit.

---

**Total estimated effort:** 30-45 minutes for /coder phase. Coder edits 4 files + writes 1 test, runs full test suite, reports verify_status: PASS.
