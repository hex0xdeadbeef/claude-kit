---
name: project-structure
description: Claude Kit project structure relevant to plan review — layer rules, script protection, docs location
type: project
---

This is a Claude Code configuration kit (not app code). Plans reviewed here are for shell scripts,
Python blocks, Markdown docs, and occasionally Go code.

**Layer architecture (Go only — import matrix):**
handler → service → repository → models (handler never imports repository directly)

**Script protection:** `.claude/scripts/` is blocked by protect-files.sh hook. All script changes
must be provided as diffs for the user to apply manually. Plans must acknowledge this.

**Docs directory:** `.claude/docs/` — may not exist (was lost in a .claude overwrite incident).
Plans referencing workflow-architecture.md should instruct coder to CREATE, not UPDATE.

**Why:** .claude overwrite incident removed docs directory entirely as of 2026-03-30.
**How to apply:** When a plan says UPDATE a file in .claude/docs/, verify the file exists first.
If missing, the coder must create it from scratch.
