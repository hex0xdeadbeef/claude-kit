# C-Stage Genericity Fix — Implementation Plan

**Spec:** [`c-stage-genericity-audit-2026-04-27.md`](.claude/prompts/c-stage-genericity-audit-2026-04-27.md) (approved 2026-04-27, all 5 problems CG1-CG5)

**Type:** refactoring (text-only documentation/prompt edits + 1 settings.example template)
**Complexity:** XL (per user instruction)
**Branch:** main (single bundled commit per approved spec)
**Baseline:** commit `9ed4d66` (22/22 tests PASS after closing 2 long-standing baseline failures)

## Context

Five C-stage genericity gaps mirror the just-merged P-stage G1-G5 audit (commit 27ab4f7). Each gap is a Go-leak that the slot scaffolding (PK > CLAUDE.md > SKIP) does NOT fix because the leak is in **prompt text or configuration defaults** — not in slot resolution. This plan addresses each with a minimal slot-aware text replacement (CG1, CG2, CG4, CG5), plus one config-level pre-flight signal (CG3) that does NOT change `settings.json` defaults (R2 backwards-compat preserved).

## Scope

### IN
- `.claude/commands/coder.md` — 2 edits (CG1: step 5 condition + tdd_mode reference)
- `.claude/agents/code-reviewer.md` — 4 edits (CG2 GET CHANGES example, CG4 4 location-format lines, CG3 worktree pre-flight + tightened doc)
- `.claude/skills/coder-rules/SKILL.md` — 2 edits (CG5: RULE_3 main + Why)
- `.claude/settings.local.json.example` — 1 edit (CG3: add commented Python/TypeScript/Rust sparsePaths templates next to existing Go default)
- `.claude/scripts/tests/test-c-stage-genericity-audit.sh` — NEW (CG1-CG5 grep predicates)

### OUT
- `.claude/settings.json` — UNCHANGED (R2 backwards-compat; the `worktree.sparsePaths` Go default stays)
- `.claude/schemas/handoff.schema.json` — UNCHANGED (no contract changes)
- `.claude/PROJECT-KNOWLEDGE.md.example` — UNCHANGED (no slot additions)
- All hooks (`inject-review-context.sh`, `validate-handoff.sh`, `save-review-checkpoint.sh`, `prepare-worktree.sh`) — UNCHANGED
- Files in spec §6 Out-of-Scope deferrals (coder.md L77 multi-language slot framing; coder.md L432 fallback; CLAUDE.md race detector; auto-fmt-go.sh; settings.json permissions Go list; code-review-rules examples.md L64 logger regex)
- P-stage artifacts (covered by G1-G5)

## Dependencies

None — text-only refactor on top of post-`9ed4d66` baseline. Prior work (`27ab4f7` P-stage G1-G5, `1a53eee` CR-001/CR-002 polish, `9ed4d66` baseline-failure fix) already merged. No prior-blocking issues.

## Architecture Decision

**Single bundled commit** per user pattern (one audit = one PR). Splitting CG1-CG5 into 5 micro-commits would create review noise without isolation benefit (no logic/test risk per problem; all changes are documentation/text + 1 settings example + 1 new test script).

**Test strategy:** new `test-c-stage-genericity-audit.sh` mirrors structure of `test-genericity-audit.sh` (P-stage). Predicates are GREP-INVERSE assertions (file does NOT contain bad-token X) + GREP-POSITIVE assertions (file DOES contain slot-form Y). Awk state-flag idiom used where range delimiters could overlap (lessons from prior G3.2 awk fix).

**No TDD step required** — text edits, no logic. Test predicates written alongside text fixes; predicates fail on `main` BEFORE fix demonstrates they gate correctly, then turn PASS once fixes land.

**CG3 design choice — pre-flight signal vs. settings.json edit:** the spec proposed two-pronged fix. R2 from prior coder-stage-spec ("settings.json defaults intentionally preserved") rules out changing `worktree.sparsePaths` defaults. The pre-flight is the only path that addresses the silent-failure mode without breaking R2.

## Parts

### Part 1: CG1 — Gate `tdd-go` skill load on `LANGUAGE == 'go'`

**File:** `.claude/commands/coder.md`

**Operation:** Edit (full block replacement of step 5 at L159-163; minor reference update at L367-370)

**Edit 1a — step 5 condition (L159-163):**

Old:
```yaml
    - action: "Conditional: Load TDD skill"
      condition: "Plan file contains '## TDD' heading"
      files:
        - ".claude/skills/tdd-go/SKILL.md"
      purpose: "Load TDD Red-Green-Refactor workflow. If ## TDD absent — skip, use standard implement→test flow."
```

New:
```yaml
    - action: "Conditional: Load TDD skill"
      condition: "Plan file contains '## TDD' heading AND PROJECT-KNOWLEDGE.md → LANGUAGE == 'go' (or LANGUAGE unset, treating kit-default as Go)"
      files:
        - ".claude/skills/tdd-go/SKILL.md"
      skip_behavior: |
        If '## TDD' is present BUT LANGUAGE != 'go':
          - SKIP loading tdd-go (kit ships Go-only TDD patterns; no per-language equivalents).
          - Coder applies generic red-green-refactor: write failing test before
            implementation, keep test minimal, refactor only after green.
          - Emit consolidated NIT in handoff.deviations_from_plan: "TDD section
            present but kit lacks language-specific TDD reference for {LANGUAGE};
            coder applied generic red-green-refactor (write failing test → minimal
            implementation → refactor)."
      purpose: "Load TDD Red-Green-Refactor workflow for Go projects. If ## TDD absent OR LANGUAGE != go — skip with NIT, use generic TDD flow."
```

