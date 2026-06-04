---
feature: reviewer-rule-delivery
complexity: XL
task_type: bugfix
backlog_ref: "workflow-audit-2026-06-04-plugin-verification.md § R1 (F-P1 + F-P2)"
status: pending_plan_review
---

# Plan — Reviewer rule-skill delivery (R1: F-P1 + F-P2)

## Context

```yaml
problem: |
  The reviewer agents declare `skills: [plan-review-rules]` / `[code-review-rules]` expecting the
  full skill body to be preloaded at subagent startup. Both rule skills are
  `disable-model-invocation: true`, and Claude Code does NOT preload a disable-model-invocation
  skill into a subagent (it skips it + logs a debug warning). Result: BOTH reviewers run WITHOUT
  their rule body (Instructions, Examples, Common-Issues, grep search_patterns, and the on-demand
  supporting-file pointers architecture-checks.md / required-sections.md / checklist.md /
  troubleshooting.md). The skill self-description "Auto-loaded via agent frontmatter" is FALSE.
evidence:
  - "docs skills:222 — 'disable-model-invocation ... Also prevents the skill from being preloaded into subagents.'"
  - "docs sub-agents:444 — 'You cannot preload skills that set disable-model-invocation: true ... skips it and logs a warning.'"
  - "LIVE PROBE (Claude Code 2.1.149): spawned plan-reviewer → 'SENTINEL: ABSENT', 'PRELOAD: NO', 'no skill body in context'."
compounding_plugin:
  - "F-P2: the on-demand fallback (reviewer Reads .claude/skills/*-rules/<file>.md) also misses in plugin mode — the reviewer runs in ISOLATED context and never receives the SessionStart 'BUNDLED KIT ROOT' directive (only the main session does). inject-review-context.sh injects review context but NOT the bundled root."
goal: "Deliver the rule-skill body to BOTH reviewers in BOTH distribution modes, WITHOUT making the skills model-invocable (preserve the disable-model-invocation main-session-budget intent). No contract/envelope/canonical-ID change. No new env var."
constraints:
  - "handoff JSON + VERDICT/VERDICT_JSON envelope shape UNCHANGED."
  - "canonical issue ID sha256(category|location|problem)[:8] byte-stable (no issue text reshaped)."
  - "caveman boundaries verbatim (VERDICT lines, JSON keys, plan H2 headers, file:line)."
  - "no new env var; reuse platform CLAUDE_PLUGIN_ROOT."
  - "all .claude/scripts/tests green before AND after."
```

## Scope

```yaml
in:
  - "plan-reviewer.md + code-reviewer.md: add an explicit STARTUP step that Reads the agent's own *-rules SKILL.md in full, with a plugin-mode 'resolve under BUNDLED KIT ROOT if present' note (mirrors the command-side B2 pattern)."
  - "inject-review-context.sh: when CLAUDE_PLUGIN_ROOT is set, prepend a 'BUNDLED KIT ROOT: <abs>' directive to the assembled review context (text), so BOTH the additionalContext path (plan-reviewer) AND the sidecar file (code-reviewer worktree) carry it."
  - "RED-first test: new test-inject-review-context-bundled-root.sh asserting directive present iff CLAUDE_PLUGIN_ROOT set; plus a static test asserting each reviewer body contains the explicit rules-Read step + bundled-root note."
  - "docs: plugin-context.md — note reviewer rule delivery (explicit Read + bundled-root via inject-review-context.sh); workflow-audit-2026-06-04.md F3/exclusion note correction (reviewers WERE affected)."
out:
  - item: "Removing disable-model-invocation: true from the two rule skills"
    reason: "Would make them model-invocable → pollutes main-session auto-load description budget + allows accidental auto-invoke. Rejected in plugin-skill-path-fix for the same reason."
  - item: "Rewriting reviewer body skill-file refs to ${CLAUDE_PLUGIN_ROOT} absolute form"
    reason: "Var does not expand in agent-body prose (docs: hook/MCP/LSP/monitor strings only) and breaks project mode."
  - item: "Solving cross-worktree absolute-path reads for code-reviewer in plugin mode"
    reason: "code-reviewer runs in an isolated worktree; reading an absolute ${CLAUDE_PLUGIN_ROOT}/.claude/skills path OUTSIDE the worktree may be sandbox-restricted. Documented as a known plugin+worktree limitation (acceptance K1); project mode + plan-reviewer plugin mode are fully fixed this increment."
```

