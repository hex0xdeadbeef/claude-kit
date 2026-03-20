---
name: hook-regex-anchoring
description: Shell hook scripts must not use ^ anchor when matching git subcommands; use re.search with suffix boundary instead
type: feedback
---

In PreToolUse hook scripts that parse `tool_input.command`, use `re.search()` with a suffix word-boundary pattern rather than `re.match()` with `^`:

- BAD: `re.match(r'^\s*git\s+commit\b', cmd)` — fails to catch chained commands (`git add && git commit`), and `\b` before `-` is non-word so `git commit-msg` falsely matches
- GOOD: `re.search(r'\bgit\s+commit(\s|$)', cmd)` — catches commit anywhere in chain, and `(\s|$)` correctly rejects `git commit-msg` and `git commit-tree`

**Why:** Discovered during FIX-01 review (pre-commit-build.sh). Two defects from one regex: (1) false-positive on git commit-tree/commit-msg due to hyphen being non-word char for `\b`; (2) chained commands silently bypassed due to `^` anchor. Both fixed by switching to re.search with `(\s|$)` suffix.

**How to apply:** Any new hook that matches on a git subcommand or shell command prefix should use `re.search` + `(\s|$)` pattern. Flag existing hooks using `re.match` + `\b` as MAJOR if the false-positive risk is real.
