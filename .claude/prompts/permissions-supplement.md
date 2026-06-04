---
feature: permissions-supplement
complexity: M
task_type: config_change
backlog_ref: "workflow research 2026-06-04 — supplement settings.local.json.default allow/deny (GATE-2 approved subset)"
status: pending_plan_review
---

# Plan — Supplement settings.local.json.default permissions (allow + deny)

## Context

```yaml
problem: |
  The recommended permissions baseline shipped in 284ac5d (16 allow / 24 deny + per-language
  allow templates) leaves language-agnostic gaps surfaced by web research against the Claude
  Code permissions + security docs and high-star community practice. Three safe commands still
  prompt during long /workflow runs (jq, git fetch, chmod +x), and three dangerous classes are
  not denied (curl/wget network tools, git branch -D force-delete, writing secret .env files).
research_findings (verified against docs):
  - "Read/Edit deny rules ALSO cover Bash file commands (cat/head/tail/sed) per code.claude.com/docs/en/permissions — so Read(.env) already blocks `cat .env`; no redundant Bash(cat .env) denies are added."
  - "Command blocklist already blocks curl/wget by default (code.claude.com/docs/en/security § Built-in protections), BUT the docs caveat 'When explicitly allowed' means a later broad Bash allow re-enables them. An explicit Bash(curl *)/Bash(wget *) deny is robust under that case and also blocks curl|bash / wget|sh RCE."
  - "Argument-scoped Bash deny rules are best-effort and bypassable (ona.com denylist-escape research: /proc/self/root, dynamic-linker, env-runner). The existing .example best-effort caveat MUST be preserved; this change adds no new guarantee."
  - "Env-runners (npx, docker exec, devbox run) are NOT wrapper-stripped — they remain OUT of allow (existing Node template 'NOT npx' warning confirmed correct)."
user_approved_scope (GATE-2, 2026-06-04): |
  ALLOW: Bash(jq *), Bash(git fetch *), Bash(chmod +x *).
  DENY: Bash(curl *), Bash(wget *), Bash(git branch -D *), Edit(.env), Write(.env),
        Edit(.env.local), Write(.env.local).
  Declined: D1 credential-file reads (.aws/.netrc/id_rsa/...), D2 broad Read(**/*.pem|*.key).
constraints:
  - "handoff/VERDICT/VERDICT_JSON contracts UNCHANGED (permission data is orthogonal to the pipeline)."
  - "canonical issue ID byte-stable; caveman boundaries verbatim; NO new env var."
  - ".default stays LEAN — additions go in the active permissions.allow/deny arrays only; NO new top-level '_' doc keys (AC-7)."
  - ".default and .example active allow/deny arrays remain BYTE-IDENTICAL (AC-2)."
  - "Granularity invariant (AC-5 family): use granular Edit(.env)/Write(.env) — NO broad Edit(.env.*)/Write(.env.*) — so .env.example/.sample stay editable."
  - "settings.json UNCHANGED — it is the kit's own Go-shaped dev config, a separate user-owned layer (out of scope)."
guarded_files: "test under .claude/scripts/tests/ — protect-files.sh .claude/scripts/ guard is currently relaxed (commented L91-92, file shows modified); write via the relaxed hook. MUST NOT commit the protect-files.sh relaxation (stage only feature files at Phase 5). settings.local.json.default/.example + README.md are NOT guarded (normal Edit)."
```

## Scope

