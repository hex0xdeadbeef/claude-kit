---
meta:
  type: "plan"
  feature: "coder-codereview-audit"
  produced_by: "/planner"
  status: "ready_for_review"
  spec_referenced: true
  spec_artifact: ".claude/prompts/coder-codereview-audit-spec.md"
  task_type: "refactoring"
  complexity: "XL"
  alternatives_considered: 2
  sequential_thinking_used: true
  parts_count: 5
  layers: ["orchestrator", "reviewers", "enforcement", "knowledge"]
  baseline: "v1.22.0 + b8d9fd1 (5 fixes) + cdc0e85 (FUNC_LOC_LIMIT revert)"
  tests_baseline: "41 PASS / 0 FAIL"
  tests_after: "46 PASS / 0 FAIL (5 new)"
---

# Plan: Coder + Code-Reviewer Pipeline Audit (v3 wave)

## Context

Plan реализует 5 правок из approved spec'а `.claude/prompts/coder-codereview-audit-spec.md`. Все правки additive — никаких contract breaks. Schema bump 1.1.0 → 1.2.0.

**Pre-flight verified:**
- 41/41 baseline tests PASS (`bash .claude/scripts/tests/test-*.sh`)
- handoff.schema.json v1.1.0 содержит 5 oneOf entries
- `.claude/agents/code-reviewer.md:139` — целевая строка `Functions ≤ 30 lines (flag if exceeded)` присутствует
- `.claude/skills/workflow-protocols/orchestration-core.md:108-115` — `increment_rules` отсутствует правило для code-review NEEDS_CHANGES

## Scope

### In

- P-1: NEEDS_CHANGES legacy alias normalization at orchestrator (re-routing.md + orchestration-core.md + delegation-templates.md + telemetry record `verdict_alias_normalized`)
- P-2: `code_review_to_completion` schema variant + write step at orchestrator + coder Phase 0.5 read (closes IMP-01.2)
- P-3: `spec_check.failure_after_retry` optional bool + spec-check.md retry exhaustion semantics + code-reviewer.md BLOCKER-on-flag rule
- P-4: Полное удаление "Functions ≤ 30 lines" bullet из `code-reviewer.md` (function-length = ответственность project linter)
- P-5: `narrative_for_reviewer` summary-only contract в coder.md + `narrative_truncated` telemetry record в delegation-templates.md

### Out

- item: "Реинтродукция FUNC_LOC_LIMIT slot или LANGUAGE-conditional threshold"
  reason: "P-4 — full removal, без conditional. Линтеры покрывают."
- item: "Расширение narrative_for_reviewer cap > 600"
  reason: "Cap зафиксирован spec'ом C-4. P-5 решает через summary-only contract."
- item: "Изменение existing required-fields в `coder_to_code_review`"
  reason: "C-1 additive only. failure_after_retry — optional."
- item: "Удаление NEEDS_CHANGES из enum схемы"
  reason: "Cross-version compatibility — нельзя сломать legacy fixtures."

## Architecture Decision

### Selected approach: Additive-only patches + orchestrator-level normalization

**Rationale:** Mirrors waves 1-2 success pattern (schema additive bumps, telemetry-only signal addition). Каждый Part touch'ит ≤4 файла, имеет dedicated тест, не меняет existing required-fields.

### Alternatives considered

- option: "One-shot mega-refactor handoff format"
  rejected_because: "Ломает 5 контрактов, переписывает validate-handoff.sh + save-review-checkpoint.sh, риск регрессии 41 теста."
- option: "Hook-only fixes (без правок agent prose)"
  rejected_because: "P-2/P-3/P-5 требуют semantic-aware изменений в coder.md и code-reviewer.md — hook не знает intent."

### Chosen

approach: "Additive 5 Parts по одному на проблему; schema 1.1.0 → 1.2.0 minor bump; telemetry only через record_kind extensions"
rationale: "Минимизирует blast radius. Каждый Part независим (по файлам и тестам). Можно merge'ить incrementально или revert'ить избирательно."

## Diff Manifest

iter=1, нет prior plan, секция `diff_vs_prior_iteration` отсутствует — plan-reviewer запускает full validation (AC-8 backward-compat path).

## Parts

---

### Part 1: NEEDS_CHANGES alias normalization at orchestrator

**Files touched (4):**
1. `.claude/skills/workflow-protocols/re-routing.md` (UPDATE — append rule)
2. `.claude/skills/workflow-protocols/orchestration-core.md` (UPDATE — Mermaid edge + increment_rules)
3. `.claude/skills/workflow-protocols/delegation-templates.md` (UPDATE — code_review_delegation.post_delegation step)
4. `.claude/scripts/tests/test-needs-changes-alias-routing.sh` (CREATE)

**Description:** Code-reviewer schema допускает legacy alias `NEEDS_CHANGES` для `code_review_verdict`, но orchestrator не обрабатывает его наравне с `CHANGES_REQUESTED`. Часть документирует canonical alias normalization, часть добавляет telemetry record `verdict_alias_normalized` при срабатывании.

**Closes ACs:** AC-P1.1, AC-P1.2, AC-P1.3, AC-P1.4, AC-P1.5.

#### 1.1 — re-routing.md (UPDATE)

**Append после существующего блока `re_routing.triggers` (после `learning:` line на L38):**

```yaml

  verdict_aliases:
    purpose: "Normalize legacy verdict variants to canonical forms before routing"
    rules:
      - source: "code_review_verdict"
        legacy_alias: "NEEDS_CHANGES"
        canonical: "CHANGES_REQUESTED"
        rationale: |
          Schema 1.1.0+ keeps NEEDS_CHANGES in code_review_verdict.enum for cross-version
          compatibility (legacy review-completions.jsonl entries). Orchestrator MUST treat
          NEEDS_CHANGES from code-reviewer identically to CHANGES_REQUESTED:
          - increment code_review counter
          - append issues_history entry (phase=4)
          - re-route to Phase 3 (/coder) via review-response.md path
        when_emitted: |
          Reviewer agents are instructed to PREFER CHANGES_REQUESTED. NEEDS_CHANGES emission
          may still occur via:
          - regex_fallback path in save-review-checkpoint.sh (non-deterministic agent text)
          - verdict-recovery agent on incomplete-output recovery
          - legacy review-completions.jsonl restore on session resume
        telemetry:
          record_kind: "verdict_alias_normalized"
          file: ".claude/workflow-state/handoff-validation.jsonl"
          payload:
            ts: "ISO-8601 UTC"
            agent: "code-reviewer"
            original_verdict: "NEEDS_CHANGES"
            normalized_verdict: "CHANGES_REQUESTED"
            iteration: "{N}/3"
            session_id: "{session_id}"
      - source: "plan_review_verdict"
        note: |
          plan_review_verdict.enum already canonicalises NEEDS_CHANGES (it is the
          authoritative variant for plan-review). No alias normalisation needed.
```

#### 1.2 — orchestration-core.md (UPDATE)

**Edit Mermaid edge на L42** (current `CR -->|CHANGES_REQUESTED\nmax 3x| COD`):

```diff
-    CR -->|CHANGES_REQUESTED\nmax 3x| COD
+    CR -->|"CHANGES_REQUESTED | NEEDS_CHANGES (alias)\nmax 3x"| COD
```

**Edit phase-4 prose на L64** (current text — minimal diff per PR-001):

```diff
-**Phase 4 — Code Review:** Before delegating, run `git worktree prune 2>/dev/null || true` to clean stale worktree metadata from crashed sessions. Delegate to code-reviewer agent. APPROVED → Done. APPROVED_WITH_COMMENTS → Done (log comments, proceed to completion). CHANGES_REQUESTED → Phase 3 (iteration N/3).
+**Phase 4 — Code Review:** Before delegating, run `git worktree prune 2>/dev/null || true` to clean stale worktree metadata from crashed sessions. Delegate to code-reviewer agent. APPROVED → Done. APPROVED_WITH_COMMENTS → Done (log comments, proceed to completion). CHANGES_REQUESTED OR NEEDS_CHANGES (legacy alias, normalized to CHANGES_REQUESTED) → Phase 3 (iteration N/3). Alias normalization emits `record_kind: "verdict_alias_normalized"` to handoff-validation.jsonl (see re-routing.md → verdict_aliases).
```

