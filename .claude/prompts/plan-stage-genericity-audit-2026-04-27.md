---
status: draft
audit_date: 2026-04-27
baseline_commit: bc2c2e8
audit_scope: Plan stage (`/planner` + `plan-reviewer` agent + planner-rules + plan-review-rules)
audit_type: fresh — ignored existing `.claude/prompts/post-1.17-symmetry-audit.md` and `plan-stage-generic-spec.md` per user instruction
audit_constraint: tags v1.16.0 → latest are merged baseline; build on top, not against
problems_selected: 5 (per user — quality over quantity)
contracts_preserved:
  - C1 handoff schema (planner_to_plan_review, plan_review_to_coder, plan_review_verdict)
  - C2 verdict envelope (IMP-02)
  - C3 issue ID pattern (IMP-03 `^PR-[0-9a-f]{8}$`)
  - C4 parts_validated[] (IMP-04)
  - C5 PROJECT-KNOWLEDGE.md slot schema (22 slots, pk_schema_version 1.1.0)
  - C6 CLAUDE.md Language Profile cascade (PK > CLAUDE.md > SKIP)
  - C7 inject-review-context.sh 4 KB cap
  - C8 5-value code_review_verdict enum (D1 from post-1.17 audit)
  - C9 D2 coder_to_code_review schema branch (post-1.17 audit)
test_impact:
  - "all 21 existing tests in .claude/scripts/tests/ MUST continue to pass"
  - "2 known pre-existing failures (test-hook-stderr-format, test-imp04 5/36) remain unchanged from current baseline"
  - "no new tests required for these 5 fixes (text-only changes; existing test-p3 already gates Go-token absence in plan-reviewer; new assertions added inline)"
---

# Plan Stage Genericity Audit (Fresh, 2026-04-27)

## 0. Why a Fresh Audit

The user asked for a re-audit of the Plan stage (`/planner` + `plan-reviewer` + their skills) on the post-v1.17.0 baseline (commit `bc2c2e8`), with explicit instructions:

> "На имеющийся план и спеку не обращай внимания, все делаем чисто (вдруг что-то осталось)"

Translation: *ignore the existing plan/spec, do this fresh — in case anything was missed.*

The prior `plan-stage-generic-spec.md` (v1.16.0, commit `42f452c`) and `post-1.17-symmetry-audit.md` (just merged in `c55e9f5`) addressed the obvious surface (extracting per-language `code-shapes/`, adding `DEPENDENCY_FILE`/`INSTALL_VERB`/`ARCHITECTURE_STYLE` slots, formal SKIP-with-NIT semantics). This audit looks deeper — at conversational text, examples, and prompts where Go-isms still leak through despite the slot scaffolding being correct.

## 1. Goal

The Plan stage of `/workflow` MUST be project-agnostic — work identically for Go, Python, TypeScript, Rust, Java, and any user-defined language. "Identically" here means: produces a plan whose layer vocabulary, file paths, and code shapes match the consumer project, NOT the kit's own dogfood Go-isms.

The PROJECT-KNOWLEDGE.md slot system is the abstraction. The cascade `PK > CLAUDE.md > SKIP-with-NIT` is the contract. **The audit looks for places where the slot abstraction is short-circuited by hardcoded reference text.**

## 2. Scope (In / Out)

### In Scope (read in full and audited line-by-line)

| Artifact | Path | Role in Plan stage |
|---|---|---|
| Planner command | `.claude/commands/planner.md` | Phase 1 entry point; produces plan + handoff |
| Plan-reviewer agent | `.claude/agents/plan-reviewer.md` | Phase 2 entry point; produces verdict + issues |
| Planner skill (root) | `.claude/skills/planner-rules/SKILL.md` | Loaded at planner startup |
| Task-analysis | `.claude/skills/planner-rules/task-analysis.md` | Complexity classification (S/M/L/XL) |
| Data-flow | `.claude/skills/planner-rules/data-flow.md` | Layer placement decisions |
| Examples | `.claude/skills/planner-rules/examples.md` | Code-completeness reference |
| Plan-review-rules (root) | `.claude/skills/plan-review-rules/SKILL.md` | Loaded at reviewer startup |
| Architecture-checks | `.claude/skills/plan-review-rules/architecture-checks.md` | Layer-rule validation |
| Required-sections | `.claude/skills/plan-review-rules/required-sections.md` | Plan-template compliance |
| Plan template | `.claude/templates/plan-template.md` | Section structure |
| Handoff schema | `.claude/schemas/handoff.schema.json` | P-stage contracts |

### Out of Scope (verified on inventory but not modified)