**Edit 1b — tdd_mode condition (L367-370):**

Old:
```yaml
      tdd_mode:
        when: "TDD skill loaded (plan contains ## TDD)"
        behavior: "Each Part follows RED-GREEN-REFACTOR instead of implement→test"
        part_order: "Tests are NOT a separate Part — they are woven into each Part via RED-GREEN-REFACTOR cycles"
        reference: ".claude/skills/tdd-go/SKILL.md § Integration with Coder Parts"
```

New:
```yaml
      tdd_mode:
        when: "TDD skill loaded (plan contains ## TDD AND LANGUAGE == 'go' OR unset)"
        behavior: "Each Part follows RED-GREEN-REFACTOR instead of implement→test"
        part_order: "Tests are NOT a separate Part — they are woven into each Part via RED-GREEN-REFACTOR cycles"
        reference: ".claude/skills/tdd-go/SKILL.md § Integration with Coder Parts"
        non_go_fallback: "If LANGUAGE != go: tdd-go skill NOT loaded (see step 5 skip_behavior); coder applies generic red-green-refactor without language-specific test idioms."
```

**Why this exact wording:**
- Condition explicitly references `PROJECT-KNOWLEDGE.md → LANGUAGE` slot — consistent with cascade contract.
- `LANGUAGE unset, treating kit-default as Go` clause preserves backwards-compat with consumers who haven't populated PK yet (kit-default is Go).
- `skip_behavior:` block follows kit convention from architecture-checks.md L23-34 (canonical SKIP-with-NIT pattern).
- The NIT message explicitly cites `{LANGUAGE}` slot value for diagnostic clarity.
- L367-370 `non_go_fallback` field cross-references step 5 to keep the two locations consistent.

**ACs covered:** CG1.1 (LANGUAGE in step 5 condition), CG1.2 (skip_behavior block present), CG1.3 ("kit ships Go-only TDD patterns" acknowledgment), CG1.4 (L367-370 reference consistent).

---

### Part 2: CG2 — Slot-ify GET CHANGES example file list

**File:** `.claude/agents/code-reviewer.md` lines 183-192

**Operation:** Edit (full block replacement of the **Block structure (example):** content)

Old:
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

New:
```markdown
**Block structure (example):**
```
[Iter 2 focus — delta only] (mode: warn)
HINT: focus on changed files first — full branch diff accessible via git diff $BASE...HEAD
Files changed since iter 1 (prior_sha=b5685fd..HEAD):
  <files matching project SOURCE_GLOB, output by inject-review-context.sh>
Stat: <file count>, +<added> -<removed>
Full branch diff: git diff $BASE...HEAD
```

<!-- EXAMPLE (lang: go) — kit-dogfood file list shape -->
<!--   internal/handler/user.go                                  -->
<!--   internal/service/user.go                                  -->
<!-- EXAMPLE (lang: python) — Django/FastAPI-like project shape  -->
<!--   app/views/user.py                                         -->
<!--   app/services/user.py                                      -->
<!-- EXAMPLE (lang: typescript) — Express/NestJS-like shape      -->
<!--   src/controllers/userController.ts                         -->
<!--   src/services/userService.ts                               -->
```

**Why this exact wording:**
- Active-body uses slot-form `<files matching project SOURCE_GLOB, ...>` (consistent with G2 fix in planner.md L329-340).
- Three concrete language examples in `<!-- EXAMPLE (lang: …) -->` comment blocks (kit standard from `code-shapes/INVARIANTS.md`).
- Go example preserved for kit dogfood (kit IS a Go project).
- Stat line uses `<placeholder>` form for counts so the example doesn't lock in `2 files, +57 -9` as canonical.

**ACs covered:** CG2.1 (no `internal/handler/user.go` outside EXAMPLE), CG2.2 (active body uses SOURCE_GLOB or slot-form), CG2.3 (≥2 EXAMPLE blocks), CG2.4 (SOURCE_GLOB pointer present).

---

### Part 3: CG3 — Worktree pre-flight + documentation tightening

**File:** `.claude/agents/code-reviewer.md` (Worktree Optimization section, around L331-337)

**Operation:** Edit (replace the section with tightened doc + add pre-flight check)

Old (L331-337):
```markdown
## Worktree Optimization
- This agent runs with `isolation: worktree` — a temporary git worktree is created per review
- `worktree.sparsePaths` in settings.json controls which paths are checked out (git sparse-checkout, v2.1.76)
- Defaults are configured in `settings.json worktree.sparsePaths`. Recommended pattern: follow PROJECT-KNOWLEDGE.md → SOURCE_GLOB + DEPENDENCY_FILE for project source layout.
- Kit-default values (Go-shaped, retained for backwards-compat with existing kit users): `.claude/`, `internal/`, `cmd/`, `go.mod`, `go.sum`, `Makefile`, `CLAUDE.md`. Non-Go projects MUST override via settings.json or settings.local.json (R2: settings.json defaults intentionally preserved per spec).
- Override per project in settings.json or settings.local.json to match source layout
- Impact: faster worktree creation and lower disk usage, especially in monorepos
```