> Note (PR-001 addressed): "REJECTED → Stop" clause dropped from `+` line — strict alias-normalization scope only. Existing REJECTED termination remains implied by mermaid edge `STOP_CR` (L24).

**Edit increment_rules на L108-115** (append entry для code-review NEEDS_CHANGES alias):

```diff
   increment_rules:
     - trigger: "plan-review verdict = NEEDS_CHANGES"
       action: "plan_review_counter += 1"
       then: "Append issues_history entry (phase=2, verdict, issues, resolved=[]) → Guard check → write checkpoint → re-run /planner"
       resolved_population: "pre_delegation step (before next plan-reviewer launch) populates resolved[] in previous entry from planner handoff"
     - trigger: "code-review verdict = CHANGES_REQUESTED"
       action: "code_review_counter += 1"
       then: "Append issues_history entry (phase=4, verdict, issues, resolved=[]) → Guard check → write checkpoint → re-run /coder"
       resolved_population: "pre_delegation step (before next code-reviewer launch) populates resolved[] in previous entry from coder handoff"
+    - trigger: "code-review verdict = NEEDS_CHANGES (legacy alias)"
+      action: "code_review_counter += 1 (treated identically to CHANGES_REQUESTED via re-routing.md → verdict_aliases)"
+      then: "Normalize verdict to CHANGES_REQUESTED → append issues_history entry (phase=4, verdict=CHANGES_REQUESTED, original_verdict=NEEDS_CHANGES, issues, resolved=[]) → emit `verdict_alias_normalized` telemetry record → Guard check → write checkpoint → re-run /coder"
+      telemetry: |
+        Append to .claude/workflow-state/handoff-validation.jsonl:
+          {
+            "ts": "{ISO-8601 UTC}",
+            "record_kind": "verdict_alias_normalized",
+            "agent": "code-reviewer",
+            "original_verdict": "NEEDS_CHANGES",
+            "normalized_verdict": "CHANGES_REQUESTED",
+            "iteration": "{N}/3",
+            "session_id": "{session_id}"
+          }
```

#### 1.3 — delegation-templates.md (UPDATE)

**Indentation rule (PR-003 addressed):** `post_delegation` is a YAML `|`-block scalar. The new step `2.1` and its sub-points `a..e` MUST match the existing scalar-block indentation: 4 spaces from the parent `post_delegation: |` key (i.e. step labels at column 5, sub-points indented 7-9 spaces consistent with surrounding `2.5 (IMP-04 — KD-4 contract-break routing)` block at L122-138). Tests use grep substring match, but consistent indent aids future patches.

**Edit `code_review_delegation.post_delegation` step 2 на L309** (current `Extract verdict from VERDICT: header`):

```diff
     2. Extract verdict from VERDICT: header (first line)
+    2.1 (P-1 alias normalization): If extracted verdict == "NEEDS_CHANGES" (code-review legacy alias):
+        a. Normalize: routing_verdict = "CHANGES_REQUESTED"
+        b. Append record to .claude/workflow-state/handoff-validation.jsonl:
+             {
+               "ts": "{ISO-8601 UTC now}",
+               "record_kind": "verdict_alias_normalized",
+               "agent": "code-reviewer",
+               "original_verdict": "NEEDS_CHANGES",
+               "normalized_verdict": "CHANGES_REQUESTED",
+               "iteration": "{N}/3",
+               "session_id": "{session_id}"
+             }
+        c. Use routing_verdict for ALL downstream routing decisions (counter increment, issues_history, re-route).
+        d. Preserve original_verdict in checkpoint.issues_history[entry].original_verdict for audit trail.
+        e. Reference: re-routing.md → verdict_aliases.
```

#### 1.4 — test-needs-changes-alias-routing.sh (CREATE)

**File:** `.claude/scripts/tests/test-needs-changes-alias-routing.sh` (mode 755)

```bash
#!/usr/bin/env bash
# test-needs-changes-alias-routing.sh
# AC-P1.1, AC-P1.2, AC-P1.3, AC-P1.4, AC-P1.5: NEEDS_CHANGES alias from code-reviewer is documented as
# routing-equivalent to CHANGES_REQUESTED + emits verdict_alias_normalized telemetry record.
set -euo pipefail
SCRIPT_NAME="$(basename "$0")"
PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
label() { echo "[${SCRIPT_NAME}] $1: $2" >&2; }
fail() { label "FAIL" "$1"; exit 1; }
pass() { label "PASS" "$1"; }
cd "$PROJECT_ROOT"

REROUT=".claude/skills/workflow-protocols/re-routing.md"
ORCH=".claude/skills/workflow-protocols/orchestration-core.md"
DELEG=".claude/skills/workflow-protocols/delegation-templates.md"

# AC-P1.1: re-routing.md contains verdict_aliases block with NEEDS_CHANGES → CHANGES_REQUESTED rule
grep -q 'verdict_aliases:' "$REROUT" \
  || fail "AC-P1.1a — verdict_aliases block missing from re-routing.md"
grep -q 'legacy_alias: "NEEDS_CHANGES"' "$REROUT" \
  || fail "AC-P1.1b — NEEDS_CHANGES alias entry missing from re-routing.md"
grep -q 'canonical: "CHANGES_REQUESTED"' "$REROUT" \
  || fail "AC-P1.1c — canonical mapping CHANGES_REQUESTED missing from re-routing.md"
pass "AC-P1.1 — re-routing.md contains alias normalization rule"

# AC-P1.2: orchestration-core.md Mermaid edge mentions NEEDS_CHANGES alias
grep -qE 'CR -->\|"?CHANGES_REQUESTED \| NEEDS_CHANGES \(alias\)' "$ORCH" \
  || fail "AC-P1.2 — Mermaid edge does not mention NEEDS_CHANGES (alias)"
pass "AC-P1.2 — Mermaid edge updated"

# AC-P1.3: increment_rules has entry for code-review NEEDS_CHANGES alias
grep -q 'trigger: "code-review verdict = NEEDS_CHANGES (legacy alias)"' "$ORCH" \
  || fail "AC-P1.3 — increment_rules missing entry for code-review NEEDS_CHANGES alias"
pass "AC-P1.3 — increment_rules covers NEEDS_CHANGES alias"

# AC-P1.4: delegation-templates.md post_delegation step 2.1 documents normalization + telemetry write
grep -q '2.1 (P-1 alias normalization)' "$DELEG" \
  || fail "AC-P1.4a — step 2.1 alias normalization missing from delegation-templates.md"
grep -q '"record_kind": "verdict_alias_normalized"' "$DELEG" \
  || fail "AC-P1.4b — verdict_alias_normalized record_kind not documented in delegation-templates.md"
pass "AC-P1.4 — delegation-templates.md documents alias normalization step"

# AC-P1.5: telemetry record_kind 'verdict_alias_normalized' документирован в re-routing.md
grep -q 'record_kind: "verdict_alias_normalized"' "$REROUT" \
  || fail "AC-P1.5 — verdict_alias_normalized record_kind not documented in re-routing.md"
pass "AC-P1.5 — telemetry record_kind documented"

label "PASS" "all AC-P1.* assertions passed"
```

---

### Part 2: code_review_to_completion handoff schema + write step + coder read

**Files touched (5):**
1. `.claude/schemas/handoff.schema.json` (UPDATE — add `code_review_to_completion` $def + extend oneOf; bump version 1.1.0 → 1.2.0)
2. `.claude/skills/workflow-protocols/handoff-protocol.md` (UPDATE — remove `code_review_to_completion` from `contracts_not_yet_covered`; document write timing)
3. `.claude/skills/workflow-protocols/delegation-templates.md` (UPDATE — `code_review_delegation.post_delegation` step 6.5 writes JSON)
4. `.claude/commands/coder.md` (UPDATE — Phase 0.5 STARTUP reads JSON if present, fallback to delegation-prompt path)
5. `.claude/scripts/tests/test-code-review-to-completion-handoff.sh` (CREATE)