- `.claude/commands/coder.md`, `.claude/agents/code-reviewer.md` — C-stage; covered by post-1.17 audit
- `.claude/agents/code-researcher.md`, `.claude/agents/db-explorer/`, `.claude/agents/project-researcher/` — auxiliary, not Plan-stage core
- `.claude/skills/workflow-protocols/` — already language-agnostic per inventory agent
- `.claude/skills/planner-rules/code-shapes/<LANG>.md` — intentional per-language references (kit standard)
- `.claude/rules/go-conventions.md`, `tdd-go/` — explicitly Go-scoped by design (loaded only when LANGUAGE=go)
- Kit's own `CLAUDE.md` Language Profile — kit-as-Go-spec is dogfood, not the audited surface
- 24 hook scripts in `.claude/scripts/` — text-only fix scope; no script changes required

## 3. Plan-stage Artifact Interaction Graph

```
                     ┌──────────────────────────────────────────────────┐
                     │             /workflow (orchestrator)             │
                     └──────────────────────────────────────────────────┘
                                          │ delegates Phase 1
                                          ▼
   ┌────────────────────────────────────────────────────────────────────┐
   │                        /planner (command)                          │
   │  Loaded skills:                                                    │
   │    planner-rules/SKILL.md ─┬─► task-analysis.md (Phase 0)          │
   │                            ├─► data-flow.md     (Phase 2 M/L/XL)   │
   │                            ├─► examples.md      (Phase 4)          │
   │                            ├─► sequential-thinking-guide.md (L/XL) │
   │                            ├─► mcp-tools.md                        │
   │                            └─► code-shapes/<LANGUAGE>.md           │
   │                                resolved from PK→LANGUAGE           │
   │                                                                    │
   │  Reads cascade:  PROJECT-KNOWLEDGE.md  ─►  CLAUDE.md L.Profile     │
   │                                            ─►  SKIP-with-NIT       │
   └────────────────────────────────────────────────────────────────────┘
                                          │ writes
                                          ▼
                  ┌─────────────────────────────────────┐
                  │  .claude/prompts/{feature}.md       │  plan artifact
                  │  .claude/workflow-state/            │  handoff JSON
                  │    {feature}-handoff.json           │  → C1: planner_to_plan_review
                  └─────────────────────────────────────┘
                                          │ validate-handoff.sh (PostToolUse)
                                          │ emit checkpoint.yaml
                                          ▼ delegates Phase 2
   ┌────────────────────────────────────────────────────────────────────┐
   │                  plan-reviewer (agent, isolated context)           │
   │  Loaded skills:                                                    │
   │    plan-review-rules/SKILL.md ─┬─► architecture-checks.md          │
   │                                ├─► required-sections.md            │
   │                                ├─► checklist.md                    │
   │                                └─► troubleshooting.md              │
   │                                                                    │
   │  inject-review-context.sh (SubagentStart, 4 KB cap)                │
   │    injects: feature, complexity, iteration, prior verdicts,        │
   │             PK slots (LANGUAGE, LAYERS, LAYER_RULE,                │
   │             ARCHITECTURE_STYLE, ERROR_WRAP, …)                     │
   └────────────────────────────────────────────────────────────────────┘
                                          │ emits
                                          ▼
                  ┌─────────────────────────────────────┐
                  │  VERDICT: line + VERDICT_JSON block │  → C2: plan_review_verdict
                  │  issues[].id normalized to canonical│  → C3: PR-[0-9a-f]{8}
                  │  parts_validated[] on iter ≥2       │  → C4: IMP-04
                  └─────────────────────────────────────┘
                                          │ save-review-checkpoint.sh (SubagentStop)
                                          │ append review-completions.jsonl
                                          ▼
                              { handoff to /coder OR loop iter+1 }
```

**Genericity contracts active in this graph:**

- The Plan stage MUST never bake language assumptions into its **dynamic output** (the plan, the verdict, the handoff) beyond what PK or CLAUDE.md Language Profile permits.
- **Static reference text** (in skill files, command files) MAY mention specific languages **only inside `<!-- EXAMPLE (lang: …) -->` comment blocks** (kit-standard escape hatch — see `code-shapes/INVARIANTS.md`).
- Hardcoded language tokens **outside** EXAMPLE blocks in the audited surface are bugs.

## 4. Audit Findings (Verified Against Current `main`)

The discovery agents found 7 candidate findings. After verification by direct file reads, I selected 5 with the highest blast radius and best contract-safety profile. Two candidates (`required-sections.md` Go+Python code blocks; `examples.md` two-language signature comparison) were dropped because they already include explicit "language-agnostic" framing notes that disclose the reference-only nature.

### Selected 5 problems (rest of this document)

| ID | Severity | File | One-line summary |
|---|---|---|---|
| G1 | HIGH | planner.md:286-289 | Layer-vocab clarifying question presents Go example FIRST + uses "for Go Clean Architecture:" framing |
| G2 | HIGH | planner.md:329-336 | code-researcher delegation_prompt_example hardcodes `internal/handler/` (Go path) |
| G3 | MEDIUM | planner.md:459-462 | parts_order default pattern uses Go-style "Data access → … → Wiring → Docs" |
| G4 | MEDIUM | plan-reviewer.md:308-310 | location-stability examples use `internal/service/user.go:Update`, `handler.go:42` |
| G5 | MEDIUM | task-analysis.md:84-97, 210 | Complexity examples bake in MVC terms ("controller", "handler", "service", "model") |

