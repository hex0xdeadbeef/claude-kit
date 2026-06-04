---
feature: operation-blocking-native-permissions
complexity: L
task_type: refactor
backlog_ref: "workflow-audit-2026-06-04-operation-blocking.md § Option B (F1+F2+F3)"
status: pending_plan_review
---

# Plan — Remove operation-blocking hook; rely on user-native permissions (Option B, full removal)

## Context

```yaml
problem: |
  block-dangerous-commands.sh (PreToolUse Bash) emits permissionDecision:"deny" for 11 command
  classes. Per docs (permissions § "Extend permissions with hooks"): "A blocking hook also takes
  precedence over allow rules" — the hook OVERRIDES the user's permissions.allow. A user who
  allowed e.g. `sudo` or `git push --force` in their own settings is STILL blocked, with no native
  opt-out (F1). In project mode the hook is also REDUNDANT with settings.json permissions.deny,
  which IS user-governable (F2).
user_directive (2026-06-04, authoritative): |
  "Мы не должны вообще перекрывать то, что настроено у юзера." + migrating to Plugin install →
  rely on what the user defines in their own settings.json / settings.local.json. The kit must
  NOT impose an un-overridable operation block. (See memory feedback_no_override_user_permissions.)
decision: |
  REMOVE block-dangerous-commands.sh entirely (delete the script + its 2 tests + unwire from both
  hook-config files). Operation-control becomes 100% the user's native permissions:
    - Project mode: settings.json permissions.deny ships as a user-OWNED, editable default baseline
      (governable via /permissions, deny-first). Kept as-is — it does NOT override the user (they can
      remove any rule). The hook (which DID override) is gone.
    - Plugin mode: settings.json permissions do not transfer → DOCUMENT the recommended deny list in
      plugin-context.md for the user to add to THEIR settings. The kit never enforces it.
constraints:
  - "handoff/verdict contracts UNCHANGED (operation-blocking is orthogonal to the pipeline)."
  - "canonical issue ID byte-stable; caveman boundaries verbatim; no new env var."
  - "settings.json ↔ hooks.json parity preserved (unwire from BOTH)."
  - "all surviving .claude/scripts/tests green before AND after."
guarded_files: "settings.json (protect-files.sh:86) + test deletions/additions under .claude/scripts/ (protect-files.sh:91) → apply via the user-authorized Bash-write method; protect-files.sh left intact. hooks.json (.claude/hooks/), CLAUDE.md, workflow.md, kit-authoring-conventions.md, PROJECT-KNOWLEDGE.md, README.md, plugin-context.md are NOT guarded (normal Edit)."
followup_out_of_scope: "protect-files.sh is the SAME anti-pattern (a Write/Edit hard-deny that overrides the user — it blocked editing settings.json this whole session). It is a RANKED FOLLOW-UP under feedback_no_override_user_permissions, NOT in this change. Flag, do not touch here."
```

## Scope

```yaml
in:
  - "DELETE .claude/scripts/block-dangerous-commands.sh (the deny-emitting operation hook)."
  - "DELETE its 2 tests: test-block-dangerous-commands.sh + test-block-dangerous-deny-parity.sh (they exist only to validate the removed hook)."
  - "UNWIRE the hook entry from BOTH .claude/settings.json AND .claude/hooks/hooks.json (PreToolUse Bash no-if group)."
  - "KEEP settings.json permissions.deny (17 rules) UNCHANGED — user-owned, editable baseline (does NOT override; the user governs via /permissions)."
  - "Clean ALL non-prompt references to block-dangerous-commands.sh: CLAUDE.md (defence-in-depth clause + hook count 30→29), workflow.md (security-hook list + count), kit-authoring-conventions.md (FATAL example), PROJECT-KNOWLEDGE.md, README.md."
  - "plugin-context.md: NEW § documenting the recommended deny list for the user to add in plugin mode (governance, NOT enforcement)."
  - "NEW guard test: assert NO deny-emitting block-dangerous hook is wired in settings.json/hooks.json AND the script file is absent (locks the 'kit ships no operation-override hook' contract)."
out:
  - {item: "Touching protect-files.sh", reason: "same anti-pattern but separate follow-up (see followup_out_of_scope)"}
  - {item: "Changing settings.json permissions.deny/allow CONTENT", reason: "it is the user-governable native layer; keep as editable default baseline"}
  - {item: "Seeding/enforcing denies in plugin mode", reason: "user directive: never override; document only"}
  - {item: "Editing historical .claude/prompts/* mentions", reason: "local research artifacts, not shipped docs"}
```

