---
feature: accept-edits-default
complexity: M
task_type: config_change
backlog_ref: "permission-automation research 2026-06-04 — ship defaultMode: acceptEdits in settings.local.json.default (user-approved)"
status: pending_plan_review
---

# Plan — Ship permissions.defaultMode "acceptEdits" in settings.local.json.default

## Context

```yaml
problem: |
  Users running /workflow still approve every file edit manually. The recommended permissions
  baseline (v1.36.0) cut Bash prompts but not edit prompts. permissions.defaultMode "acceptEdits"
  auto-accepts file edits + common filesystem commands in the working directory, which is the
  single biggest unattended-run win that the kit CAN ship from project/local scope.
research_findings (verified against docs):
  - "Exact key is nested: permissions.defaultMode (NOT top-level defaultMode). Source: code.claude.com/docs/en/permission-modes."
  - "acceptEdits auto-approves: file edits/creates AND mkdir/touch/rm/rmdir/mv/cp/sed (also under safe env-var or timeout/nice/nohup wrappers), but ONLY for paths inside the working directory or additionalDirectories. All other Bash commands, out-of-scope paths, and protected-path writes still prompt."
  - "deny rules ALWAYS take precedence over any mode — the shipped deny baseline (rm -rf, sudo, curl/wget, secret reads/writes, ...) still blocks even under acceptEdits."
  - "Protected paths (.git, .claude, .mcp.json, shell rc files, .npmrc, ...) are NEVER auto-approved in acceptEdits — they still prompt. So editing the kit itself (.claude/**) still prompts; acceptEdits mainly helps end-users editing ordinary app code."
  - "defaultMode: auto is IGNORED in project/local settings (.claude/settings.json, .claude/settings.local.json) since v2.1.142 — a repo cannot self-grant auto. The kit therefore CANNOT ship auto; it can only document the user-global ~/.claude/settings.json path. Out of scope here."
user_approved_scope (2026-06-04): "Yes, ship acceptEdits in .default/.example via the pipeline. (auto mode set separately in ~/.claude/settings.json — not a kit artifact.)"
constraints:
  - "handoff/VERDICT/VERDICT_JSON contracts UNCHANGED; canonical issue ID byte-stable; caveman boundaries verbatim; NO new env var."
  - ".default stays LEAN — defaultMode goes INSIDE the existing permissions object (a real key, not a '_' doc key); no new top-level '_' keys (AC-7)."
  - ".default and .example permissions blocks remain BYTE-IDENTICAL (AC-2 covers allow/deny; new AC-14 covers defaultMode parity)."
  - "settings.json UNCHANGED (kit's own dev config; separate user-owned layer)."
guarded_files: "test under .claude/scripts/tests/ — protect-files.sh .claude/scripts/ guard state varies; write via the relaxed hook if active, else Bash-apply. MUST NOT commit any protect-files.sh relaxation. .default/.example + README are NOT guarded (normal Edit)."
```

## Scope

```yaml
in:
  - "Add \"defaultMode\": \"acceptEdits\" as the first key inside permissions {} in BOTH .default and .example (byte-identical)."
  - "Extend test-permission-defaults.sh: AC-14 — both files have permissions.defaultMode == \"acceptEdits\" (and they match)."
  - "Document in .example _permissions_comment: what acceptEdits auto-approves, that deny still wins, that protected paths (.git/.claude/.mcp.json) still prompt, and that auto mode must live in ~/.claude/settings.json (ignored in project/local scope)."
  - "Document the same briefly in README permissions baseline section."
out:
  - {item: "Shipping defaultMode: auto anywhere in the kit", reason: "ignored in project/local settings by design (v2.1.142+); document-only"}
  - {item: "Editing settings.json", reason: "kit's own dev config; separate user-owned layer"}
  - {item: "Editing ~/.claude/settings.json", reason: "separate user-global step the orchestrator performs AFTER this kit change; not a committed kit artifact"}
  - {item: "New env vars / sandbox config / PreToolUse auto-approve hook", reason: "not in approved scope; LLM permission-hook is an override anti-pattern + external paid dep — explicitly rejected"}
```

## Architecture Decision