**Description:** Закрытие IMP-01.2: orchestrator после извлечения verdict пишет handoff JSON в `.claude/workflow-state/{feature}-handoff.json` с discriminator `$handoff_contract: "code_review_to_completion"`. Coder при re-entry на CHANGES_REQUESTED читает этот файл (если present) для structured issues; fallback на existing delegation-prompt-text path при absence.

**Closes ACs:** AC-P2.1..AC-P2.7.

#### 2.1 — handoff.schema.json (UPDATE)

**Bump version + extend `oneOf` + add $def. Existing 5 entries сохраняются byte-identical.**

Edit `version: "1.1.0"` → `version: "1.2.0"`.

Edit `description` (L6) — append: ` Schema version 1.2.0 (additive minor): added code_review_to_completion contract (closes IMP-01.2). Existing 1.0.0/1.1.0 fixtures remain valid (additive only).`

Edit `oneOf` array (L7-13) — append одну entry:

```diff
   "oneOf": [
     { "$ref": "#/$defs/planner_to_plan_review" },
     { "$ref": "#/$defs/plan_review_to_coder" },
     { "$ref": "#/$defs/coder_to_code_review" },
     { "$ref": "#/$defs/plan_review_verdict" },
-    { "$ref": "#/$defs/code_review_verdict" }
+    { "$ref": "#/$defs/code_review_verdict" },
+    { "$ref": "#/$defs/code_review_to_completion" }
   ],
```

**Add new $def внутри `$defs` (после `coder_to_code_review` definition, перед closing `}`):**

```json
,
    "code_review_to_completion": {
      "title": "code_review_to_completion",
      "description": "Handoff from code-reviewer agent to workflow/completion (or coder re-entry on CHANGES_REQUESTED). Closes IMP-01.2 — symmetry with plan_review_to_coder. Written by orchestrator post_delegation step 6.5 after verdict extraction.",
      "type": "object",
      "required": [
        "$handoff_contract",
        "verdict",
        "issues",
        "iteration"
      ],
      "properties": {
        "$handoff_contract": {
          "const": "code_review_to_completion",
          "description": "Discriminator — must be 'code_review_to_completion'."
        },
        "verdict": {
          "type": "string",
          "enum": ["APPROVED", "APPROVED_WITH_COMMENTS", "CHANGES_REQUESTED", "NEEDS_CHANGES", "REJECTED"],
          "description": "Code-reviewer verdict (post-alias-normalization at orchestrator). NEEDS_CHANGES retained for cross-version compatibility — see re-routing.md verdict_aliases."
        },
        "original_verdict": {
          "type": "string",
          "enum": ["APPROVED", "APPROVED_WITH_COMMENTS", "CHANGES_REQUESTED", "NEEDS_CHANGES", "REJECTED"],
          "description": "OPTIONAL. Pre-normalization verdict. Set when alias normalization occurred (e.g., NEEDS_CHANGES → CHANGES_REQUESTED). Absent when no normalization."
        },
        "issues": {
          "type": "array",
          "description": "Canonical-ID issues from code-reviewer's structured verdict. Mirror of code_review_verdict.issues shape — same per-issue caps.",
          "maxItems": 30,
          "items": {
            "type": "object",
            "required": ["id", "severity", "category", "problem"],
            "properties": {
              "id":         { "type": "string", "pattern": "^CR-[0-9a-f]{8}$" },
              "severity":   { "type": "string", "enum": ["BLOCKER", "MAJOR", "MINOR", "NIT"] },
              "category":   { "type": "string", "maxLength": 64 },
              "location":   { "type": "string", "maxLength": 200 },
              "problem":    { "type": "string", "maxLength": 400 },
              "suggestion": { "type": "string", "maxLength": 400 },
              "reference":  { "type": "string", "maxLength": 400 }
            },
            "additionalProperties": false
          }
        },
        "iteration": {
          "type": "string",
          "description": "Code-review iteration counter. Format N/3 where N in {1,2,3} (max 3 per workflow loop limit).",
          "pattern": "^[123]/3$"
        },
        "narrative_for_coder": {
          "type": "string",
          "description": "OPTIONAL. Brief recommendation summary for coder re-entry (≤400 chars). Detailed issues live in issues[].",
          "maxLength": 400
        }
      },
      "additionalProperties": false
    }
```

#### 2.2 — handoff-protocol.md (UPDATE)

Edit `contracts_covered` block (L152-158):

```diff
     contracts_covered:
       - "planner_to_plan_review — written in plan_review_delegation.pre_delegation step 0"
       - "plan_review_to_coder — written in plan_review_delegation.post_delegation step 4.5"
       - "coder_to_code_review — written in code_review_delegation.pre_delegation STEP 0 (since this Part)"
+      - "code_review_to_completion — written in code_review_delegation.post_delegation step 6.5 (since v1.23.x — closes IMP-01.2)"
     contracts_not_yet_covered:
-      - "designer_to_planner, code_review_to_completion → IMP-01.2"
+      - "designer_to_planner → future"
```

Edit `code_review_to_completion` payload definition (L89-101) — add discriminator + optional fields:

```diff
     code_review_to_completion:
       producer: "code-reviewer (agent)"
       consumer: "workflow/completion"
       payload:
+        "$handoff_contract": "code_review_to_completion"  # IMP-01.2 discriminator
         verdict: "APPROVED|APPROVED_WITH_COMMENTS|CHANGES_REQUESTED"
+        original_verdict: "{pre-normalization verdict, e.g. NEEDS_CHANGES}"  # OPTIONAL
         issues:
           - id: "CR-001"
             severity: "BLOCKER|MAJOR|MINOR|NIT"
             category: "architecture|security|error_handling|completeness|style"
             location: "path/file{EXT}:line"
             problem: "..."
             suggestion: "..."
         iteration: "N/3"
+        narrative_for_coder: "{brief recommendation summary ≤400 chars}"  # OPTIONAL
```

#### 2.3 — delegation-templates.md (UPDATE)

**Indentation rule (PR-003 addressed):** Same as §1.3 — `post_delegation` `|`-scalar requires 4-space indentation from parent key. The new `6.5 (IMP-01.2 …)` step label sits at column 5; nested fields (JSON shape, source-of-fields, failure-handling) follow consistent 7-9 space indent matching surrounding step 2.5/3-6 blocks.

Append после `code_review_delegation.post_delegation` step 6 (L327, currently `Write checkpoint: phase_completed=4, verdict={extracted_verdict}`):

```diff
     6. Write checkpoint: phase_completed=4, verdict={extracted_verdict}
+    6.5 (IMP-01.2 — symmetry with plan_review_delegation step 6.5):
+        Write code-review handoff JSON to .claude/workflow-state/{feature}-handoff.json.
+        Hook auto-validates on write. Format (contract code_review_to_completion):
+          {
+            "$handoff_contract": "code_review_to_completion",
+            "verdict": "{normalized verdict}",
+            "original_verdict": "{pre-normalization verdict if alias normalised, omit otherwise}",
+            "issues": [{ ...canonical-ID issues from latest review-completions.jsonl entry... }],
+            "iteration": "{N}/3",
+            "narrative_for_coder": "{≤400 char summary, OPTIONAL}"
+          }
+        Source of fields:
+          - verdict, original_verdict: from step 2 + step 2.1 (alias normalization)
+          - issues: read canonical_issue_ids[] from latest review-completions.jsonl entry; map to schema shape using IMP-03 normalised IDs; severity/category/problem/suggestion/location populated from canonical_issue_ids[].* fields written by save-review-checkpoint.sh
+          - iteration: from checkpoint.iteration.code_review
+          - narrative_for_coder: extract from agent's narrative section if ≤400 chars, omit otherwise
+        Failure handling: if write fails (disk error) or validation fails in strict mode →
+          log WARN to handoff-validation.jsonl (record_kind: "code_review_to_completion_write_failed")
+          and proceed with re-route (graceful degradation; coder falls back to delegation-prompt-text path).
+        Backwards compat: file is OPTIONAL on coder side — Phase 0.5 reads if present, falls back if absent.
     7. If verdict is INCOMPLETE → Read .claude/skills/workflow-protocols/incomplete-output-recovery.md
        and follow on_incomplete_output fallback chain (step_0..step_5).
```