New:
```markdown
## Worktree Optimization
- This agent runs with `isolation: worktree` — a temporary git worktree is created per review.
- `worktree.sparsePaths` in settings.json controls which paths are checked out (git sparse-checkout, v2.1.76).
- Defaults are configured in `settings.json worktree.sparsePaths`. Recommended pattern: follow PROJECT-KNOWLEDGE.md → SOURCE_GLOB + DEPENDENCY_FILE for project source layout.
- Kit-default values (Go-shaped, retained for backwards-compat with existing kit users): `.claude/`, `internal/`, `cmd/`, `go.mod`, `go.sum`, `Makefile`, `CLAUDE.md`.
- **MANDATORY for non-Go projects:** override `worktree.sparsePaths` via `settings.json` OR `settings.local.json` BEFORE first code-review run. The QUICK CHECK pre-flight (below) verifies at least one non-`.claude/` source path resolvable on disk; if all paths beyond `.claude/` are unresolvable AND PK→LANGUAGE != 'go', code-reviewer emits a BLOCKER issue (`worktree-misconfigured`) and exits with REJECTED verdict.
- See `.claude/settings.local.json.example` for non-Go template sparsePaths blocks (Python, TypeScript, Rust, Java commented out — uncomment for your stack).
- Impact: faster worktree creation and lower disk usage, especially in monorepos.

### QUICK CHECK Pre-flight (step 0.5 — Worktree sparsePaths sanity)

Before starting review, verify worktree sparsePaths resolve to actual files:

```yaml
worktree_sparsepaths_check:
  purpose: "Detect Go-shaped sparsePaths on non-Go projects before review begins."
  step:
    - 1. Read worktree.sparsePaths from settings.
    - 2. For each path, test `[ -e "$ROOT/$path" ]`.
    - 3. Resolve LANGUAGE from PROJECT-KNOWLEDGE.md → LANGUAGE (or CLAUDE.md fallback).
  trigger:
    - condition: "AT MOST '.claude/' resolves AND LANGUAGE != 'go' (or LANGUAGE unset AND no Go markers like go.mod present)"
    - emit_blocker: |
        {
          "id": "CR-worktree-misconfigured",
          "severity": "BLOCKER",
          "category": "configuration",
          "location": ".claude/settings.json:worktree.sparsePaths",
          "problem": "Worktree sparsePaths uses kit-default Go shape; non-Go project has no resolvable source paths beyond .claude/. Reviewer cannot see source files.",
          "suggestion": "Override worktree.sparsePaths in settings.local.json with project-appropriate paths. Templates available at .claude/settings.local.json.example (Python: ['.claude/','src/','tests/','pyproject.toml','CLAUDE.md']; TypeScript: ['.claude/','src/','package.json','tsconfig.json','CLAUDE.md']; Rust: ['.claude/','src/','tests/','Cargo.toml','CLAUDE.md']).",
          "reference": "code-reviewer.md § Worktree Optimization"
        }
    - exit_verdict: "REJECTED (irrecoverable; user must fix config before retry)"
  skip_when: "LANGUAGE == 'go' OR Go markers (go.mod) detected — kit defaults intentionally preserved (R2)."
```
```

**Edit 3b — Process step 2 cross-reference (PR-003 from plan-review iter 1):**

In `code-reviewer.md` Process step 2 (QUICK CHECK), add a single line at the top of the step
that wires the pre-flight into the linear reviewer flow:

```markdown
2. QUICK CHECK
   - **Pre-flight (NEW):** run Worktree sparsePaths sanity check (see ## Worktree Optimization → QUICK CHECK Pre-flight). If pre-flight emits BLOCKER, exit with REJECTED verdict before continuing.
   - <existing step 2 content unchanged>
```

This tightens the integration so reviewer LLMs following Process steps 1→2→3→4→5 linearly
discover the pre-flight without having to scan the entire document.

**Why this exact wording:**
- Active-body documentation upgraded from "MUST override" advisory to "**MANDATORY for non-Go projects**" with explicit BLOCKER consequence.
- New `### QUICK CHECK Pre-flight` subsection makes the runtime signal an explicit reviewer step (not implicit).
- `CR-worktree-misconfigured` issue ID prefix is advisory — `save-review-checkpoint.sh` IMP-03 normalization will compute the canonical 8-hex form from `category|location|problem`. The reviewer emits the advisory string; hook normalizes (existing C8 contract preserved).
- `skip_when:` clause ensures kit's own dogfood (Go) runs without the pre-flight firing — R2 backwards-compat.
- Templates explicitly cited point to `settings.local.json.example` updated in Part 4.
- Edit 3b adds one cross-reference line in Process step 2 (PR-003 from plan-review) — addresses the loose-integration risk noted in §Risks row 1.

**ACs covered:** CG3.1 (MANDATORY + BLOCKER mention), CG3.2 (QUICK CHECK pre-flight present), CG3.3 (advisory ID `CR-worktree-misconfigured`), CG3.5 (settings.json untouched — verified by AC-T1 below).

---

### Part 4: CG3 — Add non-Go sparsePaths templates to settings.local.json.example

**File:** `.claude/settings.local.json.example` lines 39-42

**Operation:** Edit (extend the worktree comment block + add inline language alternatives as JSON-comments)

