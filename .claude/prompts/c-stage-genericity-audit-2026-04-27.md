---
status: draft
audit_date: 2026-04-27
baseline_commit: 9ed4d66
audit_scope: C-stage (`/coder` + `code-reviewer` agent + coder-rules + code-review-rules)
audit_type: fresh — ignored existing `.claude/prompts/coder-stage-generic-spec.md` and `post-1.17-symmetry-audit.md` per user instruction
audit_constraint: tags v1.16.0 → latest are merged baseline; build on top, not against
problems_selected: 5 (per user — quality over quantity)
mirrors_p_stage_audit: ".claude/prompts/plan-stage-genericity-audit-2026-04-27.md (G1-G5, commit 27ab4f7)"
contracts_preserved:
  - C1 handoff schema (existing $handoff_contract values, all oneOf branches)
  - C2 verdict envelope (sentinel, fence, severity enum)
  - C3 checkpoint YAML 12 core fields
  - C4 file paths .claude/workflow-state/, .claude/prompts/
  - C5 PK schema 22 slots (no slot additions)
  - C6 PK injection 4 KB cap (inject-review-context.sh)
  - C7 5-value code_review_verdict enum (post-1.17 D1)
  - C8 IMP-03 issue ID `^CR-[0-9a-f]{8}$`
  - C9 IMP-04 parts_validated[] + diff-manifest format
test_impact:
  - "all 22 existing tests in .claude/scripts/tests/ MUST continue to pass (current baseline 22/22 PASS after commit 9ed4d66)"
  - "no schema changes; no hook changes; pure text/config refactor"
  - "1 new test script test-c-stage-genericity-audit.sh asserts CG1-CG5 ACs via grep predicates"
---

# C-Stage Genericity Audit (Fresh, 2026-04-27)

## 0. Why a Fresh Audit (Symmetric to P-stage G1..G5)

The user asked for a fresh re-audit of C-stage (`/coder` + `code-reviewer`) on the post-9ed4d66 baseline, mirroring the P-stage genericity audit just merged in commits `27ab4f7` (G1-G5) and `1a53eee` (CR-001/CR-002 polish). User instruction:

> "В соответствии с нашими правками в Plan (Теги релизов с версии 1.16 по latest включительно) мы должны привести стадии Coder и Code Reviewer в соответствие стадиям Planner и Plan Reviewer."

Translation: *Bring Coder + Code-Reviewer stages into alignment with our Plan-stage edits (releases v1.16 through latest), so the entire Plan + Coder + Reviewer pipeline is generic.*

The prior `coder-stage-generic-spec.md` (v1.17.0, commit `a3d0752`) and `post-1.17-symmetry-audit.md` (v1.17.0+1.17.1, commits `c55e9f5`, `cd265e9`) addressed structural genericity (C1-C5: code-shapes reuse, VERIFY cascade, import-matrix SKIP, slot consumption, schema additions). This audit looks deeper — at conversational text, examples, and configuration where Go-isms still leak through despite the slot scaffolding being structurally correct.

Each finding maps to a P-stage G-fix to make the symmetry obvious:

| C-stage finding | Mirrors P-stage fix |
|---|---|
| CG1 — tdd-go skill auto-loaded ungated | (no direct P-mirror; new C-stage gap) |
| CG2 — GET CHANGES example file list hardcoded `internal/{handler,service}/*.go` | G2 (planner.md delegation_prompt_example) |
| CG3 — settings.json worktree sparsePaths Go-shaped | (no direct P-mirror; configuration variant of G3) |
| CG4 — IMP-03 location examples use `internal/service/*.go`, `handler/auth.go`, `.go:line` | G4 (plan-reviewer.md L308-312) — direct mirror |
| CG5 — coder-rules RULE_3 hardcodes "handler/API layer" terminology | G5 (task-analysis.md MVC term replacement) |

## 1. Goal

The C-stage of `/workflow` MUST be project-agnostic in the same sense the P-stage was just made project-agnostic: produce code/review output whose paths, layer terms, and configuration match the consumer project, NOT the kit's Go-isms. The `PK > CLAUDE.md > SKIP-with-NIT` cascade is correct structurally; this audit closes residual Go-leakage in **prompt text and configuration defaults** that the cascade alone does not fix.

## 2. Scope (In / Out)

### In Scope (read in full and audited line-by-line)

| Artifact | Path | Role in C-stage |
|---|---|---|
| Coder command | `.claude/commands/coder.md` | Phase 3 entry point; produces code + verify_status + handoff |
| Code-reviewer agent | `.claude/agents/code-reviewer.md` | Phase 4 entry point; produces verdict + issues + handoff |
| Coder skill (root) | `.claude/skills/coder-rules/SKILL.md` | Loaded at coder startup |
| Coder examples | `.claude/skills/coder-rules/examples.md` | Code patterns reference |
| Coder review-response | `.claude/skills/coder-rules/review-response.md` | Phase 0.5 re-entry |
| Code-review-rules (root) | `.claude/skills/code-review-rules/SKILL.md` | Loaded at reviewer startup |
| Code-review examples | `.claude/skills/code-review-rules/examples.md` | Architecture/error patterns |
| Settings (worktree) | `.claude/settings.json` `worktree.sparsePaths` block | Configuration consumed during code-reviewer worktree creation (C-stage) |

### Out of Scope (verified on inventory but not modified)

- `.claude/commands/planner.md`, `.claude/agents/plan-reviewer.md`, `.claude/skills/planner-rules/`, `.claude/skills/plan-review-rules/` — P-stage; covered by G1-G5 audit
- `.claude/skills/workflow-protocols/` — language-agnostic per C-stage inventory
- Kit's own `CLAUDE.md` Language Profile + `.claude/PROJECT-KNOWLEDGE.md` — kit-as-Go-spec dogfood; not the audited surface
- `.claude/skills/tdd-go/` — explicitly Go-scoped by name; CG1 addresses *how this skill is loaded*, not the skill's content
- `.claude/scripts/auto-fmt-go.sh`, `pre-commit-build.sh`, `import-matrix-prompt.sh` — Go-scoped by name and use `.go` matchers in settings.json (correct gating already in place)
- `.claude/rules/handler-rules.md`, `service-rules.md`, etc. — layer-rule files are Go-specific by their own design; separate audit concern
- `.claude/skills/code-review-rules/security-checklist.md` — OWASP-driven, generic by content
- 24 hook scripts in `.claude/scripts/` not listed above — text-only fix scope, no script changes required
- All test-c{1-5}*.sh — pre-existing AC tests covering structural C-stage genericity (verified PASS on baseline)