#### 2.4 — coder.md (UPDATE)

Edit Phase 0.5 (L218-229, currently REVIEW RESPONSE). Insert новый sub-step "Read structured handoff" перед `steps:`:

```diff
     - phase: 0.5
       name: "REVIEW RESPONSE (re-entry only)"
       condition: "Active when /coder re-enters after CHANGES_REQUESTED"
       skip_when: "First run (no prior code-review)"
       reference: ".claude/skills/coder-rules/review-response.md"
+      structured_handoff_read:
+        when: "On Phase 0.5 entry, BEFORE TRIAGE step"
+        action: |
+          Check for .claude/workflow-state/{feature}-handoff.json with discriminator
+          $handoff_contract == "code_review_to_completion" (IMP-01.2). If present:
+          - Use issues[] from JSON as authoritative source (canonical CR-IDs included).
+          - Use original_verdict (if set) to detect alias-normalized cases.
+          - Use narrative_for_coder (if set) as supplemental context.
+          If absent OR discriminator mismatch:
+          - Fall back to delegation-prompt-text path (existing behavior).
+          - Issues parsed from prompt text + checkpoint.issues_history[].
+        rationale: "Closes IMP-01.2 asymmetry. Schema-validated issues replace text parsing."
+        reference: ".claude/schemas/handoff.schema.json → code_review_to_completion"
       steps:
         - "TRIAGE: Parse issues by severity from code-reviewer handoff"
         - "VERIFY: Check each issue against current codebase"
         - "EVALUATE: ACCEPT / PUSH_BACK / CLARIFY per issue"
         - "Output: issues triage summary → feeds into IMPLEMENT phase"
       note: "Replaces EVALUATE (Phase 1.5) on re-entry — plan already validated, focus on review feedback"
```

#### 2.5 — test-code-review-to-completion-handoff.sh (CREATE)

**File:** `.claude/scripts/tests/test-code-review-to-completion-handoff.sh` (mode 755)

```bash
#!/usr/bin/env bash
# test-code-review-to-completion-handoff.sh
# AC-P2.1..AC-P2.7: code_review_to_completion contract closure (IMP-01.2).
set -euo pipefail
SCRIPT_NAME="$(basename "$0")"
PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
label() { echo "[${SCRIPT_NAME}] $1: $2" >&2; }
fail() { label "FAIL" "$1"; exit 1; }
pass() { label "PASS" "$1"; }
cd "$PROJECT_ROOT"

SCHEMA=".claude/schemas/handoff.schema.json"
HANDOFF=".claude/skills/workflow-protocols/handoff-protocol.md"
DELEG=".claude/skills/workflow-protocols/delegation-templates.md"
CODER=".claude/commands/coder.md"
VALIDATOR=".claude/scripts/validate-handoff.sh"

# AC-P2.1: schema contains $def code_review_to_completion with discriminator
grep -q '"code_review_to_completion"' "$SCHEMA" \
  || fail "AC-P2.1a — code_review_to_completion $def missing from schema"
grep -q '"const": "code_review_to_completion"' "$SCHEMA" \
  || fail "AC-P2.1b — discriminator const missing"
pass "AC-P2.1 — schema $def + discriminator present"

# AC-P2.2: oneOf has 6 entries
ONEOF_COUNT=$(python3 -c "import json; s=json.load(open('$SCHEMA')); print(len(s['oneOf']))")
[[ "$ONEOF_COUNT" == "6" ]] || fail "AC-P2.2a — oneOf count = $ONEOF_COUNT, expected 6"
# version bumped
VERSION=$(python3 -c "import json; s=json.load(open('$SCHEMA')); print(s['version'])")
[[ "$VERSION" == "1.2.0" ]] || fail "AC-P2.2b — schema version = $VERSION, expected 1.2.0"
pass "AC-P2.2 — oneOf=6 + version=1.2.0"

# AC-P2.3: delegation-templates.md post_delegation step 6.5
grep -q '6.5 (IMP-01.2' "$DELEG" \
  || fail "AC-P2.3a — post_delegation step 6.5 missing"
grep -q '"\$handoff_contract": "code_review_to_completion"' "$DELEG" \
  || fail "AC-P2.3b — discriminator not referenced in step 6.5"
pass "AC-P2.3 — delegation step 6.5 documented"

# AC-P2.4: coder.md Phase 0.5 structured_handoff_read
grep -q 'structured_handoff_read:' "$CODER" \
  || fail "AC-P2.4a — coder Phase 0.5 missing structured_handoff_read"
grep -q 'code_review_to_completion' "$CODER" \
  || fail "AC-P2.4b — coder.md does not reference code_review_to_completion contract"
pass "AC-P2.4 — coder.md Phase 0.5 reads structured handoff"

# AC-P2.5: graceful fallback documented
grep -qE 'Fall back to delegation-prompt-text path|If absent.* Fall back' "$CODER" \
  || fail "AC-P2.5 — fallback path not documented in coder.md"
pass "AC-P2.5 — graceful fallback documented"

# AC-P2.6: validator accepts valid + rejects invalid fixture
FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

VALID_FIXTURE="$FIXTURE_DIR/valid-completion.json"
cat > "$VALID_FIXTURE" <<'JSON'
{
  "$handoff_contract": "code_review_to_completion",
  "verdict": "CHANGES_REQUESTED",
  "original_verdict": "NEEDS_CHANGES",
  "issues": [
    {"id": "CR-ab12cd34", "severity": "MAJOR", "category": "error_handling", "problem": "missing nil check in handler"}
  ],
  "iteration": "2/3",
  "narrative_for_coder": "Re-iter focus: handler error path."
}
JSON
bash "$VALIDATOR" "$VALID_FIXTURE" 2>/dev/null \
  || fail "AC-P2.6a — valid code_review_to_completion fixture rejected"
pass "AC-P2.6a — valid fixture accepted"

INVALID_FIXTURE="$FIXTURE_DIR/invalid-completion.json"
cat > "$INVALID_FIXTURE" <<'JSON'
{
  "$handoff_contract": "code_review_to_completion",
  "verdict": "CHANGES_REQUESTED",
  "issues": [],
  "iteration": "5/3"
}
JSON
set +e
CLAUDE_HANDOFF_VALIDATION_MODE=strict bash "$VALIDATOR" "$INVALID_FIXTURE" 2>/dev/null
RC=$?
set -e
[[ $RC -ne 0 ]] || fail "AC-P2.6b — invalid fixture (iteration=5/3) accepted in strict mode"
pass "AC-P2.6b — invalid fixture rejected (iteration pattern violation)"

# AC-P2.7: handoff-protocol.md updated
grep -q 'code_review_to_completion → future' "$HANDOFF" \
  && fail "AC-P2.7 — code_review_to_completion still listed as 'not yet covered' in handoff-protocol.md"
grep -q 'code_review_to_completion — written in code_review_delegation.post_delegation step 6.5' "$HANDOFF" \
  || fail "AC-P2.7 — handoff-protocol.md does not document covered contract"
pass "AC-P2.7 — handoff-protocol.md reflects covered contract"

# Existing fixtures remain valid (backward-compat regression guard)
for f in .claude/scripts/tests/fixtures/valid-*.json; do
  bash "$VALIDATOR" "$f" 2>/dev/null \
    || fail "regression — existing fixture $(basename "$f") no longer validates after schema 1.2.0 bump"
done
pass "regression — all existing valid fixtures still pass schema 1.2.0"

label "PASS" "all AC-P2.* assertions passed"
```

---

### Part 3: spec_check.failure_after_retry — additive schema + reviewer BLOCKER rule