## Architecture Decision

```yaml
decision: "Delete the deny-emitting hook + its tests; unwire from both config files; protection+governance become the user's native settings.json/settings.local.json permissions (project: editable deny baseline; plugin: documented paste-in). Never override the user."
rationale: |
  - Fixes F1 (allow-override) and F2 (project-mode redundancy) at the root by REMOVING the hook, per
    the user's authoritative 'never override' directive and the Plugin-migration direction.
  - Protection is preserved where it belongs: settings.json permissions.deny (user-owned, deny-first,
    editable via /permissions). Removing the hook does not weaken project-mode denial — it just makes
    it user-overridable, which is the goal.
  - Plugin mode: platform forbids shipping permissions via plugin settings.json, so the only correct
    'user governs' mechanism is documentation (give the deny list to paste). The kit never enforces.
alternatives_rejected:
  - {opt: "keep the script unwired (opt-in)", why: "leaves a latent override hook in the kit; user said 'удалить' (remove). Dead code contradicts the principle."}
  - {opt: "deny→ask hook", why: "still a hook that interposes on user-permitted ops; user directive is to not interpose at all."}
  - {opt: "bootstrap-seed denies", why: "imposing denies on the user contradicts 'never override'; document only."}
```

## Parts

```yaml
Part 1:
  name: "RED — contract guard: no operation-override hook + zero dangling refs"
  files: [".claude/scripts/tests/test-no-operation-override-hook.sh (NEW)"]
  action: |
    NEW test (Bash-apply). Assert:
      (a) block-dangerous-commands.sh is NOT referenced as a PreToolUse command hook in
          .claude/settings.json NOR .claude/hooks/hooks.json (parse JSON, scan all PreToolUse groups).
      (b) the script file .claude/scripts/block-dangerous-commands.sh does NOT exist.
      (c) settings.json permissions.deny still contains the BASH deny baseline (rm -rf, sudo,
          git push --force, ...) — the user-owned layer is intact.
      (d) COMPLETENESS GATE (replaces the non-existent check-references safety net, PR-002):
          grep the repo for the literal `block-dangerous` and assert ZERO matches in SHIPPED files —
          excluding .claude/prompts/** , .claude/workflow-state/** , .git/** , the audit artifact
          (workflow-audit-2026-06-04-operation-blocking.md), and THIS test file itself (its grep
          pattern contains the token). This machine-checks that every shipped doc/config ref is gone.
    Run → RED (hook wired + file present + refs exist).
  guard: "Bash-apply (.claude/scripts/tests/)."
  note: "PR-002: check-references.sh is .md-only (line 68) and does NOT track .sh references — it is NOT a safety net here; assertion (d) is the real, falsifiable completeness gate."

Part 2:
  name: "GREEN — delete the hook + unwire from both config files"
  files: [".claude/scripts/block-dangerous-commands.sh (DELETE)", ".claude/settings.json", ".claude/hooks/hooks.json"]
  action: |
    Delete the script. Remove its PreToolUse Bash group (settings.json group index 3; the parallel
    ${CLAUDE_PLUGIN_ROOT}-prefixed entry in hooks.json) — remove the whole group object; leave all
    other PreToolUse groups intact. settings.json permissions UNCHANGED. Verify settings↔hooks parity
    (test-plugin-scaffold.sh derives counts).
  guard: "settings.json + script delete via Bash-apply (protect-files.sh:86/91); hooks.json normal Edit."

Part 3:
  name: "Delete the now-orphaned hook tests"
  files: [".claude/scripts/tests/test-block-dangerous-commands.sh (DELETE)", ".claude/scripts/tests/test-block-dangerous-deny-parity.sh (DELETE)"]
  action: "Remove both — they exist only to validate the removed hook. (Plugin-mode deny parity is no longer a kit concern; the user governs via native permissions.) Bash-apply."

Part 4:
  name: "Docs — remove ALL references (enumerated) + fix hook count + native-permissions governance"
  files: ["CLAUDE.md", ".claude/commands/workflow.md", ".claude/rules/kit-authoring-conventions.md", ".claude/PROJECT-KNOWLEDGE.md", "README.md", "README.ru.md"]
  action: |
    EXHAUSTIVE enumeration (verified by grep — PR-001/PR-003). Edit every shipped reference; do NOT
    rely on check-references.sh (it is .md-only and does not track .sh — PR-002). The Part-1 (d) gate
    is the completeness check.
      CLAUDE.md:
        - :34 — drop the "...and `block-dangerous-commands.sh` still provides defence-in-depth on all
          versions" clause; state operation-control is the user's native settings permissions (kit
          does not override).
        - :171 — "16 event types, 30 scripts + 2 prompt hooks" → "...29 scripts..." (R3 drift-guard).
      .claude/commands/workflow.md:
        - :379 — "...30 scripts..." → "...29 scripts...".
        - :391 — "security hooks (protect-files, block-dangerous-commands) unconditional" →
          "security hook (protect-files) unconditional".
      .claude/rules/kit-authoring-conventions.md:33 — drop block-dangerous-commands.sh from the FATAL
        security-hook example; keep protect-files.sh.
      .claude/PROJECT-KNOWLEDGE.md:
        - :97 — FATAL example: remove block-dangerous-commands.sh (keep protect-files.sh).
        - :230 — hooks-table row "| block-dangerous-commands.sh | ... |" → delete the row.
        - :267 (prose) — "PreToolUse → file protection + dangerous commands + artifact size + import
          matrix" → drop "dangerous commands" (the literal-grep won't catch this prose — explicit).
      README.md:
        - :522 — mermaid node line `TOOL -->|Bash| PRE3["block-dangerous-commands.sh (blocking)"]` →
          remove the PRE3 node line (keep the mermaid block + its 4-block count intact).
        - :873 — security-hooks prose: drop `block-dangerous-commands.sh` from the blocking list.
        - :884 — hooks-table row → delete.
      README.ru.md (MIRROR of README.md — PR-001):
        - :524 — mermaid PRE3 node line → remove.
        - :875 — prose blocking list → drop block-dangerous-commands.sh.
        - :886 — hooks-table row → delete.
    Run test-hook-count-doc-accuracy.sh → GREEN at 29; run Part-1 (d) gate → ZERO shipped refs.

Part 5:
  name: "Plugin-mode governance doc — recommended deny list (NOT enforced)"
  files: [".claude/docs/plugin-context.md"]
  action: |
    Add § "Operation safety is YOUR settings (the kit does not override)": the kit ships NO
    dangerous-command hook; in plugin mode settings.json permissions do not transfer, so to opt into
    the kit's recommended denies, add them to YOUR .claude/settings.json (or settings.local.json) —
    governable via /permissions, deny-first, and nothing the kit imposes. Include the recommended
    16-rule Bash deny list verbatim to paste. Optional doc-existence test.
```