Old:
```json
  "_worktree_comment": "Uncomment for monorepos (100k+ files) to speed up code-reviewer worktree creation. Only checked-out paths will be visible to the reviewer agent.",
  "worktree": {
    "sparsePaths": ["internal/", "cmd/", "go.mod", "go.sum", "Makefile"]
  }
}
```

New:
```json
  "_worktree_comment": "Uncomment for monorepos (100k+ files) to speed up code-reviewer worktree creation. Only checked-out paths will be visible to the reviewer agent. The kit ships Go-shaped defaults; for non-Go projects, replace the sparsePaths array with one of the language-specific templates below.",
  "_worktree_templates_python": "Python (Django / FastAPI / Flask): [\"src/\", \"tests/\", \"pyproject.toml\", \"requirements.txt\", \"setup.py\"]",
  "_worktree_templates_typescript": "TypeScript / Node.js: [\"src/\", \"tests/\", \"package.json\", \"tsconfig.json\"]",
  "_worktree_templates_rust": "Rust: [\"src/\", \"tests/\", \"Cargo.toml\", \"Cargo.lock\"]",
  "_worktree_templates_java": "Java (Maven / Gradle): [\"src/main/\", \"src/test/\", \"pom.xml\", \"build.gradle\", \"build.gradle.kts\"]",
  "worktree": {
    "sparsePaths": ["internal/", "cmd/", "go.mod", "go.sum", "Makefile"]
  }
}
```

**Why this exact wording:**
- JSON doesn't support comments, so we use the kit-standard underscore-prefix-keys-as-comments convention (`_worktree_comment`, `_worktree_templates_*`) consistent with existing `_comment`, `_env_comment`, `_worktree_comment` keys in the file (per L13: "keys with a leading '_' are inactive").
- 4 language templates (Python, TypeScript, Rust, Java) cover the 5 languages the kit's `code-shapes/<LANG>.md` supports (Go is the active default; the 4 templates fill in the others).
- `pyproject.toml` listed first for Python (modern PEP 621 standard); `requirements.txt` and `setup.py` as fallbacks.
- All templates include `src/` + tests dir + manifest file — consistent shape.

**ACs covered:** CG3.4 (template sparsePaths blocks for Python, TypeScript, Rust present in `.example` file).

---

### Part 5: CG4 — Generic IMP-03 location examples (5 lines)

**File:** `.claude/agents/code-reviewer.md` (4 separate edit locations)

**Operation:** Edit (replace 5 individual lines)

**Edit 5a — Output Format spec (L238):**

Old:
```markdown
- Location: path/file.go:line
```

New:
```markdown
- Location: <source-glob-relative-path>:<symbol> (preferred — stable until file rename)
            OR <symbol> alone (Part-anchored, most stable)
            AVOID line-numbers-only (drift-prone; line numbers shift with edits)
```

**Edit 5b — VERDICT_JSON example payload (L274):**

Old:
```markdown
{"id": "CR-001", "severity": "MINOR", "category": "style", "location": "internal/service/foo.go:42", "problem": "…"}
```

New:
```markdown
{"id": "CR-001", "severity": "MINOR", "category": "style", "location": "internal/service/foo:Create", "problem": "…"}
```

**Edit 5c — Location-stability guidance (L299-301):**

Old:
```markdown
**Location-stability guidance (IMP-03 KD-8):** prefer function / symbol name over line number in the `location` field. Line numbers shift when code is edited, which changes the hash → breaks ID continuity across iterations. Examples:
- PREFER: `"internal/service/user.go:Update"` or `"handler/auth.go:login_handler"` (stable across edits)
- AVOID: `"user.go:42"` alone (drift-prone)
```

New:
```markdown
**Location-stability guidance (IMP-03 KD-8):** prefer function / symbol name over line number in the `location` field. Line numbers shift when code is edited, which changes the hash → breaks ID continuity across iterations. File extensions and project-specific path prefixes also drift (refactors, language ports, monorepo restructuring). Examples (language-agnostic):
- PREFER: `"Part 3: UserHandler.Create"` (Part-anchored symbol — most stable)
- ACCEPT: `"<source-glob-relative-path>:Update"` (path + symbol — stable until file rename)
- AVOID: `"<filename>:42"` alone (line number only — drift-prone)

**Note:** match path conventions to the project's `SOURCE_GLOB` slot (PROJECT-KNOWLEDGE.md). Avoid hardcoding language-specific prefixes (`internal/`, `src/`, `lib/`) or file extensions (`.go`, `.py`, `.ts`) in the `location` string — those vary per project.
```

**Why this exact wording:**
- The location-stability text (Edit 5c) is **byte-identical** to G4 fix in plan-reviewer.md L308-312 (just merged in commit 27ab4f7). Explicit P/C-stage symmetry — same lesson, same wording, same gradient (PREFER → ACCEPT → AVOID).
- Edit 5a (Output Format) shows the gradient inline, teaching reviewers the trade-offs at the spec level.
- Edit 5b (VERDICT_JSON example) drops `.go` extension and `:42` line-number-only form — replaced with `internal/service/foo:Create` (path + symbol, no extension). Path `internal/service/foo` is generic enough to be plausible across stacks (Go uses `internal/service/foo.go`, Python uses `internal/service/foo.py` if such layout exists; without extension, both cover).
- All four edits combined: zero `.go` literal in the location-stability section + Output Format + VERDICT_JSON example.

