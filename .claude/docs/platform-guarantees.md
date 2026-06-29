# Platform Guarantees (externalized from CLAUDE.md — audit #5)

> On-demand maintenance reference. CLAUDE.md keeps a pointer here. Consult when
> changing the `>= 2.1.141` version floor or rolling back a platform reliance.

## Platform Guarantees Relied Upon

The kit depends on these Claude Code platform behaviours. Do NOT lower the `>= 2.1.141` version
floor or roll back a reliance without re-checking this list — each row is load-bearing for the
pipeline. (Sources: local `CHANGELOG.md` at the cited versions.)

| Platform guarantee | Version | What the kit relies on it for |
| ------------------ | ------- | ----------------------------- |
| Background subagents cannot bypass the worktree-isolation guard (write to the shared checkout) | 2.1.154 | `code-reviewer` (`isolation: worktree`) — clean-slate review without polluting the main checkout |
| Background-agent completion no longer triggers premature "out of context" on 1M-context models | 2.1.154 | Opus 4.8 1M-context pipeline — review/research agents finishing mid-run must not abort the orchestrator |
| `worktree.baseRef: "head"` resolves the current worktree's HEAD (not the main checkout's) | 2.1.154 | Correct base ref for worktree-spawned review agents |
| Sandbox write-allowlist in worktrees narrowed to `.git` (was the whole repo root) | 2.1.150 | Worktree review isolation — writes scoped away from the main tree |
| Worktree cleanup no longer `rm -rf` on `git worktree remove` failure | 2.1.143 | Safe teardown of review worktrees — no destructive fallback |
| Read tool returns a PARTIAL view instead of a hard error past the token cap | 2.1.145 | `planner`/`coder` large-file reads degrade gracefully instead of failing the phase |
| Compaction preserves sensitive user instructions | 2.1.139 | Checkpoint / `--resume` recovery keeps the workflow contract intact across compaction |
| 1H prompt-cache TTL no longer silently downgrades to 5-min | 2.1.129 / 2.1.132 | XL "Prompt Cache Policy" relies on the 1H TTL surviving phase transitions |
| A malformed hooks / managed-settings entry no longer voids the whole settings file | 2.1.122 / 2.1.154 | Hook wiring survives a single bad entry — pipeline hooks keep firing |
| Claude-managed worktrees left unlocked on finish; leaked locked agent worktree registrations auto-cleaned | 2.1.157 / 2.1.187 | Worktree-isolated `code-reviewer` registrations under `.claude/worktrees/agent-*` are reaped by the platform; below 2.1.187 use the interim helper (see note below) |

### Interim worktree cleanup for CC < 2.1.187

Below the 2.1.187 auto-clean, killed worktree-isolated `code-reviewer` agents leave locked
`.claude/worktrees/agent-*` registrations that accumulate and can poison
`resolve-worktree-path.py` Strategy 2 (most-recent-by-mtime). Run the standalone helper to
reap stale registrations (age guard defaults to 6h, measured by the `.git/worktrees/<name>`
metadata mtime — the same signal the resolver trusts; review agents finish in minutes, so the
guard never touches an active worktree):

    bash .claude/scripts/prune-stale-worktrees.sh [max_age_hours]

It is intentionally NOT hook-wired: that would re-touch the `settings.json` / AC-C5.13 /
hook-count / exec-bit surface and make the existing `test-stop-circuit-breaker.sh` T8
SessionEnd test exercise prune logic against the real repo — and CC 2.1.187 is the long-term
owner. Leftover `worktree-agent-*` branches are left intact (`git branch -D` is in the
permission deny-list and the refs are harmless).

