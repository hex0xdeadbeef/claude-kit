---
feature: ctx-audit-2-rule-workflow-split
task_type: refactor
complexity: M
backlog_ref: ".claude/workflow-audit-2026-05-30.md #2"
sequential_thinking_used: false
---

# Plan — Stop rules/workflow.md eager-loading hook-author docs every session (backlog #2)

## Scope

IN:
- `.claude/rules/workflow.md` — the ONLY rule file with no frontmatter, so it loads its full
  5060 bytes into EVERY session. Keep L1-30 (runtime command/agent map + model routing + the
  `/workflows` disambiguation note) global; move the two maintenance sections out.
- NEW `.claude/rules/kit-authoring-conventions.md` — a path-scoped rule (frontmatter `globs:`)
  holding the moved `## Hook stderr Convention` (L32-64) + `## Path Conventions` (L66-78) verbatim,
  loaded ONLY when editing kit-internal files.
- `CLAUDE.md` L165 (Rules list) — update workflow.md's description (drop "hook stderr convention")
  and add a line for the new scoped rule.
- `.claude/agents/meta-agent/scripts/check-references.sh` — MINIMAL integration touch (necessary to
  preserve an existing invariant, not a meta-agent feature change): add the new file to the PK-01
  bare-form exemption case (L42) and update the two stale comment pointers (L27, L37) that point at
  `rules/workflow.md → Path Conventions`.
- NEW test `.claude/scripts/tests/test-rule-workflow-split.sh`.

OUT (with reason):
- L1-30 of rules/workflow.md stays global and UNCHANGED — it is runtime pipeline info the
  orchestrator references; the finding scopes only L32-78. No re-scoping of the runtime map.
- The convention TEXT is preserved byte-for-byte; only its load-location changes. No rewording.

## Architecture Decision

Decision: extract the two maintenance sections into a new `globs:`-scoped rule instead of a plain
doc + manual pointer.

Rationale:
1. The 7 other rules are all path-scoped (`globs:`/`paths:`), so they load only when editing matching
   files. rules/workflow.md is the lone unscoped rule → loads every session at every complexity
   (its own H1 says "loaded every session"). A consumer working on their own Go project pays for
   ~2891 bytes of kit hook-authoring docs they never touch.
2. A `globs:`-scoped rule (vs a plain doc) preserves PROACTIVE guidance: the conventions auto-load
   when an agent edits a kit script/artifact, exactly when they are relevant — no manual
   pointer-follow needed. Scope: `.claude/**/*.sh`, `.claude/**/*.md`, `.claude/**/*.json`.
3. The runtime map (L1-30) stays global because the orchestrator references the command/agent map +
   model routing + the `/workflows` disambiguation on every pipeline run.

check-references.sh integration (necessary, not optional): PK-01 detects bare `PROJECT-KNOWLEDGE.md`
(regex `(?<![\/.])PROJECT-KNOWLEDGE\.md`). The moved `## Path Conventions` section contains the
forbidden bare form as its documented example, so the new file MUST join the L42 exemption case
(alongside `check-references.sh`, `rules/workflow.md`, `prompts/*`) — otherwise the hook self-fires
on the new file. This preserves the existing exemption invariant exactly; it adds no new behavior.

Contract surface: NONE. Rules are auto-loaded context guidance. The moved sections are hook-author
documentation, not parsed by the orchestrator at runtime, not a field in any of the 4 handoff
payloads, not part of the VERDICT/VERDICT_JSON envelope, and not an input to the canonical issue ID
hash. The hook stderr format is enforced by the scripts' own `echo >&2` lines regardless of whether
the convention doc is in the LLM window.

## Tests

TDD — write the test FIRST (RED), then implement (GREEN).

New test `test-rule-workflow-split.sh` asserts:
- AC-1 (sections moved out): rules/workflow.md does NOT contain `## Hook stderr Convention`,
  `## Path Conventions`, nor the `| Label | Meaning |` table header.
- AC-2 (runtime map kept): rules/workflow.md STILL contains `Model Routing`, the Commands/Agents map,
  and the `/workflows` disambiguation note (regression guard for test-workflow-disambiguation-doc.sh).
- AC-3 (new scoped rule): `.claude/rules/kit-authoring-conventions.md` exists, line 1 is `---`
  (frontmatter present), frontmatter has `globs:`, and the body contains `Hook stderr Convention`,
  the `| Label |` table, AND `Path Conventions`.
- AC-4 (check-references exemption works): running check-references.sh against the new file produces
  NO `PK_PATH: bare form detected` warning and exits 0 (proves the L42 exemption + that moving the
  bare-form text did not create a false positive).
- AC-5 (CLAUDE.md updated): CLAUDE.md Rules list references `kit-authoring-conventions.md` and
  workflow.md's description no longer claims it holds the "hook stderr convention".
- AC-6 (no orphaned pointer): the new rule is reachable from a pointer in rules/workflow.md.

Regression: test-workflow-disambiguation-doc.sh stays green (L3 `/workflows` note kept); full 87→88
test suite green.

## Acceptance Criteria

- [ ] 4 handoff payloads + VERDICT enum + fenced VERDICT_JSON block unchanged in shape.
- [ ] Canonical issue ID sha256(category|location|problem)[:8] byte-stable (no hashed text moved).
- [ ] All existing tests pass BEFORE and AFTER; test-workflow-disambiguation-doc.sh green.
- [ ] New test test-rule-workflow-split.sh exists and passes (AC-1..AC-6).
- [ ] No new env vars. Caveman boundaries verbatim (the moved H2 headers `## Hook stderr Convention`,
      `## Path Conventions` are preserved verbatim in the new file; only their location changes).
- [ ] check-references.sh does not false-positive on the new file (exemption added).
- [ ] Moved text is byte-identical to the original sections (no rewording).

## Parts

Part 1: Write test-rule-workflow-split.sh (RED) — AC-1..AC-6. The AC-4 self-fire probe (PR-002) MUST
        feed the hook its stdin-JSON contract: pipe `{"tool_input":{"file_path":".claude/rules/kit-authoring-conventions.md"}}`
        to check-references.sh via stdin (NOT argv), AFTER the new file exists on disk (the hook
        guards on `[[ -f "$FILE_PATH" ]]` at L46), and assert exit 0 with no `PK_PATH: bare form
        detected` line.
Part 2: Create .claude/rules/kit-authoring-conventions.md = `---`+`globs:` frontmatter +
        `# <title>` + the two sections (## Hook stderr Convention, ## Path Conventions) copied
        BYTE-IDENTICAL from workflow.md L32-78 (PR-003: preserve existing hard line-wraps; no
        re-flow, no re-indent). Trim rules/workflow.md to L1-30 + a 2-line pointer that references
        ONLY the new rule file PATH (PR-005: do not restate the Path Conventions body / bare-PK form).
        Update CLAUDE.md Rules list (drop "hook stderr convention" from workflow.md line; add the new
        scoped rule line). Update check-references.sh: (a) PR-001 — add the EXACT pattern
        `*.claude/rules/kit-authoring-conventions.md` to the L42 `case` alternation (the leading `*`
        matches both absolute and repo-relative invocation forms, mirroring the existing
        `*.claude/rules/workflow.md` entry); (b) update the L27 + L37 comment pointers to name the new
        rule file as the canonical Path-Conventions home. (GREEN)
Part 3: VERIFY — new test + full suite + test-workflow-disambiguation-doc.sh green; the AC-4 probe
        (stdin-JSON form, per Part 1) confirms check-references.sh does NOT self-fire on the new file.