**ACs covered:** CG4.1 (no `.go` in Output Format), CG4.2 (no `.go:` in VERDICT_JSON), CG4.3 (no Go-specific paths in location-stability bullets outside EXAMPLE), CG4.4 (Part-anchored symbol PREFER first), CG4.5 (SOURCE_GLOB pointer in location-stability section).

---

### Part 6: CG5 — Replace "handler/API layer" with neutral terminology

**File:** `.claude/skills/coder-rules/SKILL.md`

**Operation:** Edit (2 separate line replacements)

**Edit 6a — RULE_3 main wording (L13):**

Old:
```markdown
- RULE_3 Clean Domain: NEVER add {DOMAIN_PROHIBIT} (resolved from PROJECT-KNOWLEDGE.md → DOMAIN_PROHIBIT; CLAUDE.md fallback) to domain entities (tags belong in DTOs at handler/API layer). SKIP if slot unset.
```

New:
```markdown
- RULE_3 Clean Domain: NEVER add {DOMAIN_PROHIBIT} (resolved from PROJECT-KNOWLEDGE.md → DOMAIN_PROHIBIT; CLAUDE.md fallback) to domain entities. Tags belong in DTOs at the API/transport layer (your project's highest LAYERS entry per PROJECT-KNOWLEDGE.md → LAYERS). SKIP if slot unset.
```

**Edit 6b — RULE_3 Why explanation (L91):**

Old:
```markdown
**Why:** RULE_3 — Domain entities must be pure. No {DOMAIN_PROHIBIT} (resolved from PROJECT-KNOWLEDGE.md). Tags belong in DTOs at the handler/API layer.
```

New:
```markdown
**Why:** RULE_3 — Domain entities must be pure. No {DOMAIN_PROHIBIT} (resolved from PROJECT-KNOWLEDGE.md). Tags belong in DTOs at the API/transport layer (highest LAYERS entry per PROJECT-KNOWLEDGE.md → LAYERS).
```

**Why this exact wording:**
- "handler/API layer" → "API/transport layer" — `API/transport` mirrors `architecture-checks.md` L63 pass_criteria language ("API/transport layer methods call business-layer methods"). Consistent neighbor terminology.
- Added LAYERS slot pointer — explicit resolution path, eliminates mental translation overhead for non-Go users.
- Both edits preserve the rule's intent (DTOs hold tags, not domain entities) — only the layer label is replaced.

**ACs covered:** CG5.1 (no literal "handler/API layer"), CG5.2 (uses "API/transport layer" + LAYERS pointer), CG5.3 (LAYERS pointer in both L13 and L91), CG5.4 (no information loss — DTO/entity intent preserved).

---

### Part 7: NEW test script (test-c-stage-genericity-audit.sh)

**File:** `.claude/scripts/tests/test-c-stage-genericity-audit.sh` (NEW)

**Operation:** Write (new file, executable bash script, mirrors structure of `test-genericity-audit.sh` from P-stage)

**Test cases (all CG ACs that are grep-automatable):**