## 3. C-stage Artifact Interaction Graph

```
                     ┌──────────────────────────────────────────────────┐
                     │             /workflow (orchestrator)             │
                     └──────────────────────────────────────────────────┘
                                          │ delegates Phase 3
                                          ▼
   ┌────────────────────────────────────────────────────────────────────┐
   │                         /coder (command)                           │
   │  Loaded skills:                                                    │
   │    coder-rules/SKILL.md ─┬─► examples.md       (Phase 2)           │
   │                          ├─► spec-check.md     (Phase 3.5 L/XL)    │
   │                          ├─► review-response.md (Phase 0.5 reentry)│
   │                          ├─► checklist.md                          │
   │                          ├─► troubleshooting.md                    │
   │                          └─► mcp-tools.md                          │
   │                                                                    │
   │  Conditional skills:                                               │
   │    tdd-go/SKILL.md      (when plan has '## TDD' heading)  ◄── CG1  │
   │    systematic-debugging (when VERIFY fails 3x)                     │
   │    simplify (Phase 2.5 when L/XL AND parts >= 5)                   │
   │                                                                    │
   │  VERIFY cascade (Phase 3): PK → CLAUDE.md → SKIP                   │
   │  Slots consumed: VERIFY_CMD, FMT_CMD, LINT_CMD, TEST_CMD,          │
   │                  DEPENDENCY_FILE, INSTALL_VERB, LAYERS,            │
   │                  LAYER_RULE, ERROR_WRAP, DOMAIN_PROHIBIT,          │
   │                  GENERATED_PATTERN, MOCK_PATTERN  ◄── CG5 in RULE_3│
   └────────────────────────────────────────────────────────────────────┘
                                          │ writes
                                          ▼
                  ┌─────────────────────────────────────┐
                  │  Source files (per plan Parts)      │
                  │  .claude/workflow-state/            │
                  │    {feature}-handoff.json           │ → coder_to_code_review (C8/C9 schema)
                  │    {feature}-checkpoint.yaml        │
                  └─────────────────────────────────────┘
                                          │ git commit (mandatory pre-review)
                                          │ validate-handoff.sh (PostToolUse, IMP-01)
                                          ▼ delegates Phase 4 (worktree-isolated)
   ┌────────────────────────────────────────────────────────────────────┐
   │                  code-reviewer (agent, worktree)                   │
   │  Loaded skills:                                                    │
   │    code-review-rules/SKILL.md ─┬─► security-checklist.md           │
   │                                ├─► examples.md                     │
   │                                ├─► checklist.md                    │
   │                                └─► troubleshooting.md              │
   │                                                                    │
   │  inject-review-context.sh code-reviewer (SubagentStart, 4 KB cap)  │
   │    injects: feature, complexity, iteration, verify_status,         │
   │             prior verdicts, delta-review block (if mode != off)    │
   │             ◄── CG2 (GET CHANGES file-list example), CG4 (location)│
   │                                                                    │
   │  Worktree (sparse checkout per settings.json sparsePaths)  ◄── CG3 │
   └────────────────────────────────────────────────────────────────────┘
                                          │ emits
                                          ▼
                  ┌─────────────────────────────────────┐
                  │  VERDICT: line + VERDICT_JSON block │  → C2/C7 envelope
                  │  issues[].id normalized to canonical│  → C8 CR-[0-9a-f]{8}
                  │  parts_validated[] on iter ≥2       │  → C9 IMP-04
                  └─────────────────────────────────────┘
                                          │ save-review-checkpoint.sh (SubagentStop)
                                          │ append review-completions.jsonl
                                          ▼
                              { handoff to /completion OR loop iter+1 }
```

**Genericity contracts active in this graph (mirror P-stage):**

- The C-stage MUST never bake language assumptions into its **dynamic output** (the code, the verdict, the handoff) beyond what PK or CLAUDE.md Language Profile permits.
- **Static reference text** (in command files, agent files, skill MD files, settings.json comments) MAY mention specific languages **only inside `<!-- EXAMPLE (lang: …) -->` comment blocks** OR as **slot-resolved placeholders** (`{LAYER_RULE}`, `<INPUT_LAYER>`, etc.).
- Hardcoded language tokens **outside** EXAMPLE blocks in the audited surface are bugs.
- Configuration defaults (settings.json) MAY ship with kit's Go shape for backwards-compat, BUT must surface a startup signal to non-Go users that override is required.

## 4. Audit Findings (Verified Against Current `main`, commit 9ed4d66)

The discovery agents found 12 candidate findings (5 HIGH / 4 MEDIUM / 3 LOW). After verification by direct file reads, I selected 5 with the highest blast radius and best contract-safety profile. Findings deferred:

- 4 MEDIUM/LOW that are already-mitigated (slot-resolved phrases like coder.md L77 `command_used:` field with multi-language examples in slot braces).
- 3 LOW that are documentation/permissions clarity gaps in kit dogfood (CLAUDE.md race detector, settings.json permissions list, auto-fmt-go.sh README).

### Selected 5 problems