## Architecture Decision

```yaml
decision: |
  Two additive layers, mirroring the proven command-side fix (prior audit B1/B2):
  (1) MODE-INDEPENDENT — each reviewer body gains an explicit "Read your rules skill" STARTUP
      sub-step. Reviewers have the Read tool. This replaces the broken implicit preload with an
      explicit Read (the same mechanism commands already use for disable-model-invocation skills).
  (2) PLUGIN-MODE — inject-review-context.sh (SubagentStart hook, the ONLY reviewer-side runtime
      context holding CLAUDE_PLUGIN_ROOT) prepends the same "BUNDLED KIT ROOT" directive the main
      session already gets from inject-kit-context.sh. The directive is prepended to `text` BEFORE
      the sidecar/emit branch, so plan-reviewer (additionalContext) AND code-reviewer (sidecar
      file) both receive it. The reviewer body's plugin-mode note then resolves the Read path.
rationale: |
  Uses the one reviewer-side channel guaranteed to hold CLAUDE_PLUGIN_ROOT (a hook). Additive
  (no contract/envelope/ID change, no new env var). Inert in project mode (no directive when
  CLAUDE_PLUGIN_ROOT unset → reviewer body note is a no-op, path is already project-local).
  Marker text "BUNDLED KIT ROOT" is byte-identical to inject-kit-context.sh so one resolution rule
  covers commands AND reviewers.
alternatives_rejected:
  - {opt: "drop disable-model-invocation", why: "main-session budget pollution + auto-invoke risk"}
  - {opt: "inline full rules into agent bodies", why: "duplicates the skill, loses progressive disclosure, larger diff, drift risk"}
  - {opt: "${CLAUDE_PLUGIN_ROOT} in agent-body prose", why: "no expansion in command/agent prose per docs; breaks project mode"}
```

## Parts