```bash
#!/usr/bin/env bash
# test-c-stage-genericity-audit.sh
#
# Asserts CG1.1..CG5.4 from .claude/prompts/c-stage-genericity-audit-2026-04-27.md
# Tests 2026-04-27 fresh C-stage audit: 5 Coder + Code-Reviewer genericity gaps
# fixed in coder.md, code-reviewer.md, coder-rules/SKILL.md, settings.local.json.example.
#
# Coverage: 14 ACs automated (manual: CG1.4 cross-reference visual, CG3.5 settings.json
# diff verified by separate AC-T1 in plan §AC, CG4.5 visual SOURCE_GLOB note check
# embedded in CG4.3 predicate).

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

# CG1.1 — coder.md step 5 condition references LANGUAGE slot
awk '/Conditional: Load TDD skill/,/skip_behavior:|purpose:/' .claude/commands/coder.md \
  | grep -qE 'LANGUAGE[[:space:]]*==[[:space:]]*.go.|PROJECT-KNOWLEDGE\.md → LANGUAGE' \
  || fail "CG1.1 — coder.md TDD-load condition missing LANGUAGE slot reference"
pass "CG1.1 — coder.md TDD-load condition gates on LANGUAGE slot"

# CG1.2 — skip_behavior block present
awk '/Conditional: Load TDD skill/,/^[[:space:]]*purpose:/' .claude/commands/coder.md \
  | grep -q 'skip_behavior:' \
  || fail "CG1.2 — coder.md TDD-load missing skip_behavior block"
pass "CG1.2 — skip_behavior documented for non-Go SKIP path"

# CG1.3 — "kit ships Go-only TDD patterns" rationale present
awk '/Conditional: Load TDD skill/,/^[[:space:]]*purpose:/' .claude/commands/coder.md \
  | grep -q 'Go-only TDD patterns\|Go-only TDD' \
  || fail "CG1.3 — coder.md TDD-load missing Go-only acknowledgment"
pass "CG1.3 — Go-only TDD acknowledgment present in skip rationale"

# CG2.1 — code-reviewer.md GET CHANGES example: no internal/handler/user.go in active body
# Active body = lines BETWEEN the two fences ``` ... ``` following "Block structure (example):"
# 3-state machine: 0=before-header, 1=after-header-before-fence, 2=between-fences (PRINT), 3=after-second-fence
# Allowed: <!-- EXAMPLE (lang: ...) --> comment lines (those live AFTER second fence, automatically excluded).
ACTIVE_BLOCK=$(awk '
  /\*\*Block structure \(example\):\*\*/ { seen=1; next }
  seen==1 && /^```$/ { seen=2; next }
  seen==2 && /^```$/ { seen=3; next }
  seen==2 { print }
' .claude/agents/code-reviewer.md)
if [[ -z "$ACTIVE_BLOCK" ]]; then
  fail "CG2.1 — failed to extract active body of GET CHANGES example (predicate broken)"
fi
if echo "$ACTIVE_BLOCK" | grep -qE 'internal/handler/user\.go|internal/service/user\.go'; then
  fail "CG2.1 — internal/handler/user.go or internal/service/user.go still in active body of GET CHANGES example"
fi
pass "CG2.1 — GET CHANGES active body free of hardcoded Go paths"

# CG2.2 — active body uses SOURCE_GLOB slot reference
echo "$ACTIVE_BLOCK" | grep -qE 'SOURCE_GLOB|<files matching|<source-glob' \
  || fail "CG2.2 — GET CHANGES active body missing SOURCE_GLOB or slot-form reference"
pass "CG2.2 — GET CHANGES active body uses slot-form file-list reference"

# CG2.3 — at least 2 EXAMPLE (lang:) comment blocks present in/after the block
EXAMPLE_COUNT=$(awk '/\*\*Block structure \(example\):\*\*/{flag=1} flag' .claude/agents/code-reviewer.md \
                 | grep -cE '<!-- EXAMPLE \(lang:' | head -1 || true)
if [[ "${EXAMPLE_COUNT:-0}" -lt 2 ]]; then
  fail "CG2.3 — fewer than 2 EXAMPLE (lang:) comment blocks (count: ${EXAMPLE_COUNT:-0})"
fi
pass "CG2.3 — at least 2 EXAMPLE (lang:) blocks (count: ${EXAMPLE_COUNT})"

# CG3.1 — code-reviewer.md Worktree Optimization section contains MANDATORY + BLOCKER
awk '/^## Worktree Optimization/,/^## /' .claude/agents/code-reviewer.md \
  | grep -qE 'MANDATORY for non-Go|BLOCKER' \
  || fail "CG3.1 — Worktree Optimization section missing MANDATORY/BLOCKER tightened wording"
pass "CG3.1 — Worktree section uses MANDATORY + BLOCKER wording"

# CG3.2 — QUICK CHECK Pre-flight subsection present
awk '/^## Worktree Optimization/,/^## /' .claude/agents/code-reviewer.md \
  | grep -qE '### QUICK CHECK Pre-flight|worktree_sparsepaths_check' \
  || fail "CG3.2 — Worktree section missing QUICK CHECK Pre-flight subsection"
pass "CG3.2 — QUICK CHECK Pre-flight subsection present"

# CG3.3 — advisory issue ID CR-worktree-misconfigured documented
awk '/^## Worktree Optimization/,/^## /' .claude/agents/code-reviewer.md \
  | grep -q 'CR-worktree-misconfigured' \
  || fail "CG3.3 — Pre-flight missing CR-worktree-misconfigured advisory ID"
pass "CG3.3 — CR-worktree-misconfigured advisory ID documented"

# CG3.4 — settings.local.json.example contains Python/TypeScript/Rust template hints
for stack in 'python' 'typescript' 'rust'; do
  grep -qiE "_worktree_templates_${stack}" .claude/settings.local.json.example \
    || fail "CG3.4 — settings.local.json.example missing _worktree_templates_${stack} hint"
done
pass "CG3.4 — settings.local.json.example has Python/TypeScript/Rust template hints"

# CG3.5 — settings.json sparsePaths default UNCHANGED (R2 backwards-compat)
# Use jq for structural assertion (settings.json stores sparsePaths as multi-line array;
# grep -q is line-oriented and won't match across newlines).
jq -e '.worktree.sparsePaths == [".claude/", "internal/", "cmd/", "go.mod", "go.sum", "Makefile", "CLAUDE.md"]' \
   .claude/settings.json >/dev/null \
  || fail "CG3.5 — settings.json sparsePaths structure changed (R2 violated)"
pass "CG3.5 — settings.json sparsePaths default unchanged (R2 preserved)"

# CG4.1 — Output Format does not contain literal "path/file.go:line"
if grep -qE '^- Location:.*\.go:line' .claude/agents/code-reviewer.md; then
  fail "CG4.1 — Output Format Location still uses 'path/file.go:line' literal"
fi
pass "CG4.1 — Output Format Location is language-agnostic"

# CG4.2 — VERDICT_JSON example does not contain ".go:" in location field
if grep -qE '"location":[[:space:]]*"[^"]*\.go:' .claude/agents/code-reviewer.md; then
  fail "CG4.2 — VERDICT_JSON example still uses .go: in location field"
fi
pass "CG4.2 — VERDICT_JSON example free of .go: in location field"

# CG4.3 — Location-stability bullets free of Go-specific paths/extensions
# Locate the bulleted list under "Location-stability guidance" and assert no Go-isms.
if awk '/Location-stability guidance/,/Iteration 2\+/' .claude/agents/code-reviewer.md \
     | grep -E '^- (PREFER|ACCEPT|AVOID):' \
     | grep -qE 'internal/service/user\.go|handler/auth\.go|user\.go:42|\.go:'; then
  fail "CG4.3 — Location-stability bullets still contain Go-specific path/extension"
fi
pass "CG4.3 — Location-stability bullets are language-agnostic"

# CG4.4 — first PREFER bullet is Part-anchored symbol (mirror G4 PR-001 from P-stage)
FIRST_BULLET=$(awk '/Location-stability guidance/,/Iteration 2\+/' .claude/agents/code-reviewer.md \
                 | grep -E '^- (PREFER|ACCEPT|AVOID):' | head -1)
if ! echo "$FIRST_BULLET" | grep -qE '^- PREFER:.*Part [0-9]+:'; then
  fail "CG4.4 — first bulleted example is not Part-anchored symbol form: $FIRST_BULLET"
fi
pass "CG4.4 — symbol-only PREFER example is first (Part-anchored, mirrors G4 PR-001)"

# CG5.1 — coder-rules/SKILL.md does not contain literal "handler/API layer"
if grep -qF 'handler/API layer' .claude/skills/coder-rules/SKILL.md; then
  fail "CG5.1 — coder-rules/SKILL.md still contains literal 'handler/API layer'"
fi
pass "CG5.1 — 'handler/API layer' removed from coder-rules"

# CG5.2 — RULE_3 wording uses neutral "API/transport layer" or LAYERS slot
grep -qE 'API/transport layer|<INPUT_LAYER>|highest LAYERS entry' .claude/skills/coder-rules/SKILL.md \
  || fail "CG5.2 — RULE_3 missing neutral layer term (API/transport / <INPUT_LAYER> / LAYERS entry)"
pass "CG5.2 — RULE_3 uses neutral layer terminology"

# CG5.3 — both L13 (RULE_3 main) and L91 (Why) reference PROJECT-KNOWLEDGE.md → LAYERS
RULE_3_REFS=$(grep -cE 'PROJECT-KNOWLEDGE\.md → LAYERS' .claude/skills/coder-rules/SKILL.md || true)
if [[ "${RULE_3_REFS:-0}" -lt 2 ]]; then
  fail "CG5.3 — RULE_3 LAYERS pointer missing in one of L13/L91 (count: ${RULE_3_REFS:-0}, expected ≥2)"
fi
pass "CG5.3 — LAYERS slot pointer present in both RULE_3 main and Why"

# ════════════════════════════════════════════════════════════════════════
# MANUAL
# ════════════════════════════════════════════════════════════════════════
# CG1.4 — L367-370 tdd_mode reference consistency (visual cross-reference review)
# CG2.4 — SOURCE_GLOB pointer in active body (covered partly by CG2.2)
# CG4.5 — SOURCE_GLOB note in location-stability section (visual review of footer note)
# CG5.4 — no information loss in RULE_3 wording (intent preservation, visual review)

label "INFO" "test-c-stage-genericity-audit.sh complete — 16/19 ACs automated (manual: CG1.4, CG2.4, CG4.5, CG5.4)"
exit 0
```