```yaml
decision: "Add the single scalar permissions.defaultMode: \"acceptEdits\" to the existing permissions block in .default + .example (byte-identical), lock it with a test assertion, and document the mode semantics + the auto-mode user-global constraint. No schema/contract/env change."
rationale: |
  - acceptEdits is the only prompt-reducing permission MODE that is honored from the kit's
    project/local install source; it removes the most frequent prompt (file edits) for end-users.
  - It is safe-by-construction here: deny rules still win, protected paths still prompt, and the
    scope is the working directory only. It is reversible per-session via Shift+Tab and per-user
    via /permissions, so it never overrides the user.
  - auto mode (the zero-prompt classifier-guarded option) is documented for ~/.claude/settings.json
    because the platform deliberately ignores it from project/local settings.
alternatives_rejected:
  - {opt: "ship defaultMode: auto in .default", why: "ignored in project/local scope since v2.1.142 — would look configured but do nothing"}
  - {opt: "defaultMode: bypassPermissions", why: "equals --dangerously-skip-permissions, which the user explicitly rejected"}
  - {opt: "defaultMode: dontAsk", why: "auto-denies anything unlisted → silent stalls mid-pipeline when a new command is needed"}
  - {opt: "third-party LLM PreToolUse permission hook", why: "external paid API key + deny-emitting override anti-pattern (the one removed in 9e5f01e); native auto mode supersedes it"}
```

## Parts

```yaml
Part 1:
  name: "RED — assert permissions.defaultMode == acceptEdits in both files"
  files: [".claude/scripts/tests/test-permission-defaults.sh"]
  action: |
    In the python heredoc (after AC-13), add AC-14 using the already-loaded dperm/eperm:
      emit(dperm.get("defaultMode") == "acceptEdits", ".default permissions.defaultMode == acceptEdits")
      emit(eperm.get("defaultMode") == "acceptEdits", ".example permissions.defaultMode == acceptEdits")
    Run → RED (key absent in both files).
  guard: "Edit under .claude/scripts/tests/ (relaxed hook) or Bash-apply."

Part 2:
  name: "GREEN — add defaultMode: acceptEdits to both files (byte-identical)"
  files: [".claude/settings.local.json.default", ".claude/settings.local.json.example"]
  action: |
    Insert \"defaultMode\": \"acceptEdits\", as the FIRST key inside the permissions object,
    immediately after the opening \"permissions\": { line, in BOTH files identically (so it
    sits above \"allow\"). Keep allow/deny arrays unchanged. Run test → GREEN; JSON parses.
  guard: "Normal Edit (files not protected)."

Part 3:
  name: "Docs — .example _permissions_comment + README permission-mode note"
  files: [".claude/settings.local.json.example", "README.md"]
  action: |
    .example _permissions_comment: add a bullet — "defaultMode acceptEdits: auto-approves file
    edits + mkdir/touch/rm/rmdir/mv/cp/sed in the working directory; deny rules still win; protected
    paths (.git, .claude, .mcp.json, shell rc) still prompt; reversible via Shift+Tab. For a fully
    unattended classifier-guarded run, set permissions.defaultMode: auto in ~/.claude/settings.json
    — auto is ignored in project/local settings (incl. this file) by design (Claude Code v2.1.142+)."
    README permissions baseline: add an equivalent short paragraph (acceptEdits shipped; auto is
    user-global only). Preserve the LIMITS and MERGE paragraphs verbatim.
  guard: "Normal Edit."
```

## Tests

```yaml
new:
  - "test-permission-defaults.sh AC-14 — both .default and .example have permissions.defaultMode == \"acceptEdits\"."
unchanged_must_stay_green:
  - "AC-1..AC-13 (non-empty allow/deny, parity, catastrophic+secret core, no over-broad Bash, granular secrets, space-form, lean .default, supplement rules, doc guards)."
regression:
  - "for f in .claude/scripts/tests/test-*.sh; do bash \"$f\" </dev/null || rc=1; done — full suite green before AND after."
```

## Acceptance Criteria

```yaml
functional:
  - "permissions.defaultMode == \"acceptEdits\" in BOTH .default and .example; JSON parses in both."
  - ".default/.example permissions blocks byte-identical (allow + deny + defaultMode)."
  - "No auto / bypassPermissions / dontAsk shipped; settings.json untouched."
technical:
  - "AC-14 RED before Part 2, GREEN after; full suite green before AND after; .default has no top-level '_' keys (AC-7)."
  - ".example _permissions_comment + README document acceptEdits semantics AND the auto-mode user-global constraint; LIMITS/MERGE caveats preserved."
architecture:
  - "No handoff/VERDICT/VERDICT_JSON change; canonical issue ID untouched; no new env var; caveman boundaries intact; settings.json untouched; protect-files.sh relaxation NOT committed."
user_directive_satisfied:
  - "Recommended default remains user-governable (Shift+Tab, /permissions); the kit overrides nothing. auto mode handled separately in the user's ~/.claude/settings.json."
```