```yaml
Part 1:
  name: "RED — encode the new contract in tests first"
  files: [".claude/scripts/tests/test-inject-review-context-bundled-root.sh (NEW)"]
  action: |
    New test (RED against current hook). Cases:
      A. CLAUDE_PLUGIN_ROOT=/fake/plugin set → run inject-review-context.sh plan-reviewer → stdout
         additionalContext contains 'BUNDLED KIT ROOT' AND '/fake/plugin'.
      B. CLAUDE_PLUGIN_ROOT unset → output does NOT contain 'BUNDLED KIT ROOT' (project-mode inert).
      C. Static assertion (FALSIFIABLE — pinned predicate, PR-004): each reviewer body must contain
         the NEW distinctive STARTUP marker line introduced in Part 3 — the literal
         `Load your review rules:` — co-located (same line) with the exact skill path
         (`.claude/skills/plan-review-rules/SKILL.md` for plan-reviewer,
         `.claude/skills/code-review-rules/SKILL.md` for code-reviewer) AND the body must contain
         `BUNDLED KIT ROOT`. The phrase `Load your review rules:` MUST NOT exist anywhere in either
         body today (verified: pre-existing on-demand refs at plan-reviewer.md:71,86 +
         code-reviewer.md:36,196,417 use 'For details see' / 'See also' wording, NOT this literal),
         so Case C FAILS (RED) until Part 3 adds it. Test greps for the literal `Load your review rules:`
         — not a loose 'SKILL.md' substring — so the pre-existing refs cannot satisfy it.
    Run expecting FAILURE before Part 2/3.
  guard: "protect-files.sh:91-92 blocks writes under .claude/scripts/ — USER must relax for this Part, restore after, never commit the relaxation."

Part 2:
  name: "GREEN (plugin layer) — inject bundled-root directive in the reviewer SubagentStart hook"
  files: [".claude/scripts/inject-review-context.sh"]
  action: |
    After `text = "\n".join(lines)` and BEFORE the sidecar/emit branch, prepend (only when
    CLAUDE_PLUGIN_ROOT is set) a directive:
      "BUNDLED KIT ROOT: <CLAUDE_PLUGIN_ROOT>\nResolve every kit .claude/skills, .claude/templates,
       and supporting protocol file under this BUNDLED KIT ROOT — they ship inside the plugin, not
       your project. Project STATE (.claude/prompts, .claude/workflow-state, .claude/agent-memory)
       stays under your project root.\n\n" + text
    Also emit the directive on the early state_render-import-failure fallback path (_emit) when
    CLAUDE_PLUGIN_ROOT is set, so the reviewer still gets path resolution. Keep exit 0 fail-silent.
  guard: "protect-files.sh:91-92 (same relaxation as Part 1)."

Part 3:
  name: "GREEN (mode-independent layer) — explicit rules-Read STARTUP step in both reviewers + fix false skill descriptions"
  files: [".claude/agents/plan-reviewer.md", ".claude/agents/code-reviewer.md", ".claude/skills/plan-review-rules/SKILL.md", ".claude/skills/code-review-rules/SKILL.md"]
  action: |
    (3a) plan-reviewer.md Process step 1 STARTUP: add a sub-step BEFORE the plan Read, using the
    PINNED marker literal `Load your review rules:` (Part-1 Case C greps for it):
      "Load your review rules: Read `.claude/skills/plan-review-rules/SKILL.md` in full (it is your
       severity/decision/auto-escalation rubric + on-demand supporting-file index). Plugin mode: if
       a BUNDLED KIT ROOT directive is present in your injected context, resolve this path under
       that root (the skill ships in the plugin, not the project)."
    code-reviewer.md Process step 1 STARTUP: same line with `Load your review rules:` +
    `.claude/skills/code-review-rules/SKILL.md`, AND note the sidecar path also carries the
    BUNDLED KIT ROOT directive in plugin+worktree.
    (3b) PR-002 — correct the FALSE self-description in BOTH skill frontmatter `description:` fields:
      plan-review-rules/SKILL.md:3 + code-review-rules/SKILL.md:3 — replace "Auto-loaded via agent
      frontmatter when [reviewer] runs (Phase N)" with an accurate clause, e.g. "Loaded by explicit
      Read in the [reviewer] STARTUP step (disable-model-invocation blocks subagent preload)."
      Keep the rest of the description (the 'Covers: ...' enumeration) intact.
    plan-reviewer.md + code-reviewer.md are NOT protect-files-guarded (.claude/agents/); the two
    SKILL.md files live under .claude/skills/ and are NOT protect-files-guarded either (the guard
    is .claude/scripts/ only — verified protect-files.sh:91).
  caveman_note: "Reviewer agents + rule skills are caveman-exempt; edits add/adjust prose only — no VERDICT line, JSON key, or plan H2 header touched. The skill `description:` is metadata, not a contract field, and is not a canonical-issue-ID input."

Part 4:
  name: "Docs + self-knowledge CORRECTION (not annotation)"
  files: [".claude/docs/plugin-context.md", ".claude/workflow-audit-2026-06-04.md"]
  action: |
    (4a) PR-001 — plugin-context.md:54-62 is currently FALSE: the 'Agent delegation' bullet
    (lines 54-57) asserts the reviewer `-rules` skills are "preloaded via agent frontmatter
    `skills:`) resolve by description / name — namespace-agnostic ... flow correctly in plugin mode
    with no path rewrite." This is the exact opposite of the verified finding. REWRITE (do NOT
    merely append a note): MOVE the reviewer `-rules` skills out of the 'Agent delegation ...
    preloaded ... resolve by description' bullet and INTO the second bullet (lines 58-62, the
    'reference skills are disable-model-invocation: true ... loaded by explicit file Read ...
    resolve via BUNDLED KIT ROOT' bullet). After the edit the document must NOT claim anywhere that
    reviewer skills are preloaded/resolve-by-description. State the delivery accurately: reviewer
    `-rules` are loaded by an explicit Read in the reviewer STARTUP step, and in plugin mode resolve
    under the BUNDLED KIT ROOT injected into the reviewer by inject-review-context.sh (plan-reviewer
    via additionalContext; code-reviewer via the worktree sidecar).
    (4b) PR-003 — disambiguate the two near-identical audit filenames. Correction target is ONLY the
    un-suffixed `.claude/workflow-audit-2026-06-04.md` `excluded:` block (lines 31-33), which says
    reviewers "load -rules via frontmatter skills: preload → ... NOT affected". Append a 1-line
    correction there: preload does NOT work for disable-model-invocation skills (docs skills:222,
    sub-agents:444; probe 2.1.149); reviewers WERE affected — tracked + fixed in R1
    (reviewer-rule-delivery). DO NOT edit `.claude/workflow-audit-2026-06-04-plugin-verification.md`
    — that (suffixed) audit already records the finding correctly (F-P1/F-P2); no edit needed.
    NOT protect-files-guarded (.claude/docs/, .claude root).
```