**Why this exact structure:**
- Header comment cites the spec file, lists CG1-CG5 ACs, and notes coverage (16 automated / 4 manual).
- Helper functions (label/fail/pass) match `test-genericity-audit.sh` structure (P-stage symmetry).
- Awk state-flag idiom for parts_order-style ranges (lessons from P-stage G3.2 fix).
- CG3.5 explicitly verifies settings.json default UNCHANGED — operationalizes the R2 preservation contract as a test.
- Manual ACs documented in trailing comment block per kit convention from `test-p1..p5` and `test-genericity-audit.sh`.

**ACs covered (test predicates):** CG1.1, CG1.2, CG1.3, CG2.1, CG2.2, CG2.3, CG3.1, CG3.2, CG3.3, CG3.4, CG3.5, CG4.1, CG4.2, CG4.3, CG4.4, CG5.1, CG5.2, CG5.3 — **16 automated**.

**ACs deferred to manual:** CG1.4, CG2.4 (covered partly by CG2.2), CG4.5, CG5.4 — visual cross-references / intent preservation.

## Files Summary

| File | Action |
|---|---|
| `.claude/commands/coder.md` | UPDATE (Part 1 — 2 sub-edits) |
| `.claude/agents/code-reviewer.md` | UPDATE (Parts 2, 3, 5 — 4 sub-edits) |
| `.claude/skills/coder-rules/SKILL.md` | UPDATE (Part 6 — 2 sub-edits) |
| `.claude/settings.local.json.example` | UPDATE (Part 4 — 1 edit) |
| `.claude/scripts/tests/test-c-stage-genericity-audit.sh` | CREATE + chmod +x |

## Acceptance Criteria

### Functional
- **AC-F1:** After all 5 fixes, `bash .claude/scripts/tests/test-c-stage-genericity-audit.sh` exits 0 with all 16 automated ACs PASS.
- **AC-F2:** All 22 existing test scripts in `.claude/scripts/tests/` retain current PASS state (22/22 PASS post-`9ed4d66`).
- **AC-F3:** Spec ACs CG1.1-CG5.4 all satisfied (16 automated + 4 manual; manual ACs verified by code-reviewer agent on diff).