## 5. Problem Details

### G1 — Layer-vocabulary clarifying question is Go-biased

**Location:** [.claude/commands/planner.md:284-289](.claude/commands/planner.md#L284-L289)

**Current text:**
```
question: |
  "Layer vocabulary: which layers does your project use, in dependency order
  (lowest → highest)? E.g., for Go Clean Architecture:
  [models, repository, service, handler]; for Django:
  [model, manager, view]; for Spring Boot:
  [entity, repository, service, controller]. Provide a comma-separated list."
```

**Why this is a problem:**
This question fires when `LAYERS` is unset in PROJECT-KNOWLEDGE.md AND `ARCHITECTURE_STYLE` is `layered` (or unset → defaults to `layered` per v1.1.0 schema). It is the user's **first** interactive contact with the Plan stage when they have not yet populated their slots — by definition the high-leverage onboarding moment. Two compounding biases:

1. **Position bias:** Go example appears FIRST in the list (after the "E.g.," lead-in). Users skim and copy the first concrete example — the Go four-layer pattern — even when their stack is Python or Rust.
2. **Framing bias:** "for Go Clean Architecture:" elevates Go to *named architectural reference*, while Django and Spring Boot are presented as unnamed alternatives. The implicit message: "Clean Architecture is the kit's mental model; here are some adaptations."

The downstream effect: planner copies the user's answer into PROJECT-KNOWLEDGE.md as `LAYERS`. A Python user who copied the Go example now has `[models, repository, service, handler]` in their PK — which then drives `LAYER_RULE` validation, Parts ordering, code-shape selection, etc. The wrong layer vocabulary cascades through 8+ downstream consumers (`architecture-checks.md`, `required-sections.md`, `data-flow.md`, `task-analysis.md`, `coder.md`, `code-reviewer.md`).

**Justification (no false-positive claims):**
- Verified Go example comes first by direct file read (line 286: "for Go Clean Architecture:").
- Verified the question is part of `phase_1_clarification` `if_layer_unset` block (lines 274-296), invoked exactly when no LAYERS data exists.
- I am NOT claiming this fixes a "miscalibrated planner" — calibration is correct (slots resolve fine when populated). I AM claiming it removes a Go bias from the slot-population path, which is purely a phrasing/ordering issue.

**Proposed fix:**
Reorder examples alphabetically by stack name (Django → Go → Spring Boot) AND replace "for Go Clean Architecture:" framing with neutral "E.g.:". Example list becomes purely illustrative, no ranked reference.

```
question: |
  "Layer vocabulary: which layers does your project use, in dependency order
  (lowest → highest)? Provide a comma-separated list of layer names. Examples
  from common stacks (use as inspiration, not template):
    - Django:    [model, manager, view]
    - Go:        [models, repository, service, handler]
    - Spring:    [entity, repository, service, controller]
  Your project's vocabulary may differ — use what your codebase actually uses."
```

**Acceptance criteria (G1.1 – G1.4):**
- **G1.1** `planner.md` line containing the clarifying-question example list does NOT have "Go" as the first stack mentioned (alphabetical ordering Django-first is verifiable via grep).
- **G1.2** `planner.md` does NOT contain the literal phrase "for Go Clean Architecture" — the framing must be neutral.
- **G1.3** All three example stacks (Django, Go, Spring) remain present (no information loss; we are de-biasing, not deleting).
- **G1.4** The question still produces actionable user input (the imperative "Provide a comma-separated list" is preserved).

**Contract safety:** None of C1-C9 reference this text. No schema, no handoff field, no test predicate keys off this string. Pure UX/text change.

**Test impact:** Existing tests do not assert this exact wording. We add a new assertion to `test-p3-plan-reviewer-skip.sh` (or a new `test-genericity-audit.sh`) that grep-checks G1.1 and G1.2 inversely.

---

### G2 — code-researcher delegation example bakes in `internal/handler/` (Go path)

**Location:** [.claude/commands/planner.md:329-336](.claude/commands/planner.md#L329-L336)

**Current text:**
```
delegation_prompt_example: |
  Research the codebase for: API handler implementation patterns
  Focus areas:
  - error handling and response formatting in internal/handler/
  - middleware usage patterns
  - input validation approach
  Context: Planning new_feature task, complexity L
```

**Why this is a problem:**
This example is the **template** the planner uses to formulate its delegation prompt to the `code-researcher` agent (Phase 3 RESEARCH, complex_search branch, fires for L/XL or 6+ files / 60% budget consumed). The planner LLM reads this example to learn the shape of a research prompt — and then writes its own variant for the actual task.

The hardcoded `internal/handler/` directory is **invisible Go convention leakage** because:
1. `internal/` is the Go-specific module visibility convention. Python uses `src/`, `<package>/`, or flat. Rust uses `src/`. TypeScript varies (`src/`, `lib/`, monorepo packages). Java uses `src/main/java/<reverse-domain>/`.
2. `handler/` is a Go/Spring naming convention. Express (Node) calls them "routes" or "controllers". Django uses "views". FastAPI uses "routers". Rust Axum uses "handlers" but the directory layout differs.

When the planner LLM sees this example for a Python project, it has two suboptimal options: (a) blindly mimic `internal/handler/` (produces a research prompt that returns 0 files because there is no such directory), or (b) mentally translate to `<some directory>/<some name>` — which adds cognitive load and may produce inconsistent results.

**Justification (no false-positive claims):**
- Verified via direct read that this is in the `complex_search` `delegation_prompt_example` block (line 329).
- Verified that this example is consumed by the planner LLM at delegation time (the planner's Phase 3 documentation references this example as the template).
- I am NOT claiming this currently breaks code-researcher invocation (the agent still runs; it just receives a Go-shaped prompt for non-Go projects). I AM claiming it produces inferior research output for non-Go projects (research prompt → wrong directory hint → noise in the agent's response).

**Proposed fix:**
Wrap the Go-specific example in `<!-- EXAMPLE (lang: go) -->` markers (kit-standard escape) and add a generic counterpart that uses slot syntax consistent with `data-flow.md` (`<INPUT_LAYER>`, `<BUSINESS_LAYER>`, `<DATA_ACCESS_LAYER>`).

```
delegation_prompt_example: |
  Research the codebase for: API handler implementation patterns
  Focus areas:
  - error handling and response formatting in <INPUT_LAYER>
    (resolve from PROJECT-KNOWLEDGE.md → LAYERS[N], or describe by role
    if LAYERS unset)
  - middleware / request-pipeline patterns
  - input validation approach
  Context: Planning new_feature task, complexity L

  <!-- EXAMPLE (lang: go) — for reference only, language-specific phrasing -->
  # Concrete Go example: replace <INPUT_LAYER> with `internal/handler/`
  # Concrete Python example: replace <INPUT_LAYER> with `app/api/` or `<pkg>/views/`
  <!-- end EXAMPLE -->
```

**Acceptance criteria (G2.1 – G2.4):**
- **G2.1** `planner.md` line in the active body of `delegation_prompt_example` does NOT contain literal `internal/handler/` (the string may appear ONLY inside an `<!-- EXAMPLE (lang: go) -->` comment block).
- **G2.2** The delegation prompt template uses slot syntax (`<INPUT_LAYER>` or `{INPUT_LAYER}`, consistent with `data-flow.md` line 18 convention).
- **G2.3** A pointer to the resolution rule (PROJECT-KNOWLEDGE.md → LAYERS[N]) is present in the example, OR a fallback ("describe by role if LAYERS unset") is documented.
- **G2.4** A concrete-Go example remains available in EXAMPLE comment form for kit dogfood (kit IS a Go project — keep the reference).

**Contract safety:** None of C1-C9 reference this template text. No structured handoff field carries this. Schema-safe, contract-safe.

**Test impact:** Add a grep-based assertion in the new `test-genericity-audit.sh` that checks `internal/handler/` does NOT appear in the active body of `planner.md` (excluding `<!-- EXAMPLE` lines), consistent with the existing `test-p3-plan-reviewer-skip.sh` AC-P3.2 predicate pattern.

---

### G3 — parts_order default pattern is Go-style backend stack

**Location:** [.claude/commands/planner.md:459-462](.claude/commands/planner.md#L459-L462)

**Current text:**
```
parts_order:
  note: "Follow dependency direction — lower layers first. Adapt to project structure."
  pattern: "Data access → Models → Domain logic → API/Handlers → Tests → Wiring → Docs"
  reference: "SEE: .claude/PROJECT-KNOWLEDGE.md for project-specific layer order (if available)"
```

**Why this is a problem:**
The `pattern` line is the **default** ordering the planner copies into the Parts section header when generating a plan. The `note` says "Adapt to project structure", and the `reference` points to PK for project-specific order — both correct framings — but the literal `pattern` string is what gets pasted as the default.

Three Go-isms in the default pattern:
1. **"Wiring"** — Go-idiomatic term for dependency injection / `main.go` wire-up (popularized by `wire` codegen library). Python calls it "fixtures" or "app factory". Rust calls it "main" or "initialization". TypeScript uses "DI configuration". Java/Spring uses "configuration class".
2. **"Data access → Models"** — In Go's typical layout, data-access (repositories) sits below models. In Python Django, **Models** sit below data access (the ORM is built on the model). The order is INVERTED for Django.
3. **"Domain logic"** vs **"API/Handlers"** — Go uses "domain" / "handler" terminology. Python frameworks use "service" / "view". Rust Axum/Actix use "service" / "handler". TypeScript NestJS uses "service" / "controller".

The note "Adapt to project structure" is correct guidance, but the literal default is the actual fallback when PK is absent or when the planner LLM defaults to the simpler path. **Defaults matter** — if the default is Go-shaped, Python projects get Go-ordered Parts unless someone explicitly overrides.

**Justification (no false-positive claims):**
- Verified the literal pattern string by direct read (line 461).
- Verified the cascade: when LAYERS slot is populated, planner uses LAYERS order (per architecture-checks.md L41 and required-sections.md L41). When LAYERS is unset, the literal `pattern` here is the fallback.
- I am NOT claiming Go projects are broken (they're not — kit's own dogfood Go project is fine). I AM claiming the fallback for non-Go projects is sub-optimal.
- I am NOT promising that fixing this **automatically** produces correctly-ordered Parts for any project — that requires LAYERS to be populated. I AM claiming the fallback default becomes neutral instead of Go-biased.

**Proposed fix:**
Replace the literal Go-pattern with a slot-templated default consistent with `data-flow.md` `<DATA_ACCESS_LAYER> → <BUSINESS_LAYER> → <INPUT_LAYER>` syntax. Keep "Tests / Setup / Docs" as universal terms (these are language-agnostic). Drop "Wiring" specifically.

```
parts_order:
  note: |
    Follow dependency direction — lower layers first. Concrete layer names
    resolve from PROJECT-KNOWLEDGE.md → LAYERS (lowest-to-highest).
  pattern_when_layers_set: "{LAYERS[0]} → {LAYERS[1]} → ... → {LAYERS[N]} → Tests → Setup → Docs"
  pattern_when_layers_unset: "<DATA_ACCESS_LAYER> → <BUSINESS_LAYER> → <INPUT_LAYER> → Tests → Setup → Docs"
  fallback_skip_rule: "If LAYERS unset AND ARCHITECTURE_STYLE != layered, planner SKIPS layer-prefix in Parts headings and uses functional grouping (input handling → core logic → output → tests → setup → docs); plan-reviewer emits consolidated NIT noting layer-allocation was skipped."
  reference: "SEE: .claude/PROJECT-KNOWLEDGE.md for project-specific layer order"
```

**Acceptance criteria (G3.1 – G3.5):**
- **G3.1** `planner.md` lines 459-462 do NOT contain the literal word "Wiring" (Go-specific term).
- **G3.2** `planner.md` parts_order pattern uses slot syntax (`{LAYERS[N]}` or `<LAYER_ROLE>`) consistent with `data-flow.md` lines 18-20 abstract-slot convention (verifiable: grep `<DATA_ACCESS_LAYER>\|{LAYERS\[` returns ≥1 hit in the parts_order block).
- **G3.3** "Tests" and "Setup" (replacing "Wiring") and "Docs" remain present — these are universal stages.
- **G3.4** The note explicitly references PROJECT-KNOWLEDGE.md → LAYERS for resolution.
- **G3.5** A `fallback_skip_rule` (or equivalent) is documented for the LAYERS-unset / non-layered case, consistent with the canonical SKIP-with-NIT pattern from `architecture-checks.md` L23-34.

**Contract safety:**
- C1 (handoff schema) — no field carries this pattern text; no impact.
- C5 (PK schema) — no slot is added/removed.
- C6 (cascade) — fix REINFORCES cascade by making the LAYERS-unset fallback explicit (currently implicit Go-default).
- C7 (4 KB cap) — `inject-review-context.sh` injects PK content, not this pattern text. No size impact.

**Test impact:**
- Existing `test-p4-required-sections-skip.sh` AC-P4.1 already asserts "data → business → api" fallback is gone from `required-sections.md`. We add a parallel assertion for `planner.md` parts_order block in the new `test-genericity-audit.sh`.
- No existing test asserts the literal "Wiring" → safe to add inversely.

---

### G4 — Location-stability examples in plan-reviewer use Go path/extension

**Location:** [.claude/agents/plan-reviewer.md:308-310](.claude/agents/plan-reviewer.md#L308-L310)

**Current text:**
```markdown
**Location-stability guidance (IMP-03 KD-8):** prefer function / symbol name over line number in the `location` field. Line numbers shift when code is edited, which changes the hash → breaks ID continuity across iterations. Examples:
- PREFER: `"Part 3: UserHandler.Create"` or `"internal/service/user.go:Update"` (stable across edits)
- AVOID: `"handler.go:42"` alone (drift-prone)
```

**Why this is a problem:**
This guidance teaches plan-reviewers (LLM agents) **how to format the `location` field** in their issue records. The location string is then hashed (with `category` and `problem`) by `save-review-checkpoint.sh` to compute the canonical IMP-03 issue ID `PR-<8hex>`. Stable IDs across iterations require stable location strings.

Two Go-isms in the examples:
1. **`internal/service/user.go`** — Go's `internal/` directory + `service` layer naming + `.go` extension. None of these are universal.
2. **`handler.go:42`** — Go's `handler` term + `.go` extension.

The intent of the guidance ("prefer symbol name over line number") is **language-agnostic and correct**. The Go-specific examples are *just illustrations*, but they teach the reviewer LLM that file extensions and Go-style paths are normal — which is wrong for Python/Rust/TypeScript reviewers.

**Practical risk:** Imagine a Python project running plan-review. The reviewer writes `location: "src/services/user.py:Update"` — that *also* contains a file extension (`.py`). The location string changes if the file is renamed (e.g. `user.py` → `user_service.py`), which **breaks the canonical ID**, causing the orchestrator's regression-detection to think the issue is new on iter 2+. The fix is to teach reviewers to **prefer symbol-only location** (e.g. `"UserService.update"`) and **avoid file extensions**, which is exactly what IMP-03 KD-8 already prescribes — just with examples that contradict the guidance.

**Justification (no false-positive claims):**
- Verified the literal text by direct read (lines 308-310).
- Verified IMP-03 KD-8 is the canonical ID stability rule (referenced earlier in plan-reviewer.md L304-306, which mentions hash inputs `category|location|problem`).
- I am NOT claiming canonical IDs currently mis-hash (the hash is computed correctly from whatever string the reviewer emits). I AM claiming the examples teach reviewers to emit Go-shaped locations even on non-Go projects, which is suboptimal for ID stability.

**Proposed fix:**
Replace Go-extension examples with language-agnostic forms. Keep two examples to teach the lesson "symbol-only > file-with-symbol > line-only".

```markdown
**Location-stability guidance (IMP-03 KD-8):** prefer function / symbol name over line number in the `location` field. Line numbers shift when code is edited, which changes the hash → breaks ID continuity across iterations. File extensions and project-specific path prefixes also drift (refactors, language ports, monorepo restructuring). Examples (language-agnostic):
- PREFER: `"Part 3: UserHandler.Create"` (Part-anchored symbol name — most stable)
- ACCEPT: `"<source-glob-relative-path>:Update"` (path + symbol — stable until file rename)
- AVOID: `"<filename>:42"` (line number alone — drift-prone)

**Note:** match path conventions to the project's `SOURCE_GLOB` slot (PROJECT-KNOWLEDGE.md). Avoid hardcoding language-specific prefixes (`internal/`, `src/`, `lib/`) or file extensions (`.go`, `.py`, `.ts`) in the example template — those vary per project.
```

**Acceptance criteria (G4.1 – G4.4):**
- **G4.1** `plan-reviewer.md` lines 308-312 (or wherever the location-stability guidance lives) do NOT contain literal `.go`, `internal/`, `handler.go`, `service/user.go`.
- **G4.2** Example list keeps **at least 2 examples** to teach the gradient (symbol-only > path+symbol > line-only).
- **G4.3** Symbol-only example (Part-anchored `Part N: ClassName.methodName`) is presented FIRST as the canonical preferred form.
- **G4.4** A note pointing to `SOURCE_GLOB` slot for project-specific path conventions is added (slot reference, not literal path).

**Contract safety:**
- C3 (IMP-03 issue ID pattern `^PR-[0-9a-f]{8}$`) — UNCHANGED. The pattern is computed by `save-review-checkpoint.sh` regardless of input string shape. We're improving input quality, not changing the hash function.
- C2 (verdict envelope) — schema's `issues[].location` field accepts any string; no constraint on shape.
- IMP-03 normalization logic in `save-review-checkpoint.sh` is unchanged.

**Test impact:**
- Existing `test-save-review-checkpoint.sh` validates the IMP-03 normalization function (canonical ID computation). The fix does NOT touch that function — pure text change to the documentation.
- Add grep-based assertion in `test-genericity-audit.sh` that `plan-reviewer.md` location-stability section does not contain `.go` literal.

---

### G5 — Task-analysis complexity examples bake in MVC layer terminology

**Location:**
- [.claude/skills/planner-rules/task-analysis.md:84-85](.claude/skills/planner-rules/task-analysis.md#L84-L85) (L complexity examples)
- [.claude/skills/planner-rules/task-analysis.md:96-97](.claude/skills/planner-rules/task-analysis.md#L96-L97) (XL complexity examples)
- [.claude/skills/planner-rules/task-analysis.md:209-210](.claude/skills/planner-rules/task-analysis.md#L209-L210) (Example 2: New API Endpoint, complexity rationale)

**Current text:**
```yaml
# L complexity:
examples:
  - "New endpoint with database → domain → API"
  - "Refactor controller by splitting into services"

# XL complexity:
examples:
  - "New domain with full stack (DB → models → controller → API → tests)"
  - "Integration with external service"

# Example 2 rationale (L210):
Complexity: L (5 Parts: DB query + model + controller + handler + tests)
```

**Why this is a problem:**
Task-analysis runs at **Phase 0** of the workflow — the very first thing after the user submits a task. Complexity classification examples are the user's first signal of "how the kit thinks about layers". The current examples use **MVC stack terminology** ("controller", "service", "handler", "model") as if it's universal vocabulary — fine for Spring Boot, awkward for:

- **Event-driven Rust services** — no "controllers"; events flow through subscribers/publishers
- **Hexagonal Java applications** — "ports/adapters" terminology
- **Functional TypeScript (Effect-TS, fp-ts)** — no MVC layers; pipelines and effects
- **Flask microservices in Python** — "blueprints" + "models", no separate "controllers"
- **Django** — "views" not "controllers"

Particular issues:
1. L:84 "Refactor controller by splitting into services" — Spring Boot specific.
2. L:96-97 "DB → models → controller → API → tests" — combines Spring's "controller" with Go's "API" (already inconsistent), and "DB" first vs "models" second is Spring/JPA-specific (Django inverts).
3. L:210 "5 Parts: DB query + model + controller + handler + tests" — uses BOTH "controller" AND "handler" (typically these are synonyms in different stacks; using both implies a dual-layer that not all projects have).

**Justification (no false-positive claims):**
- Verified all three locations by direct read.
- Verified task-analysis.md is loaded by planner-rules/SKILL.md as a "ALWAYS load" reference for full classification details (per SKILL.md L45).
- I am NOT claiming complexity classification is currently broken — the table at SKILL.md L22-27 (S/M/L/XL by Parts/Layers/Files counts) works regardless of layer names. I AM claiming the examples set wrong expectations for non-MVC stacks and lower onboarding quality for those users.

**Proposed fix:**
Rephrase using **architecture-neutral terminology** — "storage", "domain/business", "input/API", "tests" — which is widely understood across MVC, hexagonal, event-driven, and flat architectures. Drop the "controller" / "handler" duality. Mention slot resolution for projects that have populated LAYERS.

```yaml
# L complexity:
examples:
  - "New endpoint touching storage → domain → input/API layers"
  - "Refactor a layer by splitting concerns across modules"
note: "Concrete layer names per project — see PROJECT-KNOWLEDGE.md → LAYERS"

# XL complexity:
examples:
  - "New domain with full stack (storage → entities → business → API → tests)"
  - "Integration with external service"
  - "Plugin/event-driven architecture across multiple boundaries"
note: "Layer terminology shown is illustrative; resolve concrete names from PROJECT-KNOWLEDGE.md → LAYERS"

# Example 2 rationale (L210):
Complexity: L (5 Parts: data query + entity + business + API + tests)
```

**Acceptance criteria (G5.1 – G5.5):**
- **G5.1** `task-analysis.md` lines 84-85 (L complexity examples) do NOT contain literal "controller" or "service" outside `<!-- EXAMPLE (lang: …) -->` blocks.
- **G5.2** `task-analysis.md` lines 96-97 (XL complexity examples) do NOT contain literal "controller" outside EXAMPLE blocks. (Replaced with "business" or "domain".)
- **G5.3** `task-analysis.md` line 210 (Example 2 rationale) does NOT contain BOTH "controller" AND "handler" simultaneously. At most one layer term, OR replaced with abstract "API" / "business".
- **G5.4** New "note" line(s) reference PROJECT-KNOWLEDGE.md → LAYERS for project-specific resolution (slot pointer, not literal value).
- **G5.5** Replacement terminology is drawn from a documented architecture-neutral set (storage / data / entities / business / domain / API / input / output / tests) — NOT MVC-specific (controller / view / handler).

**Contract safety:**
- No schema field carries these example strings.
- No test predicate currently asserts these specific words. Verified by `grep -rn "controller" .claude/scripts/tests/` — returns no matches relevant to task-analysis content.

**Test impact:** Add new `test-genericity-audit.sh` script with G5.1 - G5.3 grep predicates.

## 6. Out of Scope (explicit list of NOT-doing)

To honor the user's "5 problems, do them well" constraint, the following candidates were considered and EXPLICITLY deferred:

| Candidate | Why deferred |
|---|---|
| `examples.md` L8: `func Get(id string) error` (Go) / `def get(id): ...` (Python) | Already shows BOTH languages explicitly — not Go-only — and frames as "bad signature-only stub" (an anti-pattern, not a normative reference). Acceptable as-is. |
| `required-sections.md` L120-140: Go+Python `example_good_*` code blocks | Already includes `note` (L140) explicitly framing as LANGUAGE-SPECIFIC reference shapes per `code-shapes/`. Acceptable framing. |
| `architecture-checks.md` L60-64 `pass_criteria` text ("API/transport layer", "Business-layer") | Uses abstract role labels, not concrete Go terms. The layer-check predicate (L27-32) already gates these checks on `ARCHITECTURE_STYLE = layered`, so non-layered styles SKIP. Acceptable. |
| Slot syntax inconsistency `{SLOT}` vs `<SLOT>` vs `LAYERS[N]` | Real issue (kit standard is curly `{SLOT}` per CLAUDE.md schema doc, but `data-flow.md` uses angle `<SLOT>`). Style cleanup, not a genericity gap. Defer to separate audit. |
| `LANGUAGE` slot validation: what if user sets LANGUAGE=ruby? | Falls back to `code-shapes/_default.md` per `examples.md` L25 — current behavior is correct. No fix needed. |
| Testing on a real Python project | Out of scope — manual operator procedure documented in audit conclusion as a recommended verification step. |

## 7. Implementation Plan (Hand-off to Phase 1 Planner)

**Total file changes:** 4 files modified, 1 file created (test).

| File | Edit | Problem |
|---|---|---|
| `.claude/commands/planner.md` | text edits at lines 286-289, 332, 459-462 | G1, G2, G3 |
| `.claude/agents/plan-reviewer.md` | text edits at lines 308-310 | G4 |
| `.claude/skills/planner-rules/task-analysis.md` | text edits at lines 84-97, 210 | G5 |
| `.claude/scripts/tests/test-genericity-audit.sh` | NEW file with G1.1, G2.1, G3.1, G4.1, G5.1-G5.3 grep predicates | All 5 |

**Estimated lines changed:** ~25 source lines + ~80 lines new test script.

**Estimated implementation time:** 30-45 minutes (text edits, no logic).

**Test plan:**
1. Run `test-genericity-audit.sh` — must pass all 5 problem predicates.
2. Run all 21 existing tests — must keep current PASS state (19/21 PASS, 2 pre-existing baseline failures unchanged).
3. Manual dogfood: re-run `/planner` on a fresh task in the kit; verify no regression in plan output for the kit's own Go context.

## 8. Contract Verification Checklist (Pre-Merge)

Before any commit:

- [ ] `git grep -nE 'internal/handler/|handler\.go:|internal/service/.*\.go:' -- .claude/commands/planner.md .claude/agents/plan-reviewer.md` returns **only** matches inside `<!-- EXAMPLE (lang: go) -->` comment blocks (or no matches at all).
- [ ] `git grep -F 'for Go Clean Architecture' -- .claude/commands/planner.md` returns no matches.
- [ ] `git grep -F 'Wiring' -- .claude/commands/planner.md` returns no matches in active body.
- [ ] `bash .claude/scripts/tests/test-validate-handoff.sh` — 18/18 PASS (handoff schema unchanged).
- [ ] `bash .claude/scripts/tests/test-save-review-checkpoint.sh` — PASS (IMP-03 normalization unchanged).
- [ ] `bash .claude/scripts/tests/test-p3-plan-reviewer-skip.sh` — PASS (P3 ACs preserved; we strengthen the predicate to extend to plan-reviewer.md location-stability text).
- [ ] `bash .claude/scripts/tests/test-genericity-audit.sh` — NEW; 5/5 PASS.
- [ ] `git diff .claude/schemas/handoff.schema.json` — empty (no schema changes).
- [ ] `git diff .claude/PROJECT-KNOWLEDGE.md.example` — empty (no slot changes).
- [ ] `git diff .claude/scripts/inject-review-context.sh` — empty (4 KB cap unchanged).

## 9. Why Exactly These 5 (and not 4 or 6)

User constraint: focus on 5 problems, do them well. The 7 candidate findings naturally divided as:

- **5 high-leverage gaps with clean ACs and zero contract risk** (G1-G5 in this doc).
- **2 marginal cases with explicit framing notes already in place** (already-noted in §6 Out of Scope).

Picking fewer (3 or 4) would leave high-impact gaps (G1's onboarding moment, G3's default Parts order). Picking more (6 or 7) would add fixes that are already half-mitigated by existing framing notes — diminishing returns and risk of touching files that are already well-shaped (e.g. `required-sections.md` L120-140 with its existing LANGUAGE-SPECIFIC clarifying note).

The selected 5 cover:
1. The **first user-facing question** (G1 — clarification when LAYERS unset)
2. The **planner-to-researcher delegation prompt** (G2 — research scope shaping)
3. The **default Parts ordering** (G3 — most-frequent fallback path)
4. The **reviewer's location formatting** (G4 — IMP-03 ID stability propagation)
5. The **first-touch task classification examples** (G5 — Phase 0 onboarding signal)

Each is in a different artifact (no within-file conflicts), each has independent ACs, and all five compose into one coherent text-only PR.

## 10. References

- `.claude/PROJECT-KNOWLEDGE.md.example` — canonical 22-slot schema (`pk_schema_version: 1.1.0`)
- `.claude/skills/planner-rules/code-shapes/INVARIANTS.md` — per-language code-shape conventions, including `<!-- EXAMPLE (lang: …) -->` comment-block standard
- `.claude/skills/plan-review-rules/architecture-checks.md` L23-34 — canonical SKIP-with-NIT rule
- `.claude/scripts/tests/test-p3-plan-reviewer-skip.sh` — existing P3 AC tests (model for new test script)
- `CLAUDE.md` — Language Profile cascade contract `PK > CLAUDE.md > SKIP`
- Prior audit: `.claude/prompts/post-1.17-symmetry-audit.md` (covered C-stage symmetry gaps; this doc covers Plan-stage genericity gaps — non-overlapping scope)
