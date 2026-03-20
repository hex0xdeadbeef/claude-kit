---
name: hook-script-conventions
description: Established patterns for PreToolUse hook scripts in this repo (stdin parsing, env var bridge, exit codes, python3 dependency)
type: project
---

Hook scripts in `.claude/scripts/` follow these conventions:

- stdin is read with `INPUT=$(cat)` — MUST consume even if unused
- JSON parsed via `python3 -c "import json, sys; ..."` inline
- Env var bridge pattern for safe JSON embedding: `export VAR=value` then `os.environ.get('VAR')` in python3 — prevents injection because json.dumps escapes all special chars
- Blocking deny: exit 0 with JSON `permissionDecision: deny` output to stdout
- Non-blocking allow: exit 0 with no output
- Hard error (missing dependency): exit 2 with stderr message (see block-dangerous-commands.sh)
- Log target: `.claude/workflow-state/hook-log.txt`
- `set -euo pipefail` at top of all hooks
- `mkdir -p "$LOG_DIR" 2>/dev/null || true` for non-fatal log dir creation

**Why:** Consistency across hooks allows easier debugging and maintenance. The env var bridge pattern was introduced after FIX-09 identified JSON injection risk from raw string interpolation.

**How to apply:** When reviewing new hook scripts, verify they match these conventions. Flag deviations as MINOR unless they introduce injection or silent failure (then MAJOR/BLOCKER).