### Technical
- **AC-T1:** `git diff 9ed4d66..HEAD -- .claude/settings.json` is EMPTY — settings.json defaults UNCHANGED (preserves R2).
- **AC-T2:** `git diff 9ed4d66..HEAD -- .claude/schemas/handoff.schema.json` is EMPTY — schema unchanged (preserves C1, C2, C7).
- **AC-T3:** `git diff 9ed4d66..HEAD -- .claude/PROJECT-KNOWLEDGE.md.example` is EMPTY — PK schema unchanged (preserves C5).
- **AC-T4:** `git diff 9ed4d66..HEAD -- .claude/scripts/inject-review-context.sh` is EMPTY — 4 KB cap and PK injection logic preserved (preserves C6).
- **AC-T5:** `git diff 9ed4d66..HEAD -- .claude/scripts/save-review-checkpoint.sh` is EMPTY — IMP-03 ID normalization preserved (preserves C8).
- **AC-T6:** `git diff 9ed4d66..HEAD -- .claude/scripts/prepare-worktree.sh` is EMPTY — worktree hook unchanged (CG3 fix is doc/preflight only).
- **AC-T7:** New test script has `chmod +x` (executable bit set, file mode 0755).

### Architecture
- **AC-A1:** All 5 ARCHITECTURE_STYLE values (`layered`, `flat`, `event_driven`, `hexagonal`, `other`) handled coherently — CG3 pre-flight detects misconfig regardless of architecture style; CG5 LAYERS pointer applies when architecture is layered (SKIP otherwise per existing canonical SKIP rule).
- **AC-A2:** Slot syntax consistent — angle-`<SLOT>` for abstract roles (Parts 3, 5), curly-`{LAYERS[N]}` only when slot is set (none added in this fix). Mirrors P-stage convention from G2/G3/G4.
- **AC-A3:** No new dependencies — no new env vars, no new scripts beyond the test, no schema fields, no slot additions.

## Config Changes

- `.claude/settings.local.json.example` — adds 4 commented `_worktree_templates_*` hint lines (CG3 Part 4). The active `worktree.sparsePaths` value is UNCHANGED (kit-default `["internal/", "cmd/", "go.mod", "go.sum", "Makefile"]` retained — non-Go consumers replace this array with one of the 4 templates).
- `.claude/settings.json` — UNCHANGED (R2 contract).

## TDD

Skipped — text/config refactor with no logic changes. Test predicates written alongside fixes (Part 7); predicates fail on `9ed4d66` BEFORE Parts 1-6 are applied (verifies they gate correctly), then turn PASS once fixes land.

## Risks & Mitigations

| Risk | Severity | Mitigation |
|---|---|---|
| CG3 pre-flight pseudo-code in code-reviewer.md is illustrative — actual reviewer LLM may not implement it without explicit "MUST run before review" framing | LOW | Active-body documentation explicitly says "QUICK CHECK pre-flight verifies..." before BLOCKER consequence. The reviewer's existing QUICK CHECK phase (around step 0.5 in code-reviewer.md startup) is where this slots in. |
| Awk-based test predicates for CG2 (active block extraction) may break if YAML formatting drifts | LOW | Predicate uses paired delimiter (`**Block structure (example):**` start, second `^```$` end). If formatting drifts, test fails noisily — easy to fix. |
| `_worktree_templates_*` underscore-key hints in settings.local.json.example are NOT activated by Claude Code runtime — purely informational | LOW (intentional) | Kit convention from L13 of same file: "keys with a leading '_' are inactive — remove the underscore prefix to activate them." Consumers MUST manually replace `worktree.sparsePaths` array; templates are reference text, not auto-applied. CG3.4 test verifies presence, not activation. |
| New test script `test-c-stage-genericity-audit.sh` blocked by global `.gitignore` for `.claude/` | LOW | Use `git add -f` consistent with existing pattern (test-p1..p5, test-genericity-audit force-added in commits `c55e9f5`, `27ab4f7`). |
| CG1 `LANGUAGE unset` clause keeps backwards-compat for current kit users without PK populated | LOW | Acknowledged: kit's own dogfood has LANGUAGE=go in PROJECT-KNOWLEDGE.md (verified via spec §0). Non-kit consumers without PK populated default to Go behavior — same as before this fix. The fix only affects consumers who EXPLICITLY set `LANGUAGE != 'go'`. |

## Out-of-Scope (Repeating Spec §6 for Coder Awareness)

Per "5 problems, do them well" + spec §6:

- coder.md L77 multi-language slot framing — already correct.
- coder.md L432 CLAUDE.md fallback "kit-default for Go projects" — explicitly Go-scoped fallback, acceptable.
- code-review-rules/examples.md L64 logger regex `log\.(Error|Warn|Info)` — wrap-in-EXAMPLE-comment fix; defer to separate audit.
- CLAUDE.md L13 "race check: go test -race" — kit dogfood; out of scope.
- settings.json L8-13 Go permissions — kit dogfood; out of scope.
- auto-fmt-go.sh / pre-commit-build.sh / import-matrix-prompt.sh — Go-scoped by name with `**/*.go` matchers; correct gating.
- Slot syntax inconsistency (`{X}` vs `<X>`) — separate audit.

---

**Total estimated effort:** 45-60 minutes for /coder phase. Coder edits 4 files + writes 1 new test + extends 1 settings.example, runs full test suite, reports verify_status: PASS (target 23/23).