**Files touched (4):**
1. `.claude/schemas/handoff.schema.json` (UPDATE — add `failure_after_retry` optional bool to `coder_to_code_review.spec_check.properties`)
2. `.claude/skills/coder-rules/spec-check.md` (UPDATE — set field at retry exhaustion)
3. `.claude/agents/code-reviewer.md` (UPDATE — PARTIAL && failure_after_retry → BLOCKER)
4. `.claude/scripts/tests/test-spec-check-failure-after-retry-blocker.sh` (CREATE)

**Description:** Spec-check retry exhaustion currently silent-demotes FAIL→PARTIAL→MINOR. Adds optional flag в `coder_to_code_review.spec_check`; reviewer raises BLOCKER (not MINOR) when flag set.

**Closes ACs:** AC-P3.1..AC-P3.6.

#### 3.1 — handoff.schema.json (UPDATE)

В `coder_to_code_review.properties.spec_check.properties` (L317-332) добавить optional bool:

```diff
         "spec_check": {
           "type": "object",
           "description": "Output of /coder Phase 3.5 SPEC CHECK. Optional — present for L/XL complexity; missing for S complexity (lightweight mode).",
           "properties": {
             "status": { "type": "string", "enum": ["PASS", "PARTIAL", "FAIL"] },
             "coverage_pct": { "type": "integer", "minimum": 0, "maximum": 100 },
             "deviations_confirmed": {
               "type": "array",
               "items": { "type": "string" }
             },
             "ac_coverage": {
               "type": "array",
               "items": { "type": "string" }
             },
             "issues": {
               "type": "array",
               "items": { "type": "object" }
             },
+            "failure_after_retry": {
+              "type": "boolean",
+              "description": "OPTIONAL flag (default: absent → false). Set to true by /coder Phase 3.5 when status=PARTIAL was reached via retry exhaustion (FAIL → 1 retry → still FAIL → status set to PARTIAL per spec-check.md). Code-reviewer treats PARTIAL+failure_after_retry==true as BLOCKER (category: completeness), not MINOR. Closes silent demotion bypass."
+            }
           },
           "additionalProperties": true
         },
```

#### 3.2 — spec-check.md (UPDATE)

Edit "Inline Fix Protocol" section (L54-59):

```diff
 ## Inline Fix Protocol

 - FAIL (missing Part): implement missing Part → re-run VERIFY → re-run SPEC CHECK
-- **Max 1 inline fix retry.** If still FAIL after retry → set status: PARTIAL, proceed
-- PARTIAL: document gaps, proceed to handoff. code-reviewer treats gaps as MINOR
+- **Max 1 inline fix retry.** If still FAIL after retry → set status: PARTIAL AND set `failure_after_retry: true` in spec_check output, proceed
+- PARTIAL (no failure_after_retry flag): document gaps, proceed to handoff. code-reviewer treats gaps as MINOR
+- PARTIAL with `failure_after_retry: true`: code-reviewer escalates to BLOCKER (category: completeness) — see code-reviewer.md QUICK CHECK spec_check branch. This is the safety net for retry exhaustion: silent FAIL→PARTIAL→MINOR demotion is closed.
 - PASS: proceed to handoff
```

Append после `## Output` section (L42-52) field documentation:

```diff
 spec_check:
   status: "PASS|PARTIAL|FAIL"
   coverage_pct: 100
   deviations_confirmed:
     - "Part N: adjustment description (from evaluate)"
   ac_coverage:
     - "AC 1: covered by TestXxx"
     - "AC 2: covered by code path in service.go:42"
   issues: []
+  failure_after_retry: false  # OPTIONAL bool. Set to true ONLY when status=PARTIAL was reached via retry exhaustion (FAIL → 1 retry → still FAIL). Default: absent/false. Reviewer raises BLOCKER on PARTIAL+true.
```

#### 3.3 — code-reviewer.md (UPDATE)

Edit QUICK CHECK spec_check branch (L72-91), specifically PARTIAL handling (L86-88):

```diff
      - If spec_check.status == PARTIAL:
-       - Note gaps from spec_check.issues, factor into REVIEW as MINOR
-       - Output: `- Spec compliance: PARTIAL ({N} gaps — see issues)`
+       - If spec_check.failure_after_retry == true:
+         - Raise BLOCKER issue:
+             {
+               "id": "(advisory; hook normalises to canonical CR-)",
+               "severity": "BLOCKER",
+               "category": "completeness",
+               "location": "Part {first missing or earliest gap}",
+               "problem": "Spec check FAIL persisted after retry exhaustion (Phase 3.5 max 1 inline fix retry). Coder set failure_after_retry=true. Plan compliance unmet — silent demotion to MINOR is bypassed.",
+               "suggestion": "Re-iterate from /coder with explicit attention to the unimplemented Part(s). If Part is genuinely infeasible, re-route to /planner via RETURN decision in Phase 1.5 EVALUATE.",
+               "reference": ".claude/skills/coder-rules/spec-check.md → Inline Fix Protocol"
+             }
+         - Output: `- Spec compliance: PARTIAL+failure_after_retry → BLOCKER raised (Part {N} unimplemented after retry exhaustion)`
+       - Else (failure_after_retry absent or false):
+         - Note gaps from spec_check.issues, factor into REVIEW as MINOR (existing behavior — unchanged)
+         - Output: `- Spec compliance: PARTIAL ({N} gaps — see issues)`
```

#### 3.4 — test-spec-check-failure-after-retry-blocker.sh (CREATE)

```bash
#!/usr/bin/env bash
# test-spec-check-failure-after-retry-blocker.sh
# AC-P3.1..AC-P3.6: failure_after_retry flag in coder_to_code_review.spec_check raises BLOCKER.
set -euo pipefail
SCRIPT_NAME="$(basename "$0")"
PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
label() { echo "[${SCRIPT_NAME}] $1: $2" >&2; }
fail() { label "FAIL" "$1"; exit 1; }
pass() { label "PASS" "$1"; }
cd "$PROJECT_ROOT"

SCHEMA=".claude/schemas/handoff.schema.json"
SPEC_CHECK=".claude/skills/coder-rules/spec-check.md"
CR=".claude/agents/code-reviewer.md"
VALIDATOR=".claude/scripts/validate-handoff.sh"

# AC-P3.1: schema includes optional failure_after_retry bool
python3 - <<'PY'
import json,sys
with open('.claude/schemas/handoff.schema.json') as f: s=json.load(f)
defs=s['$defs']['coder_to_code_review']
sc=defs['properties']['spec_check']['properties']
assert 'failure_after_retry' in sc, "AC-P3.1a — failure_after_retry not in spec_check.properties"
assert sc['failure_after_retry']['type']=='boolean', "AC-P3.1b — failure_after_retry not bool type"
# Required-list does NOT include failure_after_retry (additive optional)
required=defs.get('required',[])
assert 'failure_after_retry' not in required, "AC-P3.1c — failure_after_retry must be OPTIONAL not required"
PY
pass "AC-P3.1 — schema field optional bool"

# AC-P3.2: spec-check.md updated retry semantics
grep -q 'failure_after_retry: true' "$SPEC_CHECK" \
  || fail "AC-P3.2a — spec-check.md does not set failure_after_retry on retry exhaustion"
grep -q 'PARTIAL with `failure_after_retry: true`' "$SPEC_CHECK" \
  || fail "AC-P3.2b — spec-check.md does not document escalation path"
pass "AC-P3.2 — spec-check.md retry semantics updated"

# AC-P3.3: code-reviewer.md raises BLOCKER on flag
grep -qE 'spec_check.failure_after_retry == true' "$CR" \
  || fail "AC-P3.3a — code-reviewer.md does not check failure_after_retry"
grep -qE 'Raise BLOCKER issue' "$CR" \
  || fail "AC-P3.3b — code-reviewer.md does not raise BLOCKER on the flag"
pass "AC-P3.3 — code-reviewer.md BLOCKER rule"

# AC-P3.4: decision matrix consistency preserved
bash .claude/scripts/tests/test-decision-matrix-consistency.sh >/dev/null 2>&1 \
  || fail "AC-P3.4 — test-decision-matrix-consistency.sh regressed"
pass "AC-P3.4 — decision matrix consistency preserved"

# AC-P3.5: existing PARTIAL semantics unchanged
grep -q 'factor into REVIEW as MINOR' "$CR" \
  || fail "AC-P3.5 — existing PARTIAL→MINOR fallback removed (regression)"
pass "AC-P3.5 — existing PARTIAL→MINOR fallback preserved for non-failure cases"

# AC-P3.6: fixtures (valid with flag, invalid bad-type, valid without flag)
FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

cat > "$FIXTURE_DIR/with-flag.json" <<'JSON'
{
  "$handoff_contract": "coder_to_code_review",
  "branch": "feature/test",
  "parts_implemented": ["Part 1: stub"],
  "verify_status": {"lint":"PASS","test":"PASS","command_used":"bash test"},
  "spec_check": {
    "status": "PARTIAL",
    "coverage_pct": 80,
    "failure_after_retry": true
  },
  "iteration": "1/3"
}
JSON
bash "$VALIDATOR" "$FIXTURE_DIR/with-flag.json" 2>/dev/null \
  || fail "AC-P3.6a — fixture with failure_after_retry=true rejected"
pass "AC-P3.6a — failure_after_retry=true accepted"

cat > "$FIXTURE_DIR/no-flag.json" <<'JSON'
{
  "$handoff_contract": "coder_to_code_review",
  "branch": "feature/test",
  "parts_implemented": ["Part 1: stub"],
  "verify_status": {"lint":"PASS","test":"PASS","command_used":"bash test"},
  "spec_check": {"status": "PARTIAL", "coverage_pct": 80},
  "iteration": "1/3"
}
JSON
bash "$VALIDATOR" "$FIXTURE_DIR/no-flag.json" 2>/dev/null \
  || fail "AC-P3.6b — fixture without flag (additive backward-compat) rejected"
pass "AC-P3.6b — fixture without flag accepted (backward compat)"

cat > "$FIXTURE_DIR/bad-type.json" <<'JSON'
{
  "$handoff_contract": "coder_to_code_review",
  "branch": "feature/test",
  "parts_implemented": ["Part 1: stub"],
  "verify_status": {"lint":"PASS","test":"PASS","command_used":"bash test"},
  "spec_check": {"status": "PARTIAL", "failure_after_retry": "yes"},
  "iteration": "1/3"
}
JSON
set +e
CLAUDE_HANDOFF_VALIDATION_MODE=strict bash "$VALIDATOR" "$FIXTURE_DIR/bad-type.json" 2>/dev/null
RC=$?
set -e
[[ $RC -ne 0 ]] || fail "AC-P3.6c — fixture with bad-type failure_after_retry accepted in strict mode"
pass "AC-P3.6c — bad-type rejected"

label "PASS" "all AC-P3.* assertions passed"
```