## Tests

```yaml
new:
  - "test-no-operation-override-hook.sh — (a) hook unwired in both configs + (b) script file absent + (c) permissions.deny baseline intact + (d) ZERO `block-dangerous` refs in shipped files (excl. prompts/, workflow-state/, .git/, the audit artifact, and the test itself). Assertion (d) is the machine-checked completeness gate replacing the .md-only check-references.sh."
deleted:
  - "test-block-dangerous-commands.sh, test-block-dangerous-deny-parity.sh (validate the removed hook)."
unchanged_must_stay_green:
  - "test-plugin-scaffold.sh — settings↔hooks parity (counts derive; unwire from both keeps equal)."
  - "test-hook-count-doc-accuracy.sh — recomputes to 29; docs updated in Part 4."
regression:
  - "for f in .claude/scripts/tests/test-*.sh; do bash \"$f\" </dev/null || rc=1; done — all green (rc-propagated; </dev/null avoids background stdin-block). Net suite: -2 deleted +1 new."
```

## Acceptance Criteria

```yaml
functional:
  - "block-dangerous-commands.sh deleted; NOT wired in settings.json NOR hooks.json; no kit hook emits permissionDecision:deny for operations."
  - "settings.json permissions.deny unchanged → project-mode baseline preserved, now user-overridable via /permissions (kit no longer overrides)."
  - "plugin-context.md documents the paste-in deny list; the kit enforces nothing."
technical:
  - "New guard test RED before Part 2, GREEN after; full suite green before AND after; hook-count recomputes to 29 and docs match; settings↔hooks parity preserved."
  - "ZERO `block-dangerous` references remain in shipped files (CLAUDE.md, workflow.md, kit-authoring-conventions.md, PROJECT-KNOWLEDGE.md incl. line-267 prose, README.md ×3, README.ru.md ×3) — enforced by the Part-1 (d) gate, NOT by check-references.sh (which is .md-only and does not track .sh refs)."
architecture:
  - "No handoff/VERDICT/VERDICT_JSON change; canonical issue ID untouched; no new env var; caveman boundaries intact; protect-files.sh untouched (separate follow-up)."
user_directive_satisfied:
  - "The kit no longer overrides anything the user configured: operation-control is entirely the user's native settings permissions."
```