```yaml
in:
  - "Add 3 allow rules to permissions.allow in BOTH .default and .example (byte-identical)."
  - "Add 7 deny rules to permissions.deny in BOTH .default and .example (byte-identical)."
  - "Extend test-permission-defaults.sh with assertions for each new rule + a write-granularity invariant (Edit/Write(.env.*) broad ABSENT)."
  - "Update .example _permissions_comment allow/deny prose to mention the new rules + the jq-redirect minor + curl/wget already-default-blocked note."
  - "Update README.md permissions baseline section (allow + deny bullets) to list the new rules."
out:
  - {item: "Touching .claude/settings.json permissions", reason: "kit's own dev config; separate user-owned layer; task targets settings.local.json.default"}
  - {item: "D1 credential-file read denies / D2 broad pem|key", reason: "explicitly declined at GATE-2"}
  - {item: "Adding redundant Bash(cat .env) denies", reason: "Read(.env) deny already covers Bash cat/head/tail/sed per docs"}
  - {item: "Removing/altering protect-files.sh .env write guard", reason: "separate follow-up under the never-override principle; native Edit/Write(.env) deny is the additive native-layer step"}
  - {item: "New env vars", reason: "constraint — none required"}
```

## Architecture Decision

```yaml
decision: "Append the GATE-2-approved language-agnostic rules to the existing recommended permissions baseline in .default + .example (byte-identical active arrays), lock each with a test assertion, and document them in .example/_permissions_comment + README. No schema/contract/env change."
rationale: |
  - allow additions (jq/git fetch/chmod +x) remove recurring prompts in long runs without widening
    to any arbitrary-command surface; each is a single safe verb, not an env-runner.
  - deny additions are best-effort safety, consistent with the documented limits: curl/wget make the
    web-fetch block robust under a future broad Bash allow and block curl|bash RCE; git branch -D
    prevents silent loss of unmerged commits; native Edit/Write(.env) deny is the USER-GOVERNABLE
    native equivalent of the protect-files.sh hard-deny (which is slated for removal under 'never
    override the user') — adding it now means .env-write protection survives that removal and the
    user can opt out via /permissions, unlike the hook.
  - granular Edit(.env)/Write(.env) (not broad .env.*) mirrors the proven Read(.env) granularity so
    .env.example/.sample remain editable (AC-5 family).
alternatives_rejected:
  - {opt: "broad Read(**/*.pem|*.key) (D2)", why: "declined at GATE-2 — false-blocks legit test fixtures/certs"}
  - {opt: "Bash(cat .env) explicit deny", why: "redundant — Read(.env) deny already covers Bash file-read commands per docs"}
  - {opt: "DB-destructive Bash deny (dropdb / DROP DATABASE patterns)", why: "SQL runs via clients/heredocs/files/vars; Bash patterns do not reliably catch it and give false confidence (docs fragility warning) — not in approved scope"}
  - {opt: "edit settings.json to match", why: "out of scope; settings.json is the kit's own dev config, a distinct user-owned layer"}
```

## Parts