---

### Part 4: Remove "Functions ≤ 30 lines" rule from code-reviewer

**Files touched (3):**
1. `.claude/agents/code-reviewer.md` (UPDATE — delete line 139)
2. `.claude/skills/code-review-rules/SKILL.md` (UPDATE — verify no 30-line reference; delete if present)
3. `.claude/scripts/tests/test-func-loc-rule-removed.sh` (CREATE)

**Description:** Полное удаление bullet, делегирование function-length линтеру проекта (golangci-lint funlen / pylint / eslint max-lines-per-function / clippy too_many_lines / checkstyle MethodLength). Reviewer концентрируется на семантических проверках error-handling.

**Closes ACs:** AC-P4.1..AC-P4.7.

#### 4.1 — code-reviewer.md (UPDATE)

Delete line 139 (`   - Functions ≤ 30 lines (flag if exceeded)`) entirely. Surrounding context preserved:

```diff
    **4b. Error Handling:**
    - All errors propagate context per {ERROR_WRAP} slot (resolved from PROJECT-KNOWLEDGE.md → ERROR_WRAP; CLAUDE.md fallback; SKIP if slot unset). Reference: ../skills/planner-rules/code-shapes/<LANGUAGE>.md for syntax-correct example.
    - No log AND return same error
-   - Functions ≤ 30 lines (flag if exceeded)
    - Grep: search for `log.*err` patterns near `return.*err`
```

#### 4.2 — code-review-rules/SKILL.md (UPDATE if needed)

`grep -n '30 lines\|≤ 30\|<= 30' .claude/skills/code-review-rules/SKILL.md` показал 0 matches при baseline check — файл чист. Если будущая правка вернёт ссылку — удалить аналогично 4.1. **No-op в этом Part при текущем baseline; тест проверяет invariant.**

#### 4.3 — test-func-loc-rule-removed.sh (CREATE)

```bash
#!/usr/bin/env bash
# test-func-loc-rule-removed.sh
# AC-P4.1..AC-P4.7: hardcoded "Functions ≤ 30 lines" rule fully removed; linter delegation preserved.
set -euo pipefail
SCRIPT_NAME="$(basename "$0")"
PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
label() { echo "[${SCRIPT_NAME}] $1: $2" >&2; }
fail() { label "FAIL" "$1"; exit 1; }
pass() { label "PASS" "$1"; }
cd "$PROJECT_ROOT"

# AC-P4.1 + AC-P4.2: rule removed from code-reviewer.md AND code-review-rules/
PATTERNS='Functions[[:space:]]*[≤<=]+[[:space:]]*30[[:space:]]*lines|≤[[:space:]]*30[[:space:]]*lines[[:space:]]*\(flag[[:space:]]*if[[:space:]]*exceeded\)|Functions <= 30 lines'

if grep -rE "$PATTERNS" .claude/agents/code-reviewer.md .claude/skills/code-review-rules/ 2>/dev/null; then
  fail "AC-P4.1+P4.2 — function-length 30-line rule still present in reviewer-side files"
fi
pass "AC-P4.1+P4.2 — rule removed from reviewer-side files"

# AC-P4.3: no FUNC_LOC_LIMIT slot reintroduced
if grep -rE 'FUNC_LOC_LIMIT' .claude/PROJECT-KNOWLEDGE.md.example .claude/agents/ .claude/skills/ 2>/dev/null; then
  fail "AC-P4.3 — FUNC_LOC_LIMIT slot reintroduced (cdc0e85 regression)"
fi
pass "AC-P4.3 — no FUNC_LOC_LIMIT slot"

# AC-P4.4: no LANGUAGE-conditional path for function-length
# Sanity grep — should not find conditional gating tied to function-length
if grep -rE 'LANGUAGE.*function.*length|function.*length.*LANGUAGE' .claude/agents/code-reviewer.md .claude/skills/code-review-rules/ 2>/dev/null; then
  fail "AC-P4.4 — LANGUAGE-conditional function-length path detected"
fi
pass "AC-P4.4 — no LANGUAGE-conditional function-length path"

# AC-P4.5 — covered by AC-P4.1+P4.2 grep (zero matches assertion)
pass "AC-P4.5 — grep assertion satisfied (zero matches)"

# AC-P4.6: coder.md Phase 3 VERIFY references LINT_CMD (linter responsibility preserved)
grep -q '{LINT_CMD}' .claude/commands/coder.md \
  || fail "AC-P4.6 — coder.md Phase 3 VERIFY does not reference LINT_CMD"
pass "AC-P4.6 — LINT_CMD reference preserved in coder.md"

# AC-P4.7: existing decision-matrix consistency test still passes
bash .claude/scripts/tests/test-decision-matrix-consistency.sh >/dev/null 2>&1 \
  || fail "AC-P4.7 — test-decision-matrix-consistency.sh regressed"
pass "AC-P4.7 — decision-matrix-consistency preserved"

label "PASS" "all AC-P4.* assertions passed"
```

---

### Part 5: narrative_for_reviewer summary-only contract + telemetry record

**Files touched (3):**
1. `.claude/commands/coder.md` (UPDATE — narrative_for_reviewer template prose + final_format example)
2. `.claude/skills/workflow-protocols/delegation-templates.md` (UPDATE — STEP 0 emits `narrative_truncated` telemetry record)
3. `.claude/scripts/tests/test-narrative-truncation-telemetry.sh` (CREATE)

