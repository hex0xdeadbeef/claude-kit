# claude-kit bug report — Plugin-install EACCES on hook scripts (posix_spawn)

**Date:** 2026-06-09
**Reporter:** Claude (Opus 4.8), during a `/workflow` run in the kit repo.
**Affected release:** v1.40.0 (regression introduced across v1.38.0–v1.40.0 plugin-mode work).
**Repo:** `claude-kit` at `/Users/dmitriym/Desktop/claude-kit`.

## TL;DR

On plugin install, every session start surfaced:

```
SessionStart:startup hook error
Failed with non-blocking status code: Error occurred while executing hook command:
EACCES: permission denied, posix_spawn
'/Users/<user>/.claude/plugins/cache/claude-kit/claude-kit/1.40.0/.claude/scripts/...'
```

(Two identical `SessionStart:startup hook error` lines = two failing SessionStart scripts.)

**Root cause:** hooks are wired **exec-form** (`{"type":"command","command":"<script>","args":[]}`),
so Claude Code `posix_spawn`s the script **directly — no shell**. Three hook scripts were
git-tracked **mode `100644`** (no executable bit). A `100644` file cannot be `posix_spawn`'d →
`EACCES`. Plugin distribution ships the git tree verbatim, so the missing `+x` reached every
plugin cache. (Project-scoped installs hit the same failure but it was masked: non-blocking, and
the affected scripts' SessionStart work is a near-no-op in project mode.)

## The three broken scripts

| Script | Hook event | Manifest entries |
| ------ | ---------- | ---------------- |
| `.claude/scripts/inject-kit-context.sh` | **SessionStart** | error line #1 |
| `.claude/scripts/bootstrap-project-config.sh` | **SessionStart** | error line #2 |
| `.claude/scripts/inject-review-context.sh` | SubagentStart (plan/code reviewer) | silently broke reviewer context injection |

All three are recent plugin-mode additions (commits `fc1dc8c` / `93cc32e` / `4d4aea8`,
Jun 4–9) created via the Write tool + `git add -f` (global gitignore ignores `.claude/`) and
**never `chmod +x`'d**. The other 26 hook command-scripts were already `100755`.

**Severity multiplier:** `inject-kit-context.sh` is the script that writes the durable
`.claude/workflow-state/.bundled-kit-root` marker — the entire **v1.40.0** Bug A/B fix
(`2026-06-09-plugin-mode-bundled-root.md`). Because it could not execute in plugin mode, the
v1.40.0 fix was **dead for every plugin user**. This fix resurrects it.

## Evidence

- Reproduced: direct-exec of a `644` script → `permission denied`, exit `126` (EACCES);
  same script via `bash <script>` → exit `0`. Matches the customer's `posix_spawn` failure.
- `git ls-files -s` showed the 3 scripts at `100644`; all 26 others at `100755`.
- Both hook manifests reference the same 29 scripts: `.claude/settings.json` (relative
  `.claude/...` paths, project install) and `.claude/hooks/hooks.json` (the plugin manifest,
  `${CLAUDE_PLUGIN_ROOT}/.claude/...` paths). `hooks.json` is the manifest the customer hits.

## Fix

`git update-index --chmod=+x` (and on-disk `chmod +x`) on the three scripts → all `100755`.
**Mode-only change, zero content lines** — so the canonical issue-ID hash
`sha256(category|location|problem)[:8]` and every handoff/verdict contract are byte-stable.
No env-var, no caveman-boundary, no schema change. No `install.sh` edit needed (it ships the
git-tracked tree; once the git mode is `100755`, project installs inherit `+x` too).

## Regression guard

`.claude/scripts/tests/test-hook-scripts-executable.sh` — **derives** the command-script set
from **both** manifests (`settings.json` + `hooks.json`, normalizing the
`${CLAUDE_PLUGIN_ROOT}/` prefix) and asserts every script is git-tracked `100755`, exists, and
has a shebang. Also asserts **manifest parity** (the two manifests wire the identical script
set — catches project/plugin drift). Any future `644` hook script fails this test the moment it
is wired into either manifest. Verified RED (revert a script to `644` → exit 1 naming it) and
GREEN (90/90 after the fix).

## Why the existing suite did not catch it

No test asserted hook-script executability — the kit's tests are themselves invoked via
`bash <test>` (so their own `644` mode is harmless), and nothing validated the *git mode* of the
spawn surface. The new guard closes that gap.