## Tests

```yaml
new:
  - "test-inject-review-context-bundled-root.sh — Cases A/B/C above (RED first, GREEN after Parts 2-3)."
regression:
  - "for f in .claude/scripts/tests/test-*.sh; do bash \"$f\" || rc=1; done — all 110+ green (rc-propagated, no silent break per feedback_verify_loop_exit_code)."
  - "Existing inject-review-context tests (delta, pk-guard, shape, effort) still pass — directive is PREPENDED, does not alter existing line assertions in project mode (CLAUDE_PLUGIN_ROOT unset in those tests)."
empirical:
  - "Re-run the SENTINEL probe (spawn plan-reviewer) AFTER Part 3 → expect SENTINEL: PRESENT (skill body now Read at startup). Documented in commit body; clean up the probe marker after."
shellcheck:
  - "shellcheck clean on inject-review-context.sh (no new warnings vs baseline)."
notes:
  - "Non-blocking (plan-review iter-1 note): the directive (~350 chars) prepended to `text` plus PK injection (≤4096 chars) could push some contexts past the 6000-char CAP (inject-review-context.sh:~685), triggering the benign `[Overflow]` preview path. Because the directive is PREPENDED it lands in the first ~1000 chars of the overflow preview, so BUNDLED KIT ROOT path resolution survives. No mitigation required; coder should confirm the overflow preview still leads with the directive."
```

## Acceptance Criteria

```yaml
functional:
  - "plan-reviewer + code-reviewer load their *-rules SKILL.md body at startup (probe: SENTINEL PRESENT)."
  - "Plugin mode: inject-review-context.sh output (and code-reviewer sidecar) contains 'BUNDLED KIT ROOT' + abs path."
  - "Project mode (CLAUDE_PLUGIN_ROOT unset): no directive; existing inject-review-context behavior byte-identical."
technical:
  - "test-inject-review-context-bundled-root.sh passes; full suite green before AND after."
  - "shellcheck clean on inject-review-context.sh."
architecture:
  - "No handoff JSON / VERDICT / VERDICT_JSON envelope shape changed."
  - "Canonical issue ID sha256(category|location|problem)[:8] inputs untouched."
  - "No new env var; caveman boundaries intact."
known_limitations:
  - "K1: code-reviewer in plugin+worktree may not be able to Read the absolute ${CLAUDE_PLUGIN_ROOT}/.claude/skills path from inside its isolated worktree (sandbox). This increment fixes project mode (both reviewers) + plugin mode (plan-reviewer, non-worktree); the plugin+worktree code-reviewer deep-rules read is documented as a follow-up, not closed here. The mode-independent Part-3 explicit-Read still improves project-mode code-reviewer (worktree is a project checkout that contains the skill)."
```