| ID | Severity | Where | What's wrong | P-stage mirror |
|---|---|---|---|---|
| **CG1** | HIGH | [coder.md:160-163](.claude/commands/coder.md#L160-L163) | `tdd-go` skill auto-loaded when plan contains `## TDD` heading — no `LANGUAGE` slot gate. Loading Go-specific TDD patterns into a Python/Rust/TS coder context. | (no direct P-mirror) |
| **CG2** | HIGH | [code-reviewer.md:188-189](.claude/agents/code-reviewer.md#L188-L189) | Delta-review GET CHANGES example file list hardcodes `internal/handler/user.go`, `internal/service/user.go` in active prose (not in EXAMPLE comment block). | G2 |
| **CG3** | HIGH | [settings.json:434-441](.claude/settings.json#L434-L441) | Worktree `sparsePaths` ships kit-default Go shape (`internal/`, `cmd/`, `go.mod`, `go.sum`, `Makefile`). Code-reviewer running in sparse worktree on non-Go projects gets empty/wrong checkout. | (config variant of G3) |
| **CG4** | HIGH | [code-reviewer.md:238,274,300,301](.claude/agents/code-reviewer.md#L238) | IMP-03 location-stability examples + Output Format spec + VERDICT_JSON example use `path/file.go:line`, `internal/service/foo.go:42`, `internal/service/user.go:Update`, `handler/auth.go:login_handler`, `user.go:42` — Go path + `.go` extension throughout. 5 lines affected. | G4 — direct mirror |
| **CG5** | MEDIUM | [coder-rules/SKILL.md:13,91](.claude/skills/coder-rules/SKILL.md#L13) | RULE_3 wording "tags belong in DTOs at handler/API layer" — Go/Spring-speak. Python uses "view"/"endpoint", Express uses "controller/route". | G5 |

## 5. Problem Details

### CG1 — `tdd-go` skill auto-loaded without `LANGUAGE` gate

**Location:** [.claude/commands/coder.md:160-163](.claude/commands/coder.md#L160-L163) and [.claude/commands/coder.md:367-370](.claude/commands/coder.md#L367-L370)

**Current text (L160-163):**
```yaml
    - step: 5
      action: "Conditionally load tdd-go skill if plan has TDD section"
      condition: "Plan file contains '## TDD' heading"
      files:
        - ".claude/skills/tdd-go/SKILL.md"
      purpose: "Load TDD Red-Green-Refactor workflow. If ## TDD absent — skip, use standard implement→test flow."
```

**Why this is a problem:**
The skill is named `tdd-go` and ships Go-only TDD patterns: `t.Run` table tests, `*testing.T` signatures, `go test -race` invocations, Go assert idioms. The condition gate (`Plan file contains '## TDD' heading`) is purely textual — it triggers the load on *any* project where the plan has a TDD section, including Python (pytest), Rust (`#[test]`), TypeScript (jest/vitest), Java (JUnit) projects. A Python project with `## TDD` in the plan will load Go test patterns into the coder LLM, producing Go-shaped pytest code (`t.Run`-style nesting, `testing.T` references) that breaks on the first lint pass.

The kit ships `tdd-go` as a Go-specific reference — there's no `tdd-python.md` / `tdd-rust.md` / `tdd-typescript.md` / `_default.md` analogue. Until those exist, the skill load must be gated on `LANGUAGE == 'go'`.

**Justification (no false-positive claims):**
- Verified by direct read: condition at L161 is purely textual, no LANGUAGE check.
- Verified by read of `.claude/skills/tdd-go/SKILL.md`: file is Go-specific (table-driven tests, `testing.T`, `go test -race`).
- I am NOT claiming the kit must ship per-language TDD skills (that's scope creep). I AM claiming the load gate must be language-aware so non-Go projects do not pollute their coder LLM with Go test idioms.
- I am NOT claiming this currently breaks the kit's own dogfood (kit IS a Go project, so `tdd-go` is appropriate). I AM claiming any non-Go consumer hits this immediately.

**Proposed fix:**
Tighten the condition gate to require BOTH the plan section AND the language match. When `LANGUAGE != 'go'` AND the plan has `## TDD`, log a SKIP-with-NIT noting that language-specific TDD reference is unavailable and the coder should use generic TDD principles (red-green-refactor).

```yaml
    - step: 5
      action: "Conditionally load tdd-go skill if plan has TDD section AND LANGUAGE=go"
      condition: "Plan file contains '## TDD' heading AND PROJECT-KNOWLEDGE.md → LANGUAGE == 'go' (or unset, treating kit-default as Go)"
      files:
        - ".claude/skills/tdd-go/SKILL.md"
      skip_behavior: |
        If '## TDD' is present BUT LANGUAGE != 'go':
          - SKIP loading tdd-go (kit ships Go-only TDD patterns).
          - Emit consolidated NIT in handoff.deviations_from_plan: "TDD section present but
            kit lacks language-specific TDD reference for {LANGUAGE}; coder applied generic
            red-green-refactor (write failing test → minimal implementation → refactor)."
          - Coder applies language-agnostic TDD principles: write failing test before
            implementation, keep test simple, refactor only after green.
      purpose: "Load TDD Red-Green-Refactor workflow for Go projects. If ## TDD absent OR LANGUAGE != go — skip with NIT, use generic TDD flow."
```

Same gate applied to L367-370 reference.

**Acceptance criteria (CG1.1 – CG1.4):**
- **CG1.1** `coder.md` step 5 condition contains both `'## TDD' heading` AND `LANGUAGE` slot reference (verifiable: grep for both in step 5 block).
- **CG1.2** A `skip_behavior:` block (or equivalent) documents the SKIP-with-NIT path for non-Go projects with TDD plans.
- **CG1.3** The phrase `kit ships Go-only TDD patterns` (or equivalent acknowledgment) is present in the skip rationale.
- **CG1.4** L367-370 reference inside `phase_implement_tdd_red:` block is consistent — also gated on `LANGUAGE == 'go'`.

**Contract safety:**
- C1-C9 all unchanged. No schema field, no handoff field, no test predicate keys off the load condition.
- The `tdd-go` skill content itself is unchanged — we only change *when* it loads.
- Backwards-compatible: kit's own dogfood (Go) keeps loading the skill; non-Go consumers gracefully SKIP.

**Test impact:** new test predicate in `test-c-stage-genericity-audit.sh` greps coder.md step 5 for `LANGUAGE`. No existing test asserts the unconditional load.

---

### CG2 — Delta-review GET CHANGES example file list hardcoded

**Location:** [.claude/agents/code-reviewer.md:183-192](.claude/agents/code-reviewer.md#L183-L192)

**Current text:**
```markdown
**Block structure (example):**
```
[Iter 2 focus — delta only] (mode: warn)
HINT: focus on changed files first — full branch diff accessible via git diff $BASE...HEAD
Files changed since iter 1 (prior_sha=b5685fd..HEAD):
  internal/handler/user.go
  internal/service/user.go
Stat: 2 files, +57 -9
Full branch diff: git diff $BASE...HEAD
```
```

**Why this is a problem:**
This is the documented example block for what the `inject-review-context.sh` hook places in the reviewer's `additionalContext` on iter 2+ (delta-review mode). The example is in **active prose** (a fenced code block with no `<!-- EXAMPLE (lang: go) -->` annotation) — meaning the reviewer LLM, on first read, sees `internal/handler/user.go` as the canonical shape of the file list. On a Python project, the LLM will model its expectations after this example: it expects `.go` extensions, `internal/` prefix, MVC `handler`/`service` directory structure. When the actual hook output for the Python project shows `app/views/user.py` and `app/services/user.py`, the reviewer's mental model has already been polluted.

This is a direct mirror of P-stage G2 (planner.md's `delegation_prompt_example` hardcoding `internal/handler/`), which was fixed in commit 27ab4f7 by wrapping the Go-specific portion in `<!-- EXAMPLE (lang: go) -->` comment blocks and adding multi-language alternatives.

**Justification (no false-positive claims):**
- Verified by direct read: lines 188-189 contain `internal/handler/user.go` and `internal/service/user.go` in a fenced code block with no language-annotation marker.
- Verified by code search: `inject-review-context.sh` produces this `additionalContext` block at runtime — the example here is *teaching* the reviewer LLM what to expect.
- I am NOT claiming this currently produces broken reviews on the kit's own dogfood (it doesn't — kit IS Go). I AM claiming non-Go reviewers face a Go-shaped mental model first, which compounds with CG4 (location examples) to produce Go-shaped issue locations on non-Go projects.

**Proposed fix:**
Wrap the Go-specific file list in `<!-- EXAMPLE (lang: go) -->` comment markers and add a generic header that references `SOURCE_GLOB`. Show 2-3 language variants so the reviewer LLM understands the file list shape varies per project.

```markdown
**Block structure (example):**
```
[Iter 2 focus — delta only] (mode: warn)
HINT: focus on changed files first — full branch diff accessible via git diff $BASE...HEAD
Files changed since iter 1 (prior_sha=b5685fd..HEAD):
  <files matching project's SOURCE_GLOB, output by inject-review-context.sh>
Stat: <file count>, <line counts>
Full branch diff: git diff $BASE...HEAD
```

<!-- EXAMPLE (lang: go) — kit-dogfood file list shape -->
<!--   internal/handler/user.go                                  -->
<!--   internal/service/user.go                                  -->
<!-- EXAMPLE (lang: python) — Django-like project shape          -->
<!--   app/views/user.py                                         -->
<!--   app/services/user.py                                      -->
<!-- EXAMPLE (lang: typescript) — Express-like project shape     -->
<!--   src/controllers/userController.ts                         -->
<!--   src/services/userService.ts                               -->
```

**Acceptance criteria (CG2.1 – CG2.4):**
- **CG2.1** code-reviewer.md L183-192 block does NOT contain `internal/handler/user.go` or `internal/service/user.go` outside `<!-- EXAMPLE (lang: …) -->` comment markers.
- **CG2.2** Active body of the block uses slot-form file list (e.g. "files matching project's SOURCE_GLOB" or `<source-glob-relative-paths>`).
- **CG2.3** At least 2 language EXAMPLEs (Go + one other) preserved in `<!-- EXAMPLE -->` comment blocks for reference.
- **CG2.4** A pointer to `SOURCE_GLOB` slot OR `inject-review-context.sh` runtime resolution is present in the active body.

**Contract safety:** None of C1-C9 reference this example text. The hook script (`inject-review-context.sh`) is unchanged — only the documentation example is updated. Schema-safe.

**Test impact:** new grep predicate in `test-c-stage-genericity-audit.sh` mirrors `test-p3-plan-reviewer-skip.sh` AC-P3.2 (excludes commented EXAMPLE lines).

---

### CG3 — settings.json worktree sparsePaths Go-shaped without override signal

**Location:** [.claude/settings.json:432-443](.claude/settings.json#L432-L443) and the documentation note at [.claude/agents/code-reviewer.md:335](.claude/agents/code-reviewer.md#L335)

**Current text (settings.json):**
```json
  "worktree": {
    "sparsePaths": [
      ".claude/",
      "internal/",
      "cmd/",
      "go.mod",
      "go.sum",
      "Makefile",
      "CLAUDE.md"
    ]
  },
```

**Current text (code-reviewer.md L335 — already documents this):**
> "Kit-default values (Go-shaped, retained for backwards-compat with existing kit users): `.claude/`, `internal/`, `cmd/`, `go.mod`, `go.sum`, `Makefile`, `CLAUDE.md`. Non-Go projects MUST override via settings.json or settings.local.json (R2: settings.json defaults intentionally preserved per spec)."

**Why this is a problem:**
The `sparsePaths` configuration is consumed by the `prepare-worktree.sh` hook on `WorktreeCreate` events, which fire when the orchestrator delegates to `code-reviewer` (Phase 4). The sparse checkout includes ONLY the listed paths, excluding everything else. On a non-Go project, this shape:
- Includes `internal/`, `cmd/`, `go.mod`, `go.sum`, `Makefile` — none of which exist
- Excludes `src/`, `tests/`, `pyproject.toml`, `package.json`, `Cargo.toml`, `pom.xml` — the actual source

Result: the code-reviewer's worktree contains `.claude/` + `CLAUDE.md` but NO source files. The reviewer has nothing to review. The current documentation note (code-reviewer.md L335) acknowledges this — "Non-Go projects MUST override" — but it's *advisory*, not *enforced*. A team onboarding the kit, especially under deadline pressure, may skip the override silently and discover the failure mode only when their first review returns "no source files visible".

This is NOT a P-stage G-mirror exactly — P-stage didn't have a config issue at this depth. But the spirit is the same as G3 (the parts_order pattern that was Go-shaped by default): kit-defaults must either be neutral OR loudly signal when they're shape-mismatched.

**Justification (no false-positive claims):**
- Verified by direct read of settings.json L432-443 and code-reviewer.md L335.
- Verified by read of `prepare-worktree.sh` (referenced in workflow.md hooks list): the hook actually applies these paths via `git sparse-checkout set`.
- I am NOT claiming kit-default sparsePaths must be removed (R2 from existing spec preserves them for backwards-compat with kit's own Go dogfood). I AM claiming the kit must surface a startup signal so non-Go consumers don't fail silently.
- I am NOT claiming this affects the kit's own dogfood (kit IS Go-shaped, so defaults work). I AM claiming any non-Go consumer hits this with broken reviews.

**Proposed fix (two-pronged: documentation + runtime signal):**

**Part A — Tighten documentation in `code-reviewer.md` L334-336 to mark the override requirement as MANDATORY, not advisory:**

Old (advisory):
> "Non-Go projects MUST override via settings.json or settings.local.json"

New (enforced via QUICK CHECK pre-flight):
> "**MANDATORY for non-Go projects:** override `worktree.sparsePaths` via settings.json or settings.local.json BEFORE first code-review run. The QUICK CHECK pre-flight (step 0.5) verifies the project has at least one non-`.claude/` source path resolvable; if all paths beyond `.claude/` are unresolvable on disk, code-reviewer emits a BLOCKER issue (`worktree-misconfigured`) and exits with REJECTED verdict. Kit defaults are Go-shaped (R2 backwards-compat); see `.claude/settings.json.example` for non-Go templates (Python, TypeScript, Rust, Java)."

**Part B — Add a startup pre-flight signal in code-reviewer.md QUICK CHECK phase:**

```yaml
quick_check_preflight:
  step_0_5_worktree_sparsePaths_check:
    purpose: "Detect Go-shaped sparsePaths on non-Go projects before review begins."
    detection:
      - Read worktree.sparsePaths from settings.
      - For each path, test `[ -e "$ROOT/$path" ]`.
      - If at most `.claude/` exists AND project's PROJECT-KNOWLEDGE.md → LANGUAGE != 'go' (or unset and CLAUDE.md fallback indicates non-Go):
          → emit BLOCKER issue:
            { "id": "CR-worktree-misconfigured", "severity": "BLOCKER",
              "category": "configuration",
              "location": ".claude/settings.json:worktree.sparsePaths",
              "problem": "Worktree sparsePaths uses kit-default Go shape; non-Go project has no resolvable source paths.",
              "suggestion": "Override worktree.sparsePaths in settings.local.json with project-appropriate paths (e.g. for Python: ['.claude/','src/','tests/','pyproject.toml','CLAUDE.md'])." }
          → exit with verdict: REJECTED (irrecoverable; user must fix config)
```

**Part C — Add `.claude/settings.json.example` (or update `.claude/settings.local.json.example`) with template sparsePaths blocks for Python, TypeScript, Rust commented out for easy uncomment.**

**Acceptance criteria (CG3.1 – CG3.5):**
- **CG3.1** `code-reviewer.md` documentation note (around L335) contains the literal phrase "MANDATORY for non-Go projects" or "MUST" with explicit BLOCKER mention (not just advisory "MUST override").
- **CG3.2** `code-reviewer.md` QUICK CHECK phase has a pre-flight step (step 0.5 or labeled equivalent) that detects Go-shaped sparsePaths on non-Go projects.
- **CG3.3** The pre-flight emits a BLOCKER issue with a stable canonical-ish ID prefix (`CR-worktree-misconfigured` or hash thereof per IMP-03) when triggered.
- **CG3.4** `.claude/settings.local.json.example` (or `settings.json.example`) contains template `worktree.sparsePaths` blocks for Python, TypeScript, Rust commented out.
- **CG3.5** `.claude/settings.json` itself is UNCHANGED (R2 backwards-compat; we add documentation + pre-flight, not change the default).

**Contract safety:**
- C1 (handoff schema) — unchanged; the BLOCKER issue follows existing schema shape (severity=BLOCKER allowed).
- C7 (verdict 5-value enum) — unchanged; REJECTED is one of the 5 values, used here for irrecoverable misconfiguration.
- C8 (issue ID pattern) — the BLOCKER's `id` field is normalized by `save-review-checkpoint.sh` per IMP-03 (CR-`<8hex>` of category|location|problem). Adding a new advisory ID prefix doesn't change the normalization function.
- R2 from coder-stage spec (settings.json defaults preserved) — UPHELD; we don't change settings.json content.

**Test impact:**
- Existing tests don't assert sparsePaths content. Safe.
- New test predicate in `test-c-stage-genericity-audit.sh`: assert "MANDATORY" + "BLOCKER" + "CR-worktree-misconfigured" tokens are present in code-reviewer.md QUICK CHECK section.

---

### CG4 — IMP-03 location examples + Output Format hardcode `.go` extension and Go paths

**Location:**
- [.claude/agents/code-reviewer.md:238](.claude/agents/code-reviewer.md#L238) — Issues Found Output Format spec
- [.claude/agents/code-reviewer.md:274](.claude/agents/code-reviewer.md#L274) — VERDICT_JSON example payload
- [.claude/agents/code-reviewer.md:300-301](.claude/agents/code-reviewer.md#L300-L301) — IMP-03 Location-stability guidance examples

**Current text (5 problem lines):**
```markdown
L238: - Location: path/file.go:line
L274: {"id": "CR-001", "severity": "MINOR", "category": "style", "location": "internal/service/foo.go:42", "problem": "…"}
L300: - PREFER: `"internal/service/user.go:Update"` or `"handler/auth.go:login_handler"` (stable across edits)
L301: - AVOID: `"user.go:42"` alone (drift-prone)
```

**Why this is a problem:**
This is the **direct C-stage mirror of G4** (P-stage location-stability fix in plan-reviewer.md L308-312, fixed in commit 27ab4f7). Three independent locations all teach the reviewer LLM the same wrong lesson: "issue locations look like Go file paths". Specifically:

1. **L238 (Output Format spec):** the canonical `Issues Found` template literally says `path/file.go:line`. A reviewer reading the spec will model their output accordingly — `.go` extension assumed.
2. **L274 (VERDICT_JSON example):** the structured-output example uses `"internal/service/foo.go:42"`. This is the FIRST concrete example a reviewer encounters when learning the verdict envelope shape.
3. **L300-301 (Location-stability guidance):** the IMP-03 KD-8 advice uses `internal/service/user.go:Update`, `handler/auth.go:login_handler`, `user.go:42` — all Go-shaped.

The downstream effect (mirror of G4 reasoning): IMP-03's canonical ID (`CR-<8hex>`) is computed from `category|location|problem`. If reviewers consistently emit Go-shaped locations on non-Go projects, the location string drifts when files are renamed (e.g. `user.py` → `user_service.py` Python refactor) more often than necessary, breaking the regression-detection chain that depends on stable canonical IDs across iterations.

**Justification (no false-positive claims):**
- Verified all 5 lines by direct read.
- Verified the IMP-03 normalization function (in `save-review-checkpoint.sh`) is purely text-based — it hashes whatever the reviewer emits, regardless of language.
- I am NOT claiming canonical IDs currently mis-hash on the kit's own dogfood (they don't — kit is Go and the examples match). I AM claiming non-Go reviewers, having modeled their output on these examples, emit `.py:line` or `internal/service/foo.py:Update` shapes that drift on Python refactors.
- The G4 fix (plan-reviewer.md L308-312) addressed this exact gap on the P-stage side. The C-stage has 5 affected lines (vs 2 for P-stage); fix follows the same shape.

**Proposed fix:**
Replace all 5 lines with language-agnostic forms consistent with the just-merged G4 fix (which uses 3-tier gradient: PREFER symbol-only Part-anchored, ACCEPT path+symbol no-extension, AVOID line-only).

**L238 (Output Format spec):**
```markdown
- Location: <source-glob-relative-path>:<symbol>     (preferred — stable)
            OR <symbol>                               (Part-anchored, most stable)
            AVOID line-numbers-only (drift-prone)
```

**L274 (VERDICT_JSON example):**
```markdown
{"id": "CR-001", "severity": "MINOR", "category": "style", "location": "internal/service/foo:Create", "problem": "…"}
```
(removed `.go` extension; `Create` symbol replaces `:42`)

**L299-302 (Location-stability guidance):**
```markdown
**Location-stability guidance (IMP-03 KD-8):** prefer function / symbol name over line number in the `location` field. Line numbers shift when code is edited, which changes the hash → breaks ID continuity across iterations. File extensions and project-specific path prefixes also drift (refactors, language ports, monorepo restructuring). Examples (language-agnostic):
- PREFER: `"Part 3: UserHandler.Create"` (Part-anchored symbol — most stable)
- ACCEPT: `"<source-glob-relative-path>:Update"` (path + symbol — stable until file rename)
- AVOID: `"<filename>:42"` alone (line number only — drift-prone)

**Note:** match path conventions to the project's `SOURCE_GLOB` slot (PROJECT-KNOWLEDGE.md). Avoid hardcoding language-specific prefixes (`internal/`, `src/`, `lib/`) or file extensions (`.go`, `.py`, `.ts`) in the `location` string — those vary per project.
```

This text is **byte-identical** to the G4 fix in plan-reviewer.md L308-312 (just merged) — explicit P/C-stage symmetry.

**Acceptance criteria (CG4.1 – CG4.5):**
- **CG4.1** code-reviewer.md L238 (Output Format) does NOT contain literal `.go` (verifiable: grep `^- Location:` followed by `\.go`).
- **CG4.2** code-reviewer.md L274 (VERDICT_JSON example) does NOT contain literal `\.go:` in the `location` field.
- **CG4.3** code-reviewer.md location-stability bulleted list (around L299-302) does NOT contain `internal/service/user.go`, `handler/auth.go`, `user.go:42` outside EXAMPLE comment blocks.
- **CG4.4** code-reviewer.md location-stability bulleted list opens with `Part-anchored symbol` (PREFER first), matching G4 in plan-reviewer.md.
- **CG4.5** A `SOURCE_GLOB` slot pointer is present in the location-stability section, matching G4.

**Contract safety:**
- C8 (IMP-03 issue ID pattern `^CR-[0-9a-f]{8}$`) — UNCHANGED. The hash function operates on `category|location|problem` regardless of input string shape. We're improving input quality, not changing the hash.
- C1 (verdict envelope schema) — `issues[].location` field accepts any string; no schema constraint on shape.
- IMP-03 normalization in `save-review-checkpoint.sh` — UNCHANGED.

**Test impact:**
- Existing `test-save-review-checkpoint.sh` validates IMP-03 normalization; not affected.
- New grep predicates in `test-c-stage-genericity-audit.sh` for CG4.1, CG4.2, CG4.3, CG4.4, CG4.5.
- Symmetry note: these mirror the G4 predicates in `test-genericity-audit.sh` (PR-001 incorporated).

---

### CG5 — coder-rules RULE_3 hardcodes "handler/API layer" Go/Spring terminology

**Location:**
- [.claude/skills/coder-rules/SKILL.md:13](.claude/skills/coder-rules/SKILL.md#L13) — RULE_3 main wording
- [.claude/skills/coder-rules/SKILL.md:91](.claude/skills/coder-rules/SKILL.md#L91) — RULE_3 explanation in "Why" section

**Current text:**
```markdown
L13: - RULE_3 Clean Domain: NEVER add {DOMAIN_PROHIBIT} (resolved from PROJECT-KNOWLEDGE.md → DOMAIN_PROHIBIT; CLAUDE.md fallback) to domain entities (tags belong in DTOs at handler/API layer). SKIP if slot unset.

L91: **Why:** RULE_3 — Domain entities must be pure. No {DOMAIN_PROHIBIT} (resolved from PROJECT-KNOWLEDGE.md). Tags belong in DTOs at the handler/API layer.
```

**Why this is a problem:**
The phrase "handler/API layer" is Go/Spring-Boot terminology. Other stacks use different vocabulary:
- **Python Django:** "view" + "serializer" (no separate "handler" layer)
- **Python FastAPI:** "router" / "endpoint"
- **Express (Node.js):** "controller" / "route"
- **Rust Axum/Actix:** "handler" (matches Go) but distinct from "service" idiom
- **Java Spring:** "controller" (not "handler")
- **TypeScript NestJS:** "controller"

When a Python/Express developer reads this rule, they have to mentally translate "handler/API layer" → their stack's vocabulary. RULE_3 is a critical rule (CRITICAL severity, gates DTO placement decisions), so unclear terminology causes silent rule misapplication.

This is the C-stage mirror of G5 (P-stage task-analysis MVC term replacement, just fixed in commit 27ab4f7 by replacing "controller", "handler", "service", "model" with "storage", "entities", "business", "API", "tests").

**Justification (no false-positive claims):**
- Verified by direct read at L13 and L91.
- Verified RULE_3 is loaded by coder.md startup as a CRITICAL rule.
- I am NOT claiming RULE_3 is currently broken on the kit's own dogfood (kit is Go, "handler/API layer" maps directly). I AM claiming non-Go developers face mental translation overhead, with non-zero risk of misapplying RULE_3 (e.g. putting JSON tags on Django models because "view" doesn't sound like "handler").

**Proposed fix:**
Replace "handler/API layer" with a layer-role-neutral phrase: "API/transport layer" (matches existing usage in `architecture-checks.md` L63 pass_criteria language and `data-flow.md` `<INPUT_LAYER>` slot). Add LAYERS slot pointer for explicit resolution.

**L13 (RULE_3 main):**
```markdown
- RULE_3 Clean Domain: NEVER add {DOMAIN_PROHIBIT} (resolved from PROJECT-KNOWLEDGE.md → DOMAIN_PROHIBIT; CLAUDE.md fallback) to domain entities. Tags belong in DTOs at the API/transport layer (your project's highest LAYERS entry — see PROJECT-KNOWLEDGE.md → LAYERS for the concrete name). SKIP if slot unset.
```

**L91 (RULE_3 Why):**
```markdown
**Why:** RULE_3 — Domain entities must be pure. No {DOMAIN_PROHIBIT} (resolved from PROJECT-KNOWLEDGE.md). Tags belong in DTOs at the API/transport layer (highest LAYERS entry per PROJECT-KNOWLEDGE.md → LAYERS).
```

**Acceptance criteria (CG5.1 – CG5.4):**
- **CG5.1** `coder-rules/SKILL.md` does NOT contain the literal phrase `handler/API layer` (verifiable: grep `-F`).
- **CG5.2** RULE_3 wording uses `API/transport layer` (or `<INPUT_LAYER>` slot, or `LAYERS[N]` reference) — language-neutral terms consistent with `data-flow.md`/`architecture-checks.md` neighbors.
- **CG5.3** RULE_3 (both L13 and L91) contains a pointer to PROJECT-KNOWLEDGE.md → LAYERS for concrete-name resolution.
- **CG5.4** No information loss: the original intent ("tags belong in DTOs, not domain entities") is preserved — only the layer label changes.

**Contract safety:**
- No schema field. No test predicate. No handoff field. Pure documentation/wording change.
- C5 (PK schema) — unchanged.
- C8 (issue ID pattern) — unchanged.

**Test impact:** new grep predicate in `test-c-stage-genericity-audit.sh`: assert `coder-rules/SKILL.md` does NOT contain `handler/API layer` (case-sensitive `grep -F`).

## 6. Out of Scope (explicit list of NOT-doing)

Per "5 problems, do them well" constraint and explicit exclusions:

| Candidate | Why deferred |
|---|---|
| coder.md L77 `command_used:` field with multi-language Go/Python examples | Already correctly slot-resolved in curly braces with multi-language framing. Acceptable. |
| coder.md L432 CLAUDE.md fallback "kit-default for Go projects: …" | Framed as "kit-default for Go projects" which is honest; fallback path explicitly Go-scoped. Cascade L427-439 has language-aware DEPENDENCY_FILE detection at L433-436. Acceptable. |
| code-review-rules/examples.md L64 `log\.(Error\|Warn\|Info)` Go logger regex | Grep pattern in an example file; should be wrapped in `<!-- EXAMPLE (lang: go) -->` comment. MEDIUM severity but file is reference-only material — defer to separate audit. |
| CLAUDE.md L13 "race check: `go test -race`" | Kit's own dogfood Language Profile, explicitly framed as Go. Already documented as overridable via PROJECT-KNOWLEDGE.md (CLAUDE.md L17). Out of scope for this audit. |
| settings.json L8-13 Go permissions (`Bash(go test *)`, etc.) | Kit dogfood permissions; non-Go consumers add their own without conflict. Documentation clarity gap, separate concern. |
| auto-fmt-go.sh / pre-commit-build.sh / import-matrix-prompt.sh — language-scoped hooks | Go-scoped by name + matched on `**/*.go` / `internal/**/*.go` matchers in settings.json. Correct gating in place. |
| Slot syntax inconsistency (`{X}` vs `<X>`) | Pre-existing kit-wide convention drift; deferred per P-stage spec §6 to separate audit. |

## 7. Implementation Plan (Hand-off to Phase 1 Planner)

**Total file changes:** 4 files modified, 1-2 files created.

| File | Edit | Problem |
|---|---|---|
| `.claude/commands/coder.md` | text edits at L160-163 (step 5 condition) and L367-370 (TDD reference) | CG1 |
| `.claude/agents/code-reviewer.md` | text edits at L183-192 (GET CHANGES example), L238 (Output Format), L274 (VERDICT_JSON example), L299-302 (Location-stability), QUICK CHECK pre-flight section addition | CG2, CG3 (preflight), CG4 |
| `.claude/skills/coder-rules/SKILL.md` | text edits at L13 (RULE_3 main) and L91 (RULE_3 Why) | CG5 |
| `.claude/settings.local.json.example` | template sparsePaths blocks for Python, TypeScript, Rust (commented) | CG3 |
| `.claude/scripts/tests/test-c-stage-genericity-audit.sh` | NEW file with CG1-CG5 grep predicates | All 5 |

**Estimated lines changed:** ~40 source lines (across 4 files) + ~140 lines new test script + ~25 lines settings example. Settings.json itself: UNCHANGED (R2 preserved).

**Estimated implementation time:** 45-60 minutes (text edits + test script + sparse-paths examples).

**Test plan:**
1. Run `test-c-stage-genericity-audit.sh` — must pass all 5 problem AC predicates.
2. Run all 22 existing tests — must keep current 22/22 PASS state (after commit 9ed4d66 baseline-failure fix).
3. Manual dogfood: re-run `/coder` then `code-reviewer` on a fresh task in the kit; verify no regression in output for the kit's own Go context (location formats remain reasonable, RULE_3 still triggers for Go domain entities).

## 8. Contract Verification Checklist (Pre-Merge)

Before any commit:

- [ ] `git diff 9ed4d66..HEAD -- .claude/schemas/handoff.schema.json` returns empty.
- [ ] `git diff 9ed4d66..HEAD -- .claude/PROJECT-KNOWLEDGE.md.example` returns empty.
- [ ] `git diff 9ed4d66..HEAD -- .claude/scripts/inject-review-context.sh` returns empty (4 KB cap unchanged).
- [ ] `git diff 9ed4d66..HEAD -- .claude/scripts/save-review-checkpoint.sh` returns empty (IMP-03 normalization unchanged).
- [ ] `git diff 9ed4d66..HEAD -- .claude/scripts/prepare-worktree.sh` returns empty (CG3 fix is doc/preflight only, hook unchanged).
- [ ] `git diff 9ed4d66..HEAD -- .claude/settings.json` shows ONLY any clarifying comments — no functional changes to sparsePaths, permissions, or hooks.
- [ ] `bash .claude/scripts/tests/test-validate-handoff.sh` — 18/18 PASS.
- [ ] `bash .claude/scripts/tests/test-save-review-checkpoint.sh` — PASS.
- [ ] `bash .claude/scripts/tests/test-c{1,2,3,4,5}-*.sh` — all 5 PASS.
- [ ] `bash .claude/scripts/tests/test-p{1,2,3,4,5}-*.sh` — all 5 PASS.
- [ ] `bash .claude/scripts/tests/test-genericity-audit.sh` — 16/16 PASS (P-stage from prior commit).
- [ ] `bash .claude/scripts/tests/test-c-stage-genericity-audit.sh` — NEW; all CG1-CG5 ACs PASS.
- [ ] `bash .claude/scripts/tests/test-hook-stderr-format.sh` — 3/3 PASS (just-fixed in 9ed4d66).
- [ ] `bash .claude/scripts/tests/test-imp04-diff-based-replan.sh` — 36/36 PASS (just-fixed in 9ed4d66).
- [ ] Full suite: 23/23 PASS (22 existing + 1 new).

## 9. Why Exactly These 5 (and not 4 or 6)

User constraint: focus on 5 problems, do them well. The 12 candidate findings naturally divided as:

- **5 high-leverage gaps with clean ACs and zero contract risk** (CG1-CG5 in this doc).
- **3 already-mitigated** (coder.md L77 multi-language slot framing; coder.md L432 explicitly Go-scoped fallback; coder-rules examples mostly grep-pattern reference).
- **3 kit-dogfood-scope** (CLAUDE.md race detector wording, settings.json permissions, auto-fmt-go.sh README) — out of scope per user "5 problems" rule and audit-scope filter.
- **1 deferred** (code-review-rules examples.md L64 logger regex) — fix-able but lower blast radius; separate audit.

Picking fewer (3 or 4) would leave high-impact gaps (CG3 silent-config-failure, CG4 5-line location-format leak). Picking more (6 or 7) would add fixes that are already half-mitigated by existing slot-resolution framing — diminishing returns and risk of touching files that are already well-shaped.

The selected 5 cover:
1. The **conditional skill load** (CG1 — semantic gate on language)
2. The **delta-review file list example** (CG2 — most user-visible reviewer instruction)
3. The **worktree configuration** (CG3 — silent-failure mode for non-Go consumers, biggest UX risk)
4. The **issue location format** (CG4 — 5 lines of direct G4 mirror, most lines fixed)
5. The **RULE_3 layer terminology** (CG5 — direct G5 mirror, critical rule wording)

Each is in a different file (no within-file conflicts), each has independent ACs, and all five compose into one coherent text+config refactor.

## 10. References

- **Prior P-stage audit (just merged):** `.claude/prompts/plan-stage-genericity-audit-2026-04-27.md` (G1-G5, commit 27ab4f7); plan: `.claude/prompts/plan-stage-genericity-fix.md`; new test: `.claude/scripts/tests/test-genericity-audit.sh`.
- **Pre-existing C-stage spec (v1.16-v1.17):** `.claude/prompts/coder-stage-generic-spec.md` (C1-C5).
- **Pre-existing post-1.17 spec:** `.claude/prompts/post-1.17-symmetry-audit.md` (D1-D5: 5-value verdict matrix, schema bump, P-stage AC tests, env-leak fix, RULE labels).
- **Test reference:** `.claude/scripts/tests/test-genericity-audit.sh` (P-stage; this audit's new test mirrors its structure).
- **Slot conventions:** `.claude/PROJECT-KNOWLEDGE.md.example` (22 slots, schema 1.1.0); CLAUDE.md Language Profile.
- **Cascade rule:** `PK > CLAUDE.md > SKIP-with-NIT` (CLAUDE.md L17-29).
- **Architecture-neutral layer slots:** `<INPUT_LAYER>`, `<BUSINESS_LAYER>`, `<DATA_ACCESS_LAYER>` (`data-flow.md` L18-20).
- **Baseline test state:** 22/22 PASS after commit 9ed4d66 (baseline failures closed).
