# Improvements Registry

Single source of truth for all IMP-XX improvements across the project.
Updated manually after each IMP commit. Use `git log --grep="IMP-"` for commit history.

| ID | Status | Priority | File | Description | Commit |
|----|--------|----------|------|-------------|--------|
| IMP-01 | DONE | P0 | save-review-checkpoint.sh | Verdict extraction from transcript | 880155d |
| IMP-02 | SUPERSEDED | P1 | prepare-worktree.sh | Worktree path fallback strategies (→ IMP-11) | 732e71b |
| IMP-03 | DONE | P2 | save-review-checkpoint.sh | SubagentStop payload logging for contract discovery | 3f8b900 |
| IMP-04 | SUPERSEDED | P1 | workflow-architecture.md | Sync hook stdout contracts (→ IMP-11) | f68a2ca |
| IMP-05 | DONE | P1 | orchestration-core.md | Replace SendMessage with re-launch fallback | df5ebee |
| IMP-06 | DONE | P1 | save-review-checkpoint.sh | Defensive fallback to /tmp for marker write | ab47e19 |
| IMP-07 | DONE | P2 | save-review-checkpoint.sh | agent_type fallback includes "name" field | 3f8b900 |
| IMP-08 | DONE | P1 | sync-agent-memory.sh | Validate worktree_path + modified-only sync | 19130b5 |
| IMP-09 | DONE | P1 | prepare-worktree.sh | Pre-seed agent memory into worktree | 75f21dc |
| IMP-10 | DONE | P1 | check-artifact-size.sh | PreToolUse hook stdout format fix | a7ecb15 |
| IMP-11 | DONE | P1 | resolve-worktree-path.py | Shared worktree resolver (supersedes IMP-02, IMP-04) | e3921ec |
| IMP-12 | DONE | P2 | save-review-checkpoint.sh | Sync guard with IMP-09 | 8e068cc |
| IMP-13 | DONE | P2 | check-uncommitted.sh | Complexity-aware staleness window | 6f67ed0 |
| IMP-14 | DONE | P2 | enrich-context.sh | Remove dead transcript-based exploration detection | e6e74d5 |
| IMP-15 | — | — | — | (gap — not assigned) | — |
| IMP-16 | DONE | P2 | session-analytics.sh | git worktree prune at SessionEnd | 09fb80a |
| IMP-17 | — | — | — | (gap — not assigned) | — |
| IMP-18 | DONE | P2 | track-task-lifecycle.sh | SubagentStart debug logging | 09fb80a |
| IMP-19 | DONE | P0 | prepare-worktree.sh | WorktreeCreate stdout protocol fix | 00b1038 |
| IMP-20 | DONE | P1 | prepare-worktree.sh | Comment update with protocol history (in IMP-19) | 00b1038 |
| IMP-21 | DONE | P1 | CLAUDE.md | Add WorktreeCreate to hooks enumeration | 7bb9ff8 |
| IMP-22 | DONE | P2 | validate-instructions.sh | Smoke test for WorktreeCreate protocol | f71a294 |
| IMP-23 | DONE | P2 | resolve-worktree-path.py | Session-aware worktree matching | 5c984ed |
| IMP-24 | DONE | P3 | improvements-registry.md | Centralize IMP tracking (this file) | cd71564 |
| IMP-25 | DONE | P3 | settings.json | SubagentStart tracking for review agents | 0e7a45d |