**Description:** Schema cap 600 не меняется (C-4). Coder перепрофилируется на narrative=summary-only (1-2 предложения); details идут в structured arrays (`high_risk_areas`, `risks_mitigated`, `deviations_from_plan` — already в schema). Orchestrator при truncation эмитит telemetry record для observability.

**Closes ACs:** AC-P5.1..AC-P5.6.

#### 5.1 — coder.md (UPDATE)

Edit `handoff_output.narrative_for_reviewer` template (L58-64):

```diff
   handoff_output:
     severity: CRITICAL
     description: "MUST generate on completion — passed to /code-review"
     # For handoff contract see [handoff-protocol.md] in workflow-protocols skill → coder_to_code_review
-    narrative_for_reviewer: |
-      [Context from coder]:
-      - Coder implemented {N} Parts per plan {feature}.md
-      - Evaluate phase: {PROCEED|REVISE|RETURN} — adjustments: {list}
-      - Deviations from plan: {list or "none"}
-      - Spec check: {PASS|PARTIAL|FAIL} (coverage: {pct}%)
-      - High-risk areas: {list}
+    narrative_for_reviewer: |
+      SUMMARY-ONLY contract (P-5, schema maxLength: 600):
+      Emit 1-2 sentences capturing the work + most critical risk. Bullets/details
+      MUST go into structured arrays (deviations_from_plan, risks_mitigated,
+      high_risk_areas, evaluate_adjustments) — those are NOT subject to the 600 cap.
+
+      Template (single line):
+        "Implemented {N} Parts per {feature}.md; evaluate {PROCEED|REVISE|RETURN}; spec check {PASS|PARTIAL|FAIL}; primary risk: {one_word_or_short_phrase}."
+
+      ANTI-pattern (DO NOT emit):
+        - Multi-line bullets or [Context from coder]: blocks → exceed 600 chars → orchestrator silent-truncates
+          last (high-risk) section, leaving reviewer with incomplete picture.
+        - Embedding deviations / risks lists in narrative — those go in their own arrays.
+
+      Telemetry: orchestrator pre_delegation STEP 0 logs `narrative_truncated` to
+      handoff-validation.jsonl when narrative > 600 chars (P-5 record_kind).
```

Edit `handoff_output.example` (L65-87) — narrative becomes single-line, structured arrays stay rich:

```diff
     example: |
       Handoff → /code-review:
         branch: feature/{name}
         parts_implemented: ["Part 1: DB migration + queries", "Part 2: Domain models", "Part 3: Service/UseCase", "Part 4: API handler", "Part 5: Tests"]
+        narrative_for_reviewer: "Implemented 5 Parts per user-create.md; evaluate REVISE; spec check PASS; primary risk: race in service mutex."
         evaluate_adjustments:
           - "Part 3: Simplified error handling — using sentinel instead of custom error type"
         risks_mitigated:
           - "N+1 query in Part 2 — optimized with batch query"
+          - "Race in service mutex — added Lock around user-write path (Part 3)"
         deviations_from_plan: []
+        high_risk_areas:
+          - "Part 3: service mutex Lock ordering"
         verify_status:
           lint: PASS
           test: PASS
           command_used: "{resolved VERIFY_CMD — Go example: 'go vet ./... && make fmt && make lint && make test'; Python example: 'pytest && ruff check'; resolved per .claude/PROJECT-KNOWLEDGE.md > CLAUDE.md fallback}"
         spec_check:
           status: PASS
           coverage_pct: 100
           deviations_confirmed:
             - "Part 3: Simplified error handling — using sentinel instead of custom error type"
           ac_coverage:
             - "AC 1: covered by TestCreateUser"
             - "AC 2: covered by TestListUsers"
           issues: []
```

#### 5.2 — delegation-templates.md (UPDATE)

Edit `code_review_delegation.pre_delegation` STEP 0 cap-rule block (L289-294):

```diff
       Source of fields: extract from coder's emitted handoff narrative.
       Cap rule (P1 schema constraint): truncate `narrative_for_reviewer` at 600 chars
       BEFORE write — schema validation rejects payloads exceeding the cap.
+      Telemetry (P-5): when truncation occurs, append record to
+      .claude/workflow-state/handoff-validation.jsonl:
+          {
+            "ts": "{ISO-8601 UTC}",
+            "record_kind": "narrative_truncated",
+            "agent": "/coder",
+            "feature": "{feature}",
+            "iteration": "{N}/3",
+            "original_length": {pre-trim length, integer},
+            "truncated_length": 600,
+            "session_id": "{session_id}"
+          }
+      Rationale: silent truncation hides the loss of high_risk_areas / deviations
+      narrative content. Telemetry makes it observable; root-cause fix is
+      coder.md narrative_for_reviewer summary-only contract (see coder.md → handoff_output).
       Failure handling: if write fails (disk error) or validation fails in strict mode →
       log WARN and proceed with delegation (graceful degradation; agent still gets the
       narrative via the delegation prompt template).
```

#### 5.3 — test-narrative-truncation-telemetry.sh (CREATE)

```bash
#!/usr/bin/env bash
# test-narrative-truncation-telemetry.sh
# AC-P5.1..AC-P5.6: narrative summary-only contract + narrative_truncated telemetry.
set -euo pipefail
SCRIPT_NAME="$(basename "$0")"
PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
label() { echo "[${SCRIPT_NAME}] $1: $2" >&2; }
fail() { label "FAIL" "$1"; exit 1; }
pass() { label "PASS" "$1"; }
cd "$PROJECT_ROOT"

CODER=".claude/commands/coder.md"
DELEG=".claude/skills/workflow-protocols/delegation-templates.md"
SCHEMA=".claude/schemas/handoff.schema.json"

# AC-P5.1: coder.md narrative is summary-only contract
grep -q 'SUMMARY-ONLY contract' "$CODER" \
  || fail "AC-P5.1a — coder.md does not declare summary-only contract"
grep -qE 'Bullets/details[[:space:]]+MUST go into structured arrays' "$CODER" \
  || fail "AC-P5.1b — coder.md does not redirect bullets to structured arrays"
pass "AC-P5.1 — narrative summary-only contract documented"

# AC-P5.2: delegation-templates.md emits narrative_truncated record
grep -q '"record_kind": "narrative_truncated"' "$DELEG" \
  || fail "AC-P5.2a — narrative_truncated record_kind missing from delegation-templates.md"
grep -q 'original_length' "$DELEG" \
  || fail "AC-P5.2b — original_length field missing from telemetry payload"
pass "AC-P5.2 — narrative_truncated telemetry documented"

# AC-P5.3: schema cap 600 unchanged
python3 - <<'PY'
import json
s=json.load(open('.claude/schemas/handoff.schema.json'))
nfr=s['$defs']['coder_to_code_review']['properties']['narrative_for_reviewer']
assert nfr['maxLength']==600, f"AC-P5.3 — schema cap drift: maxLength={nfr['maxLength']}, expected 600"
PY
pass "AC-P5.3 — schema cap 600 preserved"

# AC-P5.4: simulate truncation — emit a synthetic narrative >600, run STEP 0 logic via prose grep
NARRATIVE_LEN=$(python3 -c 'print(len("a"*750))')
[[ "$NARRATIVE_LEN" == "750" ]] || fail "AC-P5.4a — sanity check: synthetic length mismatch"
# Verify delegation-templates.md prose explicitly handles >600 case
grep -qE 'when truncation occurs' "$DELEG" \
  || fail "AC-P5.4b — delegation-templates.md missing 'when truncation occurs' trigger"
pass "AC-P5.4 — truncation trigger documented"

# AC-P5.5: existing handoff-size-cap test still passes
if [[ -f .claude/scripts/tests/test-handoff-size-cap.sh ]]; then
  bash .claude/scripts/tests/test-handoff-size-cap.sh >/dev/null 2>&1 \
    || fail "AC-P5.5 — test-handoff-size-cap.sh regressed"
  pass "AC-P5.5 — handoff-size-cap test preserved"
else
  pass "AC-P5.5 — handoff-size-cap test not present (no regression possible)"
fi

# AC-P5.6: coder.md final_format example shows single-line narrative + structured arrays
grep -qE 'narrative_for_reviewer: "Implemented [0-9]+ Parts' "$CODER" \
  || fail "AC-P5.6a — coder.md example does not show single-line narrative"
grep -q 'high_risk_areas:' "$CODER" \
  || fail "AC-P5.6b — coder.md example does not populate high_risk_areas array"
pass "AC-P5.6 — coder.md example reflects new contract"

label "PASS" "all AC-P5.* assertions passed"
```