```yaml
Part 1:
  name: "RED — extend test-permission-defaults.sh for the new allow/deny rules + write-granularity invariant"
  files: [".claude/scripts/tests/test-permission-defaults.sh"]
  action: |
    Add assertions inside the existing python3 heredoc (operating on da/dd/ea/ed already loaded):
      AC-8 (allow additions): for r in ["Bash(jq *)", "Bash(git fetch *)", "Bash(chmod +x *)"]: assert r in da.
      AC-9 (deny network tools): for r in ["Bash(curl *)", "Bash(wget *)"]: assert r in dd.
      AC-10 (deny git footgun): assert "Bash(git branch -D *)" in dd.
      AC-11 (deny .env writes, granular): assert "Edit(.env)" in dd AND "Write(.env)" in dd AND
              "Edit(.env.local)" in dd AND "Write(.env.local)" in dd.
      AC-12 (write-granularity invariant): assert "Edit(.env.*)" NOT in dd AND "Write(.env.*)" NOT in dd
              (keeps .env.example/.sample editable — mirrors AC-5 for writes).
    Reuse the existing emit()/parity machinery; AC-2 mirror-parity assertion already enforces
    .default==.example for the added rules (no new parity code needed).
    Run → RED (rules absent from both files).
  guard: "Bash-apply / Edit under .claude/scripts/tests/ (protect-files guard currently relaxed)."

Part 2:
  name: "GREEN — add the approved rules to .default and .example (byte-identical active arrays)"
  files: [".claude/settings.local.json.default", ".claude/settings.local.json.example"]
  action: |
    In BOTH files, append to permissions.allow:
      "Bash(jq *)", "Bash(git fetch *)", "Bash(chmod +x *)"
    In BOTH files, append to permissions.deny:
      "Bash(curl *)", "Bash(wget *)", "Bash(git branch -D *)",
      "Edit(.env)", "Write(.env)", "Edit(.env.local)", "Write(.env.local)"
    Keep arrays byte-identical between the two files (AC-2). No '_' keys added to .default (AC-7).
    Group logically: jq/git fetch near rg/git ops; chmod +x near nothing risky; curl/wget as a
    network-tools block; git branch -D near git deny group; Edit/Write(.env) adjacent to Read(.env).
    Run test → GREEN.
  guard: "Normal Edit (files not protected)."

Part 3:
  name: "Docs — .example _permissions_comment + README permissions baseline"
  files: [".claude/settings.local.json.example", "README.md"]
  action: |
    .example _permissions_comment:
      - allow bullet: add jq, git fetch, chmod +x to the language-agnostic-core sentence; note the
        minor that `jq … > file` redirect can write (still low-risk, single safe verb otherwise).
      - deny bullet: add curl/wget (note: already default-blocked by the command blocklist — explicit
        deny stays robust if a broad Bash allow is later added, and blocks curl|bash), git branch -D,
        and granular Edit/Write(.env)/(.env.local) (write-protect secrets; .env.example stays editable).
      - PRESERVE the existing LIMITS bullet verbatim (best-effort / bypassable / sandboxing-is-the-hard-boundary).
    README.md permissions baseline (~L801-802):
      - allow bullet: append `jq`, `git fetch`, `chmod +x`.
      - deny bullet: append `curl`/`wget` (with the already-default-blocked note), `git branch -D`,
        and `.env`/`.env.local` write-deny.
    No change to the LIMITS / MERGE paragraphs beyond the new rule names.
  guard: "Normal Edit."
```

## Tests

```yaml
new:
  - "test-permission-defaults.sh AC-8..AC-12 — allow additions present, deny network/git/.env-write present, broad Edit/Write(.env.*) absent. Each new rule has a dedicated assertion."
unchanged_must_stay_green:
  - "test-permission-defaults.sh AC-1..AC-7 (non-empty, parity, catastrophic+secret core, no over-broad Bash, Read(.env.*) absent, space-form, lean .default)."
regression:
  - "for f in .claude/scripts/tests/test-*.sh; do bash \"$f\" </dev/null || rc=1; done — full suite green before AND after (rc-propagated; </dev/null avoids stdin block)."
```

## Acceptance Criteria

```yaml
functional:
  - "permissions.allow in .default AND .example each gain Bash(jq *), Bash(git fetch *), Bash(chmod +x *)."
  - "permissions.deny in .default AND .example each gain Bash(curl *), Bash(wget *), Bash(git branch -D *), Edit(.env), Write(.env), Edit(.env.local), Write(.env.local)."
  - ".default and .example active allow/deny arrays remain byte-identical (AC-2)."
  - ".env.example/.sample remain editable AND readable (no broad Edit/Write/Read(.env.*) rule)."
technical:
  - "New AC-8..AC-12 assertions RED before Part 2, GREEN after; full suite green before AND after."
  - ".default has NO top-level '_' doc keys (AC-7); JSON in both files parses."
  - ".example _permissions_comment + README list the new rules; LIMITS/MERGE caveats preserved verbatim."
architecture:
  - "No handoff/VERDICT/VERDICT_JSON change; canonical issue ID untouched; no new env var; caveman boundaries intact; settings.json untouched; protect-files.sh relaxation NOT committed."
user_directive_satisfied:
  - "Recommended defaults remain user-governable via /permissions; the kit overrides nothing. Additions are the GATE-2-approved language-agnostic subset."
```