---

## Files Summary

| File | Part | Action |
|------|------|--------|
| `.claude/skills/workflow-protocols/re-routing.md` | 1 | UPDATE — append verdict_aliases block |
| `.claude/skills/workflow-protocols/orchestration-core.md` | 1 | UPDATE — Mermaid edge + phase-4 prose + increment_rules entry |
| `.claude/skills/workflow-protocols/delegation-templates.md` | 1, 2, 5 | UPDATE — alias norm step 2.1 + step 6.5 + STEP 0 telemetry |
| `.claude/skills/workflow-protocols/handoff-protocol.md` | 2 | UPDATE — covered/not_yet_covered lists + payload doc |
| `.claude/schemas/handoff.schema.json` | 2, 3 | UPDATE — version bump 1.1.0→1.2.0; add code_review_to_completion $def + failure_after_retry field |
| `.claude/commands/coder.md` | 2, 5 | UPDATE — Phase 0.5 structured_handoff_read + narrative summary-only |
| `.claude/skills/coder-rules/spec-check.md` | 3 | UPDATE — retry exhaustion sets failure_after_retry |
| `.claude/agents/code-reviewer.md` | 3, 4 | UPDATE — BLOCKER on flag; delete L139 |
| `.claude/skills/code-review-rules/SKILL.md` | 4 | UPDATE if needed (verify-only at current baseline) |
| `.claude/scripts/tests/test-needs-changes-alias-routing.sh` | 1 | CREATE |
| `.claude/scripts/tests/test-code-review-to-completion-handoff.sh` | 2 | CREATE |
| `.claude/scripts/tests/test-spec-check-failure-after-retry-blocker.sh` | 3 | CREATE |
| `.claude/scripts/tests/test-func-loc-rule-removed.sh` | 4 | CREATE |
| `.claude/scripts/tests/test-narrative-truncation-telemetry.sh` | 5 | CREATE |

**Total: 9 UPDATE + 5 CREATE = 14 file changes.**

## Acceptance Criteria

### Functional

- 36 ACs из spec'а (5 global + 31 per-part) полностью покрыты пятью Parts (AC-P1×5, AC-P2×7, AC-P3×6, AC-P4×7, AC-P5×6 = 31 per-part). PR-002 reconciled.
- 41 existing tests + 5 new tests = 46/46 PASS.
- Schema 1.2.0 принимает все existing fixtures без изменений.

### Technical

- `bash .claude/scripts/tests/test-*.sh` — 46/46 PASS (run iterating, see CLAUDE.md feedback_verify_loop_exit_code).
- `check-jsonschema --schemafile .claude/schemas/handoff.schema.json .claude/scripts/tests/fixtures/valid-*.json` — все valid pass'ат после schema bump.
- Каждый новый test зелёный по отдельности.

### Architecture

- C-1: schema additive — verified (oneOf=6, version 1.2.0; no removed properties).
- C-2: 41/41 baseline preserved (regression guard в test-code-review-to-completion-handoff.sh L88-92).
- C-3: contracts/discriminators/H2 headers verbatim — verified в spec checking.
- C-4: v1.16..v1.22 правки сохранены — verified (canonical-ID normalize untouched, 600-cap untouched, summarised additionalContext CAP 6000 untouched, defensive backfill untouched, verdict ordering untouched, FUNC_LOC_LIMIT NOT reintroduced).
- C-5: каждое изменение ссылается на конкретный file:line из spec'а.

## Verify Commands

```bash
# Full regression
pass=0; fail=0; for f in .claude/scripts/tests/test-*.sh; do
  if bash "$f" >/dev/null 2>&1; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $f"; fi
done; echo "Total: $pass PASS / $fail FAIL (target: 46 PASS / 0 FAIL)"

# Schema sanity for existing fixtures (regression guard)
for f in .claude/scripts/tests/fixtures/valid-*.json; do
  bash .claude/scripts/validate-handoff.sh "$f" || echo "REGRESSION: $f"
done
```

## Notes

- Plan-Only enforcement (RULE_1): coder выполняет EXACTLY этот plan, нет improvements.
- TDD-always-on: каждый Part имеет dedicated test → Red-Green-Refactor cycle: (1) написать failing test, (2) сделать prose/schema edit, (3) test PASS, (4) verify regression suite green.
- Order рекомендуется coder'у: Part 4 (smallest, no deps) → Part 1 → Part 5 → Part 3 → Part 2 (largest schema impact, last). Но coder может PROCEED либо REVISE если найдёт inline-correctable gaps — без изменения общего scope.
- Schema bump 1.2.0 — единственный additive minor; все existing fixtures валидируются без правок.

---

# Handoff for plan-review

```yaml
"$handoff_contract": planner_to_plan_review
artifact: ".claude/prompts/coder-codereview-audit.md"
metadata:
  task_type: refactoring
  complexity: XL
  sequential_thinking_used: true
  alternatives_considered: 2
  spec_referenced: true
  spec_artifact: ".claude/prompts/coder-codereview-audit-spec.md"
key_decisions:
  - "Schema bump 1.1.0 → 1.2.0 (additive — new $def code_review_to_completion + optional failure_after_retry; no removed properties)"
  - "P-1 alias normalization at orchestrator (not agent) — preserves cross-version compatibility of NEEDS_CHANGES enum value while fixing routing gap"
  - "P-2 code_review_to_completion handoff JSON is OPTIONAL on coder side (graceful fallback to delegation-prompt-text path) — backwards compatible rollout"
  - "P-3 failure_after_retry preserves existing PARTIAL→MINOR semantics for non-failure cases; flag is additive bool, default absent/false"
  - "P-4 full removal (not LANGUAGE-conditional) — function-length is project-linter responsibility (golangci-lint funlen / pylint / eslint / clippy / checkstyle); cdc0e85 revert respected"
  - "P-5 narrative summary-only contract enforced at coder.md prose level + telemetry-only signal at orchestrator level — schema cap 600 unchanged"
  - "All 5 Parts independent (no inter-Part deps); each has dedicated test; coder may implement in any order"
known_risks:
  - "Schema bump may shadow-break a fixture if check-jsonschema soft-prereq absent — mitigated by regression guard in test-code-review-to-completion-handoff.sh L88-92"
  - "P-2 coder Phase 0.5 read path adds new I/O — graceful fallback documented; integration with existing review-response.md text-path flow tested via fixture absence"
  - "P-3 BLOCKER raise on PARTIAL+failure_after_retry may surprise existing pipelines that expected silent merge — intentional behavior change per spec C-3 documented as wave-3 improvement"
  - "P-5 narrative shape change in coder.md final_format example may require coder agent to internalise the single-line summary format — test-narrative-truncation-telemetry.sh AC-P5.6 catches drift"
areas_needing_attention:
  - "Part 2: schema 1.1.0 → 1.2.0 — verify all existing fixtures continue to validate (regression guard in Part 2 test)"
  - "Part 2: coder.md Phase 0.5 STARTUP edit — verify new structured_handoff_read sub-block does not conflict with existing review-response.md flow"
  - "Part 3: spec_check.failure_after_retry semantics — verify existing PARTIAL→MINOR fallback is preserved for non-failure cases (AC-P3.5 explicitly tests this)"
  - "Part 1 + Part 5: telemetry record_kinds (verdict_alias_normalized, narrative_truncated) — verify they don't collide with existing record_kinds in handoff-validation.jsonl consumers"
  - "Part 4: pure deletion — verify no regression in test-decision-matrix-consistency.sh (tests AC-P4.7)"
```
